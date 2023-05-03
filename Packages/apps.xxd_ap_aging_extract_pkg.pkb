--
-- XXD_AP_AGING_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_AGING_EXTRACT_PKG"
AS
         /****************************************************************************************
* Package      : XXD_AP_AGING_EXTRACT_PKG
* Design       : This package will be used to fetch the Aging details and send to blackline
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 20-Apr-2021  1.0        Showkath Ali            Initial Version
******************************************************************************************/

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    gn_error          CONSTANT NUMBER := 2;
    gv_delimeter               VARCHAR2 (1) := '|';

    -- Procedure to write the file into blackline folder
    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

    PROCEDURE write_ap_file (p_file_path     IN     VARCHAR2,
                             p_file_name     IN     VARCHAR2,
                             p_request_id    IN     NUMBER,
                             x_ret_code         OUT VARCHAR2,
                             x_ret_message      OUT VARCHAR2)
    IS
        CURSOR write_ap_extract IS
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || (-1) * ROUND (SUM (subledger_acc_bal), 2) line
                FROM XXDO.XXD_AP_AGING_EXTRACT_T
               WHERE request_id = p_request_id AND accounted = 'Accounted'
            GROUP BY entity_unique_identifier, account_number, key3,
                     key4, key5, key6,
                     key7, key8, key9,
                     key10, period_end_date, subledger_rep_bal,
                     subledger_alt_bal;

        --DEFINE VARIABLES

        lv_file_path              VARCHAR2 (360);
        lv_output_file            UTL_FILE.file_type;
        lv_outbound_file          VARCHAR2 (360);
        lv_err_msg                VARCHAR2 (2000) := NULL;
        lv_line                   VARCHAR2 (32767) := NULL;
        lv_vs_default_file_path   VARCHAR2 (2000);
        lv_vs_file_path           VARCHAR2 (200);
        lv_vs_file_name           VARCHAR2 (200);
        ln_request_id             NUMBER := fnd_global.conc_request_id;
    BEGIN
        -- WRITE INTO FND LOGS
        FOR i IN write_ap_extract
        LOOP
            lv_line   := i.line;
            fnd_file.put_line (fnd_file.output, lv_line);
        END LOOP;

        IF p_file_path IS NOT NULL
        THEN
            -- WRITE INTO BL FOLDER
            --showkath

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
                       AND ffvl.description = 'APAGING'
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
                    || ln_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';

                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                       ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN write_ap_extract
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the givr extract data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                --END IF;
                END IF;
            END IF;

            UTL_FILE.fclose (lv_output_file);

            -- update value set,

            BEGIN
                UPDATE apps.fnd_flex_values ffvl
                   SET ffvl.attribute5   =
                           (SELECT user_name
                              FROM fnd_user
                             WHERE user_id = gn_user_id),
                       ffvl.attribute6   =
                           TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS')
                 WHERE     1 = 1
                       AND ffvl.flex_value_set_id =
                           (SELECT flex_value_set_id
                              FROM apps.fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'XXD_GL_AAR_FILE_DETAILS_VS')
                       AND NVL (TRUNC (ffvl.start_date_active),
                                TRUNC (SYSDATE)) <=
                           TRUNC (SYSDATE)
                       AND NVL (TRUNC (ffvl.end_date_active),
                                TRUNC (SYSDATE)) >=
                           TRUNC (SYSDATE)
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.flex_value = p_file_path;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Exp- Updation As-of-Date failed in Valueset ');
            END;
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END write_ap_file;


    PROCEDURE generate_prog_file (p_request_id IN NUMBER, p_include_invoice_detail IN VARCHAR2, p_include_site_detail IN VARCHAR2, p_file_path IN VARCHAR2, p_operating_unit IN NUMBER, x_ret_code OUT VARCHAR2
                                  , x_ret_message OUT VARCHAR2)
    AS
        CURSOR detail_extract IS
            SELECT vendor_number || gv_delimeter || vendor_name || gv_delimeter || invoice_number || gv_delimeter || invoice_date || gv_delimeter || accounted || gv_delimeter || currency || gv_delimeter || entered_amount || gv_delimeter || amount_remaining || gv_delimeter || current_bucket || gv_delimeter || bucket1 || gv_delimeter || bucket2 || gv_delimeter || bucket3 || gv_delimeter || bucket4 line
              FROM xxdo.xxd_ap_aging_extract_t
             WHERE request_id = p_request_id;

        CURSOR summary_extract IS
              SELECT vendor_number || gv_delimeter || vendor_name || gv_delimeter || city || gv_delimeter || vendor_state || gv_delimeter || SUM (amount_remaining) || gv_delimeter || SUM (current_bucket) || gv_delimeter || SUM (bucket1) || gv_delimeter || SUM (bucket2) || gv_delimeter || SUM (bucket3) || gv_delimeter || SUM (bucket4) line
                FROM xxdo.xxd_ap_aging_extract_t
               WHERE request_id = p_request_id
            GROUP BY vendor_number, vendor_name, city,
                     vendor_state;

        lv_file_name       VARCHAR2 (360);
        lv_file_dir        VARCHAR2 (1000);
        lv_output_file     UTL_FILE.file_type;
        lv_output_file1    UTL_FILE.file_type;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
        lv_vs_file_path    VARCHAR2 (100);
        lv_vs_file_name    VARCHAR2 (100);
        lv_ou_short_name   VARCHAR2 (100);
        ln_request_id      NUMBER := fnd_global.conc_request_id;
        lv_period_name     VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Program file generation starts here...');

        IF NVL (p_include_invoice_detail, 'N') = 'Y'
        THEN
            lv_line   :=
                   'Vendor Number'
                || gv_delimeter
                || 'Vendor Name'
                || gv_delimeter
                || 'Invoice Number'
                || gv_delimeter
                || 'Invoice Date'
                || gv_delimeter
                || 'Accounted'
                || gv_delimeter
                || 'Currency'
                || gv_delimeter
                || 'Entered Amount'
                || gv_delimeter
                || 'Amount Remaining'
                || gv_delimeter
                || 'Current'
                || gv_delimeter
                || '1-30 Days Overdue'
                || gv_delimeter
                || '31-60 Days Overdue'
                || gv_delimeter
                || '61-90 Days Overdue'
                || gv_delimeter
                || '91+ Days Overdue';
        ELSIF NVL (p_include_invoice_detail, 'N') = 'N'
        THEN
            lv_line   :=
                   'Vendor Number'
                || gv_delimeter
                || 'Vendor Name'
                || gv_delimeter
                || 'City'
                || gv_delimeter
                || 'State'
                || gv_delimeter
                || 'Amount Remaining'
                || gv_delimeter
                || 'Current'
                || gv_delimeter
                || '1-30 Days Overdue'
                || gv_delimeter
                || '31-60 Days Overdue'
                || gv_delimeter
                || '61-90 Days Overdue'
                || gv_delimeter
                || '91+ Days Overdue';
        END IF;

        fnd_file.put_line (fnd_file.output, lv_line);

        IF NVL (p_include_invoice_detail, 'N') = 'Y'
        THEN
            FOR i IN detail_extract
            LOOP
                lv_line   := NULL;
                lv_line   := i.line;
                fnd_file.put_line (fnd_file.output, lv_line);
            END LOOP;
        ELSE
            FOR i IN summary_extract
            LOOP
                lv_line   := NULL;
                lv_line   := i.line;
                fnd_file.put_line (fnd_file.output, lv_line);
            END LOOP;
        END IF;


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
                       AND ffvl.description = 'APAGING'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;

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

                -- query to fetch period name

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

                lv_file_dir   := lv_vs_file_path;
                lv_file_name   :=
                       lv_vs_file_name
                    || '_'
                    || lv_period_name
                    || '_'
                    || lv_ou_short_name
                    || '_'
                    || ln_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';
                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    IF NVL (p_include_invoice_detail, 'N') = 'Y'
                    THEN
                        lv_line   :=
                               'Vendor Number'
                            || gv_delimeter
                            || 'Vendor Name'
                            || gv_delimeter
                            || 'Invoice Number'
                            || gv_delimeter
                            || 'Invoice Date'
                            || gv_delimeter
                            || 'Accounted'
                            || gv_delimeter
                            || 'Currency'
                            || gv_delimeter
                            || 'Entered Amount'
                            || gv_delimeter
                            || 'Amount Remaining'
                            || gv_delimeter
                            || 'Current'
                            || gv_delimeter
                            || '1-30 Days Overdue'
                            || gv_delimeter
                            || '31-60 Days Overdue'
                            || gv_delimeter
                            || '61-90 Days Overdue'
                            || gv_delimeter
                            || '91+ Days Overdue';
                    ELSE
                        lv_line   :=
                               'Vendor Number'
                            || gv_delimeter
                            || 'Vendor Name'
                            || gv_delimeter
                            || 'City'
                            || gv_delimeter
                            || 'State'
                            || gv_delimeter
                            || 'Amount Remaining'
                            || gv_delimeter
                            || 'Current'
                            || gv_delimeter
                            || '1-30 Days Overdue'
                            || gv_delimeter
                            || '31-60 Days Overdue'
                            || gv_delimeter
                            || '61-90 Days Overdue'
                            || gv_delimeter
                            || '91+ Days Overdue';
                    END IF;

                    UTL_FILE.put_line (lv_output_file, lv_line);

                    IF NVL (p_include_invoice_detail, 'N') = 'Y'
                    THEN
                        FOR i IN detail_extract
                        LOOP
                            lv_line   := NULL;
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;
                    ELSE
                        FOR i IN summary_extract
                        LOOP
                            lv_line   := NULL;
                            lv_line   := i.line;
                            UTL_FILE.put_line (lv_output_file, lv_line);
                        END LOOP;
                    END IF;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the AP extract data file for writing. Error is : '
                            || SQLERRM,
                            1,
                            2000);
                    fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                    x_ret_code      := gn_error;
                    x_ret_message   := lv_err_msg;
                    RETURN;
                END IF;

                UTL_FILE.fclose (lv_output_file);
            END IF;
        END IF;
    --END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            lv_err_msg      :=
                'INVALID_PATH: File location or filename was invalid.';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
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
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            x_ret_code      := gn_error;
            x_ret_message   := lv_err_msg;
            raise_application_error (-20109, lv_err_msg);
    END generate_prog_file;

    PROCEDURE generate_data (p_operating_unit IN NUMBER, p_sort_invoices_by IN VARCHAR2, p_include_invoice_detail IN VARCHAR2, p_include_site_detail IN VARCHAR2, p_minimum_amount_due IN NUMBER, p_maximum_amount_due IN NUMBER, p_invoice_type IN VARCHAR2, p_trading_partner IN VARCHAR2, p_aging_period_name IN VARCHAR2, p_sob IN VARCHAR2, p_trace_switch IN VARCHAR2, p_currency IN VARCHAR2
                             , p_accounted IN VARCHAR2)
    AS
        CURSOR fetch_eligible_records IS
              SELECT NVL (v.vendor_name, hp.party_name) c_vendor_name, v.segment1 c_vendor_number, NVL (v.vendor_name, hp.party_name) c_short_vendor_name, /*Bug11849094 : Added NVL*/
                     v.vendor_id c_vendor_id, i.vendor_site_id c_contact_site_id, vs.vendor_site_code c_vendor_site_code,
                     -- decode(:SORT_BY_ALTERNATE, 'Y', vs.vendor_site_code_alt, vs.vendor_site_code) C_VENDOR_SITE_CODE_BRK,
                     NVL (vs.state, ' ') c_vendor_state, NVL (SUBSTR (vs.city, 1, 15), ' ') c_vendor_city, ps.payment_num c_reference_number,
                     i.vendor_site_id c_address_id, NVL (SUBSTR (i.invoice_type_lookup_code, 1, 20), ' ') c_invoice_type, i.invoice_id c_payment_sched_id,
                     NVL (TO_CHAR (ps.due_date, 'DD-MON-RR'), ' ') c_due_date, i.accts_pay_code_combination_id c_vendor_trx_id, DECODE (ap_invoices_pkg.get_posting_status (i.invoice_id), 'Y', 'Accounted', 'Unaccounted') c_accounted,
                     i.invoice_num c_invoice_number, i.invoice_num c_invoice_num_short, TO_CHAR (i.invoice_date, 'DD-MON-RR') c_invoice_date,
                     CEIL (TO_DATE (TO_CHAR (SYSDATE, 'DD-MON-RR'), 'DD-MON-RR') - ps.due_date) c_days_past_due, NVL (i.exchange_rate, 1) c_exchange_rate, i.org_id,
                     ou.name ou_name, ps.amount_remaining c_amt_e, i.invoice_currency_code c_curr_e,
                     i.invoice_type_lookup_code, (NVL (ps.amount_remaining, 0) * NVL (i.exchange_rate, 1)) due_amount
                FROM ap_payment_schedules_all ps, ap_invoices_all i, hz_parties hp,
                     ap_suppliers v, po_vendor_sites_all vs, hr_operating_units ou
               WHERE     i.invoice_id = ps.invoice_id
                     AND ap_invoices_pkg.get_posting_status (i.invoice_id) =
                         NVL (
                             p_accounted,
                             ap_invoices_pkg.get_posting_status (i.invoice_id))
                     AND i.party_id = hp.party_id
                     AND i.vendor_id = v.vendor_id(+)
                     AND i.vendor_site_id = vs.vendor_site_id(+)
                     AND (TO_DATE (TO_CHAR (SYSDATE, 'DD-MON-RR'), 'DD-MON-RR') - ps.due_date) >=
                         NVL (
                             p_minimum_amount_due,
                             (TO_DATE (TO_CHAR (SYSDATE, 'DD-MON-RR'), 'DD-MON-RR') - ps.due_date))
                     AND (TO_DATE (TO_CHAR (SYSDATE, 'DD-MON-RR'), 'DD-MON-RR') - ps.due_date) <=
                         NVL (
                             p_maximum_amount_due,
                             (TO_DATE (TO_CHAR (SYSDATE, 'DD-MON-RR'), 'DD-MON-RR') - ps.due_date))
                     AND i.invoice_type_lookup_code =
                         NVL (p_invoice_type, invoice_type_lookup_code)
                     AND i.cancelled_date IS NULL
                     AND i.org_id = ou.organization_id
                     AND i.org_id = p_operating_unit
                     AND (NVL (ps.amount_remaining, 0) * NVL (i.exchange_rate, 1)) !=
                         0
                     AND i.invoice_currency_code =
                         NVL (p_currency, i.invoice_currency_code)
                     AND NVL (v.vendor_name, hp.party_name) =
                         NVL (p_trading_partner,
                              NVL (v.vendor_name, hp.party_name))
                     AND NVL (i.payment_status_flag, 'N') IN ('N', 'P')
            ORDER BY 1;

        lv_segment1          gl_code_combinations.segment1%TYPE;
        lv_segment2          gl_code_combinations.segment2%TYPE;
        lv_segment3          gl_code_combinations.segment3%TYPE;
        lv_segment4          gl_code_combinations.segment4%TYPE;
        lv_segment5          gl_code_combinations.segment5%TYPE;
        lv_segment6          gl_code_combinations.segment6%TYPE;
        lv_segment7          gl_code_combinations.segment7%TYPE;
        lv_period_end_date   VARCHAR2 (20);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Program starts');

        FOR i IN fetch_eligible_records
        LOOP
            fnd_file.put_line (fnd_file.LOG, 'inside loop');

            -- query to get code combination and segments for given invoice_currency_code
            BEGIN
                SELECT DISTINCT gcc.segment1, gcc.segment2, gcc.segment3,
                                gcc.segment4, gcc.segment5, gcc.segment6,
                                gcc.segment7
                  INTO lv_segment1, lv_segment2, lv_segment3, lv_segment4,
                                  lv_segment5, lv_segment6, lv_segment7
                  FROM xla_distribution_links xdl, ap_invoice_distributions_all aida, ap_invoices_all aia,
                       xla_ae_headers xah, xla_ae_lines xal, gl_code_combinations gcc
                 WHERE     xdl.source_distribution_id_num_1 =
                           aida.invoice_distribution_id
                       AND aia.invoice_id = aida.invoice_id
                       AND xal.ledger_id = aia.set_of_books_id
                       AND source_distribution_type = 'AP_INV_DIST'
                       AND xdl.rounding_class_code = 'LIABILITY'
                       AND aia.invoice_id = i.c_payment_sched_id
                       AND xah.ae_header_id = xdl.ae_header_id
                       AND xah.ae_header_id = xal.ae_header_id
                       AND accounting_class_code = 'LIABILITY'
                       AND xal.code_combination_id = gcc.code_combination_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_segment1   := NULL;
                    lv_segment2   := NULL;
                    lv_segment3   := NULL;
                    lv_segment4   := NULL;
                    lv_segment5   := NULL;
                    lv_segment6   := NULL;
                    lv_segment7   := NULL;
            END;

            -- query to fetch period end date

            BEGIN
                SELECT TO_CHAR (LAST_DAY (SYSDATE), 'MM/DD/YYYY')
                  INTO lv_period_end_date
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_period_end_date   := NULL;
            END;

            BEGIN
                INSERT INTO xxdo.xxd_ap_aging_extract_t (
                                vendor_number,
                                vendor_name,
                                invoice_number,
                                invoice_date,
                                accounted,
                                currency,
                                entered_amount,
                                amount_remaining,
                                exchange_rate,
                                invoice_type,
                                due_days,
                                city,
                                vendor_state,
                                org_id,
                                current_bucket,
                                bucket1,
                                bucket2,
                                bucket3,
                                bucket4,
                                entity_unique_identifier,
                                account_number,
                                key3,
                                key4,
                                key5,
                                key6,
                                key7,
                                period_end_date,
                                subledger_acc_bal,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                request_id)
                         VALUES (
                                    i.c_vendor_number,
                                    i.c_vendor_name,
                                    i.c_invoice_number,
                                    i.c_invoice_date,
                                    i.c_accounted,
                                    i.c_curr_e,
                                    i.c_amt_e,
                                    i.due_amount,
                                    i.c_exchange_rate,
                                    i.invoice_type_lookup_code,
                                    i.c_days_past_due,
                                    i.c_vendor_city,
                                    i.c_vendor_state,
                                    i.org_id,
                                    CASE
                                        WHEN i.c_days_past_due <= 0
                                        THEN
                                            i.due_amount
                                        ELSE
                                            NULL
                                    END,
                                    CASE
                                        WHEN     i.c_days_past_due >= 1
                                             AND i.c_days_past_due <= 30
                                        THEN
                                            i.due_amount
                                        ELSE
                                            NULL
                                    END,
                                    CASE
                                        WHEN     i.c_days_past_due >= 31
                                             AND i.c_days_past_due <= 60
                                        THEN
                                            i.due_amount
                                        ELSE
                                            NULL
                                    END,
                                    CASE
                                        WHEN     i.c_days_past_due >= 61
                                             AND i.c_days_past_due <= 90
                                        THEN
                                            i.due_amount
                                        ELSE
                                            NULL
                                    END,
                                    CASE
                                        WHEN i.c_days_past_due >= 91
                                        THEN
                                            i.due_amount
                                        ELSE
                                            NULL
                                    END,
                                    lv_segment1,
                                    lv_segment6,
                                    lv_segment2,
                                    lv_segment3,
                                    lv_segment4,
                                    lv_segment5,
                                    lv_segment7,
                                    lv_period_end_date,
                                    i.due_amount,
                                    gn_user_id,
                                    SYSDATE,
                                    gn_user_id,
                                    SYSDATE,
                                    gn_request_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'insert failed' || SQLERRM);
            END;
        END LOOP;
    END generate_data;

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_operating_unit IN NUMBER, p_sort_invoices_by IN VARCHAR2, p_include_invoice_detail IN VARCHAR2, p_include_site_detail IN VARCHAR2, p_minimum_amount_due IN NUMBER, p_maximum_amount_due IN NUMBER, p_invoice_type IN VARCHAR2, p_trading_partner IN VARCHAR2, p_aging_period_name IN VARCHAR2, p_sob IN VARCHAR2, p_trace_switch IN VARCHAR2, p_currency IN VARCHAR2, p_accounted IN VARCHAR2
                    , p_file_path IN VARCHAR2)
    AS
    BEGIN
        -- Display Report parameters
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_operating_unit:' || p_operating_unit);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_sort_invoices_by:' || p_sort_invoices_by);
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'p_include_invoice_detail:' || p_include_invoice_detail);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_include_site_detail:' || p_include_site_detail);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_minimum_amount_due:' || p_minimum_amount_due);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_maximum_amount_due:' || p_maximum_amount_due);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_invoice_type:' || p_invoice_type);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_trading_partner:' || p_trading_partner);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'p_aging_period_name:' || p_aging_period_name);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_sob:' || p_sob);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_trace_switch:' || p_trace_switch);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_currency:' || p_currency);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'p_accounted:' || p_accounted);
        generate_data (p_operating_unit, p_sort_invoices_by, p_include_invoice_detail, p_include_site_detail, p_minimum_amount_due, p_maximum_amount_due, p_invoice_type, p_trading_partner, p_aging_period_name, p_sob, p_trace_switch, p_currency
                       , p_accounted);

        generate_prog_file (gn_request_id, p_include_invoice_detail, p_include_site_detail, p_file_path, p_operating_unit, p_retcode
                            , p_errbuf);
    END main;

    PROCEDURE main_group (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_operating_unit IN NUMBER, p_sort_invoices_by IN VARCHAR2, p_include_invoice_detail IN VARCHAR2, p_include_site_detail IN VARCHAR2, p_minimum_amount_due IN NUMBER, p_maximum_amount_due IN NUMBER, p_invoice_type IN VARCHAR2, p_trading_partner IN VARCHAR2, p_aging_period_name IN VARCHAR2, p_sob IN VARCHAR2, p_trace_switch IN VARCHAR2, p_currency IN VARCHAR2, p_accounted IN VARCHAR2
                          , p_file_path IN VARCHAR2)
    AS
        v_request_id       NUMBER;
        v_phase            VARCHAR2 (240);
        v_status           VARCHAR2 (240);
        v_request_phase    VARCHAR2 (240);
        v_request_status   VARCHAR2 (240);
        v_finished         BOOLEAN;
        v_message          VARCHAR2 (240);
        v_sub_status       BOOLEAN := FALSE;
        lv_file_name       VARCHAR2 (360)
            :=    'Sub_SL_AP_'
               || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
               || '.txt';
        lv_errbuff         VARCHAR2 (240);
        lv_retcode         VARCHAR2 (10);
    BEGIN
        BEGIN
            v_request_id   :=
                fnd_request.submit_request (application => 'XXDO', program => 'XXD_AP_AGING_RPT', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => p_operating_unit, argument2 => p_sort_invoices_by, argument3 => p_include_invoice_detail, argument4 => p_include_site_detail, argument5 => p_minimum_amount_due, argument6 => p_maximum_amount_due, argument7 => p_invoice_type, argument8 => p_trading_partner, argument9 => p_aging_period_name, argument10 => p_sob, argument11 => p_trace_switch, argument12 => p_currency, argument13 => p_accounted
                                            , argument14 => p_file_path);
            COMMIT;
        END;

        IF (v_request_id = 0)
        THEN
            DBMS_OUTPUT.put_line ('AP AGing Program Not Submitted');
            v_sub_status   := FALSE;
        ELSE
            v_finished   :=
                fnd_concurrent.wait_for_request (
                    request_id   => v_request_id,
                    INTERVAL     => 0,
                    max_wait     => 0,
                    phase        => v_phase,
                    status       => v_status,
                    dev_phase    => v_request_phase,
                    dev_status   => v_request_status,
                    MESSAGE      => v_message);

            DBMS_OUTPUT.put_line ('Request Phase  : ' || v_request_phase);
            DBMS_OUTPUT.put_line ('Request Status : ' || v_request_status);
            DBMS_OUTPUT.put_line ('Request id     : ' || v_request_id);
        END IF;

        -- calling procedure to write GIVR file
        write_ap_file (p_file_path, lv_file_name, v_request_id,
                       lv_retcode, lv_errbuff);
    -- END;
    END main_group;
END xxd_ap_aging_extract_pkg;
/
