--
-- XXD_RMS_LMT_BAL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_RMS_LMT_BAL_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_RMS_LMT_BAL_PKG
     REPORT NAME    : Deckers Lucernex Balances to Black Line

     REVISIONS:
     Date        Author             Version  Description
     ----------  ----------         -------  ---------------------------------------------------
     10-JUN-2021 Srinath Siricilla  1.0      Created this package using XXD_RMS_LMT_BAL_PKG
                                             for sending the report output to BlackLine
    *********************************************************************************************/

    --Global constants
    -- Return Statuses
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
    gv_delimeter                  VARCHAR2 (1) := '|';


    PROCEDURE write_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000) := pv_msg;
    BEGIN
        IF gn_user_id = -1
        THEN
            write_log (pv_msg);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, pv_msg);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error in WRITE_LOG Procedure -' || SQLERRM);
            write_log ('Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

    FUNCTION xxd_remove_junk_fnc (p_input IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_output   VARCHAR2 (32767) := NULL;
    BEGIN
        IF p_input IS NOT NULL
        THEN
            SELECT REPLACE (REPLACE (REPLACE (REPLACE (p_input, CHR (9), ''), CHR (10), ''), '|', ' '), CHR (13), '')
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

    PROCEDURE purge_prc (pn_purge_days IN NUMBER)
    IS
        CURSOR purge_cur IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_rms_lmt_asset_stg_t stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);
    BEGIN
        FOR purge_rec IN purge_cur
        LOOP
            DELETE FROM xxdo.xxd_rms_lmt_asset_stg_t
                  WHERE 1 = 1 AND request_id = purge_rec.request_id;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in Purge Procedure -' || SQLERRM);
    END purge_prc;

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'XXD_UTL_FILE_LIST.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2 DEFAULT 'XXD_LCX_BAL_BL_INB_DIR', p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
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
        l_input       UTL_FILE.file_type;

        l_lastLine    VARCHAR2 (4000);
        l_cnames      VARCHAR2 (4000);
        l_bindvars    VARCHAR2 (4000);
        l_status      INTEGER;
        l_cnt         NUMBER DEFAULT 0;
        l_rowCount    NUMBER DEFAULT 0;
        l_sep         CHAR (1) DEFAULT NULL;
        L_ERRMSG      VARCHAR2 (4000);
        V_EOF         BOOLEAN := FALSE;
        l_theCursor   NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert      VARCHAR2 (1100);
    BEGIN
        l_cnt        := 1;

        FOR TAB_COLUMNS
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
        L_BINDVARS   := RTRIM (L_BINDVARS, ',');

        -- write_log ('Count of Columns is - ' || l_cnt);
        write_log ('Count of Columns is - ' || l_cnt);


        L_INPUT      := UTL_FILE.FOPEN (P_DIR, P_FILENAME, 'r');

        IF p_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. p_ignore_headerlines
                LOOP
                    -- write_log ('No of lines Ignored is - ' || i);
                    write_log ('No of lines Ignored is - ' || i);
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
            || p_table
            || '('
            || l_cnames
            || ') values ('
            || l_bindvars
            || ')';

        --        write_log (l_theCursor || 'cursor' || l_bindvars || '---' || l_cnames);

        IF NOT v_eof
        THEN
            /*write_log (
                   l_theCursor
                || '-'
                || 'insert into '
                || p_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')'); */

            write_log (
                   l_theCursor
                || '-'
                || 'insert into '
                || p_table
                || '('
                || l_cnames
                || ') values ('
                || l_bindvars
                || ')');
            --dbms_sql.parse( l_theCursor, 'insert into ' || p_table || '(' || l_cnames || ') values (' || l_bindvars || ');' dbms_sql.native );
            DBMS_SQL.parse (l_theCursor, v_insert, DBMS_SQL.native);

            --            write_log (112);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastLine);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        EXIT;
                END;

                --            l_buffer := l_lastLine || p_delimiter;

                --                write_log ('LENGTH (l_lastLine) - ' || LENGTH (l_lastLine));

                IF LENGTH (l_lastLine) > 0
                THEN
                    FOR i IN 1 .. l_cnt - 1
                    LOOP
                        --                        write_log (
                        --                               ' Value is - '
                        --                            || SUBSTR (l_lastline,
                        --                                       1,
                        --                                       INSTR (l_lastline, p_delimiter) - 1));
                        --                        write_log (
                        --                               ' Value is - '
                        --                            || RTRIM (
                        --                                   RTRIM (
                        --                                       LTRIM (
                        --                                           LTRIM (
                        --                                               REGEXP_SUBSTR (
                        --                                                   l_lastline,
                        --                                                   '(^|,)("[^"]*"|[^",]*)',
                        --                                                   1,
                        --                                                   i),
                        --                                               p_delimiter),
                        --                                           p_optional_enclosed),
                        --                                       p_delimiter),
                        --                                   p_optional_enclosed));
                        --                    DBMS_SQL.bind_variable (
                        --                            l_theCursor,
                        --                            ':b' || i,
                        --                            SUBSTR (l_buffer, 1, INSTR (l_buffer, p_delimiter) - 1));
                        --                        l_buffer := SUBSTR (l_buffer, INSTR (l_buffer, p_delimiter) + 1);
                        --
                        --                        write_log (
                        --                            ' l_buffer Buffer Statement in the loop is - ' || l_buffer);
                        --                        write_log (
                        --                               ' l_theCursor Buffer Statement in the loop is - '
                        --                            || l_theCursor);
                        DBMS_SQL.bind_variable (
                            l_theCursor,
                            ':b' || i,
                            xxd_remove_junk_fnc (
                                RTRIM (
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', 1
                                                                        , i),
                                                         p_delimiter),
                                                  p_optional_enclosed),
                                           p_delimiter),
                                    p_optional_enclosed)));
                    END LOOP;

                    BEGIN
                        l_status     := DBMS_SQL.execute (l_theCursor);

                        l_rowCount   := l_rowCount + 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            L_ERRMSG   := SQLERRM;
                    -- insert into BADLOG ( TABLE_NAME, ERRM, data, ERROR_DATE )
                    -- values ( P_TABLE,l_errmsg, l_lastLine ,systimestamp );
                    END;
                END IF;
            END LOOP;

            DBMS_SQL.close_cursor (l_theCursor);
            UTL_FILE.fclose (l_input);
        -- commit;
        END IF;
    -- insert into IMPORT_HIST (FILENAME,TABLE_NAME,NUM_OF_REC,IMPORT_DATE)
    -- values ( P_FILENAME, P_TABLE,l_rowCount,sysdate );
    --        write_log (P_DIR || '-' || P_FILENAME);    --added by Akash
    --RETURN L_ROWCOUNT;
    END load_file_into_tbl;

    PROCEDURE CopyFile_prc (p_in_filename IN VARCHAR2, p_out_filename IN VARCHAR2, p_src_dir VARCHAR2
                            , p_dest_dir VARCHAR2)
    IS
        in_file                UTL_FILE.FILE_TYPE;
        out_file               UTL_FILE.FILE_TYPE;

        buffer_size   CONSTANT INTEGER := 32767;    -- Max Buffer Size = 32767
        buffer                 RAW (32767);
        buffer_length          INTEGER;
    BEGIN
        -- Open a handle to the location where you are going to read the Text or Binary file from
        -- NOTE: The 'rb' parameter means "read in byte mode" and is only available

        in_file         :=
            UTL_FILE.FOPEN (p_src_dir, p_in_filename, 'rb',
                            buffer_size);

        -- Open a handle to the location where you are going to write the Text or Binary file to
        -- NOTE: The 'wb' parameter means "write in byte mode" and is only available

        out_file        :=
            UTL_FILE.FOPEN (p_dest_dir, p_out_filename, 'wb',
                            buffer_size);

        -- Attempt to read the first chunk of the in_file
        UTL_FILE.GET_RAW (in_file, buffer, buffer_size);

        -- Determine the size of the first chunk read
        buffer_length   := UTL_RAW.LENGTH (buffer);

        -- Only write the chunk to the out_file if data exists
        WHILE buffer_length > 0
        LOOP
            -- Write one chunk of data
            UTL_FILE.PUT_RAW (out_file, buffer, TRUE);

            -- Read the next chunk of data
            IF buffer_length = buffer_size
            THEN
                -- Buffer was full on last read, read another chunk
                UTL_FILE.GET_RAW (in_file, buffer, buffer_size);
                -- Determine the size of the current chunk
                buffer_length   := UTL_RAW.LENGTH (buffer);
            ELSE
                buffer_length   := 0;
            END IF;
        END LOOP;

        -- Close the file handles
        UTL_FILE.FCLOSE (in_file);
        UTL_FILE.FCLOSE (out_file);
    EXCEPTION
        -- Raised when the size of the file is a multiple of the buffer_size
        WHEN NO_DATA_FOUND
        THEN
            -- Close the file handles
            UTL_FILE.FCLOSE (in_file);
            UTL_FILE.FCLOSE (out_file);
    END;

    PROCEDURE process_data_prc (PV_TYPE IN VARCHAR2)
    IS
        CURSOR cur_data IS
              SELECT portfolio, contract_name, currency_type,
                     fiscal_period_year, fiscal_period, cum_period_num,
                     sum_begin_date, SUM (NVL (begin_bal, 0)), SUM (NVL (initial_asset_bal_act, 0)),
                     SUM (NVL (inactive_amount, 0)), SUM (NVL (period_asset_amort_exp, 0)), SUM (NVL (closing_bal, 0)),
                     SUM (NVL (accumulated_amort, 0)) accumulated_amort, --                       SUM(NVL(initial_asset_bal,0)) initial_asset_bal
                                                                         SUM (NVL (REPLACE (initial_asset_bal, CHR (13), ''), 0)) initial_asset_bal
                FROM xxdo.xxd_rms_lmt_asset_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY portfolio, contract_name, currency_type,
                     fiscal_period_year, fiscal_period, cum_period_num,
                     sum_begin_date;

        CURSOR cur_lmt_ret_data IS
              SELECT portfolio, NAME, effective_date,
                     due_date, coverage_begin_date, coverage_end_date,
                     currency_type, expense_group, expense_type,
                     expense_category, ar_tracking, SUM (NVL (REPLACE (invoice_amount, '$', ''), 0)) invoice_amount,
                     vendor, approval_status, processed
                FROM xxdo.xxd_rms_lmt_ret_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY portfolio, NAME, effective_date,
                     due_date, coverage_begin_date, coverage_end_date,
                     currency_type, expense_group, expense_type,
                     expense_category, ar_tracking, vendor,
                     approval_status, processed;

        CURSOR cur_lmt_lia_data IS
              SELECT portfolio, contract_name, currency_type,
                     fiscal_period_year, fiscal_period, cum_period_num,
                     sum_begin_date, SUM (NVL (begin_bal, 0)), SUM (NVL (initial_liability_bal_act, 0)),
                     SUM (NVL (inactive_amount, 0)), SUM (NVL (period_liability_amort_exp, 0)), SUM (NVL (closing_bal, 0)),
                     SUM (NVL (short_term, 0)) short_term, SUM (NVL (REPLACE (long_term, CHR (13), ''), 0)) long_term
                FROM xxdo.xxd_rms_lmt_liability_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY portfolio, contract_name, currency_type,
                     fiscal_period_year, fiscal_period, cum_period_num,
                     sum_begin_date;

        CURSOR cur_ret_lia_data IS
              SELECT SUM (TO_NUMBER (NVL (REPLACE (REPLACE (ret.invoice_amount, '$', ''), ',', ''), 0))) invoice_amount, lia.contract_name contract_name, TO_NUMBER (lia.short_term) short_term,
                     TO_NUMBER (lia.long_term) long_term
                FROM xxdo.xxd_rms_lmt_liability_stg_t lia, xxdo.xxd_rms_lmt_ret_stg_t ret
               WHERE     1 = 1
                     --               AND  ret.request_id = lia.request_id
                     --               AND  ret.name = lia.contract_name
                     AND ret.request_id(+) = lia.request_id
                     --               AND  lia.request_id = 267715144
                     AND ret.name(+) = lia.contract_name
                     AND lia.request_id = gn_request_id
            GROUP BY lia.contract_name, TO_NUMBER (lia.short_term), TO_NUMBER (lia.long_term);

        lv_acc_seg1        gl_code_combinations_kfv.segment1%TYPE;
        lv_acc_seg2        gl_code_combinations_kfv.segment2%TYPE;
        lv_acc_seg3        gl_code_combinations_kfv.segment3%TYPE;
        lv_acc_seg4        gl_code_combinations_kfv.segment4%TYPE;
        lv_acc_seg5        gl_code_combinations_kfv.segment5%TYPE;
        lv_acc_seg6        gl_code_combinations_kfv.segment6%TYPE;
        lv_acc_seg7        gl_code_combinations_kfv.segment7%TYPE;
        lv_ini_seg1        gl_code_combinations_kfv.segment1%TYPE;
        lv_ini_seg2        gl_code_combinations_kfv.segment2%TYPE;
        lv_ini_seg3        gl_code_combinations_kfv.segment3%TYPE;
        lv_ini_seg4        gl_code_combinations_kfv.segment4%TYPE;
        lv_ini_seg5        gl_code_combinations_kfv.segment5%TYPE;
        lv_ini_seg6        gl_code_combinations_kfv.segment6%TYPE;
        lv_ini_seg7        gl_code_combinations_kfv.segment7%TYPE;
        lv_acc_code_comb   gl_code_combinations_kfv.concatenated_segments%TYPE;
        lv_ini_code_comb   gl_code_combinations_kfv.concatenated_segments%TYPE;

        lv_st_seg1         gl_code_combinations_kfv.segment1%TYPE;
        lv_st_seg2         gl_code_combinations_kfv.segment2%TYPE;
        lv_st_seg3         gl_code_combinations_kfv.segment3%TYPE;
        lv_st_seg4         gl_code_combinations_kfv.segment4%TYPE;
        lv_st_seg5         gl_code_combinations_kfv.segment5%TYPE;
        lv_st_seg6         gl_code_combinations_kfv.segment6%TYPE;
        lv_st_seg7         gl_code_combinations_kfv.segment7%TYPE;
        lv_lt_seg1         gl_code_combinations_kfv.segment1%TYPE;
        lv_lt_seg2         gl_code_combinations_kfv.segment2%TYPE;
        lv_lt_seg3         gl_code_combinations_kfv.segment3%TYPE;
        lv_lt_seg4         gl_code_combinations_kfv.segment4%TYPE;
        lv_lt_seg5         gl_code_combinations_kfv.segment5%TYPE;
        lv_lt_seg6         gl_code_combinations_kfv.segment6%TYPE;
        lv_lt_seg7         gl_code_combinations_kfv.segment7%TYPE;
        lv_st_code_comb    gl_code_combinations_kfv.concatenated_segments%TYPE;
        lv_lt_code_comb    gl_code_combinations_kfv.concatenated_segments%TYPE;

        ln_st_reclass      NUMBER;
        ln_lt_reclass      NUMBER;
        ln_st_lia_adj      NUMBER;
        ln_lt_lia_adj      NUMBER;
    BEGIN
        IF pv_type = 'ASSET'
        THEN
            FOR data_rec IN cur_data
            LOOP
                lv_ini_seg1        := NULL;
                lv_ini_seg2        := NULL;
                lv_ini_seg3        := NULL;
                lv_ini_seg4        := NULL;
                lv_ini_seg5        := NULL;
                lv_ini_seg6        := NULL;
                lv_ini_seg7        := NULL;
                lv_acc_seg1        := NULL;
                lv_acc_seg2        := NULL;
                lv_acc_seg3        := NULL;
                lv_acc_seg4        := NULL;
                lv_acc_seg5        := NULL;
                lv_acc_seg6        := NULL;
                lv_acc_seg7        := NULL;
                lv_acc_code_comb   := NULL;
                lv_ini_code_comb   := NULL;

                -- Get the GL Code Combination

                IF data_rec.accumulated_amort IS NOT NULL
                THEN
                    BEGIN
                        lv_acc_seg1        := NULL;
                        lv_acc_seg2        := NULL;
                        lv_acc_seg3        := NULL;
                        lv_acc_seg4        := NULL;
                        lv_acc_seg5        := NULL;
                        lv_acc_seg6        := NULL;
                        lv_acc_seg7        := NULL;
                        lv_acc_code_comb   := NULL;

                        SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                               ffv.attribute6, ffv.attribute7, ffv.attribute18,
                               ffv.attribute13
                          INTO lv_acc_seg1, lv_acc_seg2, lv_acc_seg3, lv_acc_seg4,
                                          lv_acc_seg5, lv_acc_seg6, lv_acc_seg7
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                         WHERE     ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_LCX_CONTRACT_NAMES_VS'
                               AND ffv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffv.end_date_active,
                                                        SYSDATE)
                               AND ffv.attribute3 = data_rec.contract_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                lv_acc_seg1        := NULL;
                                lv_acc_seg2        := NULL;
                                lv_acc_seg3        := NULL;
                                lv_acc_seg4        := NULL;
                                lv_acc_seg5        := NULL;
                                lv_acc_seg6        := NULL;
                                lv_acc_seg7        := NULL;
                                lv_acc_code_comb   := NULL;

                                SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                                       ffv.attribute6, ffv.attribute7, ffv.attribute18,
                                       ffv.attribute13
                                  INTO lv_acc_seg1, lv_acc_seg2, lv_acc_seg3, lv_acc_seg4,
                                                  lv_acc_seg5, lv_acc_seg6, lv_acc_seg7
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                                 WHERE     ffvs.flex_value_set_id =
                                           ffv.flex_value_set_id
                                       AND ffvs.flex_value_set_name =
                                           'XXD_LCX_CONTRACT_NAMES_NEW_VS'
                                       AND ffv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffv.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffv.end_date_active,
                                                               SYSDATE)
                                       AND ffv.attribute3 =
                                           data_rec.contract_name;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_acc_seg1        := NULL;
                                    lv_acc_seg2        := NULL;
                                    lv_acc_seg3        := NULL;
                                    lv_acc_seg4        := NULL;
                                    lv_acc_seg5        := NULL;
                                    lv_acc_seg6        := NULL;
                                    lv_acc_seg7        := NULL;
                                    lv_acc_code_comb   := NULL;
                            END;
                    END;
                END IF;

                lv_acc_code_comb   :=
                       lv_acc_seg1
                    || '.'
                    || lv_acc_seg2
                    || '.'
                    || lv_acc_seg3
                    || '.'
                    || lv_acc_seg4
                    || '.'
                    || lv_acc_seg5
                    || '.'
                    || lv_acc_seg6
                    || '.'
                    || lv_acc_seg7;

                IF data_rec.initial_asset_bal IS NOT NULL
                THEN
                    BEGIN
                        lv_ini_seg1   := NULL;
                        lv_ini_seg2   := NULL;
                        lv_ini_seg3   := NULL;
                        lv_ini_seg4   := NULL;
                        lv_ini_seg5   := NULL;
                        lv_ini_seg6   := NULL;
                        lv_ini_seg7   := NULL;

                        SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                               ffv.attribute6, ffv.attribute7, ffv.attribute19,
                               ffv.attribute13
                          INTO lv_ini_seg1, lv_ini_seg2, lv_ini_seg3, lv_ini_seg4,
                                          lv_ini_seg5, lv_ini_seg6, lv_ini_seg7
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                         WHERE     ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_LCX_CONTRACT_NAMES_VS'
                               AND ffv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffv.end_date_active,
                                                        SYSDATE)
                               AND ffv.attribute3 = data_rec.contract_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                lv_ini_seg1   := NULL;
                                lv_ini_seg2   := NULL;
                                lv_ini_seg3   := NULL;
                                lv_ini_seg4   := NULL;
                                lv_ini_seg5   := NULL;
                                lv_ini_seg6   := NULL;
                                lv_ini_seg7   := NULL;

                                SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                                       ffv.attribute6, ffv.attribute7, ffv.attribute19,
                                       ffv.attribute13
                                  INTO lv_ini_seg1, lv_ini_seg2, lv_ini_seg3, lv_ini_seg4,
                                                  lv_ini_seg5, lv_ini_seg6, lv_ini_seg7
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                                 WHERE     ffvs.flex_value_set_id =
                                           ffv.flex_value_set_id
                                       AND ffvs.flex_value_set_name =
                                           'XXD_LCX_CONTRACT_NAMES_NEW_VS'
                                       AND ffv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffv.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffv.end_date_active,
                                                               SYSDATE)
                                       AND ffv.attribute3 =
                                           data_rec.contract_name;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_ini_seg1   := NULL;
                                    lv_ini_seg2   := NULL;
                                    lv_ini_seg3   := NULL;
                                    lv_ini_seg4   := NULL;
                                    lv_ini_seg5   := NULL;
                                    lv_ini_seg6   := NULL;
                            END;
                    END;
                END IF;

                lv_ini_code_comb   :=
                       lv_ini_seg1
                    || '.'
                    || lv_ini_seg2
                    || '.'
                    || lv_ini_seg3
                    || '.'
                    || lv_ini_seg4
                    || '.'
                    || lv_ini_seg5
                    || '.'
                    || lv_ini_seg6
                    || '.'
                    || lv_ini_seg7;

                UPDATE xxdo.xxd_rms_lmt_asset_stg_t
                   SET accumulated_amort_gl_code = lv_acc_code_comb, initial_asset_bal_gl_code = lv_ini_code_comb, last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 --                    period_end_date = data_rec.period_ed
                 WHERE     1 = 1
                       AND request_id = gn_request_id
                       AND contract_name = data_rec.contract_name;
            --                AND accrual_date = data_rec.accrual_date
            --                AND currency = data_rec.currency;

            END LOOP;
        ELSIF PV_TYPE = 'LIABILITY_RETAIL'
        THEN
            FOR lmt_lia_data IN cur_lmt_lia_data
            LOOP
                lv_lt_seg1        := NULL;
                lv_lt_seg2        := NULL;
                lv_lt_seg3        := NULL;
                lv_lt_seg4        := NULL;
                lv_lt_seg5        := NULL;
                lv_lt_seg6        := NULL;
                lv_lt_seg7        := NULL;
                lv_st_seg1        := NULL;
                lv_st_seg2        := NULL;
                lv_st_seg3        := NULL;
                lv_st_seg4        := NULL;
                lv_st_seg5        := NULL;
                lv_st_seg6        := NULL;
                lv_st_seg7        := NULL;
                lv_st_code_comb   := NULL;
                lv_lt_code_comb   := NULL;

                ln_st_reclass     := 0;
                ln_lt_reclass     := 0;
                ln_st_lia_adj     := 0;
                ln_lt_lia_adj     := 0;

                -- Get the GL Code Combination

                IF lmt_lia_data.short_term IS NOT NULL
                THEN
                    BEGIN
                        lv_st_seg1        := NULL;
                        lv_st_seg2        := NULL;
                        lv_st_seg3        := NULL;
                        lv_st_seg4        := NULL;
                        lv_st_seg5        := NULL;
                        lv_st_seg6        := NULL;
                        lv_st_seg7        := NULL;
                        lv_st_code_comb   := NULL;

                        SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                               ffv.attribute6, ffv.attribute7, ffv.attribute16,
                               ffv.attribute13
                          INTO lv_st_seg1, lv_st_seg2, lv_st_seg3, lv_st_seg4,
                                         lv_st_seg5, lv_st_seg6, lv_st_seg7
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                         WHERE     ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_LCX_CONTRACT_NAMES_VS'
                               AND ffv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffv.end_date_active,
                                                        SYSDATE)
                               AND ffv.attribute3 =
                                   lmt_lia_data.contract_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                lv_st_seg1        := NULL;
                                lv_st_seg2        := NULL;
                                lv_st_seg3        := NULL;
                                lv_st_seg4        := NULL;
                                lv_st_seg5        := NULL;
                                lv_st_seg6        := NULL;
                                lv_st_seg7        := NULL;
                                lv_st_code_comb   := NULL;

                                SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                                       ffv.attribute6, ffv.attribute7, ffv.attribute16,
                                       ffv.attribute13
                                  INTO lv_st_seg1, lv_st_seg2, lv_st_seg3, lv_st_seg4,
                                                 lv_st_seg5, lv_st_seg6, lv_st_seg7
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                                 WHERE     ffvs.flex_value_set_id =
                                           ffv.flex_value_set_id
                                       AND ffvs.flex_value_set_name =
                                           'XXD_LCX_CONTRACT_NAMES_NEW_VS'
                                       AND ffv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffv.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffv.end_date_active,
                                                               SYSDATE)
                                       AND ffv.attribute3 =
                                           lmt_lia_data.contract_name;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_st_seg1        := NULL;
                                    lv_st_seg2        := NULL;
                                    lv_st_seg3        := NULL;
                                    lv_st_seg4        := NULL;
                                    lv_st_seg5        := NULL;
                                    lv_st_seg6        := NULL;
                                    lv_st_seg7        := NULL;
                                    lv_st_code_comb   := NULL;
                            END;
                    END;
                END IF;

                lv_st_code_comb   :=
                       lv_st_seg1
                    || '.'
                    || lv_st_seg2
                    || '.'
                    || lv_st_seg3
                    || '.'
                    || lv_st_seg4
                    || '.'
                    || lv_st_seg5
                    || '.'
                    || lv_st_seg6
                    || '.'
                    || lv_st_seg7;

                IF lmt_lia_data.long_term IS NOT NULL
                THEN
                    BEGIN
                        lv_lt_seg1   := NULL;
                        lv_lt_seg2   := NULL;
                        lv_lt_seg3   := NULL;
                        lv_lt_seg4   := NULL;
                        lv_lt_seg5   := NULL;
                        lv_lt_seg6   := NULL;
                        lv_lt_seg7   := NULL;

                        SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                               ffv.attribute6, ffv.attribute7, ffv.attribute17,
                               ffv.attribute13
                          INTO lv_lt_seg1, lv_lt_seg2, lv_lt_seg3, lv_lt_seg4,
                                         lv_lt_seg5, lv_lt_seg6, lv_lt_seg7
                          FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                         WHERE     ffvs.flex_value_set_id =
                                   ffv.flex_value_set_id
                               AND ffvs.flex_value_set_name =
                                   'XXD_LCX_CONTRACT_NAMES_VS'
                               AND ffv.enabled_flag = 'Y'
                               AND SYSDATE BETWEEN NVL (
                                                       ffv.start_date_active,
                                                       SYSDATE)
                                               AND NVL (ffv.end_date_active,
                                                        SYSDATE)
                               AND ffv.attribute3 =
                                   lmt_lia_data.contract_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            BEGIN
                                lv_lt_seg1   := NULL;
                                lv_lt_seg2   := NULL;
                                lv_lt_seg3   := NULL;
                                lv_lt_seg4   := NULL;
                                lv_lt_seg5   := NULL;
                                lv_lt_seg6   := NULL;
                                lv_lt_seg7   := NULL;

                                SELECT ffv.attribute13, ffv.attribute15, ffv.attribute14,
                                       ffv.attribute6, ffv.attribute7, ffv.attribute17,
                                       ffv.attribute13
                                  INTO lv_lt_seg1, lv_lt_seg2, lv_lt_seg3, lv_lt_seg4,
                                                 lv_lt_seg5, lv_lt_seg6, lv_lt_seg7
                                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffv
                                 WHERE     ffvs.flex_value_set_id =
                                           ffv.flex_value_set_id
                                       AND ffvs.flex_value_set_name =
                                           'XXD_LCX_CONTRACT_NAMES_NEW_VS'
                                       AND ffv.enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               ffv.start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               ffv.end_date_active,
                                                               SYSDATE)
                                       AND ffv.attribute3 =
                                           lmt_lia_data.contract_name;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    lv_lt_seg1   := NULL;
                                    lv_lt_seg2   := NULL;
                                    lv_lt_seg3   := NULL;
                                    lv_lt_seg4   := NULL;
                                    lv_lt_seg5   := NULL;
                                    lv_lt_seg6   := NULL;
                            END;
                    END;
                END IF;

                lv_lt_code_comb   :=
                       lv_lt_seg1
                    || '.'
                    || lv_lt_seg2
                    || '.'
                    || lv_lt_seg3
                    || '.'
                    || lv_lt_seg4
                    || '.'
                    || lv_lt_seg5
                    || '.'
                    || lv_lt_seg6
                    || '.'
                    || lv_lt_seg7;

                UPDATE xxdo.xxd_rms_lmt_liability_stg_t
                   SET short_term_gl_code = lv_st_code_comb, long_term_gl_code = lv_lt_code_comb, last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 --                    period_end_date = lmt_lia_data.period_ed
                 WHERE     1 = 1
                       AND request_id = gn_request_id
                       AND contract_name = lmt_lia_data.contract_name;

                --                AND strual_date = lmt_lia_data.strual_date
                --                AND currency = lmt_lia_data.currency;

                COMMIT;
            END LOOP;

            FOR ret_lia_data IN cur_ret_lia_data
            LOOP
                ln_st_reclass   := 0;
                ln_lt_reclass   := 0;
                ln_st_lia_adj   := 0;
                ln_lt_lia_adj   := 0;

                -- LT reclass Calc.

                --                IF NVL(ret_lia_data.long_term,0) >= NVL(ret_lia_data.short_term,0) AND NVL(ret_lia_data.long_term,0) >  ret_lia_data.invoice_amount
                --                THEN
                --                    ln_st_reclass := 0;
                --                    ln_lt_reclass := ret_lia_data.Invoice_amount;
                --                ELSIF


                IF     ret_lia_data.long_term >= ret_lia_data.invoice_amount
                   AND ret_lia_data.invoice_amount <> 0
                THEN
                    ln_lt_reclass   := ret_lia_data.Invoice_amount;
                --                    write_log ('LT>INV 1 for Contractor - '||ret_lia_data.contract_name);
                ELSE
                    ln_lt_reclass   := 0;
                END IF;

                -- ST reclass Calc.

                --IF ln_lt_reclass = 0
                --THEN

                IF     ret_lia_data.long_term >= ret_lia_data.invoice_amount
                   AND ret_lia_data.invoice_amount <> 0
                THEN
                    ln_st_reclass   := 0;
                ELSIF ret_lia_data.short_term >= ret_lia_data.invoice_amount
                THEN
                    --                    write_log ('ST>INV 2 for Contractor - '||ret_lia_data.contract_name);
                    ln_st_reclass   := ret_lia_data.Invoice_amount;
                ELSE
                    ln_st_reclass   := 0;
                END IF;

                --END IF;

                --                IF ret_lia_data.short_term > ret_lia_data.invoice_amount
                --                THEN
                --                    ln_st_reclass := ret_lia_data.short_term - ret_lia_data.Invoice_amount;
                --                ELSIF ret_lia_data.short_term <= ret_lia_data.invoice_amount
                --                THEN
                --                    ln_st_reclass := 0;
                --                END IF;



                ln_st_lia_adj   := ret_lia_data.short_term - ln_st_reclass;
                ln_lt_lia_adj   := ret_lia_data.long_term - ln_lt_reclass;

                UPDATE xxdo.xxd_rms_lmt_liability_stg_t
                   SET short_term_liability_adj = ln_st_lia_adj, long_term_liability_adj = ln_lt_lia_adj, prepaid_amount = ret_lia_data.invoice_amount,
                       short_term_reclass = ln_st_reclass, long_term_reclass = ln_lt_reclass, last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 --                    period_end_date = lmt_lia_data.period_ed
                 WHERE     1 = 1
                       AND request_id = gn_request_id
                       AND contract_name = ret_lia_data.contract_name;

                COMMIT;
            END LOOP;
        END IF;
    END process_data_prc;

    PROCEDURE MAIN_PRC (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_period_end_date IN VARCHAR2
                        , pv_type IN VARCHAR2, pv_file_path IN VARCHAR2)
    IS
        CURSOR get_file_cur IS
            SELECT filename
              FROM xxd_utl_file_upload_gt
             WHERE UPPER (filename) LIKE UPPER ('Deckers-ROUAsset%');

        CURSOR get_ret_file_cur IS
            SELECT filename
              FROM xxd_utl_file_upload_gt
             WHERE UPPER (filename) LIKE UPPER ('LXRetail%');

        CURSOR get_lia_file_cur IS
            SELECT filename
              FROM xxd_utl_file_upload_gt
             WHERE UPPER (filename) LIKE UPPER ('Deckers-Lease%');

        CURSOR files_cur IS
            SELECT filename
              FROM xxd_utl_file_upload_gt
             WHERE    UPPER (filename) LIKE UPPER ('LXRetail%')
                   OR UPPER (filename) LIKE UPPER ('Deckers-Lease%');



        lv_directory_path       VARCHAR2 (100);
        lv_directory            VARCHAR2 (100);
        lv_arc_directory_path   VARCHAR2 (100);
        lv_file_name            VARCHAR2 (100);
        lv_ret_message          VARCHAR2 (4000) := NULL;
        lv_ret_code             VARCHAR2 (30) := NULL;
        lv_period_name          VARCHAR2 (100);
        ln_file_exists          NUMBER;
        ln_ret_count            NUMBER := 0;
        ln_final_count          NUMBER := 0;
        ln_lia_count            NUMBER := 0;
        ln_req_id               NUMBER;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lb_wait_req             BOOLEAN;
        lv_message              VARCHAR2 (4000);
    BEGIN
        lv_directory_path   := NULL;
        lv_directory        := 'XXD_LCX_BAL_BL_INB_DIR';
        ln_file_exists      := 0;

        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE directory_name LIKE 'XXD_LCX_BAL_BL_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        BEGIN
            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE directory_name = 'XXD_LCX_BAL_BL_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
        END;

        -- Now Get the file names

        get_file_names (lv_directory_path);

        IF pv_type = 'ASSET'
        THEN
            FOR data IN get_file_cur
            LOOP
                ln_file_exists   := 0;

                write_log (' File is availale - ' || data.filename);

                -- Check the file name exists in the table if exists then SKIP

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_file_exists
                      FROM xxdo.xxd_rms_lmt_asset_stg_t
                     WHERE UPPER (file_name) = UPPER (data.filename);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_file_exists   := 0;
                END;

                IF ln_file_exists = 0
                THEN
                    load_file_into_tbl (p_table => 'XXD_RMS_LMT_ASSET_STG_T', p_dir => 'XXD_LCX_BAL_BL_INB_DIR', p_filename => data.filename, p_ignore_headerlines => 1, p_delimiter => ',', p_optional_enclosed => '"'
                                        , p_num_of_columns => 25);

                    --
                    UPDATE xxdo.xxd_rms_lmt_asset_stg_t
                       SET file_name = data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                           last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                     WHERE file_name IS NULL AND request_id IS NULL;

                    --
                    --             Utl_File.Fcopy('XXD_LCX_BAL_BL_INB_DIR', data.filename, 'XXD_CONCURACC_BL_ARC_DIR',data.filename);
                    ----             Utl_File.Fremove('XXD_LCX_BAL_BL_INB_DIR', data.filename);
                    --
                    --            CopyFile_prc (data.filename, SYSDATE||data.filename,'XXD_LCX_BAL_BL_INB_DIR','XXD_CONCURACC_BL_ARC_DIR');
                    ----
                    --            Utl_File.Fremove('XXD_LCX_BAL_BL_INB_DIR', data.filename);

                    BEGIN
                        write_log (
                               'Move files Process Begins...'
                            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                        ln_req_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDO',
                                program       => 'XXDO_CP_MV_RM_FILE',
                                argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                                argument2     => 2,
                                argument3     =>
                                    lv_directory_path || '/' || data.filename, -- Source File Directory
                                argument4     =>
                                       lv_arc_directory_path
                                    || '/'
                                    || SYSDATE
                                    || '_'
                                    || data.filename, -- Destination File Directory
                                start_time    => SYSDATE,
                                sub_request   => FALSE);
                        COMMIT;

                        IF ln_req_id = 0
                        THEN
                            retcode   := gn_warning;
                            write_log (
                                ' Unable to submit move files concurrent program ');
                        ELSE
                            write_log (
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
                                write_log (
                                       'Move Files concurrent request with the request id '
                                    || ln_req_id
                                    || ' completed with NORMAL status.');
                            ELSE
                                retcode   := gn_warning;
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
                            retcode   := gn_error;
                            write_log ('Error in Move Files -' || SQLERRM);
                    END;
                --
                ELSE
                    write_log (
                           ' Data with this File name - '
                        || data.filename
                        || ' - is already loaded. Please change the file data ');
                END IF;
            END LOOP;
        ELSIF pv_type = 'LIABILITY_RETAIL'
        THEN
            ln_ret_count     := 0;
            ln_final_count   := 0;
            ln_lia_count     := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_ret_count
                  FROM xxd_utl_file_upload_gt
                 WHERE UPPER (filename) LIKE UPPER ('LXRetail%');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ret_count   := 0;
            END;

            ln_lia_count     := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_lia_count
                  FROM xxd_utl_file_upload_gt
                 WHERE UPPER (filename) LIKE UPPER ('Deckers-Lease%');
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_lia_count   := 0;
            END;

            IF ln_ret_count > 0 AND ln_lia_count > 0
            THEN
                ln_final_count   := 1;
            ELSE
                ln_final_count   := 0;
            END IF;

            -- Loading into the tables should happen only when both the Retail and Liability files exists in the Directory

            IF ln_final_count = 1
            THEN
                -- Load the Lease Libaility Data

                FOR lia_data IN get_lia_file_cur
                LOOP
                    ln_file_exists   := 0;

                    write_log (' File is availale - ' || lia_data.filename);

                    -- Check the file name exists in the table if exists then SKIP

                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_file_exists
                          FROM xxdo.xxd_rms_lmt_liability_stg_t
                         WHERE UPPER (file_name) = UPPER (lia_data.filename);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_file_exists   := 0;
                    END;

                    IF ln_file_exists = 0
                    THEN
                        load_file_into_tbl (p_table => 'XXD_RMS_LMT_LIABILITY_STG_T', p_dir => 'XXD_LCX_BAL_BL_INB_DIR', p_filename => lia_data.filename, p_ignore_headerlines => 1, --6,
                                                                                                                                                                                     p_delimiter => ',', p_optional_enclosed => '"'
                                            , p_num_of_columns => 25);

                        --
                        UPDATE xxdo.xxd_rms_lmt_liability_stg_t
                           SET file_name = lia_data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                               last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                         WHERE file_name IS NULL AND request_id IS NULL;
                    ELSE
                        write_log (
                               ' Data with this File name - '
                            || lia_data.filename
                            || ' - is already loaded. Please change the file data ');
                    END IF;
                END LOOP;

                -- Loading the Retail Data

                FOR ret_data IN get_ret_file_cur
                LOOP
                    ln_file_exists   := 0;

                    write_log (' File is availale - ' || ret_data.filename);

                    -- Check the file name exists in the table if exists then SKIP

                    BEGIN
                        SELECT COUNT (1)
                          INTO ln_file_exists
                          FROM xxdo.xxd_rms_lmt_ret_stg_t
                         WHERE UPPER (file_name) = UPPER (ret_data.filename);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_file_exists   := 0;
                    END;

                    IF ln_file_exists = 0
                    THEN
                        load_file_into_tbl (p_table => 'XXD_RMS_LMT_RET_STG_T', p_dir => 'XXD_LCX_BAL_BL_INB_DIR', p_filename => ret_data.filename, p_ignore_headerlines => 1, --2,
                                                                                                                                                                               p_delimiter => ',', p_optional_enclosed => '"'
                                            , p_num_of_columns => 25);

                        --
                        UPDATE xxdo.xxd_rms_lmt_ret_stg_t
                           SET file_name = ret_data.filename, request_id = gn_request_id, creation_date = SYSDATE,
                               last_update_date = SYSDATE, created_by = gn_user_id, last_updated_by = gn_user_id
                         WHERE file_name IS NULL AND request_id IS NULL;
                    ELSE
                        write_log (
                               ' Data with this File name - '
                            || ret_data.filename
                            || ' - is already loaded. Please change the file data ');
                    END IF;
                END LOOP;

                FOR files_rec IN files_cur
                LOOP
                    BEGIN
                        write_log (
                               'Move files Process Begins...'
                            || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                        ln_req_id   :=
                            fnd_request.submit_request (
                                application   => 'XXDO',
                                program       => 'XXDO_CP_MV_RM_FILE',
                                argument1     => 'MOVE', -- MODE : COPY, MOVE, RENAME, REMOVE
                                argument2     => 2,
                                argument3     =>
                                    lv_directory_path || '/' || files_rec.filename, -- Source File Directory
                                argument4     =>
                                       lv_arc_directory_path
                                    || '/'
                                    || SYSDATE
                                    || '_'
                                    || files_rec.filename, -- Destination File Directory
                                start_time    => SYSDATE,
                                sub_request   => FALSE);
                        COMMIT;

                        IF ln_req_id = 0
                        THEN
                            retcode   := gn_warning;
                            write_log (
                                ' Unable to submit move files concurrent program ');
                        ELSE
                            write_log (
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
                                write_log (
                                       'Move Files concurrent request with the request id '
                                    || ln_req_id
                                    || ' completed with NORMAL status.');
                            ELSE
                                retcode   := gn_warning;
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
                            retcode   := gn_error;
                            write_log ('Error in Move Files -' || SQLERRM);
                    END;
                END LOOP;
            ELSE
                write_log (
                    ' Both the Files RETAIL and LIABILITY are not available. So Skipping the File Loading.. ');
            END IF;
        END IF;

        --
        --        COMMIT;

        process_data_prc (pv_type);
        --
        --        FOR gl_data_rec IN cur_gl_data
        --        LOOP
        --
        --        write_log(' cur_gl_data for company - '||gl_data_rec.gl_bal_seg);
        --
        write_op_file (pv_file_path, lv_file_name, pv_period_end_date,
                       pv_type, lv_ret_code, lv_ret_message);
        --
        --        END LOOP;

        --update_attributes (lv_ret_message, pv_period_end_date,pv_type);

        --        write_log(' write cur_gl_data for company');
        write_ret_recon_file (pv_file_path, lv_file_name, pv_period_end_date,
                              pv_type, lv_ret_code, lv_ret_message);

        --        FOR gl_data_rec IN cur_gl_data
        --        LOOP
        --        write_log(' write cur_gl_data for company - '||gl_data_rec.gl_bal_seg);
        --        write_ret_recon_file (pv_file_path,
        --                              lv_file_name,
        ----                              gl_data_rec.gl_bal_seg,
        --                              lv_ret_code,
        --                              lv_ret_message);
        --        END LOOP;

        update_valueset_prc (pv_file_path);
    END MAIN_PRC;


    PROCEDURE write_ret_recon_file (pv_file_path IN VARCHAR2, pv_file_name IN VARCHAR2, pv_period_end_date IN VARCHAR2
                                    , pv_type IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR ret_reconcilation IS
            SELECT *
              FROM (  SELECT                                        --a.ROWID,
                                REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 1)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 6)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 2)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 3)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 4)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 5)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1
                                               , 7)
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || TO_CHAR (
                                    LAST_DAY (
                                        TO_DATE (pv_period_end_date,
                                                 'RRRR/MM/DD HH24:MI:SS')),
                                    'MM/DD/RRRR')
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             ||   (-1)
                                * SUM (REPLACE (a.accumulated_amort, ',', '')) line
                        FROM xxdo.xxd_rms_lmt_asset_stg_t a --, gl_code_combinations_kfv c
                       WHERE     1 = 1
                             AND a.request_id = gn_request_id
                             AND NVL (accumulated_amort, 0) <> 0
                    GROUP BY a.accumulated_amort_gl_code
                    UNION ALL
                      SELECT    REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 1)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 6)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 2)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 3)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 4)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 5)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1
                                               , 7)
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || TO_CHAR (
                                    LAST_DAY (
                                        TO_DATE (pv_period_end_date,
                                                 'RRRR/MM/DD HH24:MI:SS')),
                                    'MM/DD/RRRR')
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || SUM (REPLACE (a.initial_asset_bal, ',', ''))
                        FROM xxdo.xxd_rms_lmt_asset_stg_t a --, gl_code_combinations_kfv c
                       WHERE     1 = 1
                             AND a.request_id = gn_request_id
                             AND NVL (initial_asset_bal, 0) <> 0
                    GROUP BY a.initial_asset_bal_gl_code
                    UNION ALL
                      SELECT    REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 1)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 6)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 2)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 3)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 4)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 5)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1
                                               , 7)
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || TO_CHAR (
                                    LAST_DAY (
                                        TO_DATE (pv_period_end_date,
                                                 'RRRR/MM/DD HH24:MI:SS')),
                                    'MM/DD/RRRR')
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             ||   (-1)
                                * SUM (
                                      REPLACE (a.SHORT_TERM_LIABILITY_ADJ,
                                               ',',
                                               '')) SHORT_TERM_LIABILITY_ADJ
                        FROM xxdo.xxd_rms_lmt_liability_stg_t a --, gl_code_combinations_kfv c
                       WHERE     1 = 1
                             AND a.request_id = gn_request_id
                             AND NVL (SHORT_TERM_LIABILITY_ADJ, 0) <> 0
                    GROUP BY a.SHORT_TERM_GL_CODE
                    UNION ALL
                      SELECT    REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               1)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               6)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               2)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               3)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               4)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               5)
                             || CHR (9)
                             || REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                               7)
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || TO_CHAR (
                                    LAST_DAY (
                                        TO_DATE (pv_period_end_date,
                                                 'RRRR/MM/DD HH24:MI:SS')),
                                    'MM/DD/RRRR')
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             || NULL
                             || CHR (9)
                             ||   (-1)
                                * SUM (
                                      REPLACE (a.LONG_TERM_LIABILITY_ADJ,
                                               ',',
                                               '')) LONG_TERM_LIABILITY_ADJ
                        FROM xxdo.xxd_rms_lmt_liability_stg_t a --, gl_code_combinations_kfv c
                       WHERE     1 = 1
                             AND a.request_id = gn_request_id
                             AND NVL (LONG_TERM_LIABILITY_ADJ, 0) <> 0
                    GROUP BY a.long_TERM_GL_CODE);

        --              SELECT  entity_uniq_identifier
        --                      || CHR (9)
        --                      || account_number
        --                      || CHR (9)
        --                      || key3
        --                      || CHR (9)
        --                      || key4
        --                      || CHR (9)
        --                      || key5
        --                      || CHR (9)
        --                      || key6
        --                      || CHR (9)
        --                      || key7
        --                      || CHR (9)
        --                      || key8
        --                      || CHR (9)
        --                      || key9
        --                      || CHR (9)
        --                      || key10
        --                      || CHR (9)
        --                      || TO_CHAR (Period_End_Date, 'MM/DD/RRRR')
        --                      || CHR (9)
        --                      || Subledr_Rep_Bal
        --                      || CHR (9)
        --                      || Subledr_alt_Bal
        --                      || CHR (9)
        --                      || SUM (Subledr_Acc_Bal_init)    line
        --                FROM xxdo.XXD_RMS_LMT_ASSET_STG_T
        --               WHERE 1 = 1 AND request_id = gn_request_id
        --                 AND pv_type = 'ASSET'
        --                 AND NVL(Subledr_Acc_Bal_init,0) <> 0
        --            GROUP BY entity_uniq_identifier,
        --                     Account_Number,
        --                     key3,
        --                     key4,
        --                     key5,
        --                     key6,
        --                     key7,
        --                     key8,
        --                     key9,
        --                     key10,
        --                     Period_End_Date,
        --                     Subledr_Rep_Bal,
        --                     Subledr_alt_Bal
        --            UNION ALL
        --            SELECT  entity_uniq_identifier
        --                      || CHR (9)
        --                      || account_number
        --                      || CHR (9)
        --                      || key3
        --                      || CHR (9)
        --                      || key4
        --                      || CHR (9)
        --                      || key5
        --                      || CHR (9)
        --                      || key6
        --                      || CHR (9)
        --                      || key7
        --                      || CHR (9)
        --                      || key8
        --                      || CHR (9)
        --                      || key9
        --                      || CHR (9)
        --                      || key10
        --                      || CHR (9)
        --                      || TO_CHAR (Period_End_Date, 'MM/DD/RRRR')
        --                      || CHR (9)
        --                      || Subledr_Rep_Bal
        --                      || CHR (9)
        --                      || Subledr_alt_Bal
        --                      || CHR (9)
        --                      || SUM (Subledr_Acc_Bal_amort)    line
        --                FROM xxdo.XXD_RMS_LMT_ASSET_STG_T
        --               WHERE 1 = 1 AND request_id = gn_request_id
        --                 AND pv_type = 'ASSET'
        --                 AND NVL(Subledr_Acc_Bal_amort,0) <> 0
        --            GROUP BY entity_uniq_identifier,
        --                     Account_Number,
        --                     key3,
        --                     key4,
        --                     key5,
        --                     key6,
        --                     key7,
        --                     key8,
        --                     key9,
        --                     key10,
        --                     Period_End_Date,
        --                     Subledr_Rep_Bal,
        --                     Subledr_alt_Bal
        --            UNION ALL
        --                SELECT entity_uniq_identifier
        --                      || CHR (9)
        --                      || account_number
        --                      || CHR (9)
        --                      || key3
        --                      || CHR (9)
        --                      || key4
        --                      || CHR (9)
        --                      || key5
        --                      || CHR (9)
        --                      || key6
        --                      || CHR (9)
        --                      || key7
        --                      || CHR (9)
        --                      || key8
        --                      || CHR (9)
        --                      || key9
        --                      || CHR (9)
        --                      || key10
        --                      || CHR (9)
        --                      || TO_CHAR (Period_End_Date, 'MM/DD/RRRR')
        --                      || CHR (9)
        --                      || Subledr_Rep_Bal
        --                      || CHR (9)
        --                      || Subledr_alt_Bal
        --                      || CHR (9)
        --                      || SUM (Subledr_Acc_Bal)    line
        --                FROM xxdo.xxd_rms_lmt_liability_stg_t
        --               WHERE 1 = 1 AND request_id = gn_request_id
        --                 AND pv_type = 'LIABILITY_RETAIL'
        --                 AND NVL(short_term_liability_adj,0) <> 0
        --            GROUP BY entity_uniq_identifier,
        --                     Account_Number,
        --                     key3,
        --                     key4,
        --                     key5,
        --                     key6,
        --                     key7,
        --                     key8,
        --                     key9,
        --                     key10,
        --                     Period_End_Date,
        --                     Subledr_Rep_Bal,
        --                     Subledr_alt_Bal
        --            UNION ALL
        --            SELECT entity_uniq_identifier
        --                      || CHR (9)
        --                      || account_number
        --                      || CHR (9)
        --                      || key3
        --                      || CHR (9)
        --                      || key4
        --                      || CHR (9)
        --                      || key5
        --                      || CHR (9)
        --                      || key6
        --                      || CHR (9)
        --                      || key7
        --                      || CHR (9)
        --                      || key8
        --                      || CHR (9)
        --                      || key9
        --                      || CHR (9)
        --                      || key10
        --                      || CHR (9)
        --                      || TO_CHAR (Period_End_Date, 'MM/DD/RRRR')
        --                      || CHR (9)
        --                      || Subledr_Rep_Bal
        --                      || CHR (9)
        --                      || Subledr_alt_Bal
        --                      || CHR (9)
        --                      || SUM (Subledr_Acc_Bal)    line
        --                FROM xxdo.xxd_rms_lmt_liability_stg_t
        --               WHERE 1 = 1 AND request_id = gn_request_id
        --                 AND pv_type = 'LIABILITY_RETAIL'
        --                 AND NVL(long_term_liability_adj,0) <> 0
        --            GROUP BY entity_uniq_identifier,
        --                     Account_Number,
        --                     key3,
        --                     key4,
        --                     key5,
        --                     key6,
        --                     key7,
        --                     key8,
        --                     key9,
        --                     key10,
        --                     Period_End_Date,
        --                     Subledr_Rep_Bal,
        --                     Subledr_alt_Bal;

        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        l_line                    VARCHAR2 (4000);
        lv_last_date              VARCHAR2 (50);
    BEGIN
        SELECT LAST_DAY (TO_DATE (pv_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;

        FOR i IN ret_reconcilation
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
        END LOOP;


        IF pv_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute2, ffvl.attribute4
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'LXBALANCES'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            IF     lv_vs_file_name IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
            THEN
                IF lv_vs_file_path IS NOT NULL
                THEN
                    lv_file_path   := lv_vs_file_path;
                ELSE
                    BEGIN
                        SELECT ffvl.description
                          INTO lv_vs_default_file_path
                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                         WHERE     fvs.flex_value_set_id =
                                   ffvl.flex_value_set_id
                               AND fvs.flex_value_set_name =
                                   'XXD_AAR_GL_BL_FILE_PATH_VS'
                               AND NVL (TRUNC (ffvl.start_date_active),
                                        TRUNC (SYSDATE)) <=
                                   TRUNC (SYSDATE)
                               AND NVL (TRUNC (ffvl.end_date_active),
                                        TRUNC (SYSDATE)) >=
                                   TRUNC (SYSDATE)
                               AND ffvl.enabled_flag = 'Y';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_vs_default_file_path   := NULL;
                    END;

                    lv_file_path   := lv_vs_default_file_path;
                END IF;


                -- WRITE INTO BL FOLDER

                lv_outbound_file   :=
                       lv_vs_file_name
                    || '_'
                    || pv_type
                    || '-'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                fnd_file.put_line (fnd_file.LOG,
                                   'BL File Name is - ' || lv_outbound_file);

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN ret_reconcilation
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the Account Balance data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    write_log (lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            END IF;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_ret_recon_file;

    PROCEDURE write_op_file (pv_file_path         IN     VARCHAR2,
                             pv_file_name         IN     VARCHAR2,
                             pv_period_end_date   IN     VARCHAR2,
                             pv_type              IN     VARCHAR2,
                             x_ret_code              OUT VARCHAR2,
                             x_ret_message           OUT VARCHAR2)
    IS
        CURSOR op_file_ret IS
              SELECT line
                FROM (SELECT 1 AS seq, Portfolio || gv_delimeter || contract_name || gv_delimeter || currency_type || gv_delimeter || fiscal_period_year || gv_delimeter || fiscal_period || gv_delimeter || cum_period_num || gv_delimeter || sum_begin_date || gv_delimeter || begin_bal || gv_delimeter || initial_asset_bal_act || gv_delimeter || inactive_amount || gv_delimeter || period_asset_amort_exp || gv_delimeter || closing_bal || gv_delimeter || accumulated_amort || gv_delimeter || initial_asset_bal || gv_delimeter || accumulated_amort_gl_code || gv_delimeter || initial_asset_bal_gl_code line
                        FROM xxdo.xxd_rms_lmt_asset_stg_t
                       WHERE     1 = 1
                             AND request_id = gn_request_id
                             AND pv_type = 'ASSET'
                      UNION
                      SELECT 2 AS seq, 'Portfolio' || gv_delimeter || 'Contract Name' || gv_delimeter || 'Currency Type' || gv_delimeter || 'Fiscal Period Year' || gv_delimeter || 'Fiscal Period' || gv_delimeter || 'Cumulative Period Number' || gv_delimeter || 'Summary Begin Date' || gv_delimeter || 'Beginning Balance' || gv_delimeter || 'Initial Asset Balance - Act' || gv_delimeter || 'Inactive Amount' || gv_delimeter || 'Period Asset Amortization Expense - Calc' || gv_delimeter || 'Closing Balance' || gv_delimeter || 'Accumulated Amortization' || gv_delimeter || 'Initial Asset Balance' || gv_delimeter || 'Accumulated Amortization Gl Code' || gv_delimeter || 'Initial Asset Balance Gl Code'
                        FROM DUAL
                       WHERE 1 = 1 AND pv_type = 'ASSET')
            ORDER BY 1 DESC;


        CURSOR op_lia_file_ret IS
              SELECT line
                FROM (SELECT 1 AS seq, Portfolio || gv_delimeter || contract_name || gv_delimeter || currency_type || gv_delimeter || fiscal_period_year || gv_delimeter || fiscal_period || gv_delimeter || cum_period_num || gv_delimeter || sum_begin_date || gv_delimeter || begin_bal || gv_delimeter || initial_liability_bal_act || gv_delimeter || inactive_amount || gv_delimeter || period_liability_amort_exp || gv_delimeter || closing_bal || gv_delimeter || prepaid_amount || gv_delimeter || short_term || gv_delimeter || long_term || gv_delimeter || short_term_reclass || gv_delimeter || long_term_reclass || gv_delimeter || short_term_liability_adj || gv_delimeter || long_term_liability_adj || gv_delimeter || Short_term_gl_code || gv_delimeter || long_term_gl_code line
                        FROM xxdo.xxd_rms_lmt_liability_stg_t
                       WHERE     1 = 1
                             AND request_id = gn_request_id
                             AND pv_type = 'LIABILITY_RETAIL'
                      UNION
                      SELECT 2 AS seq, 'Portfolio' || gv_delimeter || 'Contract Name' || gv_delimeter || 'Currency Type' || gv_delimeter || 'Fiscal Period Year' || gv_delimeter || 'Fiscal Period' || gv_delimeter || 'Cumulative Period Number' || gv_delimeter || 'Begin Date' || gv_delimeter || 'Beginning Balance' || gv_delimeter || 'Initial Liability Balance - Act' || gv_delimeter || 'Inactive Amount' || gv_delimeter || 'Period Liability Amortization Expense - Calc' || gv_delimeter || 'Closing Balance' || gv_delimeter || 'Prepaid Amount' || gv_delimeter || 'Short Term' || gv_delimeter || 'Long Term' || gv_delimeter || 'Short Term Reclass' || gv_delimeter || 'Long term reclass' || gv_delimeter || 'Short Term Liability Adjustment' || gv_delimeter || 'Long term Liability Adjustment' || gv_delimeter || 'Short Term GL Code' || gv_delimeter || 'Long Term GL Code'
                        FROM DUAL
                       WHERE 1 = 1 AND pv_type = 'LIABILITY_RETAIL')
            ORDER BY 1 DESC;


        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);          -- := pv_file_path;
        lv_file_name              VARCHAR2 (360);
        lv_file_dir               VARCHAR2 (1000);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);          -- := pv_file_name;
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        lv_ou_short_name          VARCHAR2 (100);
        lv_period_name            VARCHAR2 (50);
    BEGIN
        -- WRITE INTO BL FOLDER

        IF pv_file_path IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1, ffvl.attribute3
                  INTO lv_vs_file_path, lv_vs_file_name
                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                 WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND fvs.flex_value_set_name =
                           'XXD_GL_AAR_FILE_DETAILS_VS'
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.description = 'LXBALANCES'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;


            IF pv_period_end_date IS NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TRUNC (SYSDATE) BETWEEN start_date
                                                   AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            ELSE
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_CY_CALENDAR'
                           AND TO_DATE (pv_period_end_date,
                                        'YYYY/MM/DD HH24:MI:SS') BETWEEN start_date
                                                                     AND end_date;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_period_name   := NULL;
                END;
            END IF;



            IF     lv_vs_file_path IS NOT NULL
               AND NVL (lv_vs_file_path, 'X') <> 'NA'
               AND lv_vs_file_name IS NOT NULL
            THEN
                lv_ou_short_name   := NULL;

                --                BEGIN
                --                   SELECT ffvl.attribute2
                --                     INTO lv_ou_short_name
                --                     FROM apps.fnd_flex_value_sets fvs,
                --                          apps.fnd_flex_values_vl ffvl
                --                    WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                --                          AND fvs.flex_value_set_name =
                --                                 'XXD_GL_AAR_OU_SHORTNAME_VS'
                --                          AND NVL (TRUNC (ffvl.start_date_active),
                --                                   TRUNC (SYSDATE)) <= TRUNC (SYSDATE)
                --                          AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                --                                 TRUNC (SYSDATE)
                --                          AND ffvl.enabled_flag = 'Y'
                --                          --AND ffvl.attribute1 = p_operating_unit;
                --                          AND ffvl.attribute3 = pv_company;
                --                EXCEPTION
                --                   WHEN OTHERS
                --                   THEN
                --
                --                      lv_ou_short_name := NULL;
                ----                      fnd_file.put_line (fnd_file.LOG,'Exce fetching OU Short Name is - ' || SUBSTR(SQLERRM,1,200));
                --
                --                END;

                --                fnd_file.put_line (fnd_file.LOG,'pn_ou_id is - ' || p_operating_unit);
                --                fnd_file.put_line (fnd_file.LOG,'lv_ou_short_name is - ' || lv_ou_short_name);

                lv_file_dir        := lv_vs_file_path;

                IF pv_type = 'ASSET'
                THEN
                    lv_file_name   :=
                           lv_vs_file_name
                        || '_'
                        || lv_period_name
                        || '_'
                        || lv_ou_short_name
                        || '_'
                        || pv_type
                        || '_'
                        || gn_request_id
                        || '_'
                        || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                        || '.txt';

                    --                END IF;



                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Supporting File Name is - ' || lv_file_name);

                    lv_output_file   :=
                        UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                      ,
                                        32767);

                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        FOR i IN op_file_ret
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;
                    ELSE
                        lv_err_msg      :=
                            SUBSTR (
                                   'Error in Opening the  data file for writing. Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        write_log (lv_err_msg);
                        x_ret_code      := gn_error;
                        x_ret_message   := lv_err_msg;
                        RETURN;
                    END IF;

                    UTL_FILE.fclose (lv_output_file);
                ELSIF pv_type = 'LIABILITY_RETAIL'
                THEN
                    lv_file_name   :=
                           lv_vs_file_name
                        || '_'
                        || lv_period_name
                        || '_'
                        || lv_ou_short_name
                        || '_'
                        || pv_type
                        || '_'
                        || gn_request_id
                        || '_'
                        || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                        || '.txt';


                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Supporting File Name is - ' || lv_file_name);

                    lv_output_file   :=
                        UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                      ,
                                        32767);

                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        FOR i IN op_lia_file_ret
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;
                    ELSE
                        lv_err_msg      :=
                            SUBSTR (
                                   'Error in Opening the  data file for writing. Error is : '
                                || SQLERRM,
                                1,
                                2000);
                        write_log (lv_err_msg);
                        x_ret_code      := gn_error;
                        x_ret_message   := lv_err_msg;
                        RETURN;
                    END IF;

                    UTL_FILE.fclose (lv_output_file);
                END IF;
            END IF;
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20101, lv_err_msg);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_MODE: The open_mode parameter in FOPEN was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20102, lv_err_msg);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILEHANDLE: The file handle was invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20103, lv_err_msg);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_OPERATION: The file could not be opened or operated on as requested.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20104, lv_err_msg);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'READ_ERROR: An operating system error occurred during the read operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20105, lv_err_msg);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'WRITE_ERROR: An operating system error occurred during the write operation.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20106, lv_err_msg);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      := 'INTERNAL_ERROR: An unspecified error in PL/SQL.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20107, lv_err_msg);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_FILENAME: The filename parameter is invalid.';
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20108, lv_err_msg);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                SUBSTR (
                       'Error while creating or writing the data into the file.'
                    || SQLERRM,
                    1,
                    2000);
            write_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_op_file;

    PROCEDURE update_attributes (x_ret_message OUT VARCHAR2, pv_period_end_date IN VARCHAR2, pv_type IN VARCHAR2)
    IS
        lv_last_date   VARCHAR2 (50);

        CURSOR c_get_data IS
            SELECT a.ROWID,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  1)
                       entity_uniq_ident,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  6)
                       account_number,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  2)
                       key3,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  3)
                       key4,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  4)
                       key5,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  5)
                       key6,
                   REGEXP_SUBSTR (a.accumulated_amort_gl_code, '[^.]+', 1,
                                  7)
                       key7,
                   NULL
                       key8,
                   NULL
                       key9,
                   NULL
                       key10,
                   REPLACE (a.accumulated_amort, ',', '')
                       sub_acct_amort_balance,
                   NULL
                       sub_acct_init_balance
              FROM xxdo.xxd_rms_lmt_asset_stg_t a --, gl_code_combinations_kfv c
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND NVL (accumulated_amort, 0) <> 0
            UNION ALL
            SELECT a.ROWID,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  1) entity_uniq_ident,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  6) account_number,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  2) key3,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  3) key4,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  4) key5,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  5) key6,
                   REGEXP_SUBSTR (a.initial_asset_bal_gl_code, '[^.]+', 1,
                                  7) key7,
                   NULL key8,
                   NULL key9,
                   NULL key10,
                   NULL sub_acct_amort_balance,
                   REPLACE (a.initial_asset_bal, ',', '') sub_acct_init_balance
              FROM xxdo.xxd_rms_lmt_asset_stg_t a --, gl_code_combinations_kfv c
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND NVL (initial_asset_bal, 0) <> 0;

        CURSOR c_lia_get_data IS
            SELECT a.ROWID,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  1) entity_uniq_ident,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  6) account_number,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  2) key3,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  3) key4,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  4) key5,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  5) key6,
                   REGEXP_SUBSTR (a.SHORT_TERM_GL_CODE, '[^.]+', 1,
                                  7) key7,
                   NULL key8,
                   NULL key9,
                   NULL key10,
                   REPLACE (a.SHORT_TERM_LIABILITY_ADJ, ',', '') sub_acct_balance
              FROM xxdo.xxd_rms_lmt_liability_stg_t a --, gl_code_combinations_kfv c
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND NVL (SHORT_TERM_LIABILITY_ADJ, 0) <> 0
            UNION ALL
            SELECT a.ROWID,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  1) entity_uniq_ident,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  6) account_number,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  2) key3,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  3) key4,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  4) key5,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  5) key6,
                   REGEXP_SUBSTR (a.LONG_TERM_GL_CODE, '[^.]+', 1,
                                  7) key7,
                   NULL key8,
                   NULL key9,
                   NULL key10,
                   REPLACE (a.LONG_TERM_LIABILITY_ADJ, ',', '') sub_acct_balance
              FROM xxdo.xxd_rms_lmt_liability_stg_t a --, gl_code_combinations_kfv c
             WHERE     1 = 1
                   AND a.request_id = gn_request_id
                   AND NVL (LONG_TERM_LIABILITY_ADJ, 0) <> 0;
    BEGIN
        -- Period end date of the as of date

        -- Period end date of the as of date
        SELECT LAST_DAY (TO_DATE (pv_period_end_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO lv_last_date
          FROM DUAL;

        IF pv_type = 'ASSET'
        THEN
            FOR i IN c_get_data
            LOOP
                IF i.sub_acct_amort_balance IS NOT NULL
                THEN
                    --dbms_output.put_line('IF sub_acct_amort_balance IS NOT NULL '||i.sub_acct_amort_balance);
                    BEGIN
                        UPDATE xxdo.XXD_RMS_LMT_ASSET_STG_T
                           SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.key3,
                               Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                               Key7 = i.Key7, Key8 = i.Key8, Key9 = i.Key9,
                               Key10 = i.Key10, Period_End_Date = lv_last_date, Subledr_Rep_Bal = NULL,
                               Subledr_alt_Bal = NULL, --Subledr_Acc_Bal_init = i.sub_acct_init_balance,
                                                       Subledr_Acc_Bal_amort = i.sub_acct_amort_balance
                         WHERE     1 = 1
                               AND ROWID = i.ROWID
                               AND request_id = gn_request_id;
                    --                       AND NVL(accumulated_amort,0) <> 0;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    --dbms_output.put_line('Error with update in Loop - '||SQLERRM||' for record num - '||ln_count);
                    END;
                --                ELSE
                --                --dbms_output.put_line('IF sub_acct_amort_balance IS NULL '||i.sub_acct_amort_balance);
                --                    NULL;
                END IF;

                IF i.sub_acct_init_balance IS NOT NULL
                THEN
                    BEGIN
                        UPDATE xxdo.XXD_RMS_LMT_ASSET_STG_T
                           SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.key3,
                               Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                               Key7 = i.Key7, Key8 = i.Key8, Key9 = i.Key9,
                               Key10 = i.Key10, Period_End_Date = lv_last_date, Subledr_Rep_Bal = NULL,
                               Subledr_alt_Bal = NULL, Subledr_Acc_Bal_init = i.sub_acct_init_balance
                         --                       Subledr_Acc_Bal_amort = i.sub_acct_amort_balance
                         WHERE     1 = 1
                               AND ROWID = i.ROWID
                               AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    --dbms_output.put_line('Error with update in Loop - '||SQLERRM||' for record num - '||ln_count);
                    END;
                END IF;
            END LOOP;

            COMMIT;
            /*BEGIN
            UPDATE xxdo.XXD_RMS_LMT_ASSET_STG_T
               SET entity_uniq_identifier = i.entity_uniq_ident,
                   Account_Number = i.account_number,
                   Key3 = i.key3,
                   Key4 = i.Key4,
                   Key5 = i.Key5,
                   Key6 = i.Key6,
                   Key7 = i.Key7,
                   Key8 = i.Key8,
                   Key9 = i.Key9,
                   Key10 = i.Key10,
                   Period_End_Date = lv_last_date,
                   Subledr_Rep_Bal = NULL,
                   Subledr_alt_Bal = NULL,
                   Subledr_Acc_Bal_init = i.sub_acct_init_balance,
                   Subledr_Acc_Bal_amort = i.sub_acct_amort_balance
             WHERE 1=1
                   AND ROWID = i.ROWID
                   AND request_id = gn_request_id;
            EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
--                fnd_file.put_line(fnd_file.log,'Error with update in Loop - '||SQLERRM);
            END;*/
        --END LOOP;

        ELSIF pv_type = 'LIABILITY_RETAIL'
        THEN
            FOR i IN c_lia_get_data
            LOOP
                BEGIN
                    UPDATE xxdo.XXD_RMS_LMT_liability_STG_T
                       SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.key3,
                           Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                           Key7 = i.Key7, Key8 = i.Key8, Key9 = i.Key9,
                           Key10 = i.Key10, Period_End_Date = lv_last_date, Subledr_Rep_Bal = NULL,
                           Subledr_alt_Bal = NULL, Subledr_Acc_Bal = i.sub_acct_balance
                     WHERE ROWID = i.ROWID AND request_id = gn_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                --                fnd_file.put_line(fnd_file.log,'Error with update in Loop - '||SQLERRM);
                END;
            END LOOP;
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_attributes;

    PROCEDURE update_valueset_prc (pv_file_path IN VARCHAR2)
    IS
        lv_user_name      VARCHAR2 (100);
        lv_request_info   VARCHAR2 (100);
    BEGIN
        lv_user_name      := NULL;
        lv_request_info   := NULL;

        BEGIN
            SELECT fu.user_name, TO_CHAR (fcr.actual_start_date, 'MM/DD/RRRR HH24:MI:SS')
              INTO lv_user_name, lv_request_info
              FROM apps.fnd_concurrent_requests fcr, apps.fnd_user fu
             WHERE request_id = gn_request_id AND requested_by = fu.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_name      := NULL;
                lv_request_info   := NULL;
        END;

        UPDATE apps.fnd_flex_values_vl FFVL
           SET ffvl.attribute5 = lv_user_name, ffvl.attribute6 = lv_request_info
         WHERE     NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y'
               AND ffvl.description = 'LXBALANCES'
               AND ffvl.flex_value = pv_file_path
               AND ffvl.flex_value_set_id IN
                       (SELECT flex_value_set_id
                          FROM apps.fnd_flex_value_sets
                         WHERE flex_value_set_name =
                               'XXD_GL_AAR_FILE_DETAILS_VS');

        COMMIT;
    END update_valueset_prc;
END XXD_RMS_LMT_BAL_PKG;
/
