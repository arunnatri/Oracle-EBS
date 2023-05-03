--
-- XXD_GL_LX_WHT_AVG_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_LX_WHT_AVG_PKG"
AS
    /***************************************************************************************
    * Program Name : XXD_GL_LX_WHT_AVG_PKG                                                 *
    * Language     : PL/SQL                                                                *
    * Description  : Package used to import the data and process the Weighted Average Report*
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Balavenu Rao         1.0       Initial Version                         21-Mar-2022   *
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
                    END LOOP;

                    BEGIN
                        write_log (' l_thecursor ' || l_thecursor);
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                    --      EXIT WHEN l_rowcount=1;
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
                    END IF; -- End of if to check if the status is normal and phase is complete
                END IF;              -- End of if to check if request ID is 0.

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
    -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
    -- utl_file.fremove(p_dir, p_filename);
    --dbms_sql.close_cursor(l_thecursor);
    --utl_file.fclose(l_input);
    -- END IF;

    END load_file_into_tbl;

    PROCEDURE load_summary_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2, p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
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
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_thecursor);
                        l_rowcount   := l_rowcount + 1;
                        EXIT WHEN l_rowcount = 1;
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

            DBMS_SQL.close_cursor (l_thecursor);
            UTL_FILE.fclose (l_input);
        END IF;
    -- copyfile_prc(p_filename, SYSDATE || p_filename, p_dir, lv_arc_dir);
    -- utl_file.fremove(p_dir, p_filename);
    --dbms_sql.close_cursor(l_thecursor);
    --utl_file.fclose(l_input);
    -- END IF;

    END load_summary_file_into_tbl;

    FUNCTION main
        RETURN BOOLEAN
    AS
        CURSOR get_file_cur IS
            SELECT filename
              FROM xxd_dir_list_tbl_syn
             WHERE filename LIKE '%WEIGHT%%LEASE%.csv%';

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
        --        fnd_file.put_line(fnd_file.log, 'P_RATE_TYPE  '  ||P_RATE_TYPE   );
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
                      FROM xxdo.XXD_GL_LX_WHT_AVG_T
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_file_exists   := 0;
                END;

                IF (p_reprocess = 'Yes')
                THEN
                    UPDATE xxdo.XXD_GL_LX_WHT_AVG_T
                       SET reprocess_flag   = 'Y'
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY'); --TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')

                    UPDATE xxdo.XXD_GL_LX_WHT_AVG_SUMRY_T
                       SET reprocess_flag   = 'Y'
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY'); --TO_DATE (p_date, 'YYYY/MM/DD HH24:MI:SS')

                    ln_file_exists   := 0;
                END IF;

                IF ln_file_exists = 0
                THEN
                    -- loading the data into staging table
                    load_summary_file_into_tbl (p_table => 'XXD_GL_LX_WHT_AVG_SUMRY_T', p_dir => lv_directory_path, p_filename => data.filename, p_ignore_headerlines => 10, p_delimiter => ',', p_optional_enclosed => '"'
                                                , p_num_of_columns => 7);
                    load_file_into_tbl (p_table => 'XXD_GL_LX_WHT_AVG_T', p_dir => lv_directory_path, p_filename => data.filename, p_ignore_headerlines => 13, p_delimiter => ',', p_optional_enclosed => '"'
                                        , p_num_of_columns => 43);

                    BEGIN
                        UPDATE xxdo.XXD_GL_LX_WHT_AVG_T
                           SET file_name          = data.filename,
                               request_id         = gn_request_id,
                               creation_date      = SYSDATE,
                               last_update_date   = SYSDATE,
                               created_by         = gn_user_id,
                               last_updated_by    = gn_user_id,
                               date_parameter     =
                                   TO_DATE (p_date, 'DD-MON-YY'),
                               REMAIN_LIKELY_DAYS   =
                                   REGEXP_REPLACE (REMAIN_LIKELY_DAYS,
                                                   '[^-.[:digit:]]'),
                               PRE_AMOUNT        =
                                   REGEXP_REPLACE (PRE_AMOUNT,
                                                   '[^-.[:digit:]]'),
                               CURNT_PERIOD_LIABILITY_BALAN   =
                                   REGEXP_REPLACE (
                                       CURNT_PERIOD_LIABILITY_BALAN,
                                       '[^-.[:digit:]]'),
                               CURNT_PERIOD_LIABILITY_BALAN_LES_PRE   =
                                   REGEXP_REPLACE (
                                       CURNT_PERIOD_LIABILITY_BALAN_LES_PRE,
                                       '[^-.[:digit:]]'),
                               CURNT_PERIOD_ASSET_BALAN   =
                                   REGEXP_REPLACE (CURNT_PERIOD_ASSET_BALAN,
                                                   '[^-.[:digit:]]'),
                               CURNT_REMAIN_BALAN_LEASE_PAY   =
                                   REGEXP_REPLACE (
                                       CURNT_REMAIN_BALAN_LEASE_PAY,
                                       '[^-.[:digit:]]'),
                               CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE   =
                                   REGEXP_REPLACE (
                                       CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE,
                                       '[^-.[:digit:]]'),
                               DISCOUNT_RATE     =
                                   REGEXP_REPLACE (DISCOUNT_RATE,
                                                   '[^-.[:digit:]]'),
                               INITIAL_ASSET_BALANCE   =
                                   REGEXP_REPLACE (INITIAL_ASSET_BALANCE,
                                                   '[^-.[:digit:]]'),
                               INITIAL_LIABILITY_BALANCE   =
                                   REGEXP_REPLACE (INITIAL_LIABILITY_BALANCE,
                                                   '[^-.[:digit:]]'),
                               WEIGHTED_REMAINING_PAYMENT   =
                                   REGEXP_REPLACE (
                                       WEIGHTED_REMAINING_PAYMENT,
                                       '[^-.[:digit:]]'),
                               WEIGHTED_REMAINING_LEASE_TERM   =
                                   REGEXP_REPLACE (
                                       WEIGHTED_REMAINING_LEASE_TERM,
                                       '[^-.[:digit:]]'),
                               rate_type          = p_rate_type,
                               balan_rate        =
                                   NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   CONTRACT_CURRENCY_TYPE
                                               AND conversion_type =
                                                   p_rate_type
                                               AND conversion_date =
                                                   TO_DATE (p_date,
                                                            'DD-MON-YY')
                                               AND gdr.from_currency <> 'USD'
                                               AND gdr.to_currency = 'USD'),
                                       1),
                               precision         =
                                   NVL (
                                       (SELECT precision
                                          FROM fnd_currencies
                                         WHERE currency_code =
                                               CONTRACT_CURRENCY_TYPE),
                                       2),
                               reprocess_flag     = 'N'
                         WHERE     1 = 1
                               AND file_name IS NULL
                               AND request_id IS NULL;

                        UPDATE XXDO.XXD_GL_LX_WHT_AVG_SUMRY_T
                           SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                               last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                               date_parameter = TO_DATE (p_date, 'DD-MON-YY'), reprocess_flag = 'N', WEIGHTED_AVG_DISC_RATE = REGEXP_REPLACE (WEIGHTED_AVG_DISC_RATE, '[^-.[:digit:]]'),
                               WEIGHTED_AVG_REMAINING_LEASE_TERM_DAYS = REGEXP_REPLACE (WEIGHTED_AVG_REMAINING_LEASE_TERM_DAYS, '[^-.[:digit:]]'), WEIGHTED_AVG_REMAINING_LEASE_TERM_YEARS = REGEXP_REPLACE (WEIGHTED_AVG_REMAINING_LEASE_TERM_YEARS, '[^-.[:digit:]]')
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
                        DELETE FROM
                            xxdo.XXD_GL_LX_WHT_AVG_T
                              WHERE     (UPPER (CONTRACT_REC_ID) LIKE ('%SUB%TOTAL%') OR UPPER (CONTRACT_REC_ID) LIKE '%GRAND%TOTAL%')
                                    AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error While Deleting the Data' || SQLERRM);
                    END;



                    BEGIN
                        UPDATE xxdo.XXD_GL_LX_WHT_AVG_T
                           SET PRE_AMOUNT = NVL (DECODE (PRE_AMOUNT, '-', 0, PRE_AMOUNT), 0), CURNT_PERIOD_LIABILITY_BALAN = NVL (DECODE (CURNT_PERIOD_LIABILITY_BALAN, '-', 0, CURNT_PERIOD_LIABILITY_BALAN), 0), CURNT_PERIOD_LIABILITY_BALAN_LES_PRE = NVL (DECODE (CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, '-', 0, CURNT_PERIOD_LIABILITY_BALAN_LES_PRE), 0),
                               CURNT_PERIOD_ASSET_BALAN = NVL (DECODE (CURNT_PERIOD_ASSET_BALAN, '-', 0, CURNT_PERIOD_ASSET_BALAN), 0), CURNT_REMAIN_BALAN_LEASE_PAY = NVL (DECODE (CURNT_REMAIN_BALAN_LEASE_PAY, '-', 0, CURNT_REMAIN_BALAN_LEASE_PAY), 0), CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE = NVL (DECODE (CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE, '-', 0, CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE), 0),
                               INITIAL_ASSET_BALANCE = NVL (DECODE (INITIAL_ASSET_BALANCE, '-', 0, INITIAL_ASSET_BALANCE), 0), INITIAL_LIABILITY_BALANCE = NVL (DECODE (INITIAL_LIABILITY_BALANCE, '-', 0, INITIAL_LIABILITY_BALANCE), 0), WEIGHTED_REMAINING_PAYMENT = NVL (DECODE (WEIGHTED_REMAINING_PAYMENT, '-', 0, WEIGHTED_REMAINING_PAYMENT), 0),
                               WEIGHTED_REMAINING_LEASE_TERM = NVL (DECODE (WEIGHTED_REMAINING_LEASE_TERM, '-', 0, WEIGHTED_REMAINING_LEASE_TERM), 0)
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    END;

                    BEGIN
                        UPDATE xxdo.XXD_GL_LX_WHT_AVG_T
                           SET USD_PRE_AMOUNT = ROUND (balan_rate * NVL (DECODE (PRE_AMOUNT, '-', 0, PRE_AMOUNT), 0), precision), USD_CURNT_PERIOD_LIABILITY_BALAN = ROUND (balan_rate * NVL (DECODE (CURNT_PERIOD_LIABILITY_BALAN, '-', 0, CURNT_PERIOD_LIABILITY_BALAN), 0), precision), USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE = ROUND (balan_rate * NVL (DECODE (CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, '-', 0, CURNT_PERIOD_LIABILITY_BALAN_LES_PRE), 0), precision),
                               USD_CURNT_PERIOD_ASSET_BALAN = ROUND (balan_rate * NVL (DECODE (CURNT_PERIOD_ASSET_BALAN, '-', 0, CURNT_PERIOD_ASSET_BALAN), 0), precision), USD_CURNT_REMAIN_BALAN_LEASE_PAY = ROUND (balan_rate * NVL (DECODE (CURNT_REMAIN_BALAN_LEASE_PAY, '-', 0, CURNT_REMAIN_BALAN_LEASE_PAY), 0), precision), USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE = ROUND (balan_rate * NVL (DECODE (CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE, '-', 0, CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE), 0), precision),
                               USD_INITIAL_ASSET_BALANCE = ROUND (balan_rate * NVL (DECODE (INITIAL_ASSET_BALANCE, '-', 0, INITIAL_ASSET_BALANCE), 0), precision), USD_INITIAL_LIABILITY_BALANCE = ROUND (balan_rate * NVL (DECODE (INITIAL_LIABILITY_BALANCE, '-', 0, INITIAL_LIABILITY_BALANCE), 0), precision)
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    END;

                    BEGIN
                        UPDATE xxdo.XXD_GL_LX_WHT_AVG_T
                           SET USD_WEIGHTED_REMAINING_PAY = ROUND ((DISCOUNT_RATE * NVL (DECODE (USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, '-', 0, USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE), 0)) / 100, precision), USD_WEIGHTED_REMAINING_LEASE_TERM = ROUND (REMAIN_LIKELY_DAYS * NVL (DECODE (USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, '-', 0, USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE), 0), precision)
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error While Updating Weighted Remaining column'
                                || TO_DATE (p_date, 'DD-MON-YY'));
                    END;

                    BEGIN
                        UPDATE XXDO.XXD_GL_LX_WHT_AVG_SUMRY_T
                           SET USD_WEIGHTED_AVG_DISC_RATE   =
                                   ROUND (
                                       (SELECT (SELECT NVL (SUM (USD_WEIGHTED_REMAINING_PAY), 0) / NVL (SUM (USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE), 0) sum_amount
                                                  FROM xxdo.XXD_GL_LX_WHT_AVG_T
                                                 WHERE     1 = 1
                                                       AND request_id =
                                                           gn_request_id)
                                          FROM DUAL),
                                       4),
                               USD_WEIGHTED_AVG_REMAINING_LEASE_TERM_DAYS   =
                                   ROUND (
                                       (SELECT (SELECT NVL (SUM (USD_WEIGHTED_REMAINING_LEASE_TERM), 0) / NVL (SUM (USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE), 0) sum_amount
                                                  FROM xxdo.XXD_GL_LX_WHT_AVG_T
                                                 WHERE     1 = 1
                                                       AND request_id =
                                                           gn_request_id)
                                          FROM DUAL),
                                       4)
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error While Updating WEIGHTED_AVG_LEASE columns'
                                || SQLERRM);
                    END;

                    BEGIN
                        UPDATE XXDO.XXD_GL_LX_WHT_AVG_SUMRY_T
                           SET USD_WEIGHTED_AVG_REMAINING_LEASE_TERM_YEARS = ROUND ((USD_WEIGHTED_AVG_REMAINING_LEASE_TERM_DAYS / 365.25), 4)
                         WHERE 1 = 1 AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error While Updating WEIGHTED_AVG_LEASE_YEAR columns'
                                || SQLERRM);
                    END;

                    BEGIN
                        UPDATE XXDO.XXD_GL_LX_WHT_AVG_SUMRY_T
                           SET (SUM_PRE_AMOUNT,
                                SUM_CURNT_PERIOD_LIABILITY_BALAN,
                                SUM_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE,
                                SUM_CURNT_PERIOD_ASSET_BALAN,
                                SUM_CURNT_REMAIN_BALAN_LEASE_PAY,
                                SUM_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE,
                                SUM_INITIAL_ASSET_BALANCE,
                                SUM_INITIAL_LIABILITY_BALANCE,
                                SUM_WEIGHTED_REMAINING_PAYMENT,
                                SUM_WEIGHTED_REMAINING_LEASE_TERM,
                                SUM_USD_PRE_AMOUNT,
                                SUM_USD_CURNT_PERIOD_LIABILITY_BALAN,
                                SUM_USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE,
                                SUM_USD_CURNT_PERIOD_ASSET_BALAN,
                                SUM_USD_CURNT_REMAIN_BALAN_LEASE_PAY,
                                SUM_USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE,
                                SUM_USD_INITIAL_ASSET_BALANCE,
                                SUM_USD_INITIAL_LIABILITY_BALANCE,
                                SUM_USD_WEIGHTED_REMAINING_PAY,
                                SUM_USD_WEIGHTED_REMAINING_LEASE_TERM)   =
                                   (SELECT SUM (TO_NUMBER (DECODE (PRE_AMOUNT, '-', 0, PRE_AMOUNT))) SUM_PRE_AMOUNT, SUM (TO_NUMBER (DECODE (CURNT_PERIOD_LIABILITY_BALAN, '-', 0, CURNT_PERIOD_LIABILITY_BALAN))) SUM_CURNT_PERIOD_LIABILITY_BALAN, SUM (TO_NUMBER (DECODE (CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, '-', 0, CURNT_PERIOD_LIABILITY_BALAN_LES_PRE))) SUM_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE,
                                           SUM (TO_NUMBER (DECODE (CURNT_PERIOD_ASSET_BALAN, '-', 0, CURNT_PERIOD_ASSET_BALAN))) SUM_CURNT_PERIOD_ASSET_BALAN, SUM (TO_NUMBER (DECODE (CURNT_REMAIN_BALAN_LEASE_PAY, '-', 0, CURNT_REMAIN_BALAN_LEASE_PAY))) SUM_CURNT_REMAIN_BALAN_LEASE_PAY, SUM (TO_NUMBER (DECODE (CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE, '-', 0, CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE))) SUM_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE,
                                           SUM (TO_NUMBER (DECODE (INITIAL_ASSET_BALANCE, '-', 0, INITIAL_ASSET_BALANCE))) SUM_INITIAL_ASSET_BALANCE, SUM (TO_NUMBER (DECODE (INITIAL_LIABILITY_BALANCE, '-', 0, INITIAL_LIABILITY_BALANCE))) SUM_INITIAL_LIABILITY_BALANCE, SUM (TO_NUMBER (DECODE (WEIGHTED_REMAINING_PAYMENT, '-', 0, WEIGHTED_REMAINING_PAYMENT))) SUM_WEIGHTED_REMAINING_PAYMENT,
                                           SUM (TO_NUMBER (DECODE (WEIGHTED_REMAINING_LEASE_TERM, '-', 0, WEIGHTED_REMAINING_LEASE_TERM))) SUM_WEIGHTED_REMAINING_LEASE_TERM, SUM (TO_NUMBER (DECODE (USD_PRE_AMOUNT, '-', 0, USD_PRE_AMOUNT))) SUM_USD_PRE_AMOUNT, SUM (TO_NUMBER (DECODE (USD_CURNT_PERIOD_LIABILITY_BALAN, '-', 0, USD_CURNT_PERIOD_LIABILITY_BALAN))) SUM_USD_CURNT_PERIOD_LIABILITY_BALAN,
                                           SUM (TO_NUMBER (DECODE (USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, '-', 0, USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE))) SUM_USD_CURNT_PERIOD_LIABILITY_BALAN_LES_PRE, SUM (TO_NUMBER (DECODE (USD_CURNT_PERIOD_ASSET_BALAN, '-', 0, USD_CURNT_PERIOD_ASSET_BALAN))) SUM_USD_CURNT_PERIOD_ASSET_BALAN, SUM (TO_NUMBER (DECODE (USD_CURNT_REMAIN_BALAN_LEASE_PAY, '-', 0, USD_CURNT_REMAIN_BALAN_LEASE_PAY))) SUM_USD_CURNT_REMAIN_BALAN_LEASE_PAY,
                                           SUM (TO_NUMBER (DECODE (USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE, '-', 0, USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE))) SUM_USD_CURNT_REMAIN_BALAN_LEASE_PAY_LES_PRE, SUM (TO_NUMBER (DECODE (USD_INITIAL_ASSET_BALANCE, '-', 0, USD_INITIAL_ASSET_BALANCE))) SUM_USD_INITIAL_ASSET_BALANCE, SUM (TO_NUMBER (DECODE (USD_INITIAL_LIABILITY_BALANCE, '-', 0, USD_INITIAL_LIABILITY_BALANCE))) SUM_USD_INITIAL_LIABILITY_BALANCE,
                                           SUM (TO_NUMBER (DECODE (USD_WEIGHTED_REMAINING_PAY, '-', 0, USD_WEIGHTED_REMAINING_PAY))) SUM_USD_WEIGHTED_REMAINING_PAY, SUM (TO_NUMBER (DECODE (USD_WEIGHTED_REMAINING_LEASE_TERM, '-', 0, USD_WEIGHTED_REMAINING_LEASE_TERM))) SUM_USD_WEIGHTED_REMAINING_LEASE_TERM
                                      FROM xxdo.XXD_GL_LX_WHT_AVG_T
                                     WHERE REQUEST_ID = gn_request_id)
                         WHERE REQUEST_ID = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error While Updating WEIGHTED_AVG_LEASE_YEAR columns'
                                || SQLERRM);
                    END;

                    BEGIN
                        DELETE FROM
                            xxdo.XXD_GL_LX_WHT_AVG_T
                              WHERE     (UPPER (CONTRACT_REC_ID) LIKE ('%SUB%TOTAL%') OR UPPER (CONTRACT_REC_ID) LIKE '%GRAND%TOTAL%'--OR accounting_method LIKE 'OperatingTotal'
                                                                                                                                     )
                                    AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Error While Updating WEIGHTED_AVG_LEASE_YEAR columns'
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
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'final SQLERRM	 ' || SQLERRM);
            RETURN FALSE;
    END main;

    FUNCTION get_rate_type_value
        RETURN VARCHAR2
    AS
        lv_period_rate_value   VARCHAR2 (100);
    BEGIN
        SELECT rate_type
          INTO lv_period_rate_value
          FROM (  SELECT rate_type, request_id
                    FROM xxdo.XXD_GL_LX_WHT_AVG_T
                   WHERE     reprocess_flag = 'N'
                         AND date_parameter = TO_DATE (p_date, 'DD-MON-YY')
                         AND request_id =
                             DECODE (p_report_process,
                                     'Report', request_id,
                                     fnd_global.conc_request_id)
                GROUP BY rate_type, request_id
                ORDER BY request_id DESC)
         WHERE ROWNUM = 1;

        RETURN lv_period_rate_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_local_end_balance
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
                                   'WEIGHTED_AVG_ACCOUNTS'
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
                               AND ffv_minor.flex_value <> 'xxxxx'--    ORDER BY
                                                                  --     ffv_major.flex_value ASC
                                                                  )
               AND gcc.summary_flag = 'N'
               AND gb.period_name = gp.period_name
               AND gcc.code_combination_id = gb.code_combination_id
               AND gp.period_set_name = 'DO_FY_CALENDAR'
               AND p_date BETWEEN start_date AND end_date;

        RETURN (ln_end_bal * -1);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_usd_end_balance
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
               --   AND ( b.ledger_category_code = 'ALC'
               --    OR b.ledger_id = 2036 )
               AND b.ledger_id <> 2081
               AND ledger_category_code = 'PRIMARY'
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
                                   'WEIGHTED_AVG_ACCOUNTS'
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
                               AND ffv_minor.flex_value <> 'xxxxx'--    ORDER BY
                                                                  --     ffv_major.flex_value ASC
                                                                  )
               AND gcc.summary_flag = 'N'
               AND gb.period_name = gp.period_name
               AND gcc.code_combination_id = gb.code_combination_id
               AND gp.period_set_name = 'DO_FY_CALENDAR'
               AND p_date BETWEEN start_date AND end_date;

        RETURN (ln_end_bal * -1);
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
                   'Deckers LX Weighted Average Lease Program';

        RETURN ln_days_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;
END XXD_GL_LX_WHT_AVG_PKG;
/
