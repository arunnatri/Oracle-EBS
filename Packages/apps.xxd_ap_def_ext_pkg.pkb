--
-- XXD_AP_DEF_EXT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:31:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_AP_DEF_EXT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_AP_DEF_EXT_PKG
    --  Design       : This package provides Text extract for Deckers Deferred Prepaid Account Extract to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  14-MAY-2021     1.0       Srinath Siricilla              CCR0009308
    --  ####################################################################################################

    gn_user_id            CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id           CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id             CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id            CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id       CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id         CONSTANT NUMBER := fnd_global.conc_request_id;
    gd_date               CONSTANT DATE := SYSDATE;

    g_pkg_name            CONSTANT VARCHAR2 (30) := 'XXD_AP_DEF_EXT_PKG';
    g_log_level           CONSTANT NUMBER := FND_LOG.G_CURRENT_RUNTIME_LEVEL;
    gv_delimeter                   VARCHAR2 (1) := '|';

    g_gl_application_id   CONSTANT NUMBER := 101;
    g_po_application_id   CONSTANT NUMBER := 201;

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


    PROCEDURE write_def_recon_file (p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, x_ret_code OUT VARCHAR2
                                    , x_ret_message OUT VARCHAR2)
    IS
        CURSOR def_reconcilation IS
              SELECT (entity_uniq_identifier || CHR (9) || account_number || CHR (9) || key3 || CHR (9) || key4 || CHR (9) || key5 || CHR (9) || key6 || CHR (9) || key7 || CHR (9) || key8 || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || TO_CHAR (Period_End_Date, 'MM/DD/RRRR') || CHR (9) || Subledr_Rep_Bal || CHR (9) || Subledr_alt_Bal || CHR (9) || SUM (Subledr_Acc_Bal)) line
                FROM xxdo.xxd_ap_def_ext_t
               WHERE 1 = 1 AND request_id = gn_request_id
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
        FOR i IN def_reconcilation
        LOOP
            l_line   := i.line;
            fnd_file.put_line (fnd_file.output, l_line);
        END LOOP;


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
                       AND ffvl.description = 'DEFERRED'
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
                    FOR i IN def_reconcilation
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
    END write_def_recon_file;

    PROCEDURE write_op_file (p_file_path     IN     VARCHAR2,
                             p_file_name     IN     VARCHAR2,
                             p_acctng_date   IN     VARCHAR2,
                             x_ret_code         OUT VARCHAR2,
                             x_ret_message      OUT VARCHAR2)
    IS
        CURSOR op_file_def IS
              SELECT line
                FROM (SELECT 1 AS seq, ou_name || gv_delimeter || invoice_num || gv_delimeter || invoice_curr_code || gv_delimeter || invoice_date || gv_delimeter || vendor_name || gv_delimeter || vendor_site_code || gv_delimeter || charge_account || gv_delimeter || distribution_amount || gv_delimeter || line_amount || gv_delimeter || accounting_date || gv_delimeter || deferred_acctg_flag || gv_delimeter || def_acctg_start_date || gv_delimeter || def_acctg_end_date || gv_delimeter || entered_amount || gv_delimeter || accounted_amount || gv_delimeter || dr_segment1 || gv_delimeter || dr_segment2 || gv_delimeter || dr_segment3 || gv_delimeter || dr_segment4 || gv_delimeter || dr_segment5 || gv_delimeter || dr_segment6 || gv_delimeter || dr_segment7 || gv_delimeter || dr_segment8 || gv_delimeter || entered_dr || gv_delimeter || cr_segment1 || gv_delimeter || cr_segment2 || gv_delimeter || cr_segment3 || gv_delimeter || cr_segment4 || gv_delimeter || cr_segment5 || gv_delimeter || cr_segment6 || gv_delimeter || cr_segment7 || gv_delimeter || cr_segment8 || gv_delimeter || entered_cr line
                        FROM xxdo.xxd_ap_def_ext_t
                       WHERE 1 = 1 AND request_id = gn_request_id
                      UNION
                      SELECT 2 AS seq, 'OU_Name' || gv_delimeter || 'Invoice_Num' || gv_delimeter || 'Invoice_Curr_Code' || gv_delimeter || 'Invoice_Date' || gv_delimeter || 'Vendor_Name' || gv_delimeter || 'Vendor_Site_Code' || gv_delimeter || 'Charge_Account' || gv_delimeter || 'Distribution_Amount' || gv_delimeter || 'Line_Amount' || gv_delimeter || 'Accounting_Date' || gv_delimeter || 'Deferred_Acctg_Flag' || gv_delimeter || 'Def_Acctg_Start_Date' || gv_delimeter || 'Def_Acctg_End_Date' || gv_delimeter || 'Entered_Amount' || gv_delimeter || 'Accounted_Amount' || gv_delimeter || 'Dr_Segment1' || gv_delimeter || 'Dr_Segment2' || gv_delimeter || 'Dr_Segment3' || gv_delimeter || 'Dr_Segment4' || gv_delimeter || 'Dr_Segment5' || gv_delimeter || 'Dr_Segment6' || gv_delimeter || 'Dr_Segment7' || gv_delimeter || 'Dr_Segment8' || gv_delimeter || 'Entered_Dr' || gv_delimeter || 'Cr_Segment1' || gv_delimeter || 'Cr_Segment2' || gv_delimeter || 'Cr_Segment3' || gv_delimeter || 'Cr_Segment4' || gv_delimeter || 'Cr_Segment5' || gv_delimeter || 'Cr_Segment6' || gv_delimeter || 'Cr_Segment7' || gv_delimeter || 'Cr_Segment8' || gv_delimeter || 'Entered_Cr'
                        FROM DUAL)
            ORDER BY 1 DESC;


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
    BEGIN
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
                       AND ffvl.description = 'DEFERRED'
                       AND ffvl.flex_value = p_file_path;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_vs_file_path   := NULL;
                    lv_vs_file_name   := NULL;
            END;


            IF p_acctng_date IS NULL
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
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TO_DATE (p_acctng_date,
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
                /*BEGIN
                   SELECT ffvl.attribute2
                     INTO lv_ou_short_name
                     FROM apps.fnd_flex_value_sets fvs,
                          apps.fnd_flex_values_vl ffvl
                    WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                          AND fvs.flex_value_set_name =
                                 'XXD_GL_AAR_OU_SHORTNAME_VS'
                          AND NVL (TRUNC (ffvl.start_date_active),
                                   TRUNC (SYSDATE)) <= TRUNC (SYSDATE)
                          AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                                 TRUNC (SYSDATE)
                          AND ffvl.enabled_flag = 'Y'
                          AND ffvl.attribute1 = p_operating_unit;
                EXCEPTION
                   WHEN OTHERS
                   THEN
                      lv_ou_short_name := NULL;
                END; */

                lv_file_dir        := lv_vs_file_path;
                lv_ou_short_name   := NULL;
                lv_file_name       :=
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

                lv_output_file     :=
                    UTL_FILE.fopen (lv_file_dir, lv_file_name, 'W' --opening the file in write mode
                                                                  ,
                                    32767);

                IF UTL_FILE.is_open (lv_output_file)
                THEN
                    FOR i IN op_file_def
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

    PROCEDURE update_attributes (x_ret_message      OUT VARCHAR2,
                                 p_acctng_date   IN     VARCHAR2)
    IS
        l_last_date   VARCHAR2 (50);

        CURSOR c_get_data IS
            SELECT a.ROWID, a.dr_segment1 entity_uniq_ident, a.dr_segment6 account_number,
                   a.dr_segment2 key3, a.dr_segment3 key4, a.dr_segment4 key5,
                   a.dr_segment5 key6, a.dr_segment7 key7, NULL key8,
                   NULL key9, NULL key10, a.accounted_amount sub_acct_balance
              FROM xxdo.xxd_ap_def_ext_t a      --, gl_code_combinations_kfv c
             WHERE 1 = 1 AND a.request_id = gn_request_id;
    --AND a.acc_account = c.concatenated_segments;

    BEGIN
        -- Period end date of the as of date
        SELECT LAST_DAY (TO_DATE (p_acctng_date, 'RRRR/MM/DD HH24:MI:SS'))
          INTO l_last_date
          FROM DUAL;

        FOR i IN c_get_data
        LOOP
            UPDATE xxdo.xxd_ap_def_ext_t
               SET entity_uniq_identifier = i.entity_uniq_ident, Account_Number = i.account_number, Key3 = i.Key3,
                   Key4 = i.Key4, Key5 = i.Key5, Key6 = i.Key6,
                   Key7 = i.Key7, Key8 = i.Key8, Key9 = i.Key9,
                   Key10 = i.Key10, Period_End_Date = l_last_date, Subledr_Rep_Bal = NULL,
                   Subledr_alt_Bal = NULL, Subledr_Acc_Bal = i.sub_acct_balance
             WHERE ROWID = i.ROWID AND request_id = gn_request_id;
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_message   := SQLERRM;
    END update_attributes;

    PROCEDURE update_valueset_prc (p_file_path IN VARCHAR2)
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
           SET ffvl.ATTRIBUTE5 = lv_user_name, ffvl.ATTRIBUTE6 = lv_request_info
         WHERE     NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                   TRUNC (SYSDATE)
               AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                   TRUNC (SYSDATE)
               AND ffvl.enabled_flag = 'Y'
               AND ffvl.description = 'DEFERRED'
               AND ffvl.flex_value = p_file_path
               AND ffvl.flex_value_set_id IN
                       (SELECT flex_value_set_id
                          FROM apps.fnd_flex_value_sets
                         WHERE flex_value_set_name =
                               'XXD_GL_AAR_FILE_DETAILS_VS');

        COMMIT;
    END update_valueset_prc;

    PROCEDURE MAIN (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_acctng_date IN VARCHAR2
                    , p_file_path IN VARCHAR2)
    IS
        p_qty_precision          NUMBER := 2;

        CURSOR cur_inv (p_accounting_date VARCHAR2)
        IS
              SELECT                                                --DISTINCT
                     hou.name ou_name,
                     ai.invoice_num invoice_num,
                     ai.invoice_currency_code invoice_curr_code,
                     ai.invoice_date invoice_date,
                     asa.vendor_name vendor_name,
                     assa.vendor_site_code vendor_site_code,
                     gcc.concatenated_segments charge_account,
                     aid.amount distribution_amount,
                     aila.amount line_amount,
                     aid.accounting_date accounting_date,
                     aila.deferred_acctg_flag deferred_acctg_flag,
                     aila.def_acctg_start_date def_acctg_start_date,
                     aila.def_acctg_end_date def_acctg_end_date,
                     SUM (xel.entered_dr) entered_amount,
                     SUM (xel.accounted_dr) accounted_amount,
                     gcc.segment1 dr_segment1,
                     gcc.segment2 dr_segment2,
                     gcc.segment3 dr_segment3,
                     gcc.segment4 dr_segment4,
                     '1000' dr_segment5,
                     (CASE
                          WHEN gcc.segment6 IN
                                   (SELECT flex_value
                                      FROM (SELECT ffv.flex_value, ffv.parent_flex_value_low
                                              FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                             WHERE     ffvs.flex_value_set_name =
                                                       'XXDO_AP_PREPAID_ACC_DVS'
                                                   AND ffvs.flex_value_set_id =
                                                       ffv.flex_value_set_id))
                          THEN
                              (SELECT UNIQUE parent_flex_value_low
                                 FROM (SELECT ffv.flex_value, ffv.parent_flex_value_low
                                         FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                        WHERE     ffvs.flex_value_set_name =
                                                  'XXDO_AP_PREPAID_ACC_DVS'
                                              AND ffvs.flex_value_set_id =
                                                  ffv.flex_value_set_id)
                                WHERE flex_value = gcc.segment6 AND ROWNUM = 1)
                          ELSE
                              '11601'
                      END) dr_segment6,
                     gcc.segment7 dr_segment7,
                     gcc.segment8 dr_segment8,
                     SUM (xel.entered_dr) AS entered_dr,
                     gcc.segment1 cr_segment1,
                     gcc.segment2 cr_segment2,
                     gcc.segment3 cr_segment3,
                     gcc.segment4 cr_segment4,
                     '1000' cr_segment5,
                     '11610' cr_segment6,
                     gcc.segment7 cr_segment7,
                     gcc.segment8 cr_segment8,
                     ' ' blank,
                     SUM (xel.entered_dr) AS entered_cr
                FROM xla_ae_lines xel, xla_ae_headers xeh, ap_invoices_all ai,
                     xla.xla_transaction_entities xte, apps.gl_ledgers gl, apps.gl_code_combinations_kfv gcc,
                     apps.xla_distribution_links dl, apps.ap_invoice_distributions_all aid, apps.ap_invoice_lines_all aila,
                     hr_operating_units hou, ap_suppliers asa, ap_supplier_sites_all assa
               WHERE     xte.application_id = 200
                     AND xel.application_id = xeh.application_id
                     AND xte.application_id = xeh.application_id
                     AND xte.transaction_number = ai.invoice_num
                     AND xel.ae_header_id = xeh.ae_header_id
                     AND xte.source_id_int_1 = ai.invoice_id
                     AND xte.entity_id = xeh.entity_id
                     AND xel.gl_transfer_mode_code = 'D'
                     AND gl.LEDGER_CATEGORY_CODE = 'PRIMARY'
                     AND gl.ledger_id = xel.ledger_id
                     AND dl.ae_header_id = xeh.ae_header_id
                     AND dl.event_id = xeh.event_id
                     AND dl.accounting_line_code =
                         'MPA_ITEM_EXPENSE_RECOGNITION'
                     AND dl.source_distribution_id_num_1 =
                         aid.invoice_distribution_id
                     AND aid.invoice_id = ai.invoice_id
                     AND aid.invoice_line_number = aila.line_number
                     AND aid.invoice_id = aila.invoice_id
                     AND gcc.code_combination_id = xel.code_combination_id
                     AND aila.DEFERRED_ACCTG_FLAG = 'Y'
                     AND aid.DIST_CODE_COMBINATION_ID = xel.code_combination_id
                     AND ai.org_id = hou.organization_id
                     AND ai.vendor_id = asa.vendor_id
                     AND ai.vendor_site_id = assa.vendor_site_id
                     AND TRUNC (aid.accounting_date) <
                         TO_DATE (p_accounting_date, 'RRRR/MM/DD HH24:MI:SS')
                     AND TRUNC (xel.accounting_date) >=
                         TO_DATE (p_accounting_date, 'RRRR/MM/DD HH24:MI:SS')
            GROUP BY aid.dist_code_combination_id, aila.default_dist_ccid, ai.invoice_num,
                     gcc.concatenated_segments, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, '1000',
                     aid.amount, aila.amount, aila.deferred_acctg_flag,
                     aila.def_acctg_start_date, aila.def_acctg_end_date, ai.invoice_id,
                     ai.invoice_currency_code, ai.invoice_date, asa.vendor_name,
                     assa.vendor_site_code, hou.name, gcc.segment6,
                     gcc.segment7, gcc.segment8, aid.accounting_date
            ORDER BY 1, 4, 2;

        l_api_name      CONSTANT VARCHAR2 (30) := 'generate_data';
        l_api_version   CONSTANT NUMBER := 1.0;
        l_return_status          VARCHAR2 (1);

        l_full_name     CONSTANT VARCHAR2 (60)
                                     := G_PKG_NAME || '.' || l_api_name ;
        l_module        CONSTANT VARCHAR2 (60) := 'cst.plsql.' || l_full_name;


        l_msg_count              NUMBER;
        l_msg_data               VARCHAR2 (240);

        lv_ret_message           VARCHAR2 (2000) := NULL;
        l_file_name              VARCHAR2 (100);

        TYPE tb_rec_inv IS TABLE OF cur_inv%ROWTYPE;

        v_tb_rec_inv             tb_rec_inv;
        --v_tb_rec_cust    tb_rec_cust;
        l_count                  NUMBER;
        lv_ret_code              VARCHAR2 (30) := NULL;

        v_bulk_limit             NUMBER := 500;
    BEGIN
        OPEN cur_inv (p_acctng_date);

        LOOP
            FETCH cur_inv BULK COLLECT INTO v_tb_rec_inv LIMIT v_bulk_limit;


            BEGIN
                FORALL i IN 1 .. v_tb_rec_inv.COUNT
                    INSERT INTO xxdo.xxd_ap_def_ext_t (request_id,
                                                       ou_name,
                                                       invoice_num,
                                                       invoice_curr_code,
                                                       invoice_date,
                                                       vendor_name,
                                                       vendor_site_code,
                                                       charge_account,
                                                       distribution_amount,
                                                       line_amount,
                                                       accounting_date,
                                                       deferred_acctg_flag,
                                                       def_acctg_start_date,
                                                       def_acctg_end_date,
                                                       entered_amount,
                                                       accounted_amount,
                                                       dr_segment1,
                                                       dr_segment2,
                                                       dr_segment3,
                                                       dr_segment4,
                                                       dr_segment5,
                                                       dr_segment6,
                                                       dr_segment7,
                                                       dr_segment8,
                                                       entered_dr,
                                                       cr_segment1,
                                                       cr_segment2,
                                                       cr_segment3,
                                                       cr_segment4,
                                                       cr_segment5,
                                                       cr_segment6,
                                                       cr_segment7,
                                                       cr_segment8,
                                                       entered_cr,
                                                       creation_date,
                                                       created_by,
                                                       last_update_date,
                                                       last_updated_by)
                         VALUES (gn_request_id, v_tb_rec_inv (i).ou_name, v_tb_rec_inv (i).invoice_num, v_tb_rec_inv (i).invoice_curr_code, v_tb_rec_inv (i).invoice_date, v_tb_rec_inv (i).vendor_name, v_tb_rec_inv (i).vendor_site_code, v_tb_rec_inv (i).charge_account, v_tb_rec_inv (i).distribution_amount, v_tb_rec_inv (i).line_amount, v_tb_rec_inv (i).accounting_date, v_tb_rec_inv (i).deferred_acctg_flag, v_tb_rec_inv (i).def_acctg_start_date, v_tb_rec_inv (i).def_acctg_end_date, v_tb_rec_inv (i).entered_amount, v_tb_rec_inv (i).accounted_amount, v_tb_rec_inv (i).dr_segment1, v_tb_rec_inv (i).dr_segment2, v_tb_rec_inv (i).dr_segment3, v_tb_rec_inv (i).dr_segment4, v_tb_rec_inv (i).dr_segment5, v_tb_rec_inv (i).dr_segment6, v_tb_rec_inv (i).dr_segment7, v_tb_rec_inv (i).dr_segment8, v_tb_rec_inv (i).entered_dr, v_tb_rec_inv (i).cr_segment1, v_tb_rec_inv (i).cr_segment2, v_tb_rec_inv (i).cr_segment3, v_tb_rec_inv (i).cr_segment4, v_tb_rec_inv (i).cr_segment5, v_tb_rec_inv (i).cr_segment6, v_tb_rec_inv (i).cr_segment7, v_tb_rec_inv (i).cr_segment8, v_tb_rec_inv (i).entered_cr, gd_date, gn_user_id
                                 , gd_date, gn_user_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'insertion failed for  Table' || SQLERRM);
            END;

            COMMIT;
            EXIT WHEN CUR_INV%NOTFOUND;
        END LOOP;

        write_op_file (p_file_path, l_file_name, p_acctng_date,
                       lv_ret_code, lv_ret_message);

        update_attributes (lv_ret_message, p_acctng_date);

        write_def_recon_file (p_file_path, l_file_name, lv_ret_code,
                              lv_ret_message);

        update_valueset_prc (p_file_path);
    END MAIN;
END;
/
