--
-- XXD_AR_AGING_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AR_AGING_RPT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_AR_AGING_RPT_PKG
    --  Design       : This package provides XML extract for Deckers Aging 4 Bucket by Brand Excel Report.
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                    Comments
    --  ======================================================================================
    --  05-Apr-2017     1.0        Gaurav Joshi          Intial Version 1.0
    --  13-Dec-2022     1.1        Kishan Reddy          Added paramter as sales channel
    --  ##########################################################
    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    gv_delimeter               VARCHAR2 (1) := '|';

    PROCEDURE print_log (pv_msg IN VARCHAR2)
    IS
        lv_msg   VARCHAR2 (4000);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, lv_msg);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unable to print log:' || SQLERRM);
    END print_log;

    FUNCTION remove_junk (p_input IN VARCHAR2)
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
    END remove_junk;

    PROCEDURE update_attributes (p_request_id IN NUMBER, p_as_of_date IN DATE, x_ret_message OUT VARCHAR2)
    IS
        l_last_date   VARCHAR2 (50);

        CURSOR c_get_data IS
            SELECT a.ROWID,
                   c.segment1 entity_uniq_ident,
                   c.segment6 account_number,
                   DECODE (
                       a.brand,
                       'ALL BRAND', '1000',
                       (SELECT flex_value
                          FROM fnd_flex_values_vl
                         WHERE     flex_value_set_id = 1015912
                               AND UPPER (description) = a.brand)) key3,
                   c.segment3 key4,
                   c.segment4 key5,
                   c.segment5 key6,
                   c.segment7 key7,
                   a.outstanding_amount sub_acct_balance
              FROM xxdo.xxd_ar_aging_extract_t a, gl_code_combinations c
             WHERE     1 = 1
                   AND a.request_id = p_request_id
                   AND a.code_combination_id = c.code_combination_id;
    BEGIN
        -- Period end date of the as of date
        SELECT LAST_DAY (p_as_of_date) INTO l_last_date FROM DUAL;

        FOR i IN c_get_data
        LOOP
            BEGIN
                UPDATE xxdo.xxd_ar_aging_extract_t
                   SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.Key3,
                       Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                       Key7 = i.Key7, Period_End_Date = l_last_date, Subledr_Rep_Bal = NULL,
                       Subledr_alt_Bal = NULL, Subledr_Acc_Bal = i.sub_acct_balance
                 WHERE ROWID = i.ROWID AND request_id = p_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        ' Exception in Update Statment - ' || SQLERRM);
            END;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_attributes;

    PROCEDURE write_ar_recon_file (p_request_id NUMBER, p_file_path IN VARCHAR2, --p_operating_unit     IN     NUMBER,
                                                                                 x_ret_code OUT VARCHAR2
                                   , x_ret_message OUT VARCHAR2)
    IS
        CURSOR ar_reconcilation IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (Period_End_Date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || Subledr_alt_Bal || CHR (9) || SUM (Subledr_Acc_Bal)) line
                FROM xxdo.xxd_ar_aging_extract_t
               WHERE 1 = 1 AND request_id = p_request_id
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
    --ln_request_id             NUMBER := fnd_global.conc_request_id;
    BEGIN
        -- WRITE INTO BL FOLDER

        IF p_file_path IS NOT NULL
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
                       AND ffvl.description = 'ARAGING'
                       AND ffvl.flex_value = p_file_path;
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
                    FOR i IN ar_reconcilation
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
                    print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_ar_recon_file;

    PROCEDURE write_op_file (p_request_id IN NUMBER, p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, p_report_lvl IN VARCHAR2, p_bucket_type IN VARCHAR2, p_operating_unit IN NUMBER
                             , p_as_of_date IN VARCHAR2, x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR op_file_customer IS
              SELECT line
                FROM (SELECT 1 AS seq, remove_junk (customer_number) || gv_delimeter || remove_junk (customer_name) || gv_delimeter || outstanding_amount || gv_delimeter || aging_bucket1 || gv_delimeter || aging_bucket2 || gv_delimeter || aging_bucket3 || gv_delimeter || aging_bucket4 || gv_delimeter || aging_bucket5 || gv_delimeter || aging_bucket6 || gv_delimeter || aging_bucket7 || gv_delimeter || aging_bucket8 || gv_delimeter || aging_bucket9 line
                        FROM xxdo.xxd_ar_aging_extract_t, apps.ar_aging_buckets aab
                       WHERE     1 = 1
                             AND request_id = p_request_id
                             AND report_level = 'C'
                             AND aab.bucket_name = p_bucket_type /*UNION ALL
                                                                 SELECT 2 AS seq,
                                                                           'Customer_Number'
                                                                        || gv_delimeter
                                                                        || 'Customer_Name'
                                                                        || gv_delimeter
                                                                        || 'Outstanding_Amount'
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 0)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 1)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 2)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 3)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 4)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 5)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 6)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 7)
                                                                        || gv_delimeter
                                                                        || GET_BUCKET_DESC (aab.aging_bucket_id, 8)
                                                                           line
                                                                   FROM DUAL a, apps.ar_aging_buckets aab
                                                                  WHERE aab.bucket_name = p_bucket_type
                                                                    AND 1<>2*/
                                                                )
            ORDER BY 1 ASC;


        CURSOR op_file_invoice IS
              SELECT line
                FROM (SELECT 1 AS seq, remove_junk (brand) || gv_delimeter || remove_junk (customer_number) || gv_delimeter || remove_junk (customer_name) || gv_delimeter || remove_junk (invoice_number) || gv_delimeter || remove_junk (TYPE) || gv_delimeter || remove_junk (term_code) || gv_delimeter || invoice_date || gv_delimeter || outstanding_amount || gv_delimeter || aging_bucket1 || gv_delimeter || aging_bucket2 || gv_delimeter || aging_bucket3 || gv_delimeter || aging_bucket4 || gv_delimeter || aging_bucket5 || gv_delimeter || aging_bucket6 || gv_delimeter || aging_bucket7 || gv_delimeter || aging_bucket8 || gv_delimeter || aging_bucket9 line
                        FROM xxdo.xxd_ar_aging_extract_t, apps.ar_aging_buckets aab
                       WHERE     1 = 1
                             AND request_id = p_request_id
                             AND report_level = 'I'
                             AND aab.bucket_name = p_bucket_type --and customer_number = '5816474-UGG'
 /*UNION ALL
 SELECT 2 AS seq,
           'Brand'
        || gv_delimeter
        || 'Customer_Number'
        || gv_delimeter
        || 'Customer_Name'
        || gv_delimeter
        || 'Invoice_Number'
        || gv_delimeter
        || 'TYPE'
        || gv_delimeter
        || 'Term_Code'
        || gv_delimeter
        || 'Invoice_Date'
        || gv_delimeter
        || 'Outstanding_Amount'
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 0)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 1)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 2)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 3)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 4)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 5)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 6)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 7)
        || gv_delimeter
        || GET_BUCKET_DESC (aab.aging_bucket_id, 8)
           line
   FROM DUAL a, apps.ar_aging_buckets aab
  WHERE aab.bucket_name = p_bucket_type
    AND 1 <> 2*/
                     )
            ORDER BY 1 ASC;


        --DEFINE VARIABLES
        lv_file_path              VARCHAR2 (360);           -- := p_file_path;
        lv_file_name              VARCHAR2 (360);
        lv_file_dir               VARCHAR2 (1000);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);           -- := p_file_name;
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        lv_ou_short_name          VARCHAR2 (100);
        lv_period_name            VARCHAR2 (50);
        lv_bucket1                VARCHAR2 (100);
        lv_bucket2                VARCHAR2 (100);
        lv_bucket3                VARCHAR2 (100);
        lv_bucket4                VARCHAR2 (100);
        lv_bucket5                VARCHAR2 (100);
        lv_bucket6                VARCHAR2 (100);
        lv_bucket7                VARCHAR2 (100);
        lv_bucket8                VARCHAR2 (100);
        lv_bucket9                VARCHAR2 (100);
    --ln_request_id             NUMBER := fnd_global.conc_request_id;
    BEGIN
        -- WRITE INTO BL FOLDER

        --      FOR i IN write_ap_extract LOOP
        --                lv_line := i.line;
        --                fnd_file.put_line(fnd_file.output, lv_line);
        --      END LOOP;

        --      IF p_report_lvl = 'C'
        --      THEN
        --         FOR i IN op_file_customer
        --         LOOP
        --            lv_line := NULL;
        --            lv_line := i.line;
        --            fnd_file.put_line (fnd_file.output, lv_line);
        --         END LOOP;
        --      ELSE
        --         FOR i IN op_file_invoice
        --         LOOP
        --            lv_line := NULL;
        --            lv_line := i.line;
        --            fnd_file.put_line (fnd_file.output, lv_line);
        --         END LOOP;
        --      END IF;

        -- Get Bucket Values

        BEGIN
            SELECT GET_BUCKET_DESC (aab.aging_bucket_id, 0), GET_BUCKET_DESC (aab.aging_bucket_id, 1), GET_BUCKET_DESC (aab.aging_bucket_id, 2),
                   GET_BUCKET_DESC (aab.aging_bucket_id, 3), GET_BUCKET_DESC (aab.aging_bucket_id, 4), GET_BUCKET_DESC (aab.aging_bucket_id, 5),
                   GET_BUCKET_DESC (aab.aging_bucket_id, 6), GET_BUCKET_DESC (aab.aging_bucket_id, 7), GET_BUCKET_DESC (aab.aging_bucket_id, 8)
              INTO lv_bucket1, lv_bucket2, lv_bucket3, lv_bucket4,
                             lv_bucket5, lv_bucket6, lv_bucket7,
                             lv_bucket8, lv_bucket9
              FROM apps.ar_aging_buckets aab
             WHERE aab.bucket_name = p_bucket_type;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_bucket1   := NULL;
                lv_bucket2   := NULL;
                lv_bucket3   := NULL;
                lv_bucket4   := NULL;
                lv_bucket5   := NULL;
                lv_bucket6   := NULL;
                lv_bucket7   := NULL;
                lv_bucket8   := NULL;
                lv_bucket9   := NULL;
        END;

        -- WRITE INTO BL FOLDER
        IF p_file_path IS NOT NULL
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
                       AND ffvl.description = 'ARAGING'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

            -- query to fetch period name
            IF p_as_of_date IS NULL
            THEN
                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND ((SYSDATE)) BETWEEN start_date AND end_date;
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
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND (TO_DATE (p_as_of_date, 'YYYY/MM/DD HH24:MI:SS') BETWEEN start_date AND end_date);
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
                BEGIN
                    SELECT ffvl.attribute2
                      INTO lv_ou_short_name
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_AAR_OU_SHORTNAME_VS'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y'
                           AND ffvl.attribute1 = p_operating_unit;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_ou_short_name   := NULL;
                END;

                lv_file_dir   := lv_vs_file_path;
                lv_file_name   :=
                       lv_vs_file_name
                    || '_'
                    || lv_period_name
                    || '_'
                    || lv_ou_short_name
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
                    apps.fnd_file.put_line (fnd_file.LOG, 'File is Open');

                    IF p_report_lvl = 'C'
                    THEN
                        lv_line   :=
                               'Customer_Number'
                            || gv_delimeter
                            || 'Customer_Name'
                            || gv_delimeter
                            || 'Outstanding_Amount'
                            || gv_delimeter
                            || lv_bucket1
                            || gv_delimeter
                            || lv_bucket2
                            || gv_delimeter
                            || lv_bucket3
                            || gv_delimeter
                            || lv_bucket4
                            || gv_delimeter
                            || lv_bucket5
                            || gv_delimeter
                            || lv_bucket6
                            || gv_delimeter
                            || lv_bucket7
                            || gv_delimeter
                            || lv_bucket8
                            || gv_delimeter
                            || lv_bucket9;
                        UTL_FILE.put_line (lv_output_file, lv_line);

                        FOR i IN op_file_customer
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;
                    ELSE
                        lv_line   :=
                               'Brand'
                            || gv_delimeter
                            || 'Customer_Number'
                            || gv_delimeter
                            || 'Customer_Name'
                            || gv_delimeter
                            || 'Invoice_Number'
                            || gv_delimeter
                            || 'TYPE'
                            || gv_delimeter
                            || 'Term_Code'
                            || gv_delimeter
                            || 'Invoice_Date'
                            || gv_delimeter
                            || 'Outstanding_Amount'
                            || gv_delimeter
                            || lv_bucket1
                            || gv_delimeter
                            || lv_bucket2
                            || gv_delimeter
                            || lv_bucket3
                            || gv_delimeter
                            || lv_bucket4
                            || gv_delimeter
                            || lv_bucket5
                            || gv_delimeter
                            || lv_bucket6
                            || gv_delimeter
                            || lv_bucket7
                            || gv_delimeter
                            || lv_bucket8
                            || gv_delimeter
                            || lv_bucket9;
                        UTL_FILE.put_line (lv_output_file, lv_line);

                        FOR i IN op_file_invoice
                        LOOP
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;
                    END IF;
                ELSE
                    apps.fnd_file.put_line (fnd_file.LOG, 'File is not Open');
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the  data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
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
            print_log (lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_op_file;

    PROCEDURE generate_data (p_reporting_entity_id IN VARCHAR2, p_as_of_date IN VARCHAR2, p_summary_level IN VARCHAR2, p_credit_option IN VARCHAR2, p_show_risk_at_risk IN VARCHAR2, p_bucket_type IN VARCHAR2, p_curr_code IN VARCHAR2, p_file_path IN VARCHAR2, p_called_from IN VARCHAR2
                             , p_sales_channel IN VARCHAR2)
    AS
        ld_as_of_date    DATE := fnd_date.canonical_to_date (p_as_of_date);

        CURSOR fecth_ar_aging_invoice IS
            SELECT brand,
                   customer_name_inv,
                   customer_number_inv,
                   invnum,
                   invoice_type_inv,
                   term_code,
                   invoice_date,
                   (DECODE (CLASS_INV, 'PMT', NVL (amt_due_remaining_inv, 0), ((NVL (L_amount_applied_late, 0) - NVL (l_adjustment_amount, 0) + NVL (amt_due_remaining_inv, 0)))))
                       outstanding_amount,
                   days_past_due_inv,
                   NVL (
                       (SELECT 0
                          FROM ar_aging_bucket_lines a, ar_aging_buckets b
                         WHERE     1 = 1
                               AND a.aging_bucket_id = b.aging_bucket_id
                               AND bucket_name = 'DO US Disp 4Bkt'
                               AND bucket_name = P_BUCKET_TYPE
                               AND days_start IS NULL
                               AND NVL (amount_in_dispute, 0) <> 0),
                       (SELECT bucket_sequence_num
                          FROM ar_aging_bucket_lines a, ar_aging_buckets b
                         WHERE     1 = 1
                               AND a.aging_bucket_id = b.aging_bucket_id
                               AND bucket_name = P_BUCKET_TYPE
                               AND days_past_due_inv BETWEEN days_start
                                                         AND days_to))
                       bucket_sequence,
                   code_combination_id
              FROM (SELECT CASE
                               WHEN (a.amount_applied_inv IS NOT NULL)
                               THEN
                                   (SELECT NVL (SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                   'Y', (DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', ra.acctd_amount_applied_from, ra.acctd_amount_applied_to), ra.acctd_amount_applied_to) + NVL (ra.acctd_earned_discount_taken, 0) + NVL (ra.acctd_unearned_discount_taken, 0)), (ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', -1, 1), 1)), 0)
                                      FROM ar_receivable_applications_ALL ra, ar_payment_schedules_ALL ps
                                     WHERE     (ra.applied_payment_schedule_id = a.payment_sched_id_inv OR ra.payment_schedule_id = a.payment_sched_id_inv)
                                           AND ra.status || '' IN
                                                   ('APP', 'ACTIVITY')
                                           AND NVL (ra.confirmed_flag, 'Y') =
                                               'Y'
                                           AND ra.gl_date + 0 >
                                               TO_DATE (ld_as_of_date,
                                                        'DD-MON-YY')
                                           AND ps.payment_schedule_id =
                                               a.payment_sched_id_inv)
                               WHEN (a.amount_applied_inv IS NULL AND A.amount_credited_inv IS NOT NULL)
                               THEN
                                   (SELECT NVL (SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                   'Y', (DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', ra.acctd_amount_applied_from, ra.acctd_amount_applied_to), ra.acctd_amount_applied_to) + NVL (ra.acctd_earned_discount_taken, 0) + NVL (ra.acctd_unearned_discount_taken, 0)), (ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', -1, 1), 1)), 0)
                                      FROM ar_receivable_applications_ALL ra, ar_payment_schedules_ALL ps
                                     WHERE     (ra.applied_payment_schedule_id = a.payment_sched_id_inv OR ra.payment_schedule_id = a.payment_sched_id_inv)
                                           AND ra.status || '' IN
                                                   ('APP', 'ACTIVITY')
                                           AND NVL (ra.confirmed_flag, 'Y') =
                                               'Y'
                                           AND ra.gl_date + 0 >
                                               TO_DATE (ld_as_of_date,
                                                        'DD-MON-YY')
                                           AND ps.payment_schedule_id =
                                               a.payment_sched_id_inv)
                           END L_amount_applied_late,
                           CASE
                               WHEN amount_adjusted_inv IS NOT NULL
                               THEN
                                   (SELECT SUM (NVL (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                   'Y', acctd_amount, amount), 0))
                                      FROM ar_adjustments_ALL adj
                                     WHERE     gl_date >
                                               TO_DATE (ld_as_of_date,
                                                        'DD-MON-YY')
                                           AND payment_schedule_id =
                                               a.payment_sched_id_inv
                                           AND status = 'A')
                           END l_adjustment_amount,
                           A.*
                      FROM (SELECT term.name term_code, trx.trx_date invoice_date, NVL (trx.attribute5, cust_acct.ATTRIBUTE1) brand,
                                   trx.customer_trx_id invoice_id, ps.org_id invoice_org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))) customer_name_inv,
                                   cust_acct.cust_account_id customer_id_inv, cust_acct.account_number customer_number_inv, RTRIM (RPAD (trx.purchase_order, 12)) reference_number,
                                   ps.payment_schedule_id payment_sched_id_inv, ps.class class_inv, ps.due_date due_date_inv,
                                   DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                 'Y', ps.acctd_amount_due_remaining, ps.amount_due_remaining) amt_due_remaining_inv, DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                                                                                                                                   'Y', ROUND ((ps.amount_due_original * NVL (ps.exchange_rate, 1)), NULL --:func_curr_precision
                                                                                                                                                                                                                                                                                         ), ps.amount_due_original) amt_due_original_inv, ps.trx_number invnum,
                                   types.name invoice_type_inv, CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date) days_past_due_inv, ps.amount_adjusted amount_adjusted_inv,
                                   ps.amount_applied amount_applied_inv, ps.amount_credited amount_credited_inv, ps.gl_date gl_date_inv,
                                   cc.code_combination_id, ps.amount_in_dispute
                              FROM ra_terms term, ra_cust_trx_types_all types, hz_cust_accounts cust_acct,
                                   hz_parties party, ar_payment_schedules_all ps, ra_customer_trx_all trx,
                                   hz_cust_site_uses_all site, hz_cust_acct_sites_all addr, hz_party_sites party_site,
                                   hz_locations loc, ra_cust_trx_line_gl_dist_all gld, gl_code_combinations cc
                             WHERE     TRUNC (ps.gl_date) <=
                                       TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   AND ps.invoice_currency_code =
                                       NVL (UPPER (p_curr_code),
                                            ps.invoice_currency_code)
                                   AND ps.customer_trx_id + 0 =
                                       trx.customer_trx_id
                                   AND ps.customer_id =
                                       cust_acct.cust_account_id
                                   AND cust_acct.party_id = party.party_id
                                   AND ps.cust_trx_type_id =
                                       types.cust_trx_type_id
                                   --  AND TRX.TRX_NUMBER = NVL (:trx_num, TRX.TRX_NUMBER)
                                   AND NVL (ps.org_id, -99) =
                                       NVL (types.org_id, -99)
                                   AND ps.customer_site_use_id + 0 =
                                       site.site_use_id(+)
                                   AND site.cust_acct_site_id =
                                       addr.cust_acct_site_id(+)
                                   AND addr.party_site_id =
                                       party_site.party_site_id(+)
                                   AND loc.location_id(+) =
                                       party_site.location_id
                                   AND ps.gl_date_closed >
                                       TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   AND term.term_id(+) = trx.term_id
                                   AND ps.customer_trx_id + 0 =
                                       gld.customer_trx_id
                                   AND gld.account_class = 'REC'
                                   AND gld.latest_rec_flag = 'Y'
                                   AND gld.code_combination_id =
                                       cc.code_combination_id
                                   AND NVL (types.org_id,
                                            p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND NVL (ps.org_id, p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND NVL (addr.org_id,
                                            p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND NVL (gld.org_id,
                                            p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND (p_reporting_entity_id = ps.org_id)
                                   AND cust_acct.sales_channel_code =
                                       NVL (p_sales_channel,
                                            cust_acct.sales_channel_code)
                            UNION ALL
                              SELECT term.name term_code, ps.trx_date invoice_date, cust_acct.ATTRIBUTE1 brand,
                                     ps.cash_receipt_id invoice_id, ps.org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))),
                                     NVL (cust_acct.cust_account_id, -999), cust_acct.account_number, NULL,
                                     ps.payment_schedule_id, ps.class, ps.due_date,
                                     -SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                         'Y', app.acctd_amount_applied_from, app.amount_applied)), ps.amount_due_original, ps.trx_number invnum,
                                     DECODE (app.applied_payment_schedule_id, -4, 'Trade Management Claim', 'Payment'), --NULL,
                                                                                                                        CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date), ps.amount_adjusted,
                                     ps.amount_applied, ps.amount_credited, ps.gl_date,
                                     cc.code_combination_id, ps.amount_in_dispute
                                FROM ar_payment_schedules_all ps, ar_receivable_applications_all app, gl_code_combinations cc,
                                     hz_cust_accounts cust_acct, hz_parties party, hz_cust_site_uses_all site,
                                     hz_cust_acct_sites_all addr, hz_party_sites party_site, hz_locations loc,
                                     ra_terms term
                               WHERE     term.term_id(+) = ps.term_id
                                     --  AND ps.TRX_NUMBER = NVL (:trx_num, ps.TRX_NUMBER)
                                     AND app.gl_date <=
                                         TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                     AND ps.invoice_currency_code =
                                         NVL (UPPER (p_curr_code),
                                              ps.invoice_currency_code)
                                     AND ps.customer_id =
                                         cust_acct.cust_account_id(+)
                                     AND cust_acct.party_id = party.party_id(+)
                                     AND ps.cash_receipt_id + 0 =
                                         app.cash_receipt_id
                                     AND ps.customer_site_use_id + 0 =
                                         site.site_use_id(+)
                                     AND site.cust_acct_site_id =
                                         addr.cust_acct_site_id(+)
                                     AND addr.party_site_id =
                                         party_site.party_site_id(+)
                                     AND loc.location_id(+) =
                                         party_site.location_id
                                     AND app.code_combination_id =
                                         cc.code_combination_id
                                     AND app.status IN ('ACC', 'UNAPP', 'UNID',
                                                        'OTHER ACC')
                                     AND NVL (app.confirmed_flag, 'Y') = 'Y'
                                     AND ps.gl_date_closed >
                                         TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                     AND ((app.reversal_gl_date IS NOT NULL AND ps.gl_date <= TO_DATE (ld_as_of_date, 'DD-MON-YY')) OR app.reversal_gl_date IS NULL)
                                     AND NVL (ps.receipt_confirmed_flag, 'Y') =
                                         'Y'
                                     AND NVL (ps.org_id, P_REPORTING_ENTITY_ID) =
                                         P_REPORTING_ENTITY_ID
                                     AND NVL (app.org_id,
                                              P_REPORTING_ENTITY_ID) =
                                         P_REPORTING_ENTITY_ID
                                     AND NVL (addr.org_id,
                                              P_REPORTING_ENTITY_ID) =
                                         P_REPORTING_ENTITY_ID
                                     AND (P_REPORTING_ENTITY_ID = ps.org_id)
                                     AND cust_acct.sales_channel_code =
                                         NVL (p_sales_channel,
                                              cust_acct.sales_channel_code)
                            GROUP BY term.name, ps.trx_date, cust_acct.ATTRIBUTE1,
                                     ps.cash_receipt_id, ps.org_id, party.party_name,
                                     site.site_use_id, loc.state, loc.city,
                                     addr.cust_acct_site_id, cust_acct.cust_account_id, cust_acct.account_number,
                                     ps.payment_schedule_id, ps.class, ps.due_date,
                                     ps.amount_due_original, ps.trx_number, ps.amount_adjusted,
                                     ps.amount_applied, ps.amount_credited, ps.gl_date,
                                     ps.amount_in_dispute, ps.amount_adjusted_pending, ps.invoice_currency_code,
                                     ps.exchange_rate, DECODE (app.status, 'UNID', 'UNID', 'UNAPP'), app.applied_payment_schedule_id,
                                     cc.code_combination_id
                            UNION ALL
                            SELECT term.name term_code, ps.trx_date invoice_date, cust_acct.ATTRIBUTE1 brand,
                                   ps.cash_receipt_id invoice_id, ps.org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))),
                                   cust_acct.cust_account_id, cust_acct.account_number, NULL,
                                   ps.payment_schedule_id, NULL, ps.due_date,
                                   DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                 'Y', crh.acctd_amount, crh.amount), DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                                                                                   'Y', ROUND ((ps.amount_due_original * NVL (ps.exchange_rate, 1)), NULL -- :func_curr_precision
                                                                                                                                                                                                                                         ), ps.amount_due_original), ps.trx_number,
                                   'Risk', CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date), ps.amount_adjusted,
                                   ps.amount_applied, ps.amount_credited, crh.gl_date,
                                   cc.code_combination_id, ps.amount_in_dispute
                              FROM ra_terms term, hz_cust_accounts cust_acct, hz_parties party,
                                   ar_payment_schedules_all ps, hz_cust_site_uses_all site, hz_cust_acct_sites_all addr,
                                   hz_party_sites party_site, hz_locations loc, ar_cash_receipts_all cr,
                                   ar_cash_receipt_history_all crh, gl_code_combinations cc
                             WHERE     term.term_id(+) = ps.term_id
                                   AND TRUNC (crh.gl_date) <=
                                       TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   AND ps.invoice_currency_code =
                                       NVL (UPPER (p_curr_code),
                                            ps.invoice_currency_code)
                                   AND ps.trx_number IS NOT NULL
                                   --  AND ps.TRX_NUMBER = NVL (:trx_num, ps.TRX_NUMBER)
                                   AND UPPER (P_SHOW_RISK_AT_RISK) != 'NONE'
                                   AND ps.customer_id =
                                       cust_acct.cust_account_id(+)
                                   AND cust_acct.party_id = party.party_id(+)
                                   AND ps.cash_receipt_id =
                                       cr.cash_receipt_id
                                   AND cr.cash_receipt_id =
                                       crh.cash_receipt_id
                                   AND crh.account_code_combination_id =
                                       cc.code_combination_id
                                   AND ps.customer_site_use_id =
                                       site.site_use_id(+)
                                   AND site.cust_acct_site_id =
                                       addr.cust_acct_site_id(+)
                                   AND addr.party_site_id =
                                       party_site.party_site_id(+)
                                   AND loc.location_id(+) =
                                       party_site.location_id
                                   AND (crh.current_record_flag = 'Y' OR crh.reversal_gl_date > TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                   AND crh.status NOT IN
                                           (DECODE (crh.factor_flag,  'Y', 'RISK_ELIMINATED',  'N', 'CLEARED'), 'REVERSED')
                                   AND NOT EXISTS
                                           (SELECT 'x'
                                              FROM ar_receivable_applications_all ra
                                             WHERE     ra.cash_receipt_id =
                                                       cr.cash_receipt_id
                                                   AND ra.status = 'ACTIVITY'
                                                   AND applied_payment_schedule_id =
                                                       -2)
                                   AND NVL (ps.org_id, p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND NVL (addr.org_id,
                                            p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND NVL (cr.org_id, p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND NVL (crh.org_id,
                                            p_reporting_entity_id) =
                                       p_reporting_entity_id
                                   AND (p_reporting_entity_id = ps.org_id)
                                   AND cust_acct.sales_channel_code =
                                       NVL (p_sales_channel,
                                            cust_acct.sales_channel_code)
                            UNION ALL
                            SELECT term.name term_code, trx.trx_date invoice_date, NVL (trx.attribute5, cust_acct.ATTRIBUTE1) brand,
                                   trx.customer_trx_id invoice_id, ps.org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))) customer_name_inv,
                                   cust_acct.cust_account_id customer_id_inv, cust_acct.account_number customer_number_inv, NULL,
                                   ps.payment_schedule_id payment_sched_id_inv, ps.class class_inv, ps.due_date due_date_inv,
                                   DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                 'Y', ps.acctd_amount_due_remaining, ps.amount_due_remaining) amt_due_remaining_inv, DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                                                                                                                                   'Y', ROUND ((ps.amount_due_original * NVL (ps.exchange_rate, 1)), NULL --:func_curr_precision
                                                                                                                                                                                                                                                                                         ), ps.amount_due_original) amt_due_original_inv, ps.trx_number invnum,
                                   types.name invoice_type_inv, CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date) days_past_due_inv, ps.amount_adjusted amount_adjusted_inv,
                                   ps.amount_applied amount_applied_inv, ps.amount_credited amount_credited_inv, ps.gl_date gl_date_inv,
                                   cc.code_combination_id, ps.amount_in_dispute
                              FROM ra_cust_trx_types_ALL types, hz_cust_accounts cust_acct, hz_parties party,
                                   ar_payment_schedules_all ps, ra_customer_trx_all trx, hz_cust_site_uses_ALL site,
                                   hz_cust_acct_sites_ALL addr, hz_party_sites party_site, hz_locations loc,
                                   ar_transaction_history th, ar_distributions_all dist, gl_code_combinations cc,
                                   ra_terms term
                             WHERE     term.term_id(+) = trx.term_id
                                   AND TRUNC (ps.gl_date) <=
                                       TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   AND ps.invoice_currency_code =
                                       NVL (UPPER (p_curr_code),
                                            ps.invoice_currency_code)
                                   AND ps.class = 'BR'
                                   AND ps.customer_trx_id + 0 =
                                       trx.customer_trx_id
                                   AND ps.customer_id =
                                       cust_acct.cust_account_id
                                   AND cust_acct.party_id = party.party_id
                                   AND ps.cust_trx_type_id =
                                       types.cust_trx_type_id
                                   AND NVL (ps.org_id, -99) =
                                       NVL (types.org_id, -99)
                                   AND ps.customer_site_use_id + 0 =
                                       site.site_use_id(+)
                                   AND site.cust_acct_site_id =
                                       addr.cust_acct_site_id(+)
                                   AND addr.party_site_id =
                                       party_site.party_site_id(+)
                                   AND loc.location_id(+) =
                                       party_site.location_id
                                   AND ps.gl_date_closed >
                                       TO_DATE (ld_as_of_date, 'DD-MON-YY')
                                   AND ps.customer_trx_id + 0 =
                                       th.customer_trx_id
                                   AND th.transaction_history_id =
                                       dist.source_id
                                   AND dist.source_table = 'TH'
                                   AND th.transaction_history_id =
                                       (SELECT MAX (transaction_history_id)
                                          FROM ar_transaction_history th2, ar_distributions_all dist2
                                         WHERE     th2.transaction_history_id =
                                                   dist2.source_id
                                               AND dist2.source_table = 'TH'
                                               AND th2.gl_date <=
                                                   TO_DATE (ld_as_of_date,
                                                            'DD-MON-YY')
                                               AND dist2.amount_dr
                                                       IS NOT NULL
                                               AND th2.customer_trx_id =
                                                   ps.customer_trx_id)
                                   AND dist.amount_dr IS NOT NULL
                                   AND dist.source_table_secondary IS NULL
                                   -- AND ps.TRX_NUMBER = NVL (:trx_num, ps.TRX_NUMBER)
                                   AND dist.code_combination_id =
                                       cc.code_combination_id
                                   AND cust_acct.sales_channel_code =
                                       NVL (p_sales_channel,
                                            cust_acct.sales_channel_code)
                                   AND NVL (types.org_id,
                                            P_REPORTING_ENTITY_ID) =
                                       P_REPORTING_ENTITY_ID
                                   AND NVL (ps.org_id, P_REPORTING_ENTITY_ID) =
                                       P_REPORTING_ENTITY_ID
                                   AND NVL (addr.org_id,
                                            P_REPORTING_ENTITY_ID) =
                                       P_REPORTING_ENTITY_ID
                                   AND (P_REPORTING_ENTITY_ID = ps.org_id)) A)
                   B;

        v_bulk_limit     NUMBER := 500;

        TYPE tb_rec IS TABLE OF fecth_ar_aging_invoice%ROWTYPE;

        CURSOR fecth_ar_aging_customer IS
              SELECT customer_name, customer_number, code_combination_id,
                     bucket_sequence, NVL (brand, 'ALL BRAND') brand, SUM (OUTSTANDING_AMOUNT) OUTSTANDING_AMOUNT
                FROM (SELECT brand,
                             customer_name_inv
                                 customer_name,
                             customer_number_inv
                                 customer_number,
                             invnum,
                             invoice_type_inv,
                             term_code,
                             invoice_date,
                             (DECODE (CLASS_INV, 'PMT', NVL (amt_due_remaining_inv, 0), ((NVL (L_amount_applied_late, 0) - NVL (l_adjustment_amount, 0) + NVL (amt_due_remaining_inv, 0)))))
                                 outstanding_amount,
                             days_past_due_inv,
                             NVL (
                                 (SELECT 0
                                    FROM ar_aging_bucket_lines a, ar_aging_buckets b
                                   WHERE     1 = 1
                                         AND a.aging_bucket_id =
                                             b.aging_bucket_id
                                         AND bucket_name = 'DO US Disp 4Bkt'
                                         AND bucket_name = P_BUCKET_TYPE
                                         AND days_start IS NULL
                                         AND NVL (amount_in_dispute, 0) <> 0),
                                 (SELECT bucket_sequence_num
                                    FROM ar_aging_bucket_lines a, ar_aging_buckets b
                                   WHERE     1 = 1
                                         AND a.aging_bucket_id =
                                             b.aging_bucket_id
                                         AND bucket_name = P_BUCKET_TYPE
                                         AND days_past_due_inv BETWEEN days_start
                                                                   AND days_to))
                                 bucket_sequence,
                             code_combination_id
                        FROM (SELECT CASE
                                         WHEN (a.amount_applied_inv IS NOT NULL)
                                         THEN
                                             (SELECT NVL (SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                             'Y', (DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', ra.acctd_amount_applied_from, ra.acctd_amount_applied_to), ra.acctd_amount_applied_to) + NVL (ra.acctd_earned_discount_taken, 0) + NVL (ra.acctd_unearned_discount_taken, 0)), (ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', -1, 1), 1)), 0)
                                                FROM ar_receivable_applications_ALL ra, ar_payment_schedules_ALL ps
                                               WHERE     (ra.applied_payment_schedule_id = a.payment_sched_id_inv OR ra.payment_schedule_id = a.payment_sched_id_inv)
                                                     AND ra.status || '' IN
                                                             ('APP', 'ACTIVITY')
                                                     AND NVL (
                                                             ra.confirmed_flag,
                                                             'Y') =
                                                         'Y'
                                                     AND ra.gl_date + 0 >
                                                         TO_DATE (
                                                             ld_as_of_date,
                                                             'DD-MON-YY')
                                                     AND ps.payment_schedule_id =
                                                         a.payment_sched_id_inv)
                                         WHEN (a.amount_applied_inv IS NULL AND A.amount_credited_inv IS NOT NULL)
                                         THEN
                                             (SELECT NVL (SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                             'Y', (DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', ra.acctd_amount_applied_from, ra.acctd_amount_applied_to), ra.acctd_amount_applied_to) + NVL (ra.acctd_earned_discount_taken, 0) + NVL (ra.acctd_unearned_discount_taken, 0)), (ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', -1, 1), 1)), 0)
                                                FROM ar_receivable_applications_ALL ra, ar_payment_schedules_ALL ps
                                               WHERE     (ra.applied_payment_schedule_id = a.payment_sched_id_inv OR ra.payment_schedule_id = a.payment_sched_id_inv)
                                                     AND ra.status || '' IN
                                                             ('APP', 'ACTIVITY')
                                                     AND NVL (
                                                             ra.confirmed_flag,
                                                             'Y') =
                                                         'Y'
                                                     AND ra.gl_date + 0 >
                                                         TO_DATE (
                                                             ld_as_of_date,
                                                             'DD-MON-YY')
                                                     AND ps.payment_schedule_id =
                                                         a.payment_sched_id_inv)
                                     END L_amount_applied_late,
                                     CASE
                                         WHEN amount_adjusted_inv IS NOT NULL
                                         THEN
                                             (SELECT SUM (NVL (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                             'Y', acctd_amount, amount), 0))
                                                FROM ar_adjustments_ALL adj
                                               WHERE     gl_date >
                                                         TO_DATE (
                                                             ld_as_of_date,
                                                             'DD-MON-YY')
                                                     AND payment_schedule_id =
                                                         a.payment_sched_id_inv
                                                     AND status = 'A')
                                     END l_adjustment_amount,
                                     A.*
                                FROM (SELECT term.name term_code, trx.trx_date invoice_date, NVL (trx.attribute5, cust_acct.ATTRIBUTE1) brand,
                                             trx.customer_trx_id invoice_id, ps.org_id invoice_org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))) customer_name_inv,
                                             cust_acct.cust_account_id customer_id_inv, cust_acct.account_number customer_number_inv, RTRIM (RPAD (trx.purchase_order, 12)) reference_number,
                                             ps.payment_schedule_id payment_sched_id_inv, ps.class class_inv, ps.due_date due_date_inv,
                                             DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                           'Y', ps.acctd_amount_due_remaining, ps.amount_due_remaining) amt_due_remaining_inv, DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                                                                                                                                             'Y', ROUND ((ps.amount_due_original * NVL (ps.exchange_rate, 1)), NULL --:func_curr_precision
                                                                                                                                                                                                                                                                                                   ), ps.amount_due_original) amt_due_original_inv, ps.trx_number invnum,
                                             types.name invoice_type_inv, CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date) days_past_due_inv, ps.amount_adjusted amount_adjusted_inv,
                                             ps.amount_applied amount_applied_inv, ps.amount_credited amount_credited_inv, ps.gl_date gl_date_inv,
                                             cc.code_combination_id, ps.amount_in_dispute
                                        FROM ra_terms term, ra_cust_trx_types_all types, hz_cust_accounts cust_acct,
                                             hz_parties party, ar_payment_schedules_all ps, ra_customer_trx_all trx,
                                             hz_cust_site_uses_all site, hz_cust_acct_sites_all addr, hz_party_sites party_site,
                                             hz_locations loc, ra_cust_trx_line_gl_dist_all gld, gl_code_combinations cc
                                       WHERE     TRUNC (ps.gl_date) <=
                                                 TO_DATE (ld_as_of_date,
                                                          'DD-MON-YY')
                                             AND ps.invoice_currency_code =
                                                 NVL (UPPER (p_curr_code),
                                                      ps.invoice_currency_code)
                                             AND ps.customer_trx_id + 0 =
                                                 trx.customer_trx_id
                                             AND ps.customer_id =
                                                 cust_acct.cust_account_id
                                             AND cust_acct.party_id =
                                                 party.party_id
                                             AND ps.cust_trx_type_id =
                                                 types.cust_trx_type_id
                                             --  AND TRX.TRX_NUMBER = NVL (:trx_num, TRX.TRX_NUMBER)
                                             AND NVL (ps.org_id, -99) =
                                                 NVL (types.org_id, -99)
                                             AND ps.customer_site_use_id + 0 =
                                                 site.site_use_id(+)
                                             AND site.cust_acct_site_id =
                                                 addr.cust_acct_site_id(+)
                                             AND addr.party_site_id =
                                                 party_site.party_site_id(+)
                                             AND loc.location_id(+) =
                                                 party_site.location_id
                                             AND ps.gl_date_closed >
                                                 TO_DATE (ld_as_of_date,
                                                          'DD-MON-YY')
                                             AND term.term_id(+) = trx.term_id
                                             AND ps.customer_trx_id + 0 =
                                                 gld.customer_trx_id
                                             AND gld.account_class = 'REC'
                                             AND gld.latest_rec_flag = 'Y'
                                             AND gld.code_combination_id =
                                                 cc.code_combination_id
                                             AND NVL (types.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND NVL (ps.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND NVL (addr.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND NVL (gld.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND (p_reporting_entity_id = ps.org_id)
                                             AND cust_acct.sales_channel_code =
                                                 NVL (
                                                     p_sales_channel,
                                                     cust_acct.sales_channel_code)
                                      UNION ALL
                                        SELECT term.name term_code, ps.trx_date invoice_date, cust_acct.ATTRIBUTE1 brand,
                                               ps.cash_receipt_id invoice_id, ps.org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))),
                                               NVL (cust_acct.cust_account_id, -999), cust_acct.account_number, NULL,
                                               ps.payment_schedule_id, ps.class, ps.due_date,
                                               -SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                   'Y', app.acctd_amount_applied_from, app.amount_applied)), ps.amount_due_original, ps.trx_number invnum,
                                               DECODE (app.applied_payment_schedule_id, -4, 'Trade Management Claim', 'Payment'), --NULL,
                                                                                                                                  CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date), ps.amount_adjusted,
                                               ps.amount_applied, ps.amount_credited, ps.gl_date,
                                               cc.code_combination_id, ps.amount_in_dispute
                                          FROM ar_payment_schedules_all ps, ar_receivable_applications_all app, gl_code_combinations cc,
                                               hz_cust_accounts cust_acct, hz_parties party, hz_cust_site_uses_all site,
                                               hz_cust_acct_sites_all addr, hz_party_sites party_site, hz_locations loc,
                                               ra_terms term
                                         WHERE     term.term_id(+) = ps.term_id
                                               --  AND ps.TRX_NUMBER = NVL (:trx_num, ps.TRX_NUMBER)
                                               AND app.gl_date <=
                                                   TO_DATE (ld_as_of_date,
                                                            'DD-MON-YY')
                                               AND ps.invoice_currency_code =
                                                   NVL (UPPER (p_curr_code),
                                                        ps.invoice_currency_code)
                                               AND ps.customer_id =
                                                   cust_acct.cust_account_id(+)
                                               AND cust_acct.party_id =
                                                   party.party_id(+)
                                               AND ps.cash_receipt_id + 0 =
                                                   app.cash_receipt_id
                                               AND ps.customer_site_use_id + 0 =
                                                   site.site_use_id(+)
                                               AND site.cust_acct_site_id =
                                                   addr.cust_acct_site_id(+)
                                               AND addr.party_site_id =
                                                   party_site.party_site_id(+)
                                               AND loc.location_id(+) =
                                                   party_site.location_id
                                               AND app.code_combination_id =
                                                   cc.code_combination_id
                                               AND app.status IN ('ACC', 'UNAPP', 'UNID',
                                                                  'OTHER ACC')
                                               AND NVL (app.confirmed_flag, 'Y') =
                                                   'Y'
                                               AND ps.gl_date_closed >
                                                   TO_DATE (ld_as_of_date,
                                                            'DD-MON-YY')
                                               AND ((app.reversal_gl_date IS NOT NULL AND ps.gl_date <= TO_DATE (ld_as_of_date, 'DD-MON-YY')) OR app.reversal_gl_date IS NULL)
                                               AND NVL (
                                                       ps.receipt_confirmed_flag,
                                                       'Y') =
                                                   'Y'
                                               AND NVL (ps.org_id,
                                                        P_REPORTING_ENTITY_ID) =
                                                   P_REPORTING_ENTITY_ID
                                               AND NVL (app.org_id,
                                                        P_REPORTING_ENTITY_ID) =
                                                   P_REPORTING_ENTITY_ID
                                               AND NVL (addr.org_id,
                                                        P_REPORTING_ENTITY_ID) =
                                                   P_REPORTING_ENTITY_ID
                                               AND (P_REPORTING_ENTITY_ID = ps.org_id)
                                               AND cust_acct.sales_channel_code =
                                                   NVL (
                                                       p_sales_channel,
                                                       cust_acct.sales_channel_code)
                                      GROUP BY term.name, ps.trx_date, cust_acct.ATTRIBUTE1,
                                               ps.cash_receipt_id, ps.org_id, party.party_name,
                                               site.site_use_id, loc.state, loc.city,
                                               addr.cust_acct_site_id, cust_acct.cust_account_id, cust_acct.account_number,
                                               ps.payment_schedule_id, ps.class, ps.due_date,
                                               ps.amount_due_original, ps.trx_number, ps.amount_adjusted,
                                               ps.amount_applied, ps.amount_credited, ps.gl_date,
                                               ps.amount_in_dispute, ps.amount_adjusted_pending, ps.invoice_currency_code,
                                               ps.exchange_rate, DECODE (app.status, 'UNID', 'UNID', 'UNAPP'), app.applied_payment_schedule_id,
                                               cc.code_combination_id
                                      UNION ALL
                                      SELECT term.name term_code, ps.trx_date invoice_date, cust_acct.ATTRIBUTE1 brand,
                                             ps.cash_receipt_id invoice_id, ps.org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))),
                                             cust_acct.cust_account_id, cust_acct.account_number, NULL,
                                             ps.payment_schedule_id, NULL, ps.due_date,
                                             DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                           'Y', crh.acctd_amount, crh.amount), DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                                                                                             'Y', ROUND ((ps.amount_due_original * NVL (ps.exchange_rate, 1)), NULL -- :func_curr_precision
                                                                                                                                                                                                                                                   ), ps.amount_due_original), ps.trx_number,
                                             'Risk', CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date), ps.amount_adjusted,
                                             ps.amount_applied, ps.amount_credited, crh.gl_date,
                                             cc.code_combination_id, ps.amount_in_dispute
                                        FROM ra_terms term, hz_cust_accounts cust_acct, hz_parties party,
                                             ar_payment_schedules_all ps, hz_cust_site_uses_all site, hz_cust_acct_sites_all addr,
                                             hz_party_sites party_site, hz_locations loc, ar_cash_receipts_all cr,
                                             ar_cash_receipt_history_all crh, gl_code_combinations cc
                                       WHERE     term.term_id(+) = ps.term_id
                                             AND TRUNC (crh.gl_date) <=
                                                 TO_DATE (ld_as_of_date,
                                                          'DD-MON-YY')
                                             AND ps.invoice_currency_code =
                                                 NVL (UPPER (p_curr_code),
                                                      ps.invoice_currency_code)
                                             AND ps.trx_number IS NOT NULL
                                             --  AND ps.TRX_NUMBER = NVL (:trx_num, ps.TRX_NUMBER)
                                             AND UPPER (P_SHOW_RISK_AT_RISK) !=
                                                 'NONE'
                                             AND ps.customer_id =
                                                 cust_acct.cust_account_id(+)
                                             AND cust_acct.party_id =
                                                 party.party_id(+)
                                             AND ps.cash_receipt_id =
                                                 cr.cash_receipt_id
                                             AND cr.cash_receipt_id =
                                                 crh.cash_receipt_id
                                             AND crh.account_code_combination_id =
                                                 cc.code_combination_id
                                             AND ps.customer_site_use_id =
                                                 site.site_use_id(+)
                                             AND site.cust_acct_site_id =
                                                 addr.cust_acct_site_id(+)
                                             AND addr.party_site_id =
                                                 party_site.party_site_id(+)
                                             AND loc.location_id(+) =
                                                 party_site.location_id
                                             AND (crh.current_record_flag = 'Y' OR crh.reversal_gl_date > TO_DATE (ld_as_of_date, 'DD-MON-YY'))
                                             AND crh.status NOT IN
                                                     (DECODE (crh.factor_flag,  'Y', 'RISK_ELIMINATED',  'N', 'CLEARED'), 'REVERSED')
                                             AND NOT EXISTS
                                                     (SELECT 'x'
                                                        FROM ar_receivable_applications_all ra
                                                       WHERE     ra.cash_receipt_id =
                                                                 cr.cash_receipt_id
                                                             AND ra.status =
                                                                 'ACTIVITY'
                                                             AND applied_payment_schedule_id =
                                                                 -2)
                                             AND NVL (ps.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND NVL (addr.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND NVL (cr.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND NVL (crh.org_id,
                                                      p_reporting_entity_id) =
                                                 p_reporting_entity_id
                                             AND (p_reporting_entity_id = ps.org_id)
                                             AND cust_acct.sales_channel_code =
                                                 NVL (
                                                     p_sales_channel,
                                                     cust_acct.sales_channel_code)
                                      UNION ALL
                                      SELECT term.name term_code, trx.trx_date invoice_date, NVL (trx.attribute5, cust_acct.ATTRIBUTE1) brand,
                                             trx.customer_trx_id invoice_id, ps.org_id, DECODE (party.party_name, NULL, '2', RTRIM (RPAD (SUBSTRB ('1' || party.party_name, 1, 50), 36))) customer_name_inv,
                                             cust_acct.cust_account_id customer_id_inv, cust_acct.account_number customer_number_inv, NULL,
                                             ps.payment_schedule_id payment_sched_id_inv, ps.class class_inv, ps.due_date due_date_inv,
                                             DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                           'Y', ps.acctd_amount_due_remaining, ps.amount_due_remaining) amt_due_remaining_inv, DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), -- rp_convert_flag
                                                                                                                                                                                                                             'Y', ROUND ((ps.amount_due_original * NVL (ps.exchange_rate, 1)), NULL --:func_curr_precision
                                                                                                                                                                                                                                                                                                   ), ps.amount_due_original) amt_due_original_inv, ps.trx_number invnum,
                                             types.name invoice_type_inv, CEIL (TO_DATE (ld_as_of_date, 'DD-MON-YY') - ps.due_date) days_past_due_inv, ps.amount_adjusted amount_adjusted_inv,
                                             ps.amount_applied amount_applied_inv, ps.amount_credited amount_credited_inv, ps.gl_date gl_date_inv,
                                             cc.code_combination_id, ps.amount_in_dispute
                                        FROM ra_cust_trx_types_ALL types, hz_cust_accounts cust_acct, hz_parties party,
                                             ar_payment_schedules_all ps, ra_customer_trx_all trx, hz_cust_site_uses_ALL site,
                                             hz_cust_acct_sites_ALL addr, hz_party_sites party_site, hz_locations loc,
                                             ar_transaction_history th, ar_distributions_all dist, gl_code_combinations cc,
                                             ra_terms term
                                       WHERE     term.term_id(+) = trx.term_id
                                             AND TRUNC (ps.gl_date) <=
                                                 TO_DATE (ld_as_of_date,
                                                          'DD-MON-YY')
                                             AND ps.invoice_currency_code =
                                                 NVL (UPPER (p_curr_code),
                                                      ps.invoice_currency_code)
                                             AND ps.class = 'BR'
                                             AND ps.customer_trx_id + 0 =
                                                 trx.customer_trx_id
                                             AND ps.customer_id =
                                                 cust_acct.cust_account_id
                                             AND cust_acct.party_id =
                                                 party.party_id
                                             AND ps.cust_trx_type_id =
                                                 types.cust_trx_type_id
                                             AND NVL (ps.org_id, -99) =
                                                 NVL (types.org_id, -99)
                                             AND ps.customer_site_use_id + 0 =
                                                 site.site_use_id(+)
                                             AND site.cust_acct_site_id =
                                                 addr.cust_acct_site_id(+)
                                             AND addr.party_site_id =
                                                 party_site.party_site_id(+)
                                             AND loc.location_id(+) =
                                                 party_site.location_id
                                             AND ps.gl_date_closed >
                                                 TO_DATE (ld_as_of_date,
                                                          'DD-MON-YY')
                                             AND ps.customer_trx_id + 0 =
                                                 th.customer_trx_id
                                             AND th.transaction_history_id =
                                                 dist.source_id
                                             AND dist.source_table = 'TH'
                                             AND th.transaction_history_id =
                                                 (SELECT MAX (transaction_history_id)
                                                    FROM ar_transaction_history th2, ar_distributions_all dist2
                                                   WHERE     th2.transaction_history_id =
                                                             dist2.source_id
                                                         AND dist2.source_table =
                                                             'TH'
                                                         AND th2.gl_date <=
                                                             TO_DATE (
                                                                 ld_as_of_date,
                                                                 'DD-MON-YY')
                                                         AND dist2.amount_dr
                                                                 IS NOT NULL
                                                         AND th2.customer_trx_id =
                                                             ps.customer_trx_id)
                                             AND dist.amount_dr IS NOT NULL
                                             AND dist.source_table_secondary
                                                     IS NULL
                                             -- AND ps.TRX_NUMBER = NVL (:trx_num, ps.TRX_NUMBER)
                                             AND dist.code_combination_id =
                                                 cc.code_combination_id
                                             AND NVL (types.org_id,
                                                      P_REPORTING_ENTITY_ID) =
                                                 P_REPORTING_ENTITY_ID
                                             AND NVL (ps.org_id,
                                                      P_REPORTING_ENTITY_ID) =
                                                 P_REPORTING_ENTITY_ID
                                             AND cust_acct.sales_channel_code =
                                                 NVL (
                                                     p_sales_channel,
                                                     cust_acct.sales_channel_code)
                                             AND NVL (addr.org_id,
                                                      P_REPORTING_ENTITY_ID) =
                                                 P_REPORTING_ENTITY_ID
                                             AND (P_REPORTING_ENTITY_ID = ps.org_id))
                                     A) B)
            GROUP BY customer_name, customer_number, bucket_sequence,
                     brand, code_combination_id;

        --      CURSOR fecth_ar_aging_customer
        --      IS
        --           SELECT customer_name,
        --                  customer_number,
        --                  code_combination_id,
        --                  bucket_sequence,
        --                  NVL(brand,'ALL BRAND') brand,
        --                  SUM (OUTSTANDING_AMOUNT) OUTSTANDING_AMOUNT
        --             FROM (SELECT customer_name,
        --                          customer_number,
        --                          c_cust_bal (p_credit_option,
        --                                      P_SHOW_RISK_AT_RISK,
        --                                      class,
        --                                      c_amt_due_remaining,
        --                                      c_on_account_amount_cash,
        --                                      c_on_account_amount_credit,
        --                                      c_on_account_amount_risk)
        --                             OUTSTANDING_AMOUNT,
        --                          bucket_sequence,
        --                          brand,
        --                          code_combination_id
        --                     FROM (SELECT customer_name,
        --                                  customer_number,
        --                                  CASE
        --                                     WHEN     (UPPER (p_credit_option) =
        --                                                  'SUMMARY')
        --                                          AND (UPPER (class) = 'PMT')
        --                                     THEN
        --                                        c_amt_due_remaining
        --                                  END
        --                                     c_on_account_amount_cash,
        --                                  CASE
        --                                     WHEN     (UPPER (p_credit_option) =
        --                                                  'SUMMARY')
        --                                          AND (UPPER (class) = 'CM')
        --                                     THEN
        --                                        c_amt_due_remaining
        --                                  END
        --                                     c_on_account_amount_credit,
        --                                  CASE
        --                                     WHEN     (UPPER (P_SHOW_RISK_AT_RISK) =
        --                                                  'SUMMARY')
        --                                          AND (UPPER (class) = 'RISK')
        --                                     THEN
        --                                        c_amt_due_remaining
        --                                  END
        --                                     c_on_account_amount_risk,
        --                                  bucket_sequence,
        --                                  code_combination_id,
        --                                  c_amt_due_remaining,
        --                                  CLASS,
        --                                  brand
        --                             FROM (SELECT c_main_formula (p_credit_option,
        --                                                          class,
        --                                                          TYPE,
        --                                                          P_SHOW_RISK_AT_RISK,
        --                                                          amt_due_remaining,
        --                                                          amount_applied,
        --                                                          payment_sched_id,
        --                                                          ld_as_of_date,
        --                                                          amount_credited,
        --                                                          amount_adjusted,
        --                                                          p_curr_code)
        --                                             c_amt_due_remaining,
        --                                          NVL (
        --                                             (SELECT 0
        --                                                FROM ar_aging_bucket_lines a,
        --                                                     ar_aging_buckets b
        --                                               WHERE     1 = 1
        --                                                     AND a.aging_bucket_id =
        --                                                            b.aging_bucket_id
        --                                                     AND bucket_name = 'DO US Disp 4Bkt'
        --                                                     AND bucket_name = P_BUCKET_TYPE
        --                                                     AND days_start IS NULL
        --                                                     AND NVL (
        --                                                            amount_in_dispute,
        --                                                            0) <> 0),
        --                                             (SELECT bucket_sequence_num
        --                                                FROM ar_aging_bucket_lines a,
        --                                                     ar_aging_buckets b
        --                                               WHERE     1 = 1
        --                                                     AND a.aging_bucket_id =
        --                                                            b.aging_bucket_id
        --                                                     AND bucket_name =
        --                                                            P_BUCKET_TYPE
        --                                                     AND days_past_due BETWEEN days_start
        --                                                                           AND days_to))
        --                                             bucket_sequence,
        --                                          A.*
        --                                     FROM (SELECT ps.org_id customer_org_id,
        --                                                  1 cust_rec_count,
        --                                                  cust_acct.attribute1 brand,
        --                                                  RTRIM (
        --                                                     RPAD (
        --                                                        SUBSTRB (
        --                                                           party.party_name,
        --                                                           1,
        --                                                           50),
        --                                                        36))
        --                                                     customer_name,
        --                                                  cust_acct.cust_account_id
        --                                                     customer_id,
        --                                                  cust_acct.account_number
        --                                                     customer_number,
        --                                                  types.name TYPE,
        --                                                  ps.payment_schedule_id
        --                                                     payment_sched_id,
        --                                                  ps.class class,
        --                                                  ps.due_date due_date,
        --                                                  DECODE (
        --                                                     DECODE (p_curr_code,
        --                                                             NULL, 'Y',
        --                                                             'N'), --'Y',   --rp_convert_flag
        --                                                     'Y', ps.acctd_amount_due_remaining,
        --                                                     ps.amount_due_remaining)
        --                                                     amt_due_remaining,
        --                                                  ps.amount_due_original
        --                                                     amt_due_original,
        --                                                  CEIL (
        --                                                       TO_DATE (ld_as_of_date,
        --                                                                'DD-MON-YY')
        --                                                     - ps.due_date)
        --                                                     days_past_due,
        --                                                  ps.amount_adjusted
        --                                                     amount_adjusted,
        --                                                  ps.amount_applied
        --                                                     amount_applied,
        --                                                  ps.amount_credited
        --                                                     amount_credited,
        --                                                  ps.gl_date gl_date,
        --                                                  cc.code_combination_id,
        --                                                  ps.amount_in_dispute
        --                                             FROM ra_cust_trx_types_all types,
        --                                                  hz_cust_accounts cust_acct,
        --                                                  hz_parties party,
        --                                                  ar_payment_schedules_all ps,
        --                                                  ra_cust_trx_line_gl_dist_ALL gld,
        --                                                  gl_code_combinations cc
        --                                            WHERE     TRUNC (ps.gl_date) <=
        --                                                         TO_DATE (
        --                                                            ld_as_of_date,
        --                                                            'DD-MON-YY')
        --                                                  AND ps.customer_id =
        --                                                         cust_acct.cust_account_id
        --                                                  AND ps.invoice_currency_code =
        --                                                         NVL (
        --                                                            UPPER (p_curr_code),
        --                                                            ps.invoice_currency_code)
        --                                                  AND cust_acct.party_id =
        --                                                         party.party_id
        --                                                  AND ps.cust_trx_type_id =
        --                                                         types.cust_trx_type_id
        --                                                  AND NVL (ps.org_id, -99) =
        --                                                         NVL (types.org_id,
        --                                                              -99)
        --                                                  AND ps.gl_date_closed >
        --                                                         TO_DATE (
        --                                                            ld_as_of_date,
        --                                                            'DD-MON-YY')
        --                                                  AND ps.customer_trx_id + 0 =
        --                                                         gld.customer_trx_id
        --                                                  AND gld.account_class = 'REC'
        --                                                  AND gld.latest_rec_flag = 'Y'
        --                                                  AND gld.code_combination_id =
        --                                                         cc.code_combination_id
        --                                                  AND NVL (
        --                                                         ps.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND NVL (
        --                                                         types.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND NVL (
        --                                                         gld.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND (P_REPORTING_ENTITY_ID =
        --                                                          ps.org_id)
        --                                           UNION ALL
        --                                             SELECT ps.org_id,
        --                                                    1 cust_rec_count,
        --                                                    cust_acct.attribute1 brand,
        --                                                    RTRIM (
        --                                                       RPAD (
        --                                                          SUBSTRB (
        --                                                             party.party_name,
        --                                                             1,
        --                                                             50),
        --                                                          36))
        --                                                       customer_name,
        --                                                    NVL (
        --                                                       cust_acct.cust_account_id,
        --                                                       -999)
        --                                                       customer_id,
        --                                                    cust_acct.account_number
        --                                                       customer_number,
        --                                                    DECODE (
        --                                                       app.applied_payment_schedule_id,
        --                                                       -4, 'TRADE MANAGEMENT CLAIM',
        --                                                       'PAYMENT')
        --                                                       TYPE,
        --                                                    ps.payment_schedule_id
        --                                                       payment_sched_id,
        --                                                    ps.class class,
        --                                                    ps.due_date due_date,
        --                                                    -SUM (
        --                                                        DECODE (
        --                                                           DECODE (p_curr_code,
        --                                                                   NULL, 'Y',
        --                                                                   'N'), --'Y', --rp_convert_flag
        --                                                           'Y', app.acctd_amount_applied_from,
        --                                                           app.amount_applied))
        --                                                       amt_due_remaining,
        --                                                    ps.amount_due_original
        --                                                       amt_due_original,
        --                                                    CEIL (
        --                                                         TO_DATE (ld_as_of_date,
        --                                                                  'DD-MON-YY')
        --                                                       - ps.due_date)
        --                                                       days_past_due,
        --                                                    ps.amount_adjusted
        --                                                       amount_adjusted,
        --                                                    ps.amount_applied
        --                                                       amount_applied,
        --                                                    ps.amount_credited
        --                                                       amount_credited,
        --                                                    ps.gl_date gl_date,
        --                                                    cc.code_combination_id,
        --                                                    ps.amount_in_dispute
        --                                               FROM ar_payment_schedules_all ps,
        --                                                    ar_receivable_applications_ALL app,
        --                                                    gl_code_combinations cc,
        --                                                    hz_cust_accounts cust_acct,
        --                                                    hz_parties party
        --                                              WHERE     app.gl_date + 0 <=
        --                                                           TO_DATE (
        --                                                              ld_as_of_date,
        --                                                              'DD-MON-YY')
        --                                                    AND ps.invoice_currency_code =
        --                                                           NVL (
        --                                                              UPPER (p_curr_code),
        --                                                              ps.invoice_currency_code)
        --                                                    AND ps.customer_id =
        --                                                           cust_acct.cust_account_id(+)
        --                                                    AND cust_acct.party_id =
        --                                                           party.party_id(+)
        --                                                    AND ps.cash_receipt_id + 0 =
        --                                                           app.cash_receipt_id
        --                                                    AND app.code_combination_id =
        --                                                           cc.code_combination_id
        --                                                    AND app.status IN
        --                                                           ('ACC',
        --                                                            'UNAPP',
        --                                                            'UNID',
        --                                                            'OTHER ACC')
        --                                                    AND NVL (app.confirmed_flag,
        --                                                             'Y') = 'Y'
        --                                                    AND ps.gl_date_closed >
        --                                                           TO_DATE (
        --                                                              ld_as_of_date,
        --                                                              'DD-MON-YY')
        --                                                    AND (   (    app.reversal_gl_date
        --                                                                    IS NOT NULL
        --                                                             AND ps.gl_date <=
        --                                                                    TO_DATE (
        --                                                                       ld_as_of_date,
        --                                                                       'DD-MON-YY'))
        --                                                         OR app.reversal_gl_date
        --                                                               IS NULL)
        --                                                    AND NVL (
        --                                                           ps.receipt_confirmed_flag,
        --                                                           'Y') = 'Y'
        --                                                    AND NVL (
        --                                                           ps.org_id,
        --                                                           P_REPORTING_ENTITY_ID) =
        --                                                           P_REPORTING_ENTITY_ID
        --                                                    AND NVL (
        --                                                           app.org_id,
        --                                                           P_REPORTING_ENTITY_ID) =
        --                                                           P_REPORTING_ENTITY_ID
        --                                                    AND (P_REPORTING_ENTITY_ID =
        --                                                            ps.org_id)
        --                                           GROUP BY ps.org_id,
        --                                                    party.party_name,
        --                                                    cust_acct.account_number,
        --                                                    cust_acct.cust_account_id,
        --                                                    ps.payment_schedule_id,
        --                                                    app.applied_payment_schedule_id,
        --                                                    ps.due_date,
        --                                                    cust_acct.attribute1,
        --                                                    ps.amount_due_original,
        --                                                    ps.amount_adjusted,
        --                                                    ps.amount_applied,
        --                                                    ps.amount_credited,
        --                                                    ps.gl_date,
        --                                                    ps.amount_in_dispute,
        --                                                    ps.amount_adjusted_pending,
        --                                                    ps.invoice_currency_code,
        --                                                    ps.exchange_rate,
        --                                                    ps.class,
        --                                                    DECODE (app.status,
        --                                                            'UNID', 'UNID',
        --                                                            'UNAPP'),
        --                                                    cc.code_combination_id
        --                                           UNION ALL
        --                                           SELECT ps.org_id,
        --                                                  1 cust_rec_count,
        --                                                  cust_acct.attribute1 brand,
        --                                                  RTRIM (
        --                                                     RPAD (
        --                                                        SUBSTRB (
        --                                                           party.party_name,
        --                                                           1,
        --                                                           50),
        --                                                        36))
        --                                                     customer_name,
        --                                                  NVL (
        --                                                     cust_acct.cust_account_id,
        --                                                     -999)
        --                                                     customer_id,
        --                                                  cust_acct.account_number
        --                                                     customer_number,
        --                                                  'RISK' TYPE,
        --                                                  ps.payment_schedule_id
        --                                                     payment_sched_id,
        --                                                  'RISK' class,
        --                                                  ps.due_date due_date,
        --                                                  DECODE (
        --                                                     DECODE (p_curr_code,
        --                                                             NULL, 'Y',
        --                                                             'N'), --'Y',   --rp_convert_flag
        --                                                     'Y', crh.acctd_amount,
        --                                                     crh.amount)
        --                                                     amt_due_remaining,
        --                                                  ps.amount_due_original
        --                                                     amt_due_original,
        --                                                  CEIL (
        --                                                       TO_DATE (ld_as_of_date,
        --                                                                'DD-MON-YY')
        --                                                     - ps.due_date)
        --                                                     days_past_due,
        --                                                  ps.amount_adjusted
        --                                                     amount_adjusted,
        --                                                  ps.amount_applied
        --                                                     amount_applied,
        --                                                  ps.amount_credited
        --                                                     amount_credited,
        --                                                  crh.gl_date gl_date,
        --                                                  cc.code_combination_id,
        --                                                  ps.amount_in_dispute
        --                                             FROM hz_cust_accounts cust_acct,
        --                                                  hz_parties party,
        --                                                  ar_payment_schedules_all ps,
        --                                                  ar_cash_receipts_all cr,
        --                                                  ar_cash_receipt_history_all crh,
        --                                                  gl_code_combinations cc
        --                                            WHERE     crh.gl_date + 0 <=
        --                                                         TO_DATE (
        --                                                            ld_as_of_date,
        --                                                            'DD-MON-YY')
        --                                                  AND UPPER (
        --                                                         P_SHOW_RISK_AT_RISK) !=
        --                                                         'NONE'
        --                                                  AND ps.customer_id =
        --                                                         cust_acct.cust_account_id(+)
        --                                                  AND cust_acct.party_id =
        --                                                         party.party_id(+)
        --                                                  AND ps.cash_receipt_id =
        --                                                         cr.cash_receipt_id
        --                                                  AND cr.cash_receipt_id =
        --                                                         crh.cash_receipt_id
        --                                                  AND crh.account_code_combination_id =
        --                                                         cc.code_combination_id
        --                                                  AND (   crh.current_record_flag =
        --                                                             'Y'
        --                                                       OR crh.reversal_gl_date >
        --                                                             TO_DATE (
        --                                                                ld_as_of_date,
        --                                                                'DD-MON-YY'))
        --                                                  AND crh.status NOT IN
        --                                                         (DECODE (
        --                                                             crh.factor_flag,
        --                                                             'Y', 'RISK_ELIMINATED',
        --                                                             'N', 'CLEARED'),
        --                                                          'REVERSED')
        --                                                  AND NOT EXISTS
        --                                                             (SELECT 'x'
        --                                                                FROM ar_receivable_applications_ALL ra
        --                                                               WHERE     ra.cash_receipt_id =
        --                                                                            cr.cash_receipt_id
        --                                                                     AND ra.status =
        --                                                                            'ACTIVITY'
        --                                                                     AND applied_payment_schedule_id =
        --                                                                            -2)
        --                                                  AND NVL (
        --                                                         ps.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND NVL (
        --                                                         cr.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND NVL (
        --                                                         crh.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND (P_REPORTING_ENTITY_ID =
        --                                                          ps.org_id)
        --                                           UNION ALL
        --                                           SELECT ps.org_id,
        --                                                  1 cust_rec_count,
        --                                                  cust_acct.attribute1 brand,
        --                                                  RTRIM (
        --                                                     RPAD (
        --                                                        SUBSTRB (
        --                                                           party.party_name,
        --                                                           1,
        --                                                           50),
        --                                                        36))
        --                                                     customer_name,
        --                                                  cust_acct.cust_account_id
        --                                                     customer_id,
        --                                                  cust_acct.account_number
        --                                                     customer_number,
        --                                                  types.name TYPE,
        --                                                  ps.payment_schedule_id
        --                                                     payment_sched_id,
        --                                                  ps.class class,
        --                                                  ps.due_date due_date,
        --                                                  DECODE (
        --                                                     DECODE (p_curr_code,
        --                                                             NULL, 'Y',
        --                                                             'N'), --'Y',   --rp_convert_flag
        --                                                     'Y', ps.acctd_amount_due_remaining,
        --                                                     ps.amount_due_remaining)
        --                                                     amt_due_remaining,
        --                                                  ps.amount_due_original
        --                                                     amt_due_original,
        --                                                  CEIL (
        --                                                       TO_DATE (ld_as_of_date,
        --                                                                'DD-MON-YY')
        --                                                     - ps.due_date)
        --                                                     days_past_due,
        --                                                  ps.amount_adjusted
        --                                                     amount_adjusted,
        --                                                  ps.amount_applied
        --                                                     amount_applied,
        --                                                  ps.amount_credited
        --                                                     amount_credited,
        --                                                  ps.gl_date gl_date,
        --                                                  cc.code_combination_id,
        --                                                  ps.amount_in_dispute
        --                                             FROM ra_cust_trx_types_all types,
        --                                                  hz_cust_accounts cust_acct,
        --                                                  hz_parties party,
        --                                                  ar_payment_schedules_all ps,
        --                                                  ar_transaction_history th,
        --                                                  ar_distributions_all dist,
        --                                                  gl_code_combinations cc
        --                                            WHERE     TRUNC (ps.gl_date) <=
        --                                                         TO_DATE (
        --                                                            ld_as_of_date,
        --                                                            'DD-MON-YY')
        --                                                  AND ps.class = 'BR'
        --                                                  AND ps.invoice_currency_code =
        --                                                         NVL (
        --                                                            UPPER (p_curr_code),
        --                                                            ps.invoice_currency_code)
        --                                                  AND ps.customer_id =
        --                                                         cust_acct.cust_account_id
        --                                                  AND cust_acct.party_id =
        --                                                         party.party_id
        --                                                  AND ps.cust_trx_type_id =
        --                                                         types.cust_trx_type_id
        --                                                  AND NVL (ps.org_id, -99) =
        --                                                         NVL (types.org_id,
        --                                                              -99)
        --                                                  AND ps.gl_date_closed >
        --                                                         TO_DATE (
        --                                                            ld_as_of_date,
        --                                                            'DD-MON-YY')
        --                                                  AND ps.customer_trx_id + 0 =
        --                                                         th.customer_trx_id
        --                                                  AND th.transaction_history_id =
        --                                                         dist.source_id
        --                                                  AND dist.source_table = 'TH'
        --                                                  AND th.transaction_history_id =
        --                                                         (SELECT MAX (
        --                                                                    transaction_history_id)
        --                                                            FROM ar_transaction_history th2,
        --                                                                 ar_distributions_all dist2
        --                                                           WHERE     th2.transaction_history_id =
        --                                                                        dist2.source_id
        --                                                                 AND dist2.source_table =
        --                                                                        'TH'
        --                                                                 AND th2.gl_date <=
        --                                                                        TO_DATE (
        --                                                                           ld_as_of_date,
        --                                                                           'DD-MON-YY')
        --                                                                 AND dist2.amount_dr
        --                                                                        IS NOT NULL
        --                                                                 AND th2.customer_trx_id =
        --                                                                        ps.customer_trx_id)
        --                                                  AND dist.amount_dr
        --                                                         IS NOT NULL
        --                                                  AND dist.source_table_secondary
        --                                                         IS NULL
        --                                                  AND dist.code_combination_id =
        --                                                         cc.code_combination_id
        --                                                  AND NVL (
        --                                                         ps.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND NVL (
        --                                                         types.org_id,
        --                                                         P_REPORTING_ENTITY_ID) =
        --                                                         P_REPORTING_ENTITY_ID
        --                                                  AND (P_REPORTING_ENTITY_ID =
        --                                                          ps.org_id)) A) B) c) d
        --         GROUP BY customer_name,
        --                  customer_number,
        --                  bucket_sequence,
        --                  brand,
        --                  code_combination_id;

        TYPE tb_rec_cust IS TABLE OF fecth_ar_aging_customer%ROWTYPE;

        --Define a variable of that table type
        v_tb_rec         tb_rec;
        v_tb_rec_cust    tb_rec_cust;
        lv_file_name     VARCHAR2 (240)
            :=    'Sub_SL_AR_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';
        lv_ret_code      VARCHAR2 (30) := NULL;
        lv_ret_message   VARCHAR2 (2000) := NULL;
        l_count          NUMBER;
    BEGIN
        IF P_SUMMARY_LEVEL = 'I'
        THEN
            OPEN fecth_ar_aging_invoice;

            LOOP
                FETCH fecth_ar_aging_invoice
                    BULK COLLECT INTO v_tb_rec
                    LIMIT v_bulk_limit;

                BEGIN
                    FORALL i IN 1 .. v_tb_rec.COUNT
                        INSERT INTO xxdo.xxd_ar_aging_extract_t (
                                        request_id,
                                        report_level,
                                        brand,
                                        customer_number,
                                        customer_name,
                                        invoice_number,
                                        TYPE,
                                        term_code,
                                        invoice_date,
                                        outstanding_amount,
                                        creation_date,
                                        aging_bucket1,
                                        aging_bucket2,
                                        aging_bucket3,
                                        aging_bucket4,
                                        aging_bucket5,
                                        aging_bucket6,
                                        aging_bucket7,
                                        aging_bucket8,
                                        aging_bucket9,
                                        Code_combination_id)
                                 VALUES (
                                            gn_request_id,
                                            P_SUMMARY_LEVEL,
                                            NVL (v_tb_rec (i).brand,
                                                 'ALL BRAND'),
                                            v_tb_rec (i).customer_number_inv,
                                            v_tb_rec (i).customer_name_inv,
                                            v_tb_rec (i).invnum,
                                            v_tb_rec (i).invoice_type_inv,
                                            v_tb_rec (i).term_code,
                                            v_tb_rec (i).invoice_date,
                                            v_tb_rec (i).OUTSTANDING_AMOUNT,
                                            SYSDATE,
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '0', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '1', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '2', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '3', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '4', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '5', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '6', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '7', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec (i).bucket_sequence,
                                                '8', v_tb_rec (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            v_tb_rec (i).code_combination_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'insertion failed for  Table' || SQLERRM);
                END;

                COMMIT;
                EXIT WHEN fecth_ar_aging_invoice%NOTFOUND;
            END LOOP;
        ELSIF P_SUMMARY_LEVEL = 'C'
        THEN
            OPEN fecth_ar_aging_customer;

            LOOP
                FETCH fecth_ar_aging_customer
                    BULK COLLECT INTO v_tb_rec_cust
                    LIMIT v_bulk_limit;

                BEGIN
                    FORALL i IN 1 .. v_tb_rec_cust.COUNT
                        INSERT INTO xxdo.xxd_ar_aging_extract_t (
                                        request_id,
                                        report_level,
                                        brand,
                                        customer_number,
                                        customer_name,
                                        outstanding_amount,
                                        creation_date,
                                        aging_bucket1,
                                        aging_bucket2,
                                        aging_bucket3,
                                        aging_bucket4,
                                        aging_bucket5,
                                        aging_bucket6,
                                        aging_bucket7,
                                        aging_bucket8,
                                        aging_bucket9,
                                        code_combination_id)
                                 VALUES (
                                            gn_request_id,
                                            P_SUMMARY_LEVEL,
                                            v_tb_rec_cust (i).brand,
                                            v_tb_rec_cust (i).customer_number,
                                            v_tb_rec_cust (i).customer_name,
                                            v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                            SYSDATE,
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '0', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '1', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '2', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '3', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '4', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '5', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '6', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '7', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            DECODE (
                                                v_tb_rec_cust (i).bucket_sequence,
                                                '8', v_tb_rec_cust (i).OUTSTANDING_AMOUNT,
                                                NULL),
                                            v_tb_rec_cust (i).code_combination_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'insertion failed for  Table' || SQLERRM);
                END;

                COMMIT;
                EXIT WHEN fecth_ar_aging_customer%NOTFOUND;
            END LOOP;
        END IF;

        --- done with data load in the custom table. now create the o/p file into ar aging directory
        --      l_file_name :=
        --         'AR_AGING_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS') || '.txt';

        fnd_file.put_line (fnd_file.LOG,
                           ' Printing Parameters into write_op_file');
        fnd_file.put_line (fnd_file.LOG, ' ===================');
        fnd_file.put_line (fnd_file.LOG, ' Request ID - ' || gn_request_id);
        fnd_file.put_line (fnd_file.LOG, ' p_file_path - ' || p_file_path);
        fnd_file.put_line (fnd_file.LOG, ' lv_file_name - ' || lv_file_name);
        fnd_file.put_line (fnd_file.LOG,
                           ' p_summary_level - ' || p_summary_level);
        fnd_file.put_line (fnd_file.LOG, ' Bucket Type - ' || p_bucket_type);
        fnd_file.put_line (fnd_file.LOG,
                           ' Org Id - ' || p_reporting_entity_id);
        fnd_file.put_line (fnd_file.LOG, ' p_as_of_date - ' || p_as_of_date);
        fnd_file.put_line (fnd_file.LOG, ' lv_ret_code - ' || lv_ret_code);
        fnd_file.put_line (fnd_file.LOG,
                           ' lv_ret_message - ' || lv_ret_message);

        write_op_file (gn_request_id, p_file_path, lv_file_name,
                       p_summary_level, p_bucket_type, p_reporting_entity_id,
                       p_as_of_date, lv_ret_code, lv_ret_message);

        fnd_file.put_line (fnd_file.LOG,
                           ' Printing Parameters into Update Atts');
        fnd_file.put_line (fnd_file.LOG, ' ===================');
        fnd_file.put_line (fnd_file.LOG, ' Request ID - ' || gn_request_id);
        fnd_file.put_line (fnd_file.LOG,
                           ' lv_ret_message - ' || lv_ret_message);

        update_attributes (gn_request_id, ld_as_of_date, lv_ret_message);
    --      IF (P_CALLED_FROM = 'WRAPPER')
    --      THEN
    --         update_attributes (gn_request_id, ld_as_of_date, lv_ret_message);
    --
    --         SELECT COUNT (1)
    --           INTO l_count
    --           FROM dba_directories
    --          WHERE directory_name = P_FILE_PATH;
    --
    --         IF l_count = 1                      -- DIRECTORY PATH IS A VALID ONCE
    --         THEN
    --            IF lv_ret_message IS NULL
    --            THEN                      -- no error while udpating the attribute
    --               lv_file_name :=
    --                     'SUB_SL_AR_AGING_'
    --                  || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
    --                  || '.txt';
    --               write_ar_recon_file (gn_request_id,
    --                                    p_file_path,
    --                                    lv_file_name,
    --                                    lv_ret_code,
    --                                    lv_ret_message);
    --            ELSE -- error while udpating the attribute; put the messages in log file
    --               fnd_file.put_line (
    --                  fnd_file.LOG,
    --                  'Attribute update failed:-' || lv_ret_message);
    --            END IF;
    --         END IF;
    --      END IF;
    END generate_data;

    FUNCTION c_main_formula (p_credit_option     IN VARCHAR2,
                             class               IN VARCHAR2,
                             TYPE                IN VARCHAR2,
                             p_risk_option       IN VARCHAR2,
                             amt_due_remaining   IN NUMBER,
                             amount_applied      IN NUMBER,
                             payment_sched_id    IN NUMBER,
                             p_as_of_date        IN DATE,
                             amount_credited     IN NUMBER,
                             amount_adjusted     IN NUMBER,
                             p_curr_code         IN VARCHAR2)
        RETURN NUMBER
    IS
        l_inv_type                   VARCHAR2 (320);
        -- bug3863428 Modified declaration
        l_amount_applied_late        NUMBER := 0;
        l_adjustment_amount          NUMBER := 0;
        l_amt_due_remaining          NUMBER := 0;
        c_amt_due_remaining          NUMBER := 0;
        c_on_account_amount_cash     NUMBER := 0;
        c_on_account_amount_credit   NUMBER := 0;
        c_on_account_amount_risk     NUMBER := 0;
    BEGIN
        IF     UPPER (p_credit_option) = 'NONE'
           AND UPPER (class) IN ('PMT', 'CM')
        THEN
            --c_amt_due_remaining:=0;
            RETURN (c_amt_due_remaining);
        END IF;

        IF UPPER (p_risk_option) = 'NONE' AND UPPER (class) = 'RISK'
        THEN
            --c_amt_due_remaining:=0;
            RETURN (c_amt_due_remaining);
        END IF;

        c_amt_due_remaining   := NVL (amt_due_remaining, 0);

        IF UPPER (TYPE) NOT IN ('PAYMENT', 'RISK', 'TRADE MANAGEMENT CLAIM')
        THEN
            IF (amount_applied IS NOT NULL)
            THEN
                SELECT NVL (SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), --DECODE(p_curr_code,NULL,'Y','N'),---DECODE(p_curr_code,NULL,'N','Y'),
                                                                               'Y', (DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', ra.acctd_amount_applied_from, ra.acctd_amount_applied_to), ra.acctd_amount_applied_to) + NVL (ra.acctd_earned_discount_taken, 0) + NVL (ra.acctd_unearned_discount_taken, 0)), (ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', -1, 1), 1)), 0)
                  INTO l_amount_applied_late
                  FROM ar_receivable_applications_all ra, ar_payment_schedules_all ps
                 WHERE     (ra.applied_payment_schedule_id = payment_sched_id OR ra.payment_schedule_id = payment_sched_id)
                       AND ra.status || '' IN ('APP', 'ACTIVITY')
                       AND NVL (ra.confirmed_flag, 'Y') = 'Y'
                       AND ra.gl_date + 0 > p_as_of_date
                       AND ps.payment_schedule_id = payment_sched_id;
            END IF;

            IF (amount_applied IS NULL)
            THEN
                IF (amount_credited IS NOT NULL)
                THEN
                    SELECT NVL (SUM (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), --DECODE(p_curr_code,NULL,'Y','N'),--DECODE(p_curr_code,NULL,'N','Y'),
                                                                                   'Y', (DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', ra.acctd_amount_applied_from, ra.acctd_amount_applied_to), ra.acctd_amount_applied_to) + NVL (ra.acctd_earned_discount_taken, 0) + NVL (ra.acctd_unearned_discount_taken, 0)), (ra.amount_applied + NVL (ra.earned_discount_taken, 0) + NVL (ra.unearned_discount_taken, 0))) * DECODE (ps.class, 'CM', DECODE (ra.application_type, 'CM', -1, 1), 1)), 0)
                      INTO l_amount_applied_late
                      FROM ar_receivable_applications_all ra, ar_payment_schedules_all ps
                     WHERE     (ra.applied_payment_schedule_id = payment_sched_id OR ra.payment_schedule_id = payment_sched_id)
                           AND ra.status || '' IN ('APP', 'ACTIVITY')
                           AND NVL (ra.confirmed_flag, 'Y') = 'Y'
                           AND ra.gl_date + 0 > p_as_of_date
                           AND ps.payment_schedule_id = payment_sched_id;
                END IF;
            END IF;

            l_amt_due_remaining   := l_amount_applied_late;

            IF amount_adjusted IS NOT NULL
            THEN
                SELECT SUM (NVL (DECODE (DECODE (p_curr_code, NULL, 'Y', 'N'), 'Y', acctd_amount, amount), 0))
                  INTO l_adjustment_amount
                  FROM ar_adjustments_all adj
                 WHERE     gl_date > p_as_of_date
                       AND payment_schedule_id = payment_sched_id
                       AND status = 'A';

                l_amt_due_remaining   :=
                    l_amt_due_remaining - NVL (l_adjustment_amount, 0);
            END IF;

            c_amt_due_remaining   :=
                c_amt_due_remaining + l_amt_due_remaining;
        END IF;

        IF (UPPER (p_credit_option) = 'SUMMARY') AND (UPPER (class) = 'PMT')
        THEN
            --:c_on_account_amount_cash :=  :c_amt_due_remaining ;
            c_amt_due_remaining   := 0;
        ELSIF     (UPPER (p_credit_option) = 'SUMMARY')
              AND (UPPER (class) = 'CM')
        THEN
            -- :c_on_account_amount_credit := :c_amt_due_remaining ;
            c_amt_due_remaining   := 0;
        ELSIF     (SUBSTR (UPPER (p_risk_option), 1, 1) = 'S')
              AND (UPPER (class) = 'RISK')
        THEN
            NULL;      --:c_on_account_amount_risk   := :c_amt_due_remaining ;
            c_amt_due_remaining   := 0;
        END IF;

        RETURN c_amt_due_remaining;
    END;

    FUNCTION c_cust_bal (p_credit_option IN VARCHAR2, p_risk_option IN VARCHAR2, class IN VARCHAR2, c_amt_due_remaining NUMBER, c_on_account_amount_cash NUMBER, c_on_account_amount_credit NUMBER
                         , c_on_account_amount_risk NUMBER)
        RETURN NUMBER
    IS
        l_cust_bal   NUMBER;
    BEGIN
        l_cust_bal   := 0;


        IF     UPPER (p_credit_option) = 'SUMMARY'
           AND UPPER (class) IN ('PMT', 'CM')
        THEN
            IF UPPER (p_risk_option) = 'SUMMARY' AND UPPER (class) = 'RISK'
            THEN
                l_cust_bal   := 0;
            ELSE
                l_cust_bal   :=
                      NVL (c_amt_due_remaining, 0)
                    + NVL (c_on_account_amount_risk, 0);
            END IF;
        ELSE
            IF UPPER (p_risk_option) = 'SUMMARY' AND UPPER (class) = 'RISK'
            THEN
                l_cust_bal   :=
                      NVL (c_amt_due_remaining, 0)
                    + NVL (c_on_account_amount_cash, 0)
                    + NVL (c_on_account_amount_credit, 0);
            ELSE
                l_cust_bal   :=
                      NVL (c_amt_due_remaining, 0)
                    + NVL (c_on_account_amount_cash, 0)
                    + NVL (c_on_account_amount_credit, 0)
                    + NVL (c_on_account_amount_risk, 0);
            END IF;
        END IF;

        RETURN (l_cust_bal);
    END;

    FUNCTION get_bucket_desc (pn_aging_bucket_id   IN NUMBER,
                              pn_bucket_seq_num    IN NUMBER)
        RETURN VARCHAR2
    IS
        l_desc   VARCHAR2 (240);
    BEGIN
        SELECT report_heading1
          INTO l_desc
          FROM apps.ar_aging_bucket_lines aabl
         WHERE     1 = 1
               AND aabl.aging_bucket_id = pn_aging_bucket_id
               AND aabl.bucket_sequence_num = pn_bucket_seq_num;

        RETURN l_desc;
    EXCEPTION
        WHEN OTHERS
        THEN
            -- LOG ('Unable to get_bucket_desc ' || SQLERRM);
            RETURN NULL;
    END;

    PROCEDURE main_wrapper (p_errbuf                   OUT VARCHAR2,
                            p_retcode                  OUT VARCHAR2,
                            p_reporting_entity_id   IN     VARCHAR2,
                            p_as_of_date            IN     VARCHAR2,
                            p_summary_level         IN     VARCHAR2,
                            p_credit_option         IN     VARCHAR2,
                            p_show_risk_at_risk     IN     VARCHAR2,
                            p_bucket_type           IN     VARCHAR2,
                            p_curr_code             IN     VARCHAR2,
                            p_file_path             IN     VARCHAR2,
                            p_sales_channel         IN     VARCHAR2)
    IS
        lv_request_id         NUMBER;
        lc_phase              VARCHAR2 (50);
        lc_status             VARCHAR2 (50);
        lc_dev_phase          VARCHAR2 (50);
        lc_dev_status         VARCHAR2 (50);
        lc_message            VARCHAR2 (50);
        l_req_return_status   BOOLEAN;
        lc_req_data           VARCHAR2 (50);
        l_layout              BOOLEAN;
        l_line                VARCHAR2 (4000);
        l_result              BOOLEAN;

        CURSOR ar_reconcilation (v_request_id NUMBER)
        IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (Period_End_Date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || Subledr_alt_Bal || CHR (9) || SUM (Subledr_Acc_Bal)) line
                FROM xxdo.xxd_ar_aging_extract_t
               WHERE 1 = 1 AND request_id = v_request_id
            GROUP BY entity_uniq_identifier, Account_Number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, Period_End_Date, Subledr_Rep_Bal,
                     Subledr_alt_Bal;
    BEGIN
        generate_data (p_reporting_entity_id, p_as_of_date, p_summary_level,
                       p_credit_option, p_show_risk_at_risk, p_bucket_type,
                       p_curr_code, p_file_path, 'WRAPPER',
                       p_sales_channel);

        print_log (' Printing Parameters into write_ar_recon_file');
        print_log (' ===================');
        print_log (' Request ID - ' || gn_request_id);
        print_log (' p_file_path - ' || p_file_path);
        print_log (' lv_ret_code - ' || p_retcode);
        print_log (' lv_ret_message - ' || p_errbuf);

        write_ar_recon_file (gn_request_id, p_file_path, --p_reporting_entity_id,
                                                         p_retcode,
                             p_errbuf);

        /*
          l_layout :=
           apps.fnd_request.add_layout (
              template_appl_name   => 'XXDO',
              template_code        => 'XXD_AR_AGING_RPT',
              template_language    => 'en',
              template_territory   => 'US',
              output_format        => 'EXCEL');

        lv_request_id :=
           fnd_request.submit_request (
              application   => 'XXDO',
              program       => 'XXD_AR_AGING_RPT',
              description   => 'Deckers Aging 4 Bucket by Brand Excel Report',
              start_time    => SYSDATE,
              sub_request   => FALSE,
              argument1     => P_REPORTING_ENTITY_ID,
              argument2     => P_AS_OF_DATE,
              argument3     => P_SUMMARY_LEVEL,
              argument4     => P_CREDIT_OPTION,
              argument5     => P_SHOW_RISK_AT_RISK,
              argument6     => P_BUCKET_TYPE,
              argument7     => P_CURR_CODE,
              argument8     => P_FILE_PATH,
              argument9     => 'WRAPPER');
        COMMIT;

        IF lv_request_id = 0
        THEN
           fnd_file.put_line (
              fnd_file.LOG,
              'Request Not Submitted due to "' || fnd_message.get || '".');
        ELSE
           fnd_file.put_line (
              fnd_file.LOG,
                 'AR Aging Program submitted successfully ?Request id :'
              || lv_request_id);
        END IF;
        IF lv_request_id > 0
        THEN
           LOOP
              --
              --To make wrapper execution to wait for AR REPORT program to complete
              --
              l_req_return_status :=
                 fnd_concurrent.wait_for_request (request_id   => lv_request_id,
                                                  INTERVAL     => 60 --interval Number of seconds to wait between checks
                                                                    --,max_wait        => 60 --Maximum number of seconds to wait for the request completion
                                                                    -- out arguments
                                                  ,
                                                  phase        => lc_phase,
                                                  STATUS       => lc_status,
                                                  dev_phase    => lc_dev_phase,
                                                  dev_status   => lc_dev_status,
                                                  MESSAGE      => lc_message);

              EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                        OR UPPER (lc_status) IN
                              ('CANCELLED', 'ERROR', 'TERMINATED');
           END LOOP;
        END IF;
       -- copy the ar aging file o/p into thr respective direcotry


  */

        FOR i IN ar_reconcilation (gn_request_id)
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END main_wrapper;

    FUNCTION AfterReport (p_called_from IN VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_req_id   NUMBER;
        lb_result   BOOLEAN := TRUE;
    BEGIN
        NULL;
        /*
          if P_CALLED_FROM='WRAPPER' THEN


             ln_req_id :=
                fnd_request.submit_request (
                   application   => 'XDO',
                   program       => 'XDOBURSTREP',
                   description   => 'Bursting',
                   argument1     => 'Y',
                   argument2     => fnd_global.conc_request_id,
                   argument3     => 'Y');

             IF ln_req_id != 0
             THEN
                lb_result := TRUE;
             ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Failed to launch bursting request');
                lb_result := FALSE;
             END IF;
       END IF;*/
        RETURN lb_result;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'exception at Bursting: ' || SQLERRM);
            RETURN FALSE;
    END AFTERREPORT;
END XXD_AR_AGING_RPT_PKG;
/
