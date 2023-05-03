--
-- XXD_GL_CC_FILE_UPLOAD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_CC_FILE_UPLOAD_PKG"
AS
    /****************************************************************************************
      * Package         : XXD_GL_CC_FILE_UPLOAD_PKG
      * Description     : This package is for Code combination creation through file upload
      * Notes           : Enable\Disable\New Creation of Code combinations
      * Modification    :
      *-------------------------------------------------------------------------------------
      * Date         Version#      Name                       Description
      *-------------------------------------------------------------------------------------
      * 05-May-2022  1.0           Aravind Kannuri            Initial Version for CCR0009744
      *
      ***************************************************************************************/
    --Variables
    gv_def_mail_recips   do_mail_utils.tbl_recips;

    --Get emailids for error report
    FUNCTION get_email_ids (pv_lookup_type VARCHAR2, pv_inst_name VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR lkp_recips_cur IS
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

        CURSOR fu_recips_cur IS
            SELECT (fu.email_address) email_id
              FROM fnd_user fu
             WHERE     1 = 1
                   AND fu.user_id = gn_user_id
                   AND TRUNC (SYSDATE) BETWEEN fu.start_date
                                           AND TRUNC (
                                                   NVL (fu.end_date, SYSDATE));
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Lookup Type for Email Recipents: ' || pv_lookup_type);
        v_def_mail_recips.DELETE;

        IF pv_inst_name = 'PRODUCTION'
        THEN
            FOR lkp_recips_rec IN lkp_recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    lkp_recips_rec.email_id;
            END LOOP;

            RETURN v_def_mail_recips;
        ELSE
            FOR fu_recips_rec IN fu_recips_cur
            LOOP
                v_def_mail_recips (v_def_mail_recips.COUNT + 1)   :=
                    fu_recips_rec.email_id;
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

    --Write Log File
    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msg);
        ELSE
            fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
            DBMS_OUTPUT.put_line (pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (apps.fnd_file.LOG,
                               'Error in write_log Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log Procedure -' || SQLERRM);
    END write_log;

    --Remove Junk Characters
    FUNCTION remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), ''), ',', '')
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
    END remove_junk_fnc;

    --Getting File Names
    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    --Loading Data file into Staging
    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2 DEFAULT 'XXD_GL_CCID_UPLOAD_DIR', p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                  , p_num_of_columns IN NUMBER)
    IS
        l_input       UTL_FILE.file_type;
        l_lastline    VARCHAR2 (4000);
        l_cnames      VARCHAR2 (4000);
        l_bindvars    VARCHAR2 (4000);
        l_status      INTEGER;
        l_cnt         NUMBER DEFAULT 0;
        l_rowcount    NUMBER DEFAULT 0;
        l_sep         CHAR (1) DEFAULT NULL;
        l_errmsg      VARCHAR2 (4000);
        v_eof         BOOLEAN := FALSE;
        l_thecursor   NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert      VARCHAR2 (1100);
    BEGIN
        write_log ('Load Data Process Begins...');
        l_cnt        := 0;

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     1 = 1
                         AND table_name = p_table
                         AND column_id <= p_num_of_columns
                ORDER BY column_id)
        LOOP
            l_cnt      := l_cnt + 1;
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
                    write_log ('No of lines Ignored is - ' || i);
                    UTL_FILE.get_line (l_input, l_lastline);
                END LOOP;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    v_eof   := TRUE;
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
                    FOR i IN 1 .. l_cnt
                    LOOP
                        DBMS_SQL.bind_variable (
                            l_thecursor,
                            ':b' || i,
                            remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         ','),
                                                  p_optional_enclosed),
                                           ','),
                                    p_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_errmsg   := SQLERRM;
                    END;
                END IF;
            END LOOP;

            DBMS_SQL.close_cursor (l_thecursor);
            UTL_FILE.fclose (l_input);

            UPDATE xxdo.xxd_gl_cc_file_upload_t
               SET file_name = p_filename, request_id = gn_request_id, creation_date = SYSDATE,
                   last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                   status = gc_new_status, record_type = 'Source'
             WHERE 1 = 1 AND file_name IS NULL AND request_id IS NULL;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exception in load_file_into_tbl: ' || SQLERRM);
    END load_file_into_tbl;

    --Move File
    PROCEDURE move_file (p_mode     VARCHAR2,
                         p_source   VARCHAR2,
                         p_target   VARCHAR2)
    IS
        ln_req_id        NUMBER;
        lv_phase         VARCHAR2 (100);
        lv_status        VARCHAR2 (30);
        lv_dev_phase     VARCHAR2 (100);
        lv_dev_status    VARCHAR2 (100);
        lb_wait_req      BOOLEAN;
        lv_message       VARCHAR2 (4000);
        l_mode_disable   VARCHAR2 (10);
    BEGIN
        write_log (
               'Move files Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        IF p_mode <> 'REMOVE'
        THEN
            l_mode_disable   := '2';
        END IF;

        ln_req_id   :=
            fnd_request.submit_request (application   => 'XXDO',
                                        program       => 'XXDO_CP_MV_RM_FILE',
                                        argument1     => p_mode,
                                        argument2     => l_mode_disable,
                                        argument3     => p_source,
                                        argument4     => p_target,
                                        start_time    => SYSDATE,
                                        sub_request   => FALSE);
        COMMIT;

        IF ln_req_id > 0
        THEN
            write_log (
                'Move Files concurrent request submitted successfully.');
            lb_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => ln_req_id, interval => 5, phase => lv_phase, status => lv_status, dev_phase => lv_dev_phase, dev_status => lv_dev_status
                                                 , MESSAGE => lv_message);

            IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
            THEN
                write_log (
                       'Move Files concurrent request with the request id '
                    || ln_req_id
                    || ' completed with NORMAL status.');
            ELSE
                write_log (
                       'Move Files concurrent request with the request id '
                    || ln_req_id
                    || ' did not complete with NORMAL status.');
            END IF;
        ELSE
            write_log (' Unable to submit move files concurrent program ');
        END IF;

        COMMIT;
        write_log (
            'Move Files Ends...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in Move Files -' || SQLERRM);
    END move_file;

    --Exception Report
    PROCEDURE generate_exception_report (p_file_name VARCHAR2, p_exc_file_name OUT VARCHAR2, p_mode IN VARCHAR2)
    IS
        CURSOR c_code_comb_enable IS
            SELECT stg.*, DECODE (stg.status, 'S', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_cc_file_upload_t stg
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND UPPER (file_name) = UPPER (p_file_name)
                   AND ((UPPER (p_mode) = 'ENABLE' AND UPPER (file_name) LIKE 'ENABLE%'))
                   AND record_type = 'Source';

        CURSOR c_code_comb_disable IS
            SELECT stg.*, DECODE (stg.status, 'S', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_cc_file_upload_t stg
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND UPPER (file_name) = UPPER (p_file_name)
                   AND ((UPPER (p_mode) = 'DISABLE' AND UPPER (file_name) LIKE 'DISABLE%'))
                   AND record_type = 'Source';

        --variables
        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_line1            VARCHAR2 (32767);
        lv_result           VARCHAR2 (1000);
    BEGIN
        lv_outbound_file   :=
               gn_request_id
            || '_Exception_RPT_'
            || TO_CHAR (SYSDATE, 'RRRR-MON-DD HH24:MI:SS')
            || '.csv';

        write_log ('Exception File Name is - ' || lv_outbound_file);

        -- Derive the directory Path
        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        lv_output_file    :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);                           -- Need to check

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            IF p_mode = 'Enable'
            THEN
                lv_line   :=
                       'File Name'
                    || ','
                    || 'Concatenated Segments'
                    || ','
                    || 'Requested By'
                    || ','
                    || 'Description'
                    || ','
                    || 'Enabled'
                    || ','
                    || 'Status'
                    || ','
                    || 'Error Message';

                lv_line1   :=
                       RPAD ('File Name', 40)
                    || RPAD ('Concatenated Segments', 40)
                    || RPAD ('Requested By', 20)
                    || RPAD ('Description', 30)
                    || RPAD ('Enabled', 10)
                    || RPAD ('Status', 10)
                    || 'Error Message';

                UTL_FILE.put_line (lv_output_file, lv_line);
                fnd_file.put_line (apps.fnd_file.output, lv_line1);

                FOR r_line IN c_code_comb_enable
                LOOP
                    write_log (
                        'r_line.Concatenated_Segments -' || r_line.concatenated_segments);
                    lv_line   :=
                           p_file_name
                        || ','
                        || r_line.concatenated_segments
                        || ','
                        || r_line.requested_by
                        || ','
                        || r_line.description
                        || ','
                        || r_line.enabled_flag
                        || ','
                        || r_line.status_desc
                        || ','
                        || r_line.error_msg;

                    lv_line1   :=
                           RPAD (NVL (p_file_name, 'No File'), 40)
                        || RPAD (
                               NVL (r_line.concatenated_segments, 'No Value'),
                               40)
                        || RPAD (NVL (r_line.requested_by, 'No Value'), 20)
                        || RPAD (NVL (r_line.description, 'No Value'), 30)
                        || RPAD (NVL (r_line.enabled_flag, 'No Value'), 10)
                        || RPAD (NVL (r_line.status_desc, 'No Value'), 10)
                        || NVL (r_line.error_msg, 'No Error');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                    fnd_file.put_line (apps.fnd_file.output, lv_line1);
                END LOOP;
            ELSE
                lv_line   :=
                       'File Name'
                    || ','
                    || 'Concatenated Segments'
                    || ','
                    || 'Requested By'
                    || ','
                    || 'Description'
                    || ','
                    || 'Disabled'
                    || ','
                    || 'Status'
                    || ','
                    || 'Error Message';

                lv_line1   :=
                       RPAD ('File Name', 40)
                    || RPAD ('Concatenated Segments', 40)
                    || RPAD ('Requested By', 20)
                    || RPAD ('Description', 30)
                    || RPAD ('Disabled', 10)
                    || RPAD ('Status', 10)
                    || 'Error Message';

                UTL_FILE.put_line (lv_output_file, lv_line);
                fnd_file.put_line (apps.fnd_file.output, lv_line1);

                FOR r_line IN c_code_comb_disable
                LOOP
                    write_log (
                        'r_line.Concatenated_Segments -' || r_line.concatenated_segments);
                    lv_line   :=
                           p_file_name
                        || ','
                        || r_line.concatenated_segments
                        || ','
                        || r_line.requested_by
                        || ','
                        || r_line.description
                        || ','
                        || r_line.disabled_flag
                        || ','
                        || r_line.status_desc
                        || ','
                        || r_line.error_msg;

                    lv_line1   :=
                           RPAD (NVL (p_file_name, 'No File'), 40)
                        || RPAD (
                               NVL (r_line.concatenated_segments, 'No Value'),
                               40)
                        || RPAD (NVL (r_line.requested_by, 'No Value'), 20)
                        || RPAD (NVL (r_line.description, 'No Value'), 30)
                        || RPAD (NVL (r_line.disabled_flag, 'No Value'), 10)
                        || RPAD (NVL (r_line.status_desc, 'No Value'), 10)
                        || NVL (r_line.error_msg, 'No Error');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                    fnd_file.put_line (apps.fnd_file.output, lv_line1);
                END LOOP;
            END IF;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            RETURN;
        END IF;

        UTL_FILE.fclose (lv_output_file);
        p_exc_file_name   := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report;

    --Generate Summary and Detail Report
    PROCEDURE generate_report (p_file_name IN VARCHAR2, p_mode IN VARCHAR2)
    IS
        CURSOR c_code_comb_enable IS
            SELECT stg.*, DECODE (stg.status, 'S', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_cc_file_upload_t stg
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND UPPER (file_name) = UPPER (p_file_name)
                   AND ((UPPER (p_mode) = 'ENABLE' AND UPPER (file_name) LIKE 'ENABLE%'))
                   AND record_type = 'Source';

        CURSOR c_code_comb_disable IS
            SELECT stg.*, DECODE (stg.status, 'S', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_cc_file_upload_t stg
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND UPPER (file_name) = UPPER (p_file_name)
                   AND ((UPPER (p_mode) = 'DISABLE' AND UPPER (file_name) LIKE 'DISABLE%'))
                   AND record_type = 'Source';

        ln_rec_fail             NUMBER;
        ln_rec_cnt              NUMBER;
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
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_cnt       := 0;
        ln_rec_success   := 0;

        IF p_mode = 'Enable'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_cnt
                  FROM xxdo.xxd_gl_cc_file_upload_t
                 WHERE     request_id = gn_request_id
                       AND UPPER (file_name) = UPPER (p_file_name)
                       AND ((UPPER (p_mode) = 'ENABLE' AND UPPER (file_name) LIKE 'ENABLE%'))
                       AND record_type = 'Source';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_cnt   := 0;
            END;
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_cnt
                  FROM xxdo.xxd_gl_cc_file_upload_t
                 WHERE     request_id = gn_request_id
                       AND UPPER (file_name) = UPPER (p_file_name)
                       AND ((UPPER (p_mode) = 'DISABLE' AND UPPER (file_name) LIKE 'DISABLE%'))
                       AND record_type = 'Source';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_cnt   := 0;
            END;
        END IF;

        IF ln_rec_cnt <= 0
        THEN
            write_log ('There is nothing to Process...No File Exists.');
        ELSE
            IF p_mode = 'Enable'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_rec_success
                      FROM xxdo.xxd_gl_cc_file_upload_t
                     WHERE     request_id = gn_request_id
                           AND ((UPPER (p_mode) = 'ENABLE' AND UPPER (file_name) LIKE 'ENABLE%'))
                           AND status = gc_process_status
                           AND record_type = 'Source';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rec_success   := 0;
                END;
            ELSE
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_rec_success
                      FROM xxdo.xxd_gl_cc_file_upload_t
                     WHERE     request_id = gn_request_id
                           AND ((UPPER (p_mode) = 'DISABLE' AND UPPER (file_name) LIKE 'DISABLE%'))
                           AND status = gc_process_status
                           AND record_type = 'Source';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rec_success   := 0;
                END;
            END IF;

            ln_rec_fail   := ln_rec_cnt - ln_rec_success;
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '              Summary of Deckers GL Code Combination Maintenance ');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                'Date:' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));

            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' File Name                                            - '
                || p_file_name);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Considered                            - '
                || ln_rec_cnt);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Errored                               - '
                || ln_rec_fail);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Successful                            - '
                || ln_rec_success);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '************************************************************************');

            apps.fnd_file.put_line (apps.fnd_file.output, '');
            apps.fnd_file.put_line (apps.fnd_file.output, '');

            IF ln_rec_cnt > 0
            THEN
                generate_exception_report (p_file_name,
                                           lv_exc_file_name,
                                           p_mode);

                BEGIN
                    SELECT directory_path
                      INTO lv_exc_directory_path
                      FROM dba_directories
                     WHERE     1 = 1
                           AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_DIR';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exc_directory_path   := NULL;
                END;

                lv_exc_file_name   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_exc_file_name;

                write_log (lv_exc_file_name);

                lv_message   :=
                       'Summary Report:'
                    || CHR (10)
                    || ' File Name                                            - '
                    || p_file_name
                    || CHR (10)
                    || ' Number of Rows in the File                           - '
                    || ln_rec_cnt
                    || CHR (10)
                    || ' Number of Rows Errored                               - '
                    || ln_rec_fail
                    || CHR (10)
                    || ' Number of Rows Successful                            - '
                    || ln_rec_success
                    || CHR (10);

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
                    get_email_ids ('XXD_GL_CONTROL_EMAILS_LKP', lv_inst_name);

                /* xxdo_mail_pkg.send_mail(pv_sender => 'erp@deckers.com', pv_recipients => gv_def_mail_recips, pv_ccrecipients => NULL,
                 pv_subject => 'Deckers Third Party control maintenance Process Report', pv_message => lv_message, pv_attachments
                 => lv_exc_file_name, xv_result => lv_result, xv_result_msg => lv_result_msg);*/

                apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers GL Code Combination Maintenance Process Report ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                     , ln_ret_val);

                do_mail_utils.send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
                do_mail_utils.send_mail_line (
                    'Please see attached Deckers GL Code Combination Maintenance Process Report.',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                do_mail_utils.send_mail_line (
                    'Note: This is auto generated mail, please donot reply.',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                              ln_ret_val);
                do_mail_utils.send_mail_line (
                       'Content-Disposition: attachment; filename="Deckers_GL_Code_Combination'
                    || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
                    || '.xls"',
                    ln_ret_val);

                apps.do_mail_utils.send_mail_line ('Summary Report',
                                                   ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line (lv_message, ln_ret_val);
                -- mail attachment
                apps.do_mail_utils.send_mail_line ('  ', ln_ret_val);
                apps.do_mail_utils.send_mail_line ('Detail Report',
                                                   ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line (
                       'File Name'
                    || CHR (9)
                    || 'Concatenated Segments'
                    || CHR (9)
                    || 'Requested By'
                    || CHR (9)
                    || 'Description'
                    || CHR (9)
                    || 'Enabled'
                    || CHR (9)
                    || 'Disabled'
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9),
                    ln_ret_val);

                -- apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);

                IF p_mode = 'Enable'
                THEN
                    FOR r_line IN c_code_comb_enable
                    LOOP
                        apps.do_mail_utils.send_mail_line (
                               p_file_name
                            || CHR (9)
                            || r_line.concatenated_segments
                            || CHR (9)
                            || r_line.requested_by
                            || CHR (9)
                            || r_line.description
                            || CHR (9)
                            || r_line.enabled_flag
                            || CHR (9)
                            || r_line.disabled_flag
                            || CHR (9)
                            || r_line.status_desc
                            || CHR (9)
                            || r_line.error_msg
                            || CHR (9),
                            ln_ret_val);
                    --apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);
                    END LOOP;
                ELSE
                    FOR r_line IN c_code_comb_disable
                    LOOP
                        apps.do_mail_utils.send_mail_line (
                               p_file_name
                            || CHR (9)
                            || r_line.concatenated_segments
                            || CHR (9)
                            || r_line.requested_by
                            || CHR (9)
                            || r_line.description
                            || CHR (9)
                            || r_line.enabled_flag
                            || CHR (9)
                            || r_line.disabled_flag
                            || CHR (9)
                            || r_line.status_desc
                            || CHR (9)
                            || r_line.error_msg
                            || CHR (9),
                            ln_ret_val);
                    -- apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);
                    END LOOP;
                END IF;

                apps.do_mail_utils.send_mail_close (ln_ret_val);
                write_log ('lv_result is - ' || lv_result);
                write_log ('lv_result_msg is - ' || lv_result_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('EXP- ' || SQLCODE || ' ' || SQLERRM);
    END generate_report;

    --Create New Code Combination
    PROCEDURE create_code_combination (pv_cc_segments IN VARCHAR2, xn_ccid OUT NUMBER, xv_code OUT VARCHAR2
                                       , xv_err_msg OUT VARCHAR2)
    IS
        ln_ccid              gl_code_combinations_kfv.code_combination_id%TYPE;
        lv_enabled_flag      gl_code_combinations_kfv.enabled_flag%TYPE;
        ln_structure_num     fnd_id_flex_structures.id_flex_num%TYPE;
        lv_ledger_name       gl_ledgers.name%TYPE;
        lv_cc_segments       gl_code_combinations_kfv.concatenated_segments%TYPE;
        lv_cc_seg1           gl_code_combinations_kfv.segment1%TYPE := NULL;
        lv_cc_seg2           gl_code_combinations_kfv.segment2%TYPE := NULL;
        lv_cc_seg3           gl_code_combinations_kfv.segment3%TYPE := NULL;
        lv_cc_seg4           gl_code_combinations_kfv.segment4%TYPE := NULL;
        lv_cc_seg5           gl_code_combinations_kfv.segment5%TYPE := NULL;
        lv_cc_seg6           gl_code_combinations_kfv.segment6%TYPE := NULL;
        lv_cc_seg7           gl_code_combinations_kfv.segment7%TYPE := NULL;
        lv_cc_seg8           gl_code_combinations_kfv.segment8%TYPE := NULL;
        lv_err_code          VARCHAR2 (100) := NULL;
        lv_err_msg           VARCHAR2 (2000) := NULL;
        lv_buf               VARCHAR2 (200);

        ln_new_ccid          NUMBER (10);                -- New combination_id
        lb_cr_combination    BOOLEAN;               -- API New Creation Return
        ld_validation_date   DATE := TO_DATE ('01-APR-2000', 'DD-MON-YYYY'); -- Validation Date
        ln_num_segments      NUMBER (10) := 8;           -- Number of segments
        lv_array_segments    fnd_flex_ext.segmentarray;       -- Segment array
    BEGIN
        --Assign variables
        lv_cc_segments   := LTRIM (RTRIM (pv_cc_segments));
        ln_new_ccid      := NULL;
        lv_err_code      := NULL;
        lv_err_msg       := NULL;

        -- Get chart_of_accounts_id\structure_num
        BEGIN
            SELECT id_flex_num
              INTO ln_structure_num
              FROM apps.fnd_id_flex_structures
             WHERE     id_flex_code = 'GL#'
                   AND id_flex_structure_code = 'DO_ACCOUNTING_FLEXFIELD';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_structure_num   := NULL;
        END;

        --CC Segments Bifurcation
        IF lv_cc_segments IS NOT NULL
        THEN
            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  1) VALUE
              INTO lv_cc_seg1
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  2) VALUE
              INTO lv_cc_seg2
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  3) VALUE
              INTO lv_cc_seg3
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  4) VALUE
              INTO lv_cc_seg4
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  5) VALUE
              INTO lv_cc_seg5
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  6) VALUE
              INTO lv_cc_seg6
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  7) VALUE
              INTO lv_cc_seg7
              FROM DUAL;

            SELECT REGEXP_SUBSTR (lv_cc_segments, '[^.]+', 1,
                                  8) VALUE
              INTO lv_cc_seg8
              FROM DUAL;
        END IF;

        -- Check if code combination exists
        BEGIN
            SELECT code_combination_id, enabled_flag
              INTO ln_ccid, lv_enabled_flag
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = lv_cc_segments;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ccid           := NULL;
                lv_enabled_flag   := NULL;
        END;

        IF ln_ccid IS NOT NULL
        THEN
            IF NVL (lv_enabled_flag, 'N') = 'Y'
            THEN
                write_log (
                       'Code combination already exists in Enable mode => '
                    || ln_ccid);
                lv_err_code   := 'CCID_ALREADY_EXISTS';
                lv_err_msg    :=
                    'Code combination already exists in Enable mode';
            ELSE
                write_log (
                    'Code combination Enabled Successfully =>' || ln_ccid);

                --Enabling code combination (No API Exists as per SR 3-29144661151, Direct update)
                BEGIN
                    UPDATE gl_code_combinations gcc
                       SET enabled_flag = 'Y', preserve_flag = NULL, last_update_date = SYSDATE,
                           last_updated_by = gn_user_id
                     WHERE     1 = 1
                           AND chart_of_accounts_id = ln_structure_num
                           AND code_combination_id = ln_ccid;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_err_msg   := 'CCID_ENABLE_ERROR';
                        write_log ('EXP- ' || SQLCODE || ' ' || SQLERRM);
                END;

                COMMIT;

                IF NVL (lv_err_msg, 'NA') <> 'CCID_ENABLE_ERROR'
                THEN
                    lv_err_code   := 'CCID_ENABLE_SUCCESS';
                    lv_err_msg    := 'Code combination Enabled Successfully';
                END IF;
            END IF;
        ELSE
            write_log ('Generation of New Code Combination..');
            lv_array_segments (1)   := lv_cc_seg1;
            lv_array_segments (2)   := lv_cc_seg2;
            lv_array_segments (3)   := lv_cc_seg3;
            lv_array_segments (4)   := lv_cc_seg4;
            lv_array_segments (5)   := lv_cc_seg5;
            lv_array_segments (6)   := lv_cc_seg6;
            lv_array_segments (7)   := lv_cc_seg7;
            lv_array_segments (8)   := lv_cc_seg8;

            -- Create a new combination using parameter of segments
            lb_cr_combination       :=
                fnd_flex_ext.get_comb_id_allow_insert (
                    application_short_name   => 'SQLGL',
                    key_flex_code            => 'GL#',
                    structure_number         => ln_structure_num,
                    validation_date          => ld_validation_date,
                    n_segments               => ln_num_segments,
                    segments                 => lv_array_segments,
                    combination_id           => ln_new_ccid);

            IF lb_cr_combination = TRUE
            THEN
                lv_buf        := lv_array_segments (1);

                FOR n IN 2 .. lv_array_segments.COUNT
                LOOP
                    lv_buf   := lv_buf || '.' || lv_array_segments (n);
                END LOOP;

                write_log ('New Code Combination : ' || lv_buf);
                write_log ('New code_combination_id : ' || ln_new_ccid);
                lv_err_code   := 'CCID_CREATION_SUCCESS';
                lv_err_msg    := 'Successfully created New Code Combination';
            ELSE
                write_log ('New Code combination Creation Failure ');
                lv_err_code   := 'CCID_CREATION_ERROR';
                lv_err_msg    := 'New Code combination Creation Failure';
            END IF;
        END IF;                                       --IF ln_ccid IS NOT NULL

        IF lv_err_msg IS NOT NULL
        THEN
            xv_err_msg   := lv_err_msg;
        ELSE
            xv_err_msg   := NULL;
        END IF;

        xn_ccid          := ln_new_ccid;
        xv_code          := lv_err_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            xn_ccid      := NULL;
            xv_code      := 'EXP_CCID_CR_ENABLE_FAILED';
            xv_err_msg   := 'EXP- ' || SQLCODE || ' ' || SQLERRM;
            write_log ('xv_err_msg :' || xv_err_msg);
    END create_code_combination;

    --DISABLE Code Combination Id
    PROCEDURE disable_code_combination (pv_cc_segments IN VARCHAR2, pv_preserve_flag IN VARCHAR2, xv_code OUT VARCHAR2
                                        , xv_err_msg OUT VARCHAR2)
    IS
        ln_ccid            gl_code_combinations_kfv.code_combination_id%TYPE;
        lv_enabled_flag    gl_code_combinations_kfv.enabled_flag%TYPE;
        ln_structure_num   fnd_id_flex_structures.id_flex_num%TYPE;
        lv_cc_segments     gl_code_combinations_kfv.concatenated_segments%TYPE;
        lv_err_code        VARCHAR2 (100) := NULL;
        lv_err_msg         VARCHAR2 (2000) := NULL;
    BEGIN
        lv_cc_segments     := LTRIM (RTRIM (pv_cc_segments));
        ln_ccid            := NULL;
        ln_structure_num   := NULL;

        -- Get chart_of_accounts_id\structure_num
        BEGIN
            SELECT id_flex_num
              INTO ln_structure_num
              FROM apps.fnd_id_flex_structures
             WHERE     id_flex_code = 'GL#'
                   AND id_flex_structure_code = 'DO_ACCOUNTING_FLEXFIELD';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_structure_num   := NULL;
        END;

        -- Get code combination
        BEGIN
            SELECT code_combination_id, enabled_flag
              INTO ln_ccid, lv_enabled_flag
              FROM gl_code_combinations_kfv
             WHERE concatenated_segments = lv_cc_segments;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ccid           := NULL;
                lv_enabled_flag   := NULL;
        END;

        IF ln_ccid IS NOT NULL
        THEN
            IF NVL (lv_enabled_flag, 'N') = 'N'
            THEN
                write_log (
                       'Code combination already exists in Disable Mode => '
                    || ln_ccid);
                lv_err_code   := 'CCID_ALREADY_DISABLE';
                lv_err_msg    :=
                    'Code combination already exists in Disable Mode';
            ELSE
                write_log (
                    'Code combination Disabled Successfully =>' || ln_ccid);

                --Disabling Code combination(No API Exists as per SR 3-29144661151, Direct update)
                IF NVL (pv_preserve_flag, 'X') = 'Y'
                THEN
                    BEGIN
                        UPDATE gl_code_combinations gcc
                           SET enabled_flag = 'N', preserve_flag = 'Y', last_update_date = SYSDATE,
                               last_updated_by = gn_user_id
                         WHERE     1 = 1
                               AND chart_of_accounts_id = ln_structure_num
                               AND code_combination_id = ln_ccid;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   := 'CCID_DISABLE_ERROR';
                            DBMS_OUTPUT.put_line (
                                'EXP- ' || SQLCODE || ' ' || SQLERRM);
                    END;
                ELSIF NVL (pv_preserve_flag, 'X') = 'N'
                THEN
                    BEGIN
                        UPDATE gl_code_combinations gcc
                           SET enabled_flag = 'N', preserve_flag = NULL, last_update_date = SYSDATE,
                               last_updated_by = gn_user_id
                         WHERE     1 = 1
                               AND chart_of_accounts_id = ln_structure_num
                               AND code_combination_id = ln_ccid;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   := 'CCID_DISABLE_ERROR';
                            DBMS_OUTPUT.put_line (
                                'EXP- ' || SQLCODE || ' ' || SQLERRM);
                    END;
                ELSE
                    BEGIN
                        UPDATE gl_code_combinations gcc
                           SET enabled_flag = 'N', preserve_flag = NULL, last_update_date = SYSDATE,
                               last_updated_by = gn_user_id
                         WHERE     1 = 1
                               AND chart_of_accounts_id = ln_structure_num
                               AND code_combination_id = ln_ccid;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_err_msg   := 'CCID_DISABLE_ERROR';
                            DBMS_OUTPUT.put_line (
                                'EXP- ' || SQLCODE || ' ' || SQLERRM);
                    END;
                END IF;

                IF (NVL (lv_err_msg, 'NA') <> 'CCID_DISABLE_ERROR')
                THEN
                    lv_err_code   := 'CCID_DISABLE_SUCCESS';
                    lv_err_msg    := 'Code combination Disabled Successfully';
                END IF;
            END IF;
        ELSE
            write_log ('Code combination not exists to Disable');
            lv_err_code   := 'CCID_NOT_EXISTS_TO_DISABLE';
            lv_err_msg    := 'Code combination not exists to Disable';
        END IF;

        COMMIT;
        xv_code            := lv_err_code;

        IF lv_err_msg IS NOT NULL
        THEN
            xv_err_msg   := lv_err_msg;
        ELSE
            xv_err_msg   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_code   := 'EXP_CCID_CR';
            xv_code       := 'EXP_CCID_DISABLE_FAILED';
            xv_err_msg    := 'EXP- ' || SQLCODE || ' ' || SQLERRM;
            write_log ('xv_err_msg :' || xv_err_msg);
    END disable_code_combination;

    --Update staging with CCID details
    PROCEDURE validate_data (p_file_name IN VARCHAR2, p_mode IN VARCHAR2, p_preserved IN VARCHAR2
                             , xv_ret_message OUT VARCHAR2)
    IS
        ln_ccid             NUMBER;
        xn_ccid             NUMBER;
        xv_code             VARCHAR2 (100);
        lv_preserved_flag   VARCHAR2 (10);
        lv_ret_status       VARCHAR2 (10);
        lv_ret_msg          VARCHAR2 (2000);
        xv_ret_msg          VARCHAR2 (2000);

        CURSOR c_get_data IS
            SELECT ROWID, concatenated_segments, enabled_flag,
                   disabled_flag, preserved_flag
              FROM xxdo.xxd_gl_cc_file_upload_t
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND status = gc_new_status
                   AND ((UPPER (p_mode) = 'ENABLE' AND UPPER (file_name) LIKE 'ENABLE%') OR (UPPER (p_mode) = 'DISABLE' AND UPPER (file_name) LIKE 'DISABLE%'));
    BEGIN
        --Update Enabled_flag with Input data in Stg
        UPDATE xxdo.xxd_gl_cc_file_upload_t
           SET enabled_flag   = enable_disable
         WHERE     1 = 1
               AND request_id = gn_request_id
               AND status = gc_new_status
               AND (UPPER (p_mode) = 'ENABLE' AND UPPER (file_name) LIKE 'ENABLE%');

        --Update Disabled_flag with Input data in Stg
        UPDATE xxdo.xxd_gl_cc_file_upload_t
           SET disabled_flag   = enable_disable
         WHERE     1 = 1
               AND request_id = gn_request_id
               AND status = gc_new_status
               AND (UPPER (p_mode) = 'DISABLE' AND UPPER (file_name) LIKE 'DISABLE%');

        COMMIT;

        write_log (
            '****Code Combination Process (NEW\ENABLE\DISABLE) Start****');

        FOR i IN c_get_data
        LOOP
            IF (UPPER (p_mode) = 'ENABLE' AND NVL (i.enabled_flag, 'Y') = 'Y')
            THEN
                --Calling Creation Code Combination procedure
                create_code_combination (pv_cc_segments => i.concatenated_segments, xn_ccid => xn_ccid, xv_code => xv_code
                                         , xv_err_msg => xv_ret_msg);

                IF xv_code = 'CCID_ALREADY_EXISTS'
                THEN
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_error_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                ELSIF (xv_code = 'CCID_CREATION_SUCCESS' OR xv_code = 'CCID_ENABLE_SUCCESS')
                THEN
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_process_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                ELSIF (xv_code = 'CCID_CREATION_ERROR' OR xv_code = 'CCID_ENABLE_ERROR' OR xv_code = 'EXP_CCID_CR_ENABLE_FAILED')
                THEN
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_error_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                ELSE
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_new_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                END IF;
            ELSIF (UPPER (p_mode) = 'DISABLE' AND NVL (i.disabled_flag, 'Y') = 'Y')
            THEN
                --Validate preserved_flag
                IF p_preserved = 'Yes'
                THEN
                    lv_preserved_flag   := 'Y';
                ELSIF p_preserved = 'No'
                THEN
                    lv_preserved_flag   := 'N';
                ELSE
                    lv_preserved_flag   := 'X';
                END IF;

                --Calling Disable Code Combination procedure
                disable_code_combination (pv_cc_segments => i.concatenated_segments, pv_preserve_flag => NVL (i.preserved_flag, lv_preserved_flag), xv_code => xv_code
                                          , xv_err_msg => xv_ret_msg);

                IF xv_code = 'CCID_ALREADY_DISABLE'
                THEN
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_error_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                ELSIF xv_code = 'CCID_DISABLE_SUCCESS'
                THEN
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_process_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                ELSIF (xv_code = 'CCID_DISABLE_ERROR' OR xv_code = 'CCID_NOT_EXISTS_TO_DISABLE' OR xv_code = 'EXP_CCID_DISABLE_FAILED')
                THEN
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_error_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                ELSE
                    UPDATE xxdo.xxd_gl_cc_file_upload_t
                       SET ccid = xn_ccid, ERROR_CODE = xv_code, status = gc_new_status,
                           error_msg = xv_ret_msg, last_update_date = gd_date, last_updated_by = gn_last_updated_by
                     WHERE     ROWID = i.ROWID
                           AND concatenated_segments =
                               i.concatenated_segments
                           AND request_id = gn_request_id;
                END IF;
            END IF;                        --IF nvl(i.enabled_flag, 'Y') = 'Y'
        END LOOP;

        write_log (
            '****Code Combination Process (NEW\ENABLE\DISABLE) End****');
        COMMIT;
        lv_ret_msg       := NULL;
        xv_ret_message   := lv_ret_msg;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exp - validate_data procedure :' || SQLERRM);
            lv_ret_msg       := 'Exp - validate_data procedure :' || SQLERRM;
            xv_ret_message   := lv_ret_msg;
    END validate_data;

    --Main Procedure
    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_mode IN VARCHAR2
                    , p_cc_hide_dummy IN VARCHAR2, p_preserved IN VARCHAR2)
    IS
        l_exception             EXCEPTION;
        lv_message              VARCHAR2 (4000);
        lv_inbound_dir_path     VARCHAR2 (1000);
        lv_arc_dir_path         VARCHAR2 (1000);
        lv_exc_directory_path   VARCHAR2 (1000);
        ln_file_exists          NUMBER;
        lv_file_name            VARCHAR2 (1000);
        ln_record_count         NUMBER := 0;

        CURSOR get_file_cur IS
              SELECT DISTINCT filename
                FROM xxd_dir_list_tbl_syn
               WHERE     1 = 1
                     AND ((UPPER (p_mode) = 'ENABLE' AND UPPER (filename) LIKE 'ENABLE%') OR (UPPER (p_mode) = 'DISABLE' AND UPPER (filename) LIKE 'DISABLE%'))
                     AND UPPER (filename) NOT LIKE 'ARCHIVE'
            ORDER BY filename;
    BEGIN
        write_log ('Start main-');
        write_log ('Program Parameters are');
        write_log ('=======================');
        write_log ('p_mode:' || p_mode);
        write_log ('p_preserved :' || p_preserved);

        -- Derive the directory Path
        BEGIN
            lv_inbound_dir_path   := NULL;

            SELECT directory_path
              INTO lv_inbound_dir_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inbound_dir_path   := NULL;
                lv_message            :=
                       'Exception Occurred while retriving the Inbound Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_arc_dir_path   := NULL;

            SELECT directory_path
              INTO lv_arc_dir_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_CCID_UPLOAD_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_dir_path   := NULL;
                lv_message        :=
                       'Exception Occurred while retriving the Archive Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        write_log ('Start Processing the file from server');

        IF p_mode = 'Enable'
        THEN
            write_log ('Mode: Enable');
            get_file_names (lv_inbound_dir_path);
            fnd_file.put_line (fnd_file.LOG, 'in get_file_names');
            ln_record_count   := 0;

            FOR data IN get_file_cur
            LOOP
                ln_file_exists    := 0;
                ln_record_count   := ln_record_count + 1;
                lv_file_name      := NULL;
                lv_file_name      := data.filename;
                write_log (' File is available - ' || lv_file_name);

                load_file_into_tbl (p_table => 'XXD_GL_CC_FILE_UPLOAD_T', p_dir => 'XXD_GL_CCID_UPLOAD_DIR', p_filename => lv_file_name, p_ignore_headerlines => 1, p_delimiter => ',', p_optional_enclosed => '"'
                                    , p_num_of_columns => 5);


                move_file (
                    p_mode     => 'MOVE',
                    p_source   => lv_inbound_dir_path || '/' || lv_file_name,
                    p_target   =>
                           lv_arc_dir_path
                        || '/'
                        || g_time_statmp
                        || '_'
                        || lv_file_name);

                lv_message        := NULL;

                validate_data (lv_file_name, p_mode, p_preserved,
                               lv_message);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                generate_report (lv_file_name, p_mode);
            END LOOP;

            IF ln_record_count = 0
            THEN
                write_log (' No File is available - ');
            END IF;
        ELSE
            write_log ('Mode: Disable');
            get_file_names (lv_inbound_dir_path);
            fnd_file.put_line (fnd_file.LOG, 'in get_file_names');
            ln_record_count   := 0;

            FOR data IN get_file_cur
            LOOP
                ln_file_exists    := 0;
                ln_record_count   := ln_record_count + 1;
                lv_file_name      := NULL;
                lv_file_name      := data.filename;
                write_log (' File is available - ' || lv_file_name);

                load_file_into_tbl (p_table => 'XXD_GL_CC_FILE_UPLOAD_T', p_dir => 'XXD_GL_CCID_UPLOAD_DIR', p_filename => lv_file_name, p_ignore_headerlines => 1, p_delimiter => ',', p_optional_enclosed => '"'
                                    , p_num_of_columns => 5);


                move_file (
                    p_mode     => 'MOVE',
                    p_source   => lv_inbound_dir_path || '/' || lv_file_name,
                    p_target   =>
                           lv_arc_dir_path
                        || '/'
                        || g_time_statmp
                        || '_'
                        || lv_file_name);

                lv_message        := NULL;

                validate_data (lv_file_name, p_mode, p_preserved,
                               lv_message);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                generate_report (lv_file_name, p_mode);
            END LOOP;

            IF ln_record_count = 0
            THEN
                write_log (' No File is available - ');
            END IF;
        END IF;                                            --p_mode = 'Enable'
    EXCEPTION
        WHEN l_exception
        THEN
            write_log (lv_message);
        WHEN OTHERS
        THEN
            write_log ('Exp- Error in main-' || SQLERRM);
    END;
END XXD_GL_CC_FILE_UPLOAD_PKG;
/
