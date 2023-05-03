--
-- XXD_GL_LX_REPORTS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_LX_REPORTS_PKG"
AS
    /***************************************************************************************
    * Program Name : XXD_GL_LX_REPORTS_PKG                                               *
    * Language     : PL/SQL                                                                *
    * Description  : Package used to import the data and process the FASB Min LX Obligation*
    *                Report                                                                *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Balavenu Rao         1.0       Initial Version                         17-Feb-2022   *
    * -------------------------------------------------------------------------------------*/

    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id          CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id            CONSTANT NUMBER := fnd_profile.VALUE ('ORG_ID');
    gn_resp_id           CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id      CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id        CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_ret_success       CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_success;
    gv_ret_error         CONSTANT VARCHAR2 (1) := fnd_api.g_ret_sts_error;
    gv_ret_unexp_error   CONSTANT VARCHAR2 (1)
                                      := fnd_api.g_ret_sts_unexp_error ;
    gv_ret_warning       CONSTANT VARCHAR2 (1) := 'W';
    gn_success           CONSTANT NUMBER := 0;
    gn_warning           CONSTANT NUMBER := 1;
    gn_error             CONSTANT NUMBER := 2;
    gn_limit_rec         CONSTANT NUMBER := 100;
    gn_commit_rows       CONSTANT NUMBER := 1000;
    gv_delimeter                  VARCHAR2 (1) := ',';
    gv_def_mail_recips            do_mail_utils.tbl_recips;

    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    --
    /***********************************************************************************************
    **************************** Function to get precision value   ************************
    ************************************************************************************************/
    FUNCTION get_precision_val (pv_currency_code IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_precision   NUMBER;
    BEGIN
        SELECT precision
          INTO ln_precision
          FROM fnd_currencies
         WHERE currency_code = pv_currency_code;

        RETURN ln_precision;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_precision   := 2;
            RETURN ln_precision;
    END;

    --
    /***********************************************************************************************
    **************************** Function to get email ids for error report ************************
    ************************************************************************************************/

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
                                                               SYSDATE))) xx
             WHERE xx.email_id IS NOT NULL;

        CURSOR submitted_by_cur IS
            SELECT (fu.email_address) email_id
              FROM fnd_user fu
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE));
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Lookup Type:' || pv_lookup_type);
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR recips_rec IN recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    recips_rec.email_id;
            END LOOP;

            --FND_FILE.PUT_LINE(FND_FILE.LOG,'Email Recipents:'||v_def_mail_recips);

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
            fnd_file.put_line (fnd_file.LOG,
                               'Failed to fetch email receipents');
            RETURN v_def_mail_recips;
    END get_email_ids;

    --
    PROCEDURE generate_report_prc
    IS
        CURSOR ar_inb_failed_msgs_cur IS
            SELECT *
              FROM XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T resp
             WHERE 1 = 1 AND resp.request_id = gn_request_id--           AND resp.invoice_type = 'AP_CB'
                                                            ;

        --  AND document_subtype <> 'DELIVERY_SUCCESS';
        --
        ln_rec_fail             NUMBER;
        ln_rec_total            NUMBER;
        ln_rec_success          NUMBER;
        lv_message              VARCHAR2 (32000);
        lv_recipients           VARCHAR2 (4000);
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_exc_file_name        VARCHAR2 (1000);
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_inst_name            VARCHAR2 (30) := NULL;
        lv_msg                  VARCHAR2 (4000) := NULL;
        ln_ret_val              NUMBER := 0;
        lv_out_line             VARCHAR2 (4000);
        lv_error_message        VARCHAR2 (240);
        lv_error_reason         VARCHAR2 (240);
        lv_breif_err_resol      VARCHAR2 (240);
        lv_comments             VARCHAR2 (240);
        ln_counter              NUMBER;
        lv_invoice_type         VARCHAR2 (20);
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T resp
             WHERE resp.request_id = gn_request_id--                AND resp.invoice_type = 'AP_CB'
                                                  ;
        --   AND document_subtype <> 'DELIVERY_SUCCESS'; -- commented as per ramesh testing

        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_total   := 0;
        END;

        IF ln_rec_total <= 0
        THEN
            write_log ('There is nothing to Process...No Errors Exists.');
        ELSE
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

            gv_def_mail_recips   :=
                get_email_ids ('XXD_AP_INV_EMAIL_NOTIF_LKP', lv_inst_name);
            apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers AP Cross Border Invoice Inbound Report ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                 , ln_ret_val);

            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Please see attached Deckers AP Cross Border Invoice Inbound success/failed/error/reject Report.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                'Note: This is auto generated mail, please donot reply.',
                ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_AP_CB_Inv_Report'
                || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
                || '.xls"',
                ln_ret_val);
            -- mail attachement
            apps.do_mail_utils.send_mail_line ('  ', ln_ret_val);
            apps.do_mail_utils.send_mail_line ('Detail Report', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            apps.do_mail_utils.send_mail_line (
                   'SR. NO'
                || CHR (9)
                || 'Invoice Number'
                || CHR (9)
                || 'Invoice Type'
                || CHR (9)
                || 'Customer Number'
                || CHR (9)
                || 'Invoice Date'
                || CHR (9)
                || 'Currency'
                || CHR (9)
                || 'Amount'
                || CHR (9)
                || 'Error Code'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Error Reason'
                || CHR (9)
                || 'Brief Resolution'
                || CHR (9)
                || 'Comments'
                || CHR (9),
                ln_ret_val);
            ln_counter   := 0;

            FOR r_line IN ar_inb_failed_msgs_cur
            LOOP
                ln_counter   := ln_counter + 1;

                BEGIN
                    SELECT ffv.description error_message, attribute1 error_reason, attribute2 breif_error_resolution,
                           attribute3 comments
                      INTO lv_error_message, lv_error_reason, lv_breif_err_resol, lv_comments
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values_vl ffv
                     WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvs.flex_value_set_name =
                               'XXD_AP_INV_ERROR_MESSAGES_VS'
                           AND ffv.enabled_flag = 'Y'--                        AND ffv.flex_value = r_line.document_subtype
                                                     ;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to get the error details ');
                        lv_error_message     := NULL;
                        lv_error_reason      := NULL;
                        lv_breif_err_resol   := NULL;
                        lv_comments          := NULL;
                END;

                -- query to fetch type of transaction

                BEGIN
                    SELECT DECODE (class,  'INV', 'Invoice',  'DM', 'Debit Memo',  'CM', 'Credit Memo',  '')
                      INTO lv_invoice_type
                      FROM ar_payment_schedules_all
                     WHERE 1 = 1--                        customer_trx_id = r_line.invoice_id
                                ;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_invoice_type   := NULL;
                END;
            --                apps.do_mail_utils.send_mail_line(ln_counter
            --                                                  || chr(9)
            ----                                                  || r_line.invoice_number
            --                                                  || chr(9)
            --                                                  || lv_invoice_type
            --                                                  || chr(9)
            --                                                  || r_line.cust_acct_num
            --                                                  || chr(9)
            --                                                  || r_line.invoice_date
            --                                                  || chr(9)
            --                                                  || r_line.invoice_currency_code
            --                                                  || chr(9)
            --                                                  || r_line.h_invoice_total
            --                                                  || chr(9)
            --                                                  || r_line.document_subtype
            --                                                  || chr(9)
            --                                                  || lv_error_message
            --                                                  || chr(9)
            --                                                  || lv_error_reason
            --                                                  || chr(9)
            --                                                  || lv_breif_err_resol
            --                                                  || chr(9)
            --                                                  || lv_comments
            --                                                  || chr(9), ln_ret_val
            --                                                  );

            --apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);

            END LOOP;

            apps.do_mail_utils.send_mail_close (ln_ret_val);
        ----write_log('lvresult is - ' || lv_result);
        --write_log('lv_result_msg is - ' || lv_result_msg);
        END IF;
    END generate_report_prc;

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REGEXP_REPLACE (p_input, '[^ -~]', ''), '$', '')
              INTO lv_output
              FROM DUAL;
        ELSE
            RETURN NULL;
        END IF;

        RETURN lv_output;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END xxd_remove_junk_fnc;

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2, p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                  , p_num_of_columns IN NUMBER)
    IS
        /***************************************************************************
        -- PROCEDURE load_file_into_tbl
        -- PURPOSE: This Procedure read the data from a CSV file.
        -- And load it into the target oracle table.
        -- Finally it renames the source file with date.
        --
        -- P_FILENAME
        -- The name of the flat file(a text file)
        --
        -- P_DIRECTORY
        -- Name of the directory where the file is been placed.
        -- Note: The grant has to be given for the user to the directory
        -- before executing the function
        --
        -- P_IGNORE_HEADERLINES:
        -- Pass the value as '1' to ignore importing headers.
        --
        -- P_DELIMITER
        -- By default the delimiter is used as ','
        -- As we are using CSV file to load the data into oracle
        --
        -- P_OPTIONAL_ENCLOSED
        -- By default the optionally enclosed is used as '"'
        -- As we are using CSV file to load the data into oracle
        --
        **************************************************************************/

        l_input                 UTL_FILE.file_type;
        l_lastline              VARCHAR2 (32767);
        l_cnames                VARCHAR2 (32767);
        l_bindvars              VARCHAR2 (32767);
        l_status                INTEGER;
        l_cnt                   NUMBER DEFAULT 0;
        l_rowcount              NUMBER DEFAULT 0;
        l_sep                   CHAR (1) DEFAULT NULL;
        l_errmsg                VARCHAR2 (32767);
        v_eof                   BOOLEAN := FALSE;
        l_thecursor             NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert                VARCHAR2 (32767);
        lv_arc_dir              VARCHAR2 (100) := 'XXD_PGR_APP_RESP_INB_ARC_DIR';
        ln_req_id               NUMBER;
        lb_wait_req             BOOLEAN;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lv_message              VARCHAR2 (1000);
        lv_inb_directory_path   VARCHAR2 (1000) := NULL;
        lv_arc_directory_path   VARCHAR2 (1000) := NULL;
    BEGIN
        l_cnt        := 1;

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE table_name = p_table AND column_id < p_num_of_columns
                ORDER BY column_id)
        LOOP
            l_cnames   := l_cnames || tab_columns.column_name || ',';

            l_bindvars   :=
                   l_bindvars
                || CASE
                       WHEN tab_columns.data_type IN ('DATE', 'TIMESTAMP(6)')
                       THEN
                           ':b' || l_cnt || ','
                       ELSE
                           ':b' || l_cnt || ','
                   END;


            l_cnt      := l_cnt + 1;
        END LOOP;

        l_cnames     := RTRIM (l_cnames, ',');
        l_bindvars   := RTRIM (l_bindvars, ',');
        write_log ('Count of Columns is - ' || l_cnt);
        l_input      := UTL_FILE.fopen (p_dir, p_filename, 'r');

        IF p_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. p_ignore_headerlines
                LOOP
                    -- DBMS_OUTPUT.put_line ('No of lines Ignored is - ' || i);
                    write_log ('No of lines Ignored is - ' || i);
                    write_log ('P_DIR - ' || p_dir);
                    write_log ('P_FILENAME - ' || p_filename);
                    UTL_FILE.get_line (l_input, l_lastline);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_eof   := TRUE;
                WHEN OTHERS
                THEN
                    write_log (
                           'File Read error due to heading size is huge: - '
                        || SQLERRM);
            END;
        END IF;

        v_insert     :=
               'insert into '
            || p_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        IF NOT v_eof
        THEN
            write_log (
                   l_thecursor
                || '-'
                || 'insert into '
                || p_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')');

            DBMS_SQL.parse (l_thecursor, v_insert, DBMS_SQL.native);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastline);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                IF LENGTH (l_lastline) > 0
                THEN
                    IF (INSTR (l_lastline, ',', 1,
                               1) = 1)
                    THEN
                        l_lastline   := ',' || l_lastline;
                    END IF;

                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        DBMS_SQL.bind_variable (
                            l_thecursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (REPLACE (l_lastline, '||', ','), '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         p_delimiter),
                                                  p_optional_enclosed),
                                           p_delimiter),
                                    p_optional_enclosed)));
                        write_log (
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (REPLACE (l_lastline, '||', ','), '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         p_delimiter),
                                                  p_optional_enclosed),
                                           p_delimiter),
                                    p_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        write_log (' l_thecursor ' || l_thecursor);
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_errmsg   := SQLERRM;
                    END;
                END IF;
            END LOOP;



            -- Derive the directory Path

            BEGIN
                SELECT directory_path
                  INTO lv_inb_directory_path
                  FROM dba_directories
                 WHERE 1 = 1 AND directory_name = 'XXD_GL_LX_REPORTS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_inb_directory_path   := NULL;
            END;

            BEGIN
                SELECT directory_path
                  INTO lv_arc_directory_path
                  FROM dba_directories
                 WHERE     1 = 1
                       AND directory_name = 'XXD_PGR_APP_RESP_INB_ARC_DIR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_arc_directory_path   := NULL;
            END;

            -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
            -- utl_file.fremove(p_dir, p_filename);
            -- Moving the file

            BEGIN
                write_log (
                       'Move files Process Begins...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_CP_MV_RM_FILE',
                        argument1     => 'REMOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                        argument2     => 2,
                        argument3     =>
                            lv_inb_directory_path || '/' || p_filename, -- Source File Directory
                        argument4     => NULL,   -- Destination File Directory
                        start_time    => SYSDATE,
                        sub_request   => FALSE);
                COMMIT;

                IF ln_req_id = 0
                THEN
                    --retcode := 1;
                    write_log (
                        ' Unable to submit move files concurrent program ');
                ELSE
                    write_log (
                        'Move Files concurrent request submitted successfully.');
                    lb_wait_req   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_req_id,
                            INTERVAL     => 5,
                            phase        => lv_phase,
                            status       => lv_status,
                            dev_phase    => lv_dev_phase,
                            dev_status   => lv_dev_status,
                            MESSAGE      => lv_message);

                    IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
                    THEN
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' completed with NORMAL status.');
                    ELSE
                        --retcode := 1;
                        write_log (
                               'Move Files concurrent request with the request id '
                            || ln_req_id
                            || ' did not complete with NORMAL status.');
                    END IF;
                END IF;

                COMMIT;
                write_log (
                       'Move Files Ends...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    --retcode := 2;
                    write_log ('Error in Move Files -' || SQLERRM);
            END;

            DBMS_SQL.close_cursor (l_thecursor);
            UTL_FILE.fclose (l_input);
        END IF;
    END load_file_into_tbl;

    FUNCTION main
        RETURN BOOLEAN
    AS
        CURSOR get_file_cur IS
            SELECT filename
              FROM xxd_dir_list_tbl_syn
             WHERE UPPER (filename) LIKE UPPER ('%FASB%.csv%');

        lv_directory_path   VARCHAR2 (100);
        lv_directory        VARCHAR2 (100);
        lv_file_name        VARCHAR2 (100);
        lv_ret_message      VARCHAR2 (4000) := NULL;
        lv_ret_code         VARCHAR2 (30) := NULL;
        lv_period_name      VARCHAR2 (100);
        ln_file_exists      NUMBER;
        ln_ret_count        NUMBER := 0;
        ln_final_count      NUMBER := 0;
        ln_lia_count        NUMBER := 0;
        lv_vs_file_method   VARCHAR2 (10);
        lv_archive_dir      VARCHAR2 (100);
        ln_req_id           NUMBER;
        lb_wait_req         BOOLEAN;
        lv_phase            VARCHAR2 (100);
        lv_status           VARCHAR2 (30);
        lv_dev_phase        VARCHAR2 (100);
        lv_dev_status       VARCHAR2 (100);
        lv_message          VARCHAR2 (1000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, '------------------------');
        fnd_file.put_line (fnd_file.LOG, 'Program parameters are:');
        fnd_file.put_line (fnd_file.LOG, '------------------------');
        -- fnd_file.put_line(fnd_file.log, 'pn_org_id:' || pn_org_id);
        lv_directory_path   := NULL;
        lv_directory        := NULL;
        ln_file_exists      := 0;

        fnd_file.put_line (fnd_file.LOG,
                           'P_REPORT_PROCESS' || P_REPORT_PROCESS);
        fnd_file.put_line (fnd_file.LOG, 'P_DATE			' || P_DATE);
        fnd_file.put_line (fnd_file.LOG, 'P_CURRENCY		' || P_CURRENCY);
        fnd_file.put_line (fnd_file.LOG, 'P_RATE_TYPE	 ' || P_RATE_TYPE);
        fnd_file.put_line (fnd_file.LOG, 'P_REPROCESS	 ' || P_REPROCESS);

        BEGIN
            fnd_file.put_line (
                fnd_file.LOG,
                'date formate	 ' || TO_DATE (p_date, 'DD-MON-YY'));
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG, 'DATE FORMATE ' || SQLERRM);
        END;

        IF (P_REPORT_PROCESS = 'Process/Report')
        THEN
            -- Derive the directory Path
            BEGIN
                SELECT directory_path
                  INTO lv_directory_path
                  FROM dba_directories
                 WHERE directory_name = 'XXD_GL_LX_REPORTS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_directory_path   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'Directory Path:' || lv_directory_path);
            -- Now Get the file names
            get_file_names (lv_directory_path);

            FOR data IN get_file_cur
            LOOP
                ln_file_exists   := 0;
                fnd_file.put_line (fnd_file.LOG,
                                   'File is availale - ' || data.filename);

                -- Check the file name exists in the table if exists then SKIP
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_file_exists
                      FROM XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_file_exists   := 0;
                END;

                IF (p_reprocess = 'Yes')
                THEN
                    UPDATE XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
                       SET reprocess_flag   = 'Y'
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY'); --TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')

                    ln_file_exists   := 0;
                END IF;

                IF ln_file_exists = 0
                THEN
                    -- loading the data into staging table
                    load_file_into_tbl (p_table => 'XXD_GL_FASB_MIN_LX_OBLIG_T', p_dir => lv_directory_path, p_filename => data.filename, p_ignore_headerlines => 4, p_delimiter => ',', p_optional_enclosed => '"'
                                        , p_num_of_columns => 22);

                    BEGIN
                        UPDATE XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
                           SET file_name          = data.filename,
                               request_id         = gn_request_id,
                               creation_date      = SYSDATE,
                               last_update_date   = SYSDATE,
                               created_by         = gn_user_id,
                               last_updated_by    = gn_user_id,
                               date_parameter     =
                                   TO_DATE (p_date, 'DD-MON-YY'),
                               rate_type          = p_rate_type,
                               rate              =
                                   NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   currency_type
                                               AND conversion_type =
                                                   p_rate_type
                                               AND conversion_date =
                                                   TO_DATE (p_date,
                                                            'DD-MON-YY')
                                               AND gdr.from_currency <> 'USD'
                                               AND gdr.to_currency = 'USD'),
                                       1),
                               year_1             =
                                   REGEXP_REPLACE (year_1, '[^-.[:digit:]]'),
                               year_2             =
                                   REGEXP_REPLACE (year_2, '[^-.[:digit:]]'),
                               year_3             =
                                   REGEXP_REPLACE (year_3, '[^-.[:digit:]]'),
                               year_4             =
                                   REGEXP_REPLACE (year_4, '[^-.[:digit:]]'),
                               year_5             =
                                   REGEXP_REPLACE (year_5, '[^-.[:digit:]]'),
                               year_6_plus       =
                                   REGEXP_REPLACE (year_6_plus,
                                                   '[^-.[:digit:]]'),
                               total_remaining_obligation   =
                                   REGEXP_REPLACE (
                                       total_remaining_obligation,
                                       '[^-.[:digit:]]'),
                               imputed_interest   =
                                   REGEXP_REPLACE (imputed_interest,
                                                   '[^-.[:digit:]]'),
                               lease_liability_rx   =
                                   REGEXP_REPLACE (lease_liability_rx,
                                                   '[^-.[:digit:]]'),
                               prepaid_amount    =
                                   REGEXP_REPLACE (prepaid_amount,
                                                   '[^-.[:digit:]]'),
                               lease_liability_less_prepaid   =
                                   REGEXP_REPLACE (
                                       lease_liability_less_prepaid,
                                       '[^-.[:digit:]]'),
                               precision         =
                                   NVL (
                                       (SELECT precision
                                          FROM fnd_currencies
                                         WHERE currency_code = currency_type),
                                       2),
                               reprocess_flag     = 'N'
                         WHERE     1 = 1
                               AND file_name IS NULL
                               AND request_id IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating the staging table is failed:'
                                || SQLERRM);
                    END;

                    BEGIN
                        UPDATE XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
                           SET usd_year_1 = ROUND (rate * year_1, precision), usd_year_2 = ROUND (rate * year_2, precision), usd_year_3 = ROUND (rate * year_3, precision),
                               usd_year_4 = ROUND (rate * year_4, precision), usd_year_5 = ROUND (rate * year_5, precision), usd_year_6_plus = ROUND (rate * year_6_plus, precision),
                               usd_total_remaining_obligation = ROUND (rate * total_remaining_obligation, precision), usd_imputed_interest = ROUND (rate * imputed_interest, precision), usd_lease_liability_rx = ROUND (rate * lease_liability_rx, precision),
                               usd_prepaid_amount = ROUND (rate * prepaid_amount, precision), usd_lease_liability_less_prepaid = ROUND (rate * lease_liability_less_prepaid, precision)
                         WHERE 1 = 1 AND request_id = gn_request_id;

                        DELETE FROM
                            XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
                              WHERE     (contract_type LIKE '%Contract Total%' OR contract_type LIKE '%Grand Total%' OR accounting_method LIKE 'Operating Total')
                                    AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating USD coulmn values failed'
                                || SQLERRM);
                    END;
                ELSE
                    BEGIN
                        write_log (
                               'Move files Process Begins...'
                            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                        ln_req_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDO',
                                program       => 'XXDO_CP_MV_RM_FILE',
                                argument1     => 'REMOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                                argument2     => 2,
                                argument3     =>
                                    lv_directory_path || '/' || data.filename, -- Source File Directory
                                argument4     => NULL, -- Destination File Directory
                                start_time    => SYSDATE,
                                sub_request   => FALSE);
                        COMMIT;

                        IF ln_req_id = 0
                        THEN
                            --retcode := 1;
                            write_log (
                                ' Unable to submit move files concurrent program ');
                        ELSE
                            write_log (
                                'Move Files concurrent request submitted successfully.');
                            lb_wait_req   :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => ln_req_id,
                                    INTERVAL     => 5,
                                    phase        => lv_phase,
                                    status       => lv_status,
                                    dev_phase    => lv_dev_phase,
                                    dev_status   => lv_dev_status,
                                    MESSAGE      => lv_message);

                            IF     lv_dev_phase = 'COMPLETE'
                               AND lv_dev_status = 'NORMAL'
                            THEN
                                write_log (
                                       'Move Files concurrent request with the request id '
                                    || ln_req_id
                                    || ' completed with NORMAL status.');
                            ELSE
                                --retcode := 1;
                                write_log (
                                       'Move Files concurrent request with the request id '
                                    || ln_req_id
                                    || ' did not complete with NORMAL status.');
                            END IF; -- End of if to check if the status is normal and phase is complete
                        END IF;      -- End of if to check if request ID is 0.

                        COMMIT;
                        write_log (
                               'Move Files Ends...'
                            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            --retcode := 2;
                            write_log ('Error in Move Files -' || SQLERRM);
                    END;
                END IF;
            END LOOP;
        END IF;

        RETURN TRUE;
    --        generate_report_prc;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN FALSE;
    END main;

    FUNCTION get_rate_type_value
        RETURN VARCHAR2
    AS
        lv_rate_type_value   VARCHAR2 (100);
    BEGIN
        SELECT rate_type
          INTO lv_rate_type_value
          FROM (  SELECT rate_type, request_id
                    FROM XXDO.XXD_GL_FASB_MIN_LX_OBLIG_T
                   WHERE     reprocess_flag = 'N'
                         AND date_parameter = TO_DATE (p_date, 'DD-MON-YY')
                         AND request_id =
                             DECODE (p_report_process,
                                     'Report', request_id,
                                     fnd_global.conc_request_id)
                GROUP BY rate_type, request_id
                ORDER BY request_id DESC)
         WHERE ROWNUM = 1;

        RETURN lv_rate_type_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_current_lease_liability
        RETURN VARCHAR2
    AS
        ln_end_bal   VARCHAR2 (100);
    BEGIN
        SELECT SUM (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0)))
          INTO ln_end_bal
          FROM gl_balances gb, gl_ledgers b, gl_code_combinations gcc,
               gl_periods gp
         WHERE     1 = 1
               AND gb.ledger_id = b.ledger_id
               AND b.currency_code = gb.currency_code
               AND (b.ledger_category_code = 'ALC' OR b.ledger_id = 2036)
               AND gcc.segment6 IN
                       (SELECT ffv_minor.flex_value
                          FROM fnd_flex_value_sets ffvs_major, fnd_flex_values ffv_major, fnd_flex_values_tl ffvt_major,
                               fnd_flex_value_sets ffvs_minor, fnd_flex_values ffv_minor, fnd_flex_values_tl ffvt_minor
                         WHERE     ffvs_major.flex_value_set_id =
                                   ffv_major.flex_value_set_id
                               AND ffv_major.flex_value_id =
                                   ffvt_major.flex_value_id
                               AND ffvt_major.language = USERENV ('LANG')
                               AND UPPER (ffvs_major.flex_value_set_name) =
                                   'XXD_GL_LX_REP_ACCOUNT_TYPE_VS'
                               AND ffv_major.ENABLED_FLAG = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               ffv_major.START_DATE_ACTIVE,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               ffv_major.END_DATE_ACTIVE,
                                                               SYSDATE + 1)
                               AND ffvs_major.flex_value_set_id =
                                   ffvs_minor.parent_flex_value_set_id
                               AND ffv_major.flex_value =
                                   'MIN_LEASE_CURR_LEASE_LIAB'
                               AND ffv_major.flex_value =
                                   ffv_minor.parent_flex_value_low
                               AND ffvs_minor.flex_value_set_id =
                                   ffv_minor.flex_value_set_id
                               AND ffv_minor.flex_value_id =
                                   ffvt_minor.flex_value_id
                               AND ffvt_minor.language = USERENV ('LANG')
                               AND ffv_minor.ENABLED_FLAG = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               ffv_minor.START_DATE_ACTIVE,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               ffv_minor.END_DATE_ACTIVE,
                                                               SYSDATE + 1)
                               AND (ffv_minor.flex_value <> 'xxxxx' OR ffv_minor.flex_value <> 'AC_INF'))
               AND gcc.summary_flag = 'N'
               AND gb.period_name = gp.period_name
               AND gcc.code_combination_id = gb.code_combination_id
               AND gp.period_set_name = 'DO_FY_CALENDAR'
               AND p_date BETWEEN start_date AND end_date;

        RETURN (ln_end_bal * -1) / 1000;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_long_term_lease_liability
        RETURN VARCHAR2
    AS
        ln_end_bal   VARCHAR2 (100);
    BEGIN
        SELECT SUM (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0)))
          INTO ln_end_bal
          FROM gl_balances gb, gl_ledgers b, gl_code_combinations gcc,
               gl_periods gp
         WHERE     1 = 1
               AND gb.ledger_id = b.ledger_id
               AND b.currency_code = gb.currency_code
               AND (b.ledger_category_code = 'ALC' OR b.ledger_id = 2036)
               AND gcc.segment6 IN
                       (SELECT ffv_minor.flex_value
                          FROM fnd_flex_value_sets ffvs_major, fnd_flex_values ffv_major, fnd_flex_values_tl ffvt_major,
                               fnd_flex_value_sets ffvs_minor, fnd_flex_values ffv_minor, fnd_flex_values_tl ffvt_minor
                         WHERE     ffvs_major.flex_value_set_id =
                                   ffv_major.flex_value_set_id
                               AND ffv_major.flex_value_id =
                                   ffvt_major.flex_value_id
                               AND ffvt_major.language = USERENV ('LANG')
                               AND UPPER (ffvs_major.flex_value_set_name) =
                                   'XXD_GL_LX_REP_ACCOUNT_TYPE_VS'
                               AND ffv_major.ENABLED_FLAG = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               ffv_major.START_DATE_ACTIVE,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               ffv_major.END_DATE_ACTIVE,
                                                               SYSDATE + 1)
                               AND ffvs_major.flex_value_set_id =
                                   ffvs_minor.parent_flex_value_set_id
                               AND ffv_major.flex_value =
                                   'MIN_LEASE_LONG_TERM_LEASE_LIAB'
                               AND ffv_major.flex_value =
                                   ffv_minor.parent_flex_value_low
                               AND ffvs_minor.flex_value_set_id =
                                   ffv_minor.flex_value_set_id
                               AND ffv_minor.flex_value_id =
                                   ffvt_minor.flex_value_id
                               AND ffvt_minor.language = USERENV ('LANG')
                               AND ffv_minor.ENABLED_FLAG = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               ffv_minor.START_DATE_ACTIVE,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               ffv_minor.END_DATE_ACTIVE,
                                                               SYSDATE + 1)
                               AND (ffv_minor.flex_value <> 'xxxxx' OR ffv_minor.flex_value <> 'AC_INF')--    ORDER BY
                                                                                                        --     ffv_major.flex_value ASC
                                                                                                        )
               AND gcc.summary_flag = 'N'
               AND gb.period_name = gp.period_name
               AND gcc.code_combination_id = gb.code_combination_id
               AND gp.period_set_name = 'DO_FY_CALENDAR'
               AND p_date BETWEEN start_date AND end_date;

        RETURN (ln_end_bal * -1) / 1000;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_summary_report_lease_liability
        RETURN VARCHAR2
    AS
        ln_end_bal   VARCHAR2 (100);
    BEGIN
        SELECT SUM (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0)))
          INTO ln_end_bal
          FROM gl_balances gb, gl_ledgers b, gl_code_combinations gcc,
               gl_periods gp
         WHERE     1 = 1
               AND gb.ledger_id = b.ledger_id
               AND b.currency_code = gb.currency_code
               AND (b.ledger_category_code = 'ALC' OR b.ledger_id = 2036)
               AND gcc.segment6 IN
                       (SELECT ffv_minor.flex_value
                          FROM fnd_flex_value_sets ffvs_major, fnd_flex_values ffv_major, fnd_flex_values_tl ffvt_major,
                               fnd_flex_value_sets ffvs_minor, fnd_flex_values ffv_minor, fnd_flex_values_tl ffvt_minor
                         WHERE     ffvs_major.flex_value_set_id =
                                   ffv_major.flex_value_set_id
                               AND ffv_major.flex_value_id =
                                   ffvt_major.flex_value_id
                               AND ffvt_major.language = USERENV ('LANG')
                               AND UPPER (ffvs_major.flex_value_set_name) =
                                   'XXD_GL_LX_REP_ACCOUNT_TYPE_VS'
                               AND ffv_major.ENABLED_FLAG = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               ffv_major.START_DATE_ACTIVE,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               ffv_major.END_DATE_ACTIVE,
                                                               SYSDATE + 1)
                               AND ffvs_major.flex_value_set_id =
                                   ffvs_minor.parent_flex_value_set_id
                               AND ffv_major.flex_value IN
                                       ('MIN_LEASE_CURR_LEASE_LIAB', 'MIN_LEASE_LONG_TERM_LEASE_LIAB')
                               AND ffv_major.flex_value =
                                   ffv_minor.parent_flex_value_low
                               AND ffvs_minor.flex_value_set_id =
                                   ffv_minor.flex_value_set_id
                               AND ffv_minor.flex_value_id =
                                   ffvt_minor.flex_value_id
                               AND ffv_minor.value_category =
                                   'XXD_GL_LX_REP_ACVAL_D_VS'
                               AND ffv_minor.ENABLED_FLAG = 'Y'
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               ffv_minor.START_DATE_ACTIVE,
                                                               SYSDATE - 1)
                                                       AND NVL (
                                                               ffv_minor.END_DATE_ACTIVE,
                                                               SYSDATE + 1)
                               AND ffvt_minor.language = USERENV ('LANG')
                               AND ffv_minor.attribute1 = 'Y'
                               AND (ffv_minor.flex_value <> 'xxxxx' OR ffv_minor.flex_value <> 'AC_INF'))
               AND gcc.summary_flag = 'N'
               AND gb.period_name = gp.period_name
               AND gcc.code_combination_id = gb.code_combination_id
               AND gp.period_set_name = 'DO_FY_CALENDAR'
               AND p_date BETWEEN start_date AND end_date;

        RETURN (ln_end_bal * -1) / 1000;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;



    FUNCTION get_account_info_msg
        RETURN VARCHAR2
    AS
        lv_msg_val   VARCHAR2 (1000);
    BEGIN
        SELECT DISTINCT REPLACE (ffvt_minor.DESCRIPTION, '/', p_date)
          INTO lv_msg_val
          FROM fnd_flex_value_sets ffvs_major, fnd_flex_values ffv_major, fnd_flex_values_tl ffvt_major,
               fnd_flex_value_sets ffvs_minor, fnd_flex_values ffv_minor, fnd_flex_values_tl ffvt_minor
         WHERE     ffvs_major.flex_value_set_id = ffv_major.flex_value_set_id
               AND ffv_major.flex_value_id = ffvt_major.flex_value_id
               AND ffvt_major.language = USERENV ('LANG')
               AND UPPER (ffvs_major.flex_value_set_name) =
                   'XXD_GL_LX_REP_ACCOUNT_TYPE_VS'
               AND ffv_major.ENABLED_FLAG = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (ffv_major.START_DATE_ACTIVE,
                                                SYSDATE - 1)
                                       AND NVL (ffv_major.END_DATE_ACTIVE,
                                                SYSDATE + 1)
               AND ffvs_major.flex_value_set_id =
                   ffvs_minor.parent_flex_value_set_id
               AND ffv_major.flex_value = 'MIN_LEASE_CURR_LEASE_LIAB'
               AND ffv_minor.ENABLED_FLAG = 'Y'
               AND TRUNC (SYSDATE) BETWEEN NVL (ffv_minor.START_DATE_ACTIVE,
                                                SYSDATE - 1)
                                       AND NVL (ffv_minor.END_DATE_ACTIVE,
                                                SYSDATE + 1)
               AND ffv_major.flex_value = ffv_minor.parent_flex_value_low
               AND ffvs_minor.flex_value_set_id = ffv_minor.flex_value_set_id
               AND ffv_minor.flex_value_id = ffvt_minor.flex_value_id
               AND ffvt_minor.language = USERENV ('LANG')
               AND ffv_minor.flex_value = 'AC_INF';

        RETURN lv_msg_val;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_reprocess_days_control_value
        RETURN NUMBER
    AS
        ln_days_count   NUMBER;
    BEGIN
        SELECT ffvt.description
          INTO ln_days_count
          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
         WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffv.flex_value_id = ffvt.flex_value_id
               AND ffvt.language = USERENV ('LANG')
               AND ffvs.flex_value_set_name = 'XXD_GL_REPROCESS_DAYS_CTRL_VS'
               AND ffv.flex_value =
                   'Deckers LX FASB Min Lease Obligation Program';

        RETURN ln_days_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;
END XXD_GL_LX_REPORTS_PKG;
/
