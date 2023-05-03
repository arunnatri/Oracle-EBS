--
-- XXDO_ONT_WMS_INTF_EMAIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_WMS_INTF_EMAIL_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_wms_intf_email_pkg_b.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_wms_intf_email_pkg
    --
    -- Description  :  This package has the utilities required the Interfaces between EBS and WMS
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- ***************************************************************************
    /*
    PROCEDURE send_email(p_out_chr_errbuf     OUT VARCHAR2,
                                        p_out_chr_retcode     OUT VARCHAR2)
    IS
      l_num_return_value NUMBER := 0;
      l_chr_to_list     VARCHAR2(2000);

    BEGIN

        p_out_chr_retcode := '0';
        p_out_chr_errbuf := NULL;


        l_chr_to_list := 'bala.murugesan@deckers.com;balasivakumar_m@infosys.com';

               SEND_MAIL_HEADER('DEV2INV@deckers.com',
                                               l_chr_to_list,
                                             'Inventory Adjustment / Host Transfer Errors',
                                             l_num_return_value
                                            );

               SEND_MAIL_LINE('Content-Type: multipart/mixed; boundary=boundarystring', l_num_return_value);
               SEND_MAIL_LINE('--boundarystring', l_num_return_value);
               SEND_MAIL_LINE('Content-Type: text/plain', l_num_return_value);

               SEND_MAIL_LINE('', l_num_return_value);
               SEND_MAIL_LINE('Please refer the attached file for error details.', l_num_return_value);
               SEND_MAIL_LINE('', l_num_return_value);
               SEND_MAIL_LINE('--boundarystring', l_num_return_value);

    --           SEND_MAIL_LINE('--boundarystring', l_num_return_value);
             SEND_MAIL_LINE('Content-Type: text/xls', l_num_return_value);
             SEND_MAIL_LINE('Content-Disposition: attachment; filename="inv_error_details.xls"', l_num_return_value);
    -- SEND_MAIL_LINE('Content-Type: application/x-msexcel; name="inv_error_details.xls"', l_num_return_value);
               SEND_MAIL_LINE('--boundarystring', l_num_return_value);


               SEND_MAIL_LINE('Warehouse' || chr(9) ||
                                            'Item Number' || chr(9) ||
                                            'Error Message' || chr(9)
                                           , l_num_return_value);

               SEND_MAIL_LINE('US1' || chr(9) ||
                                            '1000137-URC-10' || chr(9) ||
                                            'Inventory Item is not valid' || chr(9)
                                           , l_num_return_value);


    --            SEND_MAIL_LINE('--boundarystring', l_num_return_value);
                SEND_MAIL_CLOSE(l_num_return_value);


    EXCEPTION
            WHEN OTHERS THEN
                    p_out_chr_errbuf :=  SQLERRM;
                    p_out_chr_retcode := '2';
                    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Unexpected error at send email procedure : ' || p_out_chr_errbuf);
    END send_email;
    */
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
            fnd_file.put_line (fnd_file.LOG,
                               CHR (10) || 'Email ID: ' || l_chr_mail_id);
            UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
        ELSE
            WHILE (LENGTH (l_chr_mail_temp) > 0)
            LOOP
                IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
                THEN
                    -- Last Mail ID
                    l_chr_mail_id   := l_chr_mail_temp;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                    EXIT;
                ELSE
                    -- Next Mail ID
                    l_chr_mail_id   :=
                        TRIM (
                            SUBSTR (l_chr_mail_temp,
                                    1,
                                    INSTR (l_chr_mail_temp, ';', 1) - 1));
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
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

    PROCEDURE send_error_email (p_out_chr_errbuf    OUT VARCHAR2,
                                p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid     ROWID;
        l_dte_last_run_time        DATE;
        v_err_data_count           NUMBER;
        l_chr_last_run_time        VARCHAR2 (100);
        l_chr_from_mail_id         VARCHAR2 (2000);
        l_chr_to_mail_ids          VARCHAR2 (2000);
        --      l_chr_report_last_run_time VARCHAR2(60);
        --      l_dte_report_last_run_time DATE;
        l_num_return_value         NUMBER;
        l_chr_header_sent          VARCHAR2 (1) := 'N';
        l_chr_instance             VARCHAR2 (60);
        l_exe_bulk_fetch_failed    EXCEPTION;
        l_exe_no_interface_setup   EXCEPTION;
        l_exe_mail_error           EXCEPTION;
        l_exe_instance_not_known   EXCEPTION;

        CURSOR c_error_data (p_last_run_date IN DATE)
        IS
            SELECT fcr.request_id, fcp.concurrent_program_name, fcp.user_concurrent_program_name,
                   fcr.responsibility_name, fcr.actual_start_date, fcr.actual_completion_date,
                   fcr.argument_text, fcr.completion_text
              FROM fnd_amp_requests_v fcr, fnd_concurrent_programs_vl fcp, fnd_lookup_values flv
             WHERE     fcr.concurrent_program_id = fcp.concurrent_program_id
                   AND fcp.concurrent_program_name = flv.lookup_code
                   AND flv.lookup_type = 'XXDO_INTERFACES_EMAIL'
                   AND flv.LANGUAGE = 'US'
                   AND fcr.status_code = 'E'
                   AND fcr.phase_code = 'C'
                   AND fcr.actual_completion_date >= p_last_run_date;

        CURSOR c_error_data_count (p_last_run_date IN DATE)
        IS
            SELECT COUNT (*)
              FROM fnd_amp_requests_v fcr, fnd_concurrent_programs_vl fcp, fnd_lookup_values flv
             WHERE     fcr.concurrent_program_id = fcp.concurrent_program_id
                   AND fcp.concurrent_program_name = flv.lookup_code
                   AND flv.lookup_type = 'XXDO_INTERFACES_EMAIL'
                   AND flv.LANGUAGE = 'US'
                   AND fcr.status = 'Error'
                   AND fcr.phase = 'Completed'
                   AND fcr.actual_completion_date >= p_last_run_date;
    BEGIN
        BEGIN
            SELECT NAME INTO l_chr_instance FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, NVL (flv.attribute12, g_dte_sysdate), flv.attribute10,
                   flv.attribute11
              INTO l_rid_lookup_rec_rowid, l_chr_last_run_time, l_chr_from_mail_id, l_chr_to_mail_ids
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = 'XXDO_ERROR_EMAIL';

            l_dte_last_run_time   :=
                TO_DATE (l_chr_last_run_time, 'DD-MON-RRRR HH24:MI:SS');
            fnd_file.put_line (
                fnd_file.LOG,
                   'Last run time : '
                || l_chr_last_run_time
                || ' '
                || l_dte_last_run_time);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        OPEN c_error_data_count (l_dte_last_run_time);

        FETCH c_error_data_count INTO v_err_data_count;

        CLOSE c_error_data_count;

        IF v_err_data_count > 0
        THEN
            send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - Concurrent Programs are in Error'
                              , l_num_return_value);

            IF l_num_return_value <> 0
            THEN
                p_out_chr_errbuf   := 'Unable to send the mail header';
                RAISE l_exe_mail_error;
            END IF;

            send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                l_num_return_value);
            send_mail_line ('--boundarystring', l_num_return_value);
            send_mail_line ('Content-Type: text/plain', l_num_return_value);
            send_mail_line ('', l_num_return_value);
            send_mail_line (
                   'Please refer the attached file for programs in Error in '
                || l_chr_instance
                || '.',
                l_num_return_value);
            send_mail_line (
                   'These errors occurred between '
                || TO_CHAR (l_dte_last_run_time, 'DD-Mon-RRRR HH24:MI:SS')
                || ' and '
                || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                || '.',
                l_num_return_value);
            send_mail_line ('', l_num_return_value);
            send_mail_line ('--boundarystring', l_num_return_value);
            send_mail_line ('Content-Type: text/xls', l_num_return_value);
            send_mail_line (
                'Content-Disposition: attachment; filename="Concurrent_Programs_Error.xls"',
                l_num_return_value);
            send_mail_line ('--boundarystring', l_num_return_value);
            send_mail_line (
                   'Concurrent Program Short Name'
                || CHR (9)
                || 'Concurrent Program Name'
                || CHR (9)
                || 'Request ID'
                || CHR (9)
                || 'Responsibility'
                || CHR (9)
                || 'Actual Start Date'
                || CHR (9)
                || 'Actual Completion Date'
                || CHR (9)
                || 'Arguments'
                || CHR (9)
                || 'Completion text'
                || CHR (9),
                l_num_return_value);

            FOR c_error_data_rec IN c_error_data (l_dte_last_run_time)
            LOOP
                send_mail_line (
                       c_error_data_rec.concurrent_program_name
                    || CHR (9)
                    || c_error_data_rec.user_concurrent_program_name
                    || CHR (9)
                    || c_error_data_rec.request_id
                    || CHR (9)
                    || c_error_data_rec.responsibility_name
                    || CHR (9)
                    || TO_CHAR (c_error_data_rec.actual_start_date,
                                'DD-MON-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (c_error_data_rec.actual_completion_date,
                                'DD-MON-RRRR HH24:MI:SS')
                    || CHR (9)
                    || c_error_data_rec.argument_text
                    || CHR (9)
                    || c_error_data_rec.completion_text
                    || CHR (9),
                    l_num_return_value);
            END LOOP;

            --    CLOSE c_error_data_rec;
            send_mail_close (l_num_return_value);

            IF l_num_return_value <> 0
            THEN
                p_out_chr_errbuf   := 'Unable to close the mail connection';
                RAISE l_exe_mail_error;
            END IF;

            -- Update the report last run time for scheduled run
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute12 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE     flv.ROWID = l_rid_lookup_rec_rowid
                       AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                       AND flv.lookup_code = 'XXDO_ERROR_EMAIL';
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    := 'No Interface setup available';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_instance_not_known
        THEN
            p_out_chr_errbuf    := 'Unable to derive the instance';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    := 'Bulk fetch failed at mail procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at mail hold report report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END send_error_email;

    PROCEDURE mail_inv_adj_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                       p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;

        CURSOR cur_error_records (p_from_date IN DATE, p_to_date IN DATE)
        IS
              SELECT CASE
                         WHEN dest_subinventory IS NOT NULL
                         THEN
                             'Host Transfer'
                         ELSE
                             'Inventory Adjustment'
                     END trans_type,
                     wh_id,
                     source_subinventory,
                     dest_subinventory,
                     source_locator,
                     destination_locator,
                     tran_date,
                     item_number,
                     qty,
                     uom,
                     reason_code,
                     error_message,
                     employee_id,
                     employee_name,
                     comments,
                     creation_date,
                     last_update_date
                FROM xxdo_inv_trans_adj_dtl_stg
               WHERE     process_status = 'ERROR'
                     AND last_update_date > p_from_date
                     AND last_update_date <= p_to_date
            ORDER BY wh_id, source_subinventory, tran_date;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_inv_adj_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        IF g_num_no_of_days IS NULL
        THEN
            -- If no of days is not passed, use the last run date from the lookup
            BEGIN
                l_dte_report_last_run_time   :=
                    TO_DATE (l_chr_report_last_run_time,
                             'DD-Mon-RRRR HH24:MI:SS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END;

            IF l_dte_report_last_run_time IS NULL
            THEN
                l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END IF;
        ELSE
            l_dte_report_last_run_time   := g_dte_sysdate - g_num_no_of_days;
        END IF;

        -- If email id is not set, use a generic one
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records (l_dte_report_last_run_time, g_dte_sysdate);

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Inventory Adjustments/Host Tranfer Error records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, g_chr_instance || ' - Inventory Adjustment / Host Transfer Errors'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of errors occurred in '
                    || g_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These errors occurred between '
                    || TO_CHAR (l_dte_report_last_run_time,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || ' and '
                    || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                    || '.',
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="Inventory_adj_error_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Transaction Type'
                    || CHR (9)
                    || 'Warehouse'
                    || CHR (9)
                    || 'From Subinventory'
                    || CHR (9)
                    || 'From Locator'
                    || CHR (9)
                    || 'To Subinventory'
                    || CHR (9)
                    || 'To Locator'
                    || CHR (9)
                    || 'Transaction Date'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Qty'
                    || CHR (9)
                    || 'UOM'
                    || CHR (9)
                    || 'Reason Code'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Employee Id'
                    || CHR (9)
                    || 'Employee Name'
                    || CHR (9)
                    || 'Comments'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).trans_type
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).source_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).source_locator
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).dest_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).destination_locator
                    || CHR (9)
                    || TO_CHAR (l_error_records_tab (l_num_ind).tran_date,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).uom
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).reason_code
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).error_message
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_name
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).comments
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate Inventory Adjustment/Host Transfer error report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at Inventory Adjustment/Host Transfer error report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at Inventory Adjustment/Host Transfer error report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_inv_adj_err_report;

    PROCEDURE mail_asn_receipt_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                           p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;

        CURSOR cur_error_records (p_from_date IN DATE, p_to_date IN DATE)
        IS
              SELECT headers.wh_id, headers.appointment_id, headers.receipt_date,
                     headers.employee_id, headers.employee_name, dtl.host_subinventory,
                     dtl.LOCATOR, dtl.shipment_number, dtl.po_number,
                     dtl.carton_id, dtl.line_number, dtl.rcpt_type,
                     dtl.item_number, dtl.qty, dtl.ordered_uom,
                     dtl.error_message, dtl.creation_date, dtl.last_update_date
                FROM xxdo_po_asn_receipt_head_stg headers, xxdo_po_asn_receipt_dtl_stg dtl
               WHERE     headers.receipt_header_seq_id =
                         dtl.receipt_header_seq_id
                     AND dtl.process_status = 'ERROR'
                     AND dtl.last_update_date > p_from_date
                     AND dtl.last_update_date <= p_to_date
            ORDER BY dtl.wh_id, dtl.host_subinventory, dtl.shipment_number,
                     dtl.po_number, dtl.carton_id, dtl.line_number;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_asn_receipt_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        IF g_num_no_of_days IS NULL
        THEN
            -- If no of days is not passed, use the last run date from the lookup
            BEGIN
                l_dte_report_last_run_time   :=
                    TO_DATE (l_chr_report_last_run_time,
                             'DD-Mon-RRRR HH24:MI:SS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END;

            IF l_dte_report_last_run_time IS NULL
            THEN
                l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END IF;
        ELSE
            l_dte_report_last_run_time   := g_dte_sysdate - g_num_no_of_days;
        END IF;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records (l_dte_report_last_run_time, g_dte_sysdate);

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Error records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, g_chr_instance || ' - ASN Receipt Errors'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of errors occurred in '
                    || g_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These errors occurred between '
                    || TO_CHAR (l_dte_report_last_run_time,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || ' and '
                    || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                    || '.',
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="ASN_receipt_error_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Appointment Id'
                    || CHR (9)
                    || 'Receipt Date'
                    || CHR (9)
                    || 'Employee ID'
                    || CHR (9)
                    || 'Employee Name'
                    || CHR (9)
                    || 'Host Subinventory'
                    || CHR (9)
                    || 'Locator'
                    || CHR (9)
                    || 'Shipment Number'
                    || CHR (9)
                    || 'PO Number'
                    || CHR (9)
                    || 'Carton'
                    || CHR (9)
                    || 'Line Number'
                    || CHR (9)
                    || 'Receipt Type'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Qty'
                    || CHR (9)
                    || 'UOM'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).appointment_id
                    || CHR (9)
                    || TO_CHAR (l_error_records_tab (l_num_ind).receipt_date,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_name
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).host_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).LOCATOR
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).shipment_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).po_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).carton_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).line_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).rcpt_type
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).ordered_uom
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).error_message
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate ASN Receipt error report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at ASN Receipt error report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at ASN Receipt error report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_asn_receipt_err_report;

    PROCEDURE mail_ship_confirm_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                            p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;

        CURSOR cur_error_records (p_from_date IN DATE, p_to_date IN DATE)
        IS
              SELECT shipment.wh_id, carton_dtl.host_subinventory, shipment.shipment_number,
                     shipment.carrier, shipment.service_level, shipment.ship_date,
                     carton.order_number, carton.carton_number, carton_dtl.line_number,
                     carton_dtl.item_number, carton_dtl.qty, carton_dtl.uom,
                     NVL (delivery.error_message, shipment.error_message) error_message, carton.tracking_number, carton.freight_list,
                     carton.freight_actual, delivery.creation_date, delivery.last_update_date
                FROM xxdo_ont_ship_conf_head_stg shipment, xxdo_ont_ship_conf_order_stg delivery, xxdo_ont_ship_conf_carton_stg carton,
                     xxdo_ont_ship_conf_cardtl_stg carton_dtl
               WHERE     delivery.shipment_number = shipment.shipment_number
                     AND delivery.wh_id = shipment.wh_id
                     AND delivery.process_status = 'ERROR'
                     AND carton.shipment_number = delivery.shipment_number
                     AND carton.order_number = delivery.order_number
                     AND carton.shipment_number = carton_dtl.shipment_number
                     AND carton.order_number = carton_dtl.order_number
                     AND carton.carton_number = carton_dtl.carton_number
                     AND shipment.request_id = delivery.request_id
                     AND delivery.request_id = carton.request_id
                     AND carton.request_id = carton_dtl.request_id
                     AND delivery.last_update_date > p_from_date
                     AND delivery.last_update_date <= p_to_date
            ORDER BY shipment.wh_id, carton_dtl.host_subinventory, shipment.ship_date,
                     shipment.shipment_number, delivery.order_number, carton.carton_number,
                     carton_dtl.line_number;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_ship_confirm_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        IF g_num_no_of_days IS NULL
        THEN
            -- If no of days is not passed, use the last run date from the lookup
            BEGIN
                l_dte_report_last_run_time   :=
                    TO_DATE (l_chr_report_last_run_time,
                             'DD-Mon-RRRR HH24:MI:SS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END;

            IF l_dte_report_last_run_time IS NULL
            THEN
                l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END IF;
        ELSE
            l_dte_report_last_run_time   := g_dte_sysdate - g_num_no_of_days;
        END IF;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records (l_dte_report_last_run_time, g_dte_sysdate);

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Ship Confirm Error records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, g_chr_instance || ' - Ship Confirm Errors'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of errors occurred in '
                    || g_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These errors occurred between '
                    || TO_CHAR (l_dte_report_last_run_time,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || ' and '
                    || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                    || '.',
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="Ship_confirm_error_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Subinventory'
                    || CHR (9)
                    || 'Shipment Number'
                    || CHR (9)
                    || 'Carrier'
                    || CHR (9)
                    || 'Service Level'
                    || CHR (9)
                    || 'Ship Date'
                    || CHR (9)
                    || 'Order Number'
                    || CHR (9)
                    || 'Carton Number'
                    || CHR (9)
                    || 'Line Number'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Qty'
                    || CHR (9)
                    || 'UOM'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Tracking Number'
                    || CHR (9)
                    || 'Freight List'
                    || CHR (9)
                    || 'Freight Cost'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).host_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).shipment_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).carrier
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).service_level
                    || CHR (9)
                    || TO_CHAR (l_error_records_tab (l_num_ind).ship_date,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).carton_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).line_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).uom
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).error_message
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).tracking_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).freight_list
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).freight_actual
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate Ship Confirm error report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at Ship Confirm error report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at Ship Confirm error report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_ship_confirm_err_report;

    PROCEDURE mail_order_status_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                            p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;

        CURSOR cur_error_records (p_from_date IN DATE, p_to_date IN DATE)
        IS
              SELECT wh_id, order_number, tran_date,
                     status, shipment_number, error_msg,
                     creation_date, last_update_date
                FROM xxdo_ont_pick_order_error_v
               WHERE     process_status = 'ERROR'
                     AND last_update_date > p_from_date
                     AND last_update_date <= p_to_date
            ORDER BY wh_id, order_number, tran_date;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_order_status_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        IF g_num_no_of_days IS NULL
        THEN
            -- If no of days is not passed, use the last run date from the lookup
            BEGIN
                l_dte_report_last_run_time   :=
                    TO_DATE (l_chr_report_last_run_time,
                             'DD-Mon-RRRR HH24:MI:SS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END;

            IF l_dte_report_last_run_time IS NULL
            THEN
                l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END IF;
        ELSE
            l_dte_report_last_run_time   := g_dte_sysdate - g_num_no_of_days;
        END IF;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records (l_dte_report_last_run_time, g_dte_sysdate);

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Order Status Update Error records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, g_chr_instance || ' - Order Status Update Errors'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of errors occurred in '
                    || g_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These errors occurred between '
                    || TO_CHAR (l_dte_report_last_run_time,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || ' and '
                    || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                    || '.',
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="Order_status_update_error_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Order Number'
                    || CHR (9)
                    || 'Transaction Date'
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || 'Shipment Number'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number
                    || CHR (9)
                    || TO_CHAR (l_error_records_tab (l_num_ind).tran_date,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).status
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).shipment_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).error_msg
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate Order Status Update error report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at Order Status Update error report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at Order Status Update error report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_order_status_err_report;

    PROCEDURE mail_rma_receipt_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                           p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;

        CURSOR cur_error_records (p_from_date IN DATE, p_to_date IN DATE)
        IS
              SELECT header.wh_id, line.host_subinventory, header.rma_number,
                     header.rma_receipt_date, line.line_number, line.item_number,
                     line.type1, line.qty, NVL (line.error_message, header.error_message) error_message,
                     line.cust_return_reason, line.employee_id, line.employee_name,
                     line.creation_date, line.last_update_date
                FROM xxdo_ont_rma_hdr_stg header, xxdo_ont_rma_line_stg line
               WHERE     header.receipt_header_seq_id =
                         line.receipt_header_seq_id
                     AND line.process_status = 'ERROR'
                     AND header.process_status = 'ERROR'
                     AND header.rma_reference IS NULL
                     AND line.last_update_date > p_from_date
                     AND line.last_update_date <= p_to_date
            ORDER BY header.wh_id, line.host_subinventory, header.rma_number,
                     header.rma_receipt_date, line.line_number;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_rma_receipt_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        IF g_num_no_of_days IS NULL
        THEN
            -- If no of days is not passed, use the last run date from the lookup
            BEGIN
                l_dte_report_last_run_time   :=
                    TO_DATE (l_chr_report_last_run_time,
                             'DD-Mon-RRRR HH24:MI:SS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END;

            IF l_dte_report_last_run_time IS NULL
            THEN
                l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END IF;
        ELSE
            l_dte_report_last_run_time   := g_dte_sysdate - g_num_no_of_days;
        END IF;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records (l_dte_report_last_run_time, g_dte_sysdate);

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of RMA Receipt Error records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, g_chr_instance || ' - RMA Receipt Errors'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of errors occurred in '
                    || g_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These errors occurred between '
                    || TO_CHAR (l_dte_report_last_run_time,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || ' and '
                    || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                    || '.',
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="RMA_receipt_error_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Subinventory'
                    || CHR (9)
                    || 'RMA Number'
                    || CHR (9)
                    || 'RMA Receipt Date'
                    || CHR (9)
                    || 'Line Number'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Type'
                    || CHR (9)
                    || 'Qty'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Return Reason'
                    || CHR (9)
                    || 'Employee ID'
                    || CHR (9)
                    || 'Employee Name'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).host_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).rma_number
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).rma_receipt_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).line_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).type1
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).error_message
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).cust_return_reason
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_name
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate RMA Receipt error report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at RMA Receipt error report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at RMA Receipt error report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_rma_receipt_err_report;

    PROCEDURE mail_rma_request_err_report (p_out_chr_errbuf    OUT VARCHAR2,
                                           p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;

        CURSOR cur_error_records (p_from_date IN DATE, p_to_date IN DATE)
        IS
              SELECT header.wh_id, line.host_subinventory, header.rma_reference,
                     header.rma_receipt_date, header.order_number, header.order_number_type,
                     header.customer_id, header.customer_name, line.line_number,
                     line.item_number, line.type1, line.qty,
                     NVL (line.error_message, header.error_message) error_message, line.cust_return_reason, line.employee_id,
                     line.employee_name, line.creation_date, line.last_update_date
                FROM xxdo_ont_rma_hdr_stg header, xxdo_ont_rma_line_stg line
               WHERE     header.receipt_header_seq_id =
                         line.receipt_header_seq_id
                     AND line.process_status = 'ERROR'
                     AND header.process_status = 'ERROR'
                     AND header.rma_reference IS NOT NULL
                     AND line.last_update_date > p_from_date
                     AND line.last_update_date <= p_to_date
            ORDER BY header.wh_id, line.host_subinventory, header.rma_reference,
                     header.rma_receipt_date, header.order_number, line.line_number;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_rma_request_prgm_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;

        IF g_num_no_of_days IS NULL
        THEN
            -- If no of days is not passed, use the last run date from the lookup
            BEGIN
                l_dte_report_last_run_time   :=
                    TO_DATE (l_chr_report_last_run_time,
                             'DD-Mon-RRRR HH24:MI:SS');
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END;

            IF l_dte_report_last_run_time IS NULL
            THEN
                l_dte_report_last_run_time   := g_dte_sysdate - 1;
            END IF;
        ELSE
            l_dte_report_last_run_time   := g_dte_sysdate - g_num_no_of_days;
        END IF;

        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids
        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        -- Logic to send the error records
        OPEN cur_error_records (l_dte_report_last_run_time, g_dte_sysdate);

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of RMA Request Error records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, g_chr_instance || ' - RMA Request Errors'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of errors occurred in '
                    || g_chr_instance
                    || '.',
                    l_num_return_value);
                send_mail_line (
                       'These errors occurred between '
                    || TO_CHAR (l_dte_report_last_run_time,
                                'DD-Mon-RRRR HH24:MI:SS')
                    || ' and '
                    || TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                    || '.',
                    l_num_return_value);
                send_mail_line ('', l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="RMA_request_error_details.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line (
                       'Warehouse'
                    || CHR (9)
                    || 'Subinventory'
                    || CHR (9)
                    || 'RMA Reference'
                    || CHR (9)
                    || 'RMA Request Date'
                    || CHR (9)
                    || 'Order Number'
                    || CHR (9)
                    || 'Order Number Type'
                    || CHR (9)
                    || 'Customer ID'
                    || CHR (9)
                    || 'Customer Name'
                    || CHR (9)
                    || 'Line Number'
                    || CHR (9)
                    || 'Item Number'
                    || CHR (9)
                    || 'Type'
                    || CHR (9)
                    || 'Qty'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9)
                    || 'Return Reason'
                    || CHR (9)
                    || 'Employee ID'
                    || CHR (9)
                    || 'Employee Name'
                    || CHR (9)
                    || 'Received from WMS at'
                    || CHR (9)
                    || 'Processed in EBS at'
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                send_mail_line (
                       l_error_records_tab (l_num_ind).wh_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).host_subinventory
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).rma_reference
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).rma_receipt_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).order_number_type
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).customer_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).customer_name
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).line_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).item_number
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).type1
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).qty
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).error_message
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).cust_return_reason
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_id
                    || CHR (9)
                    || l_error_records_tab (l_num_ind).employee_name
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).creation_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9)
                    || TO_CHAR (
                           l_error_records_tab (l_num_ind).last_update_date,
                           'DD-Mon-RRRR HH24:MI:SS')
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate RMA Request error report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at RMA Request error report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at RMA Request error report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_rma_request_err_report;

    /*
      PROCEDURE mail_address_corr_report(p_out_chr_errbuf     OUT VARCHAR2,
                                                               p_out_chr_retcode     OUT VARCHAR2)
       IS
          l_rid_lookup_rec_rowid ROWID;
          l_chr_from_mail_id     VARCHAR2(2000);
          l_chr_to_mail_ids        VARCHAR2(2000);
          l_chr_report_last_run_time VARCHAR2(60);
          l_dte_report_last_run_time DATE;
          l_num_return_value NUMBER;
          l_chr_header_sent VARCHAR2(1) := 'N';

          l_exe_bulk_fetch_failed    EXCEPTION;
          l_exe_no_interface_setup EXCEPTION;
          l_exe_mail_error             EXCEPTION;

          CURSOR cur_error_records
                  IS
             SELECT   sco.ROWID row_id, ph.customer_code cust_num,
                      ph.warehouse_code wh_code, ph.order_number ord_num,
                      sco.shipment_number shipment_num, ph.ship_to_code ship_to,
                      ph.ship_to_addr1 pick_addr1, ph.ship_to_addr2 pick_addr2,
                      ph.ship_to_addr3 pick_addr3, ph.ship_to_city pick_city,
                      ph.ship_to_state pick_state, ph.ship_to_zip pick_zip,
                      ph.ship_to_country_code pick_country,
                      sco.ship_to_addr1 ship_addr1, sco.ship_to_addr2 ship_addr2,
                      sco.ship_to_addr3 ship_addr3, sco.ship_to_city ship_city,
                      sco.ship_to_state ship_state, sco.ship_to_zip ship_zip,
                      sco.ship_to_country_code ship_country
                 FROM xxdo_ont_ship_conf_order_stg sco,
                      xxont_pick_intf_hdr_stg ph
                WHERE sco.address_verified IN( 'NOT VERIFIED','N')
                  AND ph.warehouse_code = sco.wh_id
                  AND ph.order_number = sco.order_number
             ORDER BY cust_num, ord_num;


       TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE INDEX BY BINARY_INTEGER;
       l_error_records_tab l_error_records_tab_type;

       BEGIN
          p_out_chr_errbuf := NULL;
          p_out_chr_retcode := '0';
          fnd_file.put_line (fnd_file.LOG,
                                ''
                            );

            -- Derive the last report run time, FROM email id and TO email ids
             BEGIN

                      SELECT flv.rowid,
                                  flv.attribute10,
                                  flv.attribute11,
                                  flv.attribute13
                         INTO l_rid_lookup_rec_rowid,
                                 l_chr_from_mail_id,
                                 l_chr_to_mail_ids,
                                 l_chr_report_last_run_time
                        FROM fnd_lookup_values flv
                        WHERE flv.language = 'US'
                            AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                            AND flv.enabled_flag = 'Y'
                            AND flv.lookup_code = g_chr_addr_corr_report_name;

             EXCEPTION
                    WHEN OTHERS THEN
                           FND_FILE.PUT_LINE(FND_FILE.LOG, 'Unable to get the inteface setup due to ' || SQLERRM);
                           RAISE l_exe_no_interface_setup;
             END;


           -- Convert the FROM email id instance specific
           IF l_chr_from_mail_id IS NULL THEN
                l_chr_from_mail_id := 'WMSInterfacesErrorReporting@deckers.com';
           END IF;

           -- Replace comma with semicolon in TO Ids

           l_chr_to_mail_ids := translate(l_chr_to_mail_ids, ',', ';');


          -- Logic to send the error records
          OPEN cur_error_records;

          LOOP
             IF l_error_records_tab.EXISTS (1)
             THEN
                l_error_records_tab.DELETE;
             END IF;

             BEGIN
                FETCH cur_error_records
                BULK COLLECT INTO l_error_records_tab LIMIT g_num_bulk_limit;
             EXCEPTION
                WHEN OTHERS
                THEN
                   CLOSE cur_error_records;

                   p_out_chr_errbuf :=
                         'Unexcepted error in BULK Fetch of Ship confirm address records : '
                      || SQLERRM;
                   fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                   RAISE l_exe_bulk_fetch_failed;
             END;                                              --end of bulk fetch

             IF NOT l_error_records_tab.EXISTS (1)
             THEN
                EXIT;
             END IF;

                IF l_chr_header_sent = 'N' THEN

                       send_mail_header(l_chr_from_mail_id,
                                                       l_chr_to_mail_ids,
                                                     g_chr_instance || ' - Address Correction Report',
                                                     l_num_return_value
                                                    );

                       IF l_num_return_value <> 0 THEN
                            p_out_chr_errbuf := 'Unable to send the mail header' ;
                            RAISE l_exe_mail_error;
                       END IF;

                       send_mail_line('Content-Type: multipart/mixed; boundary=boundarystring', l_num_return_value);
                       send_mail_line('--boundarystring', l_num_return_value);
                       send_mail_line('Content-Type: text/plain', l_num_return_value);

                       send_mail_line('', l_num_return_value);
    --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
    --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
    --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
    --                                              l_num_return_value);
                       send_mail_line('Please refer the attached file for details of address discrepancies occurred in ' || g_chr_instance ||'.'  ,l_num_return_Value);
                       send_mail_line('', l_num_return_value);

                       send_mail_line('--boundarystring', l_num_return_value);

                     send_mail_line('Content-Type: text/xls', l_num_return_value);
                     send_mail_line('Content-Disposition: attachment; filename="Address_correction_report.xls"', l_num_return_value);
                       send_mail_line('--boundarystring', l_num_return_value);


                       send_mail_line(  'Customer Number' || CHR (9)||
                                                'Warehouse Code'|| CHR (9)||
                                                'Order Number'|| CHR (9)||
                                                'Shipment Number'|| CHR (9)||
                                                'Pick Ticket - Address Line1'|| CHR (9)||
                                                'Pick Ticket - Address Line 2'|| CHR (9)||
                                                'Pick Ticket - Address Line 3'|| CHR (9)||
                                                'Pick Ticket - City'|| CHR (9)||
                                                'Pick Ticket - State'|| CHR (9)||
                                                'Pick Ticket - Zip'|| CHR (9)||
                                                'Pick Ticket - Country'|| CHR (9)||
                                                'Shipment - Address Line1'|| CHR (9)||
                                                'Shipment - Address Line2'|| CHR (9)||
                                                'Shipment - Address Line3'|| CHR (9)||
                                                'Shipment - City'|| CHR (9)||
                                                'Shipment - State'|| CHR (9)||
                                                'Shipment - Zip'|| CHR (9)||
                                                'Shipment - Country'|| CHR (9),
                                                    l_num_return_value
                                                   );

                      l_chr_header_sent := 'Y';

                END IF;

                FOR l_num_ind IN l_error_records_tab.FIRST .. l_error_records_tab.LAST
                LOOP


                             IF (   NVL (l_error_records_tab(l_num_ind).ship_addr1, '-1') !=
                                                              NVL (l_error_records_tab(l_num_ind).pick_addr1, '-1')
                                 OR NVL (l_error_records_tab(l_num_ind).ship_addr2, '-1') !=
                                                              NVL (l_error_records_tab(l_num_ind).pick_addr2, '-1')
                                 OR NVL (l_error_records_tab(l_num_ind).ship_addr3, '-1') !=
                                                              NVL (l_error_records_tab(l_num_ind).pick_addr3, '-1')
                                 OR NVL (l_error_records_tab(l_num_ind).ship_city, '-1') !=
                                                               NVL (l_error_records_tab(l_num_ind).pick_city, '-1')
                                 OR NVL (l_error_records_tab(l_num_ind).ship_state, '-1') !=
                                                              NVL (l_error_records_tab(l_num_ind).pick_state, '-1')
                                 OR NVL (l_error_records_tab(l_num_ind).ship_zip, '-1') !=
                                                                NVL (l_error_records_tab(l_num_ind).pick_zip, '-1')
                                 OR NVL (l_error_records_tab(l_num_ind).ship_country, '-1') !=
                                                            NVL (l_error_records_tab(l_num_ind).pick_country, '-1')
                                )
                             THEN

                                       send_mail_line(  l_error_records_tab(l_num_ind).cust_num || CHR (9)
                                                   || l_error_records_tab(l_num_ind).wh_code || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ord_num || CHR (9)
                                                   || l_error_records_tab(l_num_ind).shipment_num || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_addr1 || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_addr2 || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_addr3 || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_city || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_state || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_zip || CHR (9)
                                                   || l_error_records_tab(l_num_ind).pick_country || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_addr1 || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_addr2 || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_addr3|| CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_city || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_state || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_zip || CHR (9)
                                                   || l_error_records_tab(l_num_ind).ship_country || CHR (9),
                                                                  l_num_return_value
                                                                   );
                                       IF l_num_return_value <> 0 THEN
                                            p_out_chr_errbuf := 'Unable to generate the attachment file' ;
                                            RAISE l_exe_mail_error;
                                       END IF;


                                UPDATE xxdo_ont_ship_conf_order_stg sco
                                   SET sco.address_verified = 'REPORTED',
                                   last_update_date= sysdate
                                 WHERE sco.ROWID = l_error_records_tab(l_num_ind).row_id;
                             ELSE
                                UPDATE xxdo_ont_ship_conf_order_stg sco
                                   SET sco.address_verified = 'VERIFIED',
                                   last_update_date= sysdate
                                 WHERE sco.ROWID = l_error_records_tab(l_num_ind).row_id;
                             END IF;

                             COMMIT;

                END LOOP;

          END LOOP;                                  -- Error headers fetch loop

          -- Close the cursor
          CLOSE cur_error_records;

          -- Close the mail connection
          send_mail_close(l_num_return_value);

           IF l_num_return_value <> 0 THEN
               p_out_chr_errbuf := 'Unable to close the mail connection' ;
               RAISE l_exe_mail_error;
           END IF;

        EXCEPTION
          WHEN l_exe_mail_error THEN
            p_out_chr_retcode := '2';
             fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
          WHEN l_exe_no_interface_setup THEN
             p_out_chr_errbuf :=
                       'No Interface setup to generate Address Correction report' ;
             p_out_chr_retcode := '2';
             fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

          WHEN l_exe_bulk_fetch_failed THEN
             p_out_chr_errbuf :=
                       'Bulk fetch failed at Address Correction report procedure' ;
             p_out_chr_retcode := '2';
             fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

          WHEN OTHERS THEN
             p_out_chr_errbuf :=
                       'Unexpected error at Address Correction report procedure : ' || SQLERRM;
             p_out_chr_retcode := '2';
             fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END mail_address_corr_report;
    */
    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_interface IN VARCHAR2
                    , p_in_num_no_of_days IN NUMBER)
    IS
        l_chr_errbuf               VARCHAR2 (2000);
        l_chr_retcode              VARCHAR2 (30) := '0';
        l_exe_instance_not_known   EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, 'Start the error reports building');
        -- Take the current sysdate into global variable - this will be the to date
        g_dte_sysdate       := SYSDATE;
        g_num_no_of_days    := p_in_num_no_of_days;

        -- Get the instance name - it will be shown in the report
        BEGIN
            SELECT NAME INTO g_chr_instance FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;

        IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'INVENTORY'
        THEN
            mail_inv_adj_err_report (p_out_chr_errbuf    => l_chr_errbuf,
                                     p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    := l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to send Inventory Adjustments Error Report due to : '
                    || p_out_chr_errbuf);
            END IF;
        END IF;

        IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'ASN'
        THEN
            mail_asn_receipt_err_report (p_out_chr_errbuf    => l_chr_errbuf,
                                         p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    := l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to send ASN Receipt Error Report due to : '
                    || p_out_chr_errbuf);
            END IF;
        END IF;

        IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'SHIPMENT'
        THEN
            mail_ship_confirm_err_report (
                p_out_chr_errbuf    => l_chr_errbuf,
                p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    := l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to send Ship Confirm Error Report due to : '
                    || p_out_chr_errbuf);
            END IF;
        END IF;

        IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'ORDER'
        THEN
            mail_order_status_err_report (
                p_out_chr_errbuf    => l_chr_errbuf,
                p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    := l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to send Order Status Error Report due to : '
                    || p_out_chr_errbuf);
            END IF;
        END IF;

        IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'RMA RECEIPT'
        THEN
            mail_rma_receipt_err_report (p_out_chr_errbuf    => l_chr_errbuf,
                                         p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    := l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to send RMA Receipt Error Report due to : '
                    || p_out_chr_errbuf);
            END IF;
        END IF;

        IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'RMA REQUEST'
        THEN
            mail_rma_request_err_report (p_out_chr_errbuf    => l_chr_errbuf,
                                         p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    := l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to send RMA Receipt Error Report due to : '
                    || p_out_chr_errbuf);
            END IF;
        END IF;

        /*
            IF p_in_chr_interface = 'ALL' OR p_in_chr_interface = 'ADDRESS CORRECTION' THEN

                    mail_address_corr_report(p_out_chr_errbuf    => l_chr_errbuf,
                                                        p_out_chr_retcode  => l_chr_retcode);

                    IF l_chr_retcode <> '0' THEN

                        p_out_chr_errbuf := l_chr_errbuf ;
                        p_out_chr_retcode := '1';
                        fnd_file.put_line (fnd_file.LOG, 'Unable to send Address Correction Report due to : ' || p_out_chr_errbuf);
                    END IF;
            END IF;
        */
        BEGIN
            fnd_file.put_line (
                fnd_file.LOG,
                'Calling procedure to send email for interfaces that has completed in error : ');
            send_error_email (l_chr_errbuf, l_chr_retcode);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                    'Unable to get the inteface setup due to ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;
    EXCEPTION
        WHEN l_exe_instance_not_known
        THEN
            p_out_chr_errbuf    := 'Unable to derive the instance';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error at main procedure : ' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END main;
END xxdo_ont_wms_intf_email_pkg;
/
