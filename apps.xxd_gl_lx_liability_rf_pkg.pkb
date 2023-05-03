--
-- XXD_GL_LX_LIABILITY_RF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_LX_LIABILITY_RF_PKG"
AS
    /***************************************************************************************
    * Program Name : XXD_GL_LX_LIABILITY_RF_PKG                                            *
    * Language     : PL/SQL                                                                *
    * Description  : Package used to report the LX Liability Report                 *
    *                                                                                      *
    * History      :                                                                       *
    *                                                                                      *
    * WHO          :       WHAT      Desc                                    WHEN          *
    * -------------- ----------------------------------------------------------------------*
    * Kishan Reddy         1.0       Initial Version                         23-JUN-2022   *
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

            BEGIN
                write_log (
                       'REMOVE files Process Begins...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
                ln_req_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDO_CP_MV_RM_FILE',
                        argument1     => 'REMOVE',
                        argument2     => 2,
                        argument3     =>
                            lv_inb_directory_path || '/' || p_filename,
                        argument4     => NULL,
                        start_time    => SYSDATE,
                        sub_request   => FALSE);
                COMMIT;

                IF ln_req_id = 0
                THEN
                    --retcode := 1;
                    write_log (
                        ' Unable to submit REMOVE files concurrent program ');
                ELSE
                    write_log (
                        'REMOVE Files concurrent request submitted successfully.');
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
                               'REMOVE Files concurrent request with the request id '
                            || ln_req_id
                            || ' completed with NORMAL status.');
                    ELSE
                        --retcode := 1;
                        write_log (
                               'REMOVE Files concurrent request with the request id '
                            || ln_req_id
                            || ' did not complete with NORMAL status.');
                    END IF;
                END IF;

                COMMIT;
                write_log (
                       'REMOVE Files Ends...'
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh:mi:ss'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    --retcode := 2;
                    write_log ('Error in REMOVE Files -' || SQLERRM);
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
             WHERE UPPER (filename) LIKE UPPER ('%LIABILITY%RF%.csv%');

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

        lv_directory_path   := NULL;
        lv_directory        := NULL;
        ln_file_exists      := 0;

        fnd_file.put_line (fnd_file.LOG,
                           'P_REPORT_PROCESS' || P_REPORT_PROCESS);
        fnd_file.put_line (fnd_file.LOG, 'P_DATE			' || P_DATE);
        fnd_file.put_line (fnd_file.LOG, 'P_CURRENCY		' || P_CURRENCY);
        fnd_file.put_line (fnd_file.LOG,
                           'P_OB_SPOT_RATE_DATE	 ' || P_OB_SPOT_RATE_DATE);
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
                      FROM xxdo.xxd_gl_lx_liability_rf_t
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_file_exists   := 0;
                END;

                IF (p_reprocess = 'Yes')
                THEN
                    UPDATE xxdo.xxd_gl_lx_liability_rf_t
                       SET reprocess_flag   = 'Y'
                     WHERE date_parameter = TO_DATE (p_date, 'DD-MON-YY');

                    ln_file_exists   := 0;
                END IF;

                IF ln_file_exists = 0
                THEN
                    -- loading the data into staging table
                    load_file_into_tbl (p_table => 'XXD_GL_LX_LIABILITY_RF_T', p_dir => lv_directory_path, p_filename => data.filename, p_ignore_headerlines => 6, p_delimiter => ',', p_optional_enclosed => '"'
                                        , p_num_of_columns => 17);

                    BEGIN
                        UPDATE xxdo.xxd_gl_lx_liability_rf_t
                           SET file_name          = data.filename,
                               request_id         = gn_request_id,
                               creation_date      = SYSDATE,
                               last_update_date   = SYSDATE,
                               created_by         = gn_user_id,
                               last_updated_by    = gn_user_id,
                               date_parameter     =
                                   TO_DATE (p_date, 'DD-MON-YY'),
                               BEGINNING_BALANCE   =
                                   REGEXP_REPLACE (BEGINNING_BALANCE,
                                                   '[^-.[:digit:]]'),
                               ADDITION          =
                                   REGEXP_REPLACE (ADDITION,
                                                   '[^-.[:digit:]]'),
                               REDUCTION         =
                                   REGEXP_REPLACE (REDUCTION,
                                                   '[^-.[:digit:]]'),
                               PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC   =
                                   REGEXP_REPLACE (
                                       PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC,
                                       '[^-.[:digit:]]'),
                               CLOSING_BALANCE   =
                                   REGEXP_REPLACE (CLOSING_BALANCE,
                                                   '[^-.[:digit:]]'),
                               SHORT_TERM        =
                                   REGEXP_REPLACE (SHORT_TERM,
                                                   '[^-.[:digit:]]'),
                               LONG_TERM         =
                                   REGEXP_REPLACE (LONG_TERM,
                                                   '[^-.[:digit:]]'),
                               PREPAID_AMOUNT    =
                                   REGEXP_REPLACE (PREPAID_AMOUNT,
                                                   '[^-.[:digit:]]'),
                               CLOSING_BALANCE_LESS_PREPAID   =
                                   REGEXP_REPLACE (
                                       CLOSING_BALANCE_LESS_PREPAID,
                                       '[^-.[:digit:]]'),
                               USD_BALANCE_RATE   =
                                   NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   currency_type
                                               AND conversion_type =
                                                   P_BALLANCE_RATE_TYPE
                                               AND conversion_date =
                                                   TO_DATE (p_date,
                                                            'DD-MON-YY')
                                               AND gdr.from_currency <> 'USD'
                                               AND gdr.to_currency = 'USD'),
                                       1),
                               USD_PERIOD_RATE   =
                                   NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   currency_type
                                               AND conversion_type =
                                                   P_PERIOD_RATE_TYPE
                                               AND conversion_date =
                                                   TO_DATE (p_date,
                                                            'DD-MON-YY')
                                               AND gdr.from_currency <> 'USD'
                                               AND gdr.to_currency = 'USD'),
                                       1),
                               FUNCTIONAL_CURRENCY_BALANCE_RATE   =
                                   NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   currency_type
                                               AND conversion_type =
                                                   P_BALLANCE_RATE_TYPE
                                               AND conversion_date =
                                                   TO_DATE (p_date,
                                                            'DD-MON-YY')
                                               AND gdr.to_currency =
                                                   (SELECT (SELECT ffv.ATTRIBUTE7 currency_code_value
                                                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
                                                             WHERE     ffvs.flex_value_set_id =
                                                                       ffv.flex_value_set_id
                                                                   AND ffv.flex_value_id =
                                                                       ffvt.flex_value_id
                                                                   AND ffvt.language =
                                                                       USERENV (
                                                                           'LANG')
                                                                   AND ffv.enabled_flag =
                                                                       'Y'
                                                                   AND ffvs.flex_value_set_name =
                                                                       'DO_GL_COMPANY'
                                                                   AND ffv.flex_value =
                                                                       (TRUNC (
                                                                            REGEXP_SUBSTR (
                                                                                PORTFOLIO,
                                                                                '[^-]+',
                                                                                1,
                                                                                1)))) currency_code_value
                                                      FROM DUAL)),
                                       1),
                               FUNCTIONAL_CURRENCY_PERIOD_RATE   =
                                   NVL (
                                       (SELECT conversion_rate
                                          FROM apps.gl_daily_rates gdr
                                         WHERE     1 = 1
                                               AND gdr.from_currency =
                                                   currency_type
                                               AND conversion_type =
                                                   P_PERIOD_RATE_TYPE
                                               AND conversion_date =
                                                   TO_DATE (p_date,
                                                            'DD-MON-YY')
                                               AND gdr.to_currency =
                                                   (SELECT (SELECT ffv.ATTRIBUTE7 currency_code_value
                                                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
                                                             WHERE     ffvs.flex_value_set_id =
                                                                       ffv.flex_value_set_id
                                                                   AND ffv.flex_value_id =
                                                                       ffvt.flex_value_id
                                                                   AND ffvt.language =
                                                                       USERENV (
                                                                           'LANG')
                                                                   AND ffv.enabled_flag =
                                                                       'Y'
                                                                   AND ffvs.flex_value_set_name =
                                                                       'DO_GL_COMPANY'
                                                                   AND ffv.flex_value =
                                                                       (TRUNC (
                                                                            REGEXP_SUBSTR (
                                                                                PORTFOLIO,
                                                                                '[^-]+',
                                                                                1,
                                                                                1)))) currency_code_value
                                                      FROM DUAL)),
                                       1),
                               FUNCTIONAL_TO_CURRENCY   =
                                   (SELECT (SELECT ffv.ATTRIBUTE7 currency_code_value
                                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
                                             WHERE     ffvs.flex_value_set_id =
                                                       ffv.flex_value_set_id
                                                   AND ffv.flex_value_id =
                                                       ffvt.flex_value_id
                                                   AND ffvt.language =
                                                       USERENV ('LANG')
                                                   AND ffv.enabled_flag = 'Y'
                                                   AND ffvs.flex_value_set_name =
                                                       'DO_GL_COMPANY'
                                                   AND ffv.flex_value =
                                                       (TRUNC (
                                                            REGEXP_SUBSTR (
                                                                PORTFOLIO,
                                                                '[^-]+',
                                                                1,
                                                                1)))) currency_code_value
                                      FROM DUAL),
                               precision         =
                                   NVL (
                                       (SELECT precision
                                          FROM fnd_currencies
                                         WHERE currency_code = currency_type),
                                       2),
                               period_date       =
                                   (SELECT (SELECT END_DATE
                                              FROM gl_periods
                                             WHERE     1 = 1
                                                   AND PERIOD_SET_NAME =
                                                       'DO_FY_CALENDAR'
                                                   AND PERIOD_YEAR =
                                                       FISCAL_PERIOD_YEAR
                                                   AND PERIOD_NUM =
                                                       FISCAL_PERIOD       --1
                                                                    )
                                      FROM DUAL),
                               Balance_Rate       = P_BALLANCE_RATE_TYPE,
                               Period_Rate        = P_PERIOD_RATE_TYPE,
                               ob_date            = P_OB_SPOT_RATE_DATE,
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
                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t
                               SET USD_CLOSING_BALANCE   =
                                       ROUND (
                                             USD_BALANCE_RATE
                                           * NVL (CLOSING_BALANCE, 0),
                                           precision),
                                   USD_SHORT_TERM   =
                                       ROUND (
                                             USD_BALANCE_RATE
                                           * NVL (SHORT_TERM, 0),
                                           precision),
                                   USD_LONG_TERM   =
                                       ROUND (
                                             USD_BALANCE_RATE
                                           * NVL (LONG_TERM, 0),
                                           precision),
                                   USD_PREPAID_AMOUNT   =
                                       ROUND (
                                             USD_BALANCE_RATE
                                           * NVL (PREPAID_AMOUNT, 0),
                                           precision),
                                   USD_CLOSING_BALANCE_LESS_PREPAID   =
                                       ROUND (
                                             USD_BALANCE_RATE
                                           * NVL (
                                                 CLOSING_BALANCE_LESS_PREPAID,
                                                 0),
                                           precision),
                                   USD_BEGINNING_BALANCE   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_BALLANCE_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         P_OB_SPOT_RATE_DATE,
                                                                         'DD-MON-YY')
                                                                 AND gdr.from_currency <>
                                                                     'USD'
                                                                 AND gdr.to_currency =
                                                                     'USD'),
                                                         1)
                                                   * NVL (BEGINNING_BALANCE,
                                                          0)
                                              FROM DUAL),
                                           precision),
                                   USD_ADDITION   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_PERIOD_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         period_date,
                                                                         'DD-MON-YY')
                                                                 AND gdr.from_currency <>
                                                                     'USD'
                                                                 AND gdr.to_currency =
                                                                     'USD'),
                                                         1)
                                                   * NVL (addition, 0)
                                              FROM DUAL),
                                           precision),
                                   USD_REDUCTION   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_PERIOD_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         period_date,
                                                                         'DD-MON-YY')
                                                                 AND gdr.from_currency <>
                                                                     'USD'
                                                                 AND gdr.to_currency =
                                                                     'USD'),
                                                         1)
                                                   * NVL (reduction, 0)
                                              FROM DUAL),
                                           precision),
                                   USD_PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_PERIOD_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         period_date,
                                                                         'DD-MON-YY')
                                                                 AND gdr.from_currency <>
                                                                     'USD'
                                                                 AND gdr.to_currency =
                                                                     'USD'),
                                                         1)
                                                   * NVL (
                                                         period_liability_amortization_expense_calc,
                                                         0)
                                              FROM DUAL),
                                           precision),
                                   USD_PERIOD_RATE   =
                                       NVL (
                                           (SELECT conversion_rate
                                              FROM apps.gl_daily_rates gdr
                                             WHERE     1 = 1
                                                   AND gdr.from_currency =
                                                       currency_type
                                                   AND conversion_type =
                                                       P_PERIOD_RATE_TYPE
                                                   AND conversion_date =
                                                       TO_DATE (period_date,
                                                                'DD-MON-YY')
                                                   AND gdr.from_currency <>
                                                       'USD'
                                                   AND gdr.to_currency =
                                                       'USD'),
                                           1),
                                   USD_MONTH_END_BALANCE_RATE   =
                                       NVL (
                                           (SELECT conversion_rate
                                              FROM apps.gl_daily_rates gdr
                                             WHERE     1 = 1
                                                   AND gdr.from_currency =
                                                       currency_type
                                                   AND conversion_type =
                                                       P_BALLANCE_RATE_TYPE
                                                   AND conversion_date =
                                                       TO_DATE (
                                                           P_OB_SPOT_RATE_DATE,
                                                           'DD-MON-YY')
                                                   AND gdr.from_currency <>
                                                       'USD'
                                                   AND gdr.to_currency =
                                                       'USD'),
                                           1),
                                   FUNCTIONAL_CURRENCY_CLOSING_BALANCE   =
                                       ROUND (
                                             FUNCTIONAL_CURRENCY_BALANCE_RATE
                                           * NVL (CLOSING_BALANCE, 0),
                                           precision),
                                   FUNCTIONAL_CURRENCY_SHORT_TERM   =
                                       ROUND (
                                             FUNCTIONAL_CURRENCY_BALANCE_RATE
                                           * NVL (SHORT_TERM, 0),
                                           precision),
                                   FUNCTIONAL_CURRENCY_LONG_TERM   =
                                       ROUND (
                                             FUNCTIONAL_CURRENCY_BALANCE_RATE
                                           * NVL (LONG_TERM, 0),
                                           precision),
                                   FUNCTIONAL_CURRENCY_PREPAID_AMOUNT   =
                                       ROUND (
                                             FUNCTIONAL_CURRENCY_BALANCE_RATE
                                           * NVL (PREPAID_AMOUNT, 0),
                                           precision),
                                   FUNCTIONAL_CURRENCY_CLOSING_BALANCE_LESS_PREPAID   =
                                       ROUND (
                                             FUNCTIONAL_CURRENCY_BALANCE_RATE
                                           * NVL (
                                                 CLOSING_BALANCE_LESS_PREPAID,
                                                 0),
                                           precision),
                                   FUNCTIONAL_CURRENCY_BEGINNING_BALANCE   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_BALLANCE_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         P_OB_SPOT_RATE_DATE,
                                                                         'DD-MON-YY')
                                                                 AND gdr.to_currency =
                                                                     functional_to_currency),
                                                         1)
                                                   * NVL (BEGINNING_BALANCE,
                                                          0)
                                              FROM DUAL),
                                           precision),
                                   FUNCTIONAL_CURRENCY_ADDITION   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_PERIOD_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         period_date,
                                                                         'DD-MON-YY')
                                                                 AND gdr.to_currency =
                                                                     functional_to_currency),
                                                         1)
                                                   * NVL (addition, 0)
                                              FROM DUAL),
                                           precision),
                                   FUNCTIONAL_CURRENCY_REDUCTION   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_PERIOD_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         period_date,
                                                                         'DD-MON-YY')
                                                                 AND gdr.to_currency =
                                                                     functional_to_currency),
                                                         1)
                                                   * NVL (reduction, 0)
                                              FROM DUAL),
                                           precision),
                                   FUNCTIONAL_PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC   =
                                       ROUND (
                                           (SELECT   NVL (
                                                         (SELECT conversion_rate
                                                            FROM apps.gl_daily_rates gdr
                                                           WHERE     1 = 1
                                                                 AND gdr.from_currency =
                                                                     currency_type
                                                                 AND conversion_type =
                                                                     P_PERIOD_RATE_TYPE
                                                                 AND conversion_date =
                                                                     TO_DATE (
                                                                         period_date,
                                                                         'DD-MON-YY')
                                                                 AND gdr.to_currency =
                                                                     functional_to_currency),
                                                         1)
                                                   * NVL (
                                                         period_liability_amortization_expense_calc,
                                                         0)
                                              FROM DUAL),
                                           precision),
                                   FUNCTIONAL_CURRENCY_PERIOD_RATE   =
                                       NVL (
                                           (SELECT conversion_rate
                                              FROM apps.gl_daily_rates gdr
                                             WHERE     1 = 1
                                                   AND gdr.from_currency =
                                                       currency_type
                                                   AND conversion_type =
                                                       P_PERIOD_RATE_TYPE
                                                   AND conversion_date =
                                                       TO_DATE (period_date,
                                                                'DD-MON-YY')
                                                   AND gdr.to_currency =
                                                       functional_to_currency),
                                           1),
                                   FUNCTIONAL_CURRENCY_MONTH_END_BALANCE_RATE   =
                                       NVL (
                                           (SELECT conversion_rate
                                              FROM apps.gl_daily_rates gdr
                                             WHERE     1 = 1
                                                   AND gdr.from_currency =
                                                       currency_type
                                                   AND conversion_type =
                                                       P_BALLANCE_RATE_TYPE
                                                   AND conversion_date =
                                                       TO_DATE (
                                                           P_OB_SPOT_RATE_DATE,
                                                           'DD-MON-YY')
                                                   AND gdr.to_currency =
                                                       functional_to_currency),
                                           1)
                             WHERE 1 = 1 AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the calculation staging table is failed:'
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t curt1
                               SET (USD_prev_ppd_AMOUNT, LOCAL_PREv_ppd_AMOUNT, prev_ppd_rate_amount
                                    , currt_ppd_rate_amount)   =
                                       (SELECT USD_prev_ppd_AMOUNT, LOCAL_PREv_ppd_AMOUNT, prev_ppd_rate_amount,
                                               currt_ppd_rate_amount
                                          FROM (  SELECT XXD_GL_LX_LIABILITY_RF_PKG.get_sum_usd_previous_month_prepaid_amount (
                                                             curt.date_parameter,
                                                             curt.ob_date,
                                                             curt.portfolio,
                                                             curt.contract_name,
                                                             'USD')
                                                             USD_prev_ppd_AMOUNT,
                                                         XXD_GL_LX_LIABILITY_RF_PKG.get_sum_usd_previous_month_prepaid_amount (
                                                             curt.date_parameter,
                                                             curt.ob_date,
                                                             curt.portfolio,
                                                             curt.contract_name,
                                                             'LOCAL')
                                                             LOCAL_PREv_ppd_AMOUNT,
                                                         XXD_GL_LX_LIABILITY_RF_PKG.get_sum_usd_previous_month_prepaid_amount (
                                                             curt.date_parameter,
                                                             curt.ob_date,
                                                             curt.portfolio,
                                                             curt.contract_name,
                                                             'PREPAID_PERIOD_RATE_AMOUNT')
                                                             prev_ppd_rate_amount,
                                                         ROUND (
                                                             SUM (
                                                                   curt.prepaid_amount
                                                                 * curt.USD_PERIOD_RATE),
                                                             2)
                                                             currt_ppd_rate_amount,
                                                         MIN (
                                                             TO_NUMBER (
                                                                 curt.fiscal_period))
                                                             min_fiscal_period,
                                                         date_parameter,
                                                         reprocess_flag,
                                                         portfolio,
                                                         contract_name
                                                    FROM xxdo.xxd_gl_lx_liability_rf_t CURT
                                                   WHERE     1 = 1
                                                         AND curt1.date_parameter =
                                                             curt.date_parameter
                                                         AND curt1.reprocess_flag =
                                                             curt.reprocess_flag
                                                         AND curt1.portfolio =
                                                             curt.portfolio
                                                         AND curt1.contract_name =
                                                             curt.contract_name
                                                         AND CURT.request_id =
                                                             gn_request_id
                                                GROUP BY curt.date_parameter, curt.portfolio, curt.contract_name,
                                                         CURT.reprocess_flag, curt.ob_date)
                                               a
                                         WHERE     1 = 1
                                               AND curt1.fiscal_period =
                                                   a.min_fiscal_period)
                             WHERE     1 = 1
                                   AND reprocess_flag = 'N'
                                   AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the calculation prepaid_amount staging table is failed:'
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t curt1
                               SET (FUNC_CUR_PREV_PPD_AMOUNT,
                                    FUNC_CUR_PREV_PPD_RATE_AMOUNT,
                                    FUNC_CUR_CURRT_PPD_RATE_AMOUNT)   =
                                       (SELECT FUNC_CUR_PREV_PPD_AMOUNT, FUNC_CUR_PREV_PPD_RATE_AMOUNT, FUNC_CUR_CURRT_PPD_RATE_AMOUNT
                                          FROM (  SELECT XXD_GL_LX_LIABILITY_RF_PKG.get_sum_functional_previous_month_prepaid_amount (
                                                             curt.date_parameter,
                                                             curt.ob_date,
                                                             curt.portfolio,
                                                             curt.contract_name,
                                                             'USD')
                                                             FUNC_CUR_PREV_PPD_AMOUNT,
                                                         XXD_GL_LX_LIABILITY_RF_PKG.get_sum_functional_previous_month_prepaid_amount (
                                                             curt.date_parameter,
                                                             curt.ob_date,
                                                             curt.portfolio,
                                                             curt.contract_name,
                                                             'PREPAID_PERIOD_RATE_AMOUNT')
                                                             FUNC_CUR_PREV_PPD_RATE_AMOUNT,
                                                         ROUND (
                                                             SUM (
                                                                   curt.prepaid_amount
                                                                 * curt.USD_PERIOD_RATE),
                                                             2)
                                                             FUNC_CUR_CURRT_PPD_RATE_AMOUNT,
                                                         MIN (
                                                             TO_NUMBER (
                                                                 curt.fiscal_period))
                                                             min_fiscal_period,
                                                         date_parameter,
                                                         reprocess_flag,
                                                         portfolio,
                                                         contract_name
                                                    FROM xxdo.xxd_gl_lx_liability_rf_t CURT
                                                   WHERE     1 = 1
                                                         AND curt1.date_parameter =
                                                             curt.date_parameter
                                                         AND curt1.reprocess_flag =
                                                             curt.reprocess_flag
                                                         AND curt1.portfolio =
                                                             curt.portfolio
                                                         AND curt1.contract_name =
                                                             curt.contract_name
                                                         AND CURT.request_id =
                                                             gn_request_id
                                                GROUP BY curt.date_parameter, curt.portfolio, curt.contract_name,
                                                         CURT.reprocess_flag, curt.ob_date)
                                               a
                                         WHERE     1 = 1
                                               AND curt1.fiscal_period =
                                                   a.min_fiscal_period)
                             WHERE     1 = 1
                                   AND reprocess_flag = 'N'
                                   AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the functional currncy calculation prepaid_amount staging table is failed:'
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t curt1
                               SET (currt_ppd_rate_amount)   =
                                       (SELECT currt_ppd_rate_amount
                                          FROM (  SELECT ROUND (SUM (curt.prepaid_amount * curt.USD_PERIOD_RATE), 2) currt_ppd_rate_amount, MAX (TO_NUMBER (curt.fiscal_period)) max_fiscal_period, date_parameter,
                                                         reprocess_flag, portfolio, contract_name
                                                    FROM xxdo.xxd_gl_lx_liability_rf_t CURT
                                                   WHERE     1 = 1
                                                         AND curt1.date_parameter =
                                                             curt.date_parameter
                                                         AND curt1.reprocess_flag =
                                                             curt.reprocess_flag
                                                         AND curt1.portfolio =
                                                             curt.portfolio
                                                         AND curt1.contract_name =
                                                             curt.contract_name
                                                         AND CURT.request_id =
                                                             gn_request_id
                                                GROUP BY curt.date_parameter, curt.portfolio, curt.contract_name,
                                                         CURT.reprocess_flag, curt.ob_date)
                                               a
                                         WHERE     1 = 1
                                               AND curt1.fiscal_period =
                                                   a.max_fiscal_period)
                             WHERE     1 = 1
                                   AND reprocess_flag = 'N'
                                   AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the calculation max prepaid_amount staging table is failed:'
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t curt1
                               SET (FUNC_CUR_CURRT_PPD_RATE_AMOUNT)   =
                                       (SELECT FUNC_CUR_CURRT_PPD_RATE_AMOUNT
                                          FROM (  SELECT ROUND (SUM (curt.prepaid_amount * curt.functional_currency_PERIOD_RATE), 2) FUNC_CUR_CURRT_PPD_RATE_AMOUNT, MAX (TO_NUMBER (curt.fiscal_period)) max_fiscal_period, date_parameter,
                                                         reprocess_flag, portfolio, contract_name
                                                    FROM xxdo.xxd_gl_lx_liability_rf_t CURT
                                                   WHERE     1 = 1
                                                         AND curt1.date_parameter =
                                                             curt.date_parameter
                                                         AND curt1.reprocess_flag =
                                                             curt.reprocess_flag
                                                         AND curt1.portfolio =
                                                             curt.portfolio
                                                         AND curt1.contract_name =
                                                             curt.contract_name
                                                         AND CURT.request_id =
                                                             gn_request_id
                                                GROUP BY curt.date_parameter, curt.portfolio, curt.contract_name,
                                                         CURT.reprocess_flag, curt.ob_date)
                                               a
                                         WHERE     1 = 1
                                               AND curt1.fiscal_period =
                                                   a.max_fiscal_period)
                             WHERE     1 = 1
                                   AND reprocess_flag = 'N'
                                   AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the functional currncy calculation max prepaid_amount staging table is failed:'
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t
                               SET FX_USD = (NVL (USD_CLOSING_BALANCE_LESS_PREPAID, 0) - (NVL (USD_BEGINNING_BALANCE, 0) + NVL (USD_ADDITION, 0) + NVL (USD_REDUCTION, 0) + NVL (USD_PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC, 0) + NVL (PREV_PPD_RATE_AMOUNT, 0) - NVL (USD_PREV_PPD_AMOUNT, 0) - NVL (CURRT_PPD_RATE_AMOUNT, 0)))
                             WHERE 1 = 1 AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the calculation FX_USD staging table is failed:'
                                    || SQLERRM);
                        END;

                        BEGIN
                            UPDATE xxdo.xxd_gl_lx_liability_rf_t
                               SET FUNCTIONAL_FX = (NVL (FUNCTIONAL_CURRENCY_CLOSING_BALANCE_LESS_PREPAID, 0) - (NVL (FUNCTIONAL_CURRENCY_BEGINNING_BALANCE, 0) + NVL (FUNCTIONAL_CURRENCY_ADDITION, 0) + NVL (FUNCTIONAL_CURRENCY_REDUCTION, 0) + NVL (FUNCTIONAL_PERIOD_LIABILITY_AMORTIZATION_EXPENSE_CALC, 0) + (NVL (FUNC_CUR_PREV_PPD_RATE_AMOUNT, 0) - NVL (FUNC_CUR_PREV_PPD_AMOUNT, 0)) - NVL (FUNC_CUR_CURRT_PPD_RATE_AMOUNT, 0)))
                             WHERE 1 = 1 AND request_id = gn_request_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Updating the calculation FUNCTIONAL_FX staging table is failed:'
                                    || SQLERRM);
                        END;

                        DELETE FROM
                            xxdo.xxd_gl_lx_liability_rf_t
                              WHERE     (PORTFOLIO LIKE '%Contract Total%' OR CONTRACT_NAME LIKE '%Grand Total%')
                                    AND request_id = gn_request_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Updating USD coulmn values failed'
                                || SQLERRM);
                            fnd_file.put_line (fnd_file.LOG,
                                               'SQLERRM	 ' || SQLERRM);
                            RETURN FALSE;
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
                                argument1     => 'REMOVE',
                                argument2     => 2,
                                argument3     =>
                                    lv_directory_path || '/' || data.filename,
                                argument4     => NULL,
                                start_time    => SYSDATE,
                                sub_request   => FALSE);
                        COMMIT;

                        IF ln_req_id = 0
                        THEN
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

    FUNCTION get_balance_rate_value
        RETURN VARCHAR2
    AS
        lv_balance_rate_value   VARCHAR2 (100);
    BEGIN
        SELECT balance_rate
          INTO lv_balance_rate_value
          FROM (  SELECT balance_rate, request_id
                    FROM xxdo.xxd_gl_lx_liability_rf_t
                   WHERE     reprocess_flag = 'N'
                         AND date_parameter = TO_DATE (p_date, 'DD-MON-YY')
                         AND request_id =
                             DECODE (p_report_process,
                                     'Report', request_id,
                                     fnd_global.conc_request_id)
                GROUP BY balance_rate, request_id
                ORDER BY request_id DESC)
         WHERE ROWNUM = 1;

        RETURN lv_balance_rate_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION get_period_rate_value
        RETURN VARCHAR2
    AS
        lv_period_rate_value   VARCHAR2 (100);
    BEGIN
        SELECT period_rate
          INTO lv_period_rate_value
          FROM (  SELECT period_rate, request_id
                    FROM xxdo.xxd_gl_lx_liability_rf_t
                   WHERE     reprocess_flag = 'N'
                         AND date_parameter = TO_DATE (p_date, 'DD-MON-YY')
                         AND request_id =
                             DECODE (p_report_process,
                                     'Report', request_id,
                                     fnd_global.conc_request_id)
                GROUP BY period_rate, request_id
                ORDER BY request_id DESC)
         WHERE ROWNUM = 1;

        RETURN lv_period_rate_value;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;


    FUNCTION get_usd_previous_month_prepaid_amount (p_current_ob_date DATE, p_current_portfolio VARCHAR2, current_contract_name VARCHAR2)
        RETURN NUMBER
    AS
        ln_previous_month_prepaid_amount   NUMBER;
    BEGIN
          SELECT SUM (prev.usd_prepaid_amount)
            INTO ln_previous_month_prepaid_amount
            FROM xxdo.xxd_gl_lx_liability_rf_t prev
           WHERE     1 = 1
                 AND prev.date_parameter = p_current_ob_date
                 AND prev.reprocess_flag = 'N'
                 AND prev.portfolio = p_current_portfolio
                 AND prev.contract_name = current_contract_name
        GROUP BY prev.portfolio, prev.contract_name;

        RETURN ln_previous_month_prepaid_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;


    FUNCTION get_sum_usd_previous_month_prepaid_amount (p_parameter_date DATE, p_ob_date DATE, p_current_portfolio VARCHAR2
                                                        , current_contract_name VARCHAR2, P_amount_type VARCHAR2)
        RETURN VARCHAR2                                               --NUMBER
    AS
        ln_sum_previous_month_prepaid_amount   NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF (P_amount_type = 'USD')
        THEN
            SELECT sum_previous_prepaid_amount
              INTO ln_sum_previous_month_prepaid_amount
              FROM (  SELECT portfolio, contract_name, curt.date_parameter,
                             SUM (curt.usd_prepaid_amount) sum_previous_prepaid_amount, curt.OB_DATE
                        FROM xxdo.xxd_gl_lx_liability_rf_t curt
                       WHERE     1 = 1
                             AND date_parameter = p_ob_date
                             AND reprocess_flag = 'N'
                             AND portfolio = p_current_portfolio
                             AND contract_name = current_contract_name
                    GROUP BY portfolio, contract_name, curt.date_parameter,
                             curt.OB_DATE)
             WHERE 1 = 1;
        ELSIF (P_amount_type = 'LOCAL')
        THEN
            SELECT sum_previous_prepaid_amount
              INTO ln_sum_previous_month_prepaid_amount
              FROM (  SELECT portfolio, contract_name, curt.date_parameter,
                             SUM (curt.prepaid_amount) sum_previous_prepaid_amount, curt.OB_DATE
                        FROM xxdo.xxd_gl_lx_liability_rf_t curt
                       WHERE     1 = 1
                             AND date_parameter = p_ob_date
                             AND reprocess_flag = 'N'
                             AND portfolio = p_current_portfolio
                             AND contract_name = current_contract_name
                    GROUP BY portfolio, contract_name, curt.date_parameter,
                             curt.OB_DATE)
             WHERE 1 = 1;
        ELSIF (P_amount_type = 'PREPAID_PERIOD_RATE_AMOUNT')
        THEN
            SELECT sum_previous_prepaid_amount
              INTO ln_sum_previous_month_prepaid_amount
              FROM (  SELECT portfolio, contract_name, curt.date_parameter,
                             ROUND (SUM (PREPAID_AMOUNT * USD_PERIOD_RATE), 2) sum_previous_prepaid_amount, curt.OB_DATE
                        FROM xxdo.xxd_gl_lx_liability_rf_t curt
                       WHERE     1 = 1
                             AND date_parameter = p_ob_date
                             AND reprocess_flag = 'N'
                             AND portfolio = p_current_portfolio
                             AND contract_name = current_contract_name
                    GROUP BY portfolio, contract_name, curt.date_parameter,
                             curt.OB_DATE)
             WHERE 1 = 1;
        END IF;

        RETURN ln_sum_previous_month_prepaid_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    FUNCTION get_sum_functional_previous_month_prepaid_amount (p_parameter_date DATE, p_ob_date DATE, p_current_portfolio VARCHAR2
                                                               , current_contract_name VARCHAR2, P_amount_type VARCHAR2)
        RETURN VARCHAR2                                               --NUMBER
    AS
        ln_sum_previous_month_prepaid_amount   NUMBER;
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        IF (P_amount_type = 'FUNCTIONAL')
        THEN
            SELECT sum_previous_prepaid_amount
              INTO ln_sum_previous_month_prepaid_amount
              FROM (  SELECT portfolio, contract_name, curt.date_parameter,
                             SUM (curt.functional_currency_prepaid_amount) sum_previous_prepaid_amount, curt.OB_DATE
                        FROM xxdo.xxd_gl_lx_liability_rf_t curt
                       WHERE     1 = 1
                             AND date_parameter = p_ob_date
                             AND reprocess_flag = 'N'
                             AND portfolio = p_current_portfolio
                             AND contract_name = current_contract_name
                    GROUP BY portfolio, contract_name, curt.date_parameter,
                             curt.OB_DATE)
             WHERE 1 = 1;
        ELSIF (P_amount_type = 'LOCAL')
        THEN
            SELECT sum_previous_prepaid_amount
              INTO ln_sum_previous_month_prepaid_amount
              FROM (  SELECT portfolio, contract_name, curt.date_parameter,
                             SUM (curt.prepaid_amount) sum_previous_prepaid_amount, curt.OB_DATE
                        FROM xxdo.xxd_gl_lx_liability_rf_t curt
                       WHERE     1 = 1
                             AND date_parameter = p_ob_date
                             AND reprocess_flag = 'N'
                             AND portfolio = p_current_portfolio
                             AND contract_name = current_contract_name
                    GROUP BY portfolio, contract_name, curt.date_parameter,
                             curt.OB_DATE)
             WHERE 1 = 1;
        ELSIF (P_amount_type = 'PREPAID_PERIOD_RATE_AMOUNT')
        THEN
            SELECT sum_previous_prepaid_amount
              INTO ln_sum_previous_month_prepaid_amount
              FROM (  SELECT portfolio, contract_name, curt.date_parameter,
                             ROUND (SUM (prepaid_amount * functional_currency_balance_rate), 2) sum_previous_prepaid_amount, curt.OB_DATE
                        FROM xxdo.xxd_gl_lx_liability_rf_t curt
                       WHERE     1 = 1
                             AND date_parameter = p_ob_date
                             AND reprocess_flag = 'N'
                             AND portfolio = p_current_portfolio
                             AND contract_name = current_contract_name
                    GROUP BY portfolio, contract_name, curt.date_parameter,
                             curt.OB_DATE)
             WHERE 1 = 1;
        END IF;

        RETURN ln_sum_previous_month_prepaid_amount;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
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
               AND ffv.flex_value = 'Deckers LX Liability RF Program';

        RETURN ln_days_count;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;
END XXD_GL_LX_LIABILITY_RF_PKG;
/
