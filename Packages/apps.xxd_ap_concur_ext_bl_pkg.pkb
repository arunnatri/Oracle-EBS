--
-- XXD_AP_CONCUR_EXT_BL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_CONCUR_EXT_BL_PKG"
IS
    /******************************************************************************************
     NAME           : XXD_AP_CONCUR_EXT_BL_PKG
     REPORT NAME    : Deckers Concur Accruals Extract to BL

     REVISIONS:
     Date        Author             Version  Description
     ----------  ----------         -------  ---------------------------------------------------
     10-JUN-2021 Srinath Siricilla  1.0      Created this package using XXD_AP_CONCUR_EXT_BL_PKG
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
            DBMS_OUTPUT.put_line (
                'Error in WRITE_LOG Procedure -' || SQLERRM);
    END write_log;

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

    PROCEDURE purge_prc (pn_purge_days IN NUMBER)
    IS
        CURSOR purge_cur IS
            SELECT DISTINCT stg.request_id
              FROM xxdo.xxd_ap_concur_bl_stg_t stg
             WHERE 1 = 1 AND stg.creation_date < (SYSDATE - pn_purge_days);
    BEGIN
        FOR purge_rec IN purge_cur
        LOOP
            DELETE FROM xxdo.xxd_ap_concur_bl_stg_t
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
        NAME 'DirList.getList( java.lang.String )' ;

    PROCEDURE load_file_into_tbl (p_table IN VARCHAR2, p_dir IN VARCHAR2 DEFAULT 'XXD_CONCURACC_BL_INB_DIR', p_filename IN VARCHAR2, p_ignore_headerlines IN INTEGER DEFAULT 1, p_delimiter IN VARCHAR2 DEFAULT ',', p_optional_enclosed IN VARCHAR2 DEFAULT '"'
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
        write_log ('Load Data Process Begins...');
        l_cnt        := 1;

        FOR TAB_COLUMNS
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     1 = 1
                         AND table_name = p_table
                         AND column_id < p_num_of_columns
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

        write_log ('Count of Columns is - ' || l_cnt);

        L_INPUT      := UTL_FILE.FOPEN (p_dir, p_filename, 'r');

        IF p_ignore_headerlines > 0
        THEN
            BEGIN
                FOR i IN 1 .. p_ignore_headerlines
                LOOP
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

        IF NOT v_eof
        THEN
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

            DBMS_SQL.parse (l_theCursor, v_insert, DBMS_SQL.native);

            LOOP
                BEGIN
                    UTL_FILE.get_line (l_input, l_lastLine);
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
                                    RTRIM (LTRIM (LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', --                                                    '([^|]*)(\||$)',
                                                                                                             1
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
                    END;
                END IF;
            END LOOP;

            DBMS_SQL.close_cursor (l_theCursor);
            UTL_FILE.fclose (l_input);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('load_file_into_tbl_prc: ' || SQLERRM);
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

    PROCEDURE process_data_prc (pv_conv_type IN VARCHAR2)
    IS
        CURSOR cur_data IS
              SELECT TRUNC (LAST_DAY (TO_DATE (SUBSTR (stg.accrual_date, 1, 15), 'MON DD YYYY HH:MI'))) period_ed, stg.currency, stg.gl_bal_seg,
                     stg.accrual_date
                FROM xxdo.xxd_ap_concur_bl_stg_t stg
               WHERE 1 = 1 AND request_id = gn_request_id
            GROUP BY stg.currency, stg.gl_bal_seg, stg.accrual_date
            ORDER BY stg.gl_bal_seg;

        lv_led_curr              fnd_currencies.currency_code%TYPE;
        lv_offset_gl_comb        gl_code_combinations_kfv.concatenated_segments%TYPE;
        lv_offset_gl_comb_paid   gl_code_combinations_kfv.concatenated_segments%TYPE;
        ln_conv_rate             gl_daily_rates.conversion_rate%TYPE;
    BEGIN
        --
        -- Get Ledger Currency
        NULL;

        FOR data_rec IN cur_data
        LOOP
            lv_offset_gl_comb        := NULL;
            lv_offset_gl_comb_paid   := NULL;
            lv_led_curr              := NULL;
            ln_conv_rate             := NULL;

            -- Get Ledger Currency

            BEGIN
                SELECT DISTINCT led.currency_code
                  INTO lv_led_curr
                  FROM xle_le_ou_ledger_v led_v, gl_ledgers led
                 WHERE     1 = 1
                       AND led_v.ledger_id = led.ledger_id
                       AND led_v.legal_entity_identifier =
                           data_rec.gl_bal_seg;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_led_curr   := NULL;
            END;

            -- Get the CCID based on Paid Flag

            BEGIN
                SELECT (SELECT concatenated_segments
                          FROM gl_code_combinations_kfv
                         WHERE code_combination_id = ffv.attribute13),
                       (SELECT concatenated_segments
                          FROM gl_code_combinations_kfv
                         WHERE code_combination_id = ffv.attribute14)
                  INTO lv_offset_gl_comb, lv_offset_gl_comb_paid
                  FROM apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values ffv
                 WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                       AND ffvs.flex_value_set_name = 'XXD_CONCUR_OU'
                       AND ffv.enabled_flag = 'Y'
                       AND SYSDATE BETWEEN NVL (ffv.start_date_active,
                                                SYSDATE)
                                       AND NVL (ffv.end_date_active, SYSDATE)
                       AND ffv.flex_value = data_rec.gl_bal_seg;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_offset_gl_comb        := NULL;
                    lv_offset_gl_comb_paid   := NULL;
            END;

            -- Get exchange Rate based on Currency and Conversion Type

            IF lv_led_curr IS NOT NULL AND data_rec.currency = lv_led_curr
            THEN
                ln_conv_rate   := 1;
            ELSIF     lv_led_curr IS NOT NULL
                  AND data_rec.currency <> lv_led_curr
            THEN
                BEGIN
                    SELECT conversion_rate
                      INTO ln_conv_rate
                      FROM gl_daily_rates
                     WHERE     from_currency = data_rec.currency
                           AND to_currency = lv_led_curr
                           AND conversion_type = pv_conv_type
                           AND conversion_date = data_rec.period_ed;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_conv_rate   := NULL;
                END;
            END IF;

            UPDATE xxdo.xxd_ap_concur_bl_stg_t
               SET conversion_rate = ln_conv_rate, Credit_cc = lv_offset_gl_comb, Credit_cc_paid = lv_offset_gl_comb_paid,
                   last_updated_by = gn_user_id, last_update_date = SYSDATE, period_end_date = data_rec.period_ed
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   --AND gl_company = data_rec.gl_bal_seg
                   AND gl_bal_seg = data_rec.gl_bal_seg
                   AND accrual_date = data_rec.accrual_date
                   AND currency = data_rec.currency;
        END LOOP;
    END process_data_prc;

    PROCEDURE MAIN_PRC (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY VARCHAR2, pv_conv_type IN VARCHAR2
                        , pv_file_path IN VARCHAR2)
    IS
        CURSOR get_file_cur IS
            SELECT filename
              FROM XXD_DIR_LIST_TBL_SYN
             WHERE UPPER (filename) NOT LIKE 'ARCHIVE';

        CURSOR cur_gl_data IS
              SELECT gl_bal_seg
                FROM xxdo.xxd_ap_concur_bl_stg_t
               WHERE request_id = gn_request_id
            GROUP BY gl_bal_seg
            ORDER BY gl_bal_seg;

        lv_directory_path       VARCHAR2 (100);
        lv_directory            VARCHAR2 (100);
        lv_arc_directory_path   VARCHAR2 (100);
        lv_file_name            VARCHAR2 (100);
        lv_ret_message          VARCHAR2 (4000) := NULL;
        lv_ret_code             VARCHAR2 (30) := NULL;
        lv_period_name          VARCHAR2 (100);
        ln_file_exists          NUMBER;
        ln_req_id               NUMBER;
        lv_phase                VARCHAR2 (100);
        lv_status               VARCHAR2 (30);
        lv_dev_phase            VARCHAR2 (100);
        lv_dev_status           VARCHAR2 (100);
        lb_wait_req             BOOLEAN;
        lv_message              VARCHAR2 (4000);
    BEGIN
        lv_directory_path       := NULL;
        lv_arc_directory_path   := NULL;
        --lv_directory := 'XXD_CONCURACC_BL_INB_DIR';
        ln_file_exists          := 0;


        -- Derive the directory Path

        BEGIN
            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE directory_name = 'XXD_CONCURACC_BL_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
        END;

        BEGIN
            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE directory_name = 'XXD_CONCURACC_BL_ARC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_arc_directory_path   := NULL;
        END;

        -- Now Get the file names

        get_file_names (lv_directory_path);

        write_log ('File names are fetched');

        FOR data IN get_file_cur
        LOOP
            --NULL;

            -- Check the file name exists in the table if exists then SKIP

            BEGIN
                SELECT COUNT (1)
                  INTO ln_file_exists
                  FROM xxdo.xxd_ap_concur_bl_stg_t
                 WHERE UPPER (file_name) = UPPER (data.filename);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_file_exists   := 0;
            END;

            IF ln_file_exists = 0
            THEN
                load_file_into_tbl (p_table => 'XXD_AP_CONCUR_BL_STG_T', p_dir => 'XXD_CONCURACC_BL_INB_DIR', p_filename => data.filename, p_ignore_headerlines => 1, p_delimiter => ',', p_optional_enclosed => '"'
                                    , p_num_of_columns => 36);

                UPDATE xxdo.xxd_ap_concur_bl_stg_t
                   SET file_name = data.filename, request_id = gn_request_id
                 WHERE file_name IS NULL AND request_id IS NULL;

                --             Utl_File.Fcopy('XXD_CONCURACC_BL_INB_DIR', data.filename, 'XXD_CONCURACC_BL_ARC_DIR',data.filename);

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
                            argument3     => lv_directory_path || '/' || data.filename, -- Source File Directory
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
                    END IF;          -- End of if to check if request ID is 0.

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
            ELSE
                write_log (
                       ' Data with this File name - '
                    || data.filename
                    || ' - is already loaded. Please change the file data ');
            END IF;
        END LOOP;

        COMMIT;

        process_data_prc (pv_conv_type);

        --        FOR gl_data_rec IN cur_gl_data
        --        LOOP
        --
        --        write_log(' cur_gl_data for company - '||gl_data_rec.gl_bal_seg);

        update_attributes (lv_ret_message, lv_period_name);

        write_op_file (pv_file_path, lv_file_name, lv_period_name,
                       --gl_data_rec.gl_bal_seg,
                       lv_ret_code, lv_ret_message);

        --        END LOOP;

        --        update_attributes (lv_ret_message, lv_period_name);

        --        FOR gl_data_rec IN cur_gl_data
        --        LOOP
        --        write_log(' write cur_gl_data for company - '||gl_data_rec.gl_bal_seg);
        write_ret_recon_file (pv_file_path, lv_file_name, --                              gl_data_rec.gl_bal_seg,
                                                          lv_ret_code,
                              lv_ret_message);
        --        END LOOP;

        update_valueset_prc (pv_file_path);
    END MAIN_PRC;


    PROCEDURE write_ret_recon_file (pv_file_path IN VARCHAR2, pv_file_name IN VARCHAR2, --                                    pv_company       IN    VARCHAR2,
                                                                                        x_ret_code OUT VARCHAR2
                                    , x_ret_message OUT VARCHAR2)
    IS
        CURSOR ret_reconcilation IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (Period_End_Date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || Subledr_alt_Bal || CHR (9) || SUM (Subledr_Acc_Bal) * -1) line
                FROM xxdo.xxd_ap_concur_bl_stg_t
               WHERE 1 = 1 AND request_id = gn_request_id
            --                 AND gl_bal_seg = pv_company
            GROUP BY entity_uniq_identifier, Account_Number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, Period_End_Date, Subledr_Rep_Bal,
                     Subledr_alt_Bal;

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
    BEGIN
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
                       AND ffvl.description = 'CONCURACC'
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

    PROCEDURE write_op_file (pv_file_path     IN     VARCHAR2,
                             pv_file_name     IN     VARCHAR2,
                             pv_period_name   IN     VARCHAR2,
                             --                             pv_Company       IN    NUMBER,
                             x_ret_code          OUT VARCHAR2,
                             x_ret_message       OUT VARCHAR2)
    IS
        CURSOR op_file_ret IS
              SELECT line
                FROM (SELECT 1 AS seq, first_name || gv_delimeter || last_name || gv_delimeter || gl_bal_seg || gv_delimeter || gl_interco_seg || gv_delimeter || report_id || gv_delimeter || gl_company || gv_delimeter || gl_brand || gv_delimeter || gl_geo || gv_delimeter || gl_channel || gv_delimeter || gl_cost_center || gv_delimeter || gl_account_code || gv_delimeter || gl_interco || gv_delimeter || gl_future || gv_delimeter || vendor_name || gv_delimeter || vendor_alt_name || gv_delimeter || vendor_desc || gv_delimeter || amount || gv_delimeter || currency || gv_delimeter || transaction_date || gv_delimeter || paid_date || gv_delimeter || paid || gv_delimeter || step_entry_date_time || gv_delimeter || cutoff_date || gv_delimeter || accrual_date || gv_delimeter || paid_flag || gv_delimeter || Subledr_Acc_Bal line
                        FROM xxdo.xxd_ap_concur_bl_stg_t
                       WHERE 1 = 1 AND request_id = gn_request_id--AND gl_bal_seg = pv_Company
                                                                 --                      UNION ALL
                                                                 --                      SELECT 2
                                                                 --                                 AS seq,
                                                                 --                                'Employee First Name'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Employee Last Name'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Balancing Segment Co'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Balancing Segment Interco'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Report ID'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Company'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Brand'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Geo'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Channel'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Cost Center'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Account Code'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Intercompany'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Future Use'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Vendor'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Vendor Alt Name'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Description'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Amount'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Currency'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Transaction Date'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Paid Date'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Paid'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Step Entry Date Time'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Cut Off Date'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Accrual Date'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Paid Flag'
                                                                 --                             || gv_delimeter
                                                                 --                             || 'Functional Amount'
                                                                 --                        FROM DUAL
                                                                 )
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
                       AND ffvl.description = 'CONCURACC'
                       AND ffvl.flex_value = pv_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;


            IF pv_period_name IS NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_CY_CALENDAR'
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
                           AND period_name = pv_period_name;
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
                --
                --                fnd_file.put_line (fnd_file.LOG,'pn_ou_id is - ' || p_operating_unit);
                --                fnd_file.put_line (fnd_file.LOG,'lv_ou_short_name is - ' || lv_ou_short_name);

                lv_file_dir        := lv_vs_file_path;
                --lv_ou_short_name := NULL;
                lv_file_name       :=
                       lv_vs_file_name
                    || '_'
                    || lv_period_name
                    || '_'
                    --                    || lv_ou_short_name
                    --                    || '_'
                    || gn_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';


                fnd_file.put_line (
                    fnd_file.LOG,
                    'Supporting File Name is - ' || lv_file_name);

                lv_output_file     :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    apps.fnd_file.put_line (fnd_file.LOG, 'File is Open');

                    lv_line   :=
                           'Employee First Name'
                        || gv_delimeter
                        || 'Employee Last Name'
                        || gv_delimeter
                        || 'Balancing Segment Co'
                        || gv_delimeter
                        || 'Balancing Segment Interco'
                        || gv_delimeter
                        || 'Report ID'
                        || gv_delimeter
                        || 'Company'
                        || gv_delimeter
                        || 'Brand'
                        || gv_delimeter
                        || 'Geo'
                        || gv_delimeter
                        || 'Channel'
                        || gv_delimeter
                        || 'Cost Center'
                        || gv_delimeter
                        || 'Account Code'
                        || gv_delimeter
                        || 'Intercompany'
                        || gv_delimeter
                        || 'Future Use'
                        || gv_delimeter
                        || 'Vendor'
                        || gv_delimeter
                        || 'Vendor Alt Name'
                        || gv_delimeter
                        || 'Description'
                        || gv_delimeter
                        || 'Amount'
                        || gv_delimeter
                        || 'Currency'
                        || gv_delimeter
                        || 'Transaction Date'
                        || gv_delimeter
                        || 'Paid Date'
                        || gv_delimeter
                        || 'Paid'
                        || gv_delimeter
                        || 'Step Entry Date Time'
                        || gv_delimeter
                        || 'Cut Off Date'
                        || gv_delimeter
                        || 'Accrual Date'
                        || gv_delimeter
                        || 'Paid Flag'
                        || gv_delimeter
                        || 'Functional Amount';

                    UTL_FILE.put_line (lv_output_file, lv_line);

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

    PROCEDURE update_attributes (x_ret_message       OUT VARCHAR2,
                                 pv_period_name   IN     VARCHAR2)
    IS
        l_last_date   DATE;                                   --VARCHAR2 (50);

        CURSOR c_get_data IS
            SELECT a.ROWID,
                   --DECODE(a.paid_flag,'No',REGEXP_SUBSTR(a.credit_cc,'[^.]+',1,1),REGEXP_SUBSTR(a.credit_cc_paid,'[^.]+',1,1)) entity_uniq_ident,
                   a.gl_bal_seg entity_uniq_ident,
                   DECODE (a.paid_flag,
                           'No', REGEXP_SUBSTR (a.credit_cc, '[^.]+', 1,
                                                6),
                           REGEXP_SUBSTR (a.credit_cc_paid, '[^.]+', 1,
                                          6)) account_number,
                   DECODE (a.paid_flag,
                           'No', REGEXP_SUBSTR (a.credit_cc, '[^.]+', 1,
                                                2),
                           REGEXP_SUBSTR (a.credit_cc_paid, '[^.]+', 1,
                                          2)) key3,
                   DECODE (a.paid_flag,
                           'No', REGEXP_SUBSTR (a.credit_cc, '[^.]+', 1,
                                                3),
                           REGEXP_SUBSTR (a.credit_cc_paid, '[^.]+', 1,
                                          3)) key4,
                   DECODE (a.paid_flag,
                           'No', REGEXP_SUBSTR (a.credit_cc, '[^.]+', 1,
                                                4),
                           REGEXP_SUBSTR (a.credit_cc_paid, '[^.]+', 1,
                                          4)) key5,
                   CASE
                       WHEN     a.gl_bal_seg = '190'
                            AND SUBSTR (a.gl_cost_center, 1, 2) = '27'
                       THEN
                           2700
                       ELSE
                           1000
                   END key6--,DECODE(a.paid_flag,'No',REGEXP_SUBSTR(a.credit_cc,'[^.]+',1,5),REGEXP_SUBSTR(a.credit_cc_paid,'[^.]+',1,5)) key6
                           ,
                   DECODE (a.paid_flag,
                           'No', REGEXP_SUBSTR (a.credit_cc, '[^.]+', 1,
                                                7),
                           REGEXP_SUBSTR (a.credit_cc_paid, '[^.]+', 1,
                                          7)) key7,
                   NULL key8,
                   NULL key9,
                   NULL key10,
                   REPLACE (a.amount, ',', '') * conversion_rate sub_acct_balance
              FROM xxdo.xxd_ap_concur_bl_stg_t a --, gl_code_combinations_kfv c
             WHERE 1 = 1 AND a.request_id = gn_request_id;
    --AND a.acc_account = c.concatenated_segments;

    BEGIN
        -- Period end date of the as of date

        BEGIN
            SELECT end_date        --TO_CHAR (end_date, 'MM/DD/YYYY') end_date
              INTO l_last_date
              FROM gl_periods
             WHERE     period_set_name = 'DO_CY_CALENDAR'
                   --AND TRUNC (SYSDATE) BETWEEN start_date AND end_date -- urrent month
                   AND period_name = pv_period_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        --fnd_file.put_line(fnd_file.log,'Erro with Date - '||SQLERRM);
        END;

        FOR i IN c_get_data
        LOOP
            BEGIN
                UPDATE xxdo.xxd_ap_concur_bl_stg_t
                   SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.key3,
                       Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                       Key7 = i.Key7, Key8 = i.Key8, Key9 = i.Key9,
                       Key10 = i.Key10, --Period_End_Date = l_last_date,
                                        Subledr_Rep_Bal = NULL, Subledr_alt_Bal = NULL,
                       Subledr_Acc_Bal = i.sub_acct_balance
                 WHERE ROWID = i.ROWID AND request_id = gn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            --                fnd_file.put_line(fnd_file.log,'Error with update in Loop - '||SQLERRM);
            END;
        END LOOP;

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
               AND ffvl.description = 'CONCURACC'
               AND ffvl.flex_value = pv_file_path
               AND ffvl.flex_value_set_id IN
                       (SELECT flex_value_set_id
                          FROM apps.fnd_flex_value_sets
                         WHERE flex_value_set_name =
                               'XXD_GL_AAR_FILE_DETAILS_VS');

        COMMIT;
    END update_valueset_prc;
END XXD_AP_CONCUR_EXT_BL_PKG;
/
