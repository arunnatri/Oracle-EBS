--
-- XXD_GL_ACCT_BALANCE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_ACCT_BALANCE_PKG"
AS
    /**********************************************************************************************
    * Package      : XXD_GL_ACCT_BALANCE_PKG
    * Design       : This package will be used to fetch the balance details and send to blackline
    * Notes        :
    * Modification :
    -- ============================================================================================
    -- Date          Version#    Name                    Comments
    -- ============  =========   ======================  ====================++++==================
    -- 03-Sep-2020   1.0         Srinath Siricilla       Initial Version
    -- 21-DEC-2020   1.1         Satyanarayana Kotha     Modified for CCR0008729
    -- 11-MAR-2021   1.2         Satyanarayana Kotha     Modified for CCR0008729
     ***********************************************************************************************/
    gn_conc_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id           NUMBER := fnd_global.user_id;

    PROCEDURE msg (MESSAGE VARCHAR2, debug_level NUMBER:= 100)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, MESSAGE);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN;
    END msg;

    PROCEDURE main
    IS
        lv_sql_stamtment   LONG;
        lv_msg             VARCHAR2 (2000);
    BEGIN
        lv_sql_stamtment   :=
               'INSERT INTO xxdo.xxd_gl_account_balance_stg (SELECT /*+full(gjl) full(gjh) full(gcc) parallel(6)*/
                  (SELECT name
                     FROM apps.gl_ledgers
                    WHERE ledger_id = gjh.ledger_id)
                     ledger_name,
                  gcc.concatenated_segments account_comb,
                  gcc.segment1 Company,
                  gcc.segment2 Brand,
                  gcc.segment3 Geo,
                  gcc.segment4 channel,
                  gcc.segment5 cost_center,
                  gcc.segment6 Natural_Account,
                  gcc.segment7 Inter_Company,
                  gcc.segment8 Future,
                  (SELECT description
                     FROM apps.fnd_flex_values_vl
                    WHERE     1 = 1
                          AND flex_value_set_id = 1015916
                          AND flex_value = gcc.segment6
                          AND enabled_flag = '
            || ''''
            || 'Y'
            || ''''
            || '
                          AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                          AND NVL (end_date_active,
                                                   SYSDATE + 1))
                     Account_Desc,
                  (SELECT gjs.user_je_source_name
                     FROM apps.gl_je_sources gjs
                    WHERE gjs.je_source_name = gjh.je_source)
                     Journal_Source,
                  (SELECT gjc.user_je_category_name
                     FROM apps.gl_je_categories gjc
                    WHERE 1 = 1 AND gjc.je_category_name = gjh.je_category)
                     Journal_category,
                  gjh.period_name,
                  SUM (NVL (gjl.entered_dr, 0)) entered_dr,
                  SUM (NVL (gjl.entered_cr, 0)) entered_cr,
                  SUM (NVL (gjl.accounted_dr, 0)) Accounted_Dr,
                  SUM (NVL (gjl.accounted_cr, 0)) Accounted_cr,
                  Null
                     Net_Entered,
                  null Net_Accounted,  
                  gjh.currency_code Currency_Code,
                  '
            || ''''
            || SYSDATE
            || ''''
            || '   last_update_date,
                  '
            || gn_user_id
            || ' last_updated_by,
                  '
            || ''''
            || SYSDATE
            || ''''
            || ' creation_date,
                  '
            || gn_user_id
            || ' created_by,
                  '
            || gn_user_id
            || ' last_update_login,
                  '
            || gn_conc_request_id
            || ' request_id
             FROM apps.gl_je_lines gjl,
                  apps.gl_code_combinations_kfv gcc,
                  apps.gl_je_headers gjh,
                  apps.gl_period_statuses gp
            WHERE     1 = 1
                  AND gcc.code_combination_id = gjl.code_combination_id
                  AND gjh.je_header_id = gjl.je_header_id
                  AND gjh.default_effective_date BETWEEN NVL (
                                                            TO_DATE (
                                                               '
            || ''''
            || p_from_date
            || ''''
            || ',
                                                               '
            || ''''
            || 'RRRR/MM/DD HH24:MI:SS'
            || ''''
            || '),
                                                            gjh.default_effective_date)
                                                     AND NVL (
                                                     TO_DATE (
                                                               '
            || ''''
            || p_to_date
            || ''''
            || ',
                                                               '
            || ''''
            || 'RRRR/MM/DD HH24:MI:SS'
            || ''''
            || '),
                                                            gjh.default_effective_date)
                  AND (   gjh.ledger_id ='
            || p_ledger_id
            || '
                       OR gjh.ledger_id IN (SELECT LEDGER_ID
                                              FROM GL_LEDGER_SET_NORM_ASSIGN_V
                                             WHERE ledger_set_id = '
            || p_ledger_id
            || '))
              --    AND gjh.period_name BETWEEN p_period_from AND p_period_to
                  AND gcc.segment1 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,1 ),
                                                           gcc.segment1) AND
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,1 ),
                                                           gcc.segment1)
                  AND gcc.segment2 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,2 ),
                                                           gcc.segment2) AND 
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,2 ),
                                                           gcc.segment2) 
                  AND gcc.segment3 BETWEEN  NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,3 ),
                                                           gcc.segment3) AND 
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,3 ),
                                                           gcc.segment3)
                  AND gcc.segment4 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,4 ),
                                                           gcc.segment4) AND 
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,4 ),
                                                           gcc.segment4)
                  AND gcc.segment5 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,5 ),
                                                           gcc.segment5) AND 
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,5 ),
                                                           gcc.segment5)
                  AND gcc.segment6 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,6 ),
                                                           gcc.segment6) AND  
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,6 ),
                                                           gcc.segment6)
                  AND gcc.segment7 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,7 ),
                                                           gcc.segment7) AND 
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,7 ),
                                                           gcc.segment7)
                  AND gcc.segment8 BETWEEN NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_from
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,8 ),
                                                           gcc.segment8) AND 
                                                   NVL (REGEXP_SUBSTR('
            || ''''
            || p_account_to
            || ''''
            || ','
            || ''''
            || '[^.]+'
            || ''''
            || ',1,8 ),
                                                           gcc.segment8)

                  AND gjh.je_source = NVL ('
            || ''''
            || p_source
            || ''''
            || ', gjh.je_source)
                  AND gjh.je_category = NVL ('
            || ''''
            || p_category
            || ''''
            || ', gjh.je_category)
                  --Added for CCR0008729
                  AND  gp.application_id = 101
                  AND gp.ledger_id=gjh.ledger_id
                        AND gp.effective_period_num BETWEEN (SELECT MIN (
                                                                       effective_period_num)
                                                               FROM apps.gl_period_statuses
                                                              WHERE     period_name =
                                                                          '
            || ''''
            || p_period_from
            || ''''
            || '
                                                                    AND application_id =
                                                                           101
                                                                    AND (   ledger_id =
                                                                              '
            || p_ledger_id
            || '
                                                                         OR gp.ledger_id IN
                                                                               (SELECT ledger_id
                                                                                  FROM GL_LEDGER_SET_NORM_ASSIGN
                                                                                 WHERE ledger_set_id =
                                                                                          '
            || p_ledger_id
            || ')))
                                                        AND (SELECT MAX (
                                                                       effective_period_num)
                                                               FROM apps.gl_period_statuses
                                                              WHERE     period_name =
                                                                          '
            || ''''
            || p_period_to
            || ''''
            || '
                                                                    AND application_id =
                                                                           101
                                                                    AND (   ledger_id =
                                                                              '
            || p_ledger_id
            || '
                                                                         OR gp.ledger_id IN
                                                                               (SELECT ledger_id
                                                                                  FROM GL_LEDGER_SET_NORM_ASSIGN
                                                                                 WHERE ledger_set_id =
                                                                                          '
            || p_ledger_id
            || ')))
                        AND gp.period_name = gjl.period_name
                        ----End for CCR0008729
         GROUP BY gjh.ledger_id,
                  gcc.concatenated_segments,
                  gcc.segment1,
                  gcc.segment2,
                  gcc.segment3,
                  gcc.segment4,
                  gcc.segment5,
                  gcc.segment6,
                  gcc.segment7,
                  gcc.segment8,
                  gjh.period_name,
                  gjh.je_source,
                  gjh.je_category,
                  gjh.currency_code)';
        msg (lv_sql_stamtment);

        EXECUTE IMMEDIATE lv_sql_stamtment;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            msg ('Exception in insert_data: ' || lv_msg);
    END main;

    FUNCTION directory_path                --Added by Madhav D for ENHC0013063
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_send_to_bl IS NOT NULL
        THEN
            IF p_file_path IS NOT NULL
            THEN
                BEGIN
                    SELECT directory_path
                      INTO p_path
                      FROM dba_directories
                     WHERE directory_name = p_file_path;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.Fnd_File.PUT_LINE (
                            apps.Fnd_File.LOG,
                               'Unable to get the file path for directory - '
                            || p_file_path);
                END;
            END IF;
        END IF;

        RETURN p_path;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in directory_path -' || SQLERRM);

            RETURN NULL;                                         --- Added New
    END directory_path;

    FUNCTION file_name
        RETURN VARCHAR2
    IS
    BEGIN
        IF p_path IS NOT NULL
        THEN
            P_FILE_NAME   :=
                   'Deckers_GL_Account_'
                || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        END IF;

        RETURN P_FILE_NAME;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.Fnd_File.PUT_LINE (apps.Fnd_File.LOG,
                                    'Error in file_name -' || SQLERRM);
            RETURN NULL;                                         --- Added New
    END file_name;

    FUNCTION before_report
        RETURN BOOLEAN
    AS
        lv_msg   VARCHAR2 (2000);
    BEGIN
        --delete previous run data
        --DELETE FROM xxdo.xxd_gl_account_balance_stg;
        --COMMIT;

        --calling insert_data to insert eligible records into staging table
        main;

        COMMIT;
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_msg   := SQLERRM;
            RETURN TRUE;
    END before_report;

    FUNCTION after_report
        RETURN BOOLEAN
    IS
        l_req_id               NUMBER;
        ex_no_recips           EXCEPTION;
        ex_no_sender           EXCEPTION;
        ex_no_data_found       EXCEPTION;
        l_start_date           DATE;
        l_end_date             DATE;
        ld_date                DATE;
        lv_file_path           VARCHAR2 (360) := p_file_path;
        lv_output_file         UTL_FILE.file_type;
        lv_outbound_cur_file   VARCHAR2 (360)
            := 'GL_ACCT_DATA_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        lv_ver                 VARCHAR2 (32767) := NULL;
        lv_line                VARCHAR2 (32767) := NULL;
        lv_line1               VARCHAR2 (32767) := NULL;
        lv_output              VARCHAR2 (360);
        lv_output1             VARCHAR2 (360);
        --      lv_delimiter           VARCHAR2 (5) := CHR (9);
        lv_delimiter           VARCHAR2 (5) := '|';
        lv_file_delimiter      VARCHAR2 (1) := '|';
        ln_valid_dir           NUMBER;

        CURSOR C1 IS
            SELECT *
              FROM xxdo.xxd_gl_account_balance_stg
             WHERE    net_entered > 0
                   OR     net_accounted > 0
                      AND request_id = APPS.FND_GLOBAL.CONC_REQUEST_ID;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (fnd_file.LOG,
                           'Send to Black Line: ' || p_send_to_bl);

        fnd_file.put_line (fnd_file.LOG, 'Path: ' || lv_file_path);

        ln_valid_dir   := 0;

        IF NVL (p_send_to_bl, 'N') = 'Y' AND lv_file_path IS NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Directory cannot be NULL for file to be Sent to Blackline: '
                || lv_file_path);
            -- errbuf := 'Directory cannot be NULL for Blackline:';
            -- retcode := 2;
            GOTO end_prog;
        END IF;


        IF lv_file_path IS NOT NULL
        THEN
            SELECT COUNT (1)
              INTO ln_valid_dir
              FROM dba_directories
             WHERE DIRECTORY_NAME = lv_file_path;


            IF ln_valid_dir = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Invalid DBA directory : ' || lv_file_path);
                -- errbuf := 'Invalid DBA directory :';
                --retcode := 2;
                GOTO end_prog;
            END IF;
        END IF;

        IF ln_valid_dir = 1 AND NVL (p_send_to_bl, 'N') <> 'Y'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Please Set the BlackLine as Y for the file to be sent to Directory: '
                || lv_file_path);
            --errbuf := 'Black Should be Yes for file Directory:';
            --retcode := 2;
            GOTO end_prog;
        END IF;



        --lv_delimiter := CHR (9);
        lv_delimiter   := '|';
        lv_ver         :=
               'Ledger Name'
            || lv_delimiter
            || 'Concatenated Segments'
            || lv_delimiter
            || 'Company'
            || lv_delimiter
            || 'Brand'
            || lv_delimiter
            || 'Geo'
            || lv_delimiter
            || 'Channel'
            || lv_delimiter
            || 'Cost Center'
            || lv_delimiter
            || 'Natural Account'
            || lv_delimiter
            || 'Inter Company'
            || lv_delimiter
            || 'Future'
            || lv_delimiter
            || 'Natural Account Description'
            || lv_delimiter
            || 'Journal Source'
            || lv_delimiter
            || 'Journal Category'
            || lv_delimiter
            || 'Period'
            || lv_delimiter
            || 'Entered Dr'
            || lv_delimiter
            || 'Entered Cr'
            || lv_delimiter
            || 'Accounted Dr'
            || lv_delimiter
            || 'Accounted Cr'
            || lv_delimiter
            || 'Entered Currency'
            || lv_delimiter
            || 'Net Entered'
            || lv_delimiter
            || 'Net Accounted';

        --Printing Output

        --      IF ln_valid_dir = 1 AND NVL (p_send_to_bl, 'N') = 'Y'
        --      THEN
        --         lv_output :=
        --            '***GL Account Balance Output file will be sent to BlackLine***';
        --         apps.fnd_file.put_line (apps.fnd_file.output, lv_output);
        --      END IF;

        --        IF lv_file_path IS NULL AND NVL (p_send_to_bl, 'N') = 'N'
        --        THEN
        --            lv_output :=
        --                '***GL Account Balance Output file will be sent to BlackLine***';
        --            apps.fnd_file.put_line (apps.fnd_file.output, lv_output);
        --            apps.fnd_file.put_line (apps.fnd_file.output, lv_ver);
        --        END IF;


        --Writing into a file
        IF NVL (p_send_to_bl, 'N') = 'Y'
        THEN
            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_cur_file || '.tmp', 'W' --opening the file in write mode
                                , 32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                lv_ver   := REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);
                UTL_FILE.put_line (lv_output_file, lv_ver);
            END IF;
        END IF;



        /* LOOP THROUGH GL BALANCES */
        FOR i IN c1
        LOOP
            BEGIN
                --lv_delimiter := '||';
                lv_delimiter   := '|';
                lv_line        :=
                       REPLACE (i.ledger_name, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.concatenated_segments, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.company, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.brand, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.geo, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.channel, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.cost_center, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.natural_account, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.inter_company, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.future, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.natural_account_description, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Journal_Source, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Journal_Category, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.period_name, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.entered_dr, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.entered_cr, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.accounted_dr, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.accounted_cr, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.ENTERED_CURRENCY, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.net_entered, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.net_accounted, CHR (9), ' ');

                IF lv_file_path IS NULL AND NVL (p_send_to_bl, 'N') = 'N'
                THEN
                    apps.fnd_file.put_line (apps.fnd_file.output, lv_line);
                END IF;

                IF NVL (p_send_to_bl, 'N') = 'Y'
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        lv_line   :=
                            REPLACE (lv_line,
                                     lv_delimiter,
                                     lv_file_delimiter);
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Account Number :' || i.concatenated_segments
                                               , l_debug_level => 1);
            END;
        END LOOP;



        IF NVL (p_send_to_bl, 'N') = 'Y'
        THEN
            UTL_FILE.fclose (lv_output_file);
            UTL_FILE.frename (
                src_location    => lv_file_path,
                src_filename    => lv_outbound_cur_file || '.tmp',
                dest_location   => lv_file_path,
                dest_filename   => lv_outbound_cur_file || '.csv',
                overwrite       => TRUE);
        END IF;

       <<end_prog>>
        NULL;
        RETURN TRUE;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_PATH: File location or filename was invalid.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_MODE: The open_mode parameter in FOPEN was invalid.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_FILEHANDLE: The file handle was invalid.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_OPERATION: The file could not be opened or operated on as requested.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'READ_ERROR: An operating system error occurred during the read operation.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'WRITE_ERROR: An operating system error occurred during the write operation.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'INTERNAL_ERROR: An unspecified error in PL/SQL.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'INVALID_FILENAME: The filename parameter is invalid.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN ex_no_data_found
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'There are no international invoices for the specified month.'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN ex_no_recips
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN ex_no_sender
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_ACCT_BALANCE_PKG.MAIN', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);

            RETURN TRUE;                                          -- Added New
    --END;
    /*BEGIN
       --RETURN FALSE;
       apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG,'inside after_report');
       IF p_file_path IS NOT NULL
       THEN
          l_req_id := FND_REQUEST.SUBMIT_REQUEST (application  => 'XDO',
                                                  program      => 'XDOBURSTREP',
                                                  description  => 'Bursting - Placing '||P_FILE_NAME||' under '||P_PATH,
                                                  start_time   => SYSDATE,
                                                  sub_request  => FALSE,
                                                  argument1    => 'Y',
                                                  argument2    => APPS.FND_GLOBAL.CONC_REQUEST_ID ,
                                                  argument3    => 'Y');

       IF NVL(l_req_id,0) = 0
       THEN
          apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG,'Bursting Failed');
       END IF;
       END IF;
       RETURN TRUE;
    EXCEPTION
       WHEN OTHERS THEN
          apps.Fnd_File.PUT_LINE(apps.Fnd_File.LOG, 'Error in after_report -'||SQLERRM);*/
    END after_report;
END;
/
