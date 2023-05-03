--
-- XXD_HYP_INB_FORECAST_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_HYP_INB_FORECAST_PKG"
IS
      /****************************************************************************************************
 NAME           : XXD_HYP_INB_FORECAST_PKG
 REPORT NAME    : Deckers Hyperion Inbound Forecast Program

 REVISIONS:
 Date         Author             Version  Description
 -----------  ----------         -------  ------------------------------------------------------------
 26-OCT-2021  Damodara Gupta     1.0      Created this package using XXD_HYP_INB_FORECAST_PKG
                                          to upload the forecast budget from Hyperion system
                                          into an Oracle staging table
*****************************************************************************************************/

    PROCEDURE write_log_prc (pv_msg IN VARCHAR2)
    IS
            /****************************************************
-- PROCEDURE write_log_prc
-- PURPOSE: This Procedure write the log messages
*****************************************************/
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

    /**********************************************************************
 -- FUNCTION xxd_remove_junk_fnc
 -- PURPOSE: This Procedure Removes Chr (9), Chr(10), Chr(13) Charcters
 **********************************************************************/
    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
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
    END xxd_remove_junk_fnc;

     /***************************************************************************
-- PROCEDURE load_file_into_tbl_prc
-- PURPOSE: This Procedure read the data from a CSV file.
-- And load it into the target oracle table.
-- Finally it renames the source file with date.
--
-- PV_FILENAME
-- The name of the flat file(a text file)
--
-- PV_DIRECTORY
-- Name of the directory where the file is been placed.
-- Note: The grant has to be given for the user to the directory
-- before executing the function
--
-- PV_IGNORE_HEADERLINES:
-- Pass the value as '1' to ignore importing headers.
--
-- PV_DELIMITER
-- By default the delimiter is used as '|'
-- As we are using CSV file to load the data into oracle
--
-- PV_OPTIONAL_ENCLOSED
-- By default the optionally enclosed is used as '"'
-- As we are using CSV file to load the data into oracle
--
**************************************************************************/
    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl_prc (pv_table IN VARCHAR2, pv_dir IN VARCHAR2 DEFAULT 'XXD_HYP_FORECAST_INB_DIR', pv_filename IN VARCHAR2, pv_ignore_headerlines IN INTEGER DEFAULT 1, pv_delimiter IN VARCHAR2 DEFAULT '|', pv_optional_enclosed IN VARCHAR2 DEFAULT '"'
                                      , pv_num_of_columns IN NUMBER)
    IS
        l_input                UTL_FILE.file_type;

        l_lastLine             VARCHAR2 (4000);
        l_cnames               VARCHAR2 (4000);
        l_bindvars             VARCHAR2 (4000);
        l_status               INTEGER;
        l_cnt                  NUMBER DEFAULT 0;
        l_rowCount             NUMBER DEFAULT 0;
        l_sep                  CHAR (1) DEFAULT NULL;
        l_errmsg               VARCHAR2 (4000);
        v_eof                  BOOLEAN := FALSE;
        l_theCursor            NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert               VARCHAR2 (4000);
        buffer_size   CONSTANT INTEGER := 32767;
    BEGIN
        write_log_prc (
               'Load Data Process Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        l_cnt        := 1;

        FOR TAB_COLUMNS
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     1 = 1
                         AND table_name = pv_table
                         AND column_id < pv_num_of_columns
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

        write_log_prc ('Count of Columns is - ' || l_cnt);

        l_input      :=
            UTL_FILE.FOPEN (pv_dir, pv_filename, 'r',
                            buffer_size);

        IF pv_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. pv_ignore_headerlines
                LOOP
                    write_log_prc ('No of lines Ignored is - ' || i);
                    UTL_FILE.get_line (l_input, l_lastLine);
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
                    UTL_FILE.GET_LINE (l_input, l_lastLine);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                IF LENGTH (l_lastLine) > 0
                THEN
                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        DBMS_SQL.bind_variable (
                            l_theCursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, --'(^|,)("[^"]*"|[^",]*)',
                                                                                    '([^|]*)(\||$)', 1
                                                                        , i),
                                                         pv_delimiter),
                                                  pv_optional_enclosed),
                                           pv_delimiter),
                                    pv_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_theCursor);

                        l_rowcount   := l_rowcount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_errmsg   := SQLERRM;
                    END;
                END IF;
            END LOOP;

            DBMS_SQL.close_cursor (l_theCursor);
            UTL_FILE.fclose (l_input);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Error in load_file_into_tbl_prc Procedure -' || SQLERRM);
    END load_file_into_tbl_prc;


    /***************************************************************************
    -- PROCEDURE validate_prc
    -- PURPOSE: This Procedure validate the recoreds present in staging table.
    ****************************************************************************/

    PROCEDURE validate_prc (pv_file_name VARCHAR2)
    IS
        CURSOR c_seg_cols IS
            SELECT ROWID, fiscal_year, currency,
                   scenario, version, company,
                   brand, channel, region,
                   department, account, inter_company,
                   period_name, budget_amount, future_segment,
                   concatenated_segments, code_combination_id, period_start_date,
                   additional_field1, additional_field2, additional_field3,
                   additional_field4, additional_field5, additional_field6,
                   additional_field7, additional_field8, additional_field9,
                   additional_field10, additional_field11, additional_field12,
                   additional_field13, additional_field14, additional_field15,
                   additional_field16, additional_field17, additional_field18,
                   additional_field19, additional_field20, consumed_flag,
                   rec_status, error_msg, request_id,
                   filename
              FROM xxdo.xxd_hyp_inb_forecast_stg_t
             WHERE     1 = 1
                   AND rec_status = 'N'
                   AND request_id = gn_request_id
                   AND UPPER (filename) = UPPER (pv_file_name);

        TYPE tb_rec IS TABLE OF c_seg_cols%ROWTYPE
            INDEX BY BINARY_INTEGER;

        v_tb_rec        tb_rec;
        v_bulk_limit    NUMBER := 5000;
        e_bulk_errors   EXCEPTION;
        PRAGMA EXCEPTION_INIT (e_bulk_errors, -24381);
        l_msg           VARCHAR2 (4000);
        l_idx           NUMBER;
        l_error_count   NUMBER;
    BEGIN
        write_log_prc (
               'Validate PRC Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

        UPDATE xxdo.xxd_hyp_inb_forecast_stg_t u
           SET rec_status = 'E', error_msg = error_msg || 'Combination Already Consumed-'
         WHERE     1 = 1
               AND consumed_flag = 'N'
               AND EXISTS
                       (SELECT 1
                          FROM xxdo.xxd_hyp_inb_forecast_stg_t s
                         WHERE     1 = 1
                               AND u.period_name = s.period_name
                               AND u.fiscal_year = s.fiscal_year
                               AND u.scenario = s.scenario
                               AND u.company = s.company
                               AND u.brand = s.brand
                               AND u.channel = s.channel
                               AND u.region = s.region
                               AND u.department = s.department
                               AND u.account = s.account
                               AND u.inter_company = s.inter_company
                               AND s.consumed_flag = 'Y'
                               AND s.request_id <> u.request_id
                               AND s.filename <> u.filename
                               AND s.consumed_flag <> u.consumed_flag)
               AND request_id = gn_request_id
               AND filename = pv_file_name;

        write_log_prc (
               SQL%ROWCOUNT
            || 'Records updated with error - Combination Already Exists and Consumed');
        COMMIT;

        OPEN c_seg_cols;

        v_tb_rec.DELETE;

        LOOP
            FETCH c_seg_cols BULK COLLECT INTO v_tb_rec LIMIT v_bulk_limit;

            EXIT WHEN v_tb_rec.COUNT = 0;

            IF v_tb_rec.COUNT > 0
            THEN
                write_log_prc ('Record Count: ' || v_tb_rec.COUNT);

                BEGIN
                    FOR i IN 1 .. v_tb_rec.COUNT
                    LOOP
                        IF v_tb_rec (i).fiscal_year IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Fiscal Year Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).currency IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Currency Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).scenario IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Scenario Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).version IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Version Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).company IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Company Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).brand IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Brand Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).channel IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Channel Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).region IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Region Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).department IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Department Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).account IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Account Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).inter_company IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Inter Company Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).period_name IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Period Name Cannot be Null-';
                        END IF;

                        IF v_tb_rec (i).budget_amount IS NULL
                        THEN
                            v_tb_rec (i).rec_status   := 'E';
                            v_tb_rec (i).error_msg    :=
                                   v_tb_rec (i).error_msg
                                || 'Budget Amount Cannot be Null-';
                        END IF;

                        v_tb_rec (i).future_segment   := '1000';

                        v_tb_rec (i).concatenated_segments   :=
                               SUBSTR (v_tb_rec (i).company, 2)
                            || '.'
                            || SUBSTR (v_tb_rec (i).brand, 2)
                            || '.'
                            || SUBSTR (v_tb_rec (i).channel, 2)
                            || '.'
                            || SUBSTR (v_tb_rec (i).region, 2)
                            || '.'
                            || SUBSTR (v_tb_rec (i).department, 2)
                            || '.'
                            || SUBSTR (v_tb_rec (i).account, 2)
                            || '.'
                            || SUBSTR (v_tb_rec (i).inter_company, 2)
                            || '.'
                            || v_tb_rec (i).future_segment;

                        BEGIN
                            SELECT code_combination_id
                              INTO v_tb_rec (i).code_combination_id
                              FROM gl_code_combinations_kfv
                             WHERE concatenated_segments =
                                   v_tb_rec (i).concatenated_segments;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_tb_rec (i).code_combination_id   := NULL;
                                write_log_prc (
                                       'Failed to Derive Code Combination ID for the Segments-'
                                    || v_tb_rec (i).concatenated_segments);
                        END;

                        BEGIN
                            SELECT start_date
                              INTO v_tb_rec (i).period_start_date
                              FROM gl.gl_periods
                             WHERE     period_set_name = 'DO_FY_CALENDAR'
                                   AND period_name =
                                          UPPER (v_tb_rec (i).period_name)
                                       || '-'
                                       || SUBSTR (v_tb_rec (i).fiscal_year,
                                                  3);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                v_tb_rec (i).period_start_date   := NULL;
                                write_log_prc (
                                       'Failed to Derive period_start_date for the Period Name-'
                                    || v_tb_rec (i).period_name);
                        END;
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                        write_log_prc (
                               SQLERRM
                            || ' Other Error - Record Validations Failed');
                END;

                BEGIN
                    FORALL i IN v_tb_rec.FIRST .. v_tb_rec.LAST
                      SAVE EXCEPTIONS
                        UPDATE xxdo.xxd_hyp_inb_forecast_stg_t
                           SET rec_status = v_tb_rec (i).rec_status, error_msg = v_tb_rec (i).error_msg, period_name = v_tb_rec (i).period_name || '-' || SUBSTR (v_tb_rec (i).fiscal_year, 3),
                               future_segment = v_tb_rec (i).future_segment, concatenated_segments = v_tb_rec (i).concatenated_segments, code_combination_id = v_tb_rec (i).code_combination_id--,period_start_date = TO_DATE('01-'||v_tb_rec(i).period_name||'-'||substr(v_tb_rec(i).fiscal_year,3),'DD-MON-RR')
                                                                                                                                                                                               ,
                               period_start_date = v_tb_rec (i).period_start_date
                         WHERE ROWID = v_tb_rec (i).ROWID;

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Records Updated with Consumed Flag and Error Msg...');
                EXCEPTION
                    WHEN e_bulk_errors
                    THEN
                        write_log_prc ('Inside E_BULK_ERRORS');
                        l_error_count   := SQL%BULK_EXCEPTIONS.COUNT;

                        FOR i IN 1 .. l_error_count
                        LOOP
                            l_msg   :=
                                SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE);
                            l_idx   := SQL%BULK_EXCEPTIONS (i).ERROR_INDEX;
                            write_log_prc (
                                   'Failed to update- '
                                || v_tb_rec (l_idx).ROWID
                                || ' with error_code- '
                                || l_msg);
                        END LOOP;
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                            'Update Failed for Error Records' || SQLERRM);
                END;

                COMMIT;
            END IF;

            EXIT WHEN c_seg_cols%NOTFOUND;
        END LOOP;

        UPDATE xxdo.xxd_hyp_inb_forecast_stg_t
           SET rec_status = 'E', error_msg = error_msg || 'Duplicate Record-'
         WHERE     1 = 1
               AND (fiscal_year, currency, scenario,
                    version, company, brand,
                    channel, region, department,
                    account, inter_company, period_name) IN
                       (  SELECT fiscal_year, currency, scenario,
                                 version, company, brand,
                                 channel, region, department,
                                 account, inter_company, period_name
                            FROM xxdo.xxd_hyp_inb_forecast_stg_t
                           WHERE     1 = 1
                                 AND request_id = gn_request_id
                                 AND filename = pv_file_name
                        GROUP BY fiscal_year, currency, scenario,
                                 version, company, brand,
                                 channel, region, department,
                                 account, inter_company, period_name
                          HAVING COUNT (1) > 1)
               AND request_id = gn_request_id
               AND filename = pv_file_name;


        write_log_prc (
            SQL%ROWCOUNT || 'Records updated with error - Duplicate Records');
        COMMIT;

        UPDATE xxdo.xxd_hyp_inb_forecast_stg_t t1
           SET active_flag   = 'N'
         WHERE     1 = 1
               AND active_flag = 'Y'
               AND (fiscal_year, currency, scenario,
                    version, company, brand,
                    channel, region, department,
                    account, inter_company, period_name) IN
                       (SELECT fiscal_year, currency, scenario,
                               version, company, brand,
                               channel, region, department,
                               account, inter_company, period_name
                          FROM xxdo.xxd_hyp_inb_forecast_stg_t t2
                         WHERE     1 = 1
                               AND request_id = gn_request_id
                               AND filename = pv_file_name
                               AND active_flag = 'Y'
                               AND t1.fiscal_year = t2.fiscal_year
                               AND t1.currency = t2.currency
                               AND t1.scenario = t2.scenario
                               AND t1.version = t2.version
                               AND t1.company = t2.company
                               AND t1.brand = t2.brand
                               AND t1.channel = t2.channel
                               AND t1.region = t2.region
                               AND t1.department = t2.department
                               AND t1.account = t2.account
                               AND t1.inter_company = t2.inter_company
                               AND t1.period_name = t2.period_name)
               AND filename <> pv_file_name;

        write_log_prc (
            SQL%ROWCOUNT || 'Records updated with Active Flag as N ');
        COMMIT;

        write_log_prc (
               'Validate PRC Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Error in validate_prc Procedure -' || SQLERRM);
    END validate_prc;

       /***************************************************************************
-- PROCEDURE create_final_zip_prc
-- PURPOSE: This Procedure Converts the file to zip file
***************************************************************************/

    FUNCTION file_to_blob_fnc (pv_directory_name   IN VARCHAR2,
                               pv_file_name        IN VARCHAR2)
        RETURN BLOB
    IS
        dest_loc   BLOB := EMPTY_BLOB ();
        src_loc    BFILE := BFILENAME (pv_directory_name, pv_file_name);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           ' Start of Convering the file to BLOB');

        DBMS_LOB.OPEN (src_loc, DBMS_LOB.LOB_READONLY);

        DBMS_LOB.CREATETEMPORARY (lob_loc   => dest_loc,
                                  cache     => TRUE,
                                  dur       => DBMS_LOB.session);

        DBMS_LOB.OPEN (dest_loc, DBMS_LOB.LOB_READWRITE);

        DBMS_LOB.LOADFROMFILE (dest_lob   => dest_loc,
                               src_lob    => src_loc,
                               amount     => DBMS_LOB.getLength (src_loc));

        DBMS_LOB.CLOSE (dest_loc);

        DBMS_LOB.CLOSE (src_loc);

        RETURN dest_loc;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in Converting the file to BLOB - ' || SQLERRM);

            RETURN NULL;
    END file_to_blob_fnc;

    PROCEDURE save_zip_prc (pb_zipped_blob     BLOB,
                            pv_dir             VARCHAR2,
                            pv_zip_file_name   VARCHAR2)
    IS
        t_fh    UTL_FILE.file_type;
        t_len   PLS_INTEGER := 32767;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of save_zip_prc Procedure');

        DBMS_OUTPUT.put_line (' Start of save_zip_prc Procedure');

        t_fh   := UTL_FILE.fopen (pv_dir, pv_zip_file_name, 'wb');

        DBMS_OUTPUT.put_line (' Start of save_zip_prc Procedure - TEST1');

        FOR i IN 0 ..
                 TRUNC ((DBMS_LOB.getlength (pb_zipped_blob) - 1) / t_len)
        LOOP
            UTL_FILE.put_raw (
                t_fh,
                DBMS_LOB.SUBSTR (pb_zipped_blob, t_len, i * t_len + 1));
        END LOOP;

        UTL_FILE.fclose (t_fh);
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);

            DBMS_OUTPUT.put_line (
                ' Exception in save_zip_prc Procedure - ' || SQLERRM);
    END save_zip_prc;


    PROCEDURE create_final_zip_prc (pv_directory_name IN VARCHAR2, pv_file_name IN VARCHAR2, pv_zip_file_name IN VARCHAR2)
    IS
        lb_file   BLOB;
        lb_zip    BLOB;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, ' Start of file_to_blob_fnc ');

        lb_file   := file_to_blob_fnc (pv_directory_name, pv_file_name);

        fnd_file.put_line (fnd_file.LOG, pv_directory_name || pv_file_name);

        fnd_file.put_line (fnd_file.LOG, ' Start of add_file PROC ');

        APEX_200200.WWV_FLOW_ZIP.add_file (lb_zip, pv_file_name, lb_file);

        fnd_file.put_line (fnd_file.LOG, ' Start of finish PROC ');

        APEX_200200.wwv_flow_zip.finish (lb_zip);

        fnd_file.put_line (fnd_file.LOG, ' Start of Saving ZIP File PROC ');

        save_zip_prc (lb_zip, pv_directory_name, pv_zip_file_name);
    END create_final_zip_prc;

    /***************************************************************************
 -- PROCEDURE generate_hyperion_report_prc
 -- PURPOSE: This Procedure generate the Report/Exception output and place
 -- into Report/Exception directory
 **************************************************************************/
    PROCEDURE generate_hyperion_report_prc ( --pv_flag                 IN     VARCHAR2,
                                            pv_period_from IN VARCHAR2, pv_period_to IN VARCHAR2, pv_consumed IN VARCHAR2
                                            , --pv_override             IN     VARCHAR2,
                                              pv_rep_file_name OUT VARCHAR2)
    IS
        CURSOR rep_rec_cur (pv_start_date DATE, pv_end_date DATE)
        IS
              SELECT seq, line
                FROM (SELECT 1 AS seq, TRIM (fiscal_year) || gv_delim_pipe || TRIM (currency) || gv_delim_pipe || TRIM (scenario) || gv_delim_pipe || TRIM (version) || gv_delim_pipe || TRIM (company) || gv_delim_pipe || TRIM (brand) || gv_delim_pipe || TRIM (channel) || gv_delim_pipe || TRIM (region) || gv_delim_pipe || TRIM (department) || gv_delim_pipe || TRIM (account) || gv_delim_pipe || TRIM (inter_company) || gv_delim_pipe || TRIM (future_segment) || gv_delim_pipe || TRIM (concatenated_segments) || gv_delim_pipe || TRIM (code_combination_id) || gv_delim_pipe || TRIM (period_name) || gv_delim_pipe || TRIM (budget_amount) || gv_delim_pipe || TRIM (additional_field1) || gv_delim_pipe || TRIM (additional_field2) || gv_delim_pipe || TRIM (additional_field3) || gv_delim_pipe || TRIM (additional_field4) || gv_delim_pipe || TRIM (additional_field5) || gv_delim_pipe || TRIM (additional_field6) || gv_delim_pipe || TRIM (additional_field7) || gv_delim_pipe || TRIM (additional_field8) || gv_delim_pipe || TRIM (additional_field9) || gv_delim_pipe || TRIM (additional_field10) || gv_delim_pipe || TRIM (additional_field11) || gv_delim_pipe || TRIM (additional_field12) || gv_delim_pipe || TRIM (additional_field13) || gv_delim_pipe || TRIM (additional_field14) || gv_delim_pipe || TRIM (additional_field15) || gv_delim_pipe || TRIM (additional_field16) || gv_delim_pipe || TRIM (additional_field17) || gv_delim_pipe || TRIM (additional_field18) || gv_delim_pipe || TRIM (additional_field19) || gv_delim_pipe || TRIM (additional_field20) || gv_delim_pipe || TRIM (consumed_flag) || gv_delim_pipe || TRIM (active_flag) || gv_delim_pipe || TRIM (rec_status) || gv_delim_pipe || TRIM (error_msg) || gv_delim_pipe || TRIM (request_id) || gv_delim_pipe || TRIM (filename) line
                        FROM xxdo.xxd_hyp_inb_forecast_stg_t
                       WHERE     1 = 1
                             -- AND rec_status = DECODE (pv_flag, 'Y', 'N','E')
                             -- AND NVL (error_msg, 'X') = DECODE (pv_flag, 'Y', 'X', error_msg)
                             -- AND request_id = DECODE (pv_flag, 'Y', request_id, gn_request_id)
                             -- AND period_start_date BETWEEN pv_start_date AND pv_end_date
                             AND ((period_start_date IS NOT NULL AND period_start_date BETWEEN pv_start_date AND pv_end_date) OR period_start_date IS NULL)
                             AND consumed_flag =
                                 NVL (SUBSTR (pv_consumed, 1, 1), 'N')
                      UNION ALL
                      SELECT 2 AS seq, 'Fiscal Year' || gv_delim_pipe || 'Currency' || gv_delim_pipe || 'Scenario' || gv_delim_pipe || 'Version' || gv_delim_pipe || 'Company' || gv_delim_pipe || 'Brand' || gv_delim_pipe || 'Channel' || gv_delim_pipe || 'Region (Geo)' || gv_delim_pipe || 'Department (Cost Center)' || gv_delim_pipe || 'Account' || gv_delim_pipe || 'Inter-Company' || gv_delim_pipe || 'Future Segment' || gv_delim_pipe || 'Concatenated Segments' || gv_delim_pipe || 'Code Combination ID' || gv_delim_pipe || 'Period Name' || gv_delim_pipe || 'Budget Amount' || gv_delim_pipe || 'Additional Field1' || gv_delim_pipe || 'Additional Field2' || gv_delim_pipe || 'Additional Field3' || gv_delim_pipe || 'Additional Field4' || gv_delim_pipe || 'Additional Field5' || gv_delim_pipe || 'Additional Field6' || gv_delim_pipe || 'Additional Field7' || gv_delim_pipe || 'Additional Field8' || gv_delim_pipe || 'Additional Field9' || gv_delim_pipe || 'Additional Field10' || gv_delim_pipe || 'Additional Field11' || gv_delim_pipe || 'Additional Field12' || gv_delim_pipe || 'Additional Field13' || gv_delim_pipe || 'Additional Field14' || gv_delim_pipe || 'Additional Field15' || gv_delim_pipe || 'Additional Field16' || gv_delim_pipe || 'Additional Field17' || gv_delim_pipe || 'Additional Field18' || gv_delim_pipe || 'Additional Field19' || gv_delim_pipe || 'Additional Field20' || gv_delim_pipe || 'Consumed Flag' || gv_delim_pipe || 'Active Flag' || gv_delim_pipe || 'Rec Status' || gv_delim_pipe || 'Error Msg' || gv_delim_pipe || 'Request ID' || gv_delim_pipe || 'File Name'
                        FROM DUAL)
            ORDER BY seq DESC;

        --DEFINE VARIABLES
        lv_output_file         UTL_FILE.file_type;
        lv_outbound_file       VARCHAR2 (32767);
        lv_err_msg             VARCHAR2 (32767) := NULL;
        lv_line                VARCHAR2 (32767) := NULL;
        lv_directory_path      VARCHAR2 (4000);
        lv_file_name           VARCHAR2 (4000);
        l_line                 VARCHAR2 (32767);
        lv_result              VARCHAR2 (32767);
        buffer_size   CONSTANT INTEGER := 32767;
        lv_period_start_date   DATE;
        lv_period_end_date     DATE;
        lv_outbound_file_zip   VARCHAR2 (32767);
    BEGIN
        write_log_prc (
               'generate_hyperion_report_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_directory_path      := NULL;
        lv_outbound_file       := NULL;

        -- Derive the directory Path

        lv_outbound_file       :=
               'Hyperion_Extract_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.csv';
        write_log_prc ('Hyperion Report File Name is - ' || lv_outbound_file);

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception Occurred white fetch the Report directory');
                lv_directory_path   := NULL;
        END;

        IF pv_period_from IS NULL
        THEN
            lv_period_start_date   := NULL;

            BEGIN
                SELECT MIN (period_start_date)
                  INTO lv_period_start_date
                  FROM xxdo.xxd_hyp_inb_forecast_stg_t;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_period_start_date   := NULL;
                    write_log_prc (
                        'Failed to extract FROM Period when pv_period_from IS NULL');
            END;
        ELSIF pv_period_from IS NOT NULL
        THEN
            lv_period_start_date   := NULL;

            BEGIN
                SELECT DISTINCT period_start_date
                  INTO lv_period_start_date
                  FROM xxdo.xxd_hyp_inb_forecast_stg_t
                 WHERE UPPER (period_name) = UPPER (pv_period_from);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_period_start_date   := NULL;

                    BEGIN
                        SELECT MIN (period_start_date)
                          INTO lv_period_start_date
                          FROM xxdo.xxd_hyp_inb_forecast_stg_t
                         WHERE period_start_date >=
                               (SELECT start_date
                                  FROM gl_periods
                                 WHERE     period_name = pv_period_from
                                       AND period_set_name = 'DO_FY_CALENDAR');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_period_start_date   := NULL;
                            write_log_prc ('Failed to extract FROM Period');
                    END;
            END;
        END IF;

        write_log_prc ('PERIOD START DATE-' || lv_period_start_date);

        IF pv_period_to IS NULL
        THEN
            lv_period_end_date   := NULL;

            BEGIN
                SELECT MAX (period_start_date)
                  INTO lv_period_end_date
                  FROM xxdo.xxd_hyp_inb_forecast_stg_t;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_period_start_date   := NULL;
                    write_log_prc (
                        'Failed to extract TO Period when pv_period_to IS NULL');
            END;
        ELSIF pv_period_to IS NOT NULL
        THEN
            lv_period_end_date   := NULL;

            BEGIN
                SELECT DISTINCT period_start_date
                  INTO lv_period_end_date
                  FROM xxdo.xxd_hyp_inb_forecast_stg_t
                 WHERE UPPER (period_name) = UPPER (pv_period_to);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_period_end_date   := NULL;

                    BEGIN
                        SELECT MAX (period_start_date)
                          INTO lv_period_end_date
                          FROM xxdo.xxd_hyp_inb_forecast_stg_t
                         WHERE period_start_date <=
                               (SELECT start_date
                                  FROM gl_periods
                                 WHERE     period_name = pv_period_to
                                       AND period_set_name = 'DO_FY_CALENDAR');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_period_end_date   := NULL;
                            write_log_prc ('Failed to extract TO Period');
                    END;
            END;
        END IF;

        write_log_prc ('PERIOD END DATE-' || lv_period_end_date);

        FOR i IN rep_rec_cur (lv_period_start_date, lv_period_end_date)
        LOOP
            l_line   := i.line;
        -- write_log_prc (l_line);
        END LOOP;

        -- WRITE INTO FOLDER

        lv_output_file         :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                    ,
                            buffer_size);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            FOR i IN rep_rec_cur (lv_period_start_date, lv_period_end_date)
            LOOP
                lv_line   := i.line;
                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
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

        UTL_FILE.fclose (lv_output_file);
        --pv_rep_file_name := lv_outbound_file;

        lv_outbound_file_zip   :=
               SUBSTR (lv_outbound_file,
                       1,
                       (INSTR (lv_outbound_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'Exception Report File Name is - ' || lv_outbound_file);
        write_log_prc (
            'Exception Report ZIP File Name is - ' || lv_outbound_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_HYP_FORECAST_REP_DIR',
            pv_file_name        => lv_outbound_file,
            pv_zip_file_name    => lv_outbound_file_zip);

        pv_rep_file_name       := lv_outbound_file_zip;

        write_log_prc (
               'generate_hyperion_report_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END generate_hyperion_report_prc;

       /***************************************************************************
-- PROCEDURE generate_hyp_excep_report_prc
-- PURPOSE: This Procedure generate the Report/Exception output and place
-- into Report/Exception directory
**************************************************************************/
    PROCEDURE generate_hyp_excep_report_prc ( --pv_flag                 IN     VARCHAR2,
                                             pv_rep_file_name OUT VARCHAR2)
    IS
        CURSOR rep_rec_cur IS
              SELECT seq, line
                FROM (SELECT 1 AS seq, TRIM (fiscal_year) || gv_delim_pipe || TRIM (currency) || gv_delim_pipe || TRIM (scenario) || gv_delim_pipe || TRIM (version) || gv_delim_pipe || TRIM (company) || gv_delim_pipe || TRIM (brand) || gv_delim_pipe || TRIM (channel) || gv_delim_pipe || TRIM (region) || gv_delim_pipe || TRIM (department) || gv_delim_pipe || TRIM (account) || gv_delim_pipe || TRIM (inter_company) || gv_delim_pipe || TRIM (future_segment) || gv_delim_pipe || TRIM (concatenated_segments) || gv_delim_pipe || TRIM (code_combination_id) || gv_delim_pipe || TRIM (period_name) || gv_delim_pipe || TRIM (budget_amount) || gv_delim_pipe || TRIM (additional_field1) || gv_delim_pipe || TRIM (additional_field2) || gv_delim_pipe || TRIM (additional_field3) || gv_delim_pipe || TRIM (additional_field4) || gv_delim_pipe || TRIM (additional_field5) || gv_delim_pipe || TRIM (additional_field6) || gv_delim_pipe || TRIM (additional_field7) || gv_delim_pipe || TRIM (additional_field8) || gv_delim_pipe || TRIM (additional_field9) || gv_delim_pipe || TRIM (additional_field10) || gv_delim_pipe || TRIM (additional_field11) || gv_delim_pipe || TRIM (additional_field12) || gv_delim_pipe || TRIM (additional_field13) || gv_delim_pipe || TRIM (additional_field14) || gv_delim_pipe || TRIM (additional_field15) || gv_delim_pipe || TRIM (additional_field16) || gv_delim_pipe || TRIM (additional_field17) || gv_delim_pipe || TRIM (additional_field18) || gv_delim_pipe || TRIM (additional_field19) || gv_delim_pipe || TRIM (additional_field20) || gv_delim_pipe || TRIM (consumed_flag) || gv_delim_pipe || TRIM (active_flag) || gv_delim_pipe || TRIM (rec_status) || gv_delim_pipe || TRIM (error_msg) || gv_delim_pipe || TRIM (request_id) || gv_delim_pipe || TRIM (filename) line
                        FROM xxdo.xxd_hyp_inb_forecast_stg_t
                       WHERE     1 = 1
                             AND rec_status = 'E'
                             AND error_msg IS NOT NULL
                             AND request_id = gn_request_id
                      UNION ALL
                      SELECT 2 AS seq, 'Fiscal Year' || gv_delim_pipe || 'Currency' || gv_delim_pipe || 'Scenario' || gv_delim_pipe || 'Version' || gv_delim_pipe || 'Company' || gv_delim_pipe || 'Brand' || gv_delim_pipe || 'Channel' || gv_delim_pipe || 'Region (Geo)' || gv_delim_pipe || 'Department (Cost Center)' || gv_delim_pipe || 'Account' || gv_delim_pipe || 'Inter-Company' || gv_delim_pipe || 'Future Segment' || gv_delim_pipe || 'Concatenated Segments' || gv_delim_pipe || 'Code Combination ID' || gv_delim_pipe || 'Period Name' || gv_delim_pipe || 'Budget Amount' || gv_delim_pipe || 'Additional Field1' || gv_delim_pipe || 'Additional Field2' || gv_delim_pipe || 'Additional Field3' || gv_delim_pipe || 'Additional Field4' || gv_delim_pipe || 'Additional Field5' || gv_delim_pipe || 'Additional Field6' || gv_delim_pipe || 'Additional Field7' || gv_delim_pipe || 'Additional Field8' || gv_delim_pipe || 'Additional Field9' || gv_delim_pipe || 'Additional Field10' || gv_delim_pipe || 'Additional Field11' || gv_delim_pipe || 'Additional Field12' || gv_delim_pipe || 'Additional Field13' || gv_delim_pipe || 'Additional Field14' || gv_delim_pipe || 'Additional Field15' || gv_delim_pipe || 'Additional Field16' || gv_delim_pipe || 'Additional Field17' || gv_delim_pipe || 'Additional Field18' || gv_delim_pipe || 'Additional Field19' || gv_delim_pipe || 'Additional Field20' || gv_delim_pipe || 'Consumed Flag' || gv_delim_pipe || 'Active Flag' || gv_delim_pipe || 'Rec Status' || gv_delim_pipe || 'Error Msg' || gv_delim_pipe || 'Request ID' || gv_delim_pipe || 'File Name'
                        FROM DUAL)
            ORDER BY seq DESC;

        --DEFINE VARIABLES
        lv_output_file         UTL_FILE.file_type;
        lv_outbound_file       VARCHAR2 (32767);
        lv_err_msg             VARCHAR2 (32767) := NULL;
        lv_line                VARCHAR2 (32767) := NULL;
        lv_directory_path      VARCHAR2 (4000);
        lv_file_name           VARCHAR2 (4000);
        l_line                 VARCHAR2 (32767);
        lv_result              VARCHAR2 (32767);
        buffer_size   CONSTANT INTEGER := 32767;
        lv_period_start_date   DATE;
        lv_period_end_date     DATE;
        lv_outbound_file_zip   VARCHAR2 (32767);
    BEGIN
        write_log_prc (
               'generate_hyp_excep_report_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_directory_path      := NULL;
        lv_outbound_file       := NULL;

        -- Derive the directory Path

        lv_outbound_file       :=
               gn_request_id
            || '_Exception_RPT_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.txt';
        write_log_prc ('Exception File Name is - ' || lv_outbound_file);

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception Occurred white fetch the Exception directory');
                lv_directory_path   := NULL;
        END;

        FOR i IN rep_rec_cur
        LOOP
            l_line   := i.line;
        -- write_log_prc (l_line);
        END LOOP;

        -- WRITE INTO FOLDER

        lv_output_file         :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                    ,
                            buffer_size);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            FOR i IN rep_rec_cur
            LOOP
                lv_line   := i.line;
                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
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

        UTL_FILE.fclose (lv_output_file);
        -- pv_rep_file_name := lv_outbound_file;

        lv_outbound_file_zip   :=
               SUBSTR (lv_outbound_file,
                       1,
                       (INSTR (lv_outbound_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'Exception Report File Name is - ' || lv_outbound_file);
        write_log_prc (
            'Exception Report ZIP File Name is - ' || lv_outbound_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_HYP_FORECAST_EXC_DIR',
            pv_file_name        => lv_outbound_file,
            pv_zip_file_name    => lv_outbound_file_zip);

        --pv_rep_file_name := lv_outbound_file_zip;
        pv_rep_file_name       := lv_outbound_file;

        write_log_prc (
               'generate_hyp_excep_report_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END generate_hyp_excep_report_prc;

       /***************************************************************************
-- PROCEDURE generate_hyp_ccid_report_prc
-- PURPOSE: This Procedure generate the CCID Exception output and place
-- into Exception directory
**************************************************************************/
    PROCEDURE generate_hyp_ccid_report_prc ( --pv_flag                 IN     VARCHAR2,
                                            pv_rep_file_name OUT VARCHAR2)
    IS
        CURSOR rep_rec_cur IS
              SELECT seq, line
                FROM (SELECT 1 AS seq, TRIM (fiscal_year) || gv_delim_pipe || TRIM (currency) || gv_delim_pipe || TRIM (scenario) || gv_delim_pipe || TRIM (version) || gv_delim_pipe || TRIM (company) || gv_delim_pipe || TRIM (brand) || gv_delim_pipe || TRIM (channel) || gv_delim_pipe || TRIM (region) || gv_delim_pipe || TRIM (department) || gv_delim_pipe || TRIM (account) || gv_delim_pipe || TRIM (inter_company) || gv_delim_pipe || TRIM (future_segment) || gv_delim_pipe || TRIM (concatenated_segments) || gv_delim_pipe || TRIM (code_combination_id) || gv_delim_pipe || TRIM (period_name) || gv_delim_pipe || TRIM (budget_amount) || gv_delim_pipe || TRIM (additional_field1) || gv_delim_pipe || TRIM (additional_field2) || gv_delim_pipe || TRIM (additional_field3) || gv_delim_pipe || TRIM (additional_field4) || gv_delim_pipe || TRIM (additional_field5) || gv_delim_pipe || TRIM (additional_field6) || gv_delim_pipe || TRIM (additional_field7) || gv_delim_pipe || TRIM (additional_field8) || gv_delim_pipe || TRIM (additional_field9) || gv_delim_pipe || TRIM (additional_field10) || gv_delim_pipe || TRIM (additional_field11) || gv_delim_pipe || TRIM (additional_field12) || gv_delim_pipe || TRIM (additional_field13) || gv_delim_pipe || TRIM (additional_field14) || gv_delim_pipe || TRIM (additional_field15) || gv_delim_pipe || TRIM (additional_field16) || gv_delim_pipe || TRIM (additional_field17) || gv_delim_pipe || TRIM (additional_field18) || gv_delim_pipe || TRIM (additional_field19) || gv_delim_pipe || TRIM (additional_field20) || gv_delim_pipe || TRIM (consumed_flag) || gv_delim_pipe || TRIM (active_flag) || gv_delim_pipe || TRIM (request_id) || gv_delim_pipe || TRIM (filename) line
                        FROM xxdo.xxd_hyp_inb_forecast_stg_t
                       WHERE     1 = 1
                             AND code_combination_id IS NULL
                             AND request_id = gn_request_id
                      UNION ALL
                      SELECT 2 AS seq, 'Fiscal Year' || gv_delim_pipe || 'Currency' || gv_delim_pipe || 'Scenario' || gv_delim_pipe || 'Version' || gv_delim_pipe || 'Company' || gv_delim_pipe || 'Brand' || gv_delim_pipe || 'Channel' || gv_delim_pipe || 'Region (Geo)' || gv_delim_pipe || 'Department (Cost Center)' || gv_delim_pipe || 'Account' || gv_delim_pipe || 'Inter-Company' || gv_delim_pipe || 'Future Segment' || gv_delim_pipe || 'Concatenated Segments' || gv_delim_pipe || 'Code Combination ID' || gv_delim_pipe || 'Period Name' || gv_delim_pipe || 'Budget Amount' || gv_delim_pipe || 'Additional Field1' || gv_delim_pipe || 'Additional Field2' || gv_delim_pipe || 'Additional Field3' || gv_delim_pipe || 'Additional Field4' || gv_delim_pipe || 'Additional Field5' || gv_delim_pipe || 'Additional Field6' || gv_delim_pipe || 'Additional Field7' || gv_delim_pipe || 'Additional Field8' || gv_delim_pipe || 'Additional Field9' || gv_delim_pipe || 'Additional Field10' || gv_delim_pipe || 'Additional Field11' || gv_delim_pipe || 'Additional Field12' || gv_delim_pipe || 'Additional Field13' || gv_delim_pipe || 'Additional Field14' || gv_delim_pipe || 'Additional Field15' || gv_delim_pipe || 'Additional Field16' || gv_delim_pipe || 'Additional Field17' || gv_delim_pipe || 'Additional Field18' || gv_delim_pipe || 'Additional Field19' || gv_delim_pipe || 'Additional Field20' || gv_delim_pipe || 'Consumed Flag' || gv_delim_pipe || 'Active Flag' || gv_delim_pipe || 'Request ID' || gv_delim_pipe || 'File Name'
                        FROM DUAL)
            ORDER BY seq DESC;

        --DEFINE VARIABLES
        lv_output_file         UTL_FILE.file_type;
        lv_outbound_file       VARCHAR2 (32767);
        lv_err_msg             VARCHAR2 (32767) := NULL;
        lv_line                VARCHAR2 (32767) := NULL;
        lv_directory_path      VARCHAR2 (4000);
        lv_file_name           VARCHAR2 (4000);
        l_line                 VARCHAR2 (32767);
        lv_result              VARCHAR2 (32767);
        buffer_size   CONSTANT INTEGER := 32767;
        lv_period_start_date   DATE;
        lv_period_end_date     DATE;
        lv_outbound_file_zip   VARCHAR2 (1000);
    BEGIN
        write_log_prc (
               'generate_hyp_ccid_report_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_directory_path      := NULL;
        lv_outbound_file       := NULL;

        -- Derive the directory Path

        lv_outbound_file       :=
               gn_request_id
            || '_CCID_RPT_'
            || TO_CHAR (SYSDATE, 'DDMMRRRRHH24MISS')
            || '.txt';
        write_log_prc ('CCID Exception File Name is - ' || lv_outbound_file);

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                write_log_prc (
                    'Exception Occurred white fetch the Exception directory');
                lv_directory_path   := NULL;
        END;

        FOR i IN rep_rec_cur
        LOOP
            l_line   := i.line;
        -- write_log_prc (l_line);
        END LOOP;

        -- WRITE INTO FOLDER

        lv_output_file         :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                    ,
                            buffer_size);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            FOR i IN rep_rec_cur
            LOOP
                lv_line   := i.line;
                UTL_FILE.put_line (lv_output_file, lv_line);
            END LOOP;
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

        UTL_FILE.fclose (lv_output_file);

        lv_outbound_file_zip   :=
               SUBSTR (lv_outbound_file,
                       1,
                       (INSTR (lv_outbound_file, '.', -1) - 1))
            || '.zip';
        write_log_prc (
            'Exception Report File Name is - ' || lv_outbound_file);
        write_log_prc (
            'Exception Report ZIP File Name is - ' || lv_outbound_file_zip);

        create_final_zip_prc (
            pv_directory_name   => 'XXD_HYP_FORECAST_EXC_DIR',
            pv_file_name        => lv_outbound_file,
            pv_zip_file_name    => lv_outbound_file_zip);

        --pv_rep_file_name := lv_outbound_file_zip;
        pv_rep_file_name       := lv_outbound_file;

        write_log_prc (
               'generate_hyp_ccid_report_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg   := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log_prc (lv_err_msg);
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
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
            --x_ret_code := gn_error;
            --x_ret_message := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END generate_hyp_ccid_report_prc;


    /**************************************************************************
    -- PROCEDURE purge_hyperion_int_prc
    -- PURPOSE: This Procedure Purge the Hyperion Interface Tables Data.
    ***************************************************************************/
    PROCEDURE purge_hyperion_int_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_num_days IN NUMBER)
    IS
        ln_days   NUMBER;
    BEGIN
        write_log_prc (
               'purge_hyperion_int_prc Begins...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        ln_days   := NVL (pv_num_days, 0);
        write_log_prc (
            'Number Of Days to Retain, Set to: ' || ln_days || ' Days');

        write_log_prc (
            'Delete Hyperion Interface Tables Data Based on Purge Parameter:');
        write_log_prc (
            '---------------------------------------------------------------');

        DELETE XXDO.XXD_HYP_INB_FORECAST_STG_T
         WHERE TRUNC (creation_date) <= (TRUNC (SYSDATE) - ln_days);

        write_log_prc (
               SQL%ROWCOUNT
            || ' Rows Deleted from XXDO.XXD_HYP_INB_FORECAST_STG_T Table');

        COMMIT;

        write_log_prc (
               'purge_hyperion_int_prc Ends...'
            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Exception Occured in Purge Procedure-' || SQLERRM);
            retcode   := gn_error;
    END purge_hyperion_int_prc;

     /***************************************************************************
-- PROCEDURE main_prc
-- PURPOSE: This Procedure is Concurrent Program.
****************************************************************************/
    PROCEDURE main_prc (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_gen_rep IN VARCHAR2, pv_dummy IN VARCHAR2, pv_period_from IN VARCHAR2, pv_period_to IN VARCHAR2
                        , pv_consumed IN VARCHAR2, pv_override IN VARCHAR2)
    IS
        CURSOR get_file_cur IS
              SELECT filename
                FROM xxd_dir_list_tbl_syn
               WHERE 1 = 1 AND UPPER (filename) LIKE UPPER ('Hyperion%')
            ORDER BY filename;

        CURSOR c_write_errors_cur IS
              SELECT error_msg, COUNT (1) err_cnt
                FROM xxdo.xxd_hyp_inb_forecast_stg_t
               WHERE     rec_status = 'E'
                     AND error_msg IS NOT NULL
                     AND request_id = gn_request_id
            GROUP BY error_msg;

        lv_inb_directory_path   VARCHAR2 (1000);
        lv_arc_directory_path   VARCHAR2 (1000);
        lv_exc_directory_path   VARCHAR2 (1000);
        lv_rep_directory_path   VARCHAR2 (1000);
        lv_directory            VARCHAR2 (1000);
        lv_file_name            VARCHAR2 (1000);
        --lv_rep_file_name        VARCHAR2 (1000);
        lv_hyp_rep_file_name    VARCHAR2 (1000);
        lv_excp_rep_file_name   VARCHAR2 (1000);
        lv_ccid_rep_file_name   VARCHAR2 (1000);
        lv_ret_message          VARCHAR2 (4000) := NULL;
        lv_ret_code             VARCHAR2 (30) := NULL;
        ln_file_exists          NUMBER;
        lv_line                 VARCHAR2 (32767) := NULL;
        lv_all_file_names       VARCHAR2 (4000) := NULL;
        ln_rec_fail             NUMBER := 0;
        ln_rec_success          NUMBER;
        ln_rec_total            NUMBER;
        lv_mail_delimiter       VARCHAR2 (1) := '/';
        lv_result               VARCHAR2 (100);
        lv_result_msg           VARCHAR2 (4000);
        lv_message1             VARCHAR2 (32000);
        lv_message2             VARCHAR2 (32000);
        lv_message3             VARCHAR2 (32000);
        lv_message4             VARCHAR2 (32000);
        lv_message5             VARCHAR2 (32000);
        lv_sender               VARCHAR2 (100);
        lv_recipients           VARCHAR2 (4000);
        lv_ccrecipients         VARCHAR2 (4000);
        l_cnt                   NUMBER := 0;
        ln_req_id               NUMBER;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lb_wait_req             BOOLEAN;
        lv_message              VARCHAR2 (1000);
        lv_flag                 VARCHAR2 (1);
        lv_code_comb_cnt        NUMBER;
        lv_attachments          VARCHAR2 (1000);
    BEGIN
        write_log_prc (
            'Main_prc Begins...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
        lv_hyp_rep_file_name    := NULL;
        lv_excp_rep_file_name   := NULL;
        lv_ccid_rep_file_name   := NULL;
        lv_file_name            := NULL;

        -- Derive the directory Path

        BEGIN
            lv_inb_directory_path   := NULL;
            lv_directory            := 'XXD_HYP_FORECAST_INB_DIR';

            SELECT directory_path
              INTO lv_inb_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_inb_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Inbound Directory');
        END;

        BEGIN
            lv_arc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Archive Directory');
        END;


        BEGIN
            lv_exc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_exc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Exception Directory');
        END;

        BEGIN
            lv_rep_directory_path   := NULL;

            SELECT directory_path
              INTO lv_rep_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_HYP_FORECAST_REP_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_rep_directory_path   := NULL;
                write_log_prc (
                    ' Exception Occurred while retriving the Report Directory');
        END;

        -- Now Get the file names
        get_file_names (lv_inb_directory_path);

        FOR data IN get_file_cur
        LOOP
            ln_file_exists   := 0;
            lv_file_name     := NULL;
            lv_file_name     := data.filename;

            write_log_prc (' File is availale - ' || lv_file_name);

            -- Check the file name exists in the table if exists then SKIP

            BEGIN
                SELECT COUNT (1)
                  INTO ln_file_exists
                  FROM xxdo.xxd_hyp_inb_forecast_stg_t
                 WHERE 1 = 1 AND UPPER (filename) = UPPER (lv_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_file_exists   := 0;
            END;

            IF ln_file_exists = 0
            THEN
                load_file_into_tbl_prc (pv_table => 'XXD_HYP_INB_FORECAST_STG_T', pv_dir => 'XXD_HYP_FORECAST_INB_DIR', pv_filename => lv_file_name, pv_ignore_headerlines => 1, pv_delimiter => '|', pv_optional_enclosed => '"'
                                        , pv_num_of_columns => 32); -- Change the number of columns

                BEGIN
                    UPDATE xxdo.xxd_hyp_inb_forecast_stg_t
                       SET filename = lv_file_name, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id,
                           rec_status = 'N'
                     WHERE 1 = 1 AND filename IS NULL AND request_id IS NULL;

                    write_log_prc (
                           SQL%ROWCOUNT
                        || ' Records updated with Filename, Request ID and WHO Columns');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                               'Error Occured while Updating the Filename, Request ID and WHO Columns-'
                            || SQLERRM);
                END;

                COMMIT;

                validate_prc (lv_file_name);

                BEGIN
                    write_log_prc (
                           'Move files Process Begins...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));

                    ln_req_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXDO_CP_MV_RM_FILE',
                            argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                            argument2     => 2,
                            argument3     =>
                                lv_inb_directory_path || '/' || lv_file_name, -- Source File Directory
                            argument4     =>
                                   lv_arc_directory_path
                                || '/'
                                || SYSDATE
                                || '_'
                                || lv_file_name, -- Destination File Directory
                            start_time    => SYSDATE,
                            sub_request   => FALSE);
                    COMMIT;

                    IF ln_req_id = 0
                    THEN
                        retcode   := gn_warning;
                        write_log_prc (
                            ' Unable to submit move files concurrent program ');
                    ELSE
                        write_log_prc (
                            'Move Files concurrent request submitted successfully.');
                        lb_wait_req   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_req_id,
                                interval     => 5,
                                phase        => lv_phase,
                                status       => lv_status,
                                dev_phase    => lv_dev_phase,
                                dev_status   => lv_dev_status,
                                MESSAGE      => lv_message);

                        IF     lv_dev_phase = 'COMPLETE'
                           AND lv_dev_status = 'NORMAL'
                        THEN
                            write_log_prc (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' completed with NORMAL status.');
                        ELSE
                            retcode   := gn_warning;
                            write_log_prc (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' did not complete with NORMAL status.');
                        END IF; -- End of if to check if the status is normal and phase is complete
                    END IF;          -- End of if to check if request ID is 0.

                    COMMIT;
                    write_log_prc (
                           'Move Files Ends...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        retcode   := gn_error;
                        write_log_prc ('Error in Move Files -' || SQLERRM);
                END;
            ELSIF ln_file_exists > 0
            THEN
                write_log_prc (
                    '**************************************************************************************************');
                write_log_prc (
                       'Data with this File name - '
                    || lv_file_name
                    || ' - is already loaded. Please change the file data.  ');
                write_log_prc (
                    '**************************************************************************************************');
                retcode   := gn_warning;

                BEGIN
                    write_log_prc (
                           'Move files Process Begins...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                    ln_req_id   :=
                        fnd_request.submit_request (
                            application   => 'XXDO',
                            program       => 'XXDO_CP_MV_RM_FILE',
                            argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                            argument2     => 2,
                            argument3     =>
                                lv_inb_directory_path || '/' || lv_file_name, -- Source File Directory
                            argument4     =>
                                   lv_arc_directory_path
                                || '/'
                                || SYSDATE
                                || '_'
                                || lv_file_name, -- Destination File Directory
                            start_time    => SYSDATE,
                            sub_request   => FALSE);
                    COMMIT;

                    IF ln_req_id = 0
                    THEN
                        retcode   := gn_warning;
                        write_log_prc (
                            ' Unable to submit move files concurrent program ');
                    ELSE
                        write_log_prc (
                            'Move Files concurrent request submitted successfully.');
                        lb_wait_req   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => ln_req_id,
                                interval     => 5,
                                phase        => lv_phase,
                                status       => lv_status,
                                dev_phase    => lv_dev_phase,
                                dev_status   => lv_dev_status,
                                MESSAGE      => lv_message);

                        IF     lv_dev_phase = 'COMPLETE'
                           AND lv_dev_status = 'NORMAL'
                        THEN
                            write_log_prc (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' completed with NORMAL status.');
                        ELSE
                            retcode   := gn_warning;
                            write_log_prc (
                                   'Move Files concurrent request with the request id '
                                || ln_req_id
                                || ' did not complete with NORMAL status.');
                        END IF; -- End of if to check if the status is normal and phase is complete
                    END IF;          -- End of if to check if request ID is 0.

                    COMMIT;
                    write_log_prc (
                           'Move Files Ends...'
                        || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        write_log_prc (
                               'File already exists, Error Occured while Copying/Removing file from Inbound directory, Check File Privileges: '
                            || SQLERRM);
                        retcode   := gn_warning;
                END;
            END IF;

            EXIT WHEN get_file_cur%NOTFOUND;
        END LOOP;

        COMMIT;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_fail
              FROM xxdo.xxd_hyp_inb_forecast_stg_t
             WHERE     1 = 1
                   AND rec_status = 'E'
                   AND error_msg IS NOT NULL
                   AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_fail   := 0;
                write_log_prc (
                    'Exception Occurred while retriving the Error Count');
        END;

        IF ln_file_exists IS NULL
        THEN
            write_log_prc ('There is nothing to Process...No File Exists.');
            retcode   := gn_warning;
        ELSE
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_hyp_inb_forecast_stg_t
             WHERE request_id = gn_request_id;

            ln_rec_success   := ln_rec_total - ln_rec_fail;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '                                                                      Deckers Hyperion Inbound Forecast Program');
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
            apps.fnd_file.put_line (apps.fnd_file.output, '');
        END IF;

        IF NVL (pv_gen_rep, 'No') = 'Yes'
        THEN
            lv_message1   := NULL;
            lv_flag       := 'Y';
            generate_hyperion_report_prc (pv_period_from, pv_period_to, pv_consumed
                                          , --pv_override,
                                            lv_hyp_rep_file_name);

            lv_hyp_rep_file_name   :=
                   lv_rep_directory_path
                || lv_mail_delimiter
                || lv_hyp_rep_file_name;
            write_log_prc (lv_hyp_rep_file_name);

            -- IF NVL (pv_send_mail,'N') = 'Y'
            -- THEN
            lv_message1   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please Find the Attached Deckers Hyperion Inbound Forecast Report'
                || '.'
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            SELECT LISTAGG (ffvl.description, ';') WITHIN GROUP (ORDER BY ffvl.description)
              INTO lv_recipients
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_HYPERION_EMAIL_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y';

            xxdo_mail_pkg.send_mail (
                pv_sender         => 'erp@deckers.com',
                pv_recipients     => lv_recipients,
                pv_ccrecipients   => lv_ccrecipients,
                pv_subject        =>
                    'Deckers Hyperion Inbound Forecast Report',
                pv_message        => lv_message1,
                pv_attachments    => lv_hyp_rep_file_name,
                xv_result         => lv_result,
                xv_result_msg     => lv_result_msg);

            write_log_prc (lv_result);
            write_log_prc (lv_result_msg);
        -- END IF;

        END IF;

        BEGIN
            lv_code_comb_cnt   := 0;

            SELECT COUNT (1) --||'.'||CHR(9)||'Code Combination Not Available'
              INTO lv_code_comb_cnt
              FROM xxdo.xxd_hyp_inb_forecast_stg_t
             WHERE code_combination_id IS NULL AND request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_code_comb_cnt   := 0;
                write_log_prc (
                    'No Records exists with Code Combination Is NULL');
        END;

        IF ln_rec_fail > 0 OR lv_code_comb_cnt > 0
        THEN
            lv_flag       := 'N';
            lv_message1   := NULL;
            lv_message2   := NULL;
            lv_message3   := NULL;
            lv_message4   := NULL;
            lv_message5   := NULL;

            IF ln_rec_fail > 0
            THEN
                generate_hyp_excep_report_prc (lv_excp_rep_file_name);
                lv_excp_rep_file_name   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_excp_rep_file_name;
                write_log_prc (lv_excp_rep_file_name);
            END IF;

            IF lv_code_comb_cnt > 0
            THEN
                generate_hyp_ccid_report_prc (lv_ccid_rep_file_name);
                lv_ccid_rep_file_name   :=
                       lv_exc_directory_path
                    || lv_mail_delimiter
                    || lv_ccid_rep_file_name;
                write_log_prc (lv_ccid_rep_file_name);

                BEGIN
                    SELECT COUNT (1) || '.' || CHR (9) || 'Code Combination Not Available'
                      INTO lv_message4
                      FROM xxdo.xxd_hyp_inb_forecast_stg_t
                     WHERE     code_combination_id IS NULL
                           AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_message4   := NULL;
                        write_log_prc (
                            'No Records exists with Code Combination Is NULL');
                END;
            END IF;

            -- IF NVL (pv_send_mail,'N') = 'Y'
            -- THEN

            lv_message2   :=
                   '************************************************************************'
                || CHR (10)
                || ' Number of Rows Considered into Inbound Staging Table - '
                || ln_rec_total
                || '.'
                || CHR (10)
                || ' Number of Rows Errored - '
                || ln_rec_fail
                || '.'
                || CHR (10)
                || ' Number of Rows Successful - '
                || ln_rec_success
                || '.'
                || CHR (10)
                || '************************************************************************'
                || CHR (10)
                || CHR (10)
                || 'Distinct Error Messages :'
                || CHR (10)
                || '========================='
                || CHR (10)
                || 'Count'
                || CHR (9)
                || 'Error Message'
                || CHR (10)
                || '-----------------------------------------------------------------';

            FOR i IN c_write_errors_cur
            LOOP
                lv_message3   :=
                    CASE
                        WHEN lv_message3 IS NOT NULL
                        THEN
                               lv_message3
                            || '.'
                            || CHR (10)
                            || i.err_cnt
                            || '.'
                            || CHR (9)
                            || i.error_msg
                        ELSE
                            i.err_cnt || '.' || CHR (9) || i.error_msg
                    END;
            END LOOP;

            IF lv_message4 IS NOT NULL
            THEN
                lv_message5   :=
                    SUBSTR (lv_message3 || CHR (10) || lv_message4, 1, 30000);
            ELSIF lv_message4 IS NULL
            THEN
                lv_message5   := SUBSTR (lv_message3, 1, 30000);
            END IF;

            lv_message1   :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please Find the Attached Deckers Hyperion Inbound Forecast Exception Report. '
                || CHR (10)
                || CHR (10)
                || lv_message2
                || CHR (10)
                || lv_message5
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            SELECT LISTAGG (ffvl.description, ';') WITHIN GROUP (ORDER BY ffvl.description)
              INTO lv_recipients
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'XXD_HYPERION_EMAIL_VS'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y';

            lv_attachments   :=
                lv_excp_rep_file_name || ';' || lv_ccid_rep_file_name;
            --lv_attachments := lv_ccid_rep_file_name;

            xxdo_mail_pkg.send_mail (
                pv_sender         => 'erp@deckers.com',
                pv_recipients     => lv_recipients,
                pv_ccrecipients   => lv_ccrecipients,
                pv_subject        =>
                    'Deckers Hyperion Inbound Forecast Exception Report',
                pv_message        => lv_message1,
                pv_attachments    => lv_attachments,
                xv_result         => lv_result,
                xv_result_msg     => lv_result_msg);

            write_log_prc (lv_result);
            write_log_prc (lv_result_msg);
        -- END IF;
        END IF;

        write_log_prc (
            'Main_prc Ends...' || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
    EXCEPTION
        WHEN OTHERS
        THEN
            errbuf    := SQLERRM;
            retcode   := gn_error;
            write_log_prc (
                'Error Occured in Procedure main_prc: ' || SQLERRM);
    END main_prc;
END xxd_hyp_inb_forecast_pkg;
/
