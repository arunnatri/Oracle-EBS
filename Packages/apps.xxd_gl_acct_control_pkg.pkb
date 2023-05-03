--
-- XXD_GL_ACCT_CONTROL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_ACCT_CONTROL_PKG"
AS
    /******************************************************************************************
    NAME           : XXD_GL_ACCT_CONTROL_PKG
    REPORT NAME    : Deckers GL Third Party Control maintainance

    REVISIONS:
    Date            Author                  Version     Description
    ----------      ----------              -------     ---------------------------------------------------
    30-DEC-2021     Laltu Sah                 1.0         Deckers GL Third Party Control maintainance
 13-Feb-2021     Showkath Ali              1.1         QA/UAT Defect - New Changes
    *********************************************************************************************/

    gv_def_mail_recips   do_mail_utils.tbl_recips;

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

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
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
                'Error in write_log_prc Procedure -' || SQLERRM);
            DBMS_OUTPUT.put_line (
                'Error in write_log_prc Procedure -' || SQLERRM);
    END write_log_prc;

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'XXD_UTL_FILE_LIST.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl_prc (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_GL_ACCT_CONTROL_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT ',', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                      , pv_num_of_columns IN NUMBER)
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
        write_log_prc ('Load Data Process Begins...');
        l_cnt        := 0;

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     1 = 1
                         AND table_name = pv_table
                         AND column_id <= pv_num_of_columns
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
        write_log_prc ('Count of Columns is - ' || l_cnt);
        l_input      := UTL_FILE.fopen (pv_dir, pv_filename, 'r');

        IF pv_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. pv_ignore_headerlines
                LOOP
                    write_log_prc ('No of lines Ignored is - ' || i);
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
            || pv_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        IF NOT v_eof
        THEN
            write_log_prc (
                   l_thecursor
                || '-'
                || 'insert into '
                || pv_table
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
                                                  pv_optional_enclosed),
                                           ','),
                                    pv_optional_enclosed)));
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

            UPDATE xxdo.xxd_gl_acct_control_stg_t
               SET file_name = pv_filename, request_id = gn_request_id, creation_date = SYSDATE,
                   last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                   status = 'N', record_type = 'Source'
             WHERE 1 = 1 AND file_name IS NULL AND request_id IS NULL;

            COMMIT;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Exception in load_file_into_tbl_prc: ' || SQLERRM);
    END load_file_into_tbl_prc;

    PROCEDURE move_file (p_mode     VARCHAR2,
                         p_source   VARCHAR2,
                         p_target   VARCHAR2)
    AS
        ln_req_id        NUMBER;
        lv_phase         VARCHAR2 (100);
        lv_status        VARCHAR2 (30);
        lv_dev_phase     VARCHAR2 (100);
        lv_dev_status    VARCHAR2 (100);
        lb_wait_req      BOOLEAN;
        lv_message       VARCHAR2 (4000);
        l_mode_disable   VARCHAR2 (10);
    BEGIN
        write_log_prc (
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
            write_log_prc (
                'Move Files concurrent request submitted successfully.');
            lb_wait_req   :=
                fnd_concurrent.wait_for_request (request_id => ln_req_id, INTERVAL => 5, phase => lv_phase, status => lv_status, dev_phase => lv_dev_phase, dev_status => lv_dev_status
                                                 , MESSAGE => lv_message);

            IF lv_dev_phase = 'COMPLETE' AND lv_dev_status = 'NORMAL'
            THEN
                write_log_prc (
                       'Move Files concurrent request with the request id '
                    || ln_req_id
                    || ' completed with NORMAL status.');
            ELSE
                write_log_prc (
                       'Move Files concurrent request with the request id '
                    || ln_req_id
                    || ' did not complete with NORMAL status.');
            END IF;
        ELSE
            write_log_prc (
                ' Unable to submit move files concurrent program ');
        END IF;

        COMMIT;
        write_log_prc (
            'Move Files Ends...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Error in Move Files -' || SQLERRM);
    END move_file;

    PROCEDURE validate_data (pv_file_name VARCHAR2, p_timing NUMBER, x_ret_msg OUT VARCHAR2
                             , p_control IN VARCHAR2)
    IS
        ln_flex_value_id     NUMBER;
        l_status             VARCHAR2 (10);
        l_err_msg            VARCHAR2 (2000);
        lv_control_seg       VARCHAR2 (100);
        ln_natural_account   NUMBER;
        ln_dup_count         NUMBER := 0;

        CURSOR c_acct_control_cur IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_acct_control_stg_t stg
             WHERE     request_id = gn_request_id
                   AND status = 'N'
                   AND UPPER (file_name) = UPPER (pv_file_name)
                   AND UPPER (file_name) LIKE 'THIRD%PARTY%';

        CURSOR c_acct_uncontrol_cur IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_acct_control_stg_t stg
             WHERE     1 = 1
                   AND ((SYSDATE - stg.creation_date) * 60 * 24) >= p_timing
                   AND NVL (status, 'N') = 'N'
                   AND record_type = 'Backup';
    BEGIN
        BEGIN
            UPDATE xxdo.xxd_gl_acct_control_stg_t stg
               SET status = gc_error_status, error_msg = 'Record already Updated within last ' || p_timing || ' Minutes' || ' - '
             WHERE     request_id = gn_request_id
                   AND status = 'N'
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_flex_values_vl ffvl, fnd_flex_value_sets ffvs
                             WHERE     ffvs.flex_value_set_name =
                                       'DO_GL_ACCOUNT'
                                   AND ffvs.flex_value_set_id =
                                       ffvl.flex_value_set_id
                                   AND ffvl.flex_value = stg.natural_acct
                                   AND ((NVL (p_timing, 0) <> 0 AND ffvl.last_update_date >= SYSDATE - p_timing / (24 * 60)) OR (NVL (p_timing, 0) = 0 AND 1 = 2)));
        END;

        IF p_control = 'Update'
        THEN
            FOR c_acct_rec IN c_acct_control_cur
            LOOP
                l_status         := gc_process_status;
                l_err_msg        := NULL;
                lv_control_seg   := NULL;

                -- fetch the data from value set to create backup record in custom table
                BEGIN
                    SELECT ffvl.flex_value_id,
                           SUBSTR (compiled_value_attributes,
                                     (INSTR (compiled_value_attributes, CHR (10), 1
                                             , 3))
                                   + 1,
                                   1),
                           ffvl.flex_value
                      INTO ln_flex_value_id, lv_control_seg, ln_natural_account
                      FROM fnd_flex_values_vl ffvl, fnd_flex_value_sets ffvs
                     WHERE     ffvs.flex_value_set_name = 'DO_GL_ACCOUNT'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvl.flex_value = c_acct_rec.natural_acct;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_flex_value_id   := 0;
                END;

                IF ln_flex_value_id <= 0
                THEN
                    l_status   := gc_error_status;
                    l_err_msg   :=
                        l_err_msg || 'Natural Account is not Valid' || ' - ';
                END IF;

                IF NVL (c_acct_rec.controlled, 'Z') NOT IN ('Y', 'C', 'N',
                                                            'R', 'S')
                THEN
                    l_status   := gc_error_status;
                    l_err_msg   :=
                           l_err_msg
                        || 'Control flag should be Y,C,N,R,S'
                        || ' - ';
                END IF;

                -- query to check the duplicate in file

                ln_dup_count     := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_dup_count
                      FROM xxdo.xxd_gl_acct_control_stg_t
                     WHERE     natural_acct = ln_natural_account
                           AND request_id = gn_request_id
                           AND record_type = 'Backup';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_dup_count   := 0;
                END;

                IF     NVL (ln_dup_count, 0) > 0
                   AND NVL (ln_flex_value_id, 0) > 0
                THEN
                    l_status    := gc_error_status;
                    l_err_msg   := l_err_msg || 'Duplicate Record' || ' - ';
                END IF;

                /* IF lv_control_seg = 'Y' THEN
                     l_status := gc_error_status;
                     l_err_msg := l_err_msg
                                  || 'Natural account is already controlled'
                                  || ' - ';
                 END IF;*/

                IF l_status = gc_process_status
                THEN
                    -- Insert the values in custom table.
                    BEGIN
                        INSERT INTO xxdo.xxd_gl_acct_control_stg_t
                             VALUES (ln_natural_account, c_acct_rec.requested_by, c_acct_rec.description, lv_control_seg, gn_request_id, c_acct_rec.file_name, 'N', NULL, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                     , 'Backup', NULL);

                        COMMIT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               ' Capturing backup is Successfull for the account:'
                            || ln_flex_value_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to insert the backup data into custom table:'
                                || SQLERRM);
                    END;

                    -- Update the values

                    UPDATE fnd_flex_values
                       SET last_update_date   =
                               NVL (c_acct_rec.last_update_date, SYSDATE),
                           compiled_value_attributes   =
                                  SUBSTR (compiled_value_attributes,
                                          1,
                                          (INSTR (compiled_value_attributes, CHR (10), 1
                                                  , 3)))
                               || c_acct_rec.controlled
                               || SUBSTR (compiled_value_attributes,
                                            (INSTR (compiled_value_attributes, CHR (10), 1
                                                    , 3))
                                          + 2,
                                          LENGTH (compiled_value_attributes)),
                           last_updated_by   = gn_user_id
                     WHERE flex_value_id = ln_flex_value_id;

                    UPDATE xxdo.xxd_gl_acct_control_stg_t
                       SET status = gc_process_status, error_msg = NULL
                     WHERE     request_id = gn_request_id
                           AND ROWID = c_acct_rec.ROWID;
                ELSE
                    UPDATE xxdo.xxd_gl_acct_control_stg_t
                       SET status = l_status, error_msg = l_err_msg
                     WHERE     request_id = gn_request_id
                           AND ROWID = c_acct_rec.ROWID;
                END IF;

                COMMIT;
            END LOOP;
        ELSE                                              -- p_mode = 'Revert'
            FOR c_acct_rec IN c_acct_uncontrol_cur
            LOOP
                l_status         := gc_process_status;
                l_err_msg        := NULL;
                lv_control_seg   := NULL;

                BEGIN
                    SELECT ffvl.flex_value_id,
                           SUBSTR (compiled_value_attributes,
                                     (INSTR (compiled_value_attributes, CHR (10), 1
                                             , 3))
                                   + 1,
                                   1)
                      INTO ln_flex_value_id, lv_control_seg
                      FROM fnd_flex_values_vl ffvl, fnd_flex_value_sets ffvs
                     WHERE     ffvs.flex_value_set_name = 'DO_GL_ACCOUNT'
                           AND ffvs.flex_value_set_id =
                               ffvl.flex_value_set_id
                           AND ffvl.flex_value = c_acct_rec.natural_acct;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_flex_value_id   := 0;
                END;

                IF ln_flex_value_id <= 0
                THEN
                    l_status   := gc_error_status;
                    l_err_msg   :=
                        l_err_msg || 'Natural Account is not Valid' || ' - ';
                END IF;

                IF l_status = gc_process_status
                THEN
                    UPDATE fnd_flex_values
                       SET last_update_date   =
                               NVL (c_acct_rec.last_update_date, SYSDATE),
                           compiled_value_attributes   =
                                  SUBSTR (compiled_value_attributes,
                                          1,
                                          (INSTR (compiled_value_attributes, CHR (10), 1
                                                  , 3)))
                               || (c_acct_rec.controlled)
                               || SUBSTR (compiled_value_attributes,
                                            (INSTR (compiled_value_attributes, CHR (10), 1
                                                    , 3))
                                          + 2,
                                          LENGTH (compiled_value_attributes)),
                           last_updated_by   = gn_user_id
                     WHERE flex_value_id = ln_flex_value_id;

                    UPDATE xxdo.xxd_gl_acct_control_stg_t
                       SET status = gc_process_status, error_msg = NULL, uncont_request_id = gn_request_id
                     WHERE status = 'N' AND ROWID = c_acct_rec.ROWID;
                ELSE
                    UPDATE xxdo.xxd_gl_acct_control_stg_t
                       SET status = l_status, error_msg = l_err_msg, uncont_request_id = gn_request_id
                     WHERE status = 'N' AND ROWID = c_acct_rec.ROWID;
                END IF;

                COMMIT;
            END LOOP;
        END IF;                                        -- IF P_mode = 'Update'

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (SQLERRM || 'validate_data');
            x_ret_msg   := 'validate_data-' || SQLERRM;
    END validate_data;

    PROCEDURE generate_exception_report_prc (pv_file_name VARCHAR2, pv_exc_file_name OUT VARCHAR2, pv_control IN VARCHAR2)
    IS
        CURSOR c_line_control IS
            SELECT stg.*, DECODE (stg.status, 'P', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_acct_control_stg_t stg
             WHERE request_id = gn_request_id AND record_type = 'Source';

        CURSOR c_line_uncontrol IS
            SELECT stg.*, DECODE (stg.status, 'P', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_acct_control_stg_t stg
             WHERE     uncont_request_id = gn_request_id
                   AND record_type = 'Backup';

        --DEFINE VARIABLES

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

        write_log_prc ('Exception File Name is - ' || lv_outbound_file);

        -- Derive the directory Path
        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        lv_output_file     :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                    ,
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'File Name'
                || ','
                || 'Natural Account'
                || ','
                || 'Requested By'
                || ','
                || 'Description'
                || ','
                || 'Controlled'
                || ','
                || 'Status'
                || ','
                || 'Error Message';

            lv_line1   :=
                   RPAD ('File Name', 30)
                || RPAD ('Natural Account', 20)
                || RPAD ('Requested By', 20)
                || RPAD ('Description', 15)
                || RPAD ('Controlled', 15)
                || RPAD ('Status', 10)
                || 'Error Message';

            UTL_FILE.put_line (lv_output_file, lv_line);
            apps.fnd_file.put_line (apps.fnd_file.output, lv_line1);

            IF pv_control = 'Update'
            THEN
                FOR r_line IN c_line_control
                LOOP
                    write_log_prc (
                        'r_line.NATURAL_ACCT-' || r_line.natural_acct);
                    lv_line   :=
                           pv_file_name
                        || ','
                        || r_line.natural_acct
                        || ','
                        || r_line.requested_by
                        || ','
                        || r_line.description
                        || ','
                        || r_line.controlled
                        || ','
                        || r_line.status_desc
                        || ','
                        || r_line.error_msg;

                    lv_line1   :=
                           RPAD (NVL (pv_file_name, 'No File'), 30)
                        || RPAD (NVL (r_line.natural_acct, 'No Value'), 20)
                        || RPAD (NVL (r_line.requested_by, 'No Value'), 20)
                        || RPAD (NVL (r_line.description, 'No Value'), 15)
                        || RPAD (NVL (r_line.controlled, 'No Value'), 15)
                        || RPAD (NVL (r_line.status_desc, 'No Value'), 10)
                        || NVL (r_line.error_msg, 'No Error');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                    apps.fnd_file.put_line (apps.fnd_file.output, lv_line1);
                END LOOP;
            ELSE
                FOR r_line IN c_line_uncontrol
                LOOP
                    write_log_prc (
                        'r_line.NATURAL_ACCT-' || r_line.natural_acct);
                    lv_line   :=
                           pv_file_name
                        || ','
                        || r_line.natural_acct
                        || ','
                        || r_line.requested_by
                        || ','
                        || r_line.description
                        || ','
                        || r_line.controlled
                        || ','
                        || r_line.status_desc
                        || ','
                        || r_line.error_msg;

                    lv_line1   :=
                           RPAD (NVL (pv_file_name, 'No File'), 30)
                        || RPAD (r_line.natural_acct, 20)
                        || RPAD (r_line.requested_by, 20)
                        || RPAD (r_line.description, 15)
                        || RPAD (r_line.controlled, 15)
                        || RPAD (r_line.status_desc, 10)
                        || NVL (r_line.error_msg, 'No Error');

                    UTL_FILE.put_line (lv_output_file, lv_line);
                    apps.fnd_file.put_line (apps.fnd_file.output, lv_line1);
                END LOOP;
            END IF;
        ELSE
            lv_err_msg   :=
                SUBSTR (
                       'Error in Opening the data file for writing. Error is : '
                    || SQLERRM,
                    1,
                    2000);
            write_log_prc (lv_err_msg);
            RETURN;
        END IF;

        --END IF;

        UTL_FILE.fclose (lv_output_file);
        pv_exc_file_name   := lv_outbound_file;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log_prc (lv_err_msg);
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
            write_log_prc (lv_err_msg);
            raise_application_error (-20109, lv_err_msg);
    END generate_exception_report_prc;

    PROCEDURE generate_report_prc (pv_file_name   IN VARCHAR2,
                                   pv_control     IN VARCHAR2--p_recipients   IN   VARCHAR2
                                                             )
    IS
        CURSOR c_line_control IS
            SELECT stg.*, DECODE (stg.status, 'P', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_acct_control_stg_t stg
             WHERE request_id = gn_request_id AND record_type = 'Source';

        CURSOR c_line_uncontrol IS
            SELECT stg.*, DECODE (stg.status, 'P', 'Success', 'Error') status_desc
              FROM xxdo.xxd_gl_acct_control_stg_t stg
             WHERE     uncont_request_id = gn_request_id
                   AND record_type = 'Backup';

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
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;

        IF pv_control = 'Update'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_total
                  FROM xxdo.xxd_gl_acct_control_stg_t
                 WHERE     request_id = gn_request_id
                       AND UPPER (file_name) = UPPER (pv_file_name)
                       AND record_type = 'Source';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_total   := 0;
            END;
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_total
                  FROM xxdo.xxd_gl_acct_control_stg_t
                 WHERE     uncont_request_id = gn_request_id
                       AND record_type = 'Backup';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_total   := 0;
            END;
        END IF;

        IF ln_rec_total <= 0
        THEN
            write_log_prc ('There is nothing to Process...No File Exists.');
        ELSE
            IF pv_control = 'Update'
            THEN
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_rec_success
                      FROM xxdo.xxd_gl_acct_control_stg_t
                     WHERE     request_id = gn_request_id
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
                      FROM xxdo.xxd_gl_acct_control_stg_t
                     WHERE     uncont_request_id = gn_request_id
                           AND status = gc_process_status
                           AND record_type = 'Backup';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_rec_success   := 0;
                END;
            END IF;

            ln_rec_fail   := ln_rec_total - ln_rec_success;
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '              Summary of Deckers Third Party control maintenance ');
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
                || pv_file_name);
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   ' Number of Rows Considered into Inbound Staging Table - '
                || ln_rec_total);
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

            IF ln_rec_total > 0
            THEN
                generate_exception_report_prc (pv_file_name,
                                               lv_exc_file_name,
                                               pv_control);

                BEGIN
                    SELECT directory_path
                      INTO lv_exc_directory_path
                      FROM dba_directories
                     WHERE     1 = 1
                           AND directory_name LIKE
                                   'XXD_GL_ACCT_CONTROL_EXC_DIR';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_exc_directory_path   := NULL;
                END;

                lv_exc_file_name   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_exc_file_name;
                write_log_prc (lv_exc_file_name);
                lv_message   :=
                       'Summary Report:'
                    || CHR (10)
                    || ' File Name                                            - '
                    || pv_file_name
                    || CHR (10)
                    || ' Number of Rows in the File                           - '
                    || ln_rec_total
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
                apps.do_mail_utils.send_mail_header ('erp@deckers.com', gv_def_mail_recips, 'Deckers Third Party control maintenance Process Report ' || ' Email generated from ' || lv_inst_name || ' instance'
                                                     , ln_ret_val);

                do_mail_utils.send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                do_mail_utils.send_mail_line ('Hello Team', ln_ret_val);
                do_mail_utils.send_mail_line (
                    'Please see attached Deckers Third Party control maintenance Process Report.',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                do_mail_utils.send_mail_line (
                    'Note: This is auto generated mail, please donot reply.',
                    ln_ret_val);
                do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
                do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                              ln_ret_val);
                do_mail_utils.send_mail_line (
                       'Content-Disposition: attachment; filename="Deckers_control_uncontrol_'
                    || TO_CHAR (SYSDATE, 'RRRRMMDD_HH24MISS')
                    || '.xls"',
                    ln_ret_val);

                apps.do_mail_utils.send_mail_line ('Summary Report',
                                                   ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line (lv_message, ln_ret_val);
                -- mail attachement
                apps.do_mail_utils.send_mail_line ('  ', ln_ret_val);
                apps.do_mail_utils.send_mail_line ('Detail Report',
                                                   ln_ret_val);
                do_mail_utils.send_mail_line ('', ln_ret_val);
                apps.do_mail_utils.send_mail_line (
                       'File Name'
                    || CHR (9)
                    || 'Natural Account'
                    || CHR (9)
                    || 'Requested By'
                    || CHR (9)
                    || 'Description'
                    || CHR (9)
                    || 'Controlled'
                    || CHR (9)
                    || 'Status'
                    || CHR (9)
                    || 'Error Message'
                    || CHR (9),
                    ln_ret_val);

                -- apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);

                IF pv_control = 'Update'
                THEN
                    FOR r_line IN c_line_control
                    LOOP
                        apps.do_mail_utils.send_mail_line (
                               pv_file_name
                            || CHR (9)
                            || r_line.natural_acct
                            || CHR (9)
                            || r_line.requested_by
                            || CHR (9)
                            || r_line.description
                            || CHR (9)
                            || r_line.controlled
                            || CHR (9)
                            || r_line.status_desc
                            || CHR (9)
                            || r_line.error_msg
                            || CHR (9),
                            ln_ret_val);
                    --apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);
                    END LOOP;
                ELSE
                    FOR r_line IN c_line_uncontrol
                    LOOP
                        apps.do_mail_utils.send_mail_line (
                               pv_file_name
                            || CHR (9)
                            || r_line.natural_acct
                            || CHR (9)
                            || r_line.requested_by
                            || CHR (9)
                            || r_line.description
                            || CHR (9)
                            || r_line.controlled
                            || CHR (9)
                            || r_line.status_desc
                            || CHR (9)
                            || r_line.error_msg
                            || CHR (9),
                            ln_ret_val);
                    -- apps.do_mail_utils.send_mail_line(lv_out_line, lv_message);
                    END LOOP;
                END IF;

                --

                apps.do_mail_utils.send_mail_close (ln_ret_val);
                write_log_prc ('lvresult is - ' || lv_result);
                write_log_prc ('lv_result_msg is - ' || lv_result_msg);
            END IF;
        END IF;
    END generate_report_prc;

    PROCEDURE main_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_control VARCHAR2
                        , p_timing NUMBER)
    IS
        l_exception             EXCEPTION;
        lv_message              VARCHAR2 (4000);
        lv_inb_directory_path   VARCHAR2 (1000);
        lv_arc_directory_path   VARCHAR2 (1000);
        lv_exc_directory_path   VARCHAR2 (1000);
        ln_file_exists          NUMBER;
        lv_file_name            VARCHAR2 (1000);
        ln_record_count         NUMBER := 0;

        CURSOR get_file_cur IS
              SELECT filename
                FROM xxd_utl_file_upload_gt
               WHERE 1 = 1 AND UPPER (filename) LIKE 'THIRD%PARTY%'
            ORDER BY filename;
    BEGIN
        write_log_prc ('Start main_prc-');
        write_log_prc ('Program Parameters are');
        write_log_prc ('=======================');
        write_log_prc ('p_control:' || p_control);
        write_log_prc ('p_timing :' || p_timing);

        -- Derive the directory Path
        BEGIN
            lv_inb_directory_path   := NULL;

            SELECT directory_path
              INTO lv_inb_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inb_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Inbound Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_arc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Archive Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Exception Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        write_log_prc ('Start Processing the file from server');

        IF p_control = 'Update'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'in update');
            get_file_names (lv_inb_directory_path);
            fnd_file.put_line (fnd_file.LOG, 'in get_file_names');
            ln_record_count   := 0;

            FOR data IN get_file_cur
            LOOP
                ln_file_exists    := 0;
                ln_record_count   := ln_record_count + 1;
                lv_file_name      := NULL;
                lv_file_name      := data.filename;
                write_log_prc (' File is available - ' || lv_file_name);
                load_file_into_tbl_prc (pv_table => 'XXD_GL_ACCT_CONTROL_STG_T', pv_dir => 'XXD_GL_ACCT_CONTROL_INB_DIR', pv_filename => lv_file_name, pv_ignore_headerlines => 1, pv_delimiter => ',', pv_optional_enclosed => '"'
                                        , pv_num_of_columns => 4);

                move_file (
                    p_mode     => 'MOVE',
                    p_source   => lv_inb_directory_path || '/' || lv_file_name,
                    p_target   =>
                           lv_arc_directory_path
                        || '/'
                        || g_time_statmp
                        || '_'
                        || lv_file_name);

                lv_message        := NULL;
                validate_data (lv_file_name, p_timing, lv_message,
                               p_control);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                --IF p_email_id IS NOT NULL THEN
                generate_report_prc (lv_file_name, p_control);
            --END IF;
            END LOOP;

            IF ln_record_count = 0
            THEN
                write_log_prc (' No File is available - ');
            END IF;
        ELSE
            validate_data (lv_file_name, p_timing, lv_message,
                           p_control);

            IF lv_message IS NOT NULL
            THEN
                RAISE l_exception;
            END IF;

            --IF p_email_id IS NOT NULL THEN
            generate_report_prc (lv_file_name, p_control);
        END IF;
    EXCEPTION
        WHEN l_exception
        THEN
            write_log_prc (lv_message);
        WHEN OTHERS
        THEN
            write_log_prc ('Error in main_prc-' || SQLERRM);
    END;

    PROCEDURE main_prc_unc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_control VARCHAR2
                            , p_timing NUMBER)
    IS
        l_exception             EXCEPTION;
        lv_message              VARCHAR2 (4000);
        lv_inb_directory_path   VARCHAR2 (1000);
        lv_arc_directory_path   VARCHAR2 (1000);
        lv_exc_directory_path   VARCHAR2 (1000);
        ln_file_exists          NUMBER;
        lv_file_name            VARCHAR2 (1000);
        ln_record_count         NUMBER := 0;

        CURSOR get_file_cur IS
              SELECT filename
                FROM xxd_utl_file_upload_gt
               WHERE 1 = 1 AND UPPER (filename) LIKE 'THIRD%PARTY%'
            ORDER BY filename;
    BEGIN
        write_log_prc ('Start main_prc-');
        write_log_prc ('Program Parameters are');
        write_log_prc ('=======================');
        write_log_prc ('p_control:' || p_control);
        write_log_prc ('p_timing :' || p_timing);

        -- Derive the directory Path
        BEGIN
            lv_inb_directory_path   := NULL;

            SELECT directory_path
              INTO lv_inb_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inb_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Inbound Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_arc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Archive Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE     1 = 1
                   AND directory_name LIKE 'XXD_GL_ACCT_CONTROL_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Exception Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        write_log_prc ('Start Processing the file from server');

        IF p_control = 'Update'
        THEN
            get_file_names (lv_inb_directory_path);
            ln_record_count   := 0;

            FOR data IN get_file_cur
            LOOP
                ln_file_exists    := 0;
                ln_record_count   := ln_record_count + 1;
                lv_file_name      := NULL;
                lv_file_name      := data.filename;
                write_log_prc (' File is available - ' || lv_file_name);
                load_file_into_tbl_prc (pv_table => 'XXD_GL_ACCT_CONTROL_STG_T', pv_dir => 'XXD_GL_ACCT_CONTROL_INB_DIR', pv_filename => lv_file_name, pv_ignore_headerlines => 1, pv_delimiter => ',', pv_optional_enclosed => '"'
                                        , pv_num_of_columns => 4);

                move_file (
                    p_mode     => 'MOVE',
                    p_source   => lv_inb_directory_path || '/' || lv_file_name,
                    p_target   =>
                           lv_arc_directory_path
                        || '/'
                        || g_time_statmp
                        || '_'
                        || lv_file_name);

                lv_message        := NULL;
                validate_data (lv_file_name, p_timing, lv_message,
                               p_control);

                IF lv_message IS NOT NULL
                THEN
                    RAISE l_exception;
                END IF;

                --IF p_email_id IS NOT NULL THEN
                generate_report_prc (lv_file_name, p_control);
            --END IF;
            END LOOP;

            IF ln_record_count = 0
            THEN
                write_log_prc (' No File is available - ');
            END IF;
        ELSE
            validate_data (lv_file_name, p_timing, lv_message,
                           p_control);

            IF lv_message IS NOT NULL
            THEN
                RAISE l_exception;
            END IF;

            --IF p_email_id IS NOT NULL THEN
            generate_report_prc (lv_file_name, p_control);
        END IF;
    EXCEPTION
        WHEN l_exception
        THEN
            write_log_prc (lv_message);
        WHEN OTHERS
        THEN
            write_log_prc ('Error in main_prc-' || SQLERRM);
    END;
END xxd_gl_acct_control_pkg;
/
