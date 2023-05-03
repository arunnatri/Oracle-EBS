--
-- XXD_GL_JE_UPLOAD_IB_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_JE_UPLOAD_IB_PKG"
AS
    /******************************************************************************************
     NAME           : XXD_GL_JE_UPLOAD_IB_PKG
     REPORT NAME    : Deckers GL Journal Automation Inbound program

     REVISIONS:
     Date        Author             Version  Description
     ----------  ----------         -------  ---------------------------------------------------
     05-SEP-2022 Thirupathi Gajula  1.0      Created this package XXD_GL_JE_UPLOAD_IB_PKG for
                                             validate GL Journal data and send it to GL Interface
    *********************************************************************************************/
    -- ======================================================================================
    -- This procedure will print the log data
    -- ======================================================================================

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

    -- ======================================================================================
    -- This procedure to get file names
    -- ======================================================================================

    PROCEDURE get_file_names (pv_directory_name IN VARCHAR2)
    AS
        LANGUAGE JAVA
        NAME 'XXD_UTL_FILE_LIST.getList( java.lang.String )' ;

    -- ======================================================================================
    -- This Function will remove the junk data
    -- ======================================================================================
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

    -- ======================================================================================
    -- This procedure will move the file from source directory to target directory
    -- ======================================================================================

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

    -- ======================================================================================
    -- This procedure will load the data into staging table
    -- ======================================================================================

    PROCEDURE load_file_into_tbl_prc (
        pv_table                IN     VARCHAR2,
        pv_dir                  IN     VARCHAR2,
        pv_filename             IN     VARCHAR2,
        pv_ignore_headerlines   IN     INTEGER DEFAULT 1,
        pv_delimiter            IN     VARCHAR2 DEFAULT ',',
        pv_optional_enclosed    IN     VARCHAR2 DEFAULT '"',
        pv_num_of_columns       IN     NUMBER,
        x_ret_status               OUT VARCHAR2)
    IS
        l_input         UTL_FILE.file_type;
        l_lastline      VARCHAR2 (4000);
        l_cnames        VARCHAR2 (4000);
        l_bindvars      VARCHAR2 (4000);
        l_status        INTEGER;
        l_cnt           NUMBER DEFAULT 0;
        l_rowcount      NUMBER DEFAULT 0;
        l_sep           CHAR (1) DEFAULT NULL;
        l_errmsg        VARCHAR2 (4000);
        v_eof           BOOLEAN := FALSE;
        l_thecursor     NUMBER DEFAULT DBMS_SQL.open_cursor;
        v_insert        VARCHAR2 (1100);
        l_load_status   VARCHAR2 (10) := 'S';
        l_date          DATE;
    BEGIN
        write_log_prc ('Load Data Process Begins...');
        l_cnt           := 1;
        l_load_status   := 'S';

        FOR tab_columns
            IN (  SELECT column_name, data_type
                    FROM all_tab_columns
                   WHERE     1 = 1
                         AND table_name = pv_table
                         AND column_id <= pv_num_of_columns
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

        l_cnames        := RTRIM (l_cnames, ',');
        l_bindvars      := RTRIM (l_bindvars, ',');
        write_log_prc ('Count of Columns is - ' || l_cnt);
        l_input         := UTL_FILE.fopen (pv_dir, pv_filename, 'r');

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

        BEGIN
            v_insert   :=
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
                        FOR i IN 1 .. l_cnt - 1
                        LOOP
                            DBMS_SQL.bind_variable (
                                l_thecursor,
                                ':b' || i,
                                xxd_remove_junk_fnc (
                                    RTRIM (
                                        RTRIM (
                                            LTRIM (
                                                LTRIM (REGEXP_SUBSTR (l_lastline, '(^|,)("[^"]*"|[^",]*)', 1
                                                                      , i),
                                                       pv_delimiter),
                                                pv_optional_enclosed),
                                            pv_delimiter),
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

                -- Update constant values in to STG table
                UPDATE xxdo.xxd_gl_je_upload_stg_t
                   SET file_name = pv_filename, ledger_name = 'Deckers Japan Secondary', ledger_currency_code = 'JPY',
                       user_je_source_name = 'PCA', user_je_category_name = 'Local Gaap', request_id = gn_request_id,
                       creation_date = SYSDATE, last_update_date = SYSDATE, created_by = gn_user_id,
                       last_updated_by = gn_user_id, last_update_login = gn_login_id, record_status = 'N'
                 WHERE 1 = 1 AND file_name IS NULL AND request_id IS NULL;

                COMMIT;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_load_status   := 'E';
        END;

        IF l_load_status = 'E'
        THEN
            DELETE FROM xxdo.xxd_gl_je_upload_stg_t
                  WHERE file_name = pv_filename;

            COMMIT;
        END IF;

        x_ret_status    := l_load_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (
                'Exception in load_file_into_tbl_prc: ' || SQLERRM);
            l_load_status   := 'E';
            x_ret_status    := l_load_status;
    END load_file_into_tbl_prc;

    -- ======================================================================================
    -- This procedure validate the records present in staging table.
    -- ======================================================================================

    PROCEDURE validate_gl_data (pv_file_name                 VARCHAR2,
                                x_ret_msg         OUT NOCOPY VARCHAR2)
    IS
        lv_user_je_source_name     gl_je_sources.user_je_source_name%TYPE;
        lv_user_je_category_name   gl_je_categories.user_je_category_name%TYPE;
        lv_cur_code                fnd_currencies.currency_code%TYPE;
        lv_ledger_id               NUMBER;
        lv_ret_status              VARCHAR2 (1);
        lv_ret_msg                 VARCHAR2 (4000);
        lv_credit_ccid             VARCHAR2 (2000);
        lv_debit_ccid              VARCHAR2 (2000);
        ln_structure_number        NUMBER;
        lb_sucess                  BOOLEAN;
        v_seg_count                NUMBER;
        l_period_name              gl_periods.period_name%TYPE;

        CURSOR amt_dr_cr IS
              SELECT accounting_date, gl_dr_company, SUM (entered_dr) amt_dr,
                     SUM (entered_cr) amt_cr
                FROM xxd_gl_je_upload_stg_t
               WHERE     1 = 1
                     AND request_id = gn_request_id
                     AND record_status = 'N'
                     AND UPPER (file_name) =
                         UPPER (NVL (pv_file_name, file_name))
            GROUP BY accounting_date, gl_dr_company
            ORDER BY 1;

        CURSOR c_gl_data IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_je_upload_stg_t stg
             WHERE     1 = 1
                   AND request_id = gn_request_id
                   AND record_status = 'N'
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name));
    BEGIN
        write_log_prc ('Start validate_gl_data');
        lv_ret_status   := 'S';
        lv_ret_msg      := NULL;

        ---- LEDGER Validation -----
        BEGIN
            SELECT ledger_id
              INTO lv_ledger_id
              FROM gl_ledgers
             WHERE name = 'Deckers Japan Secondary';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ledger_id    := NULL;
                lv_ret_status   := 'E';
                lv_ret_msg      :=
                    lv_ret_msg || ' - ' || 'The Ledger is not correct. ';
                write_log_prc ('Error Occured in ledger_id-' || SQLERRM);
        END;

        write_log_prc ('Ledger Validation completed');

        ---- SOURCE NAME Validation -----
        BEGIN
            SELECT user_je_source_name
              INTO lv_user_je_source_name
              FROM gl_je_sources
             WHERE je_source_name =
                   (SELECT fv.attribute1
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values fv, apps.fnd_flex_values_tl fvt
                     WHERE     fvs.flex_value_set_name =
                               'XXD_GL_IMP_SPECIFIC_FOLDER_VS'
                           AND fvs.flex_value_set_id = fv.flex_value_set_id
                           AND fv.flex_value_id = fvt.flex_value_id
                           AND fv.flex_value = '1006'
                           AND fvt.language = 'US');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_je_source_name   := NULL;
                lv_ret_status            := 'E';
                lv_ret_msg               :=
                    lv_ret_msg || ' - ' || 'The SOURCE NAME is not correct.';
                write_log_prc (
                    'Error Occured in user_je_source_name-' || SQLERRM);
        END;

        write_log_prc ('Source Validation completed');

        ---- CATEGORY NAME Validation -----
        BEGIN
            SELECT user_je_category_name
              INTO lv_user_je_category_name
              FROM gl_je_categories
             WHERE UPPER (je_category_name) =
                   (SELECT UPPER (fv.attribute2)
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values fv, apps.fnd_flex_values_tl fvt
                     WHERE     fvs.flex_value_set_name =
                               'XXD_GL_IMP_SPECIFIC_FOLDER_VS'
                           AND fvs.flex_value_set_id = fv.flex_value_set_id
                           AND fv.flex_value_id = fvt.flex_value_id
                           AND fv.flex_value = '1006'
                           AND fvt.language = 'US');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_user_je_category_name   := NULL;
                lv_ret_status              := 'E';
                lv_ret_msg                 :=
                       lv_ret_msg
                    || ' - '
                    || 'The Category name is not correct.';
                write_log_prc ('Error Occured in Category name-' || SQLERRM);
        END;

        write_log_prc ('Category Validation completed');

        ---- Currency Code Validation -----
        BEGIN
            SELECT currency_code
              INTO lv_cur_code
              FROM fnd_currencies
             WHERE enabled_flag = 'Y' AND currency_code = 'JPY';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_cur_code     := NULL;
                lv_ret_status   := 'E';
                lv_ret_msg      :=
                       lv_ret_msg
                    || ' - '
                    || 'The Currency code is not correct.';
                write_log_prc ('Error Occured in Currency code-' || SQLERRM);
        END;

        write_log_prc ('Currency Validation completed');

        ---- Total Debit and Credit amounts Validation -----
        BEGIN
            FOR r_amt_dr_cr IN amt_dr_cr
            LOOP
                IF r_amt_dr_cr.amt_dr <> r_amt_dr_cr.amt_cr
                THEN
                    lv_ret_status   := 'E';
                    lv_ret_msg      :=
                           lv_ret_msg
                        || ' - '
                        || 'Total Debit and Credit amounts are not matching for the company. ';
                    write_log_prc (
                           'Total Debit and Credit amounts are not matching for the company-'
                        || SQLERRM);
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ret_status   := 'E';
                lv_ret_msg      :=
                       lv_ret_msg
                    || ' - '
                    || 'Error Occured in Total Debit and Credit amounts.';
                write_log_prc (
                       'Error Occured in Total Debit and Credit amounts-'
                    || SQLERRM);
        END;

        write_log_prc ('Total Debit and Credit amounts validation completed');
        write_log_prc ('lv_ret_status-' || lv_ret_status);

        IF lv_ret_status = 'S'
        THEN
            FOR r_gl_data IN c_gl_data
            LOOP
                lv_ret_status    := 'S';
                lv_ret_msg       := NULL;
                lv_debit_ccid    := NULL;
                lv_credit_ccid   := NULL;

                ---- Accounting Date validation ----
                IF r_gl_data.accounting_date IS NULL
                THEN
                    lv_ret_status   := 'E';
                    lv_ret_msg      :=
                           lv_ret_msg
                        || ' - '
                        || 'Accounting Date can not be null';
                END IF;

                write_log_prc ('Accounting Date Validation completed');

                ---- Line Decription validation ----
                IF r_gl_data.line_description IS NULL
                THEN
                    lv_ret_status   := 'E';
                    lv_ret_msg      :=
                        lv_ret_msg || ' - ' || 'Description can not be null';
                END IF;

                write_log_prc ('Description Validation completed');

                ---- Code combination validation for Debit segments ----
                IF NVL (r_gl_data.entered_dr, 0) <> 0
                THEN    -- Per UAT Changes, skip validation if entered_dr is 0
                    BEGIN
                        ln_structure_number   := NULL;
                        lb_sucess             := NULL;

                        SELECT chart_of_accounts_id
                          INTO ln_structure_number
                          FROM gl_ledgers
                         WHERE name = r_gl_data.ledger_name;

                        lv_debit_ccid         :=
                               r_gl_data.gl_dr_company
                            || '.'
                            || r_gl_data.gl_dr_brand
                            || '.'
                            || r_gl_data.gl_dr_geo
                            || '.'
                            || r_gl_data.gl_dr_channel
                            || '.'
                            || r_gl_data.gl_dr_cost_center
                            || '.'
                            || r_gl_data.gl_dr_account_code
                            || '.'
                            || r_gl_data.gl_dr_interco
                            || '.'
                            || r_gl_data.gl_dr_future;

                        lb_sucess             :=
                            fnd_flex_keyval.validate_segs (
                                operation          => 'CREATE_COMBINATION',
                                appl_short_name    => 'SQLGL',
                                key_flex_code      => 'GL#',
                                structure_number   => ln_structure_number,
                                concat_segments    => lv_debit_ccid,
                                validation_date    => SYSDATE);

                        IF lb_sucess
                        THEN
                            write_log_prc (
                                   'Successful. Debit Code Combination ID:'
                                || fnd_flex_keyval.combination_id ());
                        ELSE
                            lv_ret_status   := 'E';
                            lv_ret_msg      :=
                                   lv_ret_msg
                                || ' - '
                                || 'One or more provided Debit Segment values are not correct combination.';
                            write_log_prc (
                                   'Error creating a Debit Code Combination ID for '
                                || lv_debit_ccid
                                || 'Error:'
                                || fnd_flex_keyval.error_message ());
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_ret_status   := 'E';
                            lv_ret_msg      :=
                                   lv_ret_msg
                                || ' - '
                                || 'Unexpected Error creating a Code Combination ID with provided Debit Segment values.';
                            write_log_prc (
                                   'Unable to create a Code Combination ID for '
                                || lv_debit_ccid
                                || 'Error:'
                                || SQLERRM ());
                    END;
                END IF;

                write_log_prc (
                    'Code combination validation for Debit segments completed');

                ---- Code combination validation for Credit segments ----
                IF NVL (r_gl_data.entered_cr, 0) <> 0
                THEN    -- Per UAT Changes, skip validation if entered_cr is 0
                    BEGIN
                        ln_structure_number   := NULL;
                        lb_sucess             := NULL;

                        SELECT chart_of_accounts_id
                          INTO ln_structure_number
                          FROM gl_ledgers
                         WHERE name = r_gl_data.ledger_name;

                        lv_credit_ccid        :=
                               r_gl_data.gl_cr_company
                            || '.'
                            || r_gl_data.gl_cr_brand
                            || '.'
                            || r_gl_data.gl_cr_geo
                            || '.'
                            || r_gl_data.gl_cr_channel
                            || '.'
                            || r_gl_data.gl_cr_cost_center
                            || '.'
                            || r_gl_data.gl_cr_account_code
                            || '.'
                            || r_gl_data.gl_cr_interco
                            || '.'
                            || r_gl_data.gl_cr_future;

                        lb_sucess             :=
                            fnd_flex_keyval.validate_segs (
                                operation          => 'CREATE_COMBINATION',
                                appl_short_name    => 'SQLGL',
                                key_flex_code      => 'GL#',
                                structure_number   => ln_structure_number,
                                concat_segments    => lv_credit_ccid,
                                validation_date    => SYSDATE);

                        IF lb_sucess
                        THEN
                            write_log_prc (
                                   'Successful. Credit Code Combination ID:'
                                || fnd_flex_keyval.combination_id ());
                        ELSE
                            lv_ret_status   := 'E';
                            lv_ret_msg      :=
                                   lv_ret_msg
                                || ' - '
                                || 'One or more provided Credit Segment values are not correct combination.';
                            write_log_prc (
                                   'Error creating a Credit Code Combination ID for '
                                || lv_credit_ccid
                                || 'Error:'
                                || fnd_flex_keyval.error_message ());
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_ret_status   := 'E';
                            lv_ret_msg      :=
                                   lv_ret_msg
                                || ' - '
                                || 'Unexpected Error creating a Code Combination ID with provided Credit Segment values.';
                            write_log_prc (
                                   'Unable to create a Code Combination ID for '
                                || lv_credit_ccid
                                || 'Error:'
                                || SQLERRM ());
                    END;
                END IF;

                write_log_prc (
                    'Code combination validation for Credit segments completed');

                -- Derivation of Period Name
                BEGIN
                    SELECT DISTINCT gps.period_name
                      INTO l_period_name
                      FROM gl_period_statuses gps
                     WHERE     gps.set_of_books_id = lv_ledger_id
                           AND gps.adjustment_period_flag = 'N'
                           AND TRUNC (
                                   TO_DATE (r_gl_data.accounting_date,
                                            'YYYYMMDD')) BETWEEN TRUNC (
                                                                     gps.start_date)
                                                             AND TRUNC (
                                                                     gps.end_date);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ret_status   := 'E';
                        lv_ret_msg      :=
                               lv_ret_msg
                            || ' - '
                            || 'Unexpected Error in GL PERIODS.';
                        write_log_prc (
                            'Unable to get GL Period Name' || SQLERRM ());
                END;

                write_log_prc ('Derive GL Period Name is completed');

                -- Update status and derived values in to STG table.
                UPDATE xxdo.xxd_gl_je_upload_stg_t
                   SET accounting_date = r_gl_data.accounting_date, debit_ccid = r_gl_data.gl_dr_company || '.' || r_gl_data.gl_dr_brand || '.' || r_gl_data.gl_dr_geo || '.' || r_gl_data.gl_dr_channel || '.' || r_gl_data.gl_dr_cost_center || '.' || r_gl_data.gl_dr_account_code || '.' || r_gl_data.gl_dr_interco || '.' || r_gl_data.gl_dr_future, credit_ccid = r_gl_data.gl_cr_company || '.' || r_gl_data.gl_cr_brand || '.' || r_gl_data.gl_cr_geo || '.' || r_gl_data.gl_cr_channel || '.' || r_gl_data.gl_cr_cost_center || '.' || r_gl_data.gl_cr_account_code || '.' || r_gl_data.gl_cr_interco || '.' || r_gl_data.gl_cr_future,
                       journal_batch_name = 'Japan FA JE from PCA and ' || l_period_name, journal_name = 'Japan FA JE PCA ' || l_period_name || ' ' || TO_CHAR (TO_DATE (r_gl_data.accounting_date, 'YYYYMMDD'), 'DD-MON-RRRR'), ledger_id = lv_ledger_id,
                       request_id = gn_request_id, record_status = lv_ret_status, error_msg = error_msg || lv_ret_msg
                 WHERE     ROWID = r_gl_data.ROWID
                       AND UPPER (file_name) =
                           UPPER (NVL (pv_file_name, file_name))
                       AND request_id = gn_request_id;

                write_log_prc ('Update Staging completed');
            END LOOP;
        ELSE
            -- Update status and derived values in to STG table.
            UPDATE xxdo.xxd_gl_je_upload_stg_t
               SET ledger_id = lv_ledger_id, request_id = gn_request_id, record_status = lv_ret_status,
                   error_msg = error_msg || lv_ret_msg
             WHERE     UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name))
                   AND request_id = gn_request_id;

            write_log_prc ('Update Staging completed');
        END IF;

        COMMIT;
        write_log_prc ('End validate_gl_data');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc (SQLERRM || 'validate_gl_data');
            x_ret_msg   := 'validate_data-' || SQLERRM;
    END validate_gl_data;

    -- ======================================================================================
    -- This procedure will insert data into GL_INTERFACE table
    -- ======================================================================================

    PROCEDURE populate_gl_int (pv_file_name                 VARCHAR2,
                               x_ret_msg         OUT NOCOPY VARCHAR2)
    IS
        --Get Valid records from staging

        CURSOR get_valid_data IS
            SELECT stg.ROWID, stg.*
              FROM xxdo.xxd_gl_je_upload_stg_t stg
             WHERE     request_id = gn_request_id
                   AND record_status = 'S'
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name));

        ln_count       NUMBER := 0;
        ln_err_count   NUMBER := 0;
        v_seq          NUMBER;
        v_group_id     NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Populate GL Interface');

        SELECT COUNT (*)
          INTO ln_err_count
          FROM xxdo.xxd_gl_je_upload_stg_t stg
         WHERE     request_id = gn_request_id
               AND record_status = 'E'
               AND UPPER (file_name) = UPPER (NVL (pv_file_name, file_name));

        IF ln_err_count = 0
        THEN
            FOR valid_data_rec IN get_valid_data
            LOOP
                ln_count   := ln_count + 1;

                IF NVL (valid_data_rec.entered_cr, 0) > 0
                THEN
                    INSERT INTO gl_interface (status,
                                              ledger_id,
                                              GROUP_ID,
                                              user_je_source_name,
                                              user_je_category_name,
                                              currency_code,
                                              actual_flag,
                                              accounting_date,
                                              date_created,
                                              created_by,
                                              entered_cr,
                                              segment1,
                                              segment2,
                                              segment3,
                                              segment4,
                                              segment5,
                                              segment6,
                                              segment7,
                                              segment8,
                                              reference1,
                                              reference4,
                                              reference5,
                                              reference10,
                                              currency_conversion_date)
                             VALUES (
                                        'NEW',
                                        valid_data_rec.ledger_id,
                                        99997,                    -- group_id,
                                        valid_data_rec.user_je_source_name,
                                        valid_data_rec.user_je_category_name,
                                        valid_data_rec.ledger_currency_code,
                                        'A',
                                        TO_CHAR (
                                            TO_DATE (
                                                valid_data_rec.accounting_date,
                                                'YYYYMMDD'),
                                            'DD-MON-RRRR'),
                                        valid_data_rec.creation_date,
                                        gn_user_id,
                                        valid_data_rec.entered_cr,
                                        valid_data_rec.gl_cr_company,
                                        valid_data_rec.gl_cr_brand,
                                        valid_data_rec.gl_cr_geo,
                                        valid_data_rec.gl_cr_channel,
                                        valid_data_rec.gl_cr_cost_center,
                                        valid_data_rec.gl_cr_account_code,
                                        valid_data_rec.gl_cr_interco,
                                        valid_data_rec.gl_cr_future,
                                        valid_data_rec.journal_batch_name,
                                        valid_data_rec.journal_name,
                                        valid_data_rec.line_description,
                                        valid_data_rec.line_description,
                                        TO_CHAR (
                                            TO_DATE (
                                                valid_data_rec.accounting_date,
                                                'YYYYMMDD'),
                                            'DD-MON-RRRR'));
                END IF;

                IF NVL (valid_data_rec.entered_dr, 0) > 0
                THEN
                    INSERT INTO gl_interface (status,
                                              ledger_id,
                                              GROUP_ID,
                                              user_je_source_name,
                                              user_je_category_name,
                                              currency_code,
                                              actual_flag,
                                              accounting_date,
                                              date_created,
                                              created_by,
                                              entered_dr,
                                              segment1,
                                              segment2,
                                              segment3,
                                              segment4,
                                              segment5,
                                              segment6,
                                              segment7,
                                              segment8,
                                              reference1,
                                              reference4,
                                              reference5,
                                              reference10,
                                              currency_conversion_date)
                             VALUES (
                                        'NEW',
                                        valid_data_rec.ledger_id,
                                        99997,                    -- group_id,
                                        valid_data_rec.user_je_source_name,
                                        valid_data_rec.user_je_category_name,
                                        valid_data_rec.ledger_currency_code,
                                        'A',
                                        TO_CHAR (
                                            TO_DATE (
                                                valid_data_rec.accounting_date,
                                                'YYYYMMDD'),
                                            'DD-MON-RRRR'),
                                        valid_data_rec.creation_date,
                                        gn_user_id,
                                        valid_data_rec.entered_dr,
                                        valid_data_rec.gl_dr_company,
                                        valid_data_rec.gl_dr_brand,
                                        valid_data_rec.gl_dr_geo,
                                        valid_data_rec.gl_dr_channel,
                                        valid_data_rec.gl_dr_cost_center,
                                        valid_data_rec.gl_dr_account_code,
                                        valid_data_rec.gl_dr_interco,
                                        valid_data_rec.gl_dr_future,
                                        valid_data_rec.journal_batch_name,
                                        valid_data_rec.journal_name,
                                        valid_data_rec.line_description,
                                        valid_data_rec.line_description,
                                        TO_CHAR (
                                            TO_DATE (
                                                valid_data_rec.accounting_date,
                                                'YYYYMMDD'),
                                            'DD-MON-RRRR'));
                END IF;

                ---- Update status to STG table for processed records

                UPDATE xxdo.xxd_gl_je_upload_stg_t
                   SET record_status   = 'P'
                 WHERE     request_id = gn_request_id
                       AND ROWID = valid_data_rec.ROWID;
            END LOOP;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Error records in Staging Table Count: ' || ln_err_count);
        END IF;

        COMMIT;
        fnd_file.put_line (fnd_file.LOG,
                           'GL_INTERFACE Record Count: ' || ln_count);
        x_ret_msg   := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_msg   := SQLERRM;
            fnd_file.put_line (fnd_file.LOG,
                               'Error in POPULATE_GL_INT:' || SQLERRM);
    END populate_gl_int;

    -- ======================================================================================
    -- This procedure will write the ouput data into file for report
    -- ======================================================================================

    PROCEDURE generate_exception_report_prc (pv_file_name VARCHAR2, pv_directory_path IN VARCHAR2, pv_exc_file_name OUT VARCHAR2)
    IS
        CURSOR c_gl_rpt IS
              SELECT stg.*
                FROM xxdo.xxd_gl_je_upload_stg_t stg
               WHERE     request_id = gn_request_id
                     AND UPPER (file_name) =
                         UPPER (NVL (pv_file_name, file_name))
            ORDER BY accounting_date;

        --DEFINE VARIABLES

        lv_output_file      UTL_FILE.file_type;
        lv_outbound_file    VARCHAR2 (4000);
        lv_err_msg          VARCHAR2 (4000) := NULL;
        lv_line             VARCHAR2 (32767) := NULL;
        lv_directory_path   VARCHAR2 (2000);
        lv_file_name        VARCHAR2 (4000);
        l_line              VARCHAR2 (4000);
        lv_result           VARCHAR2 (1000);
    BEGIN
        lv_outbound_file    :=
               gn_request_id
            || '_Exception_RPT_'
            || TO_CHAR (SYSDATE, 'RRRR-MON-DD HH24:MI:SS')
            || '.xls';

        write_log_prc ('Exception File Name is - ' || lv_outbound_file);
        lv_directory_path   := pv_directory_path;
        lv_output_file      :=
            UTL_FILE.fopen (lv_directory_path, lv_outbound_file, 'W',
                            32767);

        IF UTL_FILE.is_open (lv_output_file)
        THEN
            lv_line   :=
                   'Ledger Name'
                || CHR (9)
                || 'User JE Source Name'
                || CHR (9)
                || 'User JE Category Name'
                || CHR (9)
                || 'Ledger Currency Code'
                || CHR (9)
                || 'Accounting Date'
                || CHR (9)
                || 'Company (Debit)'
                || CHR (9)
                || 'Brand (Debit)'
                || CHR (9)
                || 'Geo (Debit)'
                || CHR (9)
                || 'Channel (Debit)'
                || CHR (9)
                || 'Cost Center (Debit)'
                || CHR (9)
                || 'Account Code (Debit)'
                || CHR (9)
                || 'Interco (Debit)'
                || CHR (9)
                || 'Future (Debit)'
                || CHR (9)
                || 'Company (Credit)'
                || CHR (9)
                || 'Brand (Credit)'
                || CHR (9)
                || 'Geo (Credit)'
                || CHR (9)
                || 'Channel (Credit)'
                || CHR (9)
                || 'Cost Center (Credit)'
                || CHR (9)
                || 'Account Code (Credit)'
                || CHR (9)
                || 'Interco (Credit)'
                || CHR (9)
                || 'Future (Credit)'
                || CHR (9)
                || 'Entered DR'
                || CHR (9)
                || 'Entered CR'
                || CHR (9)
                || 'Description'
                || CHR (9)
                || 'Request ID'
                || CHR (9)
                || 'File Name'
                || CHR (9)
                || 'Record Status'
                || CHR (9)
                || 'Error Message';

            UTL_FILE.put_line (lv_output_file, lv_line);

            FOR r_gl_rpt IN c_gl_rpt
            LOOP
                lv_line   :=
                       NVL (r_gl_rpt.ledger_name, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.user_je_source_name, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.user_je_category_name, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.ledger_currency_code, '')
                    || CHR (9)
                    || NVL (
                           TO_CHAR (
                               TO_DATE (r_gl_rpt.accounting_date, 'YYYYMMDD'),
                               'DD-MON-RRRR'),
                           '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_company, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_brand, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_geo, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_channel, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_cost_center, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_account_code, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_interco, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_dr_future, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_company, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_brand, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_geo, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_channel, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_cost_center, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_account_code, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_interco, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.gl_cr_future, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.entered_dr, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.entered_cr, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.line_description, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.request_id, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.file_name, '')
                    || CHR (9)
                    || NVL (r_gl_rpt.record_status, '')
                    || CHR (9)
                    || NVL (SUBSTR (r_gl_rpt.error_msg, 1, 200), '');

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
        pv_exc_file_name    := lv_outbound_file;
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

    -- ======================================================================================
    -- This procedure will generate report and send the email notification to user
    -- ======================================================================================

    PROCEDURE generate_report_prc (pv_file_name            IN VARCHAR2,
                                   pv_exc_directory_path   IN VARCHAR2)
    IS
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
        ln_war_rec              NUMBER;
        l_file_name_str         VARCHAR2 (1000);
    BEGIN
        ln_rec_fail      := 0;
        ln_rec_total     := 0;
        ln_rec_success   := 0;
        ln_war_rec       := 0;

        BEGIN
            SELECT COUNT (1)
              INTO ln_rec_total
              FROM xxdo.xxd_gl_je_upload_stg_t
             WHERE     request_id = gn_request_id
                   AND UPPER (file_name) =
                       UPPER (NVL (pv_file_name, file_name));
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_rec_total   := 0;
        END;

        IF ln_rec_total <= 0
        THEN
            write_log_prc ('There is nothing to Process...No File Exists.');
        ELSE
            BEGIN
                SELECT COUNT (1)
                  INTO ln_rec_success
                  FROM xxdo.xxd_gl_je_upload_stg_t
                 WHERE     request_id = gn_request_id
                       AND UPPER (file_name) =
                           UPPER (NVL (pv_file_name, file_name))
                       AND record_status = 'P';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_rec_success   := 0;
            END;

            l_file_name_str         :=
                   ' File Name                                            - '
                || pv_file_name;
            ln_rec_fail             := ln_rec_total - ln_rec_success;
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '              Summary of Deckers GL Japan Journal Inbound Program ');
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
            apps.fnd_file.put_line (apps.fnd_file.output, l_file_name_str);
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
            --IF ln_rec_fail > 0 THEN
            lv_exc_directory_path   := pv_exc_directory_path;
            generate_exception_report_prc (pv_file_name,
                                           lv_exc_directory_path,
                                           lv_exc_file_name);
            lv_exc_file_name        :=
                   lv_exc_directory_path
                || lv_mail_delimiter
                || lv_exc_file_name;
            write_log_prc ('lv_exc_file_name- ' || lv_exc_file_name);
            lv_message              :=
                   'Hello Team,'
                || CHR (10)
                || CHR (10)
                || 'Please Find the Attached Deckers GL Japan Journal Inbound Program Report. '
                || CHR (10)
                || CHR (10)
                || l_file_name_str
                || CHR (10)
                || ' Number of Rows in the File                           - '
                || ln_rec_total
                || CHR (10)
                || ' Number of Rows Errored                               - '
                || ln_rec_fail
                || CHR (10)
                || ' Number of Rows Successful                            - '
                || ln_rec_success
                || CHR (10)
                || CHR (10)
                || 'Regards,'
                || CHR (10)
                || 'SYSADMIN.'
                || CHR (10)
                || CHR (10)
                || 'Note: This is auto generated mail, please donot reply.';

            BEGIN
                SELECT LISTAGG (flv.meaning, ';') WITHIN GROUP (ORDER BY flv.meaning)
                  INTO lv_recipients
                  FROM fnd_lookup_values flv
                 WHERE     lookup_type = 'XXD_GL_JE_IB_EMAILS_LKP'
                       AND enabled_flag = 'Y'
                       AND language = 'US'
                       AND SYSDATE BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                                 NVL (end_date_active,
                                                      SYSDATE)
                                               + 1);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_recipients   := NULL;
            END;

            xxdo_mail_pkg.send_mail (
                pv_sender         => 'erp@deckers.com',
                pv_recipients     => lv_recipients,
                pv_ccrecipients   => NULL,
                pv_subject        =>
                    'Deckers GL Japan Journal Inbound Program Report',
                pv_message        => lv_message,
                pv_attachments    => lv_exc_file_name,
                xv_result         => lv_result,
                xv_result_msg     => lv_result_msg);

            BEGIN
                UTL_FILE.fremove (lv_exc_directory_path, lv_exc_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    write_log_prc (
                           'Unable to delete the execption report file- '
                        || SQLERRM);
            END;

            write_log_prc ('lvresult is - ' || lv_result);
            write_log_prc ('lv_result_msg is - ' || lv_result_msg);
        --END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log_prc ('Exception in generate_report_prc- ' || SQLERRM);
    END generate_report_prc;

    -- ======================================================================================
    -- This procedure is Main Procedure and will perform GL Japan Journal Inbound program
    -- ======================================================================================

    PROCEDURE main_prc (errbuf OUT VARCHAR2, retcode OUT VARCHAR2)
    IS
        CURSOR get_file_cur IS
              SELECT filename
                FROM xxd_utl_file_upload_gt
               WHERE     1 = 1
                     AND UPPER (filename) NOT LIKE UPPER ('%ARCHIVE%')
                     AND UPPER (filename) LIKE '%.CSV'
            ORDER BY filename;

        lv_directory_path          VARCHAR2 (1000);
        lv_inb_directory_path      VARCHAR2 (1000);
        lv_arc_directory_path      VARCHAR2 (1000);
        lv_exc_directory_path      VARCHAR2 (1000);
        lv_file_name               VARCHAR2 (1000);
        lv_exc_file_name           VARCHAR2 (1000);
        lv_ret_message             VARCHAR2 (4000) := NULL;
        lv_ret_code                VARCHAR2 (30) := NULL;
        ln_file_exists             NUMBER;
        lv_line                    VARCHAR2 (32767) := NULL;
        lv_all_file_names          VARCHAR2 (4000) := NULL;
        ln_rec_fail                NUMBER := 0;
        ln_rec_success             NUMBER;
        ln_rec_total               NUMBER;
        ln_ele_rec_total           NUMBER;
        lv_mail_delimiter          VARCHAR2 (1) := '/';
        lv_result                  VARCHAR2 (100);
        lv_result_msg              VARCHAR2 (4000);
        lv_message                 VARCHAR2 (4000);
        lv_sender                  VARCHAR2 (100);
        lv_recipients              VARCHAR2 (4000);
        lv_ccrecipients            VARCHAR2 (4000);
        l_cnt                      NUMBER := 0;
        ln_req_id                  NUMBER;
        lv_phase                   VARCHAR2 (100);
        lv_status                  VARCHAR2 (30);
        lv_dev_phase               VARCHAR2 (100);
        lv_dev_status              VARCHAR2 (100);
        lb_wait_req                BOOLEAN;
        l_exception                EXCEPTION;
        l_reprocess_cnt            NUMBER;
        lv_file_load_status        VARCHAR (10);
        lv_attach_directory_path   VARCHAR2 (1000);
    BEGIN
        write_log_prc ('Start main_prc-');
        lv_exc_file_name   := NULL;
        lv_file_name       := NULL;

        -- Derive the directory Path
        BEGIN
            lv_directory_path   := NULL;

            SELECT directory_path
              INTO lv_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_JPY_INB_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_directory_path   := NULL;
                lv_message          :=
                       'Exception Occurred while retriving the Inbound Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        BEGIN
            lv_arc_directory_path   := NULL;

            SELECT directory_path
              INTO lv_arc_directory_path
              FROM dba_directories
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_JPY_ARC_DIR';
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
             WHERE 1 = 1 AND directory_name LIKE 'XXD_GL_JPY_EXC_DIR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_exc_directory_path   := NULL;
                lv_message              :=
                       'Exception Occurred while retriving the Exception Directory-'
                    || SQLERRM;
                RAISE l_exception;
        END;

        -- Now Get the file names

        write_log_prc ('Start Processing the file from server');
        get_file_names (lv_directory_path);

        FOR data IN get_file_cur
        LOOP
            ln_file_exists   := 0;
            lv_file_name     := NULL;
            lv_file_name     := data.filename;
            ln_req_id        := NULL;
            lv_phase         := NULL;
            lv_status        := NULL;
            lv_dev_phase     := NULL;
            lv_dev_status    := NULL;
            lv_message       := NULL;
            write_log_prc (' File is available - ' || lv_file_name);

            -- Check the file name exists in the table if exists then SKIP
            BEGIN
                SELECT COUNT (1)
                  INTO ln_file_exists
                  FROM xxdo.xxd_gl_je_upload_stg_t
                 WHERE 1 = 1 AND UPPER (file_name) = UPPER (lv_file_name);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_file_exists   := 0;
            END;

            IF ln_file_exists = 0
            THEN
                load_file_into_tbl_prc (
                    pv_table                => 'XXD_GL_JE_UPLOAD_STG_T',
                    pv_dir                  => 'XXD_GL_JPY_INB_DIR',
                    pv_filename             => lv_file_name,
                    pv_ignore_headerlines   => 1,
                    pv_delimiter            => ',',
                    pv_optional_enclosed    => '"',
                    pv_num_of_columns       => 20, -- Change the number of columns
                    x_ret_status            => lv_file_load_status);

                IF lv_file_load_status = 'E'
                THEN
                    write_log_prc (
                        'There is nothing to Process...No File Exists OR File type is other than CSV.');
                ELSE
                    move_file (
                        p_mode     => 'MOVE',
                        p_source   => lv_directory_path || '/' || lv_file_name,
                        p_target   =>
                               lv_arc_directory_path
                            || '/'
                            || SYSDATE
                            || '_'
                            || lv_file_name);
                END IF;
            ELSE
                write_log_prc (
                    '**************************************************************************************************');
                write_log_prc (
                       'Data with this File name - '
                    || lv_file_name
                    || ' - is already loaded. Please change the file data.  ');
                write_log_prc (
                    '**************************************************************************************************');
                move_file (
                    p_mode     => 'MOVE',
                    p_source   => lv_directory_path || '/' || lv_file_name,
                    p_target   =>
                           lv_arc_directory_path
                        || '/'
                        || SYSDATE
                        || '_'
                        || lv_file_name);
            END IF;

            lv_message       := NULL;
            validate_gl_data (lv_file_name, lv_message);

            IF lv_message IS NOT NULL
            THEN
                RAISE l_exception;
            END IF;

            lv_message       := NULL;
            populate_gl_int (lv_file_name, lv_message);

            IF lv_message IS NOT NULL
            THEN
                RAISE l_exception;
            END IF;

            generate_report_prc (lv_file_name, lv_exc_directory_path);
        END LOOP;

        write_log_prc ('End main_prc-');
    EXCEPTION
        WHEN l_exception
        THEN
            write_log_prc (lv_message);
        WHEN OTHERS
        THEN
            write_log_prc ('Error in main_prc-' || SQLERRM);
    END main_prc;
END XXD_GL_JE_UPLOAD_IB_PKG;
/
