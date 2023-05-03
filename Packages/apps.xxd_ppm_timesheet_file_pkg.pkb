--
-- XXD_PPM_TIMESHEET_FILE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PPM_TIMESHEET_FILE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PPM_TIMESHEET_FILE_PKG
    * Design       : This package is used for timesheet interface
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 04-Jan-2022  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    gc_dir_name     VARCHAR2 (20) := 'XXD_PPM_IN';
    gc_dir_path     VARCHAR2 (1000);
    gc_recipients   VARCHAR2 (1000);

    -- ===============================================================================
    -- To print debug messages
    -- ===============================================================================
    PROCEDURE msg (p_msg IN VARCHAR2)
    AS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_msg);
        DBMS_OUTPUT.put_line (p_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Exception in MSG: ' || SQLERRM);
    END msg;

    -- ===============================================================================
    -- To send email for all success and error scenarios cases
    -- ===============================================================================
    PROCEDURE send_email (p_subject           IN VARCHAR2,
                          p_message           IN VARCHAR2,
                          p_attachment_file   IN VARCHAR2 DEFAULT NULL)
    AS
        lc_result       VARCHAR2 (2000);
        lc_result_msg   VARCHAR2 (2000);
        lc_db_name      VARCHAR2 (30);
    BEGIN
        -- Derive Instance Name
        BEGIN
            SELECT name INTO lc_db_name FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_db_name   := 'TEST';
        END;

        xxdo_mail_pkg.send_mail (
            pv_sender         => 'erp@deckers.com',
            pv_recipients     => gc_recipients,
            pv_ccrecipients   => NULL,
            pv_subject        => lc_db_name || ' - ' || p_subject,
            pv_message        => p_message,
            pv_attachments    => p_attachment_file,
            xv_result         => lc_result,
            xv_result_msg     => lc_result_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Unable to send email: ' || SQLERRM);
    END send_email;

    -- ===============================================================================
    -- Java Program to get the Filenames
    -- ===============================================================================
    PROCEDURE get_file_names (p_dir_path IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'XXD_UTL_FILE_LIST.getList( java.lang.String )' ;

    -- ===============================================================================
    -- Truncate all Current Tables to start data loading
    -- ===============================================================================
    PROCEDURE truncate_current_tables
    AS
    BEGIN
        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_custom_data_current_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_daily_tr_current_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_ip_user_current_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_resources_current_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_structure_current_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_criteria_current_t';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_ppm_plan_entity_current_t';

        msg ('All Current tables are truncated');
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Unable to truncate current tables: ' || SQLERRM);
    END truncate_current_tables;

    -- ===============================================================================
    -- When data load fails, copy the data into current tables from prior tables
    -- ===============================================================================
    PROCEDURE restore_current_tables
    AS
    BEGIN
        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_custom_data_current_t SELECT * FROM xxdo.xxd_ppm_custom_data_prior_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_daily_tr_current_t SELECT * FROM xxdo.xxd_ppm_daily_tr_prior_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_ip_user_current_t SELECT * FROM xxdo.xxd_ppm_ip_user_prior_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_resources_current_t SELECT * FROM xxdo.xxd_ppm_resources_prior_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_structure_current_t SELECT * FROM xxdo.xxd_ppm_structure_prior_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_criteria_current_t SELECT * FROM xxdo.xxd_ppm_criteria_prior_t';

        EXECUTE IMMEDIATE 'INSERT INTO xxdo.xxd_ppm_plan_entity_current_t SELECT * FROM xxdo.xxd_ppm_plan_entity_prior_t';

        COMMIT;
        msg ('All Current tables has been restored from Prior tables');
    EXCEPTION
        WHEN OTHERS
        THEN
            msg ('Unable to restore current tables: ' || SQLERRM);
    END restore_current_tables;

    -- ===============================================================================
    -- To check if datafiles exists in the source directory
    -- ===============================================================================
    PROCEDURE check_data_file (x_status OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    AS
        CURSOR get_dir_path IS
            SELECT directory_path
              FROM dba_directories
             WHERE directory_name = gc_dir_name;

        lc_err_msg      VARCHAR2 (4000);
        lc_subject      VARCHAR2 (100);
        lc_message      VARCHAR2 (1000);
        lc_dir_path     VARCHAR2 (100);
        ln_file_count   NUMBER;
    BEGIN
        OPEN get_dir_path;

        FETCH get_dir_path INTO gc_dir_path;

        CLOSE get_dir_path;

        get_file_names (p_dir_path => gc_dir_path);

        -- Check if any data file exists in GT
        SELECT COUNT (1) INTO ln_file_count FROM xxd_utl_file_upload_gt;

        msg ('File Count: ' || ln_file_count);

        IF ln_file_count = 0
        THEN
            x_status     := 'E';
            x_err_msg    :=
                'No data file exists in the source path: ' || gc_dir_path;

            lc_subject   := 'Planview Inbound Datafiles - Not Available';
            lc_message   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please note that there are no Planview datafiles available in Oracle Inbound directory to process.'
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN';
            msg (x_err_msg);
        ELSIF ln_file_count < 7
        THEN
            x_status     := 'E';
            x_err_msg    :=
                'Few files missing in the source path: ' || gc_dir_path;
            lc_subject   := 'Planview Inbound Datafiles - Few Files Missing';
            lc_message   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please note that few inbound datafiles are missing in Oracle Inbound directory for processing and the upload process was aborted. '
                || 'Please contact the Admin team. '
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN';
            msg (x_err_msg);
        ELSE
            x_status    := 'S';
            x_err_msg   := NULL;
            -- Truncate Current Tables
            truncate_current_tables ();
        END IF;

        IF x_status <> 'S'
        THEN
            msg ('Error in Check Data File. Sending Email');
            send_email (p_subject => lc_subject, p_message => lc_message);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := SQLERRM;
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
    END check_data_file;

    -- ===============================================================================
    -- Load each datafile into the target table
    -- ===============================================================================
    PROCEDURE load_data (p_table_name IN VARCHAR2, p_filename IN VARCHAR2, p_skip_rows IN NUMBER
                         , p_delimiter IN VARCHAR2 DEFAULT '^', x_file_status OUT VARCHAR2, x_bad_file_name OUT VARCHAR2)
    IS
        l_file_handle        UTL_FILE.file_type;
        l_bad_file_handle    UTL_FILE.file_type;
        l_open_cursor        INTEGER DEFAULT DBMS_SQL.open_cursor;
        lc_buffer            VARCHAR2 (32767);
        lc_lastline          VARCHAR2 (32767);
        lc_header_row        VARCHAR2 (32767);
        lc_separator         VARCHAR2 (1);
        lc_err_msg           VARCHAR2 (4000);
        lc_file_status       VARCHAR2 (1) := 'N';
        lc_bad_file_exists   VARCHAR2 (1) := 'N';
        lc_table_name        VARCHAR2 (100)
                                 := REPLACE (p_table_name, 'XXDO.');
        lc_bad_file_name     VARCHAR2 (100);
        ln_status            NUMBER;
        ln_col_count         NUMBER := 0;
        ln_row_count         NUMBER := 0;
    BEGIN
        l_file_handle   := UTL_FILE.fopen (gc_dir_name, p_filename, 'R');

        lc_buffer       := 'insert into ' || p_table_name || ' values (';

        FOR i IN (  SELECT column_id, data_type
                      FROM all_tab_cols
                     WHERE table_name = lc_table_name
                  ORDER BY column_id)
        LOOP
            ln_col_count   := ln_col_count + 1;
            lc_buffer      :=
                   lc_buffer
                || lc_separator
                || CASE
                       WHEN i.data_type = 'DATE'
                       THEN
                              'TO_DATE (:a'
                           || i.column_id
                           || ', ''DD-MON-YYYY HH24:MI:SS'')'
                       ELSE
                           ':a' || i.column_id
                   END;
            lc_separator   := ',';
        END LOOP;

        lc_buffer       := lc_buffer || ')';

        DBMS_SQL.parse (l_open_cursor, lc_buffer, DBMS_SQL.native);

        --Skip Records
        FOR i IN 1 .. p_skip_rows
        LOOP
            UTL_FILE.get_line (l_file_handle, lc_lastline);
            ln_row_count   := ln_row_count + 1;
        END LOOP;

        -- Loop through each row in the data file
        LOOP
            BEGIN
                UTL_FILE.get_line (l_file_handle, lc_lastline);
                ln_row_count   := ln_row_count + 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    EXIT;
            END;

            lc_buffer   := lc_lastline || p_delimiter;

            FOR i IN 1 .. ln_col_count
            LOOP
                DBMS_SQL.bind_variable (
                    l_open_cursor,
                    ':a' || i,
                    SUBSTR (lc_buffer, 1, INSTR (lc_buffer, p_delimiter) - 1));
                lc_buffer   :=
                    SUBSTR (lc_buffer, INSTR (lc_buffer, p_delimiter) + 1);
            END LOOP;

            BEGIN
                ln_status   := DBMS_SQL.execute (l_open_cursor);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lc_err_msg       := SQLERRM;
                    lc_file_status   := 'Y';
                    -- Create Bad Data file for each datafile
                    lc_bad_file_name   :=
                           SUBSTR (p_filename,
                                   1,
                                   INSTR (p_filename, '.') - 1)
                        || '_ERRORS_'
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY_HH24MI')
                        || '.txt';

                    IF lc_bad_file_exists = 'N'
                    THEN
                        l_bad_file_handle    :=
                            UTL_FILE.fopen (gc_dir_name, lc_bad_file_name, 'W'
                                            , 32767);

                        -- Skip header for CUSTOM_DATA File
                        IF p_skip_rows > 0
                        THEN
                            FOR i
                                IN (SELECT 'ROWNUM' || p_delimiter || LISTAGG (column_name, p_delimiter) WITHIN GROUP (ORDER BY column_id) || p_delimiter || 'ERROR_MESSAGE' header_row
                                      FROM all_tab_cols
                                     WHERE table_name = lc_table_name)
                            LOOP
                                lc_header_row   := i.header_row;
                            END LOOP;
                        END IF;

                        UTL_FILE.put_line (l_bad_file_handle, lc_header_row);
                        lc_bad_file_exists   := 'Y';
                    END IF;

                    IF UTL_FILE.is_open (l_bad_file_handle)
                    THEN
                        UTL_FILE.put_line (l_bad_file_handle,
                                              ln_row_count
                                           || p_delimiter
                                           || REPLACE (lc_lastline, CHR (13))
                                           || p_delimiter
                                           || REGEXP_SUBSTR (lc_err_msg, '[^:]+', 1
                                                             , 2));
                    END IF;
            END;
        END LOOP;

        DBMS_SQL.close_cursor (l_open_cursor);

        IF UTL_FILE.is_open (l_file_handle)
        THEN
            UTL_FILE.fclose (l_file_handle);
        END IF;

        IF UTL_FILE.is_open (l_bad_file_handle)
        THEN
            UTL_FILE.fclose (l_bad_file_handle);
        END IF;

        IF lc_file_status = 'N'
        THEN
            -- To take care of CRLF in Plan Entity Table
            IF p_table_name = 'XXDO.XXD_PPM_PLAN_ENTITY_CURRENT_T'
            THEN
                UPDATE xxdo.xxd_ppm_plan_entity_current_t
                   SET ppl_code   = REPLACE (ppl_code, CHR (13));
            END IF;

            COMMIT;
            x_file_status     := 'S';
            x_bad_file_name   := NULL;
        ELSE
            ROLLBACK;
            x_file_status     := 'E';
            x_bad_file_name   := lc_bad_file_name;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_file_status   := 'E';
            lc_err_msg      := SQLERRM;
            DBMS_OUTPUT.put_line ('Main Exp in Loading: ' || lc_err_msg);
    END load_data;

    -- ===============================================================================
    -- Read each datafile and load into the target table
    -- ===============================================================================
    PROCEDURE load_data_file (x_status OUT VARCHAR2, x_err_msg OUT VARCHAR2)
    AS
        lc_err_msg           VARCHAR2 (4000);
        lc_bad_file_name     VARCHAR2 (4000);
        lc_attachment_file   VARCHAR2 (4000);
        lc_subject           VARCHAR2 (100);
        lc_message           VARCHAR2 (4000);
        lc_file_status       VARCHAR2 (1) := 'S';
        lc_bad_file          VARCHAR2 (1) := 'N';
    BEGIN
        FOR i IN (SELECT DECODE (UPPER (SUBSTR (filename, 1, INSTR (filename, '.') - 1)),  'CUSTOM_DATA', 'XXDO.XXD_PPM_CUSTOM_DATA_CURRENT_T',  'DAILY_TR', 'XXDO.XXD_PPM_DAILY_TR_CURRENT_T',  'IP_USER', 'XXDO.XXD_PPM_IP_USER_CURRENT_T',  'RESOURCES', 'XXDO.XXD_PPM_RESOURCES_CURRENT_T',  'STRUCTURE', 'XXDO.XXD_PPM_STRUCTURE_CURRENT_T',  'CRITERIA', 'XXDO.XXD_PPM_CRITERIA_CURRENT_T',  'PLANNING_ENTITY', 'XXDO.XXD_PPM_PLAN_ENTITY_CURRENT_T') table_name, filename, DECODE (UPPER (SUBSTR (filename, 1, INSTR (filename, '.') - 1)), 'CUSTOM_DATA', 0, 1) skip_rows
                    FROM xxd_utl_file_upload_gt
                   -- Consider only identified filenames and ignore rest
                   WHERE filename IN ('CUSTOM_DATA.CSV', 'DAILY_TR.CSV', 'IP_USER.CSV',
                                      'RESOURCES.CSV', 'STRUCTURE.CSV', 'CRITERIA.CSV',
                                      'PLANNING_ENTITY.CSV'))
        LOOP
            msg ('Loading Data in ' || i.table_name);
            load_data (p_table_name      => i.table_name,
                       p_filename        => i.filename,
                       p_skip_rows       => i.skip_rows,
                       x_file_status     => lc_file_status,
                       x_bad_file_name   => lc_bad_file_name);
            msg ('Loading Status: ' || lc_file_status);

            -- Check file status
            IF lc_file_status <> 'S'
            THEN
                lc_bad_file   := 'Y';
                lc_attachment_file   :=
                       lc_attachment_file
                    || gc_dir_path
                    || '/'
                    || lc_bad_file_name
                    || ',';
            END IF;
        END LOOP;

        IF lc_bad_file = 'Y'
        THEN
            ROLLBACK;
            -- Restore the prior data as current
            restore_current_tables ();
            -- Send Email with Bad Files

            lc_subject   := 'Planview Inbound Files - Error Details';
            lc_message   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please find the attached error log file with appropriate error message for each respective row in the original data file. '
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN';
            send_email (p_subject           => lc_subject,
                        p_message           => lc_message,
                        p_attachment_file   => lc_attachment_file);

            x_status     := 'E';
            x_err_msg    :=
                'One or more file has data corruption. Please refer the error log files. All file uploads were rejected.';
        ELSE
            COMMIT;
            x_status    := 'S';
            x_err_msg   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := SQLERRM;
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
    END load_data_file;

    -- ===============================================================================
    -- Main procedure to call each step to process the data
    -- ===============================================================================
    PROCEDURE process_file (p_recipients   IN     VARCHAR2,
                            x_status          OUT VARCHAR2,
                            x_err_msg         OUT VARCHAR2)
    AS
        lc_status    VARCHAR2 (1);
        lc_err_msg   VARCHAR2 (4000);
    BEGIN
        gc_recipients   := p_recipients;
        -- Check if files exists
        check_data_file (x_status => lc_status, x_err_msg => lc_err_msg);

        msg ('Data File Check Status: ' || lc_status);

        IF lc_status = 'S'
        THEN
            -- Load the data
            load_data_file (x_status => lc_status, x_err_msg => lc_err_msg);

            msg ('Load Data File Status: ' || lc_status);
        END IF;

        IF lc_status <> 'S'
        THEN
            x_status    := 'E';
            x_err_msg   := lc_err_msg;
        ELSE
            x_status    := 'S';
            x_err_msg   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_err_msg   := SQLERRM;
            x_status     := 'E';
            x_err_msg    := lc_err_msg;
    END process_file;
END xxd_ppm_timesheet_file_pkg;
/
