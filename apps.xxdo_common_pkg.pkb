--
-- XXDO_COMMON_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_COMMON_PKG"
AS
    gv_subprogram_code   VARCHAR2 (2000);
    gv_operation_code    VARCHAR2 (2000);
    gv_operation_key     VARCHAR2 (2000);
    gv_yes               VARCHAR2 (1) := 'Y';
    gd_sysdate           DATE := SYSDATE;
    gn_user_id           NUMBER := fnd_global.user_id;
    gn_login_id          NUMBER := fnd_global.login_id;
    gn_request_id        NUMBER := fnd_global.conc_request_id;
    gn_prog_appl_id      NUMBER := fnd_global.prog_appl_id;
    gn_program_id        NUMBER := fnd_global.conc_program_id;
    gv_resp_name         VARCHAR2 (30) := 'EGO_PIM_DATA_LIBRARIAN';


    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : spool_query                                            --
    -- PARAMETERS  : pv_spoolfile     - Spool File to be created            --
    --               pv_directory     - Directory name to place file        --
    --               pv_header        - Heading for the file                --
    --               pv_spoolquery    - Query to be processed               --
    --               pv_delimiter     - Delimiter to separate the columns   --
    --               pv_quote         - Quote to be used to put data columns--
    --               pxn_record_count - Number of records processed         --
    -- PURPOSE     : This procedure will be used to spool a query and write --
    --               the query data to the specified file.                  --
    --                                                                      --
    --               Procedure validates that File and Query are not null   --
    --               It also confirms that query is a SELECT query. Then    --
    --               query is parsed and executed. For each record retrieved--
    --               the columns of the query are concatenated together     --
    --               and written to the file using UTL_FILE utility.        --
    --                                                             --
    -- Modification History                                          --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE spool_query (pv_spoolfile IN VARCHAR2, pv_directory IN VARCHAR2, pv_header IN VARCHAR2 DEFAULT 'DEFAULT', pv_spoolquery IN VARCHAR2, pv_delimiter IN VARCHAR2 DEFAULT CHR (9), pv_quote IN VARCHAR2 DEFAULT NULL
                           , pxn_record_count OUT NUMBER)
    IS
        -----------------------------
        -- Declare local variables --
        -----------------------------
        cv_blank    CONSTANT VARCHAR2 (1) := ' ';
        cv_none     CONSTANT VARCHAR2 (1) := '';
        lv_string            VARCHAR2 (4000) := NULL;
        lv_heading           VARCHAR2 (4000) := NULL;
        lv_value             VARCHAR2 (4000) := NULL;
        li_max_col           INTEGER := NULL;
        trec_file_type       UTL_FILE.file_type;
        ttab_desc_rec        DBMS_SQL.desc_tab2;
        ln_cnt               NUMBER := 1;
        ln_open_cursor       NUMBER := NULL;
        ln_dir_count         NUMBER := 0;
        lv_operation_code    VARCHAR2 (240);
        lv_directory         VARCHAR2 (2000);
        lv_subprogram_code   VARCHAR2 (2000) := 'xxdo_common_pkg.SPOOL_QUERY';
        le_spool_query_err   EXCEPTION;
        lv_error_message     VARCHAR2 (2000);
    BEGIN
        gv_operation_code   := 'Validating input parameters';
        lv_error_message    := NULL;

        -------------------------
        -- Validate parameters --
        -------------------------
        IF pv_spoolfile IS NULL
        THEN
            lv_error_message   :=
                   lv_error_message
                || 'Parameter PV_SPOOLFILE must be specified.';
            RAISE le_spool_query_err;
        END IF;

        IF TRIM (pv_spoolquery) IS NULL
        THEN
            lv_error_message   :=
                   lv_error_message
                || 'Parameter PV_SPOOLQUERY must be specified.';
            RAISE le_spool_query_err;
        END IF;

        IF UPPER (TRIM (pv_spoolquery)) NOT LIKE 'SELECT%'
        THEN
            lv_error_message   :=
                lv_error_message || 'Query must be a SELECT query.';
            RAISE le_spool_query_err;
        END IF;

        gv_operation_code   :=
            'Validating input directory - ' || pv_directory;

        SELECT COUNT (1)
          INTO ln_dir_count
          FROM all_directories
         WHERE directory_name = pv_directory;

        IF ln_dir_count < 1
        THEN
            BEGIN
                SELECT ad.directory_name
                  INTO lv_directory
                  FROM all_directories ad
                 WHERE ad.directory_path = pv_directory AND ROWNUM = 1;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || 'Directory-'
                        || pv_directory
                        || ' does not exist.';
                    RAISE le_spool_query_err;
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || ' Exception while '
                        || gv_operation_code
                        || ' SQL Code - '
                        || SQLCODE
                        || ' SQL Error - '
                        || SQLERRM;
                    RAISE le_spool_query_err;
            END;
        END IF;

        -------------------------------------
        -- Open data file and parse cursor --
        -------------------------------------
        gv_operation_code   := 'Opening the file using UTL_FILE.fopen';
        trec_file_type      :=
            UTL_FILE.fopen (pv_directory, pv_spoolfile, 'w',
                            32760);
        gv_operation_code   := 'Call to DBMS_SQL.open_cursor';
        ln_open_cursor      := DBMS_SQL.open_cursor;
        gv_operation_code   := 'Call to DBMS_SQL.parse';
        DBMS_SQL.parse (ln_open_cursor, pv_spoolquery, DBMS_SQL.native);
        ----------------------------------------
        -- Define columns and resolve heading --
        ----------------------------------------
        gv_operation_code   := 'Call to DBMS_SQL.describe_columns2';
        DBMS_SQL.describe_columns2 (ln_open_cursor,
                                    li_max_col,
                                    ttab_desc_rec);
        gv_operation_code   := 'Define columns and resolve heading';

        FOR ln_cnt IN 1 .. li_max_col
        LOOP
            lv_heading          :=
                   lv_heading
                || pv_quote
                || ttab_desc_rec (ln_cnt).col_name
                || pv_quote
                || pv_delimiter;
            gv_operation_code   := 'Call to DBMS_SQL.define_column_char';
            DBMS_SQL.define_column_char (ln_open_cursor,
                                         ln_cnt,
                                         TO_CHAR (ln_cnt),
                                         ttab_desc_rec (ln_cnt).col_max_len);
        END LOOP;

        -------------------------------
        -- Resolve and write heading --
        -------------------------------
        -------------------------------------------------------
        -- The test condition for pv_header as NULL is added --
        -- to suppress the headings in the output file       --
        -------------------------------------------------------
        gv_operation_code   := 'writing heading';

        IF pv_header = 'DEFAULT'
        THEN
            UTL_FILE.put_line (trec_file_type, lv_heading);
        ELSIF pv_header IS NOT NULL
        THEN
            IF UPPER (pv_header) = 'NULL'
            THEN
                UTL_FILE.put_line (trec_file_type, cv_blank);
            ELSE
                UTL_FILE.put_line (trec_file_type,
                                   pv_header || CHR (13) || CHR (10));
            END IF;
        END IF;

        -------------------------------------------
        -- Process cursor and write data records --
        -------------------------------------------
        ----------------------------------------------------------
        -- The test condition for pv_delimiter as NULL is added --
        -- to suppress the delimiter in the output file         --
        ----------------------------------------------------------
        gv_operation_code   := 'Call DBMS_SQL.EXECUTE';

        ln_cnt              := DBMS_SQL.execute (ln_open_cursor);
        pxn_record_count    := 0;

        IF UPPER (pv_delimiter) = 'NULL'
        THEN
            WHILE DBMS_SQL.fetch_rows (ln_open_cursor) > 0
            LOOP
                lv_string          := NULL;

                FOR ln_cnt IN 1 .. li_max_col
                LOOP
                    DBMS_SQL.column_value_char (ln_open_cursor,
                                                ln_cnt,
                                                lv_value);
                    lv_string   :=
                           lv_string
                        || pv_quote
                        || RTRIM (lv_value)
                        || pv_quote
                        || cv_none;
                END LOOP;

                UTL_FILE.put_line (trec_file_type, lv_string);
                pxn_record_count   := pxn_record_count + 1;
            END LOOP;
        ELSE
            WHILE DBMS_SQL.fetch_rows (ln_open_cursor) > 0
            LOOP
                lv_string          := NULL;

                FOR ln_cnt IN 1 .. li_max_col
                LOOP
                    DBMS_SQL.column_value_char (ln_open_cursor,
                                                ln_cnt,
                                                lv_value);
                    lv_string   :=
                           lv_string
                        || pv_quote
                        || RTRIM (lv_value)
                        || pv_quote
                        || pv_delimiter;
                END LOOP;

                UTL_FILE.put_line (trec_file_type, lv_string);
                pxn_record_count   := pxn_record_count + 1;
            END LOOP;
        END IF;

        --------------------------------
        -- Close cursor and data file --
        --------------------------------
        gv_operation_code   := 'Call DBMS_SQL.CLOSE_CURSOR';
        DBMS_SQL.close_cursor (ln_open_cursor);
        UTL_FILE.fclose (trec_file_type);
    EXCEPTION
        WHEN le_spool_query_err
        THEN
            ------------------------------
            -- Close any open data file --
            ------------------------------
            IF UTL_FILE.is_open (trec_file_type)
            THEN
                UTL_FILE.fclose (trec_file_type);
            END IF;

            -----------------------
            -- Close open cursor --
            -----------------------
            IF DBMS_SQL.is_open (ln_open_cursor)
            THEN
                DBMS_SQL.close_cursor (ln_open_cursor);
            END IF;

            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_SPOOL_QUERY_ERR',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => gv_operation_key,
                pv_token_name1       => 'ERROR',
                pv_token_value1      => lv_error_message);
            raise_application_error (
                -20026,
                'SPOOL_QUERY: Received error ' || lv_error_message);
        WHEN OTHERS
        THEN
            ------------------------------
            -- Close any open data file --
            ------------------------------
            IF UTL_FILE.is_open (trec_file_type)
            THEN
                UTL_FILE.fclose (trec_file_type);
            END IF;

            -----------------------
            -- Close open cursor --
            -----------------------
            IF DBMS_SQL.is_open (ln_open_cursor)
            THEN
                DBMS_SQL.close_cursor (ln_open_cursor);
            END IF;

            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_ORA_EXCEPTION',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => gv_operation_key,
                pv_token_name1       => 'SQLCODE',
                pv_token_value1      => SQLCODE,
                pv_token_name2       => 'SQLERRM',
                pv_token_value2      =>
                    'SPOOL_QUERY: Received error ' || SQLERRM);
            raise_application_error (
                -20026,
                'SPOOL_QUERY: Received error ' || SQLCODE || ' ' || SQLERRM);
    END spool_query;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : send_email                                             --
    -- PARAMETERS  : pv_sender        - Sender of the email                 --
    --                      If no  value is given, sender will  --
    --                          be fetched from XXCMN_SENDER_ADDR   --
    --                      profile option                      --
    --               pv_recipient     - Recipient of the email. Multiple    --
    --                                  addresses should be comma separated --
    --               pv_ccrecipient   - CC Recipient of the email. Multiple --
    --                                  addresses should be comma separated --
    --               pv_subject       - Subject of the email                --
    --               pv_body          - Body of the email                   --
    --               pv_attachments   - Attachments in the email. Multiple  --
    --                                  attachments should be comma         --
    --                                  separated. Complete unix file path  --
    --                                  name should be provided             --
    --                      e.g. /utl/CSERPD1/tmp/test_file.txt --
    --                      or CSERPD1_DIR/test_file.txt        --
    --           pn_request_id       - Request Id
    -- PURPOSE     : This procedure will be used to send email with         --
    --               attachments                                            --
    --                                                         --
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                   --
    -- ----------   -----------     ------------    --------------------------
    -- 01/08/2013   Infosys      1.0          Initial Version               --
    --------------------------------------------------------------------------
    PROCEDURE send_email (pv_sender        IN VARCHAR2 DEFAULT NULL,
                          pv_recipient     IN VARCHAR2,
                          pv_ccrecipient   IN VARCHAR2 DEFAULT NULL,
                          pv_subject       IN VARCHAR2,
                          pv_body          IN VARCHAR2 DEFAULT NULL,
                          pv_attachments   IN VARCHAR2 DEFAULT NULL,
                          pn_request_id    IN NUMBER DEFAULT NULL,
                          pv_override_fn   IN VARCHAR2 DEFAULT NULL)
    IS
        -----------------------------
        -- Declare local variables --
        -----------------------------
        cv_success   CONSTANT VARCHAR2 (10) := 'SUCCESS';
        lv_sender             VARCHAR2 (100);
        lv_db_name            VARCHAR2 (100);
        lv_subject            VARCHAR2 (240);
        lv_result             VARCHAR2 (240);
        lv_result_msg         VARCHAR2 (2000);
        lv_recipients         VARCHAR2 (4000);
        lv_subprogram_code    VARCHAR2 (2000) := 'xxdo_common_pkg.SEND_EMAIL';
        lv_error_message      VARCHAR2 (2000);
        le_send_email_err     EXCEPTION;
    BEGIN
        gv_operation_code   := 'Validate mandatory input parameters';

        -----------------------------------------
        -- Validate mandatory input parameters --
        ------------------------------------------
        IF pv_recipient IS NULL
        THEN
            lv_error_message   :=
                   lv_error_message
                || 'Parameter PV_RECIPIENT must be specified.';
            RAISE le_send_email_err;
        END IF;

        IF pv_subject IS NULL
        THEN
            lv_error_message   :=
                lv_error_message || 'Parameter PV_SUBJECT must be specified.';
            RAISE le_send_email_err;
        END IF;

        --------------------------------------------------------
        -- Fetch environment name to concatenate with subject --
        --------------------------------------------------------
        gv_operation_code   := 'Fetch the db name';

        BEGIN
            SELECT name INTO lv_db_name FROM v$database;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_db_name   := NULL;
            WHEN OTHERS
            THEN
                lv_db_name   := NULL;
        END;

        gv_operation_code   := 'Derive subject';
        lv_subject          :=
               '('
            || lv_db_name
            || ')'
            || ' '
            || pv_subject
            || ' '
            || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS');
        gv_operation_code   := 'Derive sender info';

        IF pv_sender IS NULL
        THEN
            BEGIN
                SELECT fnd_profile.VALUE ('XXCMN_SENDER_ADDR')
                  INTO lv_sender
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_sender   := NULL;
            END;
        ELSE
            lv_sender   := pv_sender;
        END IF;

        ---------------------------------------
        -- Call send_email to send the email --
        ---------------------------------------
        IF pn_request_id IS NULL
        THEN
            gv_operation_code   := 'Call xxcmn_mail_pkg.send_mail';

            BEGIN
                xxdo_mail_pkg.send_mail (pv_sender         => lv_sender,
                                         pv_recipients     => pv_recipient,
                                         pv_ccrecipients   => pv_ccrecipient,
                                         pv_subject        => lv_subject,
                                         pv_message        => pv_body,
                                         pv_attachments    => pv_attachments,
                                         xv_result         => lv_result,
                                         xv_result_msg     => lv_result_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || ' Exception while '
                        || gv_operation_code
                        || ' SQL Code - '
                        || SQLCODE
                        || ' SQL Error - '
                        || SQLERRM;
                    RAISE le_send_email_err;
            END;
        ELSE
            BEGIN
                gv_operation_code   :=
                    'Call xxdo_mail_pkg.send_mail_after_request';
                xxdo_mail_pkg.send_mail_after_request (
                    pv_sender         => lv_sender,
                    pv_recipients     => pv_recipient,
                    pv_ccrecipients   => pv_ccrecipient,
                    pv_subject        => lv_subject,
                    pv_message        => pv_body,
                    pv_attachments    => pv_attachments,
                    pn_request_id     => pn_request_id,
                    pv_override_fn    => pv_override_fn,
                    xv_result         => lv_result,
                    xv_result_msg     => lv_result_msg);
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_error_message   :=
                           lv_error_message
                        || ' Exception while '
                        || gv_operation_code
                        || ' SQL Code - '
                        || SQLCODE
                        || ' SQL Error - '
                        || SQLERRM;
                    RAISE le_send_email_err;
            END;
        END IF;

        ------------------------------------------
        -- If the return code is zero, it means --
        -- SUCCESS, otherwise raise an error    --
        ------------------------------------------
        IF lv_result <> cv_success
        THEN
            lv_error_message   :=
                   lv_error_message
                || 'SEND_EMAIL received error '
                || lv_result_msg
                || ' from SEND_MAIL procedure';
            RAISE le_send_email_err;
        END IF;
    EXCEPTION
        WHEN le_send_email_err
        THEN
            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_SEND_EMAIL_ERR',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => gv_operation_key,
                pv_token_name1       => 'ERROR',
                pv_token_value1      => lv_error_message);
            raise_application_error (
                -20012,
                   'SEND_EMAIL: Received error in SEND_EMAIL '
                || lv_error_message);
        WHEN OTHERS
        THEN
            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_ORA_EXCEPTION',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => gv_operation_key,
                pv_token_name1       => 'SQLCODE',
                pv_token_value1      => SQLCODE,
                pv_token_name2       => 'SQLERRM',
                pv_token_value2      => SQLERRM);

            raise_application_error (
                -20012,
                   'SEND_EMAIL: Received error in SEND_EMAIL '
                || SQLCODE
                || ' '
                || SQLERRM);
    END send_email;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : notify                                                 --
    -- PARAMETERS  : pv_exception_code - Exception Code                     --
    --           pv_program_code   - Program Code
    -- PURPOSE     : This procedure will be used to send notifications      --
    --                                       --
    -- Modification History                                        --
    --------------------------------------------------------------------------
    -- Date      Developer             Version      Description             --
    -- ----------   -----------       ------------    --------------------------
    -- 01/08/2013   Infosys               1.0          Initial Version         --
    -- 02/25/2013   Pushkal Mishra CG     1.1          Updated the logic for Levels to notify
    --------------------------------------------------------------------------
    PROCEDURE notify (xv_errbuf              OUT VARCHAR2,
                      xn_retcode             OUT NUMBER,
                      pv_exception_code   IN     VARCHAR2 DEFAULT NULL,
                      pv_program_code     IN     VARCHAR2 DEFAULT NULL,
                      pn_application_id   IN     NUMBER DEFAULT NULL)
    AS
        ------------------------------------------------------------------
        -- Cursor to fetch the error records for immediate notification --
        ------------------------------------------------------------------
        CURSOR lcsr_immediate_notifs (lv_exception_code VARCHAR2, lv_program_code VARCHAR2, ln_application_id NUMBER)
        IS
                SELECT exception_code, program_code, application_id,
                       levels_to_notify, levels_notified, notif_flag,
                       request_id, subprogram_code, operation_code,
                       operation_key, error_message
                  FROM xxdo_errors xe
                 WHERE     notif_flag LIKE 'I%'
                       AND xe.exception_code =
                           NVL (lv_exception_code, xe.exception_code)
                       AND xe.program_code =
                           NVL (lv_program_code, xe.program_code)
                       AND xe.application_id =
                           NVL (ln_application_id, xe.application_id)
                       AND status = 'E'
            FOR UPDATE OF notif_flag;

        -----------------------------------------------------------------
        -- Cursor to fetch the notification definitions that are to be --
        -- sent for bulk error records                    --
        -- PM Updated the cursor
        ------------------------------------------------------------------
        CURSOR lcsr_bulk_notifs (lv_exception_code VARCHAR2, lv_program_code VARCHAR2, ln_application_id NUMBER)
        IS
                SELECT xnd.exception_code, xnd.program_code, xnd.application_id,
                       DECODE (xnd.frequency,  'PROGRAM', 0,  'HOURLY', 1 / 24,  '12HOURS', 1 / 2,  'DAILY', 1,  'WEEKLY', 7) frequency, xnd.to_mailing_list, xnd.cc_mailing_list,
                       xnd.subject, xnd.body, xnd.last_notified_dt,
                       "LEVEL"
                  FROM xxdo_notif_defns xnd
                 WHERE     xnd.notif_type LIKE 'B%'
                       AND NVL (xnd.exception_code, 'NULL') =
                           NVL (lv_exception_code,
                                NVL (xnd.exception_code, 'NULL'))
                       AND NVL (xnd.program_code, 'NULL') =
                           NVL (lv_program_code, NVL (xnd.program_code, 'NULL'))
                       AND NVL (xnd.application_id, -1) =
                           NVL (ln_application_id, NVL (xnd.application_id, -1))
              ORDER BY "LEVEL"
            FOR UPDATE OF xnd.last_notified_dt;

        -----------------------------
        -- Variable initialization --
        -----------------------------
        lv_to_mailing_list    VARCHAR2 (2000);
        lv_cc_mailing_list    VARCHAR2 (2000);
        lv_subject            VARCHAR2 (240);
        lv_body               VARCHAR2 (2000);
        ld_last_notified_dt   DATE;
        ln_rec_count          NUMBER;
        lv_dir                VARCHAR2 (4000);
        lv_file               VARCHAR2 (100);
        lv_path               VARCHAR2 (100);
        lv_sender             VARCHAR2 (100);
        lv_query              VARCHAR2 (4000);
        ln_record_count       NUMBER;
        lv_appl_expt_flag     VARCHAR2 (1);
    BEGIN
        xv_errbuf            := NULL;
        xn_retcode           := 0;
        gv_subprogram_code   := 'xxdo_common_pkg.NOTIFY';
        gv_operation_code    := NULL;
        gv_operation_code    := 'Getting the profile value for directory';
        lv_dir               := fnd_profile.VALUE ('XXCMN_TRACE_DIR');

        IF lv_dir IS NULL
        THEN
            raise_application_error (
                -20013,
                'NOTIFY: Directory not found ' || SQLCODE || ' ' || SQLERRM);
        ELSE
            lv_path   := lv_dir;
        END IF;

        gv_operation_code    :=
            'Getting the profile value for sender address';
        lv_sender            := fnd_profile.VALUE ('XXCMN_SENDER_ADDR');

        IF lv_sender IS NULL
        THEN
            raise_application_error (
                -20014,
                   'NOTIFY: Sender Email ID not found '
                || SQLCODE
                || ' '
                || SQLERRM);
        END IF;

        -------------------------------------------------------------------
        -- Fetch the error table records and notify the exception to the --
        -- mailing list for the concurrent program and exception code    --
        -- combinations
        -- PM Updated the process for notification                                               --
        -------------------------------------------------------------------
        FOR lrec_immediate_notifs
            IN lcsr_immediate_notifs (pv_exception_code,
                                      pv_program_code,
                                      pn_application_id)
        LOOP
            gv_operation_code    :=
                'Inside the cursor - lcsr_immediate_notifs';
            lv_to_mailing_list   := NULL;
            lv_cc_mailing_list   := NULL;
            lv_appl_expt_flag    := 'Y';
            gv_operation_code    := 'Setting the query for spool query';
            lv_query             := NULL;
            lv_query             :=
                   'SELECT '
                || ''''
                || lrec_immediate_notifs.request_id
                || ''''
                || ' request_id, '
                || ''''
                || lrec_immediate_notifs.exception_code
                || ''''
                || ' exception_code, '
                || ''''
                || lrec_immediate_notifs.subprogram_code
                || ''''
                || ' subprogram_code, '
                || ''''
                || lrec_immediate_notifs.operation_code
                || ''''
                || ' operation_code, '
                || ''''
                || lrec_immediate_notifs.operation_key
                || ''''
                || ' operation_key, '
                || ''''
                || lrec_immediate_notifs.error_message
                || ''''
                || ' error_message'
                || ' FROM dual';
            lv_file              :=
                   'xxdo_errors-'
                || 'IMMEDIATE_NOTIFS'
                || '-'
                || TO_CHAR (SYSDATE, 'mm-dd-yyyy hh24:mi:ss')
                || '.xls';
            ln_record_count      := 0;
            gv_operation_code    := 'Call spool query';
            spool_query (pv_spoolfile       => lv_file,
                         pv_directory       => lv_path,
                         pv_spoolquery      => lv_query,
                         pv_quote           => '"',
                         pxn_record_count   => ln_record_count);

            BEGIN
                gv_operation_code   :=
                    'Derive the mailing lists for immediate notif type';

                SELECT xnd.to_mailing_list, xnd.cc_mailing_list, xnd.subject,
                       xnd.body, xnd.appl_expt_flag
                  INTO lv_to_mailing_list, lv_cc_mailing_list, lv_subject, lv_body,
                                         lv_appl_expt_flag
                  FROM xxdo_notif_defns xnd
                 WHERE     xnd.exception_code =
                           lrec_immediate_notifs.exception_code
                       AND xnd.program_code =
                           lrec_immediate_notifs.program_code
                       AND xnd.application_id =
                           lrec_immediate_notifs.application_id
                       AND xnd.notif_type = 'I';

                gv_operation_code   :=
                    'Call to Send Email for immediate notif types';
                send_email (pv_sender => lv_sender, pv_recipient => lv_to_mailing_list, pv_ccrecipient => lv_cc_mailing_list, pv_subject => lv_subject, pv_body => lv_body, pv_attachments => lv_path || '/' || lv_file
                            , pn_request_id => NULL);
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    xxdo_error_pkg.log_message (
                        'Immediate Block No data Found',
                        'LOG');
                WHEN OTHERS
                THEN
                    xxdo_error_pkg.log_message (
                        'Immediate Block Others exception ' || SQLERRM,
                        'LOG');
                    RAISE;
            END;

            IF     lv_appl_expt_flag = 'Y'
               AND lrec_immediate_notifs.application_id IS NOT NULL
            THEN
                BEGIN
                    gv_operation_code   :=
                        'Derive mailing list for A+E level immediate notif types';

                    SELECT xnd.to_mailing_list, xnd.cc_mailing_list, xnd.subject,
                           xnd.body, xnd.appl_expt_flag
                      INTO lv_to_mailing_list, lv_cc_mailing_list, lv_subject, lv_body,
                                             lv_appl_expt_flag
                      FROM xxdo_notif_defns xnd
                     WHERE     xnd.exception_code =
                               lrec_immediate_notifs.exception_code
                           AND xnd.program_code IS NULL
                           AND xnd.application_id =
                               lrec_immediate_notifs.application_id
                           AND xnd.notif_type = 'I';

                    gv_operation_code   :=
                        'Call Send Email for A+E level immediate notif types';
                    send_email (pv_sender => lv_sender, pv_recipient => lv_to_mailing_list, pv_ccrecipient => lv_cc_mailing_list, pv_subject => lv_subject, pv_body => lv_body, pv_attachments => lv_path || '/' || lv_file
                                , pn_request_id => NULL);
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        xxdo_error_pkg.log_message (
                            'Immediate Block Application + Exception No data Found',
                            'LOG');
                    WHEN OTHERS
                    THEN
                        xxdo_error_pkg.log_message (
                               'Immediate Block A+E level Others exception '
                            || SQLERRM,
                            'LOG');
                        RAISE;
                END;
            END IF;

            IF lrec_immediate_notifs.notif_flag = 'IB'
            THEN
                gv_operation_code   := 'Update xxdo_errors notif_flag to BI';

                UPDATE xxdo_errors
                   SET notif_flag   = 'BI'
                 /*Updating to BI so that it is not picked for the next run*/
                 WHERE CURRENT OF lcsr_immediate_notifs;
            ELSE
                gv_operation_code   := 'Update xxdo_errors notif_flag to Y';

                UPDATE xxdo_errors
                   SET notif_flag   = 'Y'
                 WHERE CURRENT OF lcsr_immediate_notifs;
            END IF;
        END LOOP;

        -------------------------------------------------------------------
        -- Fetch the error table records and notify the exception to the --
        -- mailing list for the concurrent program and exception code    --
        -- combinations                                                  --
        -------------------------------------------------------------------
        FOR lrec_bulk_notifs
            IN lcsr_bulk_notifs (pv_exception_code,
                                 pv_program_code,
                                 pn_application_id)
        LOOP
            gv_operation_code     := 'Inside the cursor - lcsr_bulk_notifs';
            ---------------------------------------------------------------
            -- To send notifications based on the frequency mentioned in --
            -- notification definition. If notifications are being sent  --
            -- for first time, send the notification.                    --
            ---------------------------------------------------------------
            ld_last_notified_dt   := NULL;

            IF    (SYSDATE - lrec_bulk_notifs.last_notified_dt) >=
                  lrec_bulk_notifs.frequency
               OR (lrec_bulk_notifs.last_notified_dt IS NULL)
            THEN
                gv_operation_code     :=
                    'After checking that the bulk record is eligible for notification';
                ld_last_notified_dt   := SYSDATE;
                ln_rec_count          := 0;
                lv_query              := NULL;
                lv_file               :=
                       'xxdo_errors-'
                    || lrec_bulk_notifs."LEVEL"
                    || '-'
                    || TO_CHAR (SYSDATE, 'mm-dd-yyyy hh24:mi:ss')
                    || '.xls';
                xxdo_error_pkg.log_message ('Bulk file name' || lv_file,
                                            'LOG');
                gv_operation_code     :=
                    'Get the count of error table records';

                SELECT COUNT (1)
                  INTO ln_rec_count
                  FROM xxdo_errors xe
                 WHERE     xe.application_id =
                           NVL (lrec_bulk_notifs.application_id,
                                xe.application_id)
                       AND xe.program_code =
                           NVL (lrec_bulk_notifs.program_code,
                                xe.program_code)
                       AND xe.exception_code =
                           NVL (lrec_bulk_notifs.exception_code,
                                xe.exception_code)
                       AND INSTR (xe.levels_to_notify, lrec_bulk_notifs."LEVEL", 1
                                  , 1) <> 0
                       AND INSTR (NVL (xe.levels_notified, '  '), lrec_bulk_notifs."LEVEL", 1
                                  , 1) = 0
                       AND xe.notif_flag LIKE 'B%';

                xxdo_error_pkg.log_message (
                    'ln_rec_count-->' || ln_rec_count);

                IF ln_rec_count > 0
                THEN
                    gv_operation_code   :=
                        'Design the spool query for bulk type notifs';
                    lv_query   := NULL;
                    lv_query   :=
                           'SELECT request_id, exception_code,  subprogram_code,
                             operation_code, operation_key, error_message
                        FROM xxdo_errors xe
                      WHERE xe.application_id =
                      NVL ('''
                        || lrec_bulk_notifs.application_id
                        || ''', xe.application_id)
                      AND xe.exception_code =
                      NVL ('''
                        || lrec_bulk_notifs.exception_code
                        || ''', xe.exception_code)
                  AND xe.program_code = NVL ('''
                        || lrec_bulk_notifs.program_code
                        || ''', xe.program_code)
                  AND INSTR (xe.levels_to_notify, '
                        || lrec_bulk_notifs."LEVEL"
                        || ', 1, 1) <> 0
                  AND INSTR (NVL (xe.levels_notified, ''DUMMY''),'
                        || lrec_bulk_notifs."LEVEL"
                        || ', 1, 1) = 0
                  AND xe.notif_flag LIKE ''B%''';
                    gv_operation_code   :=
                        'Call spool_query for bulk type notifs';
                    spool_query (pv_spoolfile       => lv_file,
                                 pv_directory       => lv_path,
                                 pv_spoolquery      => lv_query,
                                 pv_quote           => '"',
                                 pxn_record_count   => ln_record_count);
                    xxdo_error_pkg.log_message (
                        'Bulk Send mail ' || lv_path || '/' || lv_file,
                        'LOG');
                    gv_operation_code   :=
                        'Call send_email for bulk type notifs';
                    send_email (pv_sender => lv_sender, -- open issues
                                                        pv_recipient => lrec_bulk_notifs.to_mailing_list, pv_ccrecipient => lrec_bulk_notifs.cc_mailing_list, pv_subject => lrec_bulk_notifs.subject, pv_body => lrec_bulk_notifs.body, pv_attachments => lv_path || '/' || lv_file
                                , pn_request_id => NULL);

                    ---
                    -- PM Updating the levels notified flag
                    ---
                    gv_operation_code   :=
                        'Updating levels_notified field in xxdo_errors';

                    UPDATE xxdo_errors xe
                       SET levels_notified = levels_notified || '-' || lrec_bulk_notifs."LEVEL"
                     WHERE     xe.application_id =
                               NVL (lrec_bulk_notifs.application_id,
                                    xe.application_id)
                           AND xe.program_code =
                               NVL (lrec_bulk_notifs.program_code,
                                    xe.program_code)
                           AND xe.exception_code =
                               NVL (lrec_bulk_notifs.exception_code,
                                    xe.exception_code)
                           AND INSTR (xe.levels_to_notify, lrec_bulk_notifs."LEVEL", 1
                                      , 1) <> 0
                           AND INSTR (NVL (xe.levels_notified, '  '), lrec_bulk_notifs."LEVEL", 1
                                      , 1) = 0
                           AND xe.notif_flag LIKE 'B%';
                END IF;

                gv_operation_code     :=
                    'Updating last_notified_dt of xxdo_notif_defns';

                UPDATE xxdo_notif_defns
                   SET last_notified_dt   = ld_last_notified_dt
                 WHERE CURRENT OF lcsr_bulk_notifs;
            END IF;
        END LOOP;

        ---
        --- PM This will update all the records which were notified
        ---
        gv_operation_code    := 'Updating notif_flag of xxdo_errors';

        UPDATE xxdo_errors xe
           SET notif_flag   = 'Y'
         WHERE     NVL (LENGTH (levels_to_notify), 0) =
                   NVL (LENGTH (levels_notified), 0)
               AND levels_to_notify IS NOT NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxdo_error_pkg.set_exception_token (
                pv_exception_code   => 'XXCMN_ORA_EXCEPTION',
                pv_token_name       => 'SQLCODE',
                pv_token_value      => SQLCODE);
            xxdo_error_pkg.set_exception_token (
                pv_exception_code   => 'XXCMN_ORA_EXCEPTION',
                pv_token_name       => 'SQLERRM',
                pv_token_value      =>
                       'Inside When Others Exception for Notify procedure-'
                    || SQLERRM);
            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_ORA_EXCEPTION',
                pv_subprogram_code   => gv_subprogram_code,
                pv_operation_code    => gv_operation_code);
            xv_errbuf    :=
                   'Inside When Others Exception for Notify procedure-'
                || SQLERRM;
            xn_retcode   := 2;
    END notify;

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : get_converted_uom_qty                                  --
    -- PARAMETERS  : pn_item_id  - Inventory Item id                        --
    --     pv_from_uom - From UOM Code                            --
    --     pv_to_uom   - To Primary UOM Code                      --
    --               pn_from_qty - From Quantity                            --
    --     pn_batch_id - Batch id to set operation key            --
    --      pv_item_code - Item name to pass error message         --
    -- PURPOSE     : This function will be used to return quantity in       --
    --               Primary UOM based on the input quantity and UOM        --
    --                   --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date   Developer   Version   Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 01/25/2013   Infosys   1.0    Initial Version         --
    ---------------------------------------------------------------------------
    FUNCTION get_converted_uom_qty (pn_item_id IN NUMBER, pv_from_uom IN VARCHAR2, pv_to_uom IN VARCHAR2
                                    , pn_from_qty IN NUMBER, pn_batch_id IN NUMBER, pv_item_code IN VARCHAR2 DEFAULT NULL)
        RETURN NUMBER
    IS
        lv_subprogram_code     VARCHAR (240) := 'get_primary_uom_qty';
        ln_converted_uom_qty   NUMBER;
        ln_uom_rate            NUMBER;
        lv_operation_key       VARCHAR2 (240);
    BEGIN
        lv_operation_key    := pn_batch_id;
        ------------------------------------
        -- Call API to get UOM Conversion --
        ------------------------------------
        gv_operation_code   :=
            'Call inv_convert.inv_um_convert to get ' || 'UOM conversion';
        ln_uom_rate         :=
            inv_convert.inv_um_convert (pn_item_id, NULL, 1,
                                        pv_from_uom, pv_to_uom, NULL,
                                        NULL);

        -----------------------------------------------
        -- Check if UOM conversion is defined or not --
        -----------------------------------------------
        gv_operation_code   := 'Check if UOM conversion is defined or not';

        IF ln_uom_rate = -99999 OR ln_uom_rate IS NULL
        THEN
            ln_converted_uom_qty   := NULL;

            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXONT_INVALID_UOM_CONV_RATE',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => lv_operation_key,
                pv_log_flag          => gv_yes,
                pv_token_name1       => 'ITEM',
                pv_token_value1      => pv_item_code,
                pv_token_name2       => 'FROM',
                pv_token_value2      => pv_from_uom,
                pv_token_name3       => 'TO',
                pv_token_value3      => pv_to_uom,
                pv_attribute2        => 'Item id - ' || pn_item_id);
        ELSE
            ln_converted_uom_qty   := ln_uom_rate * pn_from_qty;
        END IF;

        RETURN ln_converted_uom_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_ORA_NOTIFICATION',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => lv_operation_key,
                pv_log_flag          => gv_yes,
                pv_token_name1       => 'SQLCODE',
                pv_token_value1      => SQLCODE,
                pv_token_name2       => 'SQLERRM',
                pv_token_value2      => SQLERRM,
                pv_attribute2        => 'Item id - ' || pn_item_id);

            RETURN NULL;
    END get_converted_uom_qty;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : CANCEL_ORDER_LINE                                      --
    -- PARAMETERS  : xn_retcode - Return Code                               --
    --                    0 - Success       --
    --                    1 - Error                                         --
    --               pn_line_id - Line id which is to be cancelled          --
    --               pv_load_nbr - Load Number to set additional attributes --
    --               pn_trip_id - Trip id to set additional attributes      --
    --               pn_delivery_detail_id - Delivery detail id             --
    --               pv_cancel_reason - Reason to cancel the line           --
    --               pn_cancel_qty - Cancelled quantity                     --
    --               pn_ordered_qty - Ordered quantity                      --
    --               pv_event - Event to be performed. It can have 2 values --
    --                          1. LINE                                     --
    --                          2. QTY                                      --
    -- PURPOSE     : This procedure is used to call process order API to    --
    --               cancel order line based on the parameters passed       --
    --            --
    -- Modification History                            --
    --------------------------------------------------------------------------
    -- Date   Developer   Version   Description             --
    -- ----------   -----------     ------------    --------------------------
    -- 05/21/2013   Infosys   1.0    Initial Version         --
    --------------------------------------------------------------------------
    PROCEDURE cancel_order_line (xn_retcode OUT NUMBER, pn_line_id IN NUMBER, pv_load_nbr IN VARCHAR2, pn_trip_id IN NUMBER, pn_delivery_detail_id IN NUMBER, pv_cancel_reason IN VARCHAR2
                                 , pn_cancel_qty IN NUMBER, pn_ordered_qty IN NUMBER, pv_event IN VARCHAR2)
    IS
        -----------------------
        -- Declare variables --
        -----------------------
        lv_subprogram_code        VARCHAR2 (240) := 'CANCEL_ORDER_LINE';
        lv_operation_key          VARCHAR2 (240);
        lv_attribute1             VARCHAR2 (240);
        lv_attribute2             VARCHAR2 (240);
        lv_attribute3             VARCHAR2 (240);
        lv_attribute4             VARCHAR2 (240);
        lv_attribute5             VARCHAR2 (240);
        lv_cancelled              VARCHAR2 (20) := 'CANCELLED';
        ltab_line                 oe_order_pub.line_tbl_type;
        ltab_old_line             oe_order_pub.line_tbl_type;
        ltab_out_line             oe_order_pub.line_tbl_type;
        lrec_header               oe_order_pub.header_rec_type;
        lrec_out_header           oe_order_pub.header_rec_type;
        ltrec_header_val          oe_order_pub.header_val_rec_type;
        ltab_header_adj           oe_order_pub.header_adj_tbl_type;
        ltab_header_adj_val       oe_order_pub.header_adj_val_tbl_type;
        ltab_header_price_att     oe_order_pub.header_price_att_tbl_type;
        ltab_header_adj_att       oe_order_pub.header_adj_att_tbl_type;
        ltab_header_adj_assoc     oe_order_pub.header_adj_assoc_tbl_type;
        ltab_header_scredit       oe_order_pub.header_scredit_tbl_type;
        ltab_header_scredit_val   oe_order_pub.header_scredit_val_tbl_type;
        ltab_header_payment       oe_order_pub.header_payment_tbl_type;
        ltab_header_payment_val   oe_order_pub.header_payment_val_tbl_type;
        ltab_line_val             oe_order_pub.line_val_tbl_type;
        ltab_line_adj             oe_order_pub.line_adj_tbl_type;
        ltab_line_adj_val         oe_order_pub.line_adj_val_tbl_type;
        ltab_line_price_att       oe_order_pub.line_price_att_tbl_type;
        ltab_line_adj_att         oe_order_pub.line_adj_att_tbl_type;
        ltab_line_adj_assoc       oe_order_pub.line_adj_assoc_tbl_type;
        ltab_line_scredit         oe_order_pub.line_scredit_tbl_type;
        ltab_line_scredit_val     oe_order_pub.line_scredit_val_tbl_type;
        ltab_line_payment         oe_order_pub.line_payment_tbl_type;
        ltab_line_payment_val     oe_order_pub.line_payment_val_tbl_type;
        ltab_lot_serial           oe_order_pub.lot_serial_tbl_type;
        ltab_lot_serial_val       oe_order_pub.lot_serial_val_tbl_type;
        ltab_action_request       oe_order_pub.request_tbl_type;
        ltab_out_action_request   oe_order_pub.request_tbl_type;
        lv_return_status          VARCHAR2 (1) := fnd_api.g_ret_sts_success;
        ln_api_version            NUMBER := 1.0;
        ln_index                  NUMBER := 1;
        ln_msg_count              NUMBER := NULL;
        lv_msg_data               VARCHAR2 (4000) := NULL;
        lv_err_msg                VARCHAR2 (4000) := NULL;
        ln_msg_index_out          NUMBER := NULL;
        lt_order_number           oe_order_headers_all.order_number%TYPE;
        lv_line_number            VARCHAR2 (30);
    BEGIN
        --------------------------
        -- Initialize variables --
        --------------------------
        gv_operation_code                             := 'Initialize variables';
        lv_operation_key                              := 'Load Nbr - ' || pv_load_nbr;
        lv_attribute1                                 := 'Load Nbr - ' || pv_load_nbr;
        lv_attribute2                                 := 'Trip id - ' || pn_trip_id;
        lv_attribute3                                 := 'Line id - ' || pn_line_id;
        lv_attribute5                                 :=
            'Delivery detail id - ' || pn_delivery_detail_id;
        lt_order_number                               := NULL;
        lv_line_number                                := NULL;
        xn_retcode                                    := 0;
        lrec_header                                   := oe_order_pub.g_miss_header_rec;
        ltab_line                                     := oe_order_pub.g_miss_line_tbl;
        ltab_out_line                                 := oe_order_pub.g_miss_line_tbl;
        ltab_old_line                                 := oe_order_pub.g_miss_line_tbl;
        fnd_msg_pub.initialize;
        oe_msg_pub.initialize;

        ------------------------
        -- Fetch line details --
        ------------------------
        gv_operation_code                             := 'Fetch line details';

        BEGIN
            SELECT ool.header_id, ool.line_id, ool.line_type_id,
                   ool.line_number, ool.shipment_number, ool.inventory_item_id,
                   ool.order_quantity_uom, ool.ordered_item, ool.ordered_item_id,
                   ool.ship_from_org_id, ool.ship_to_org_id, ool.request_date,
                   ool.schedule_ship_date, ool.item_type_code, ool.line_category_code,
                   ool.open_flag, ool.booked_flag, ool.cancelled_flag,
                   ool.unit_selling_price, ool.unit_list_price, ool.ordered_quantity,
                   ool.org_id, ool.promise_date, ool.pricing_quantity,
                   ool.pricing_quantity_uom, ool.cancelled_quantity, ool.fulfilled_quantity,
                   ool.shipped_quantity, ool.shipping_quantity, ool.shipping_quantity_uom,
                   ool.tax_exempt_flag, ool.tax_code, ool.tax_date,
                   ool.tax_rate, ool.tax_value, ool.invoice_to_org_id,
                   ool.sold_from_org_id, ool.sold_to_org_id, ool.deliver_to_org_id,
                   ool.ship_to_contact_id, ool.deliver_to_contact_id, ool.invoice_to_contact_id,
                   ool.price_list_id, ool.pricing_date, ool.invoice_interface_status_code,
                   ool.shipment_priority_code, ool.shipping_method_code, ool.freight_carrier_code,
                   ool.freight_terms_code, ool.payment_term_id, ool.invoicing_rule_id,
                   ool.accounting_rule_id, ool.source_document_type_id, ool.source_document_id,
                   ool.source_document_line_id, ool.source_document_version_number, ool.order_source_id,
                   ool.orig_sys_document_ref, ool.orig_sys_line_ref, ool.orig_sys_shipment_ref,
                   ool.actual_shipment_date, ool.schedule_arrival_date, ool.schedule_status_code,
                   ool.source_type_code, ool.salesrep_id, ool.arrival_set_id,
                   ool.ship_set_id, ool.item_identifier_type, ool.shipping_interfaced_flag,
                   ool.drop_ship_flag, ool.customer_line_number, ool.customer_shipment_number,
                   ool.customer_payment_term_id, ool.fulfilled_flag, ool.shipping_instructions,
                   ool.packing_instructions, ool.invoiced_quantity, ool.shippable_flag,
                   ool.re_source_flag, ool.flow_status_code, ool.fulfillment_method_code,
                   ool.calculate_price_flag, ool.fulfillment_date, ool.lock_control,
                   ool.subinventory, ool.item_substitution_type_code, ool.unit_cost,
                   ool.item_relationship_type, ool.blanket_number, ool.blanket_line_number,
                   ool.blanket_version_number, ool.earliest_ship_date, ool.transaction_phase_code,
                   ool.actual_fulfillment_date, ool.earliest_acceptable_date, ool.actual_arrival_date,
                   ool.accepted_by, ool.accepted_quantity, ool.accounting_rule_duration,
                   ool.agreement_id, ool.ato_line_id, ool.attribute1,
                   ool.attribute10, ool.attribute11, ool.attribute12,
                   ool.attribute13, ool.attribute14, ool.attribute15,
                   ool.attribute16, ool.attribute17, ool.attribute18,
                   ool.attribute19, ool.attribute2, ool.attribute20,
                   ool.attribute3, ool.attribute4, ool.attribute5,
                   ool.attribute6, ool.attribute7, ool.attribute8,
                   ool.attribute9, ool.authorized_to_ship_flag, ool.auto_selected_quantity,
                   ool.cancelled_quantity2, ool.change_sequence, ool.charge_periodicity_code,
                   ool.commitment_id, ool.component_code, ool.component_number,
                   ool.component_sequence_id, ool.config_header_id, ool.config_rev_nbr,
                   ool.configuration_id, ool.context, ool.contingency_id,
                   ool.credit_invoice_line_id, ool.cust_model_serial_number, ool.cust_po_number,
                   ool.cust_production_seq_num, ool.customer_dock_code, ool.customer_item_net_price,
                   ool.customer_job, ool.customer_production_line, ool.customer_trx_line_id,
                   ool.delivery_lead_time, ool.demand_bucket_type_code, ool.demand_class_code,
                   ool.dep_plan_required_flag, ool.end_customer_id, ool.end_customer_contact_id,
                   ool.end_customer_site_use_id, ool.end_item_unit_number, ool.explosion_date,
                   ool.firm_demand_flag, ool.first_ack_code, ool.first_ack_date,
                   ool.fob_point_code, ool.fulfilled_quantity2, ool.global_attribute1,
                   ool.global_attribute10, ool.global_attribute11, ool.global_attribute12,
                   ool.global_attribute13, ool.global_attribute14, ool.global_attribute15,
                   ool.global_attribute16, ool.global_attribute17, ool.global_attribute18,
                   ool.global_attribute19, ool.global_attribute2, ool.global_attribute20,
                   ool.global_attribute3, ool.global_attribute4, ool.global_attribute5,
                   ool.global_attribute6, ool.global_attribute7, ool.global_attribute8,
                   ool.global_attribute9, ool.global_attribute_category, ool.ib_owner,
                   ool.ib_installed_at_location, ool.ib_current_location, ool.industry_attribute1,
                   ool.industry_attribute10, ool.industry_attribute11, ool.industry_attribute12,
                   ool.industry_attribute13, ool.industry_attribute14, ool.industry_attribute15,
                   ool.industry_attribute16, ool.industry_attribute17, ool.industry_attribute18,
                   ool.industry_attribute19, ool.industry_attribute20, ool.industry_attribute21,
                   ool.industry_attribute22, ool.industry_attribute23, ool.industry_attribute24,
                   ool.industry_attribute25, ool.industry_attribute26, ool.industry_attribute27,
                   ool.industry_attribute28, ool.industry_attribute29, ool.industry_attribute30,
                   ool.industry_attribute2, ool.industry_attribute3, ool.industry_attribute4,
                   ool.industry_attribute5, ool.industry_attribute6, ool.industry_attribute7,
                   ool.industry_attribute8, ool.industry_attribute9, ool.industry_context,
                   ool.intmed_ship_to_org_id, ool.intmed_ship_to_contact_id, ool.item_revision,
                   ool.last_ack_code, ool.last_ack_date, ool.late_demand_penalty_factor,
                   ool.latest_acceptable_date, ool.line_set_id, ool.link_to_line_id,
                   ool.marketing_source_code_id, ool.mfg_component_sequence_id, ool.mfg_lead_time,
                   ool.minisite_id, ool.model_group_number, ool.model_remnant_flag,
                   ool.option_flag, ool.option_number, ool.order_firmed_date,
                   ool.ordered_quantity2, ool.ordered_quantity_uom2, ool.original_inventory_item_id,
                   ool.original_item_identifier_type, ool.original_list_price, ool.original_ordered_item_id,
                   ool.original_ordered_item, ool.over_ship_reason_code, ool.over_ship_resolved_flag,
                   ool.override_atp_date_code, ool.planning_priority, ool.preferred_grade,
                   ool.price_request_code, ool.pricing_attribute1, ool.pricing_attribute10,
                   ool.pricing_attribute2, ool.pricing_attribute3, ool.pricing_attribute4,
                   ool.pricing_attribute5, ool.pricing_attribute6, ool.pricing_attribute7,
                   ool.pricing_attribute8, ool.pricing_attribute9, ool.pricing_context,
                   ool.project_id, ool.reference_customer_trx_line_id, ool.reference_header_id,
                   ool.reference_line_id, ool.reference_type, ool.return_attribute1,
                   ool.return_attribute10, ool.return_attribute11, ool.return_attribute12,
                   ool.return_attribute13, ool.return_attribute14, ool.return_attribute15,
                   ool.return_attribute2, ool.return_attribute3, ool.return_attribute4,
                   ool.return_attribute5, ool.return_attribute6, ool.return_attribute7,
                   ool.return_attribute8, ool.return_attribute9, ool.return_context,
                   ool.return_reason_code, ool.retrobill_request_id, ool.revenue_amount,
                   ool.revrec_event_code, ool.revrec_expiration_days, ool.revrec_comments,
                   ool.revrec_reference_document, ool.revrec_signature, ool.revrec_signature_date,
                   ool.revrec_implicit_flag, ool.rla_schedule_type_code, ool.service_number,
                   ool.service_reference_type_code, ool.service_reference_line_id, ool.service_reference_system_id,
                   ool.service_txn_reason_code, ool.service_txn_comments, ool.service_duration,
                   ool.service_period, ool.service_start_date, ool.service_end_date,
                   ool.service_coterminate_flag, ool.ship_model_complete_flag, ool.ship_tolerance_above,
                   ool.ship_tolerance_below, ool.shipped_quantity2, ool.shipping_quantity2,
                   ool.shipping_quantity_uom2, ool.sort_order, ool.tax_exempt_number,
                   ool.tax_exempt_reason_code, ool.tax_point_code, ool.top_model_line_id,
                   ool.unit_list_percent, ool.unit_selling_percent, ool.unit_percent_base_price,
                   ool.unit_list_price_per_pqty, ool.unit_selling_price_per_pqty, ool.upgraded_flag,
                   ool.veh_cus_item_cum_key_id, ool.visible_demand_flag, ool.task_id,
                   ool.tp_context, ool.tp_attribute1, ool.tp_attribute2,
                   ool.tp_attribute3, ool.tp_attribute4, ool.tp_attribute5,
                   ool.tp_attribute6, ool.tp_attribute7, ool.tp_attribute8,
                   ool.tp_attribute9, ool.tp_attribute10, ool.tp_attribute11,
                   ool.tp_attribute12, ool.tp_attribute13, ool.tp_attribute14,
                   ool.tp_attribute15, ool.creation_date, ool.created_by,
                   ool.last_update_date, ool.last_updated_by, ool.last_update_login,
                   ool.program_application_id, ool.program_id, ool.program_update_date
              INTO ltab_line (ln_index).header_id, ltab_line (ln_index).line_id, ltab_line (ln_index).line_type_id, ltab_line (ln_index).line_number,
                                                 ltab_line (ln_index).shipment_number, ltab_line (ln_index).inventory_item_id, ltab_line (ln_index).order_quantity_uom,
                                                 ltab_line (ln_index).ordered_item, ltab_line (ln_index).ordered_item_id, ltab_line (ln_index).ship_from_org_id,
                                                 ltab_line (ln_index).ship_to_org_id, ltab_line (ln_index).request_date, ltab_line (ln_index).schedule_ship_date,
                                                 ltab_line (ln_index).item_type_code, ltab_line (ln_index).line_category_code, ltab_line (ln_index).open_flag,
                                                 ltab_line (ln_index).booked_flag, ltab_line (ln_index).cancelled_flag, ltab_line (ln_index).unit_selling_price,
                                                 ltab_line (ln_index).unit_list_price, ltab_line (ln_index).ordered_quantity, ltab_line (ln_index).org_id,
                                                 ltab_line (ln_index).promise_date, ltab_line (ln_index).pricing_quantity, ltab_line (ln_index).pricing_quantity_uom,
                                                 ltab_line (ln_index).cancelled_quantity, ltab_line (ln_index).fulfilled_quantity, ltab_line (ln_index).shipped_quantity,
                                                 ltab_line (ln_index).shipping_quantity, ltab_line (ln_index).shipping_quantity_uom, ltab_line (ln_index).tax_exempt_flag,
                                                 ltab_line (ln_index).tax_code, ltab_line (ln_index).tax_date, ltab_line (ln_index).tax_rate,
                                                 ltab_line (ln_index).tax_value, ltab_line (ln_index).invoice_to_org_id, ltab_line (ln_index).sold_from_org_id,
                                                 ltab_line (ln_index).sold_to_org_id, ltab_line (ln_index).deliver_to_org_id, ltab_line (ln_index).ship_to_contact_id,
                                                 ltab_line (ln_index).deliver_to_contact_id, ltab_line (ln_index).invoice_to_contact_id, ltab_line (ln_index).price_list_id,
                                                 ltab_line (ln_index).pricing_date, ltab_line (ln_index).invoice_interface_status_code, ltab_line (ln_index).shipment_priority_code,
                                                 ltab_line (ln_index).shipping_method_code, ltab_line (ln_index).freight_carrier_code, ltab_line (ln_index).freight_terms_code,
                                                 ltab_line (ln_index).payment_term_id, ltab_line (ln_index).invoicing_rule_id, ltab_line (ln_index).accounting_rule_id,
                                                 ltab_line (ln_index).source_document_type_id, ltab_line (ln_index).source_document_id, ltab_line (ln_index).source_document_line_id,
                                                 ltab_line (ln_index).source_document_version_number, ltab_line (ln_index).order_source_id, ltab_line (ln_index).orig_sys_document_ref,
                                                 ltab_line (ln_index).orig_sys_line_ref, ltab_line (ln_index).orig_sys_shipment_ref, ltab_line (ln_index).actual_shipment_date,
                                                 ltab_line (ln_index).schedule_arrival_date, ltab_line (ln_index).schedule_status_code, ltab_line (ln_index).source_type_code,
                                                 ltab_line (ln_index).salesrep_id, ltab_line (ln_index).arrival_set_id, ltab_line (ln_index).ship_set_id,
                                                 ltab_line (ln_index).item_identifier_type, ltab_line (ln_index).shipping_interfaced_flag, ltab_line (ln_index).drop_ship_flag,
                                                 ltab_line (ln_index).customer_line_number, ltab_line (ln_index).customer_shipment_number, ltab_line (ln_index).customer_payment_term_id,
                                                 ltab_line (ln_index).fulfilled_flag, ltab_line (ln_index).shipping_instructions, ltab_line (ln_index).packing_instructions,
                                                 ltab_line (ln_index).invoiced_quantity, ltab_line (ln_index).shippable_flag, ltab_line (ln_index).re_source_flag,
                                                 ltab_line (ln_index).flow_status_code, ltab_line (ln_index).fulfillment_method_code, ltab_line (ln_index).calculate_price_flag,
                                                 ltab_line (ln_index).fulfillment_date, ltab_line (ln_index).lock_control, ltab_line (ln_index).subinventory,
                                                 ltab_line (ln_index).item_substitution_type_code, ltab_line (ln_index).unit_cost, ltab_line (ln_index).item_relationship_type,
                                                 ltab_line (ln_index).blanket_number, ltab_line (ln_index).blanket_line_number, ltab_line (ln_index).blanket_version_number,
                                                 ltab_line (ln_index).earliest_ship_date, ltab_line (ln_index).transaction_phase_code, ltab_line (ln_index).actual_fulfillment_date,
                                                 ltab_line (ln_index).earliest_acceptable_date, ltab_line (ln_index).actual_arrival_date, ltab_line (ln_index).accepted_by,
                                                 ltab_line (ln_index).accepted_quantity, ltab_line (ln_index).accounting_rule_duration, ltab_line (ln_index).agreement_id,
                                                 ltab_line (ln_index).ato_line_id, ltab_line (ln_index).attribute1, ltab_line (ln_index).attribute10,
                                                 ltab_line (ln_index).attribute11, ltab_line (ln_index).attribute12, ltab_line (ln_index).attribute13,
                                                 ltab_line (ln_index).attribute14, ltab_line (ln_index).attribute15, ltab_line (ln_index).attribute16,
                                                 ltab_line (ln_index).attribute17, ltab_line (ln_index).attribute18, ltab_line (ln_index).attribute19,
                                                 ltab_line (ln_index).attribute2, ltab_line (ln_index).attribute20, ltab_line (ln_index).attribute3,
                                                 ltab_line (ln_index).attribute4, ltab_line (ln_index).attribute5, ltab_line (ln_index).attribute6,
                                                 ltab_line (ln_index).attribute7, ltab_line (ln_index).attribute8, ltab_line (ln_index).attribute9,
                                                 ltab_line (ln_index).authorized_to_ship_flag, ltab_line (ln_index).auto_selected_quantity, ltab_line (ln_index).cancelled_quantity2,
                                                 ltab_line (ln_index).change_sequence, ltab_line (ln_index).charge_periodicity_code, ltab_line (ln_index).commitment_id,
                                                 ltab_line (ln_index).component_code, ltab_line (ln_index).component_number, ltab_line (ln_index).component_sequence_id,
                                                 ltab_line (ln_index).config_header_id, ltab_line (ln_index).config_rev_nbr, ltab_line (ln_index).configuration_id,
                                                 ltab_line (ln_index).context, ltab_line (ln_index).contingency_id, ltab_line (ln_index).credit_invoice_line_id,
                                                 ltab_line (ln_index).cust_model_serial_number, ltab_line (ln_index).cust_po_number, ltab_line (ln_index).cust_production_seq_num,
                                                 ltab_line (ln_index).customer_dock_code, ltab_line (ln_index).customer_item_net_price, ltab_line (ln_index).customer_job,
                                                 ltab_line (ln_index).customer_production_line, ltab_line (ln_index).customer_trx_line_id, ltab_line (ln_index).delivery_lead_time,
                                                 ltab_line (ln_index).demand_bucket_type_code, ltab_line (ln_index).demand_class_code, ltab_line (ln_index).dep_plan_required_flag,
                                                 ltab_line (ln_index).end_customer_id, ltab_line (ln_index).end_customer_contact_id, ltab_line (ln_index).end_customer_site_use_id,
                                                 ltab_line (ln_index).end_item_unit_number, ltab_line (ln_index).explosion_date, ltab_line (ln_index).firm_demand_flag,
                                                 ltab_line (ln_index).first_ack_code, ltab_line (ln_index).first_ack_date, ltab_line (ln_index).fob_point_code,
                                                 ltab_line (ln_index).fulfilled_quantity2, ltab_line (ln_index).global_attribute1, ltab_line (ln_index).global_attribute10,
                                                 ltab_line (ln_index).global_attribute11, ltab_line (ln_index).global_attribute12, ltab_line (ln_index).global_attribute13,
                                                 ltab_line (ln_index).global_attribute14, ltab_line (ln_index).global_attribute15, ltab_line (ln_index).global_attribute16,
                                                 ltab_line (ln_index).global_attribute17, ltab_line (ln_index).global_attribute18, ltab_line (ln_index).global_attribute19,
                                                 ltab_line (ln_index).global_attribute2, ltab_line (ln_index).global_attribute20, ltab_line (ln_index).global_attribute3,
                                                 ltab_line (ln_index).global_attribute4, ltab_line (ln_index).global_attribute5, ltab_line (ln_index).global_attribute6,
                                                 ltab_line (ln_index).global_attribute7, ltab_line (ln_index).global_attribute8, ltab_line (ln_index).global_attribute9,
                                                 ltab_line (ln_index).global_attribute_category, ltab_line (ln_index).ib_owner, ltab_line (ln_index).ib_installed_at_location,
                                                 ltab_line (ln_index).ib_current_location, ltab_line (ln_index).industry_attribute1, ltab_line (ln_index).industry_attribute10,
                                                 ltab_line (ln_index).industry_attribute11, ltab_line (ln_index).industry_attribute12, ltab_line (ln_index).industry_attribute13,
                                                 ltab_line (ln_index).industry_attribute14, ltab_line (ln_index).industry_attribute15, ltab_line (ln_index).industry_attribute16,
                                                 ltab_line (ln_index).industry_attribute17, ltab_line (ln_index).industry_attribute18, ltab_line (ln_index).industry_attribute19,
                                                 ltab_line (ln_index).industry_attribute20, ltab_line (ln_index).industry_attribute21, ltab_line (ln_index).industry_attribute22,
                                                 ltab_line (ln_index).industry_attribute23, ltab_line (ln_index).industry_attribute24, ltab_line (ln_index).industry_attribute25,
                                                 ltab_line (ln_index).industry_attribute26, ltab_line (ln_index).industry_attribute27, ltab_line (ln_index).industry_attribute28,
                                                 ltab_line (ln_index).industry_attribute29, ltab_line (ln_index).industry_attribute30, ltab_line (ln_index).industry_attribute2,
                                                 ltab_line (ln_index).industry_attribute3, ltab_line (ln_index).industry_attribute4, ltab_line (ln_index).industry_attribute5,
                                                 ltab_line (ln_index).industry_attribute6, ltab_line (ln_index).industry_attribute7, ltab_line (ln_index).industry_attribute8,
                                                 ltab_line (ln_index).industry_attribute9, ltab_line (ln_index).industry_context, ltab_line (ln_index).intermed_ship_to_org_id,
                                                 ltab_line (ln_index).intermed_ship_to_contact_id, ltab_line (ln_index).item_revision, ltab_line (ln_index).last_ack_code,
                                                 ltab_line (ln_index).last_ack_date, ltab_line (ln_index).late_demand_penalty_factor, ltab_line (ln_index).latest_acceptable_date,
                                                 ltab_line (ln_index).line_set_id, ltab_line (ln_index).link_to_line_id, ltab_line (ln_index).marketing_source_code_id,
                                                 ltab_line (ln_index).mfg_component_sequence_id, ltab_line (ln_index).mfg_lead_time, ltab_line (ln_index).minisite_id,
                                                 ltab_line (ln_index).model_group_number, ltab_line (ln_index).model_remnant_flag, ltab_line (ln_index).option_flag,
                                                 ltab_line (ln_index).option_number, ltab_line (ln_index).order_firmed_date, ltab_line (ln_index).ordered_quantity2,
                                                 ltab_line (ln_index).ordered_quantity_uom2, ltab_line (ln_index).original_inventory_item_id, ltab_line (ln_index).original_item_identifier_type,
                                                 ltab_line (ln_index).original_list_price, ltab_line (ln_index).original_ordered_item_id, ltab_line (ln_index).original_ordered_item,
                                                 ltab_line (ln_index).over_ship_reason_code, ltab_line (ln_index).over_ship_resolved_flag, ltab_line (ln_index).override_atp_date_code,
                                                 ltab_line (ln_index).planning_priority, ltab_line (ln_index).preferred_grade, ltab_line (ln_index).price_request_code,
                                                 ltab_line (ln_index).pricing_attribute1, ltab_line (ln_index).pricing_attribute10, ltab_line (ln_index).pricing_attribute2,
                                                 ltab_line (ln_index).pricing_attribute3, ltab_line (ln_index).pricing_attribute4, ltab_line (ln_index).pricing_attribute5,
                                                 ltab_line (ln_index).pricing_attribute6, ltab_line (ln_index).pricing_attribute7, ltab_line (ln_index).pricing_attribute8,
                                                 ltab_line (ln_index).pricing_attribute9, ltab_line (ln_index).pricing_context, ltab_line (ln_index).project_id,
                                                 ltab_line (ln_index).reference_customer_trx_line_id, ltab_line (ln_index).reference_header_id, ltab_line (ln_index).reference_line_id,
                                                 ltab_line (ln_index).reference_type, ltab_line (ln_index).return_attribute1, ltab_line (ln_index).return_attribute10,
                                                 ltab_line (ln_index).return_attribute11, ltab_line (ln_index).return_attribute12, ltab_line (ln_index).return_attribute13,
                                                 ltab_line (ln_index).return_attribute14, ltab_line (ln_index).return_attribute15, ltab_line (ln_index).return_attribute2,
                                                 ltab_line (ln_index).return_attribute3, ltab_line (ln_index).return_attribute4, ltab_line (ln_index).return_attribute5,
                                                 ltab_line (ln_index).return_attribute6, ltab_line (ln_index).return_attribute7, ltab_line (ln_index).return_attribute8,
                                                 ltab_line (ln_index).return_attribute9, ltab_line (ln_index).return_context, ltab_line (ln_index).return_reason_code,
                                                 ltab_line (ln_index).retrobill_request_id, ltab_line (ln_index).revenue_amount, ltab_line (ln_index).revrec_event_code,
                                                 ltab_line (ln_index).revrec_expiration_days, ltab_line (ln_index).revrec_comments, ltab_line (ln_index).revrec_reference_document,
                                                 ltab_line (ln_index).revrec_signature, ltab_line (ln_index).revrec_signature_date, ltab_line (ln_index).revrec_implicit_flag,
                                                 ltab_line (ln_index).rla_schedule_type_code, ltab_line (ln_index).service_number, ltab_line (ln_index).service_reference_type_code,
                                                 ltab_line (ln_index).service_reference_line_id, ltab_line (ln_index).service_reference_system_id, ltab_line (ln_index).service_txn_reason_code,
                                                 ltab_line (ln_index).service_txn_comments, ltab_line (ln_index).service_duration, ltab_line (ln_index).service_period,
                                                 ltab_line (ln_index).service_start_date, ltab_line (ln_index).service_end_date, ltab_line (ln_index).service_coterminate_flag,
                                                 ltab_line (ln_index).ship_model_complete_flag, ltab_line (ln_index).ship_tolerance_above, ltab_line (ln_index).ship_tolerance_below,
                                                 ltab_line (ln_index).shipped_quantity2, ltab_line (ln_index).shipping_quantity2, ltab_line (ln_index).shipping_quantity_uom2,
                                                 ltab_line (ln_index).sort_order, ltab_line (ln_index).tax_exempt_number, ltab_line (ln_index).tax_exempt_reason_code,
                                                 ltab_line (ln_index).tax_point_code, ltab_line (ln_index).top_model_line_id, ltab_line (ln_index).unit_list_percent,
                                                 ltab_line (ln_index).unit_selling_percent, ltab_line (ln_index).unit_percent_base_price, ltab_line (ln_index).unit_list_price_per_pqty,
                                                 ltab_line (ln_index).unit_selling_price_per_pqty, ltab_line (ln_index).upgraded_flag, ltab_line (ln_index).veh_cus_item_cum_key_id,
                                                 ltab_line (ln_index).visible_demand_flag, ltab_line (ln_index).task_id, ltab_line (ln_index).tp_context,
                                                 ltab_line (ln_index).tp_attribute1, ltab_line (ln_index).tp_attribute2, ltab_line (ln_index).tp_attribute3,
                                                 ltab_line (ln_index).tp_attribute4, ltab_line (ln_index).tp_attribute5, ltab_line (ln_index).tp_attribute6,
                                                 ltab_line (ln_index).tp_attribute7, ltab_line (ln_index).tp_attribute8, ltab_line (ln_index).tp_attribute9,
                                                 ltab_line (ln_index).tp_attribute10, ltab_line (ln_index).tp_attribute11, ltab_line (ln_index).tp_attribute12,
                                                 ltab_line (ln_index).tp_attribute13, ltab_line (ln_index).tp_attribute14, ltab_line (ln_index).tp_attribute15,
                                                 ltab_line (ln_index).creation_date, ltab_line (ln_index).created_by, ltab_line (ln_index).last_update_date,
                                                 ltab_line (ln_index).last_updated_by, ltab_line (ln_index).last_update_login, ltab_line (ln_index).program_application_id,
                                                 ltab_line (ln_index).program_id, ltab_line (ln_index).program_update_date
              FROM oe_order_lines ool
             WHERE ool.line_id = pn_line_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ltab_line (ln_index).line_number       := fnd_api.g_miss_num;
                ltab_line (ln_index).shipment_number   := fnd_api.g_miss_num;
                ltab_line (ln_index).item_type_code    := fnd_api.g_miss_char;
                ltab_line (ln_index).line_category_code   :=
                    fnd_api.g_miss_char;
                ltab_line (ln_index).open_flag         :=
                    fnd_api.g_miss_char;
                ltab_line (ln_index).booked_flag       :=
                    fnd_api.g_miss_char;
                ltab_line (ln_index).cancelled_flag    :=
                    fnd_api.g_miss_char;
                ltab_line (ln_index).unit_selling_price   :=
                    fnd_api.g_miss_num;
                ltab_line (ln_index).unit_list_price   :=
                    fnd_api.g_miss_num;
                ltab_line (ln_index).ordered_quantity   :=
                    fnd_api.g_miss_num;
                ltab_line (ln_index).line_type_id      :=
                    fnd_api.g_miss_char;
        END;

        ----------------------------------
        -- Get Order number for logging --
        ----------------------------------
        gv_operation_code                             := 'Get Order number for logging';

        BEGIN
            SELECT order_number, ltab_line (ln_index).line_number || DECODE (ltab_line (ln_index).shipment_number, NULL, NULL, '.' || ltab_line (ln_index).shipment_number)
              INTO lt_order_number, lv_line_number
              FROM oe_order_headers
             WHERE header_id = ltab_line (ln_index).header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lt_order_number   := NULL;
                lv_line_number    := NULL;
        END;

        lv_attribute4                                 :=
            'Header id - ' || ltab_line (ln_index).header_id;

        ------------------------
        -- Create record type --
        ------------------------
        gv_operation_code                             := 'Create record type for old line';
        ltab_old_line (ln_index)                      := ltab_line (ln_index);

        gv_operation_code                             := 'Create record type for header';
        lrec_header.header_id                         := ltab_line (ln_index).header_id;
        lrec_header.operation                         := oe_globals.g_opr_none;

        gv_operation_code                             := 'Create record type for line';
        ltab_line (ln_index).creation_date            := gd_sysdate;
        ltab_line (ln_index).created_by               := gn_user_id;
        ltab_line (ln_index).last_update_date         := gd_sysdate;
        ltab_line (ln_index).last_updated_by          := gn_user_id;
        ltab_line (ln_index).last_update_login        := gn_login_id;
        ltab_line (ln_index).request_id               := gn_request_id;
        ltab_line (ln_index).program_application_id   := gn_prog_appl_id;
        ltab_line (ln_index).program_id               := gn_program_id;
        ltab_line (ln_index).program_update_date      := gd_sysdate;
        ltab_line (ln_index).operation                :=
            oe_globals.g_opr_update;
        ltab_line (ln_index).cancelled_quantity       :=
            NVL (pn_cancel_qty, ltab_line (ln_index).ordered_quantity);
        ltab_line (ln_index).ordered_quantity         :=
            NVL (pn_ordered_qty, 0);

        IF pv_event = 'LINE'
        THEN
            ltab_line (ln_index).cancelled_flag     := gv_yes;
            ltab_line (ln_index).flow_status_code   := lv_cancelled;
        END IF;

        ltab_line (ln_index).change_reason            := pv_cancel_reason;

        -----------------------------------
        -- Call API to Cancel order line --
        -----------------------------------
        gv_operation_code                             :=
            'Call oe_order_pub.process_order API to cancel ' || 'order line';

        oe_order_pub.process_order (
            p_org_id                   => ltab_line (ln_index).org_id,
            p_api_version_number       => ln_api_version,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => lv_return_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lv_msg_data,
            p_header_rec               => lrec_header,
            p_line_tbl                 => ltab_line,
            p_old_line_tbl             => ltab_old_line,
            p_action_request_tbl       => ltab_action_request,
            x_header_rec               => lrec_out_header,
            x_header_val_rec           => ltrec_header_val,
            x_header_adj_tbl           => ltab_header_adj,
            x_header_adj_val_tbl       => ltab_header_adj_val,
            x_header_price_att_tbl     => ltab_header_price_att,
            x_header_adj_att_tbl       => ltab_header_adj_att,
            x_header_adj_assoc_tbl     => ltab_header_adj_assoc,
            x_header_scredit_tbl       => ltab_header_scredit,
            x_header_scredit_val_tbl   => ltab_header_scredit_val,
            x_header_payment_tbl       => ltab_header_payment,
            x_header_payment_val_tbl   => ltab_header_payment_val,
            x_line_tbl                 => ltab_out_line,
            x_line_val_tbl             => ltab_line_val,
            x_line_adj_tbl             => ltab_line_adj,
            x_line_adj_val_tbl         => ltab_line_adj_val,
            x_line_price_att_tbl       => ltab_line_price_att,
            x_line_adj_att_tbl         => ltab_line_adj_att,
            x_line_adj_assoc_tbl       => ltab_line_adj_assoc,
            x_line_scredit_tbl         => ltab_line_scredit,
            x_line_scredit_val_tbl     => ltab_line_scredit_val,
            x_line_payment_tbl         => ltab_line_payment,
            x_line_payment_val_tbl     => ltab_line_payment_val,
            x_lot_serial_tbl           => ltab_lot_serial,
            x_lot_serial_val_tbl       => ltab_lot_serial_val,
            x_action_request_tbl       => ltab_out_action_request);

        xxdo_error_pkg.log_message (
               'API return status for Cancellation of line - '
            || lv_return_status);

        gv_operation_code                             :=
               'Check error status for oe_order_pub.process_order for '
            || 'Cancellation of line';

        IF lv_return_status = fnd_api.g_ret_sts_unexp_error
        THEN
            xn_retcode   := 1;
            xxdo_error_pkg.log_message (
                   'API oe_order_pub.process_order for Cancellation of line'
                || ' for Load Nbr - '
                || pv_load_nbr
                || ' Trip id - '
                || pn_trip_id
                || ' Delivery detail id - '
                || pn_delivery_detail_id
                || ' Order# - '
                || lt_order_number
                || ' Line# - '
                || lv_line_number
                || ' returned '
                || ln_msg_count
                || ' unexpected error messages',
                'LOG');

            IF ln_msg_count IS NOT NULL
            THEN
                FOR lrec_msg IN 1 .. ln_msg_count
                LOOP
                    lv_err_msg   :=
                           lv_err_msg
                        || oe_msg_pub.get (lrec_msg, fnd_api.g_false);
                END LOOP;

                xxdo_error_pkg.log_exception (
                    pv_exception_code    => 'XXONT_API_UNEXPECTED_ERROR',
                    pv_subprogram_code   => lv_subprogram_code,
                    pv_operation_code    => gv_operation_code,
                    pv_operation_key     => lv_operation_key,
                    pv_log_flag          => gv_yes,
                    pv_token_name1       => 'API',
                    pv_token_value1      => 'oe_order_pub.process_order',
                    pv_token_name2       => 'SQLERRM',
                    pv_token_value2      =>
                           'Order# - '
                        || lt_order_number
                        || ' Line# - '
                        || lv_line_number
                        || ' returned message - '
                        || SUBSTR (lv_err_msg, 1, 1900),
                    pv_attribute1        => lv_attribute1,
                    pv_attribute2        => lv_attribute2,
                    pv_attribute3        => lv_attribute3,
                    pv_attribute4        => lv_attribute4,
                    pv_attribute5        => lv_attribute5);
            END IF;                                      -- ln_msg_count check
        ELSIF lv_return_status = fnd_api.g_ret_sts_error
        THEN
            xn_retcode   := 1;
            xxdo_error_pkg.log_message (
                   'API oe_order_pub.process_order for Cancellation of line'
                || ' for Load Nbr - '
                || pv_load_nbr
                || ' Trip id - '
                || pn_trip_id
                || ' Delivery detail id - '
                || pn_delivery_detail_id
                || ' Order# - '
                || lt_order_number
                || ' Line# - '
                || lv_line_number
                || ' returned '
                || ln_msg_count
                || ' error messages',
                'LOG');

            IF ln_msg_count IS NOT NULL
            THEN
                FOR lrec_msg IN 1 .. ln_msg_count
                LOOP
                    lv_err_msg   :=
                           lv_err_msg
                        || oe_msg_pub.get (lrec_msg, fnd_api.g_false);
                END LOOP;

                xxdo_error_pkg.log_exception (
                    pv_exception_code    => 'XXONT_API_ERROR',
                    pv_subprogram_code   => lv_subprogram_code,
                    pv_operation_code    => gv_operation_code,
                    pv_operation_key     => lv_operation_key,
                    pv_log_flag          => gv_yes,
                    pv_token_name1       => 'API',
                    pv_token_value1      => 'oe_order_pub.process_order',
                    pv_token_name2       => 'SQLERRM',
                    pv_token_value2      =>
                           'Order# - '
                        || lt_order_number
                        || ' Line# - '
                        || lv_line_number
                        || ' returned message - '
                        || SUBSTR (lv_err_msg, 1, 1900),
                    pv_attribute1        => lv_attribute1,
                    pv_attribute2        => lv_attribute2,
                    pv_attribute3        => lv_attribute3,
                    pv_attribute4        => lv_attribute4,
                    pv_attribute5        => lv_attribute5);
            END IF;                                      -- ln_msg_count check
        END IF;                         -- Expected or unexpected  error check
    EXCEPTION
        WHEN OTHERS
        THEN
            xn_retcode   := 1;

            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_ORA_NOTIFICATION',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => lv_operation_key,
                pv_log_flag          => gv_yes,
                pv_token_name1       => 'SQLCODE',
                pv_token_value1      => SQLCODE,
                pv_token_name2       => 'SQLERRM',
                pv_token_value2      => SQLERRM,
                pv_attribute1        => lv_attribute1,
                pv_attribute2        => lv_attribute2,
                pv_attribute3        => lv_attribute3,
                pv_attribute4        => lv_attribute4,
                pv_attribute5        => lv_attribute5);
    END cancel_order_line;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Function get_master_org is for Retreiving Master Organization Id
    -- This is a common function used/called from various packages.
    -------------------------------------------------------------------------------
    -- Modification log:
    --   Date          Programmer    Description
    --  -------------  ----------    ----------------------------------------------
    --   06/24/2013    Infosys      1.0.0
    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    FUNCTION get_master_org
        RETURN NUMBER
    IS
        lv_operation_key     VARCHAR2 (240) := NULL;
        lv_operation_name    VARCHAR2 (240) := NULL;
        lv_subprogram_code   VARCHAR2 (40) := 'GET_MASTER_ORG';
        ln_master_org_id     mtl_parameters.master_organization_id%TYPE
                                 := NULL;
    BEGIN
        ------------------------------------------------
        --Fetching Operating Unit for an organization --
        ------------------------------------------------
        BEGIN
            lv_operation_key    := 'Getting Master Organization ID: ';
            lv_operation_name   :=
                'Get Master Organization Id for an organization';


            gv_operation_code   := 'Fetch Master Org';

            SELECT master_organization_id
              INTO ln_master_org_id
              FROM mtl_parameters
             WHERE organization_id = master_organization_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_master_org_id   := 0;
                xxdo_error_pkg.log_message (
                    'Error in Fetching Master Organization Id ');
        END;

        RETURN ln_master_org_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_master_org_id   := 0;
            xxdo_error_pkg.log_message (
                'Error in Fetching Master Org ' || SQLERRM,
                'LOG');
            RETURN ln_master_org_id;
    END get_master_org;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Function get_op_unit is for Retreiving Operating Unit Name
    -- This is a common function used/called from various packages.
    -------------------------------------------------------------------------------
    -- Modification log:
    --   Date          Programmer    Description
    --  -------------  ----------    ----------------------------------------------
    --   06/24/2013    Infosys       1.0.0
    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    FUNCTION get_op_unit (pn_organization_id     IN NUMBER,
                          pv_organization_code   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_operation_key     VARCHAR2 (240) := NULL;
        lv_operation_name    VARCHAR2 (240) := NULL;
        lv_subprogram_code   VARCHAR2 (40) := 'GET_OPERATING_UNIT';
        lv_op_unit_name      hr_operating_units.name%TYPE := NULL;
    BEGIN
        ------------------------------------------------
        --Fetching Operating Unit for an organization --
        ------------------------------------------------
        BEGIN
            lv_operation_key    := 'Getting Operating Unit : ';
            lv_operation_name   := 'Get Operating Unit for an organization';

            gv_operation_code   := 'Fetch Operating Unit';

            SELECT UPPER (hou.name)
              INTO lv_op_unit_name
              FROM org_organization_definitions ood, hr_operating_units hou
             WHERE     ood.operating_unit = hou.organization_id
                   AND ood.organization_id =
                       NVL (pn_organization_id, ood.organization_id)
                   AND ood.organization_code =
                       NVL (pv_organization_code, ood.organization_code);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_op_unit_name   := 0;
                xxdo_error_pkg.log_message (
                    'Error in Fetching Operating Unit Name ');
        END;

        RETURN lv_op_unit_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_op_unit_name   := 0;
            xxdo_error_pkg.log_message (
                'Error in Fetching Operating Unit ' || SQLERRM,
                'LOG');
            RETURN lv_op_unit_name;
    END get_op_unit;

    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    -- Procedure process_item_uda is for Creating/Updating/Deleting Item Attributes
    -- This is a common function used/called from various packages.
    -------------------------------------------------------------------------------
    -- Modification log:
    --     Date        Programmer   Description
    --  -------------  ----------  ----------------------------------------------
    --   09-MAY-2012    Infosys      1.0.0
    -------------------------------------------------------------------------------
    -------------------------------------------------------------------------------
    PROCEDURE process_item_uda (pn_user_id            IN     NUMBER,
                                pn_resp_id            IN     NUMBER,
                                pn_resp_appl_id       IN     NUMBER,
                                pn_org_id             IN     NUMBER,
                                pn_item_id            IN     NUMBER,
                                pn_attr_group_id      IN     NUMBER,
                                pn_attr_value         IN     NUMBER,
                                pv_transaction_type   IN     VARCHAR2,
                                pv_attr_value         IN     VARCHAR2,
                                pv_attr_name          IN     VARCHAR2,
                                pv_attr_disp_name     IN     VARCHAR2,
                                pv_attr_level         IN     VARCHAR2,
                                pd_attr_value         IN     DATE,
                                xv_return_status         OUT VARCHAR2)
    IS
        ln_attr_identifier        NUMBER := 0;
        ln_grp_identifier         NUMBER := 0;
        l_attributes_row_table    ego_user_attr_row_table
                                      := ego_user_attr_row_table ();
        l_attributes_data_table   ego_user_attr_data_table
                                      := ego_user_attr_data_table ();
        l_failed_row_id_list      VARCHAR2 (2000) := NULL;
        lv_return_status          VARCHAR2 (1) := NULL;
        ln_errorcode              NUMBER := 0;
        ln_msg_count              NUMBER := 0;
        lv_msg_data               VARCHAR2 (2000) := NULL;
        lv_err_txt                VARCHAR2 (2000);
        ln_error_count            NUMBER := 0;
        x_failed_row_id_list      VARCHAR2 (255);
        x_message_list            error_handler.error_tbl_type;
        x_return_status           VARCHAR2 (10);
        x_errorcode               NUMBER;
        x_msg_count               NUMBER;
        x_msg_data                VARCHAR2 (255);
        lv_error_text             VARCHAR2 (2000) := NULL;
        lv_error_txt              VARCHAR2 (4000) := NULL;
        lv_op_key                 VARCHAR2 (240) := NULL;
        lv_op_name                VARCHAR2 (240) := NULL;
        ln_resp_appl_id           NUMBER := -1;
        ln_resp_id                NUMBER := -1;
        ln_user_id                NUMBER := -1;
    BEGIN
        lv_op_name           := 'Processing Item UDAs From Common Package';
        lv_op_key            :=
               'Item id :: '
            || pn_item_id
            || ' Organization Id :: '
            || pn_org_id;

        -- Get the application_id and responsibility_id
        BEGIN
            lv_op_key   := 'Responsibility key: ' || gv_resp_name;
            lv_op_name   :=
                'Getting application id and responsibility id for apps initialization';

            SELECT application_id, responsibility_id
              INTO ln_resp_appl_id, ln_resp_id
              FROM fnd_responsibility
             WHERE responsibility_key = gv_resp_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in Fetching Responsibility :: '
                    || gv_resp_name
                    || ' :: '
                    || SQLERRM);
        END;

        BEGIN
            lv_op_key    := 'User id: ' || gn_user_id;
            lv_op_name   := 'fnd_global.apps_initialize';
            fnd_global.apps_initialize (pn_user_id,
                                        ln_resp_id,
                                        ln_resp_appl_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in Apps Initializing :: ' || SQLERRM);
        END;

        lv_op_key            :=
               'Attr group id - item_id - orgn_id: '
            || pn_attr_group_id
            || ' - '
            || pn_item_id
            || ' - '
            || pn_org_id;
        lv_op_name           :=
               'Calling ego_item_pub.process_user_attrs_for_item for pv_attr_name-value: '
            || pv_attr_name
            || ' - '
            || pv_attr_value
            || pn_attr_value
            || pd_attr_value;

        ln_grp_identifier    := ln_grp_identifier + 1;
        ln_attr_identifier   := ln_attr_identifier + 1;
        l_attributes_row_table.EXTEND ();
        l_attributes_row_table (ln_grp_identifier)   :=
            ego_user_attrs_data_pub.build_attr_group_row_object (
                p_row_identifier      => ln_grp_identifier,
                p_attr_group_id       => pn_attr_group_id,
                p_attr_group_app_id   => ln_resp_appl_id,
                p_attr_group_type     => 'EGO_ITEMMGMT_GROUP',
                p_attr_group_name     => NULL,
                p_data_level          => pv_attr_level,
                p_data_level_1        => NULL,
                p_data_level_2        => NULL,
                p_data_level_3        => NULL,
                p_data_level_4        => NULL,
                p_data_level_5        => NULL,
                p_transaction_type    => pv_transaction_type -- ego_user_attrs_data_pvt.g_sync_mode
                                                            );
        l_attributes_data_table.EXTEND ();
        l_attributes_data_table (ln_attr_identifier)   :=
            ego_user_attr_data_obj (ln_grp_identifier, pv_attr_name, pv_attr_value, pn_attr_value, pd_attr_value, pv_attr_disp_name
                                    , NULL, NULL);

        BEGIN
            ego_item_pub.process_user_attrs_for_item (
                p_api_version               => 1.0,
                p_inventory_item_id         => pn_item_id,
                p_organization_id           => pn_org_id,
                p_attributes_row_table      => l_attributes_row_table,
                p_attributes_data_table     => l_attributes_data_table,
                p_entity_id                 => NULL,
                p_entity_index              => NULL,
                p_entity_code               => NULL,
                p_debug_level               => 0,
                p_init_error_handler        => fnd_api.g_true,
                p_write_to_concurrent_log   => fnd_api.g_false,
                p_init_fnd_msg_list         => fnd_api.g_false,
                p_log_errors                => fnd_api.g_true,
                p_add_errors_to_fnd_stack   => fnd_api.g_false,
                p_commit                    => fnd_api.g_false,
                x_failed_row_id_list        => l_failed_row_id_list,
                x_return_status             => lv_return_status,
                x_errorcode                 => ln_errorcode,
                x_msg_count                 => ln_msg_count,
                x_msg_data                  => lv_msg_data);
            fnd_file.put_line (fnd_file.LOG,
                               'API Return Status is: ' || lv_return_status);
            COMMIT;
            xv_return_status   := lv_return_status;

            IF (lv_return_status <> fnd_api.g_ret_sts_success)
            THEN
                ln_error_count   := ln_error_count + 1;
                error_handler.get_message_list (
                    x_message_list => x_message_list);

                FOR l_num_loop_count IN 1 .. x_message_list.COUNT
                LOOP
                    lv_error_txt   :=
                        x_message_list (l_num_loop_count).MESSAGE_TEXT;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error is :: ' || lv_error_txt);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Return Status : '
                        || x_message_list (l_num_loop_count).MESSAGE_TEXT);
                END LOOP;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_text   :=
                       'Error Code is '
                    || TO_CHAR (SQLCODE)
                    || ' Error message is '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error is :: ' || lv_error_txt);
        END;

        IF (x_return_status <> fnd_api.g_ret_sts_success)
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error Message: ');
            error_handler.get_message_list (x_message_list => x_message_list);

            FOR i IN 1 .. x_message_list.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error Message is: ' || x_message_list (i).MESSAGE_TEXT);
            END LOOP;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           '=====================================');
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_txt   :=
                   'Error Code is '
                || TO_CHAR (SQLCODE)
                || ' Error message is '
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, 'Error is :: ' || lv_err_txt);
    END process_item_uda;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                                        --
    -- NAME        : spool_email_pgm                                             --
    -- PARAMETERS  : xv_errbuf     -  Return Error message           --
    --               xn_retcode             - Return Error Code                 --
    --               xn_record_count    - Number of records processed --
    --               pn_spool_id            - Spool query Id                      --
    -- PURPOSE     : This procedure will be used to spool a query    --
    --               and write the query data to the specified file.          --
    --                                                                                         --
    -- Modification History                                                             --
    ----------------------------------------------------------------------------
    -- Date      Developer      Version      Description                        --
    -- ----------   -----------     ------------    -------------------------------
    -- 08/30/2013   Infosys      1.0          Initial Version                    --
    -----------------------------------------------------------------------------
    PROCEDURE spool_email_pgm (xv_errbuf        OUT VARCHAR2,
                               xn_retcode       OUT NUMBER,
                               pn_spool_id   IN     NUMBER)
    IS
        lv_spool_file        VARCHAR2 (2000);
        lv_delimiter         VARCHAR2 (2000);
        lv_query             VARCHAR2 (2000);
        lv_quote             VARCHAR2 (2000);
        lv_to_mailing_list   VARCHAR2 (2000);
        lv_cc_mailing_list   VARCHAR2 (2000);
        lv_subject           VARCHAR2 (2000);
        lv_body              VARCHAR2 (2000);
        lv_dir               VARCHAR2 (4000);
        lv_attachment_path   VARCHAR2 (4000);
        lv_error_message     VARCHAR2 (4000);
        le_spool_error       EXCEPTION;
        lv_subprogram_code   VARCHAR2 (2000)
                                 := 'XXCMN_COMMOM_PKG.SPOOL_EMAIL_PGM';
        ln_rec_count         NUMBER;
    BEGIN
        lv_error_message     := NULL;
        gv_operation_code    := 'Deriving the profile value';

        SELECT fnd_profile.VALUE ('XXCMN_TRACE_DIR') INTO lv_dir FROM DUAL;

        IF lv_dir IS NULL
        THEN
            lv_error_message   :=
                   lv_error_message
                || 'Directory is not setup in the profile - CMN Trace Directory';
            RAISE le_spool_error;
        END IF;

        gv_operation_code    := 'Query from table - xxcmn_spool_query';

        BEGIN
            SELECT xsq.spool_file, xsq.delimiter, xsq.query,
                   xsq.quote, xsq.to_mailing_list, xsq.cc_mailing_list,
                   xsq.subject, xsq.body
              INTO lv_spool_file, lv_delimiter, lv_query, lv_quote,
                                lv_to_mailing_list, lv_cc_mailing_list, lv_subject,
                                lv_body
              FROM xxdo_spool_query xsq
             WHERE xsq.spool_id = pn_spool_id AND xsq.attribute1 = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       lv_error_message
                    || ' Exception while '
                    || gv_operation_code
                    || ' SQL Code - '
                    || SQLCODE
                    || ' SQL Error - '
                    || SQLERRM;
                RAISE le_spool_error;
        END;

        gv_operation_code    := 'Call xxdo_common_pkg.spool_query';
        ln_rec_count         := 0;

        BEGIN
            xxdo_common_pkg.spool_query (pv_spoolfile => lv_spool_file, pv_directory => lv_dir, pv_header => 'DEFAULT', pv_spoolquery => lv_query, pv_delimiter => lv_delimiter, pv_quote => NULL
                                         , pxn_record_count => ln_rec_count);
            xxdo_error_pkg.log_message (
                   'Number of records inserted in spool file - '
                || TO_CHAR (ln_rec_count),
                'LOG');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       lv_error_message
                    || ' Exception while '
                    || gv_operation_code
                    || ' SQL Code - '
                    || SQLCODE
                    || ' SQL Error - '
                    || SQLERRM;
                RAISE le_spool_error;
        END;

        gv_operation_code    := 'Deriving lv_attachment_path';
        lv_attachment_path   := lv_dir || '/' || lv_spool_file;
        gv_operation_code    := 'Call xxdo_common_pkg.send_email';

        BEGIN
            xxdo_common_pkg.send_email (
                pv_sender        => NULL,
                pv_recipient     => lv_to_mailing_list,
                pv_ccrecipient   => lv_cc_mailing_list,
                pv_subject       => lv_subject,
                pv_body          => lv_body,
                pv_attachments   => lv_attachment_path);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_error_message   :=
                       lv_error_message
                    || ' Exception while '
                    || gv_operation_code
                    || ' SQL Code - '
                    || SQLCODE
                    || ' SQL Error - '
                    || SQLERRM;
                RAISE le_spool_error;
        END;
    EXCEPTION
        WHEN le_spool_error
        THEN
            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_SPOOL_ERR',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => gv_operation_key,
                pv_token_name1       => 'ERROR',
                pv_token_value1      => lv_error_message);
            xn_retcode   := 1;
        WHEN OTHERS
        THEN
            xxdo_error_pkg.log_exception (
                pv_exception_code    => 'XXCMN_ORA_EXCEPTION',
                pv_subprogram_code   => lv_subprogram_code,
                pv_operation_code    => gv_operation_code,
                pv_operation_key     => gv_operation_key,
                pv_token_name1       => 'SQLCODE',
                pv_token_value1      => SQLCODE,
                pv_token_name2       => 'SQLERRM',
                pv_token_value2      => SQLERRM);

            xv_errbuf    := SQLERRM;
            xn_retcode   := 2;
    END spool_email_pgm;

    --------------------------------------------------------------------------
    -- TYPE        : Procedure                                              --
    -- NAME        : is_this_prod                                           --
    -- PARAMETERS  : pv_prod_flag                                           --
    --                   Returns Y if current instance is production        --
    --                   otherwise N                                        --
    --               pv_curr_instance - returns instance name               --
    --               pv_prod_instance - returns production instance name    --
    --               instance                                               --
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                    --
    -- ----------   -----------     ------------    --------------------------
    -- 09/20/2013   Debbi        1.0          Initial Version               --
    --------------------------------------------------------------------------
    PROCEDURE is_this_prod (pv_prod_flag OUT VARCHAR2, pv_curr_instance OUT VARCHAR2, pv_prod_instance OUT VARCHAR2)
    IS
    BEGIN
        -- Get the name of the CURRENT instance we are logged into
        BEGIN
            SELECT VALUE
              INTO pv_curr_instance
              FROM v$parameter
             WHERE LOWER (name) = 'db_name';
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_curr_instance   := NULL;
        END;

        -- Get the name of the PRODUCTION database instance
        BEGIN
            SELECT apps.fnd_profile.VALUE ('XXCMN_PROD_DB_INSTANCE_NAME')
              INTO pv_prod_instance
              FROM DUAL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_prod_instance   := 'NOTFOUND';
        END;

        -- Compare the CURRENT instance to the PRODUCTION instance
        IF pv_curr_instance = pv_prod_instance
        THEN
            pv_prod_flag   := 'Y';             -- We are running in production
        ELSE
            pv_prod_flag   := 'N';                   -- This is NOT production
        END IF;
    END is_this_prod;

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : get_edi_server_url                                     --
    -- PARAMETERS  :                                                        --
    --               Function returns the edi host details depending on     --
    --               instance                                               --
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                    --
    -- ----------   -----------     ------------    --------------------------
    -- 09/20/2013   Debbi        1.0          Initial Version               --
    --------------------------------------------------------------------------
    FUNCTION get_edi_server_url
        RETURN VARCHAR2
    AS
        lv_prod_flag       VARCHAR2 (1) := 'N';
        lv_curr_instance   fnd_profile_option_values.profile_option_value%TYPE;
        lv_prod_instance   fnd_profile_option_values.profile_option_value%TYPE;
    BEGIN
        -- Determine if this is production or not
        xxdo_common_pkg.is_this_prod (pv_prod_flag       => lv_prod_flag,
                                      pv_curr_instance   => lv_curr_instance,
                                      pv_prod_instance   => lv_prod_instance);

        IF lv_prod_flag = 'N'
        THEN
            -- If not prod, use the QA server; ex: http://siqa.ce-cs.com:3080/
            RETURN fnd_profile.VALUE ('XXCMN_QA_EDI_SERVER');
        ELSE
            -- This is prod, use the PROD server; ex: http://si.ce-cs.com:3080/
            RETURN fnd_profile.VALUE ('XXCMN_PROD_EDI_SERVER');
        END IF;
    END get_edi_server_url;

    --------------------------------------------------------------------------
    -- TYPE        : Function                                               --
    -- NAME        : get_edi_server_url                                     --
    -- PARAMETERS  : pv_uri_profile_name                                    --
    --               This is an overload function returns the edi server url--
    -- Modification History                                              --
    --------------------------------------------------------------------------
    -- Date      Developer      Version      Description                    --
    -- ----------   -----------     ------------    --------------------------
    -- 09/20/2013   Debbi        1.0          Initial Version               --
    --------------------------------------------------------------------------
    FUNCTION get_edi_server_url (
        pv_uri_profile_name   IN apps.fnd_profile_options.profile_option_name%TYPE)
        RETURN VARCHAR2
    AS
    BEGIN
        RETURN get_edi_server_url || fnd_profile.VALUE (pv_uri_profile_name);
    END get_edi_server_url;
END xxdo_common_pkg;
/
