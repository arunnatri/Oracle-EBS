--
-- XXD_VT_ICS_RECON_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_VT_ICS_RECON_EXTRACT_PKG"
IS
    /****************************************************************************************
  * Package      : XXD_VT_ICS_RECON_EXTRACT_PKG
  * Design       : This package will be used to fetch the VT details and send to blackline
  * Notes        :
  * Modification :
  -- ======================================================================================
  -- Date         Version#   Name                    Comments
  -- ======================================================================================
  -- 02-Jun-2021  1.0        Showkath Ali            Initial Version
  ******************************************************************************************/
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gn_user_id      NUMBER := fnd_global.user_id;
    gn_error        NUMBER := 1;

    -- Procedure to write the summary in the BL folder
    PROCEDURE write_VT_file (p_file_path IN VARCHAR2, p_request_id IN NUMBER, x_ret_code OUT VARCHAR2
                             , x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_vt_extract IS
              SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || period_end_date || CHR (9) || subledger_rep_bal || CHR (9) || subledger_alt_bal || CHR (9) || ROUND (SUM (subledger_acc_bal), 2) line
                FROM xXDO.xxd_gl_vt_ics_gl_ytd_recon_t
               WHERE request_id = p_request_id AND subledger_acc_bal <> 0
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
        FOR i IN write_vt_extract
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
                       AND ffvl.description = 'VTICS'
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
                    FOR i IN write_vt_extract
                    LOOP
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;
                ELSE
                    lv_err_msg      :=
                        SUBSTR (
                               'Error in Opening the VT extract data file for writing. Error is : '
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
    END write_vt_file;

    -- Procedure to write the output into folder
    PROCEDURE write_vt_output (p_request_id    IN     NUMBER,
                               p_file_path     IN     VARCHAR2,
                               p_period        IN     VARCHAR2,
                               x_ret_code         OUT VARCHAR2,
                               x_ret_message      OUT VARCHAR2)
    IS
        CURSOR write_vt_output_cur IS
            SELECT Company || '|' || compant_name || '|' || ic_partners || '|' || accounted_currency || '|' || entered_currency || '|' || account_string || '|' || com_ar_bal_in_ics || '|' || com_ap_bal_in_ics || '|' || net_entered_bal_in_ics || '|' || gl_balance || '|' || entered_diff || '|' || com_acc_ar_bal_in_ics || '|' || com_acc_ap_bal_in_ics || '|' || net_accounted_bal_in_ics || '|' || gl_balance_accounted || '|' || fx_rate line
              FROM xxdo.xxd_gl_vt_ics_gl_ytd_recon_t
             WHERE request_id = p_request_id;

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
                       AND ffvl.description = 'VTICS'
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
                /*BEGIN
             SELECT
             ffvl. attribute2
          INTO lv_ou_short_name
         FROM
             apps.fnd_flex_value_sets   fvs,
             apps.fnd_flex_values_vl    ffvl
         WHERE
             fvs.flex_value_set_id = ffvl.flex_value_set_id
             AND fvs.flex_value_set_name = 'XXD_GL_AAR_OU_SHORTNAME_VS'
             AND nvl(trunc(ffvl.start_date_active), trunc(SYSDATE)) <= trunc(SYSDATE)
             AND nvl(trunc(ffvl.end_date_active), trunc(SYSDATE)) >= trunc(SYSDATE)
             AND ffvl.enabled_flag = 'Y';
             --AND ffvl.attribute1 = p_operating_unit;

             EXCEPTION WHEN OTHERS THEN
             lv_ou_short_name:=NULL;
             END;*/

                -- query to fetch period name

                BEGIN
                    SELECT period_year || '.' || period_num || '.' || period_name
                      INTO lv_period_name
                      FROM apps.gl_periods
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND period_name = p_period;
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
                    || ln_request_id
                    || '_'
                    || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS')
                    || '.txt';
                lv_output_file   :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);   --opening the file in write mode

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    lv_line   :=
                           'Company'
                        || '|'
                        || 'Company Name'
                        || '|'
                        || 'IC Partners'
                        || '|'
                        || 'Company Accounted Currency'
                        || '|'
                        || 'Entered Currency'
                        || '|'
                        || 'Account String'
                        || '|'
                        || 'Company AR Balance in ICS'
                        || '|'
                        || 'Company AP Balance in ICS'
                        || '|'
                        || 'Net Entered Balance in ICS'
                        || '|'
                        || 'GL Balance'
                        || '|'
                        || 'Entered Difference'
                        || '|'
                        || 'Company Accounted AR Balance in ICS'
                        || '|'
                        || 'Company Accounted AP Balance in ICS'
                        || '|'
                        || 'Net Accounted Balance in ICS'
                        || '|'
                        || 'GL Balance Accounted'
                        || '|'
                        || 'FX Rate';
                    UTL_FILE.put_line (lv_output_file, lv_line);

                    FOR i IN write_vt_output_cur
                    LOOP
                        lv_line   := NULL;
                        lv_line   := i.line;
                        UTL_FILE.put_line (lv_output_file, lv_line);
                    END LOOP;

                    UTL_FILE.fclose (lv_output_file);
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
    END;

    --
    FUNCTION Software_Version
        RETURN VARCHAR2
    IS
    BEGIN
        RETURN ('Version [04.01.13] Build Date [17-MAY-2019] Name [XXCP_BI_PUB]');
    END Software_Version;

    ----------------------------------------------------------------
    -- Converts clob to char.
    ----------------------------------------------------------------
    PROCEDURE printClobOut (cClob         IN CLOB,
                            cHeader_Req   IN VARCHAR2 DEFAULT 'N')
    IS
        vPos         PLS_INTEGER := 1;
        vConst_Amt   NUMBER := 8000;
        vAmt         NUMBER;
        vBuffer      VARCHAR2 (32767);

        vNum         NUMBER := 0;
        vSlash       NUMBER := 0;
        vLessThan    NUMBER := 0;
        tempbuf      VARCHAR2 (32767);
    BEGIN
        IF cClob IS NOT NULL
        THEN
            IF cHeader_Req = 'Y'
            THEN
                fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
            END IF;

            LOOP
                vNum      := vNum + 1;

                -- work out where the last > is in this chunk of XML, so we don't trunc a XML tag.
                vAmt      :=
                    INSTR (DBMS_LOB.SUBSTR (cClob, vConst_Amt, vPos),
                           '>',
                           -1);
                tempbuf   := DBMS_LOB.SUBSTR (cClob, vConst_Amt, vPos);

                -- Start or End Node?
                IF vAmt > 0
                THEN
                    vSlash      := INSTR (SUBSTR (tempbuf, 1, vAmt), '</', -1);
                    vLessThan   := INSTR (SUBSTR (tempbuf, 1, vAmt), '<', -1);

                    IF vSlash < vLessThan
                    THEN
                        --Get previous > tag (so startnode-value-endnode is not split)
                        vAmt   :=
                            INSTR (SUBSTR (tempbuf, 1, vLessThan), '>', -1);
                    END IF;
                END IF;

                -- NCM 14/04/2010 if there is no > character in the next chunck then get
                -- the whole of the next chunk.
                IF vAmt = 0
                THEN
                    vAmt   :=
                        DBMS_LOB.getlength (
                            DBMS_LOB.SUBSTR (cClob, vConst_Amt, vPos));
                END IF;

                --vBuffer := utl_raw.cast_to_raw( dbms_lob.substr( cClob, vAmt, vPos ) );
                vBuffer   := DBMS_LOB.SUBSTR (cClob, vAmt, vPos);

                EXIT WHEN vBuffer IS NULL;

                fnd_file.put_line (fnd_file.output, vBuffer);

                vPos      := vPos + vAmt;
            END LOOP;
        ELSE
            -- Output Dummy XML so Layout is applied
            IF cHeader_Req = 'Y'
            THEN
                fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
            END IF;

            fnd_file.put_line (fnd_file.output, '<ROWSET>');
            fnd_file.put_line (fnd_file.output, '</ROWSET>');
        END IF;
    END printClobOut;



    ----------------------------------------------------------------
    -- Generic Procedure.
    ----------------------------------------------------------------
    PROCEDURE GENERIC (cTable_Name     IN VARCHAR2,
                       cWhere_Clause   IN VARCHAR2 DEFAULT NULL)
    IS
        TYPE tab_varchar IS TABLE OF VARCHAR2 (30)
            INDEX BY BINARY_INTEGER;

        t_column_name   tab_varchar;
        t_result        tab_varchar;
        vSQL            VARCHAR2 (32000);
        vCursor         PLS_INTEGER;
        vRows           PLS_INTEGER;

        vColTemp        VARCHAR2 (1000);

        CURSOR c1 (pTable_Name IN VARCHAR2)
        IS
              SELECT column_name
                FROM xxcp_instance_all_tabcols_v
               WHERE     ((owner = 'XXCP' AND table_name LIKE 'CP%') OR (owner = 'APPS' AND table_name LIKE 'XXCP%'))
                     AND table_name = pTable_Name
                     AND data_type IN ('NUMBER', 'VARCHAR2', 'DATE')
                     AND instance_id = 0
            ORDER BY column_id;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'GENERIC XML GENERATION. START...');

        fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
        fnd_file.put_line (fnd_file.output, '<dt>');

        -- Build Dynamic Query
        FOR c1_rec IN c1 (cTable_Name)
        LOOP
            t_column_name (t_column_name.COUNT + 1)   := c1_rec.column_name;

            IF vSQL IS NULL
            THEN
                vSQL   := 'select ' || c1_rec.column_name;
            ELSE
                vSQL   := vSQL || ',' || c1_rec.column_name;
            END IF;
        END LOOP;

        -- Finalize Query
        IF vSQL IS NOT NULL
        THEN
            vSQL   := vSQL || ' from ' || cTable_Name;

            IF cWhere_Clause IS NOT NULL
            THEN
                vSQL   := vSQL || ' ' || cWhere_Clause;
            END IF;
        END IF;

        -- Now Execute Dynamic SQL
        vCursor   := DBMS_SQL.OPEN_CURSOR;
        DBMS_SQL.PARSE (vCursor, vSQL, DBMS_SQL.native);

        -- Define Cols
        FOR i IN 1 .. t_column_name.COUNT
        LOOP
            DBMS_SQL.DEFINE_COLUMN (vCursor, i, vColTemp,
                                    1000);
        END LOOP;

        vRows     := DBMS_SQL.EXECUTE (vCursor);

        -- Loop Through Records
        LOOP
            IF DBMS_SQL.FETCH_ROWS (vCursor) = 0
            THEN
                EXIT;
            END IF;

            -- Output in XML format
            fnd_file.put_line (fnd_file.output, '<' || cTable_Name || '>');

            FOR i IN 1 .. t_column_name.COUNT
            LOOP
                DBMS_SQL.COLUMN_VALUE (vCursor, i, vColTemp);
                fnd_file.put_line (
                    fnd_file.output,
                       ' <'
                    || t_column_name (i)
                    || '>'
                    || vColTemp
                    || '</'
                    || t_column_name (i)
                    || '>');
            END LOOP;

            fnd_file.put_line (fnd_file.output, '</' || cTable_Name || '>');
        END LOOP;

        fnd_file.put_line (fnd_file.output, '</dt>');
        fnd_file.put_line (fnd_file.LOG, 'GENERIC XML GENERATION. FINISH...');

        DBMS_SQL.CLOSE_CURSOR (vCursor);
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_SQL.CLOSE_CURSOR (vCursor);
            RAISE;
    END GENERIC;


    PROCEDURE TAX_REGISTRATIONS_OLD (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        CURSOR c1 IS
            SELECT tax_registration_id, short_code, description
              FROM xxcp_tax_registrations;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'SJS TEST....');

        fnd_file.put_line (fnd_file.output, '<?xml version="1.0"?>');
        fnd_file.put_line (fnd_file.output, '<dt>');

        FOR c1_rec IN c1
        LOOP
            fnd_file.put_line (fnd_file.output, '<tax_registration>');
            fnd_file.put_line (
                fnd_file.output,
                   '<tax_registration_id>'
                || c1_rec.tax_registration_id
                || '</tax_registration_id>');
            fnd_file.put_line (
                fnd_file.output,
                '<short_code>' || c1_rec.short_code || '</short_code>');
            fnd_file.put_line (
                fnd_file.output,
                '<description>' || c1_rec.description || '</description>');
            fnd_file.put_line (fnd_file.output, '</tax_registration>');
        END LOOP;

        fnd_file.put_line (fnd_file.output, '</dt>');
    END TAX_REGISTRATIONS_OLD;



    ----------------------------------------------------------------
    -- Tax Registrations Procedure.
    ----------------------------------------------------------------
    PROCEDURE TAX_REGISTRATIONS (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        CURSOR c1 IS
            SELECT tax_registration_id, short_code, description
              FROM xxcp_tax_registrations;
    BEGIN
        generic ('XXCP_TAX_REGISTRATIONS');
    END TAX_REGISTRATIONS;

    ----------------------------------------------------------------
    -- Sett Pay File Procedure.
    ----------------------------------------------------------------
    PROCEDURE SETT_PAY_FILE (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        vClob   CLOB;
    BEGIN
        --generic('XXCP_BI_SETT_HDR_REF_V');

        SELECT DBMS_XMLGEN.getxml ('
    select p.pay_file_id,
           p.paying_company,
           p.receiving_company,
           p.period_name,
           p.payment_amount,
           p.payment_currency,
           cursor(select r.ref_action,
                         r.reference,
                         h.ics_type,
                         h.acct_period,
                         h.owner_tax_reg_id,
                         h.partner_tax_reg_id,
                         h.ic_pair,
                         h.currency_code,
                         h.amount_ap,
                         h.amount_ar,
                         h.accounted_currency,
                         h.accounted_amount_ap,
                         h.accounted_amount_ar
                  from   xxcp_ic_settlement_references r,
                         xxcp_ic_settlement_hdr h
                  where  h.ics_group_id = r.ics_group_id
                  and    h.ap_ar_ind    = ''AP''
                  and    p.pay_file_id = r.payment_id) as hdr
    from xxcp_ic_payment_file p') xml INTO vClob FROM DUAL;

        printClobOut (vClob);
    END SETT_PAY_FILE;

    ----------------------------------------------------------------
    -- Ics_Recon1 Procedure.
    ----------------------------------------------------------------
    PROCEDURE Ics_Recon1 (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        vClob   CLOB;
    BEGIN
        -- NOTE!!! Need to add Period Param into Query!!!

        SELECT DBMS_XMLGEN.getxml ('
            select
             v.Acct_Period
            ,v.Settlement_type
            --- Owner
            ,v.OWNER_COMP
            ,v.OWNER_COMP_NAME
            ,v.OWNER_ACCOUNT_SEGMENT
            ,sum(v.Owner_AP) Owner_AP
            ,sum(v.Owner_AR) Owner_AR
            ,ent_curr Owner_ent_curr
            --- Partner
            ,v.PARTNER_COMP
            ,v.PARTNER_COMP_NAME
            ,v.PARTNER_ACCOUNT_SEGMENT
            ,sum(v.Partner_AP) Partner_AP
            ,sum(v.Partner_AR) Partner_AR
            ,ent_curr Partner_Ent_Curr
            ,sum(v.Owner_AP) - sum(v.Partner_AR) AR_AP_Diff
            ,sum(v.Owner_AR) - sum(v.Partner_AP) AP_AR_Diff
            from xxcp_ics_recon_hdr_v v
            where v.acct_period = nvl(null,v.acct_period)
            group by
             v.acct_period
            ,v.Settlement_type
            --- Owner
            ,v.OWNER_COMP
            ,v.OWNER_COMP_NAME
            ,v.OWNER_ACCOUNT_SEGMENT
            ,v.ent_curr
            --- Partner
            ,v.PARTNER_COMP
            ,v.PARTNER_COMP_NAME
            ,v.PARTNER_ACCOUNT_SEGMENT
            ,v.ent_curr
            order by
             v.acct_period
            --- Owner
            ,v.OWNER_COMP
            ,v.OWNER_COMP_NAME
            ,v.OWNER_ACCOUNT_SEGMENT
            ,v.ent_curr
            --- Partner
            ,v.PARTNER_COMP
            ,v.PARTNER_COMP_NAME
            ,v.PARTNER_ACCOUNT_SEGMENT
            ,v.ent_curr') xml INTO vClob FROM DUAL;

        printClobOut (vClob);
    END Ics_Recon1;

    ----------------------------------------------------------------
    -- Ics_Balance_Listing
    ----------------------------------------------------------------
    PROCEDURE Ics_Balance_Listing (errbuf            OUT VARCHAR2,
                                   retcode           OUT NUMBER,
                                   cAcct_Period   IN     VARCHAR2 DEFAULT '',
                                   cCompany       IN     VARCHAR2 DEFAULT '',
                                   cCurrency      IN     VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
            select
             v.acct_period
            ,v.ent_curr
            ,v.Settlement_type
            --- Owner
            ,v.owner_Comp
            ,v.owner_Comp_Name
            ,v.type
            ,v.transaction_ref
            ,v.Owner_Account_Segment
            ,(v.Owner_AP)
            ,(v.Owner_AR)
            ,(v.Owner_AP_acct)
            ,(v.Owner_AR_acct)
            ,v.Owner_acct_Curr
            ,v.status
            --- Partner
            ,v.Partner_Comp
            ,v.partner_Comp_Name
            ,v.Partner_Account_Segment
            ,(v.Partner_AP)
            ,(v.Partner_AR)
            ,(v.Partner_AP_acct)
            ,(v.Partner_AR_acct)
            ,v.Partner_acct_Curr
            ----
            ,v.Owner_AP - v.Partner_AR AP_AR_Diff
            ,v.Owner_AR - v.Partner_AP AR_AP_Diff
            ----
            from xxcp_ics_recon_det_v v
            where v.acct_period = ''' || cAcct_Period || '''
            and   v.owner_comp  = ''' || cCompany || '''
            and   v.ent_curr    = ''' || cCurrency || '''
            order by
            abs(AP_AR_Diff) desc
            ,abs(AR_AP_Diff) desc
            ,v.acct_period
            ,v.ent_curr
            ,v.Settlement_type
            --- Owner
            ,v.owner_Comp
            ,v.owner_Comp_Name
            ,v.type
            ,v.reference
            ,v.Owner_Account_Segment
            ,v.Owner_acct_Curr
            ,v.status
            --- Partner
            ,v.Partner_Comp
            ,v.partner_Comp_Name
            ,v.Partner_Account_Segment
            ,v.Partner_acct_Curr') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Balance_Listing;

    ----------------------------------------------------------------
    -- Ics_Balance_Summary
    ----------------------------------------------------------------
    PROCEDURE Ics_Balance_Summary (errbuf            OUT VARCHAR2,
                                   retcode           OUT NUMBER,
                                   cAcct_Period   IN     VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
              select
               v.acct_period
              ,v.ent_curr
              ,v.Settlement_type
              --- Owner
              ,v.owner_Comp
              ,v.owner_Comp_Name
              ,v.type
              ,v.Owner_Account_Segment
              ,sum(v.Owner_AP) Owner_AP
              ,sum(v.Owner_AR) Owner_AR
              ,sum(v.Owner_AP_acct) Owner_AP_acct
              ,sum(v.Owner_AR_acct) Owner_AR_acct
              ,Owner_acct_Curr
              ,v.Owner_pay_curr
              ,v.status
              --- Partner
              ,v.Partner_Comp
              ,v.partner_Comp_Name
              ,v.Partner_Account_Segment
              ,sum(v.Partner_AP) Partner_AP
              ,sum(v.Partner_AR) Partner_AR
              ,sum(v.Partner_AP_acct) Partner_AP_acct
              ,sum(v.Partner_AR_acct) Partner_AR_acct
              ,v.Partner_acct_Curr
              ,v.Partner_pay_curr
              ---
              ,sum(v.Owner_AP) - sum(v.Partner_AR) AR_AP_Diff
              ,sum(v.Owner_AR) - sum(v.Partner_AP) AP_AR_Diff
              ----
              from xxcp_ics_recon_hdr_v v
              where v.acct_period = nvl(''' || cAcct_Period || ''',v.acct_period)
              and v.status not in (''Re-Classed'', ''Inactive'',''Interim'')
              group by
               v.acct_period
              ,v.ent_curr
              ,v.Settlement_type
              --- Owner
              ,v.owner_Comp
              ,v.owner_Comp_Name
              ,v.type
              ,v.Owner_Account_Segment
              ,Owner_acct_Curr
              ,v.Owner_pay_curr
              ,v.status
              --- Partner
              ,v.Partner_Comp
              ,v.partner_Comp_Name
              ,v.Partner_Account_Segment
              ,v.Partner_acct_Curr
              ,v.Partner_pay_curr
              order by
              abs(AR_AP_Diff) desc
              ,abs(AP_AR_Diff) desc
              ,v.acct_period
              ,v.ent_curr
              ,v.Settlement_type
              --- Owner
              ,v.owner_Comp
              ,v.owner_Comp_Name
              ,v.type
              ,v.Owner_Account_Segment
              ,Owner_acct_Curr
              ,v.Owner_pay_curr
              ,v.status
              --- Partner
              ,v.Partner_Comp
              ,v.partner_Comp_Name
              ,v.Partner_Account_Segment
              ,v.Partner_acct_Curr
              ,v.Partner_pay_curr') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Balance_Summary;

    ----------------------------------------------------------------
    -- Ics_Balance_Total
    ----------------------------------------------------------------
    PROCEDURE Ics_Balance_Total (errbuf            OUT VARCHAR2,
                                 retcode           OUT NUMBER,
                                 cAcct_Period   IN     VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
            select
             ent_curr
            ,sum(v.Owner_AP) Owner_AP
            ,sum(v.Owner_AR) Owner_AR
            ,sum(v.Partner_AP) Partner_AP
            ,sum(v.Partner_AR) Partner_AR
            ,sum(v.Owner_AP) - sum(v.Owner_AR) Owner_var
            ,sum(v.Partner_AP) - sum(v.Partner_AR) Partner_var
            from xxcp_ics_recon_hdr_v v
            where v.acct_period = nvl(''' || cAcct_Period || ''',v.acct_period)
            group by v.ent_curr
            order by v.ent_curr') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Balance_Total;

    ----------------------------------------------------------------
    -- Ics_Invoice_Listing
    ----------------------------------------------------------------
    PROCEDURE Ics_Invoice_Listing (errbuf            OUT VARCHAR2,
                                   retcode           OUT NUMBER,
                                   cAcct_Period   IN     VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
              select
               p.period_name
              ,tro.SHORT_CODE Owning_Comp, tro.DESCRIPTION Owning_Comp_Name
              , a.TRANSACTION_DATE, a.TRANSACTION_ID||a.trading_set_id Invoice_Identifier, a.transaction_ref1 VT_Transaction_Ref, a.transaction_ref3 Shipment_Num
              ,trp.SHORT_CODE Customer_Code, trp.DESCRIPTION Customer
              , st.Type, a.TRANSACTION_REF2 Item, a.QUANTITY, a.UOM
              ,a.IC_PRICE, a.IC_CURRENCY, (a.IC_PRICE * (1 + nvl(a.ADJUSTMENT_RATE,0))) Line_Value
              , (a.IC_PRICE * (1 + nvl(a.ADJUSTMENT_RATE,0)) * a.Quantity) Invoice_Value
              from xxcp_transaction_attributes a
              ,xxcp_tax_registrations tro
              ,xxcp_tax_registrations trp
              ,xxcp_sys_source_types st
              ,xxcp_source_assignments sa
              ,xxcp_instance_gl_periods_v p
              ,     (select ph.attribute_id, count(ph.attribute_id) AR_Count
                    from xxcp_process_history ph
                        ,xxcp_account_rules ar
                    where ph.rule_id = ar.rule_id
                    and ar.REPORT_SETTLEMENT_RULE = ''AR''
                    group by ph.attribute_id) ics
              where a.attribute_id = ics.attribute_id
              and ics.AR_Count > 0
              and a.OWNER_TAX_REG_ID = tro.TAX_REGISTRATION_ID
              and a.PARTNER_TAX_REG_ID = trp.TAX_REGISTRATION_ID
              and a.SOURCE_TYPE_ID = st.SOURCE_TYPE_ID
              and a.source_assignment_id = sa.source_assignment_id
              and a.TRANSACTION_DATE >= p.START_DATE
              and a.TRANSACTION_DATE <= p.END_DATE
              and p.PERIOD_NAME = ''' || cAcct_Period || '''
              order by
              tro.SHORT_CODE, trp.SHORT_CODE, st.Type, a.TRANSACTION_DATE, a.TRANSACTION_ID') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Invoice_Listing;

    ----------------------------------------------------------------
    -- Ics_GL_Recon
    ----------------------------------------------------------------
    PROCEDURE Ics_GL_Recon (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAcct_Period IN VARCHAR2 DEFAULT ''
                            , cConv_Type IN VARCHAR2 DEFAULT '', cConv_Date IN VARCHAR2 DEFAULT '', cPaired_Sorting IN VARCHAR2 DEFAULT 'N')
    IS
        vClob   CLOB;
    BEGIN
        xxcp_context.set_context ('acct_period', cAcct_Period);
        xxcp_context.set_context (
            'conv_date',
            NVL (fnd_date.canonical_to_date (cConv_Date), SYSDATE));
        xxcp_context.set_context ('conv_type', cConv_Type);
        xxcp_context.set_context ('Paired_Sorting',
                                  NVL (cPaired_Sorting, 'N'));

        SELECT DBMS_XMLGEN.getxml ('select  co,
                                       ic_pair,
                                       ap_ar_ind,
                                       co_name,
                                       co_acct_curr,
                                       ent_curr,
                                       trading_pair,
                                       acct,
                                       conversion_rate,
                                       max_segments,
                                       co_ar,
                                       co_ap,
                                       gl_balance,
                                       ent_diff,
                                       co_acct_ar,
                                       co_acct_ap,
                                       gl_balance_acct,
                                       order_by_amount
                                from xxcp_bi_ics_gl_recon_v v3
                                order by  v3.ic_pair,
                                          v3.order_by_amount,
                                          v3.ap_ar_ind,
                                          v3.Co,
                                          v3.Co_Name,
                                          v3.Co_acct_curr,
                                          v3.acct,
                                          v3.ent_curr') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_GL_Recon;

    ----------------------------------------------------------------
    -- Ics_GL_Recon (Summarized by segment)
    ----------------------------------------------------------------
    PROCEDURE Ics_GL_Recon_summ (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAcct_Period IN VARCHAR2 DEFAULT '', cConv_Type IN VARCHAR2 DEFAULT '', cConv_Date IN VARCHAR2 DEFAULT '', cSegment1 IN VARCHAR2 DEFAULT 'N', cSegment2 IN VARCHAR2 DEFAULT 'N', cSegment3 IN VARCHAR2 DEFAULT 'N', cSegment4 IN VARCHAR2 DEFAULT 'N', cSegment5 IN VARCHAR2 DEFAULT 'N', cSegment6 IN VARCHAR2 DEFAULT 'N', cSegment7 IN VARCHAR2 DEFAULT 'N'
                                 , cSegment8 IN VARCHAR2 DEFAULT 'N', cSegment9 IN VARCHAR2 DEFAULT 'N', cSegment10 IN VARCHAR2 DEFAULT 'N')
    IS
        vClob   CLOB;
    BEGIN
        -- Pass the parameters to the view using sys_context
        xxcp_context.set_context ('acct_period', cAcct_Period);
        xxcp_context.set_context (
            'conv_date',
            NVL (fnd_date.canonical_to_date (cConv_Date), SYSDATE));
        xxcp_context.set_context ('conv_type', cConv_Type);
        xxcp_context.set_context ('segment1', cSegment1);
        xxcp_context.set_context ('segment2', cSegment2);
        xxcp_context.set_context ('segment3', cSegment3);
        xxcp_context.set_context ('segment4', cSegment4);
        xxcp_context.set_context ('segment5', cSegment5);
        xxcp_context.set_context ('segment6', cSegment6);
        xxcp_context.set_context ('segment7', cSegment7);
        xxcp_context.set_context ('segment8', cSegment8);
        xxcp_context.set_context ('segment9', cSegment9);
        xxcp_context.set_context ('segment10', cSegment10);

        SELECT DBMS_XMLGEN.getxml ('select co,
                                      co_name,
                                      trading_pair,
                                      co_acct_curr,
                                      ent_curr,
                                      case when max_segments >= 1 then nvl(segment1,''*'') end||
                                      case when max_segments >= 2 then ''-''||nvl(segment2,''*'') end||
                                      case when max_segments >= 3 then ''-''||nvl(segment3,''*'') end||
                                      case when max_segments >= 4 then ''-''||nvl(segment4,''*'') end||
                                      case when max_segments >= 5 then ''-''||nvl(segment5,''*'') end||
                                      case when max_segments >= 6 then ''-''||nvl(segment6,''*'') end||
                                      case when max_segments >= 7 then ''-''||nvl(segment7,''*'') end||
                                      case when max_segments >= 8 then ''-''||nvl(segment8,''*'') end||
                                      case when max_segments >= 9 then ''-''||nvl(segment9,''*'') end||
                                      case when max_segments >= 10 then ''-''||nvl(segment10,''*'') end acct,
                                      co_Ar,
                                      co_Ap,
                                      ent_net_bal,
                                      gl_balance,
                                      ent_diff,
                                      co_Acct_ar,
                                      co_acct_ap,
                                      acc_Net_Bal,
                                      gl_balance_acct,
                                      conversion_rate
                                from  xxcp_bi_Ics_GL_Recon_summ_v
                               order by Co, Co_Name, Co_acct_curr, acct, ent_curr') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_GL_Recon_summ;

    ----------------------------------------------------------------
    -- Ics_YTD_GL_Recon (Summarized by segment)
    ----------------------------------------------------------------
    PROCEDURE Ics_YTD_GL_Recon (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAcct_Period IN VARCHAR2 DEFAULT '', cConv_Type IN VARCHAR2 DEFAULT '', cConv_Date IN VARCHAR2 DEFAULT '', cSegment1 IN VARCHAR2 DEFAULT 'N', cSegment2 IN VARCHAR2 DEFAULT 'N', cSegment3 IN VARCHAR2 DEFAULT 'N', cSegment4 IN VARCHAR2 DEFAULT 'N', cSegment5 IN VARCHAR2 DEFAULT 'N', cSegment6 IN VARCHAR2 DEFAULT 'N', cSegment7 IN VARCHAR2 DEFAULT 'N', cSegment8 IN VARCHAR2 DEFAULT 'N', cSegment9 IN VARCHAR2 DEFAULT 'N', cSegment10 IN VARCHAR2 DEFAULT 'N'
                                , cFile_Path IN VARCHAR2 DEFAULT '')
    IS
        vClob                CLOB;
        lv_period_end_date   VARCHAR2 (100);
        x_ret_code           NUMBER;
        x_ret_message        VARCHAR2 (4000);
    BEGIN
        -- Pass the parameters to the view using sys_context
        xxcp_context.set_context ('acct_period', cAcct_Period);
        xxcp_context.set_context (
            'conv_date',
            NVL (fnd_date.canonical_to_date (cConv_Date), SYSDATE));
        xxcp_context.set_context ('conv_type', cConv_Type);
        xxcp_context.set_context ('segment1', cSegment1);
        xxcp_context.set_context ('segment2', cSegment2);
        xxcp_context.set_context ('segment3', cSegment3);
        xxcp_context.set_context ('segment4', cSegment4);
        xxcp_context.set_context ('segment5', cSegment5);
        xxcp_context.set_context ('segment6', cSegment6);
        xxcp_context.set_context ('segment7', cSegment7);
        xxcp_context.set_context ('segment8', cSegment8);
        xxcp_context.set_context ('segment9', cSegment9);
        xxcp_context.set_context ('segment10', cSegment10);

        SELECT DBMS_XMLGEN.getxml ('select sys_context(''XXCP_CONTEXT'', ''conv_type'') p_conv_type,
        sys_context(''XXCP_CONTEXT'', ''conv_date'') p_conv_date,
        sys_context(''XXCP_CONTEXT'', ''acct_period'') p_acct_period,
        sys_context(''XXCP_CONTEXT'', ''segment1'') p_segment1,
        sys_context(''XXCP_CONTEXT'', ''segment2'') p_segment2,
        sys_context(''XXCP_CONTEXT'', ''segment3'') p_segment3,
        sys_context(''XXCP_CONTEXT'', ''segment4'') p_segment4,
        sys_context(''XXCP_CONTEXT'', ''segment5'') p_segment5,
        sys_context(''XXCP_CONTEXT'', ''segment6'') p_segment6,
        sys_context(''XXCP_CONTEXT'', ''segment7'') p_segment7,
        sys_context(''XXCP_CONTEXT'', ''segment8'') p_segment8,
        sys_context(''XXCP_CONTEXT'', ''segment9'') p_segment9,
        sys_context(''XXCP_CONTEXT'', ''segment10'') p_segment10,
        cursor( select co,
                co_name,
                trading_pair,
                co_acct_curr,
                ent_curr,
                case when max_segments >= 1 then nvl(segment1,''*'') end||
                case when max_segments >= 2 then ''-''||nvl(segment2,''*'') end||
                case when max_segments >= 3 then ''-''||nvl(segment3,''*'') end||
                case when max_segments >= 4 then ''-''||nvl(segment4,''*'') end||
                case when max_segments >= 5 then ''-''||nvl(segment5,''*'') end||
                case when max_segments >= 6 then ''-''||nvl(segment6,''*'') end||
                case when max_segments >= 7 then ''-''||nvl(segment7,''*'') end||
                case when max_segments >= 8 then ''-''||nvl(segment8,''*'') end||
                case when max_segments >= 9 then ''-''||nvl(segment9,''*'') end||
                case when max_segments >= 10 then ''-''||nvl(segment10,''*'') end acct,
                co_Ar,
                co_Ap,
                ent_net_bal,
                gl_balance,
                ent_diff,
                co_Acct_ar,
                co_acct_ap,
                acc_Net_Bal,
                gl_balance_acct,
                conversion_rate
          from  xxcp_bi_Ics_ytd_GL_Recon_v
         order by Co, Co_Name, Co_acct_curr, acct, ent_curr) data
         from dual') xml
          INTO vClob
          FROM DUAL;

        -- query to get period end date
        BEGIN
            SELECT TO_CHAR (end_date, 'MM/DD/YYYY')
              INTO lv_period_end_date
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_name = cAcct_Period;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_period_end_date   := NULL;
        END;

        --
        BEGIN
            INSERT INTO xxdo.xxd_gl_vt_ics_gl_ytd_recon_t
                  SELECT co,
                         co_name,
                         trading_pair,
                         co_acct_curr,
                         ent_curr,
                            CASE
                                WHEN max_segments >= 1 THEN NVL (segment1, '*')
                            END
                         || CASE
                                WHEN max_segments >= 2
                                THEN
                                    '-' || NVL (segment2, '*')
                            END
                         || CASE
                                WHEN max_segments >= 3
                                THEN
                                    '-' || NVL (segment3, '*')
                            END
                         || CASE
                                WHEN max_segments >= 4
                                THEN
                                    '-' || NVL (segment4, '*')
                            END
                         || CASE
                                WHEN max_segments >= 5
                                THEN
                                    '-' || NVL (segment5, '*')
                            END
                         || CASE
                                WHEN max_segments >= 6
                                THEN
                                    '-' || NVL (segment6, '*')
                            END
                         || CASE
                                WHEN max_segments >= 7
                                THEN
                                    '-' || NVL (segment7, '*')
                            END
                         || CASE
                                WHEN max_segments >= 8
                                THEN
                                    '-' || NVL (segment8, '*')
                            END
                         || CASE
                                WHEN max_segments >= 9
                                THEN
                                    '-' || NVL (segment9, '*')
                            END
                         || CASE
                                WHEN max_segments >= 10
                                THEN
                                    '-' || NVL (segment10, '*')
                            END acct,
                         co_Ar,
                         co_Ap,
                         ent_net_bal,
                         gl_balance,
                         ent_diff,
                         co_Acct_ar,
                         co_acct_ap,
                         acc_Net_Bal,
                         gl_balance_acct,
                         conversion_rate,
                         segment1,
                         segment6,
                         segment2,
                         segment3,
                         segment4,
                         segment5,
                         segment7,
                         NULL,
                         NULL,
                         NULL,
                         lv_period_end_date,
                         NULL,
                         NULL,
                         acc_Net_Bal,
                         gn_user_id,
                         SYSDATE,
                         gn_user_id,
                         SYSDATE,
                         gn_request_id
                    FROM xxcp_bi_Ics_ytd_GL_Recon_v
                ORDER BY Co, Co_Name, Co_acct_curr,
                         acct, ent_curr;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Failed to insert into the custom table:' || SQLERRM);
        END;

        write_vt_output (gn_request_id, cFile_Path, cAcct_Period,
                         x_ret_code, x_ret_message);
        write_VT_file (cFile_Path, gn_request_id, x_ret_code,
                       x_ret_message);
    --

    --  printClobOut(vClob);

    END Ics_YTD_GL_Recon;


    ----------------------------------------------------------------
    -- Ics_Day_Aged_By_Status
    ----------------------------------------------------------------
    PROCEDURE Ics_Day_Aged_By_Status (errbuf OUT VARCHAR2, retcode OUT NUMBER, cCompany IN VARCHAR2 DEFAULT ''
                                      , cRun_Date IN VARCHAR2 DEFAULT '')
    IS
        vClob       CLOB;
        vRun_Date   DATE;
    BEGIN
        vRun_Date   := NVL (fnd_date.canonical_to_date (cRun_Date), SYSDATE);

        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
                  select v.owner_comp, v.owner_comp_Name, v.ent_curr
                  , Case When v.status in (''Approved'', ''Pending Payment'') Then ''Approved''
                         When v.Acct_type_ind = ''LT'' Then ''Long Term''
                         Else ''Outstanding'' End Status
                  , sum(nvl(owner_AR,0)) owner_Tot_AR
                  , sum(nvl(owner_AP,0)) owner_Tot_AP
                  ---------
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE <= 30
                     Then v.owner_AP
                     Else 0 End) owner_ST_AP_30
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE between 31 and 60
                     Then v.owner_AP
                     Else 0 End) owner_ST_AP_60
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE between 61 and 90
                     Then v.owner_AP
                     Else 0 End) owner_ST_AP_90
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE > 90
                     Then v.owner_AP
                     Else 0 End) owner_ST_AP_GTR
                  ---
                  , v.partner_comp, v.partner_comp_name
                  , sum(nvl(Partner_AR,0)) Partner_Tot_AR
                  , sum(nvl(Partner_AP,0)) Partner_Tot_AP
                  ---------
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE <= 30
                     Then v.Partner_AP
                     Else 0 End) Partner_ST_AP_30
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE between 31 and 60
                     Then v.Partner_AP
                     Else 0 End) Partner_ST_AP_60
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE between 61 and 90
                     Then v.Partner_AP
                     Else 0 End) Partner_ST_AP_90
                  , Sum(Case When to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''', ''DD-MON-YYYY'') - v.ACCOUNTING_DATE > 90
                     Then v.Partner_AP
                     Else 0 End) Partner_ST_AP_GTR
                  ---
                  from  xxcp_ics_recon_det_v v
                  ---
                  where v.owner_comp = nvl(''' || cCompany || ''',v.owner_comp)
                  and v.status not in (''Re-Classed'', ''Inactive'', ''Interim'')
                  ---
                  group by v.owner_comp, v.owner_comp_Name
                  , Case When v.status in (''Approved'', ''Pending Payment'') Then ''Approved''
                         When v.Acct_type_ind = ''LT'' Then ''Long Term''
                         Else ''Outstanding'' End
                  , v.ent_curr, v.partner_comp, v.partner_comp_name
                  order by v.owner_comp, v.owner_comp_Name
                  , Case When v.status in (''Approved'', ''Pending Payment'') Then ''Approved''
                         When v.Acct_type_ind = ''LT'' Then ''Long Term''
                         Else ''Outstanding'' End
                  , v.ent_curr, v.partner_comp, v.partner_comp_name') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Day_Aged_By_Status;

    ----------------------------------------------------------------
    -- Ics_Report_Entered
    ----------------------------------------------------------------
    PROCEDURE Ics_Report_Entered (errbuf        OUT VARCHAR2,
                                  retcode       OUT NUMBER,
                                  cCompany   IN     VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
            select v.request_id Pay_Batch, v.owner_comp, v.owner_Comp_Name, v.ent_curr, v.settlement_type
            , sum(nvl(owner_AR,0)) owner_Tot_AR
            , Sum(Case When v.status in (''Approved'', ''Pending Payment'')
               Then nvl(owner_AR,0)
               Else 0 End) owner_AR_App
            , Sum(Case When NOT v.status in (''Approved'', ''Pending Payment'')
               Then nvl(owner_AR,0)
               Else 0 End) owner_AR_Not_App
            --
            , sum(nvl(owner_AP,0)) owner_Tot_AP
            , Sum(Case When v.status in (''Approved'', ''Pending Payment'')
               Then nvl(owner_AP,0)
               Else 0 End) owner_AP_App
            , Sum(Case When NOT v.status in (''Approved'', ''Pending Payment'')
               Then nvl(owner_AP,0)
               Else 0 End) owner_AP_Not_App
            , Sum(Case When v.acct_type_ind = ''ST''
               And v.status = ''Rejected''
               Then nvl(owner_AP,0)
               Else 0 End) owner_ST_AP_Rej
            , Sum(Case When v.acct_type_ind = ''ST''
               And v.status = ''New''
               Then nvl(owner_AP,0)
               Else 0 End) owner_ST_AP_New
            , Sum(Case When v.status = ''Pending Re-Class''
               Then nvl(owner_AP,0)
               Else 0 End) owner_ST_AP_Reclass
            , Sum(Case When v.acct_type_ind = ''LT''
               Then nvl(owner_AP,0)
               Else 0 End) owner_AP_LT
            ---
            , Sum(Case When v.status in (''Approved'', ''Pending Payment'')
               Then nvl(owner_AP,0) - nvl(partner_AP,0)
               Else 0 End) owner_Pay_Net
            ---
            , v.partner_comp, v.partner_comp_Name
            , sum(nvl(partner_AR,0)) partner_Tot_AR
            , Sum(Case When v.status in (''Approved'', ''Pending Payment'')
               Then nvl(partner_AR,0)
               Else 0 End) partner_AR_App
            , Sum(Case When NOT v.status in (''Approved'', ''Pending Payment'')
               Then nvl(partner_AR,0)
               Else 0 End) partner_AR_Not_App
            --
            , sum(nvl(partner_AP,0)) partner_Tot_AP
            , Sum(Case When v.status in (''Approved'', ''Pending Payment'')
               Then nvl(partner_AP,0)
               Else 0 End) partner_AP_App
            , Sum(Case When NOT v.status in (''Approved'', ''Pending Payment'')
               Then nvl(partner_AP,0)
               Else 0 End) partner_AP_Not_App
            , Sum(Case When v.status = ''Rejected''
               Then nvl(partner_AP,0)
               Else 0 End) partner_AP_Rej
            , Sum(Case When v.status = ''New''
               Then nvl(partner_AP,0)
               Else 0 End) partner_AP_New
            , Sum(Case When v.status = ''Pending Re-Class''
               Then nvl(partner_AP,0)
               Else 0 End) partner_AP_Reclass
            , Sum(Case When v.acct_type_ind = ''LT''
               Then nvl(partner_AP,0)
               Else 0 End) partner_AP_LT
            ---
            , Sum(Case When v.status in (''Approved'', ''Pending Payment'')
               Then nvl(partner_AP,0) - nvl(owner_AP,0)
               Else 0 End) partner_Pay_Net
            ---
            from  xxcp_ics_recon_hdr_v  v
            ---
            where v.owner_comp = nvl(''' || cCompany || ''',v.owner_comp)
            ---
            group by v.request_id, v.owner_comp, v.owner_Comp_Name, v.ent_curr
            , v.settlement_type, v.partner_comp, v.partner_comp_Name
            order by v.request_id, v.owner_comp, v.owner_Comp_Name, v.ent_curr
            , v.settlement_type, v.partner_comp, v.partner_comp_Name
            ') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Report_Entered;

    PROCEDURE Ics_payment_data_sheet (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAP_short_code IN VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        SELECT DBMS_XMLGEN.getxml ('
      select t1.description                   "Payer_Company_Name"
            ,t1.short_code                    "Payer_Tax_Reg_Code"
            ,t2.description                   "Payee_Company_Name"
            ,t2.short_code                    "Payee_Tax_Reg_Code"
            ,h.acct_period                    "Accounting_Period"
            ,d.transaction_ref                "Transaction_Reference"
            ,abs(d.entered_amount)            "Amount_to_pay"
            ,h.currency_code                  "Currency"
            ,h.account_segment                "Account_String"
            ,h.ics_group_id                   "ICS_Summary_Group_ID"
            ,h.classification                 "Classification"
            ,d.ics_line_group_id              "ICS_Line_Group_ID"
            ,d.attribute10                    "ICS_Attribute10"
            ,d.accounting_date                "Accounting_Date"
            ,r.reference_note                 "Summary_Notes"
      from   xxcp_ic_settlement_hdr        h,
             xxcp_ic_settlement_det        d,
             xxcp_ic_settlement_references r,
             xxcp_tax_registrations        t1,
             xxcp_tax_registrations        t2
      where  h.ics_id = d.ics_id
      and    t1.tax_registration_id = h.owner_tax_reg_id
      and    t2.tax_registration_id = h.partner_tax_reg_id
      and    h.status = ''Approved''
      and    h.ap_ar_ind = ''AP''
      and    h.ics_group_id = r.ics_group_id
      and    t1.short_code = nvl(''' || cAP_short_code || ''',t1.short_code)
      order by
             t1.description
            ,t2.description
            ,h.acct_period
            ,h.currency_code
            ,h.account_segment
            ,h.ics_group_id
            ,d.transaction_ref
            ,d.attribute10
      ') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_payment_data_sheet;

    PROCEDURE Mtch_det_inv_extract (
        errbuf                  OUT VARCHAR2,
        retcode                 OUT NUMBER,
        cTransaction_Ref     IN     VARCHAR2 DEFAULT '',
        cTransaction_Class   IN     VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
    BEGIN
        SELECT DBMS_XMLGEN.getxml ('
        select  i.reference4                  "Commercial_Invoice_Number",
  i.vt_interface_id             "VT_Interface_ID",
  i.vt_status                   "VT_Status",
  i.vt_status_code              "VT_Status_Code",
  i.vt_source_assignment_id     "VT_Source_Assignment ID",
  i.vt_transaction_table        "VT_Trx_Table",
  i.vt_transaction_type         "VT_Trx_Type",
  i.vt_transaction_class        "VT_Trx_Class",
  i.vt_transaction_ref          "VT_Transaction_Ref",
  i.vt_transaction_id           "VT_Transaction_ID",
  i.vt_parent_trx_id            "VT_Parent Trx_ID",
  i.vt_internal_error_code      "VT_Internal_Error_Code",
  i.vt_transaction_date         "Invoice_Creation_Date",
  i.date_created                "Date_Created_in_VT",
  i.currency_conversion_date    "Invoice_Exchange_Rate_Date",
  i.segment1                    "Segment1",
  i.segment2                    "Segment2",
  i.segment3                    "Segment3",
  i.segment4                    "Segment4",
  i.segment5                    "Segment5",
  i.segment6                    "Segment6",
  i.segment7                    "Segment7",
  i.segment8                    "Segment8",
  i.segment9                    "Segment9",
  i.segment10                   "Segment10",
  i.segment11                   "Segment11",
  i.segment12                   "Segment12",
  i.segment13                   "Segment13",
  i.segment14                   "Segment14",
  i.segment15                   "Segment15",
  decode(i.entered_dr
        ,null
        ,i.entered_cr||'' CR''
        ,i.entered_dr||'' DR''
        )                       "Invoice_Line_Value",
  i.currency_code               "Currency_Code",
  i.reference17                 "Total_Invoice_Value",
  i.reference1                  "Sales_Order_Number",
  i.reference2                  "Sales_Order_Line_Number",
  i.reference3                  "Shipment_Number",
  i.reference5                  "Source_System_Invoice_Number",
  i.reference6                  "Source_System",
  i.reference7                  "Ship_From_Division",
  i.reference8                  "Ship_To_Division",
  i.reference9                  "Quantity",
  i.reference18                 "Unit_of_Measure",
  i.reference10                 "Part_Number",
  i.reference21                 "Item_Description",
  i.reference11                 "Part_Num_in_the_Source_System",
  i.reference12                 "Purchase_Order_Number",
  i.reference13                 "Purchase_Order_Line_Number",
  i.reference14                 "Ship_Date",
  i.reference15                 "Receipt_Date",
  i.reference16                 "Receipt_Number",
  i.reference22                 "Vendor_Name",
  i.reference23                 "Alternate_Vendor_Name",
  i.reference24                 "Vendor_ID",
  i.reference25                 "Customer_Name",
  i.reference26                 "Alternate_Customer_Name",
  i.reference27                 "Customer_ID",
  i.period_name                 "Accounting_Period"
from    xxcp_gl_interface  i
where   i.vt_transaction_ref = ''' || cTransaction_Ref || '''
and     i.vt_transaction_class = nvl(''' || cTransaction_Class || ''',i.vt_transaction_class)
and     i.vt_source_assignment_id in (select source_assignment_id
                                from   xxcp_source_assignments
                                where  source_id = 37)
order by i.vt_transaction_class,
   i.reference10
               ') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Mtch_det_inv_extract;

    PROCEDURE Mtch_inv_discrep (errbuf OUT VARCHAR2, retcode OUT NUMBER, cOwner_short_code IN VARCHAR2 DEFAULT ''
                                , cPartner_short_code IN VARCHAR2 DEFAULT '')
    IS
        vClob   CLOB;
        vSQL    VARCHAR2 (32767);
    BEGIN
        vSQL    :=
               'WITH head_assign_error as
          (
          select sa.source_assignment_id,
                 sa.source_assignment_name,
                 h.parent_trx_id,
                 h.transaction_id,
                 h.source_table,
                 h.partner_legal_name,
                 h.owner_legal_name,
                 h.owner_taxreg_name,
                 h.partner_taxreg_name
          from   xxcp_gateway_headers_v          h,
                 xxcp_gateway_assignment_v       sa
          Where  h.source_id = 37
          and    h.source_id            = sa.source_id
          and    h.source_assignment_id = sa.source_assignment_id
          and    h.owner_taxreg_name   = nvl('''
            || cOwner_short_code
            || ''',h.owner_taxreg_name)
          and    h.partner_taxreg_name = nvl('''
            || cPartner_short_code
            || ''',h.partner_taxreg_name)
          ),
          interface_error as
          (
          select i.*,
                 err.internal_error_code,
                 err.description error_description,
                 err.error_id
          from   xxcp_gl_interface i,
                 xxcp_gateway_errors_v err
          where  i.vt_status = ''ERROR''
          and    i.vt_source_assignment_id = err.source_assignment_id (+)
          and    i.vt_parent_trx_id        = err.parent_trx_id        (+)
          and    i.vt_transaction_id       = err.transaction_id       (+)
          -- Source 37
          and    i.vt_source_assignment_id in (select source_assignment_id
                                               from   xxcp_source_assignments
                                               where  source_id = 37)
          -- Get Last Error Message (suppress duplicates)
          and    (err.error_id is null
                  or
                  err.error_id              = (select max(error_id)
                                               from   xxcp_gateway_errors_v e2
                                               where  err.source_assignment_id = e2.source_assignment_id
                                               and    err.parent_trx_id        = e2.parent_trx_id
                                               and    err.transaction_id       = e2.transaction_id)
                 )
          )
          select
          i.vt_transaction_table "Invoice_Trx_Table",
          i.vt_transaction_ref "Commercial_Inv_Number",
          nvl(i.error_description,xxcp_gateway_utils.Internal_Error_Message(i.vt_internal_error_code)) "Discrepancy_Reason",
          decode(i.vt_transaction_class,''REC'',i.vt_transaction_date,null)  "AR_Invoice_Creation_Date",
          decode(i.vt_transaction_class,''PAY'',i.vt_transaction_date,null)  "AP_Invoice_Creation_Date",
          decode(i.vt_transaction_class,''REC'',i.reference6,null)           "AR_Source_System",
          decode(i.vt_transaction_class,''PAY'',i.reference6,null)           "AP_Source_System",
          decode(i.vt_transaction_class,''REC'',i.reference5,null)           "AR_Source_System_Inv_Number",
          decode(i.vt_transaction_class,''PAY'',i.reference5,null)           "AP_Source_System_Inv_Number",
          hae.owner_legal_name "Ship_From_Company",
          hae.partner_legal_name "Ship_To_Company",
          decode(i.vt_transaction_class,''REC'',reference7,null)             "Ship_From_Division",
          decode(i.vt_transaction_class,''PAY'',reference8,null)             "Ship_To_Division",
          hae.source_assignment_name "VT_Source_Assignment",
          decode(i.vt_transaction_class,''REC'',i.reference17,null)          "AR_Invoice_Value",
          decode(i.vt_transaction_class,''PAY'',i.reference17,null)          "AP_Invoice_Value",
          decode(i.vt_transaction_class,''REC'',i.currency_code,null)        "AR_Invoice_Currency",
          decode(i.vt_transaction_class,''PAY'',i.currency_code,null)        "AP_Invoice_Currency",
          decode(i.vt_transaction_class,''REC'',i.reference19,null)          "AR_Mapped_Part_Number",
          decode(i.vt_transaction_class,''PAY'',i.reference19,null)          "AP_Mapped_Part_Number",
          decode(i.vt_transaction_class,''REC'',i.reference10,null)          "AR_Orig_Part_Number",
          decode(i.vt_transaction_class,''PAY'',i.reference10,null)          "AP_Orig_Part_Number",
          decode(i.vt_transaction_class,''REC'',i.reference21,null)          "AR_Item_Description",
          decode(i.vt_transaction_class,''PAY'',i.reference21,null)          "AP_Item_Description",
          decode(i.vt_transaction_class,''REC'',i.reference9,null)           "Quantity_AR_Inv",
          decode(i.vt_transaction_class,''PAY'',i.reference9,null)           "Quantity_AP_Inv",
          decode(i.vt_transaction_class,''REC'',i.reference18,null)          "UOM_AR_Inv",
          decode(i.vt_transaction_class,''PAY'',i.reference18,null)          "UOM_AP_Inv",
          decode(i.vt_transaction_class,''REC'',nvl(i.entered_dr,0)-
                                              nvl(i.entered_cr,0),null)    "Line_Value_AR_Inv",
          decode(i.vt_transaction_class,''PAY'',nvl(i.entered_cr,0)-
                                              nvl(i.entered_dr,0),null)    "Line_Value_AP_Inv",
          i.reference1 "Sales_Order_Number",
          i.reference12 "Purchase_Order_Number",
          i.reference14 "Ship_Date",
          i.reference15 "Receipt_Date",
          i.reference16 "Receipt_Number",
          i.reference28 "User_Notes_1",
          i.reference29 "User_Notes_2",
          i.reference30 "User_Notes_3"
          from   interface_error i,
                 head_assign_error hae
          where  i.vt_transaction_table    = ''IC TRADE''
          and    i.vt_source_assignment_id = hae.source_assignment_id (+)
          and    i.vt_parent_trx_id        = hae.parent_trx_id (+)
          and    i.vt_transaction_id       = hae.transaction_id (+)
          and    i.vt_transaction_table    = hae.source_table (+)
          and    nvl(hae.owner_taxreg_name,''~NULL~'') = nvl(nvl('''
            || cOwner_short_code
            || ''',hae.owner_taxreg_name),''~NULL~'')
          and    nvl(hae.partner_taxreg_name,''~NULL~'') = nvl(nvl('''
            || cPartner_short_code
            || ''',hae.partner_taxreg_name),''~NULL~'')
          ';

        vClob   := DBMS_XMLGEN.getxml (vSQL);

        printClobOut (vClob);
    END Mtch_inv_discrep;

    PROCEDURE Mtch_sum_intr_bal (errbuf OUT VARCHAR2, retcode OUT NUMBER)
    IS
        vClob   CLOB;
    BEGIN
        SELECT DBMS_XMLGEN.getxml ('select   case when i.vt_transaction_class = ''REC''
              then h.owner_legal_name
              else h.partner_legal_name
         end                                            "Company",
         case when i.vt_transaction_class = ''REC''
              then ota.target_set_of_books
              else pta.target_set_of_books
         end                                            "Set_of_Books_Name",
         case when i.vt_transaction_class = ''REC''
              then ota.target_set_of_books_id
              else pta.target_set_of_books_id
         end                                            "Set_of_Books_ID",
         i.period_name                                  "Period",
         i.segment1,
         i.segment2,
         i.segment3,
         i.segment4,
         i.segment5,
         i.segment6,
         i.segment7,
         i.segment8,
         i.segment9,
         i.segment10,
         i.segment11,
         i.segment12,
         i.segment13,
         i.segment14,
         i.segment15,
         sum(nvl(i.entered_dr,0) - nvl(i.entered_cr,0)) "Amount",
         i.currency_code                                "Invoice_Currency"
from    xxcp_gl_interface            i,
        xxcp_gateway_headers_v       h,
        xxcp_gateway_assignment_v    sa,
        xxcp_tax_registrations       otr,
        xxcp_tax_registrations       ptr,
        xxcp_target_assignments      ota,
        xxcp_target_assignments      pta
where   i.vt_transaction_table = h.source_table
and     h.source_id = 37
---
and     i.vt_status in (''WAITING'',''ERROR'')
and     i.vt_source_assignment_id = sa.source_assignment_id
and     sa.source_id = 37
---
and     h.source_assignment_id = i.vt_source_assignment_id
and     h.parent_trx_id = i.vt_parent_trx_id
and     h.transaction_id = i.vt_transaction_id
---
and     otr.tax_registration_id = h.owner_tax_reg
and     ptr.tax_registration_id = h.partner_tax_reg
and     ota.reg_id = otr.reg_id
and     pta.reg_id = ptr.reg_id
---
group by case when i.vt_transaction_class = ''REC''
              then h.owner_legal_name
              else h.partner_legal_name
         end,
         case when i.vt_transaction_class = ''REC''
              then ota.target_set_of_books
              else pta.target_set_of_books
         end,
         case when i.vt_transaction_class = ''REC''
              then ota.target_set_of_books_id
              else pta.target_set_of_books_id
         end,
         i.period_name,
         i.segment1,
         i.segment2,
         i.segment3,
         i.segment4,
         i.segment5,
         i.segment6,
         i.segment7,
         i.segment8,
         i.segment9,
         i.segment10,
         i.segment11,
         i.segment12,
         i.segment13,
         i.segment14,
         i.segment15,
         i.currency_code
order by case when i.vt_transaction_class = ''REC''
              then h.owner_legal_name
              else h.partner_legal_name
         end,
         i.period_name,
         i.segment1,
         i.segment2,
         i.segment3,
         i.segment4,
         i.segment5,
         i.segment6,
         i.segment7,
         i.segment8,
         i.segment9,
         i.segment10,
         i.segment11,
         i.segment12,
         i.segment13,
         i.segment14,
         i.segment15,
         i.currency_code') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Mtch_sum_intr_bal;

    PROCEDURE Mtch_unmatched_inv (
        errbuf                     OUT VARCHAR2,
        retcode                    OUT NUMBER,
        cSource_Assignment_id   IN     NUMBER DEFAULT NULL,
        cOwner_short_code       IN     VARCHAR2 DEFAULT '',
        cPartner_short_code     IN     VARCHAR2 DEFAULT '')
    IS
        vClob                   CLOB;
        vSource_Assignment_id   VARCHAR2 (30);
    BEGIN
        IF cSource_Assignment_id IS NULL
        THEN
            vSource_Assignment_id   := 'Null';
        ELSE
            vSource_Assignment_id   := TO_CHAR (cSource_Assignment_id);
        END IF;

        SELECT DBMS_XMLGEN.getxml ('select  i.vt_transaction_table                                   "Invoice_Trx_Table",
              i.vt_transaction_class                                   "Invoice_Class",
              i.vt_transaction_type                                    "Invoice_Type",
              i.vt_transaction_ref                                     "Commercial_Inv_Number",
              i.vt_transaction_date                                    "Inv_Creation_Date",
              trunc(i.vt_created_date)                                 "VT_Creation_Date",
              i.reference6                                             "Source_System",
              i.reference5                                             "Source_System_Invoice_Number",
              h.owner_legal_name                                       "Ship_From_Company",
              h.partner_legal_name                                     "Ship_To_Company",
              decode(i.vt_transaction_class,''REC'',reference7,null)   "Ship_From_Division",
              decode(i.vt_transaction_class,''PAY'',reference8,null)   "Ship_To_Division",
              i.reference22                                            "Supplier_Name",
              i.reference25                                            "Customer_Name",
              sa.source_assignment_name                                "VT_Source_Assignment",
              sum(nvl(i.entered_dr,0) - nvl(i.entered_cr,0))           "Invoice_Value",
              i.currency_code                                          "Invoice_Currency"
      from    xxcp_gl_interface            i,
              xxcp_gateway_headers_v          h,
              xxcp_gateway_assignment_v       sa
      where   i.vt_transaction_table = h.source_table(+)
      ---
      and     i.vt_status = ''WAITING''
      and     i.vt_source_assignment_id = sa.source_assignment_id
      ---
      and     h.source_assignment_id(+) = i.vt_source_assignment_id
      and     h.parent_trx_id(+) = i.vt_parent_trx_id
      and     h.transaction_id(+) = i.vt_transaction_id
      ---
      and     i.vt_source_assignment_id = nvl(' || vSource_Assignment_id || ',i.vt_source_assignment_id)
      and     decode(''' || cOwner_short_code || ''',  null, ''X'',h.owner_taxreg_name(+))   = decode(''' || cOwner_short_code || ''',  null,''X'',''' || cOwner_short_code || ''')
      and     decode(''' || cPartner_short_code || ''',null, ''X'',h.partner_taxreg_name(+)) = decode(''' || cPartner_short_code || ''',null,''X'',''' || cPartner_short_code || ''')
      ---
      group by i.vt_transaction_table,
               i.vt_transaction_class,
               i.vt_transaction_type,
               i.vt_transaction_ref,
               i.vt_transaction_date,
               trunc(i.vt_created_date),
               i.reference6,
               i.reference5,
               h.owner_legal_name,
               h.partner_legal_name,
               decode(i.vt_transaction_class,''REC'',reference7,null),
               decode(i.vt_transaction_class,''PAY'',reference8,null),
               i.reference22,
               i.reference25,
               sa.source_assignment_name,
               i.currency_code
      order by trunc(i.vt_created_date),
               i.vt_transaction_table,
               sa.source_assignment_name,
               h.owner_legal_name,
               h.partner_legal_name,
               decode(i.vt_transaction_class,''REC'',reference7,null),
               decode(i.vt_transaction_class,''PAY'',reference8,null),
               i.vt_transaction_ref,
               i.vt_transaction_class,
               i.vt_transaction_type,
               i.currency_code') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Mtch_unmatched_inv;

    --
    -- IC Invoice
    --
    PROCEDURE IC_Invoice (errbuf                     OUT VARCHAR2,
                          retcode                    OUT NUMBER,
                          cInvoiceType            IN     VARCHAR2,
                          cSource_id              IN     VARCHAR2,
                          cSource_group_id        IN     VARCHAR2,
                          cSource_assignment_id   IN     VARCHAR2,
                          cInvoiceTaxReg          IN     VARCHAR2,
                          cCustomerTaxReg         IN     VARCHAR2,
                          cInvoice_Number_From    IN     VARCHAR2,
                          cInvoice_Number_To      IN     VARCHAR2,
                          cPurchase_Order         IN     VARCHAR2,
                          cSales_Order            IN     VARCHAR2,
                          cInvoice_Date_Low       IN     VARCHAR2,
                          cInvoice_Date_High      IN     VARCHAR2,
                          cProduct_Family         IN     VARCHAR2,
                          cUnPrinted_Flag         IN     VARCHAR2,
                          cInvoice_class          IN     VARCHAR2)
    IS
        vClob      CLOB;
        vDummy     BOOLEAN;
        vCounter   PLS_INTEGER;

        -- OOD-641 capture all un-printed invoices that match given parameters
        CURSOR curNotPrinted (pInvoiceTaxReg IN PLS_INTEGER, pCustomerTaxReg IN PLS_INTEGER, pInvoice_Number_From IN VARCHAR2, pInvoice_Number_To IN VARCHAR2, pPurchaseOrder IN VARCHAR2, pSalesOrder IN VARCHAR2, pProductFamily IN VARCHAR2, pInvoiceDateLow IN VARCHAR2, pInvoiceDateHigh IN VARCHAR2
                              , pInvoice_class IN VARCHAR2)
        IS
            SELECT a.invoice_header_id, a.invoice_tax_reg_id, a.customer_tax_reg_id
              FROM xxcp_ic_inv_header a
             WHERE     NVL (a.invoice_tax_reg_id, 0) =
                       NVL (pInvoiceTaxReg, NVL (a.invoice_tax_reg_id, 0))
                   AND NVL (a.customer_tax_reg_id, 0) =
                       NVL (pCustomerTaxReg, NVL (a.customer_tax_reg_id, 0))
                   AND NVL (a.invoice_class, '~null~') =
                       NVL (pInvoice_class, NVL (a.Invoice_class, '~null~'))
                   AND a.invoice_header_id IN
                           (SELECT b.invoice_header_id
                              FROM xxcp_instance_ic_inv_v b
                             WHERE     NVL (b.po_number, '~null~') =
                                       NVL (pPurchaseOrder,
                                            NVL (b.po_number, '~null~'))
                                   AND NVL (b.so_number, '~null~') =
                                       NVL (pSalesOrder,
                                            NVL (b.so_Number, '~null~'))
                                   AND NVL (b.product_family, '~null~') =
                                       NVL (pProductFamily,
                                            NVL (b.product_family, '~null~'))
                                   -- VT273-437 Only select headers that have not been printed for this run
                                   AND a.printed_flag = 'N'
                                   AND NVL (b.invoice_number, '~null~') BETWEEN NVL (
                                                                                    pInvoice_Number_From,
                                                                                    NVL (
                                                                                        b.invoice_number,
                                                                                        '~null~'))
                                                                            AND NVL (
                                                                                    pInvoice_Number_To,
                                                                                    NVL (
                                                                                        b.invoice_number,
                                                                                        '~null~'))
                                   AND a.invoice_date BETWEEN NVL (
                                                                  TO_DATE (
                                                                      pInvoiceDateLow,
                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                  TRUNC (
                                                                      b.invoice_date))
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      pInvoiceDateHigh,
                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                  TRUNC (
                                                                      b.invoice_date)))
                   AND a.invoice_header_id IN
                           (SELECT c.header_id
                              FROM xxcp_instance_ic_inv_comp_v c
                             WHERE     NVL (a.invoice_tax_reg_id, 0) =
                                       NVL (pInvoiceTaxReg,
                                            NVL (c.comp_tax_reg_id, 0))
                                   AND NVL (a.customer_tax_reg_id, 0) =
                                       NVL (pCustomerTaxReg,
                                            NVL (c.cust_tax_reg_id, 0)));
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'XXCP_BI_PUB.IC_Invoice Parameters Entered');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice type:         ' || NVL (cInvoiceType, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice tax reg:      ' || NVL (cInvoiceTaxReg, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Customer tax reg:     ' || NVL (cCustomerTaxReg, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice number from:  ' || NVL (cInvoice_Number_From, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice number to:    ' || NVL (cInvoice_Number_To, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Purchase order:       ' || NVL (cPurchase_Order, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Sales Order           ' || NVL (cSales_Order, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice date from:    ' || NVL (cInvoice_Date_Low, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice date to:      ' || NVL (cInvoice_Date_High, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Product family:       ' || NVL (cProduct_Family, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Unprinted:            ' || NVL (cUnPrinted_Flag, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice class:        ' || NVL (cInvoice_class, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_id:            ' || NVL (cSource_id, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_group_id:      ' || NVL (cSource_group_id, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_assignment_id: ' || NVL (cSource_assignment_id, 'ALL'));

        -- 03.06.28 Set the context so that can be used in the views
        xxcp_context.set_source_id (cSource_id => cSource_id);
        xxcp_context.set_context (cAttribute   => 'source_group_id',
                                  cValue       => cSource_group_id);
        xxcp_context.set_context (cAttribute   => 'source_assignment_id',
                                  cValue       => cSource_assignment_id);

          SELECT XMLELEMENT (
                     "INVOICE_PRINT",
                     XMLELEMENT (
                         "PARAMS",
                         XMLELEMENT (
                             "PARAM_AMALGAM",
                                'Company Reg ID: '
                             || NVL (cInvoiceTaxReg, '*')
                             || ' Customer Reg ID: '
                             || NVL (cCustomerTaxReg, '*')
                             || CHR (10)
                             || DECODE (
                                    cInvoice_Date_High,
                                    NULL, NULL,
                                       'Invoice Date: '
                                    || NVL (SUBSTR (cInvoice_Date_Low, 1, 10),
                                            '*')
                                    || ' - '
                                    || SUBSTR (cInvoice_Date_High, 1, 10)
                                    || CHR (10))
                             || DECODE (
                                    cPurchase_Order,
                                    NULL, NULL,
                                       'PO: '
                                    || cPurchase_Order
                                    || DECODE (cSales_Order,
                                               NULL, NULL,
                                               ' SO: ' || cSales_Order)
                                    || CHR (10))
                             || DECODE (
                                    cInvoiceType,
                                    NULL, NULL,
                                       'Invoice Type: '
                                    || cInvoiceType
                                    || CHR (10))
                             || DECODE (
                                    cInvoice_Number_From,
                                    NULL, NULL,
                                       'Invoice Number: '
                                    || cInvoice_Number_From
                                    || ' - '
                                    || cInvoice_Number_To
                                    || CHR (10))),
                         XMLELEMENT ("UNPRINTED", NVL (cUnPrinted_Flag, 'N'))),
                     XMLAGG (
                         XMLELEMENT (
                             "HEADER",
                             XMLELEMENT ("HEADER_ID", a.header_id),
                             XMLELEMENT ("COMPANY_TAX_REG_ID",
                                         a.comp_tax_reg_id),
                             XMLELEMENT ("COMPANY_TAX_REF", a.comp_tax_ref),
                             XMLELEMENT ("COMPANY_DESC", a.comp_desc),
                             XMLELEMENT ("BILL_TO_ADDRESS", a.BILL_TO_ADDRESS),
                             XMLELEMENT ("COMPANY_TELEPHONE", a.comp_telephone),
                             XMLELEMENT ("CUSTOMER_TAX_REG_ID",
                                         a.cust_tax_reg_id),
                             XMLELEMENT ("SHIP_TO_ADDRESS", a.SHIP_TO_ADDRESS),
                             XMLELEMENT ("CUSTOMER_TAX_REF", a.cust_tax_ref),
                             XMLELEMENT ("CUSTOMER_BT_DESC", a.cust_BT_desc),
                             XMLELEMENT ("CUSTOMER_BT_TELEPHONE",
                                         a.cust_BT_telephone),
                             XMLELEMENT ("CUSTOMER_ST_DESC", a.cust_ST_desc),
                             XMLELEMENT ("CUSTOMER_ST_TELEPHONE",
                                         a.cust_ST_telephone),
                             XMLELEMENT ("INVOICE_CURRENCY", a.inv_currency),
                             XMLELEMENT ("PAY_TERMS", a.Pay_Terms),
                             XMLELEMENT ("INTERCOMPANY_TERMS",
                                         a.Int_Comp_Terms),
                             XMLELEMENT ("LEGAL_TEXT", a.legal_text),
                             XMLELEMENT ("ATTRIBUTE1", a.att1),
                             XMLELEMENT ("ATTRIBUTE2", a.att2),
                             XMLELEMENT ("ATTRIBUTE3", a.att3),
                             XMLELEMENT ("ATTRIBUTE4", a.att4),
                             XMLELEMENT ("ATTRIBUTE5", a.att5),
                             XMLELEMENT ("ATTRIBUTE6", a.att6),
                             XMLELEMENT ("ATTRIBUTE7", a.att7),
                             XMLELEMENT ("ATTRIBUTE8", a.att8),
                             XMLELEMENT ("ATTRIBUTE9", a.att9),
                             XMLELEMENT ("ATTRIBUTE10", a.att10),
                             XMLELEMENT ("ATTRIBUTE11", a.att11),
                             XMLELEMENT ("ATTRIBUTE12", a.att12),
                             XMLELEMENT ("ATTRIBUTE13", a.att13),
                             XMLELEMENT ("ATTRIBUTE14", a.att14),
                             XMLELEMENT ("ATTRIBUTE15", a.att15),
                             XMLELEMENT ("ATTRIBUTE16", a.att16),
                             XMLELEMENT ("ATTRIBUTE17", a.att17),
                             XMLELEMENT ("ATTRIBUTE18", a.att18),
                             XMLELEMENT ("ATTRIBUTE19", a.att19),
                             XMLELEMENT ("ATTRIBUTE30", a.att20),
                             XMLELEMENT ("COMP_BILL_TO_COUNTRY_CODE",
                                         a.comp_bill_to_country_code),
                             XMLELEMENT ("COMP_SHIP_TO_COUNTRY_CODE",
                                         a.comp_ship_to_country_code),
                             XMLELEMENT ("CUST_BILL_TO_COUNTRY_CODE",
                                         a.cust_bill_to_country_code),
                             XMLELEMENT ("CUST_SHIP_TO_COUNTRY_CODE",
                                         a.cust_ship_to_country_code),
                             XMLAGG (XMLELEMENT (
                                         "INVOICE_LINE",
                                         XMLELEMENT ("INVOICE_NUMBER",
                                                     b.INVOICE_NUMBER),
                                         XMLELEMENT ("VOUCHER_NUMBER",
                                                     b.VOUCHER_NUMBER),
                                         XMLELEMENT (
                                             "INVOICE_DATE",
                                             TO_CHAR (b.INVOICE_DATE,
                                                      'DD-MON-YYYY')),
                                         XMLELEMENT ("PO_NUMBER", b.Po_Number),
                                         XMLELEMENT ("SO_NUMBER", b.So_Number),
                                         XMLELEMENT ("PAYMENT_TERM",
                                                     b.Payment_Term),
                                         XMLELEMENT (
                                             "DUE_DATE",
                                             TO_CHAR (b.Due_Date,
                                                      'DD-MON-YYYY')),
                                         XMLELEMENT ("PAID_FLAG", b.Paid_Flag),
                                         XMLELEMENT ("DUE_DATE", b.due_date),
                                         XMLELEMENT ("LINE", b.line_no),
                                         XMLELEMENT ("UOM", b.uom),
                                         XMLELEMENT ("QTY", b.quantity),
                                         XMLELEMENT ("PART_NUMBER",
                                                     b.item_number),
                                         XMLELEMENT ("DESCRIPTION", b.Item),
                                         XMLELEMENT ("TAX_CODE", b.tax_code),
                                         XMLELEMENT ("TAX_RATE", b.tax_rate),
                                         XMLELEMENT ("UNIT_PRICE",
                                                     b.UNIT_PRICE),
                                         XMLELEMENT ("TOTAL_AMOUNT",
                                                     b.Extended_Amount),
                                         XMLELEMENT ("TAX_AMOUNT",
                                                     b.TAX_AMOUNT),
                                         XMLELEMENT ("LINE_AMOUNT",
                                                     b.Line_Amount),
                                         XMLELEMENT ("PRODUCT_FAMILY",
                                                     b.product_family),
                                         XMLELEMENT ("ATTRIBUTE1", b.att1),
                                         XMLELEMENT ("ATTRIBUTE2", b.att2),
                                         XMLELEMENT ("ATTRIBUTE3", b.att3),
                                         XMLELEMENT ("ATTRIBUTE4", b.att4),
                                         XMLELEMENT ("ATTRIBUTE5", b.att5),
                                         XMLELEMENT ("ATTRIBUTE6", b.att6),
                                         XMLELEMENT ("ATTRIBUTE7", b.att7),
                                         XMLELEMENT ("ATTRIBUTE8", b.att8),
                                         XMLELEMENT ("ATTRIBUTE9", b.att9),
                                         XMLELEMENT ("ATTRIBUTE10", b.att10),
                                         XMLELEMENT ("ATTRIBUTE11", b.att11),
                                         XMLELEMENT ("ATTRIBUTE12", b.att12),
                                         XMLELEMENT ("ATTRIBUTE13", b.att13),
                                         XMLELEMENT ("ATTRIBUTE14", b.att14),
                                         XMLELEMENT ("ATTRIBUTE15", b.att15),
                                         XMLELEMENT ("ATTRIBUTE16", b.att16),
                                         XMLELEMENT ("ATTRIBUTE17", b.att17),
                                         XMLELEMENT ("ATTRIBUTE18", b.att18),
                                         XMLELEMENT ("ATTRIBUTE19", b.att19),
                                         XMLELEMENT ("ATTRIBUTE30", b.att20),
                                         XMLELEMENT ("MATCHING_DOCUMENT",
                                                     b.matching_document),
                                         XMLELEMENT ("INVOICE_CLASS",
                                                     b.invoice_class),
                                         XMLELEMENT ("CUSTOMER_CONTACT",
                                                     b.customer_contact))
                                     ORDER BY b.invoice_number, TO_NUMBER (b.line_no)),
                             XMLELEMENT (
                                 "HEADER_TOTAL",
                                 (  SELECT XMLAGG (
                                               XMLELEMENT (
                                                   "TOTAL",
                                                   XMLFOREST (
                                                       c.TAX_CODE tax_code,
                                                       c.ic_currency curr,
                                                       c.tax_rate,
                                                       SUM (
                                                           c.Unit_Price * c.quantity)
                                                           net_price_tot,
                                                       SUM (c.TAX_AMOUNT)
                                                           tax_amount_tot)))
                                      FROM xxcp_instance_ic_inv_v c, xxcp_instance_ic_inv_comp_v d
                                     WHERE     c.invoice_header_id = d.header_id
                                           AND c.invoice_header_id = a.header_id
                                  GROUP BY c.tax_code, c.ic_currency, c.tax_rate))))).getClobVal () xml
            INTO vClob
            FROM xxcp_instance_ic_inv_comp_v a, xxcp_instance_ic_inv_v b
           WHERE     a.header_id = b.invoice_header_id
                 AND NVL (a.comp_tax_reg_id, 0) =
                     NVL (cInvoiceTaxReg, NVL (a.comp_tax_reg_id, 0))
                 AND NVL (a.cust_tax_reg_id, 0) =
                     NVL (cCustomerTaxReg, NVL (a.cust_tax_reg_id, 0))
                 AND NVL (b.po_number, '~null~') =
                     NVL (cPurchase_Order, NVL (b.po_number, '~null~'))
                 AND NVL (b.so_number, '~null~') =
                     NVL (cSales_Order, NVL (b.so_number, '~null~'))
                 AND NVL (b.product_family, '~null~') =
                     NVL (cProduct_Family, NVL (b.product_family, '~null~'))
                 AND TRUNC (b.invoice_date) BETWEEN NVL (
                                                        TO_DATE (
                                                            cInvoice_Date_Low,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TRUNC (b.invoice_date))
                                                AND NVL (
                                                        TO_DATE (
                                                            cInvoice_Date_High,
                                                            'YYYY/MM/DD HH24:MI:SS'),
                                                        TRUNC (b.invoice_date))
                 AND NVL (b.invoice_number, '~null~') BETWEEN NVL (
                                                                  cInvoice_Number_from,
                                                                  NVL (
                                                                      b.invoice_number,
                                                                      '~null~'))
                                                          AND NVL (
                                                                  cInvoice_Number_to,
                                                                  NVL (
                                                                      b.invoice_number,
                                                                      '~null~'))
                 AND a.invoice_type =
                     NVL (cInvoiceType, NVL (a.invoice_type, '~null~'))
                 AND NVL (b.invoice_class, '~null~') =
                     NVL (cInvoice_class, NVL (b.invoice_class, '~null~'))
                 AND NVL (a.printed_flag, 'N') =
                     DECODE (SUBSTR (cUnPrinted_Flag, 1, 1),
                             'Y', 'N',
                             a.printed_flag)
        GROUP BY a.header_id, comp_tax_reg_id, a.comp_tax_ref,
                 a.comp_Desc, a.bill_to_address, a.comp_telephone,
                 a.cust_tax_reg_id, a.ship_to_address, a.cust_tax_ref,
                 a.cust_BT_desc, a.cust_BT_telephone, a.cust_ST_desc,
                 a.cust_ST_telephone, a.inv_currency, a.pay_terms,
                 a.int_comp_terms, a.legal_text, a.att1,
                 a.att2, a.att3, a.att4,
                 a.att5, a.att6, a.att7,
                 a.att8, a.att9, a.att10,
                 a.att11, a.att12, a.att13,
                 a.att14, a.att15, a.att16,
                 a.att17, a.att18, a.att19,
                 a.att20, a.comp_bill_to_country_code, a.comp_ship_to_country_code,
                 a.cust_bill_to_country_code, a.cust_ship_to_country_code
        ORDER BY b.invoice_number, TO_NUMBER (b.line_no);

        -- Update the printed information for the header
        UPDATE xxcp_ic_inv_header a
           SET printed_flag = 'Y', printed_counter = printed_counter + 1, last_printed_date = SYSDATE
         WHERE     NVL (a.invoice_tax_REG_ID, 0) =
                   NVL (cInvoiceTaxReg, NVL (a.invoice_tax_reg_id, 0))
               AND NVL (a.customer_tax_reg_id, 0) =
                   NVL (cCustomerTaxReg, NVL (a.customer_tax_reg_id, 0))
               AND NVL (a.invoice_class, '~null~') =
                   NVL (cInvoice_class, NVL (a.Invoice_class, '~null~'))
               AND a.invoice_header_id IN
                       (SELECT b.invoice_header_id
                          FROM xxcp_instance_ic_inv_v b
                         WHERE     NVL (b.Po_Number, '~null~') =
                                   NVL (cPurchase_Order,
                                        NVL (b.Po_Number, '~null~'))
                               AND NVL (b.So_Number, '~null~') =
                                   NVL (cSales_Order,
                                        NVL (b.So_Number, '~null~'))
                               AND NVL (b.product_family, '~null~') =
                                   NVL (cProduct_Family,
                                        NVL (b.product_family, '~null~'))
                               AND a.printed_flag =
                                   DECODE (SUBSTR (cUnprinted_Flag, 1, 1),
                                           'Y', 'N',
                                           a.printed_flag)
                               AND NVL (b.invoice_number, '~null~') BETWEEN NVL (
                                                                                cInvoice_Number_From,
                                                                                NVL (
                                                                                    b.invoice_number,
                                                                                    '~null~'))
                                                                        AND NVL (
                                                                                cInvoice_Number_To,
                                                                                NVL (
                                                                                    b.invoice_number,
                                                                                    '~null~'))
                               AND a.INVOICE_DATE BETWEEN NVL (
                                                              TO_DATE (
                                                                  cInvoice_Date_Low,
                                                                  'YYYY/MM/DD HH24:MI:SS'),
                                                              TRUNC (
                                                                  b.INVOICE_DATE))
                                                      AND NVL (
                                                              TO_DATE (
                                                                  cInvoice_Date_High,
                                                                  'YYYY/MM/DD HH24:MI:SS'),
                                                              TRUNC (
                                                                  b.INVOICE_DATE)))
               -- OOD-641 ensure header is present in xxcp_instance_ic_inv_comp_v view (complete with address details)
               AND a.invoice_header_id IN
                       (SELECT c.header_id
                          FROM xxcp_instance_ic_inv_comp_v c
                         WHERE     NVL (a.invoice_tax_reg_id, 0) =
                                   NVL (cInvoiceTaxReg,
                                        NVL (c.comp_tax_reg_id, 0))
                               AND NVL (a.customer_tax_reg_id, 0) =
                                   NVL (cCustomerTaxReg,
                                        NVL (c.cust_tax_reg_id, 0)));

        -- OOD-641 issue warning for records not printed due to lack of address
        vCounter   := 0;

        FOR rec IN curNotPrinted (cInvoiceTaxReg, cCustomerTaxReg, cInvoice_Number_From, cInvoice_Number_To, cPurchase_Order, cSales_Order, cProduct_Family, cInvoice_Date_Low, cInvoice_Date_High
                                  , cInvoice_class)
        LOOP
            vCounter   := vCounter + 1;

            IF vCounter = 1
            THEN
                fnd_file.put_line (fnd_file.LOG, '');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'WARNING - The following selected headers were not printed (no address details):');
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Header ID: '
                || rec.invoice_header_id
                || ', Company Tax Reg: '
                || rec.invoice_tax_reg_id
                || ', Customer Tax Reg: '
                || rec.customer_tax_reg_id);
        END LOOP;

        IF vCounter != 0
        THEN
            vDummy   :=
                fnd_concurrent.set_completion_status (
                    'WARNING',
                    'Some header records had no address details defined.');
        END IF;

        -- Send the XML output back
        printClobOut (cClob => vClob, cHeader_Req => 'Y');
    END IC_Invoice;


    -- IC Invoicing Listing
    PROCEDURE IC_Invoice_Listing (errbuf OUT VARCHAR2, retcode OUT NUMBER, cInvoiceType IN VARCHAR2, cSource_id IN VARCHAR2, cSource_group_id IN VARCHAR2, cSource_assignment_id IN VARCHAR2, cInvoiceTaxReg IN VARCHAR2, cCustomerTaxReg IN VARCHAR2, cInvoice_Date_Low IN VARCHAR2
                                  , cInvoice_Date_High IN VARCHAR2, cUnPrinted_Flag IN VARCHAR2, cInvoice_class IN VARCHAR2)
    IS
        -- OOD-641 capture all un-printed invoices that match given parameters
        CURSOR curNotPrinted (pInvoiceTaxReg     IN PLS_INTEGER,
                              pCustomerTaxReg    IN PLS_INTEGER,
                              pInvoiceDateLow    IN VARCHAR2,
                              pInvoiceDateHigh   IN VARCHAR2,
                              pInvoice_class     IN VARCHAR2)
        IS
            SELECT a.invoice_header_id, a.invoice_tax_reg_id, a.customer_tax_reg_id
              FROM xxcp_ic_inv_header a
             WHERE     NVL (a.invoice_tax_reg_id, 0) =
                       NVL (pInvoiceTaxReg, NVL (a.invoice_tax_reg_id, 0))
                   AND NVL (a.customer_tax_reg_id, 0) =
                       NVL (pCustomerTaxReg, NVL (a.customer_tax_reg_id, 0))
                   AND NVL (a.invoice_class, '~null~') =
                       NVL (pInvoice_class, NVL (a.Invoice_class, '~null~'))
                   AND a.invoice_header_id IN
                           (SELECT b.invoice_header_id
                              FROM xxcp_instance_ic_inv_v b
                             -- VT273-437 Only select headers that have not been printed for this run
                             WHERE     a.printed_flag = 'N'
                                   AND NVL (a.release_invoice, 'Y') = 'Y'
                                   AND a.invoice_date BETWEEN NVL (
                                                                  TO_DATE (
                                                                      pInvoiceDateLow,
                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                  TRUNC (
                                                                      b.invoice_date))
                                                          AND NVL (
                                                                  TO_DATE (
                                                                      pInvoiceDateHigh,
                                                                      'YYYY/MM/DD HH24:MI:SS'),
                                                                  TRUNC (
                                                                      b.invoice_date)))
                   AND a.invoice_header_id IN
                           (SELECT c.header_id
                              FROM xxcp_instance_ic_inv_comp_v c
                             WHERE     NVL (a.invoice_tax_reg_id, 0) =
                                       NVL (pInvoiceTaxReg,
                                            NVL (c.comp_tax_reg_id, 0))
                                   AND NVL (a.customer_tax_reg_id, 0) =
                                       NVL (pCustomerTaxReg,
                                            NVL (c.cust_tax_reg_id, 0)));

        vClob      CLOB;
        vCounter   PLS_INTEGER;
        vDummy     BOOLEAN;
    BEGIN
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'XXCP_BI_PUB.IC_Invoice_Listing Parameters Entered');
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice type:         ' || NVL (cInvoiceType, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice tax reg:      ' || NVL (cInvoiceTaxReg, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Customer tax reg:     ' || NVL (cCustomerTaxReg, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice date from:    ' || NVL (cInvoice_Date_Low, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice date to:      ' || NVL (cInvoice_Date_High, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Unprinted:            ' || NVL (cUnPrinted_Flag, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Invoice class:        ' || NVL (cInvoice_class, 'ALL'));
        -- 03.06.28 Output the extra parameters
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_id:            ' || NVL (cSource_id, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_group_id:      ' || NVL (cSource_group_id, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Source_assignment_id: ' || NVL (cSource_assignment_id, 'ALL'));
        -- 03.06.28 Set the context so that can be used in the views
        xxcp_context.set_source_id (cSource_id => cSource_id);
        xxcp_context.set_context (cAttribute   => 'source_group_id',
                                  cValue       => cSource_group_id);
        xxcp_context.set_context (cAttribute   => 'source_assignment_id',
                                  cValue       => cSource_assignment_id);

          SELECT XMLELEMENT (
                     "INVOICE_LIST",
                     XMLAGG (
                         XMLELEMENT (
                             "HEADER",
                             XMLELEMENT ("CURRENCY", w1.invoice_currency),
                             XMLELEMENT ("INV_COMP_NUMBER", w1.Inv_Comp_Number),
                             XMLELEMENT ("INV_TAX_REG_NAME",
                                         w1.Inv_Tax_Reg_Name),
                             XMLELEMENT ("INV_TAX_REF", w1.Inv_Tax_Ref),
                             XMLELEMENT ("INV_COMP_BT_NAME",
                                         w1.Inv_Comp_bt_name),
                             XMLELEMENT ("INV_COMP_ADDRESS",
                                         w1.BILL_TO_ADDRESS),
                             XMLELEMENT ("CUST_TAX_REG_NAME",
                                         w1.Cust_Tax_Reg_Name),
                             XMLELEMENT ("CUST_TAX_REF", w1.Cust_Tax_Ref),
                             XMLELEMENT ("CUST_COMP_BT_NAME",
                                         w1.Cust_Comp_bt_name),
                             XMLELEMENT ("CUST_COMP_ST_NAME",
                                         w1.Cust_Comp_st_name),
                             XMLELEMENT ("CUST_COMP_NUMBER",
                                         w1.Cust_Comp_Number),
                             XMLELEMENT ("CUST_BILL_ADDRESS", w1.B_TO_ADDRESS),
                             XMLELEMENT ("CUST_SHIP_ADDRESS",
                                         w1.SHIP_TO_ADDRESS),
                             XMLAGG (XMLELEMENT (
                                         "INVOICE_LIST_LINE",
                                         XMLELEMENT ("INVOICE_NUMBER",
                                                     w1.invoice_number),
                                         XMLELEMENT ("VOUCHER_NUMBER",
                                                     w1.voucher_number),
                                         XMLELEMENT ("INV_TAX_REG_NAME",
                                                     w1.Inv_Tax_Reg_Name),
                                         XMLELEMENT ("CUST_TAX_REG_NAME",
                                                     w1.Cust_Tax_Reg_Name),
                                         XMLELEMENT ("INVOICE_DATE",
                                                     w1.invoice_date),
                                         XMLELEMENT ("INVOICE_CURRENCY",
                                                     w1.invoice_currency),
                                         XMLELEMENT ("TAX_CODE", w1.tax_code),
                                         XMLELEMENT ("IC_TAX_AMOUNT",
                                                     NVL (w1.ic_tax_amount, 0)),
                                         XMLELEMENT ("IC_PRICE",
                                                     NVL (w1.ic_price, 0)),
                                         XMLELEMENT ("MATCHING_DOCUMENT",
                                                     w1.matching_document))
                                     ORDER BY w1.invoice_number)))).getClobVal () xml
            INTO vClob
            FROM XXCP_INSTANCE_INVOICE_LIST_V w1
           WHERE     w1.invoice_type =
                     NVL (cInvoiceType, NVL (w1.Invoice_Type, '~null~'))
                 AND NVL (w1.invoice_class, '~null~') =
                     NVL (cInvoice_class, NVL (w1.Invoice_class, '~null~'))
                 AND w1.printed_flag =
                     DECODE (SUBSTR (cUnPrinted_Flag, 1, 1),
                             'Y', 'N',
                             w1.printed_flag)
                 AND NVL (w1.release_invoice, 'Y') = 'Y'
                 AND w1.customer_tax_reg_id =
                     NVL (cCustomerTaxReg, NVL (w1.customer_tax_reg_id, 0))
                 AND w1.invoice_tax_reg_id =
                     NVL (cInvoiceTaxReg, NVL (w1.invoice_tax_reg_id, 0))
                 AND w1.invoice_date BETWEEN NVL (
                                                 TO_DATE (
                                                     cInvoice_Date_Low,
                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                 TRUNC (w1.INVOICE_DATE))
                                         AND NVL (
                                                 TO_DATE (
                                                     cInvoice_Date_High,
                                                     'YYYY/MM/DD HH24:MI:SS'),
                                                 TRUNC (w1.INVOICE_DATE))
        GROUP BY w1.invoice_currency, w1.Inv_Comp_Number, w1.Inv_Tax_Reg_Name,
                 w1.Inv_Tax_Ref, w1.Inv_Comp_bt_name, w1.BILL_TO_ADDRESS,
                 w1.Cust_Tax_Reg_Name, w1.Cust_Tax_Ref, w1.Cust_Comp_bt_name,
                 w1.Cust_Comp_st_name, w1.Cust_Comp_Number, w1.B_TO_ADDRESS,
                 w1.ship_to_address
        ORDER BY w1.invoice_currency, w1.invoice_number, w1.Inv_Tax_Reg_Name,
                 w1.Cust_Tax_Reg_Name;

        -- OOD-641 issue warning for records not printed due to lack of address
        vCounter   := 0;

        FOR rec IN curNotPrinted (cInvoiceTaxReg, cCustomerTaxReg, cInvoice_Date_Low
                                  , cInvoice_Date_High, cInvoice_class)
        LOOP
            vCounter   := vCounter + 1;

            IF vCounter = 1
            THEN
                fnd_file.put_line (fnd_file.LOG, '');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'WARNING - The following selected headers were not printed (no address details):');
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Header ID: '
                || rec.invoice_header_id
                || ', Company Tax Reg: '
                || rec.invoice_tax_reg_id
                || ', Customer Tax Reg: '
                || rec.customer_tax_reg_id);
        END LOOP;

        IF vCounter != 0
        THEN
            vDummy   :=
                fnd_concurrent.set_completion_status (
                    'WARNING',
                    'Some header records had no address details defined.');
        END IF;

        -- Send the XML output back
        printClobOut (cClob => vClob, cHeader_Req => 'Y');
    END IC_Invoice_Listing;

    -- New Report
    PROCEDURE Sub_Journal_Recon (errbuf OUT VARCHAR2, retcode OUT NUMBER, cAccess_Set IN VARCHAR2, cCOA_ID IN VARCHAR2, cLedger_ID IN VARCHAR2, cStart_Date IN VARCHAR2, cEnd_Date IN VARCHAR2, cAccount_From IN VARCHAR2, cAccount_To IN VARCHAR2
                                 , cPosting_Status IN VARCHAR2, cJournal_Source IN VARCHAR2, cJournal_Category IN VARCHAR2)
    IS
        vClob                CLOB;
        vDelimeter           VARCHAR2 (10);
        vStart_Date          DATE
            := TRUNC (TO_DATE (cStart_Date, 'YYYY/MM/DD HH24:MI:SS'));
        vEnd_Date            DATE
            := TRUNC (TO_DATE (cEnd_Date, 'YYYY/MM/DD HH24:MI:SS'));

        vMax_Segs            NUMBER;
        vSegments_From       XXCP_DYNAMIC_ARRAY
                                 := XXCP_DYNAMIC_ARRAY ('', '', '',
                                                        '', '', '',
                                                        '', '', '',
                                                        '', '', '',
                                                        '', '', '',
                                                        '', '');
        vSegments_To         XXCP_DYNAMIC_ARRAY
                                 := XXCP_DYNAMIC_ARRAY ('', '', '',
                                                        '', '', '',
                                                        '', '', '',
                                                        '', '', '',
                                                        '', '', '',
                                                        '', '');
        vSeg_Count           NUMBER := 0;
        vFull_Account_From   VARCHAR2 (2000);
        vFull_Account_To     VARCHAR2 (2000);
        vCnt                 NUMBER;

        CURSOR c1 (cCOA_ID NUMBER)
        IS
            SELECT str.concatenated_segment_delimiter delim
              FROM fnd_id_flex_structures_vl str
             WHERE     str.ID_FLEX_NUM = cCOA_ID
                   AND str.APPLICATION_ID = 101
                   AND str.ID_FLEX_CODE = 'GL#';

        CURSOR c2 (cCOA_ID NUMBER)
        IS
            SELECT a.max_segments
              FROM XXCP_INSTANCE_COA_SEG_COUNT_V a
             WHERE a.instance_id = 0 AND a.coa_id = cCOA_ID;
    BEGIN
        -- Display the parameters entered in the log file
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'XXCP_BI_PUB.Journal_Report Parameters Entered');
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Access Set ID     ' || NVL (cAccess_Set, 'ALL'));
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'COA ID:           ' || NVL (cCOA_ID, 'ALL'));
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Ledger:           ' || NVL (cLedger_ID, 'ALL'));
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Start Date:       ' || NVL (cStart_Date, 'ALL'));
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'End Date:         ' || NVL (cEnd_Date, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Account From:     ' || NVL (cAccount_From, 'ALL'));
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Account To:       ' || NVL (cAccount_To, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Posting Status:   ' || NVL (cPosting_Status, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Journal Source:   ' || NVL (cJournal_Source, 'ALL'));
        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Journal Category: ' || NVL (cJournal_Category, 'ALL'));

        -- Default the date variables
        vStart_Date          := NVL (vStart_Date, '01-JAN-2000');
        vEnd_Date            := NVL (vEnd_Date, '01-JAN-2099');

        -- Fetch the delimeter for the chart of accounts

        FOR x IN c1 (cCOA_ID)
        LOOP
            vDelimeter   := x.delim;
        END LOOP;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Delimiter found as ' || vDelimeter);

        -- Fetch the maximum number of segments allowed for the chart of account.

        FOR y IN c2 (cCOA_ID)
        LOOP
            vMax_segs   := y.max_segments;
        END LOOP;

        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Max segments for COA is ' || TO_CHAR (vMax_Segs));

        -- Deconstruct the account strings coming in.

        vFull_Account_From   := cAccount_From;
        vFull_Account_To     := cAccount_To;

        IF vMax_Segs > 0
        THEN
            FOR x IN 1 .. vMax_Segs
            LOOP
                IF INSTR (vFull_Account_From, vDelimeter) > 0
                THEN
                    vSegments_From (x)   :=
                        SUBSTR (vFull_Account_From,
                                1,
                                INSTR (vFull_Account_From, vDelimeter) - 1);
                    vFull_Account_From   :=
                        SUBSTR (vFull_Account_From,
                                INSTR (vFull_Account_From, vDelimeter) + 1,
                                200);
                ELSIF     INSTR (vFull_Account_From, vDelimeter) = 0
                      AND vFull_Account_From IS NOT NULL
                THEN
                    vSegments_From (x)   := vFull_Account_From;
                    vFull_Account_From   := NULL;
                END IF;
            END LOOP;

            FOR x IN 1 .. vMax_Segs
            LOOP
                IF INSTR (vFull_Account_To, vDelimeter) > 0
                THEN
                    vSegments_To (x)   :=
                        SUBSTR (vFull_Account_To,
                                1,
                                INSTR (vFull_Account_To, vDelimeter) - 1);
                    vFull_Account_To   :=
                        SUBSTR (vFull_Account_To,
                                INSTR (vFull_Account_To, vDelimeter) + 1,
                                200);
                ELSIF     INSTR (vFull_Account_To, vDelimeter) = 0
                      AND vFull_Account_To IS NOT NULL
                THEN
                    vSegments_To (x)   := vFull_Account_To;
                    vFull_Account_To   := NULL;
                END IF;
            END LOOP;
        END IF;

          -- Fetch the data based upon the parameters entered and derived.

          SELECT XMLELEMENT (
                     "JOURNALS",
                     XMLAGG (
                         XMLELEMENT (
                             "LINE",
                             XMLELEMENT ("LEDGER", sla.ledger),
                             XMLELEMENT ("LEDGER_ID", sla.ledger_ID),
                             XMLELEMENT ("COA_ID", sla.coa_id),
                             XMLELEMENT ("POSTING_STATUS", sla.posting_status),
                             XMLELEMENT ("SEGMENT1",
                                         '="' || sla.segment1 || '"'),
                             XMLELEMENT ("SEGMENT2",
                                         '="' || sla.segment2 || '"'),
                             XMLELEMENT ("SEGMENT3",
                                         '="' || sla.segment3 || '"'),
                             XMLELEMENT ("SEGMENT4",
                                         '="' || sla.segment4 || '"'),
                             XMLELEMENT ("SEGMENT5",
                                         '="' || sla.segment5 || '"'),
                             XMLELEMENT ("SEGMENT6",
                                         '="' || sla.segment6 || '"'),
                             XMLELEMENT ("SEGMENT7",
                                         '="' || sla.segment7 || '"'),
                             XMLELEMENT ("SEGMENT8",
                                         '="' || sla.segment8 || '"'),
                             XMLELEMENT ("SEGMENT9",
                                         '="' || sla.segment9 || '"'),
                             XMLELEMENT ("SEGMENT10",
                                         '="' || sla.segment10 || '"'),
                             XMLELEMENT ("SEGMENT11",
                                         '="' || sla.segment11 || '"'),
                             XMLELEMENT ("SEGMENT12",
                                         '="' || sla.segment12 || '"'),
                             XMLELEMENT ("SEGMENT13",
                                         '="' || sla.segment13 || '"'),
                             XMLELEMENT ("SEGMENT14",
                                         '="' || sla.segment14 || '"'),
                             XMLELEMENT ("SEGMENT15",
                                         '="' || sla.segment15 || '"'),
                             XMLELEMENT ("CODE_COMB_DESC", sla.code_comb_desc),
                             XMLELEMENT ("GL_DATE", sla.gl_date),
                             XMLELEMENT ("SOURCE", sla.source),
                             XMLELEMENT ("CATEGORY", sla.category),
                             XMLELEMENT ("BATCH_NAME", sla.batch_name),
                             XMLELEMENT ("DOC_SEQUENCE", sla.doc_sequence),
                             XMLELEMENT ("LINE_NUM", sla.line_num),
                             XMLELEMENT ("DESCRIPTION", sla.description),
                             XMLELEMENT ("GL_ENT_AMOUNT", sla.gl_ent_amount),
                             XMLELEMENT ("GL_ACT_AMOUNT", sla.gl_act_amount)--                    ,xmlelement("CURRENCY_CODE",sla.currency_code) changed by MSS
                                                                            ,
                             XMLELEMENT ("ENTERED_CURRENCY",
                                         sla.entered_currency),
                             XMLELEMENT ("ACCOUNTED_CURRENCY",
                                         sla.accounted_currency),
                             XMLELEMENT ("ACCOED_EXCH_RATE",
                                         sla.accoed_exch_rate),
                             XMLELEMENT ("PARTY_NUMBER", sla.party_number),
                             XMLELEMENT ("PARTY_NAME", sla.party_name),
                             XMLELEMENT ("RECON_REF1", sla.recon_ref1),
                             XMLELEMENT ("RECON_REF2", sla.recon_ref2),
                             XMLELEMENT ("RECON_REF3", sla.recon_ref3),
                             XMLELEMENT ("TRANSACTION_REF1",
                                         sla.transaction_ref1),
                             XMLELEMENT ("TRANSACTION_REF2",
                                         sla.transaction_ref2),
                             XMLELEMENT ("TRANSACTION_REF3",
                                         sla.transaction_ref3)--                    ,XMLElement("AE_LINE_NUM",sla.ae_line_num)
                                                              ,
                             XMLELEMENT ("ACCOUNTING_CLASS",
                                         sla.accounting_class),
                             XMLELEMENT ("SLA_ENT_AMOUNT", sla.sla_ent_amount),
                             XMLELEMENT ("SLA_ACT_AMOUNT", sla.sla_act_amount),
                             XMLELEMENT ("SLA_ENT_CURR",
                                         sla.SLA_entered_currency),
                             XMLELEMENT ("SLA_ACT_CURR",
                                         sla.SLA_accounted_currency)))).getClobVal ()
                     xml,
                 COUNT (*)
                     cnt
            INTO vClob, vCnt
            FROM xxcp_instance_sla_recon_v sla
           WHERE     (NVL (sla.segment1, '~null~') >= NVL (vSegments_From (1), '~null~') AND NVL (sla.segment1, '~null~') <= NVL (vSegments_To (1), '~null~'))
                 AND (NVL (sla.segment2, '~null~') >= NVL (vSegments_From (2), '~null~') AND NVL (sla.segment2, '~null~') <= NVL (vSegments_To (2), '~null~'))
                 AND (NVL (sla.segment3, '~null~') >= NVL (vSegments_From (3), '~null~') AND NVL (sla.segment3, '~null~') <= NVL (vSegments_To (3), '~null~'))
                 AND (NVL (sla.segment4, '~null~') >= NVL (vSegments_From (4), '~null~') AND NVL (sla.segment4, '~null~') <= NVL (vSegments_To (4), '~null~'))
                 AND (NVL (sla.segment5, '~null~') >= NVL (vSegments_From (5), '~null~') AND NVL (sla.segment5, '~null~') <= NVL (vSegments_To (5), '~null~'))
                 AND (NVL (sla.segment6, '~null~') >= NVL (vSegments_From (6), '~null~') AND NVL (sla.segment6, '~null~') <= NVL (vSegments_To (6), '~null~'))
                 AND (NVL (sla.segment7, '~null~') >= NVL (vSegments_From (7), '~null~') AND NVL (sla.segment7, '~null~') <= NVL (vSegments_To (7), '~null~'))
                 AND (NVL (sla.segment8, '~null~') >= NVL (vSegments_From (8), '~null~') AND NVL (sla.segment8, '~null~') <= NVL (vSegments_To (8), '~null~'))
                 AND (NVL (sla.segment9, '~null~') >= NVL (vSegments_From (9), '~null~') AND NVL (sla.segment9, '~null~') <= NVL (vSegments_To (9), '~null~'))
                 AND (NVL (sla.segment10, '~null~') >= NVL (vSegments_From (10), '~null~') AND NVL (sla.segment10, '~null~') <= NVL (vSegments_To (10), '~null~'))
                 AND (NVL (sla.segment11, '~null~') >= NVL (vSegments_From (11), '~null~') AND NVL (sla.segment11, '~null~') <= NVL (vSegments_To (11), '~null~'))
                 AND (NVL (sla.segment12, '~null~') >= NVL (vSegments_From (12), '~null~') AND NVL (sla.segment12, '~null~') <= NVL (vSegments_To (12), '~null~'))
                 AND (NVL (sla.segment13, '~null~') >= NVL (vSegments_From (13), '~null~') AND NVL (sla.segment13, '~null~') <= NVL (vSegments_To (13), '~null~'))
                 AND (NVL (sla.segment14, '~null~') >= NVL (vSegments_From (14), '~null~') AND NVL (sla.segment14, '~null~') <= NVL (vSegments_To (14), '~null~'))
                 AND (NVL (sla.segment15, '~null~') >= NVL (vSegments_From (15), '~null~') AND NVL (sla.segment15, '~null~') <= NVL (vSegments_To (15), '~null~'))
                 AND NVL (sla.ledger_id, 0) = NVL (cLedger_ID, 0)
                 AND NVL (sla.gl_date, '01-JAN-2000') >= vStart_Date
                 AND NVL (sla.gl_date, '01-JAN-2000') <= vEnd_Date
                 AND NVL (sla.posting_status, '~null~') =
                     NVL (cPosting_Status, NVL (sla.posting_status, '~null~'))
                 AND NVL (sla.coa_id, 0) = NVL (cCOA_ID, NVL (sla.coa_id, 0))
                 AND NVL (sla.source, '~null~') =
                     NVL (cJournal_Source, NVL (sla.source, '~null~'))
                 AND NVL (sla.category, '~null~') =
                     NVL (cJournal_Category, NVL (sla.category, '~null~'))
        ORDER BY sla.ledger, sla.source, sla.category,
                 sla.recon_ref1, sla.recon_ref2, sla.recon_ref3,
                 sla.transaction_ref1, sla.line_num--,sla.ae_line_num
                                                   ;

        printClobOut (cClob => vClob, cHeader_Req => 'Y');
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Count is ' || TO_CHAR (vCnt));
    END Sub_Journal_Recon;

    ----------------------------------------------------------------
    -- Ics_Day_Aged_By_Status_Det
    ----------------------------------------------------------------
    PROCEDURE Ics_Day_Aged_By_Status_Det (errbuf OUT VARCHAR2, retcode OUT NUMBER, cCompany IN VARCHAR2 DEFAULT ''
                                          , cRun_Date IN VARCHAR2 DEFAULT '')
    IS
        vClob       CLOB;
        vRun_Date   DATE;
    BEGIN
        vRun_Date   := NVL (fnd_date.canonical_to_date (cRun_Date), SYSDATE);

        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('
      SELECT v.transaction_ref invoice_no
            ,v.owner_comp
            ,v.owner_comp_Name
            ,v.ent_curr
            ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
                ''Approved''
             WHEN v.Acct_type_ind = ''LT'' THEN
                ''Long Term''
             ELSE
                ''Outstanding''
             END Status
            ,NVL(owner_AR,0) owner_Tot_AR
            ,NVL(owner_AP,0) owner_Tot_AP
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE <= 30 THEN
                v.owner_AP
             ELSE
                0
             END owner_ST_AP_30
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE BETWEEN 31 AND 60 THEN
                v.owner_AP
             ELSE
                0
             END owner_ST_AP_60
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE BETWEEN 61 AND 90 THEN
                v.owner_AP
             ELSE
                0
             END owner_ST_AP_90
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE > 90 THEN
                v.owner_AP
             ELSE
                0
             END owner_ST_AP_GTR
             ---
            ,v.partner_comp
            ,v.partner_comp_name
            ,NVL(Partner_AR
                ,0) Partner_Tot_AR
            ,NVL(Partner_AP
                ,0) Partner_Tot_AP
             ---------
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE <= 30 THEN
                v.Partner_AP
             ELSE
                0
             END Partner_ST_AP_30
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE BETWEEN 31 AND 60 THEN
                v.Partner_AP
             ELSE
                0
             END Partner_ST_AP_60
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE BETWEEN 61 AND 90 THEN
                v.Partner_AP
             ELSE
                0
             END Partner_ST_AP_90
            ,CASE WHEN to_date(''' || TO_CHAR (vRun_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'') - v.ACCOUNTING_DATE > 90 THEN
                v.Partner_AP
             ELSE
                0
             END Partner_ST_AP_GTR
      ---
        FROM xxcp_ics_recon_det_v v
      ---
       WHERE v.owner_comp = NVL(''' || cCompany || ''',v.owner_comp)
         AND v.status NOT IN (''Re-Classed'',''Inactive'', ''Interim'')
      ---
       ORDER BY v.owner_comp
               ,v.owner_comp_Name
               ,CASE
                  WHEN v.status IN (''Approved'',''Pending Payment'') THEN
                   ''Approved''
                  WHEN v.Acct_type_ind = ''LT'' THEN
                   ''Long Term''
                  ELSE
                   ''Outstanding''
                END
               ,v.ent_curr
               ,v.partner_comp
               ,v.partner_comp_name
               ,v.transaction_ref') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Day_Aged_By_Status_Det;

    ----------------------------------------------------------------
    -- Ics_Report_Entered_Det
    ----------------------------------------------------------------

    PROCEDURE Ics_Report_Entered_Det (errbuf OUT VARCHAR2, retcode OUT NUMBER, cCompany IN VARCHAR2 DEFAULT ''
                                      , cExch_Rate_Date IN VARCHAR2 DEFAULT '', cExch_Rate_Type IN VARCHAR2 DEFAULT '')
    IS
        vClob             CLOB;
        vExch_Rate_Date   DATE;
    BEGIN
        vExch_Rate_Date   :=
            NVL (fnd_date.canonical_to_date (cExch_Rate_Date), SYSDATE);

        -- NOTE!!! Need to add Period Param into Query!!!
        SELECT DBMS_XMLGEN.getxml ('SELECT v.request_id Pay_Batch
     ,v.transaction_ref
     ,v.owner_comp
     ,v.owner_Comp_Name
     ,v.ent_curr
     ,v.settlement_type
     ,NVL(owner_AR,0) owner_Tot_AR
     ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
           NVL(owner_AR,0)
      ELSE
           0
      END owner_AR_App
     ,CASE WHEN NOT v.status IN (''Approved'',''Pending Payment'') THEN
           NVL(owner_AR,0)
      ELSE
           0
      END owner_AR_Not_App
     ,NVL(owner_AP,0) owner_Tot_AP
     ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
           NVL(owner_AP,0)
      ELSE
           0
      END owner_AP_App
     ,CASE WHEN NOT v.status IN (''Approved'',''Pending Payment'') THEN
           NVL(owner_AP,0)
      ELSE
           0
      END owner_AP_Not_App
     ,CASE WHEN v.acct_type_ind = ''ST'' AND v.status = ''Rejected'' THEN
           NVL(owner_AP,0)
      ELSE
           0
      END owner_ST_AP_Rej
     ,CASE WHEN v.acct_type_ind = ''ST'' AND v.status = ''New'' THEN
           NVL(owner_AP,0)
      ELSE
           0
      END owner_ST_AP_New
     ,CASE WHEN v.status = ''Pending Re-Class'' THEN
           NVL(owner_AP,0)
      ELSE
           0
      END owner_ST_AP_Reclass
     ,CASE WHEN v.acct_type_ind = ''LT'' THEN
           NVL(owner_AP,0)
      ELSE
           0
      END owner_AP_LT
     ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
           NVL(owner_AP,0) - NVL(partner_AP,0)
      ELSE
           0
      END owner_Pay_Net
     ,v.partner_comp
     ,v.partner_comp_Name
     ,CASE WHEN v.owner_ar_acct = 0 THEN
           to_char(xxcp_gwu.Safe_Divide(NVL(v.owner_ap_acct,0) , NVL(v.owner_ap,0)))
      ELSE
           to_char(xxcp_gwu.Safe_Divide(NVL(v.owner_ar_acct,0) , NVL(v.owner_ar,0)))
      END owner_acct_rate
     ,v.owner_ar_acct
     ,NVL(partner_AR,0) partner_Tot_AR
    ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
          NVL(partner_AR,0)
     ELSE
          0
     END partner_AR_App
    ,CASE WHEN NOT v.status IN (''Approved'',''Pending Payment'') THEN
          NVL(partner_AR,0)
     ELSE
          0
     END partner_AR_Not_App
    ,NVL(partner_AP,0) partner_Tot_AP
    ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
          NVL(partner_AP,0)
     ELSE
          0
     END partner_AP_App
    ,CASE WHEN NOT v.status IN (''Approved'',''Pending Payment'') THEN
          NVL(partner_AP,0)
     ELSE
          0
     END partner_AP_Not_App
    ,CASE WHEN v.status = ''Rejected'' THEN
          NVL(partner_AP,0)
     ELSE
          0
     END partner_AP_Rej
    ,CASE WHEN v.status = ''New'' THEN
          NVL(partner_AP,0)
     ELSE
          0
     END partner_AP_New
    ,CASE WHEN v.status = ''Pending Re-Class'' THEN
          NVL(partner_AP,0)
     ELSE
          0
     END partner_AP_Reclass
    ,CASE WHEN v.acct_type_ind = ''LT'' THEN
          NVL(partner_AP,0)
     ELSE
          0
     END partner_AP_LT
    ,CASE WHEN v.status IN (''Approved'',''Pending Payment'') THEN
          NVL(partner_AP,0) - NVL(owner_AP,0)
     ELSE
          0
     END partner_Pay_Net
,decode(v.ent_curr,v.owner_acct_curr,1,z.conversion_rate) owner_reval_rate
,decode(v.ent_curr,v.owner_acct_curr,(1*nvl(v.owner_ar,0)),(nvl(v.owner_ar,0)*nvl(z.conversion_rate,0))) owner_ar_reval
,nvl(v.owner_ap_acct,0) owner_ap_acct
,decode(v.ent_curr,v.owner_acct_curr,(1*nvl(v.owner_ap,0)),(nvl(v.owner_ap,0)*nvl(z.conversion_rate,0))) owner_ap_reval
  FROM xxcp_ics_recon_det_v v
      ,Xxcp_Instance_Daily_Rates_v z
 where v.owner_comp = nvl(''' || cCompany || ''',v.owner_comp)
   and z.from_currency(+) = v.ent_curr
   and z.to_currency(+) = v.owner_acct_curr
   and z.conversion_date(+) = to_date(''' || TO_CHAR (vExch_Rate_Date, 'DD-MON-YYYY') || ''',''DD-MON-YYYY'')
   and z.conversion_type(+) = ''' || cExch_Rate_Type || '''
 ORDER BY v.request_id
         ,v.owner_comp
         ,v.owner_Comp_Name
         ,v.ent_curr
         ,v.settlement_type
         ,v.partner_comp
         ,v.partner_comp_Name
         ,v.transaction_ref') xml
          INTO vClob
          FROM DUAL;

        printClobOut (vClob);
    END Ics_Report_Entered_Det;

    PROCEDURE Best_Match_Reporting (errbuf OUT VARCHAR2, retcode OUT NUMBER, cStart_Date IN VARCHAR2
                                    , cEnd_Date IN VARCHAR2)
    IS
        vClob         CLOB;
        vCnt          NUMBER;
        vStart_Date   DATE;
        vEnd_Date     DATE;
    BEGIN
        -- Display the parameters entered in the log file
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'XXCP_BI_PUB.Best_Match_Reporting');
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Start Date:       ' || NVL (cStart_Date, 'ALL'));
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'End Date:         ' || NVL (cEnd_Date, 'ALL'));

        vStart_Date   :=
            TRUNC (TO_DATE (cStart_Date, 'YYYY/MM/DD HH24:MI:SS'));
        vEnd_Date   := TRUNC (TO_DATE (cEnd_Date, 'YYYY/MM/DD HH24:MI:SS'));

          -- Fetch the data based upon the parameters entered and derived.
          SELECT XMLELEMENT (
                     "BEST_MATCH",
                     XMLAGG (
                         XMLELEMENT (
                             "LINE",
                             XMLELEMENT ("SOURCE_NAME", s.source_name),
                             XMLELEMENT (
                                 "CATEGORY_NAME",
                                    cbr.category_name
                                 || DECODE (cdc.description,
                                            NULL, NULL,
                                            ' - ' || cdc.description)),
                             XMLELEMENT ("TRANSACTION_NUMBER",
                                         cbr.transaction_id)--                    ,xmlelement("DELIVERY_NUMBER",    cbr.transaction_ref)
                                                            ,
                             XMLELEMENT ("SELECTED_RULE_ID",
                                         cbr.cust_data_selected),
                             XMLELEMENT ("MATCHES_COUNT", cbr.matches_count),
                             XMLELEMENT ("ALL_RULE_IDS",
                                         cbr.other_cust_data_matches),
                             XMLELEMENT (
                                 "DATE",
                                 TO_CHAR (cbr.creation_date, 'DD-MON-YYYY'))))).getClobVal ()
                     xml,
                 COUNT (*)
                     cnt
            INTO vClob, vCnt
            FROM xxcp_bestmatch_report cbr, xxcp_source_assignments sa, xxcp_sys_sources s,
                 xxcp_cust_data_ctl cdc
           WHERE     cbr.source_assignment_id = sa.source_assignment_id
                 AND sa.source_id = s.source_id
                 AND cbr.category_name = cdc.category_name
                 AND TRUNC (cbr.creation_date) BETWEEN NVL (
                                                           vStart_Date,
                                                           TRUNC (
                                                               cbr.creation_date))
                                                   AND NVL (
                                                           vEnd_Date,
                                                           TRUNC (
                                                               cbr.creation_date))
        ORDER BY cbr.transaction_id;

        printClobOut (cClob => vClob, cHeader_Req => 'Y');
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Count is ' || TO_CHAR (vCnt));
    END;
END XXD_VT_ICS_RECON_EXTRACT_PKG;
/
