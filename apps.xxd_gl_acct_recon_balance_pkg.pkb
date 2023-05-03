--
-- XXD_GL_ACCT_RECON_BALANCE_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_ACCT_RECON_BALANCE_PKG"
AS
    --****************************************************************************************************
    --*  NAME       : XXD_GL_ACCT_RECON_BALANCE_PKG
    --*  APPLICATION: Oracle General Ledger
    --*
    --*  AUTHOR     : Gaurav
    --*  DATE       : 01-MAR-2021
    --*
    --*  DESCRIPTION: This package will do the following
    --*               A. Extract account balances and generate tab delimted file
    --*  REVISION HISTORY:
    --*  Change Date     Version             By              Change Description
    --****************************************************************************************************
    --* 01-MAR-2021      1.0           Gaurav      Initial Creation
    --****************************************************************************************************
    /*segment1 -- company
    segment2 -- brand
    segment3 -- geo
    segment4 -- channel
    segment5 -- cost centre
    segment6 -- account
    segment7 -- intercompany
    segment8 -- future
     */

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

    PROCEDURE check_file_exists (p_file_path     IN     VARCHAR2,
                                 p_file_name     IN     VARCHAR2,
                                 x_file_exists      OUT BOOLEAN,
                                 x_file_length      OUT NUMBER,
                                 x_block_size       OUT BINARY_INTEGER)
    IS
        lv_proc_name     VARCHAR2 (30) := 'CHECK_FILE_EXISTS';
        lb_file_exists   BOOLEAN := FALSE;
        ln_file_length   NUMBER := NULL;
        ln_block_size    BINARY_INTEGER := NULL;
        lv_err_msg       VARCHAR2 (2000) := NULL;
    BEGIN
        --Checking if p_file_name file exists in p_file_dir directory
        --If exists, x_file_exists is true else false
        UTL_FILE.FGETATTR (location      => p_file_path,
                           filename      => p_file_name,
                           fexists       => lb_file_exists,
                           file_length   => ln_file_length,
                           block_size    => ln_block_size);
        x_file_exists   := lb_file_exists;
        x_file_length   := ln_file_length;
        x_block_size    := ln_block_size;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_file_exists   := lb_file_exists;
            x_file_length   := ln_file_length;
            x_block_size    := ln_block_size;
            lv_err_msg      :=
                SUBSTR (
                       'When Others expection while checking file is created or not in '
                    || lv_proc_name
                    || ' procedure. Error is: '
                    || SQLERRM,
                    1,
                    2000);
            print_log (lv_err_msg);
    END check_file_exists;

    PROCEDURE get_secondary_period (p_period_name          IN     VARCHAR2,
                                    x_period_name             OUT VARCHAR2,
                                    x_start_date              OUT VARCHAR2,
                                    x_quarter_start_date      OUT VARCHAR2,
                                    x_year_start_date         OUT VARCHAR2)
    IS
    BEGIN
        x_period_name          := NULL;
        x_start_date           := NULL;
        x_quarter_start_date   := NULL;
        x_year_start_date      := NULL;

        SELECT gp.period_name, gp.start_date, gp.quarter_start_date,
               gp.year_start_date
          INTO x_period_name, x_start_date, x_quarter_start_date, x_year_start_date
          FROM apps.gl_periods gp, apps.gl_periods gp1
         WHERE     gp1.period_name = p_period_name
               AND gp1.start_date = gp.start_date
               AND gp.period_set_name = 'DO_CY_CALENDAR'
               AND gp1.period_set_name = 'DO_FY_CALENDAR';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_period_name          := NULL;
            x_start_date           := NULL;
            x_quarter_start_date   := NULL;
            x_year_start_date      := NULL;
    END;

    FUNCTION get_record_exists (pn_ccid IN NUMBER, pv_period_end_date IN VARCHAR2, pv_stat_ledger IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_count   NUMBER;
    BEGIN
        ln_count   := 0;

        IF pv_stat_ledger IS NULL
        THEN
            NULL;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM DUAL
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_account_balance_t
                                 WHERE     1 = 1
                                       AND code_combination_id = pn_ccid
                                       AND TO_DATE (period_end_date,
                                                    'MM-DD-RRRR') =
                                           TO_DATE (pv_period_end_date,
                                                    'MM-DD-RRRR')
                                       AND stat_ledger_flag IS NULL);

                RETURN ln_count;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
                    RETURN ln_count;
            END;
        ELSIF pv_stat_ledger IS NOT NULL
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM DUAL
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_account_balance_t
                                 WHERE     1 = 1
                                       AND code_combination_id = pn_ccid
                                       AND TO_DATE (period_end_date,
                                                    'MM-DD-RRRR') =
                                           TO_DATE (pv_period_end_date,
                                                    'MM-DD-RRRR')
                                       AND stat_ledger_flag = pv_stat_ledger);

                RETURN ln_count;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
                    RETURN ln_count;
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
            RETURN ln_count;
    END get_record_exists;

    PROCEDURE write_bal_file (p_request_id           NUMBER,
                              p_file_path     IN     VARCHAR2,
                              p_file_name     IN     VARCHAR2,
                              x_ret_code         OUT VARCHAR2,
                              x_ret_message      OUT VARCHAR2)
    IS
        CURSOR write_account_balance IS
            SELECT entity_unique_identifier || CHR (9) || account_number || CHR (9) || brand || CHR (9) || geo || CHR (9) || channel || CHR (9) || costcenter || CHR (9) || intercompany || CHR (9) || statuary_ledger || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || account_desc || CHR (9) || account_reference1 || CHR (9) || financial_statement || CHR (9) || account_type || CHR (9) || acitve_account || CHR (9) || activity_in_period || CHR (9) || alt_currency || CHR (9) || account_currency || CHR (9) || period_end_date || CHR (9) || gl_reporting_balance || CHR (9) || gl_alt_balance || CHR (9) || gl_account_balance || CHR (9) || account_reference_2 || CHR (9) || account_reference_3 || CHR (9) || account_reference_4 || CHR (9) || account_reference_5 || CHR (9) || account_reference_6 line
              FROM XXDO.xxd_gl_account_balance_t
             WHERE     1 = 1
                   AND request_id = p_request_id
                   AND activity_in_period = 'TRUE';

        --DEFINE VARIABLES
        lv_file_path       VARCHAR2 (360) := p_file_path;
        lv_output_file     UTL_FILE.file_type;
        lv_outbound_file   VARCHAR2 (360) := p_file_name;
        lv_err_msg         VARCHAR2 (2000) := NULL;
        lv_line            VARCHAR2 (32767) := NULL;
    BEGIN
        IF lv_file_path IS NULL
        THEN                                            -- WRITE INTO FND LOGS
            FOR i IN write_account_balance
            LOOP
                lv_line   := i.line;
                fnd_file.put_line (fnd_file.OUTPUT, lv_line);
            END LOOP;
        ELSE
            -- WRITE INTO BL FOLDER

            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_file, 'W' --opening the file in write mode
                                                                   ,
                                32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                FOR i IN write_account_balance
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
    END write_bal_file;

    FUNCTION is_parent (p_in_value VARCHAR2, p_in_vs_name VARCHAR2)
        RETURN VARCHAR2
    IS
        l_result   VARCHAR2 (1) := 'N';
    BEGIN
        IF p_in_value IS NULL
        THEN
            RETURN 'N';
        ELSE
            SELECT 'P'
              INTO l_result
              FROM fnd_flex_value_children_v a, fnd_flex_value_sets b
             WHERE     parent_flex_value = p_in_value
                   AND b.FLEX_VALUE_SET_ID = a.FLEX_VALUE_SET_ID
                   AND FLEX_VALUE_SET_NAME = p_in_vs_name
                   AND ROWNUM = 1;

            RETURN l_result;
        END IF;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 'C';
        WHEN OTHERS
        THEN
            RETURN l_result;
    END;

    --  This procedure is for account extraction from master valueset and store in the the custom table

    PROCEDURE main_control (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2)
    IS
        CURSOR c_valueset_entries (l_prg_last_run_date     DATE,
                                   l_vs_last_update_date   DATE)
        IS
            (SELECT *
               FROM (WITH
                         weight_all
                         AS
                             (SELECT company_weight, brand_weight, geo_weight,
                                     channel_weight, costcenter_weight, account_weight,
                                     intercompany_weight
                                FROM (  SELECT ffv.flex_value, ffvt.description value_description, ffvs.flex_value_set_id
                                          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
                                         WHERE     ffvs.flex_value_set_id =
                                                   ffv.flex_value_set_id
                                               AND ffv.flex_value_id =
                                                   ffvt.flex_value_id
                                               AND ffvt.language =
                                                   USERENV ('LANG')
                                               AND flex_value_set_name LIKE
                                                       'XXD_ACCT_INFO_SEG_WEIGHTAGE'
                                               AND ffv.enabled_flag = 'Y'
                                      ORDER BY flex_value ASC)
                                     PIVOT (MAX (value_description)
                                           FOR flex_value
                                           IN ('SEGMENT1' company_weight,
                                              'SEGMENT2' brand_weight,
                                              'SEGMENT3' geo_weight,
                                              'SEGMENT4' channel_weight,
                                              'SEGMENT5' costcenter_weight,
                                              'SEGMENT6' account_weight,
                                              'SEGMENT7' intercompany_weight)))
                       SELECT CASE
                                  WHEN Weightage IS NULL
                                  THEN
                                      (  CASE
                                             WHEN company_hierchy = 'P'
                                             THEN
                                                 company_weight + 1
                                             WHEN company_hierchy = 'C'
                                             THEN
                                                 company_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN brand_hierchy = 'P'
                                             THEN
                                                 brand_weight + 1
                                             WHEN brand_hierchy = 'C'
                                             THEN
                                                 brand_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN geo_hierchy = 'P'
                                             THEN
                                                 geo_weight + 1
                                             WHEN geo_hierchy = 'C'
                                             THEN
                                                 geo_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN channel_hierchy = 'P'
                                             THEN
                                                 channel_weight + 1
                                             WHEN channel_hierchy = 'C'
                                             THEN
                                                 channel_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN costcenter_hierchy = 'P'
                                             THEN
                                                 costcenter_weight + 1
                                             WHEN costcenter_hierchy = 'C'
                                             THEN
                                                 costcenter_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN account_hierchy = 'P'
                                             THEN
                                                 account_weight + 1
                                             WHEN account_hierchy = 'C'
                                             THEN
                                                 account_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN intercompany_hierchy = 'P'
                                             THEN
                                                 intercompany_weight + 1
                                             WHEN intercompany_hierchy = 'C'
                                             THEN
                                                 intercompany_weight + 2
                                             ELSE
                                                 0
                                         END)
                                  ELSE
                                      TO_NUMBER (Weightage)
                              END AS total_rank,
                              a.*
                         FROM (SELECT flex_value
                                          unique_identifier,
                                      attribute2
                                          company,
                                      attribute3
                                          brand,
                                      attribute4
                                          geo,
                                      attribute5
                                          channel,
                                      attribute6
                                          costcenter,
                                      attribute7
                                          account,
                                      attribute8
                                          intercompany,
                                      attribute9
                                          future,
                                        CASE
                                            WHEN attribute2 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute3 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute4 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute5 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute6 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute7 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute8 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute9 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                          AS total_not_null,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute2),
                                          'DO_GL_COMPANY')
                                          company_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute3),
                                          'DO_GL_BRAND')
                                          brand_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute4),
                                          'DO_GL_GEO')
                                          geo_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute5),
                                          'DO_GL_CHANNEL')
                                          channel_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute6),
                                          'DO_GL_COST_CENTER')
                                          costcenter_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute7),
                                          'DO_GL_ACCOUNT')
                                          account_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute8),
                                          'DO_GL_COMPANY')
                                          intercompany_hierchy,
                                      company_weight,
                                      brand_weight,
                                      geo_weight,
                                      channel_weight,
                                      costcenter_weight,
                                      account_weight,
                                      intercompany_weight,
                                      b.attribute39
                                          Weightage,
                                      ATTRIBUTE1,
                                      ATTRIBUTE2,
                                      ATTRIBUTE3,
                                      ATTRIBUTE4,
                                      ATTRIBUTE5,
                                      ATTRIBUTE6,
                                      ATTRIBUTE7,
                                      ATTRIBUTE8,
                                      ATTRIBUTE9,
                                      ATTRIBUTE10,
                                      ATTRIBUTE11,
                                      ATTRIBUTE12,
                                      ATTRIBUTE13,
                                      ATTRIBUTE14,
                                      ATTRIBUTE15,
                                      ATTRIBUTE16,
                                      ATTRIBUTE17,
                                      ATTRIBUTE18,
                                      ATTRIBUTE19,
                                      ATTRIBUTE20,
                                      ATTRIBUTE21,
                                      ATTRIBUTE22,
                                      ATTRIBUTE23,
                                      ATTRIBUTE24,
                                      ATTRIBUTE25,
                                      ATTRIBUTE26,
                                      ATTRIBUTE27,
                                      ATTRIBUTE28,
                                      ATTRIBUTE29,
                                      ATTRIBUTE30,
                                      ATTRIBUTE31,
                                      ATTRIBUTE32,
                                      ATTRIBUTE33,
                                      ATTRIBUTE34,
                                      ATTRIBUTE35,
                                      ATTRIBUTE36,
                                      ATTRIBUTE37,
                                      ATTRIBUTE38,
                                      ATTRIBUTE39,
                                      ATTRIBUTE40,
                                      ATTRIBUTE41,
                                      ATTRIBUTE42,
                                      ATTRIBUTE43,
                                      ATTRIBUTE44,
                                      ATTRIBUTE45,
                                      ATTRIBUTE46,
                                      ATTRIBUTE47,
                                      ATTRIBUTE48,
                                      ATTRIBUTE49,
                                      ATTRIBUTE50,
                                      DO_BL_ACCOUNT_BALANCE_1.*
                                 FROM fnd_flex_value_sets a,
                                      fnd_flex_values b,
                                      weight_all c,
                                      (SELECT flex_value vs_line_identifier_1, ATTRIBUTE1 ATTRIBUTE1_2, ATTRIBUTE2 ATTRIBUTE2_2,
                                              ATTRIBUTE3 ATTRIBUTE3_2, ATTRIBUTE4 ATTRIBUTE4_2, ATTRIBUTE5 ATTRIBUTE5_2,
                                              ATTRIBUTE6 ATTRIBUTE6_2, ATTRIBUTE7 ATTRIBUTE7_2, ATTRIBUTE8 ATTRIBUTE8_2,
                                              ATTRIBUTE9 ATTRIBUTE9_2, ATTRIBUTE10 ATTRIBUTE10_2, ATTRIBUTE11 ATTRIBUTE11_2,
                                              ATTRIBUTE12 ATTRIBUTE12_2, ATTRIBUTE13 ATTRIBUTE13_2, ATTRIBUTE14 ATTRIBUTE14_2,
                                              ATTRIBUTE15 ATTRIBUTE15_2, ATTRIBUTE16 ATTRIBUTE16_2, ATTRIBUTE17 ATTRIBUTE17_2,
                                              ATTRIBUTE18 ATTRIBUTE18_2, ATTRIBUTE19 ATTRIBUTE19_2, ATTRIBUTE20 ATTRIBUTE20_2,
                                              ATTRIBUTE21 ATTRIBUTE21_2, ATTRIBUTE22 ATTRIBUTE22_2, ATTRIBUTE23 ATTRIBUTE23_2,
                                              ATTRIBUTE24 ATTRIBUTE24_2, ATTRIBUTE25 ATTRIBUTE25_2, ATTRIBUTE26 ATTRIBUTE26_2,
                                              ATTRIBUTE27 ATTRIBUTE27_2, ATTRIBUTE28 ATTRIBUTE28_2, ATTRIBUTE29 ATTRIBUTE29_2,
                                              ATTRIBUTE30 ATTRIBUTE30_2, ATTRIBUTE31 ATTRIBUTE31_2, ATTRIBUTE32 ATTRIBUTE32_2,
                                              ATTRIBUTE33 ATTRIBUTE33_2, ATTRIBUTE34 ATTRIBUTE34_2, ATTRIBUTE35 ATTRIBUTE35_2,
                                              ATTRIBUTE36 ATTRIBUTE36_2, ATTRIBUTE37 ATTRIBUTE37_2, ATTRIBUTE38 ATTRIBUTE38_2,
                                              ATTRIBUTE39 ATTRIBUTE39_2, ATTRIBUTE40 ATTRIBUTE40_2, ATTRIBUTE41 ATTRIBUTE41_2,
                                              ATTRIBUTE42 ATTRIBUTE42_2, ATTRIBUTE43 ATTRIBUTE43_2, ATTRIBUTE44 ATTRIBUTE44_2,
                                              ATTRIBUTE45 ATTRIBUTE45_2, ATTRIBUTE46 ATTRIBUTE46_2, ATTRIBUTE47 ATTRIBUTE47_2,
                                              ATTRIBUTE48 ATTRIBUTE48_2, ATTRIBUTE49 ATTRIBUTE49_2, ATTRIBUTE50 ATTRIBUTE50_2,
                                              b.start_date_active start_date_active_1, b.end_date_active end_date_active_1
                                         FROM fnd_flex_value_sets a, fnd_flex_values b
                                        WHERE     a.flex_value_set_name =
                                                  'DO_BL_ACCOUNT_BALANCE_1'
                                              AND a.flex_value_set_id =
                                                  b.flex_value_set_id
                                              AND b.enabled_flag = 'Y'
                                              AND SYSDATE BETWEEN NVL (
                                                                      b.start_date_active,
                                                                      SYSDATE)
                                                              AND NVL (
                                                                      b.end_date_active,
                                                                      SYSDATE))
                                      DO_BL_ACCOUNT_BALANCE_1
                                WHERE     a.flex_value_set_name =
                                          'DO_BL_ACCOUNT_BALANCE'
                                      AND b.flex_value =
                                          DO_BL_ACCOUNT_BALANCE_1.vs_line_identifier_1(+)
                                      AND a.flex_value_set_id =
                                          b.flex_value_set_id
                                      AND b.enabled_flag = 'Y'
                                      AND SYSDATE BETWEEN NVL (
                                                              b.start_date_active,
                                                              SYSDATE)
                                                      AND NVL (
                                                              b.end_date_active,
                                                              SYSDATE)
                                      AND l_vs_last_update_date >
                                          l_prg_last_run_date) a
                     ORDER BY total_rank DESC));

        CURSOR c_get_ccid_notfromvs IS
            (SELECT *
               FROM (WITH
                         weight_all
                         AS
                             (SELECT company_weight, brand_weight, geo_weight,
                                     channel_weight, costcenter_weight, account_weight,
                                     intercompany_weight
                                FROM (  SELECT ffv.flex_value, ffvt.description value_description, ffvs.flex_value_set_id
                                          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
                                         WHERE     ffvs.flex_value_set_id =
                                                   ffv.flex_value_set_id
                                               AND ffv.flex_value_id =
                                                   ffvt.flex_value_id
                                               AND ffvt.language =
                                                   USERENV ('LANG')
                                               AND flex_value_set_name LIKE
                                                       'XXD_ACCT_INFO_SEG_WEIGHTAGE'
                                               AND ffv.enabled_flag = 'Y'
                                      ORDER BY flex_value ASC)
                                     PIVOT (MAX (value_description)
                                           FOR flex_value
                                           IN ('SEGMENT1' company_weight,
                                              'SEGMENT2' brand_weight,
                                              'SEGMENT3' geo_weight,
                                              'SEGMENT4' channel_weight,
                                              'SEGMENT5' costcenter_weight,
                                              'SEGMENT6' account_weight,
                                              'SEGMENT7' intercompany_weight)))
                     SELECT   CASE
                                  WHEN company_hierchy = 'P'
                                  THEN
                                      company_weight + 1
                                  WHEN company_hierchy = 'C'
                                  THEN
                                      company_weight + 2
                                  ELSE
                                      0
                              END
                            + CASE
                                  WHEN brand_hierchy = 'P'
                                  THEN
                                      brand_weight + 1
                                  WHEN brand_hierchy = 'C'
                                  THEN
                                      brand_weight + 2
                                  ELSE
                                      0
                              END
                            + CASE
                                  WHEN geo_hierchy = 'P' THEN geo_weight + 1
                                  WHEN geo_hierchy = 'C' THEN geo_weight + 2
                                  ELSE 0
                              END
                            + CASE
                                  WHEN channel_hierchy = 'P'
                                  THEN
                                      channel_weight + 1
                                  WHEN channel_hierchy = 'C'
                                  THEN
                                      channel_weight + 2
                                  ELSE
                                      0
                              END
                            + CASE
                                  WHEN costcenter_hierchy = 'P'
                                  THEN
                                      costcenter_weight + 1
                                  WHEN costcenter_hierchy = 'C'
                                  THEN
                                      costcenter_weight + 2
                                  ELSE
                                      0
                              END
                            + CASE
                                  WHEN account_hierchy = 'P'
                                  THEN
                                      account_weight + 1
                                  WHEN account_hierchy = 'C'
                                  THEN
                                      account_weight + 2
                                  ELSE
                                      0
                              END
                            + CASE
                                  WHEN intercompany_hierchy = 'P'
                                  THEN
                                      intercompany_weight + 1
                                  WHEN intercompany_hierchy = 'C'
                                  THEN
                                      intercompany_weight + 2
                                  ELSE
                                      0
                              END AS total_rank,
                            a.*
                       FROM (SELECT code_combination_id, chart_of_accounts_id, segment1 company,
                                    segment2 brand, segment3 geo, segment4 channel,
                                    segment5 costcenter, segment6 account, segment7 intercompany,
                                    segment8 future, NULL total_not_null, xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment1), 'DO_GL_COMPANY') company_hierchy,
                                    xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment2), 'DO_GL_BRAND') brand_hierchy, xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment3), 'DO_GL_GEO') geo_hierchy, xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment4), 'DO_GEO_CHANNEL') channel_hierchy,
                                    xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment5), 'DO_GL_COST_CENTER') costcenter_hierchy, xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment6), 'DO_GL_ACCOUNT') account_hierchy, xxd_gl_acct_recon_balance_pkg.is_parent (TO_NUMBER (segment7), 'DO_GL_COMPANY') intercompany_hierchy,
                                    company_weight, brand_weight, geo_weight,
                                    channel_weight, costcenter_weight, account_weight,
                                    intercompany_weight
                               FROM gl_code_combinations_kfv a, weight_all b
                              WHERE     1 = 1
                                    AND gl_account_type IN ('A', 'O', 'L')
                                    AND enabled_flag = 'Y'
                                    -- AND LAST_UPDATE_DATE > l_prg_last_run_date
                                    AND NOT EXISTS
                                            (SELECT 1
                                               FROM xxdo.xxd_gl_acc_recon_extract_t
                                              WHERE     extract_level = 2
                                                    AND ccid =
                                                        a.code_combination_id))
                            a)
              WHERE     1 = 1
                    AND COMPANY_HIERCHY = 'C'
                    AND BRAND_HIERCHY = 'C'
                    AND GEO_HIERCHY = 'C'
                    AND CHANNEL_HIERCHY = 'C'
                    AND COSTCENTER_HIERCHY = 'C'
                    AND ACCOUNT_HIERCHY = 'C'
                    AND INTERCOMPANY_HIERCHY = 'C');

        CURSOR c_get_DI_vs_indentifier (p_in_account VARCHAR2)
        IS
            (SELECT *
               FROM (WITH
                         weight_all
                         AS
                             (SELECT company_weight, brand_weight, geo_weight,
                                     channel_weight, costcenter_weight, account_weight,
                                     intercompany_weight
                                FROM (  SELECT ffv.flex_value, ffvt.description value_description, ffvs.flex_value_set_id
                                          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt
                                         WHERE     ffvs.flex_value_set_id =
                                                   ffv.flex_value_set_id
                                               AND ffv.flex_value_id =
                                                   ffvt.flex_value_id
                                               AND ffvt.language =
                                                   USERENV ('LANG')
                                               AND flex_value_set_name LIKE
                                                       'XXD_ACCT_INFO_SEG_WEIGHTAGE'
                                               AND ffv.enabled_flag = 'Y'
                                      ORDER BY flex_value ASC)
                                     PIVOT (MAX (value_description)
                                           FOR flex_value
                                           IN ('SEGMENT1' company_weight,
                                              'SEGMENT2' brand_weight,
                                              'SEGMENT3' geo_weight,
                                              'SEGMENT4' channel_weight,
                                              'SEGMENT5' costcenter_weight,
                                              'SEGMENT6' account_weight,
                                              'SEGMENT7' intercompany_weight)))
                       SELECT CASE
                                  WHEN Weightage IS NULL
                                  THEN
                                      (  CASE
                                             WHEN company_hierchy = 'P'
                                             THEN
                                                 company_weight + 1
                                             WHEN company_hierchy = 'C'
                                             THEN
                                                 company_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN brand_hierchy = 'P'
                                             THEN
                                                 brand_weight + 1
                                             WHEN brand_hierchy = 'C'
                                             THEN
                                                 brand_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN geo_hierchy = 'P'
                                             THEN
                                                 geo_weight + 1
                                             WHEN geo_hierchy = 'C'
                                             THEN
                                                 geo_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN channel_hierchy = 'P'
                                             THEN
                                                 channel_weight + 1
                                             WHEN channel_hierchy = 'C'
                                             THEN
                                                 channel_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN costcenter_hierchy = 'P'
                                             THEN
                                                 costcenter_weight + 1
                                             WHEN costcenter_hierchy = 'C'
                                             THEN
                                                 costcenter_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN account_hierchy = 'P'
                                             THEN
                                                 account_weight + 1
                                             WHEN account_hierchy = 'C'
                                             THEN
                                                 account_weight + 2
                                             ELSE
                                                 0
                                         END
                                       + CASE
                                             WHEN intercompany_hierchy = 'P'
                                             THEN
                                                 intercompany_weight + 1
                                             WHEN intercompany_hierchy = 'C'
                                             THEN
                                                 intercompany_weight + 2
                                             ELSE
                                                 0
                                         END)
                                  ELSE
                                      TO_NUMBER (Weightage)
                              END AS total_rank,
                              a.*
                         FROM (SELECT flex_value
                                          unique_identifier,
                                      attribute2
                                          company,
                                      attribute3
                                          brand,
                                      attribute4
                                          geo,
                                      attribute5
                                          channel,
                                      attribute6
                                          costcenter,
                                      attribute7
                                          account,
                                      attribute8
                                          intercompany,
                                      attribute9
                                          future,
                                        CASE
                                            WHEN attribute2 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute3 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute4 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute5 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute6 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute7 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute8 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                      + CASE
                                            WHEN attribute9 IS NOT NULL THEN 1
                                            ELSE 0
                                        END
                                          AS total_not_null,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute2),
                                          'DO_GL_COMPANY')
                                          company_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute3),
                                          'DO_GL_BRAND')
                                          brand_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute4),
                                          'DO_GL_GEO')
                                          geo_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute5),
                                          'DO_GL_CHANNEL')
                                          channel_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute6),
                                          'DO_GL_COST_CENTER')
                                          costcenter_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute7),
                                          'DO_GL_ACCOUNT')
                                          account_hierchy,
                                      xxd_gl_acct_recon_balance_pkg.is_parent (
                                          TO_NUMBER (attribute8),
                                          'DO_GL_COMPANY')
                                          intercompany_hierchy,
                                      company_weight,
                                      brand_weight,
                                      geo_weight,
                                      channel_weight,
                                      costcenter_weight,
                                      account_weight,
                                      intercompany_weight,
                                      b.attribute39
                                          Weightage
                                 FROM fnd_flex_value_sets a, fnd_flex_values b, weight_all c
                                WHERE     a.flex_value_set_name =
                                          'DO_BL_ACCOUNT_BALANCE'
                                      AND a.flex_value_set_id =
                                          b.flex_value_set_id
                                      AND b.enabled_flag = 'Y'
                                      AND b.attribute7 IN
                                              (SELECT (PARENT_FLEX_VALUE)
                                                 FROM fnd_flex_value_children_v
                                                WHERE flex_value = p_in_account
                                               UNION
                                               SELECT p_in_account FROM DUAL)
                                      AND SYSDATE BETWEEN NVL (
                                                              b.start_date_active,
                                                              SYSDATE)
                                                      AND NVL (
                                                              b.end_date_active,
                                                              SYSDATE)) a
                     ORDER BY total_rank DESC));

        TYPE value_set_entries_type
            IS TABLE OF xxdo.xxd_gl_acc_recon_extract_t%ROWTYPE;

        v_value_set_entries_type    value_set_entries_type
                                        := value_set_entries_type ();

        v_line_record               xxdo.xxd_gl_acc_recon_extract_t%ROWTYPE;

        TYPE code_combination_type
            IS TABLE OF gl_code_combinations_kfv%ROWTYPE;

        TYPE code_combination_type_direct
            IS TABLE OF c_get_ccid_notfromvs%ROWTYPE;



        v_code_combination_type     code_combination_type
                                        := code_combination_type ();
        v_code_combination_direct   code_combination_type_direct
                                        := code_combination_type_direct ();
        v_code_combination_di       code_combination_type
                                        := code_combination_type ();


        account_type_tbl            xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        company_type_tbl            xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        brand_type_tbl              xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        geo_type_tbl                xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        channel_type_tbl            xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        cc_type_tbl                 xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        ic_type_tbl                 xxdo.xxd_gl_item_recon_tbl_type
            := xxdo.xxd_gl_item_recon_tbl_type (NULL);
        l_prg_start_date            VARCHAR2 (100);
        l_flag                      VARCHAR2 (1) := 'N';
        lb_return                   BOOLEAN;
        l_line_identifier           VARCHAR2 (100);
        l_vs_last_update_date       DATE;
        l_prg_last_run_date         DATE;
        l_count                     NUMBER := 0;
        l_count_di                  NUMBER;
        l_request_id                NUMBER;
        l_value                     VARCHAR2 (240);
        l_full_load                 VARCHAR2 (1) := 'N';
    BEGIN
        l_request_id       := fnd_global.conc_request_id;
        l_prg_start_date   := TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS');
        l_prg_last_run_date   :=
            NVL (
                TO_DATE (fnd_profile.VALUE ('XXD_GL_ACC_EXTRACT_TIME'),
                         'DD-MON-YYYY HH24:MI:SS'),
                SYSDATE - 1);

        BEGIN
            SELECT MAX (b.last_update_date)
              INTO l_vs_last_update_date
              FROM fnd_flex_value_sets a, fnd_flex_values b
             WHERE     a.flex_value_set_name IN
                           ('DO_BL_ACCOUNT_BALANCE', 'DO_BL_ACCOUNT_BALANCE_1')
                   AND a.flex_value_set_id = b.flex_value_set_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_vs_last_update_date   := SYSDATE;
        END;



        -- lOop through each and every entry of valueset
        FOR i
            IN c_valueset_entries (l_prg_last_run_date,
                                   l_vs_last_update_date)
        LOOP
            -- valuset set values got changes since the last time this pg ran; reload the table completely
            -- truncate will execte onyl once;
            print_log ('inside vs loop');

            IF l_count = 0
            THEN
                INSERT INTO xxdo.xxd_gl_acc_recon_extract_h (
                                request_id,
                                ccid,
                                vs_unique_identifier,
                                created_by,
                                creation_date)
                    SELECT request_id, ccid, vs_unique_identifier,
                           created_by, creation_date
                      FROM xxdo.xxd_gl_acc_recon_extract_t
                     WHERE extract_level = 2 AND RECORD_SOURCE = 'VS';

                --- delete ccids which are interfaced via VS and reload freshly
                -- DELETE FROM xxdo.xxd_gl_acc_recon_extract_t
                --      WHERE NVL (RECORD_SOURCE, 'XX') <> 'DI';

                EXECUTE IMMEDIATE('TRUNCATE TABLE XXDO.XXD_GL_ACC_RECON_EXTRACT_T');

                COMMIT;
            END IF;

            l_count       := l_count + 1;

            INSERT INTO XXDO.XXD_GL_ACC_RECON_EXTRACT_T (
                            request_id,
                            vs_unique_identifier,
                            company,
                            brand,
                            geo,
                            channel,
                            costcenter,
                            account,
                            intercompany,
                            Weightage,
                            company_hierchy,
                            brand_hierchy,
                            geo_hierchy,
                            channel_hierchy,
                            costcenter_hierchy,
                            account_hierchy,
                            intercompany_hierchy,
                            total_rank,
                            extract_level,
                            created_by,
                            creation_date)
                 VALUES (l_request_id, i.unique_identifier, i.company,
                         i.brand, i.geo, i.channel,
                         i.costcenter, i.account, i.intercompany,
                         i.weightage, i.company_hierchy, i.brand_hierchy,
                         i.geo_hierchy, i.channel_hierchy, i.costcenter_hierchy, i.account_hierchy, i.intercompany_hierchy, i.total_rank
                         , 1, fnd_global.user_id, SYSDATE);


            -- TAKE BACKUP OF CURRENT VALUES SET ALL ATTRIBUTES 1..50
            account_type_tbl.delete;
            brand_type_tbl.delete;
            company_type_tbl.delete;
            Geo_type_tbl.delete;
            channel_type_tbl.delete;
            cc_type_tbl.delete;
            ic_type_tbl.delete;

            FOR id
                IN (  SELECT descriptive_flex_context_code, APPLICATION_COLUMN_NAME, COLUMN_SEQ_NUM,
                             END_USER_COLUMN_NAME, enabled_flag, NULL VALUE
                        FROM fnd_descr_flex_col_usage_vl
                       WHERE descriptive_flex_context_code IN
                                 ('DO_BL_ACCOUNT_BALANCE', 'DO_BL_ACCOUNT_BALANCE_1')
                    ORDER BY 1, 3)
            LOOP
                IF id.descriptive_flex_context_code = 'DO_BL_ACCOUNT_BALANCE'
                THEN
                    IF id.application_column_name = 'ATTRIBUTE1'
                    THEN
                        l_value   := i.attribute1;
                    ELSIF id.application_column_name = 'ATTRIBUTE2'
                    THEN
                        l_value   := i.attribute2;
                    ELSIF id.application_column_name = 'ATTRIBUTE3'
                    THEN
                        l_value   := i.attribute3;
                    ELSIF id.application_column_name = 'ATTRIBUTE4'
                    THEN
                        l_value   := i.attribute4;
                    ELSIF id.application_column_name = 'ATTRIBUTE5'
                    THEN
                        l_value   := i.attribute5;
                    ELSIF id.application_column_name = 'ATTRIBUTE6'
                    THEN
                        l_value   := i.attribute6;
                    ELSIF id.application_column_name = 'ATTRIBUTE7'
                    THEN
                        l_value   := i.attribute7;
                    ELSIF id.application_column_name = 'ATTRIBUTE8'
                    THEN
                        l_value   := i.attribute8;
                    ELSIF id.application_column_name = 'ATTRIBUTE9'
                    THEN
                        l_value   := i.attribute9;
                    ELSIF id.application_column_name = 'ATTRIBUTE10'
                    THEN
                        l_value   := i.attribute10;
                    ELSIF id.application_column_name = 'ATTRIBUTE11'
                    THEN
                        l_value   := i.attribute11;
                    ELSIF id.application_column_name = 'ATTRIBUTE12'
                    THEN
                        l_value   := i.attribute12;
                    ELSIF id.application_column_name = 'ATTRIBUTE13'
                    THEN
                        l_value   := i.attribute13;
                    ELSIF id.application_column_name = 'ATTRIBUTE14'
                    THEN
                        l_value   := i.attribute14;
                    ELSIF id.application_column_name = 'ATTRIBUTE15'
                    THEN
                        l_value   := i.attribute15;
                    ELSIF id.application_column_name = 'ATTRIBUTE16'
                    THEN
                        l_value   := i.attribute16;
                    ELSIF id.application_column_name = 'ATTRIBUTE17'
                    THEN
                        l_value   := i.attribute17;
                    ELSIF id.application_column_name = 'ATTRIBUTE18'
                    THEN
                        l_value   := i.attribute18;
                    ELSIF id.application_column_name = 'ATTRIBUTE19'
                    THEN
                        l_value   := i.attribute19;
                    ELSIF id.application_column_name = 'ATTRIBUTE20'
                    THEN
                        l_value   := i.attribute20;
                    ELSIF id.application_column_name = 'ATTRIBUTE21'
                    THEN
                        l_value   := i.attribute21;
                    ELSIF id.application_column_name = 'ATTRIBUTE22'
                    THEN
                        l_value   := i.attribute22;
                    ELSIF id.application_column_name = 'ATTRIBUTE23'
                    THEN
                        l_value   := i.attribute23;
                    ELSIF id.application_column_name = 'ATTRIBUTE24'
                    THEN
                        l_value   := i.attribute24;
                    ELSIF id.application_column_name = 'ATTRIBUTE25'
                    THEN
                        l_value   := i.attribute25;
                    ELSIF id.application_column_name = 'ATTRIBUTE26'
                    THEN
                        l_value   := i.attribute26;
                    ELSIF id.application_column_name = 'ATTRIBUTE27'
                    THEN
                        l_value   := i.attribute27;
                    ELSIF id.application_column_name = 'ATTRIBUTE28'
                    THEN
                        l_value   := i.attribute28;
                    ELSIF id.application_column_name = 'ATTRIBUTE29'
                    THEN
                        l_value   := i.attribute29;
                    ELSIF id.application_column_name = 'ATTRIBUTE30'
                    THEN
                        l_value   := i.attribute30;
                    ELSIF id.application_column_name = 'ATTRIBUTE31'
                    THEN
                        l_value   := i.attribute31;
                    ELSIF id.application_column_name = 'ATTRIBUTE32'
                    THEN
                        l_value   := i.attribute32;
                    ELSIF id.application_column_name = 'ATTRIBUTE33'
                    THEN
                        l_value   := i.attribute33;
                    ELSIF id.application_column_name = 'ATTRIBUTE34'
                    THEN
                        l_value   := i.attribute34;
                    ELSIF id.application_column_name = 'ATTRIBUTE35'
                    THEN
                        l_value   := i.attribute35;
                    ELSIF id.application_column_name = 'ATTRIBUTE36'
                    THEN
                        l_value   := i.attribute36;
                    ELSIF id.application_column_name = 'ATTRIBUTE37'
                    THEN
                        l_value   := i.attribute37;
                    ELSIF id.application_column_name = 'ATTRIBUTE38'
                    THEN
                        l_value   := i.attribute38;
                    ELSIF id.application_column_name = 'ATTRIBUTE39'
                    THEN
                        l_value   := i.attribute39;
                    ELSIF id.application_column_name = 'ATTRIBUTE40'
                    THEN
                        l_value   := i.attribute40;
                    ELSIF id.application_column_name = 'ATTRIBUTE41'
                    THEN
                        l_value   := i.attribute41;
                    ELSIF id.application_column_name = 'ATTRIBUTE42'
                    THEN
                        l_value   := i.attribute42;
                    ELSIF id.application_column_name = 'ATTRIBUTE43'
                    THEN
                        l_value   := i.attribute43;
                    ELSIF id.application_column_name = 'ATTRIBUTE44'
                    THEN
                        l_value   := i.attribute44;
                    ELSIF id.application_column_name = 'ATTRIBUTE45'
                    THEN
                        l_value   := i.attribute45;
                    ELSIF id.application_column_name = 'ATTRIBUTE46'
                    THEN
                        l_value   := i.attribute46;
                    ELSIF id.application_column_name = 'ATTRIBUTE47'
                    THEN
                        l_value   := i.attribute47;
                    ELSIF id.application_column_name = 'ATTRIBUTE48'
                    THEN
                        l_value   := i.attribute48;
                    ELSIF id.application_column_name = 'ATTRIBUTE49'
                    THEN
                        l_value   := i.attribute49;
                    ELSIF id.application_column_name = 'ATTRIBUTE50'
                    THEN
                        l_value   := i.attribute50;
                    END IF;
                ELSE
                    IF id.application_column_name = 'ATTRIBUTE1'
                    THEN
                        l_value   := i.attribute1_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE2'
                    THEN
                        l_value   := i.attribute2_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE3'
                    THEN
                        l_value   := i.attribute3_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE4'
                    THEN
                        l_value   := i.attribute4_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE5'
                    THEN
                        l_value   := i.attribute5_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE6'
                    THEN
                        l_value   := i.attribute6_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE7'
                    THEN
                        l_value   := i.attribute7_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE8'
                    THEN
                        l_value   := i.attribute8_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE9'
                    THEN
                        l_value   := i.attribute9_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE10'
                    THEN
                        l_value   := i.attribute10_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE11'
                    THEN
                        l_value   := i.attribute11_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE12'
                    THEN
                        l_value   := i.attribute12_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE13'
                    THEN
                        l_value   := i.attribute13_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE14'
                    THEN
                        l_value   := i.attribute14_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE15'
                    THEN
                        l_value   := i.attribute15_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE16'
                    THEN
                        l_value   := i.attribute16_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE17'
                    THEN
                        l_value   := i.attribute17_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE18'
                    THEN
                        l_value   := i.attribute18_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE19'
                    THEN
                        l_value   := i.attribute19_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE20'
                    THEN
                        l_value   := i.attribute20_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE21'
                    THEN
                        l_value   := i.attribute21_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE22'
                    THEN
                        l_value   := i.attribute22_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE23'
                    THEN
                        l_value   := i.attribute23_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE24'
                    THEN
                        l_value   := i.attribute24_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE25'
                    THEN
                        l_value   := i.attribute25_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE26'
                    THEN
                        l_value   := i.attribute26_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE27'
                    THEN
                        l_value   := i.attribute27_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE28'
                    THEN
                        l_value   := i.attribute28_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE29'
                    THEN
                        l_value   := i.attribute29_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE30'
                    THEN
                        l_value   := i.attribute30_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE31'
                    THEN
                        l_value   := i.attribute31_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE32'
                    THEN
                        l_value   := i.attribute32_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE33'
                    THEN
                        l_value   := i.attribute33_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE34'
                    THEN
                        l_value   := i.attribute34_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE35'
                    THEN
                        l_value   := i.attribute35_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE36'
                    THEN
                        l_value   := i.attribute36_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE37'
                    THEN
                        l_value   := i.attribute37_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE38'
                    THEN
                        l_value   := i.attribute38_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE39'
                    THEN
                        l_value   := i.attribute39_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE40'
                    THEN
                        l_value   := i.attribute40_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE41'
                    THEN
                        l_value   := i.attribute41_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE42'
                    THEN
                        l_value   := i.attribute42_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE43'
                    THEN
                        l_value   := i.attribute43_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE44'
                    THEN
                        l_value   := i.attribute44_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE45'
                    THEN
                        l_value   := i.attribute45_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE46'
                    THEN
                        l_value   := i.attribute46_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE47'
                    THEN
                        l_value   := i.attribute47_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE48'
                    THEN
                        l_value   := i.attribute48_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE49'
                    THEN
                        l_value   := i.attribute49_2;
                    ELSIF id.application_column_name = 'ATTRIBUTE50'
                    THEN
                        l_value   := i.attribute50_2;
                    END IF;
                END IF;

                INSERT INTO XXDO.XXD_GL_AAR_VS_BKP_T (request_id, descriptive_flex_context_code, application_column_name, column_seq_num, end_user_column_name, enabled_flag, actual_value, vs_line_identifier, created_by
                                                      , creation_date)
                     VALUES (l_request_id, id.descriptive_flex_context_code, id.application_column_name, id.column_seq_num, id.end_user_column_name, id.enabled_flag, l_value, i.unique_identifier, fnd_global.user_id
                             , SYSDATE);

                COMMIT;
            END LOOP;

            get_segment_child_values (i.account, i.account_hierchy, 'DO_GL_ACCOUNT'
                                      , account_type_tbl);


            get_segment_child_values (i.brand, i.brand_hierchy, 'DO_GL_BRAND'
                                      , brand_type_tbl);

            get_segment_child_values (i.company, i.company_hierchy, 'DO_GL_COMPANY'
                                      , company_type_tbl);

            get_segment_child_values (i.geo, i.geo_hierchy, 'DO_GL_GEO',
                                      Geo_type_tbl);

            get_segment_child_values (i.channel, i.channel_hierchy, 'DO_GL_CHANNEL'
                                      , channel_type_tbl);

            get_segment_child_values (i.costcenter, i.costcenter_hierchy, 'DO_GL_COST_CENTER'
                                      , cc_type_tbl);

            get_segment_child_values (i.intercompany, i.intercompany_hierchy, 'DO_GL_COMPANY'
                                      , ic_type_tbl);


            SELECT *
              BULK COLLECT INTO v_code_combination_type
              FROM gl_code_combinations_kfv gcxck
             WHERE     1 = 1
                   /*    and is_parent(gcxck.SEGMENT1) ='C'
                        and is_parent(gcxck.SEGMENT2) ='C'
                         and is_parent(gcxck.SEGMENT3) ='C'
                          and is_parent(gcxck.SEGMENT4) ='C'
                           and is_parent(gcxck.SEGMENT5) ='C'
                            and is_parent(gcxck.SEGMENT6) ='C'
                             and is_parent(gcxck.SEGMENT7) ='C'*/
                   AND gcxck.SEGMENT6 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT6)
                              FROM TABLE (account_type_tbl)
                             WHERE 1 = 1)
                   AND gcxck.SEGMENT1 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT1)
                              FROM TABLE (company_type_tbl)
                             WHERE 1 = 1)
                   AND gcxck.SEGMENT2 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT2)
                              FROM TABLE (brand_type_tbl)
                             WHERE 1 = 1)
                   AND gcxck.SEGMENT3 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT3)
                              FROM TABLE (geo_type_tbl)
                             WHERE 1 = 1)
                   AND gcxck.SEGMENT4 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT4)
                              FROM TABLE (channel_type_tbl)
                             WHERE 1 = 1)
                   AND gcxck.SEGMENT5 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT5)
                              FROM TABLE (cc_type_tbl)
                             WHERE 1 = 1)
                   AND gcxck.SEGMENT7 IN
                           (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT7)
                              FROM TABLE (ic_type_tbl)
                             WHERE 1 = 1);


            -- storing the hierarchy and later filtering due to performance issue. if we try to exclude parent in the master query above, hitting performance issue

            fnd_file.put_line (
                fnd_file.LOG,
                'total records' || v_code_combination_type.COUNT);

            IF (v_code_combination_type.COUNT > 0)
            THEN
                FORALL j
                    IN v_code_combination_type.FIRST ..
                       v_code_combination_type.LAST
                    MERGE INTO xxdo.xxd_gl_acc_recon_extract_t a
                         USING (SELECT v_code_combination_type (j).code_combination_id code_combination_id
                                  FROM DUAL) b
                            ON (a.ccid = b.code_combination_id)
                    WHEN NOT MATCHED
                    THEN
                        INSERT     (request_id,
                                    ccid,
                                    coaid,
                                    vs_unique_identifier,
                                    company_hierchy,
                                    brand_hierchy,
                                    geo_hierchy,
                                    channel_hierchy,
                                    costcenter_hierchy,
                                    account_hierchy,
                                    intercompany_hierchy,
                                    extract_level,
                                    record_source,
                                    created_by,
                                    creation_date)
                            VALUES (l_request_id, v_code_combination_type (j).code_combination_id, v_code_combination_type (j).chart_of_accounts_id, i.unique_identifier, is_parent (v_code_combination_type (j).SEGMENT1, 'DO_GL_COMPANY'), is_parent (v_code_combination_type (j).SEGMENT2, 'DO_GL_BRAND'), is_parent (v_code_combination_type (j).SEGMENT3, 'DO_GL_GEO'), is_parent (v_code_combination_type (j).SEGMENT4, 'DO_GL_CHANNEL'), is_parent (v_code_combination_type (j).SEGMENT5, 'DO_GL_COST_CENTER'), is_parent (v_code_combination_type (j).SEGMENT6, 'DO_GL_ACCOUNT'), is_parent (v_code_combination_type (j).SEGMENT7, 'DO_GL_COMPANY'), 2
                                    , 'VS', fnd_global.user_id, SYSDATE);

                l_flag   := 'Y';
            END IF;

            l_full_load   := 'Y';
        END LOOP;

        COMMIT;

        OPEN c_get_ccid_notfromvs ();

        FETCH c_get_ccid_notfromvs
            BULK COLLECT INTO v_code_combination_direct;

        CLOSE c_get_ccid_notfromvs;

        IF (v_code_combination_direct.COUNT > 0)
        THEN
            FOR i IN v_code_combination_direct.FIRST ..
                     v_code_combination_direct.LAST
            LOOP
                l_line_identifier   := NULL;

                -- if case of full load as Y, insert all the remaining ccid as null unique_identifier; no need to run thru the valueset and try to find out unique indetifier
                -- if full load as N means, its not a truncate of the table, so we are good to run over the vs and try to find vs uinque identifier
                IF l_full_load = 'N'
                THEN
                    FOR j
                        IN c_get_DI_vs_indentifier (
                               v_code_combination_direct (i).account)
                    LOOP
                        account_type_tbl.delete;
                        brand_type_tbl.delete;
                        company_type_tbl.delete;
                        Geo_type_tbl.delete;
                        channel_type_tbl.delete;
                        cc_type_tbl.delete;
                        ic_type_tbl.delete;

                        get_segment_child_values (j.account, j.account_hierchy, 'DO_GL_ACCOUNT'
                                                  , account_type_tbl);


                        get_segment_child_values (j.brand, j.brand_hierchy, 'DO_GL_BRAND'
                                                  , brand_type_tbl);

                        get_segment_child_values (j.company, j.company_hierchy, 'DO_GL_COMPANY'
                                                  , company_type_tbl);

                        get_segment_child_values (j.geo, j.geo_hierchy, 'DO_GL_GEO'
                                                  , Geo_type_tbl);

                        get_segment_child_values (j.channel, j.channel_hierchy, 'DO_GL_CHANNEL'
                                                  , channel_type_tbl);

                        get_segment_child_values (j.costcenter, j.costcenter_hierchy, 'DO_GL_COST_CENTER'
                                                  , cc_type_tbl);

                        get_segment_child_values (j.intercompany, j.intercompany_hierchy, 'DO_GL_COMPANY'
                                                  , ic_type_tbl);

                        SELECT COUNT (*)
                          INTO l_count_di
                          FROM gl_code_combinations_kfv gcxck
                         WHERE     1 = 1
                               AND gcxck.SEGMENT6 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT6)
                                          FROM TABLE (account_type_tbl)
                                         WHERE 1 = 1)
                               AND gcxck.SEGMENT1 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT1)
                                          FROM TABLE (company_type_tbl)
                                         WHERE 1 = 1)
                               AND gcxck.SEGMENT2 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT2)
                                          FROM TABLE (brand_type_tbl)
                                         WHERE 1 = 1)
                               AND gcxck.SEGMENT3 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT3)
                                          FROM TABLE (geo_type_tbl)
                                         WHERE 1 = 1)
                               AND gcxck.SEGMENT4 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT4)
                                          FROM TABLE (channel_type_tbl)
                                         WHERE 1 = 1)
                               AND gcxck.SEGMENT5 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT5)
                                          FROM TABLE (cc_type_tbl)
                                         WHERE 1 = 1)
                               AND gcxck.SEGMENT7 IN
                                       (SELECT NVL (TO_NUMBER (segment_val), gcxck.SEGMENT7)
                                          FROM TABLE (ic_type_tbl)
                                         WHERE 1 = 1)
                               AND code_combination_id =
                                   v_code_combination_direct (i).code_combination_id;

                        --- highest rank is on the top; so as soon as we found l_count_di as 1; break the loop
                        IF (l_count_di = 1)
                        THEN
                            l_line_identifier   := j.unique_identifier;
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;

                -- now extract all the ccid and see if this ccid is being matched with any of the ccid being extracted

                /*
                            BEGIN
                               SELECT vs_unique_identifier
                                 INTO l_line_identifier
                                 FROM (  SELECT a.*,
                                                ROW_NUMBER ()
                                                   OVER (ORDER BY
                                                            A.ACCOUNT_WEIGHT DESC,
                                                            A.CHANNEL_WEIGHT DESC,
                                                            A.COMPANY_WEIGHT DESC,
                                                            A.BRAND_WEIGHT DESC,
                                                            A.GEO_WEIGHT DESC,
                                                            A.CC_WEIGHT DESC,
                                                            a.ic_weight DESC)
                                                   seq_num
                                           FROM (WITH std_ccid
                                                      AS (              -- ccid being inserted
                                                          SELECT b.segment6,
                                                                 b.segment4,
                                                                 b.segment1,
                                                                 b.segment2,
                                                                 b.segment3,
                                                                 b.segment5,
                                                                 b.segment7
                                                            FROM gl_code_combinations_kfv b
                                                           WHERE code_combination_id =
                                                                    v_code_combination_direct (
                                                                       i).code_combination_id)
                                                 SELECT -- mapping ccid being inserted as closely as possible(using weightage) with the ccid already extracted from the VS
                                                       CONCATENATED_SEGMENTS,
                                                        b.segment6,
                                                        b.segment4,
                                                        b.segment1,
                                                        b.segment2,
                                                        b.segment3,
                                                        b.segment5,
                                                        b.segment7,
                                                        vs_unique_identifier,
                                                        CASE
                                                           WHEN std_ccid.segment6 = b.segment6
                                                           THEN
                                                              35
                                                           ELSE
                                                              0
                                                        END
                                                           account_weight,
                                                        CASE
                                                           WHEN std_ccid.segment4 = b.segment4
                                                           THEN
                                                              30
                                                           ELSE
                                                              0
                                                        END
                                                           channel_weight,
                                                        CASE
                                                           WHEN std_ccid.segment1 = b.segment1
                                                           THEN
                                                              25
                                                           ELSE
                                                              0
                                                        END
                                                           company_weight,
                                                        CASE
                                                           WHEN std_ccid.segment2 = b.segment2
                                                           THEN
                                                              20
                                                           ELSE
                                                              0
                                                        END
                                                           brand_weight,
                                                        CASE
                                                           WHEN std_ccid.segment3 = b.segment3
                                                           THEN
                                                              15
                                                           ELSE
                                                              0
                                                        END
                                                           geo_weight,
                                                        CASE
                                                           WHEN std_ccid.segment5 = b.segment5
                                                           THEN
                                                              10
                                                           ELSE
                                                              0
                                                        END
                                                           cc_weight,
                                                        CASE
                                                           WHEN std_ccid.segment7 = b.segment7
                                                           THEN
                                                              5
                                                           ELSE
                                                              0
                                                        END
                                                           ic_weight
                                                   FROM xxdo.xxd_gl_acc_recon_extract_t a,
                                                        gl_code_combinations_kfv b,
                                                        std_ccid
                                                  WHERE     a.ccid = b.code_combination_id
                                                        AND std_ccid.segment6 = b.segment6
                                                        AND extract_level = 2
                                                        AND record_source = 'VS') a
                                       ORDER BY ACCOUNT_WEIGHT DESC,
                                                CHANNEL_WEIGHT DESC,
                                                COMPANY_WEIGHT DESC,
                                                BRAND_WEIGHT DESC,
                                                GEO_WEIGHT DESC,
                                                CC_WEIGHT DESC,
                                                IC_WEIGHT DESC)
                                WHERE seq_num = 1;
                            EXCEPTION
                               WHEN OTHERS
                               THEN
                                  NULL;
                            END;
                */
                MERGE INTO xxdo.xxd_gl_acc_recon_extract_t a
                     USING (SELECT v_code_combination_direct (i).code_combination_id code_combination_id
                              FROM DUAL) b
                        ON (a.ccid = b.code_combination_id)
                WHEN NOT MATCHED
                THEN
                    INSERT     (request_id, ccid, coaid,
                                vs_unique_identifier, extract_level, record_source
                                , created_by, creation_date)
                        VALUES (l_request_id, v_code_combination_direct (i).code_combination_id, v_code_combination_direct (i).chart_of_accounts_id, l_line_identifier, 2, 'DI'
                                , fnd_global.user_id, SYSDATE);
            END LOOP;
        END IF;


        -- extra logic
        --  now check if there are CCID in standard table of acocunt type A, O, L  but not in our custom table; insert all those

        --F l_flag = 'Y'
        -- THEN
        lb_return          :=
            fnd_profile.SAVE ('XXD_GL_ACC_EXTRACT_TIME',
                              l_prg_start_date,
                              'SITE');

        --END IF;

        -- now here remove all records having any of the segment as parent
        DELETE FROM
            xxdo.xxd_gl_acc_recon_extract_t
              WHERE     1 = 1
                    AND (company_hierchy = 'P' OR brand_hierchy = 'P' OR geo_hierchy = 'P' OR channel_hierchy = 'P' OR costcenter_hierchy = 'P' OR account_hierchy = 'P' OR intercompany_hierchy = 'P')
                    AND EXTRACT_LEVEL = 2
                    AND request_id = l_request_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('error is' || SQLERRM);
    END main_control;

    PROCEDURE get_segment_child_values (
        p_value                    IN     VARCHAR2,
        p_hierchy                  IN     VARCHAR2,
        p_type                     IN     VARCHAR2, -- this is the gl segment value set name
        p_gl_item_recon_tbl_type      OUT xxdo.xxd_gl_item_recon_tbl_type)
    AS
        TYPE account_type IS TABLE OF VARCHAR2 (200);

        v_account_typ   account_type := account_type ();
    BEGIN
        p_gl_item_recon_tbl_type   := xxdo.xxd_gl_item_recon_tbl_type ();

        IF (p_value IS NOT NULL AND p_hierchy = 'P')
        THEN
            /* SELECT ffvc.flex_value
               BULK COLLECT INTO v_account_typ
               FROM fnd_flex_value_sets ffvs,
                    fnd_flex_values ffv,
                    fnd_flex_values_tl ffvt,r
                    fnd_flex_value_children_v ffvc
              WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                    AND ffv.flex_value_id = ffvt.flex_value_id
                    AND ffvt.language = USERENV ('LANG')
                    AND flex_value_set_name = p_type
                    AND ffvc.SUMMARY_FLAG = 'N'
                    AND ffvc.flex_value_set_id = ffv.flex_value_set_id
                    AND ffvc.flex_value = ffv.flex_value
                    AND ffvc.parent_flex_value = p_value;
                    */

            SELECT flex_value
              BULK COLLECT INTO v_account_typ
              FROM (SELECT ffvc.flex_value
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt,
                           fnd_flex_value_children_v ffvc
                     WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffv.flex_value_id = ffvt.flex_value_id
                           AND ffvt.language = USERENV ('LANG')
                           AND flex_value_set_name = p_type
                           AND ffvc.SUMMARY_FLAG = 'N'
                           AND ffvc.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvc.flex_value = ffv.flex_value
                           AND ffvc.parent_flex_value = p_value
                    UNION
                    SELECT ffvc.flex_value
                      -- BULK COLLECT INTO v_account_typ
                      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt,
                           fnd_flex_value_children_v ffvc
                     WHERE     ffvs.flex_value_set_id = ffv.flex_value_set_id
                           AND ffv.flex_value_id = ffvt.flex_value_id
                           AND ffvt.language = USERENV ('LANG')
                           AND flex_value_set_name = p_type
                           AND flex_value_set_name = 'DO_GL_CHANNEL'
                           AND ffvc.SUMMARY_FLAG = 'N'
                           AND ffvc.flex_value_set_id = ffv.flex_value_set_id
                           AND ffvc.flex_value = ffv.flex_value
                           AND ffvc.parent_flex_value IN
                                   (SELECT ffvc.flex_value
                                      -- BULK COLLECT INTO v_account_typ
                                      FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, fnd_flex_values_tl ffvt,
                                           fnd_flex_value_children_v ffvc
                                     WHERE     ffvs.flex_value_set_id =
                                               ffv.flex_value_set_id
                                           AND ffv.flex_value_id =
                                               ffvt.flex_value_id
                                           AND ffvt.language =
                                               USERENV ('LANG')
                                           AND flex_value_set_name =
                                               'DO_GL_CHANNEL'
                                           AND flex_value_set_name = p_type
                                           AND ffvc.SUMMARY_FLAG = 'Y'
                                           AND ffvc.flex_value_set_id =
                                               ffv.flex_value_set_id
                                           AND ffvc.flex_value =
                                               ffv.flex_value
                                           AND ffvc.parent_flex_value =
                                               p_value));


            IF (v_account_typ.COUNT > 0)
            THEN
                FOR i IN v_account_typ.FIRST .. v_account_typ.LAST
                LOOP
                    p_gl_item_recon_tbl_type.EXTEND;
                    p_gl_item_recon_tbl_type (p_gl_item_recon_tbl_type.LAST)   :=
                        xxdo.xxd_gl_item_recon_rec_type (v_account_typ (i));
                END LOOP;
            ELSE
                p_gl_item_recon_tbl_type.EXTEND;
                p_gl_item_recon_tbl_type (p_gl_item_recon_tbl_type.LAST)   :=
                    xxdo.xxd_gl_item_recon_rec_type (p_value);
            END IF;
        ELSE
            p_gl_item_recon_tbl_type.EXTEND;
            p_gl_item_recon_tbl_type (p_gl_item_recon_tbl_type.LAST)   :=
                xxdo.xxd_gl_item_recon_rec_type (p_value);
        END IF;
    END get_segment_child_values;

    PROCEDURE get_ccid_values (p_in_ccid IN NUMBER, p_in_company IN NUMBER, p_in_alt_currency IN VARCHAR2, p_in_period IN VARCHAR2, p_end_date IN VARCHAR2, p_stat_ledger_flag IN VARCHAR2, p_end_bal_flag IN VARCHAR2, p_out_activty_in_prd OUT VARCHAR2, p_out_sec_activty_in_prd OUT VARCHAR2, p_out_active_acct OUT VARCHAR2, p_out_pri_gl_rpt_bal OUT NUMBER, p_out_pri_gl_alt_bal OUT NUMBER, p_out_pri_gl_acct_bal OUT NUMBER, p_out_sec_gl_rpt_bal OUT NUMBER, p_out_sec_gl_alt_bal OUT NUMBER, p_out_sec_gl_acct_bal OUT NUMBER, p_out_alt_currency OUT VARCHAR2, p_out_primary_currency OUT VARCHAR2, p_out_sec_currency OUT VARCHAR2, p_out_secondary_ledger OUT VARCHAR2, p_out_sgl_acct_bal OUT NUMBER
                               , p_sec_curr_code OUT VARCHAR2)
    IS
        l_secondary_ledger        NUMBER;
        l_bl_alt_curr_flag        VARCHAR2 (10);
        l_pri_ledger_id           NUMBER;
        l_pri_gl_acct_bal_begin   NUMBER;
        l_sec_gl_acct_bal_begin   NUMBER;
        l_activity                NUMBER;
        l_sec_activity            NUMBER;
        l_sec_ledger_id           NUMBER;
        l_period_name             VARCHAR2 (100);
        l_start_date              VARCHAR2 (100);
        l_quarter_start_date      VARCHAR2 (100);
        l_year_start_date         VARCHAR2 (100);
        ln_valid_sec_cnt          NUMBER;
        ln_valid_pri_cnt          NUMBER;
    --l_sec_curr_code           VARCHAR2(100);
    BEGIN
        p_out_active_acct          := NULL;
        p_out_activty_in_prd       := NULL;
        p_out_pri_gl_rpt_bal       := NULL;
        p_out_pri_gl_alt_bal       := NULL;
        p_out_pri_gl_acct_bal      := NULL;
        p_out_sec_gl_rpt_bal       := NULL;
        p_out_sec_gl_alt_bal       := NULL;
        p_out_sec_gl_acct_bal      := NULL;
        p_out_alt_currency         := NULL;
        p_out_primary_currency     := NULL;
        p_out_secondary_ledger     := NULL;
        l_pri_gl_acct_bal_begin    := NULL;
        l_sec_gl_acct_bal_begin    := NULL;
        l_activity                 := NULL;
        l_sec_activity             := NULL;
        l_pri_ledger_id            := NULL;
        l_sec_ledger_id            := NULL;
        l_secondary_ledger         := NULL;
        l_bl_alt_curr_flag         := NULL;
        p_out_sec_currency         := NULL;
        p_out_sgl_acct_bal         := NULL;
        p_out_sec_activty_in_prd   := NULL;
        l_period_name              := NULL;
        l_start_date               := NULL;
        l_quarter_start_date       := NULL;
        l_year_start_date          := NULL;
        p_sec_curr_code            := NULL;
        ln_valid_sec_cnt           := NULL;
        ln_valid_pri_cnt           := NULL;


        -- Get the Secondary period based on Primary Period

        get_secondary_period (p_period_name          => p_in_period,
                              x_period_name          => l_period_name,
                              x_start_date           => l_start_date,
                              x_quarter_start_date   => l_quarter_start_date,
                              x_year_start_date      => l_year_start_date);

        -- PICK THE SECONDARY LEDGER/ atl currency flag From THE COMPANY DFF

        BEGIN
            SELECT DECODE (b.attribute1, 'Y', c.currency_code, NULL), TO_NUMBER (b.attribute8), b.attribute1,
                   c.currency_code
              INTO p_out_alt_currency, l_secondary_ledger, l_bl_alt_curr_flag, p_sec_curr_code
              FROM fnd_flex_value_sets a, fnd_flex_values b, gl_ledgers c
             WHERE     a.flex_value_set_name = 'DO_GL_COMPANY'
                   AND a.flex_value_set_id = b.flex_value_set_id
                   AND b.attribute8 = ledger_id
                   AND flex_value = TO_CHAR (p_in_company);
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- Secondary ledger name to insert into custom table when statuary_ledger = 'Y'
        BEGIN
            SELECT name
              INTO p_out_secondary_ledger
              FROM gl_ledgers
             WHERE ledger_id = l_secondary_ledger;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_secondary_ledger   := NULL;
        END;

        -- Check if the CCID and Combination already exists for that period

        --       IF  UPPER (NVL(p_stat_ledger_flag,'N')) = 'N' OR UPPER (NVL(p_stat_ledger_flag,'N')) = 'NO'
        --       THEN
        ln_valid_pri_cnt           :=
            get_record_exists (p_in_ccid, p_end_date, NULL);

        --       END IF;

        IF ln_valid_pri_cnt IS NOT NULL AND ln_valid_pri_cnt = 0
        THEN
            --       PIRMARY BALANCE
            BEGIN
                SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)),
                       (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0)))
                           end_bal,
                       b.currency_code,
                       B.ledger_id,
                       (  SELECT COUNT (DISTINCT gll.ledger_id)
                            FROM gl_ledgers gll, gl_je_lines gjl
                           WHERE     gll.ledger_id <> 2081
                                 AND gjl.code_combination_id = p_in_ccid
                                 AND gjl.ledger_id = gll.ledger_id
                                 AND gjl.period_name = p_in_period
                                 AND b.ledger_id = gll.ledger_id
                                 AND gll.ledger_category_code = 'PRIMARY'
                                 AND gjl.status = 'P'
                                 AND NOT EXISTS
                                         (SELECT 1
                                            FROM apps.gl_je_headers gjh
                                           WHERE     gjh.je_header_id =
                                                     gjl.je_header_id
                                                 AND gjh.je_category =
                                                     'Revaluation'
                                                 AND je_source = 'Revaluation')
                        GROUP BY gll.ledger_id)
                           cnt
                  INTO l_pri_gl_acct_bal_begin, p_out_pri_gl_acct_bal, p_out_primary_currency, l_pri_ledger_id,
                                              l_activity
                  FROM gl_balances gb, gl_ledgers b
                 WHERE     period_name = p_in_period
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.ledger_id <> 2081
                       AND b.currency_code = gb.currency_code
                       AND ledger_category_code = 'PRIMARY';
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        ELSIF ln_valid_pri_cnt IS NOT NULL AND ln_valid_pri_cnt > 0
        THEN
            BEGIN
                SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)), (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal, b.currency_code,
                       B.ledger_id
                  INTO l_pri_gl_acct_bal_begin, p_out_pri_gl_acct_bal, p_out_primary_currency, l_pri_ledger_id
                  FROM gl_balances gb, gl_ledgers b
                 WHERE     period_name = p_in_period
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.ledger_id <> 2081
                       AND b.currency_code = gb.currency_code
                       AND ledger_category_code = 'PRIMARY';
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        -- Secondary Balances

        IF    UPPER (p_stat_ledger_flag) = 'Y'
           OR UPPER (p_stat_ledger_flag) = 'YES'
        THEN
            ln_valid_sec_cnt   :=
                get_record_exists (p_in_ccid, p_end_date, p_stat_ledger_flag);

            IF ln_valid_sec_cnt IS NOT NULL AND ln_valid_sec_cnt = 0
            THEN
                BEGIN
                    SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)),
                           (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0)))
                               end_bal,
                           b.currency_code,
                           B.ledger_id,
                           (  SELECT COUNT (DISTINCT gll.ledger_id)
                                FROM gl_ledgers gll, gl_je_lines gjl
                               WHERE     gll.ledger_id <> 2081
                                     AND gjl.code_combination_id = p_in_ccid
                                     AND gjl.ledger_id = gll.ledger_id
                                     AND gjl.period_name =
                                         DECODE (
                                             gll.period_set_name,
                                             'DO_CY_CALENDAR', l_period_name,
                                             p_in_period)
                                     AND b.ledger_id = gll.ledger_id
                                     AND gll.ledger_category_code = 'SECONDARY'
                                     AND gjl.status = 'P'
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM apps.gl_je_headers gjh
                                               WHERE     gjh.je_header_id =
                                                         gjl.je_header_id
                                                     AND gjh.je_category =
                                                         'Revaluation'
                                                     AND je_source =
                                                         'Revaluation')
                            GROUP BY gll.ledger_id)
                               cnt
                      INTO l_sec_gl_acct_bal_begin, p_out_sgl_acct_bal, p_out_primary_currency, l_sec_ledger_id,
                                                  l_sec_activity
                      FROM gl_balances gb, gl_ledgers b
                     WHERE     period_name =
                               DECODE (b.period_set_name,
                                       'DO_CY_CALENDAR', l_period_name,
                                       p_in_period)
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.ledger_id <> 2081
                           AND b.currency_code = gb.currency_code
                           AND ledger_category_code = 'SECONDARY';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            ELSIF ln_valid_sec_cnt IS NOT NULL AND ln_valid_sec_cnt > 0
            THEN
                BEGIN
                    SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)), (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal, b.currency_code,
                           B.ledger_id
                      INTO l_sec_gl_acct_bal_begin, p_out_sgl_acct_bal, p_out_primary_currency, l_sec_ledger_id
                      FROM gl_balances gb, gl_ledgers b
                     WHERE     period_name =
                               DECODE (b.period_set_name,
                                       'DO_CY_CALENDAR', l_period_name,
                                       p_in_period)
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.ledger_id <> 2081
                           AND b.currency_code = gb.currency_code
                           AND ledger_category_code = 'SECONDARY';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        END IF;


        -- if Y company dff lvel, take the ledger id associated as secondary ledger in the balancing segment and check the currency of gl_ledgers,
        --          then get the accounted amount of that currency


        IF p_in_alt_currency IS NULL
        THEN
            IF l_bl_alt_curr_flag = 'Y'
            THEN
                BEGIN
                    SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal
                      INTO p_out_pri_gl_alt_bal
                      FROM gl_balances gb, GL_LEDGERS b
                     WHERE     period_name =
                               DECODE (b.period_set_name,
                                       'DO_CY_CALENDAR', l_period_name,
                                       p_in_period)
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.LEDGER_ID <> 2081
                           AND b.LEDGER_ID = l_secondary_ledger
                           AND gb.currency_code =
                               (SELECT currency_code
                                  FROM GL_LEDGERS
                                 WHERE ledger_id = l_secondary_ledger);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        ELSE -- p_in_alt_currency is not null i.e vs has the alternate currency entered
            BEGIN
                SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal
                  INTO p_out_pri_gl_alt_bal
                  FROM gl_balances gb, GL_LEDGERS b
                 WHERE     period_name = p_in_period
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.LEDGER_ID <> 2081
                       AND LEDGER_CATEGORY_CODE = 'PRIMARY'
                       AND gb.currency_code = UPPER (p_in_alt_currency);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        -- REPORTING LEDGER
        BEGIN
            SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal
              INTO p_out_pri_gl_rpt_bal
              FROM gl_balances gb, GL_LEDGERS b
             WHERE     period_name = p_in_period
                   AND gb.code_combination_id = p_in_ccid
                   AND gb.ledger_id = b.ledger_id
                   AND b.LEDGER_ID <> 2081
                   AND b.CURRENCY_cODE = GB.CURRENCY_cODE
                   AND LEDGER_CATEGORY_CODE = 'ALC';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- SECONDARY LEDGER
        BEGIN
            SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal
              INTO p_out_sec_gl_acct_bal
              FROM gl_balances gb, GL_LEDGERS b
             WHERE     period_name =
                       DECODE (b.period_set_name,
                               'DO_CY_CALENDAR', l_period_name,
                               p_in_period)
                   AND gb.code_combination_id = p_in_ccid
                   AND gb.ledger_id = b.ledger_id
                   AND b.LEDGER_ID <> 2081
                   AND b.ledger_id = l_secondary_ledger
                   AND b.CURRENCY_cODE = GB.CURRENCY_cODE
                   AND ledger_category_code = 'SECONDARY';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        BEGIN
            BEGIN
                SELECT DECODE (enabled_flag, 'Y', 'TRUE', 'FALSE')
                  INTO p_out_active_acct
                  FROM gl_code_combinations
                 WHERE code_combination_id = p_in_ccid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_active_acct   := 'FALSE';
            END;


            IF ln_valid_pri_cnt > 0
            THEN
                p_out_activty_in_prd   := 'TRUE';
            ELSE
                IF p_out_active_acct = 'TRUE'
                THEN                             -- AND HAS ACTIVITY IN PERIOD
                    IF p_end_bal_flag = 'Y' AND p_out_pri_gl_acct_bal <> 0
                    THEN
                        p_out_activty_in_prd   := 'TRUE';
                    ELSIF l_pri_gl_acct_bal_begin <> 0
                    THEN
                        p_out_activty_in_prd   := 'TRUE';
                    ELSIF l_activity > 0    -- p_pri_gl_acct_bal_begin = 0 AND
                    THEN
                        p_out_activty_in_prd   := 'TRUE';
                    ELSIF     l_pri_gl_acct_bal_begin = 0
                          AND p_out_pri_gl_acct_bal <> 0
                          AND l_activity = 0       --AND p_closing_bal = 'YES'
                    THEN
                        p_out_activty_in_prd   := 'TRUE';
                    ELSE
                        p_out_activty_in_prd   := 'FALSE';
                    END IF;
                ELSIF p_out_active_acct = 'FALSE'
                THEN
                    IF    l_pri_gl_acct_bal_begin <> 0
                       OR p_out_pri_gl_acct_bal <> 0
                    THEN
                        p_out_activty_in_prd   := 'TRUE';
                    ELSE
                        p_out_activty_in_prd   := 'FALSE';
                    END IF;
                END IF;
            END IF;


            IF    UPPER (p_stat_ledger_flag) = 'Y'
               OR UPPER (p_stat_ledger_flag) = 'YES'
            THEN
                IF ln_valid_sec_cnt > 0
                THEN
                    p_out_sec_activty_in_prd   := 'TRUE';
                ELSE
                    IF p_out_active_acct = 'TRUE'
                    THEN                         -- AND HAS ACTIVITY IN PERIOD
                        IF p_end_bal_flag = 'Y' AND p_out_sgl_acct_bal <> 0
                        THEN
                            p_out_activty_in_prd   := 'TRUE';
                        ELSIF l_sec_gl_acct_bal_begin <> 0
                        THEN
                            p_out_sec_activty_in_prd   := 'TRUE';
                        ELSIF l_sec_activity > 0 -- p_pri_gl_acct_bal_begin = 0 AND
                        THEN
                            p_out_sec_activty_in_prd   := 'TRUE';
                        ELSIF     l_sec_gl_acct_bal_begin = 0
                              AND p_out_sgl_acct_bal <> 0
                              AND l_sec_activity = 0 --AND p_closing_bal = 'YES'
                        THEN
                            p_out_sec_activty_in_prd   := 'TRUE';
                        ELSE
                            p_out_sec_activty_in_prd   := 'FALSE';
                        END IF;
                    ELSIF p_out_active_acct = 'FALSE'
                    THEN
                        IF    l_sec_gl_acct_bal_begin <> 0
                           OR p_out_sgl_acct_bal <> 0
                        THEN
                            p_out_sec_activty_in_prd   := 'TRUE';
                        ELSE
                            p_out_sec_activty_in_prd   := 'FALSE';
                        END IF;
                    END IF;
                END IF;
            END IF;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_ccid_values;

    -- This procedure is for account balances extract to BL

    PROCEDURE account_balance (p_errbuf OUT VARCHAR2, p_retcode OUT VARCHAR2, p_current_period IN VARCHAR2
                               , p_previous_period IN VARCHAR2, p_file_path IN VARCHAR2, p_closing_bal IN VARCHAR2)
    IS
        CURSOR c_get_account IS
            (SELECT EXTRACTED_CCID.ccid,
                    gcc.segment1
                        AS entity_unique_identifier,                -- compnay
                    gcc.segment2
                        brand,
                    gcc.segment3
                        geo,
                    gcc.segment4
                        channel,
                    gcc.segment5
                        cost_center,
                    gcc.segment6
                        account,
                    gcc.segment7
                        intercompany,
                    STATUARY_LEDGER,
                    future,
                    key3,
                    key4,
                    key5,
                    key6,
                    key7,
                    key8,
                    key9,
                    key10,
                    NVL (
                        account_desc,
                        gl_flexfields_pkg.get_description_sql (coaid, --- chart of account id
                                                               6, ----- Position of segment
                                                               account ---- Segment value
                                                                      ))
                        account_description,
                    NVL (ACCOUNT_REFERENCE,
                         gl_flexfields_pkg.get_description_sql (
                             coaid,                    --- chart of account id
                             6,                      ----- Position of segment
                             (SELECT MAX (parent_flex_value)
                                FROM fnd_flex_value_children_v
                               WHERE flex_value = account)  ---- Segment value
                                                          ))
                        account_refernce,
                    acitve_account,
                    NVL (
                        FINANCIAL_STATEMENT,
                        DECODE (gcc.account_type,
                                'A', 'A',
                                'O', 'A',
                                'L', 'A',
                                'I'))
                        financal_stmt,
                    NVL (
                        XXD_GL_BL_ACCT_BAL_VS_ATTRS_V.account_type,
                        DECODE (gcc.account_type,
                                'R', 'Revenue',
                                'A', 'Asset',
                                'O', 'Equity',
                                'E', 'Expense',
                                'L', 'Liability'))
                        account_type,
                    (SELECT MAX (parent_flex_value)
                       FROM fnd_flex_value_children_v
                      WHERE flex_value = account)
                        compnany_immdiate_parent,
                    alt_currency,
                    activity_in_period,
                    ACCOUNT_CURRENCY,
                    ACCOUNT_REFERENCE_2,
                    ACCOUNT_REFERENCE_3,
                    ACCOUNT_REFERENCE_4,
                    NULL
                        ACCOUNT_REFERENCE_5,
                    NULL
                        ACCOUNT_REFERENCE_6,
                    statuary_ledger
                        stat_ledger_flag
               FROM (SELECT VS_UNIQUE_IDENTIFIER, CCID, COAID
                       FROM xxdo.xxd_gl_acc_recon_extract_t
                      WHERE     EXTRACT_LEVEL = 2
                            AND vs_unique_identifier IS NOT NULL)
                    EXTRACTED_CCID,
                    (SELECT * FROM XXD_GL_BL_ACCT_BAL_VS_ATTRS_V)
                    XXD_GL_BL_ACCT_BAL_VS_ATTRS_V,
                    gl_code_combinations gcc
              WHERE     1 = 1
                    AND XXD_GL_BL_ACCT_BAL_VS_ATTRS_V.VS_LINE_IDENTIFIER =
                        EXTRACTED_CCID.VS_UNIQUE_IDENTIFIER
                    AND gcc.code_combination_id = EXTRACTED_CCID.ccid);

        CURSOR get_period IS
            (SELECT period_name, TO_CHAR (end_date, 'MM/DD/YYYY') end_date
               FROM gl_periods
              WHERE     period_set_name = 'DO_FY_CALENDAR'
                    AND TRUNC (SYSDATE) BETWEEN start_date AND end_date -- urrent month
                    AND 'Y' = p_current_period
             --AND period_name = 'DEC-21'
             UNION
             SELECT period_name, TO_CHAR (end_date, 'MM/DD/YYYY')
               FROM gl_periods
              WHERE     period_set_name = 'DO_FY_CALENDAR'
                    AND TRUNC (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -1)) BETWEEN start_date
                                                                           AND end_date -- previous month
                    AND 'Y' = p_previous_period);

        p_out_activty_in_prd       VARCHAR2 (240);
        p_out_sec_activty_in_prd   VARCHAR2 (240);
        p_out_begin_balance        NUMBER;
        p_out_closing_balance      NUMBER;
        p_alt_currency             VARCHAR2 (240);
        p_out_primary_currency     VARCHAR2 (240);
        p_out_pri_gl_rpt_bal       NUMBER;
        p_out_pri_gl_alt_bal       NUMBER;
        p_out_pri_gl_acct_bal      NUMBER;
        p_out_sec_gl_rpt_bal       NUMBER;
        p_out_sec_gl_alt_bal       NUMBER;
        p_out_sec_gl_acct_bal      NUMBER;
        p_out_secondary_ledger     VARCHAR2 (240);
        p_out_active_acct          VARCHAR2 (240);
        p_out_alt_currency         VARCHAR2 (100);
        p_out_sec_currency         VARCHAR2 (100);
        p_out_sgl_acct_bal         NUMBER;
        p_sec_curr_code            VARCHAR2 (100);
        l_file_name                VARCHAR2 (240);
        lv_ret_code                VARCHAR2 (30) := NULL;
        lv_ret_message             VARCHAR2 (2000) := NULL;
        l_request_id               NUMBER;
        lb_file_exists             BOOLEAN;
        ln_file_length             NUMBER := NULL;
        ln_block_size              NUMBER := NULL;
        lv_outbound_cur_file       VARCHAR2 (360)
            := 'GLAccounts_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
    BEGIN
        l_request_id   := fnd_global.conc_request_id;

        IF p_file_path IS NOT NULL
        THEN
            l_file_name   := lv_outbound_cur_file || '.txt';
        END IF;

        FOR j IN get_period
        LOOP
            FOR i IN c_get_account
            LOOP
                -- Added New
                p_out_activty_in_prd       := NULL;
                p_out_sec_activty_in_prd   := NULL;
                p_out_active_acct          := NULL;
                p_out_pri_gl_rpt_bal       := NULL;
                p_out_pri_gl_alt_bal       := NULL;
                p_out_pri_gl_acct_bal      := NULL;
                p_out_sec_gl_rpt_bal       := NULL;
                p_out_sec_gl_alt_bal       := NULL;
                p_out_sec_gl_acct_bal      := NULL;
                p_out_alt_currency         := NULL;
                p_out_primary_currency     := NULL;
                p_out_secondary_ledger     := NULL;
                p_out_sec_currency         := NULL;
                p_out_sgl_acct_bal         := NULL;
                p_sec_curr_code            := NULL;
                -- Added New


                get_ccid_values (i.ccid, i.entity_unique_identifier, i.alt_currency, j.period_name, j.end_date, i.stat_ledger_flag, p_closing_bal, p_out_activty_in_prd, p_out_sec_activty_in_prd, p_out_active_acct, p_out_pri_gl_rpt_bal, p_out_pri_gl_alt_bal, p_out_pri_gl_acct_bal, p_out_sec_gl_rpt_bal, p_out_sec_gl_alt_bal, p_out_sec_gl_acct_bal, p_out_alt_currency, p_out_primary_currency, p_out_sec_currency, p_out_secondary_ledger, p_out_sgl_acct_bal
                                 , p_sec_curr_code);


                --            fnd_file.put_line(fnd_file.log,'CCID is - '||'|'||i.ccid||'|'||'Account is - '||'|'||i.account||'|'||'Cost Center is - '||'|'||i.cost_center||'|'||'p_out_activty_in_prd is - '||'|'||p_out_activty_in_prd
                --                              ||'|'||'p_out_sec_activty_in_prd is - '||'|'||p_out_sec_activty_in_prd);

                IF p_out_activty_in_prd = 'TRUE'       -- p_out_activty_in_prd
                THEN
                    INSERT INTO XXDO.xxd_gl_account_balance_t (
                                    request_id,
                                    code_combination_id,
                                    file_name,
                                    entity_unique_identifier,
                                    account_number,
                                    brand,
                                    geo,
                                    channel,
                                    costcenter,
                                    intercompany,
                                    statuary_ledger,
                                    stat_ledger_flag,
                                    key9,
                                    key10,
                                    account_desc,
                                    account_reference1,
                                    financial_statement,
                                    account_type,
                                    acitve_account,
                                    activity_in_period,
                                    alt_currency,
                                    account_currency,
                                    period_end_date,
                                    gl_reporting_balance,
                                    gl_alt_balance,
                                    gl_account_balance,
                                    account_reference_2,
                                    account_reference_3,
                                    account_reference_4,
                                    account_reference_5,
                                    account_reference_6,
                                    attribute1,
                                    created_by,
                                    creation_date)
                         VALUES (l_request_id, i.ccid, l_file_name,
                                 i.entity_unique_identifier, i.account, i.brand, i.geo, i.channel, i.cost_center, i.intercompany, NULL, NULL, i.key9, i.key10, i.ACCOUNT_DESCRIPTION, i.ACCOUNT_REFERNCE, i.FINANCAL_STMT, i.account_type, NVL (i.acitve_account, p_out_activty_in_prd), NVL (i.acitve_account, p_out_activty_in_prd), --NVL (i.activity_in_period, p_out_activty_in_prd),
                                                                                                                                                                                                                                                                                                                                       NVL (i.alt_currency, NVL (p_out_alt_currency, 'USD')), --alt_currency
                                                                                                                                                                                                                                                                                                                                                                                              NVL (i.account_currency, p_out_primary_currency), --account_currency
                                                                                                                                                                                                                                                                                                                                                                                                                                                j.end_date, --period_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                                                            NVL (p_out_pri_gl_rpt_bal, p_out_pri_gl_acct_bal), --gl_reporting_balance
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               p_out_pri_gl_alt_bal, --gl_alt_balance
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     p_out_pri_gl_acct_bal, -- gl_account_balance
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            i.ACCOUNT_REFERENCE_2, -- account_reference_2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   i.ACCOUNT_REFERENCE_3, --account_reference_3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          i.ACCOUNT_REFERENCE_4, i.ACCOUNT_REFERENCE_5, i.ACCOUNT_REFERENCE_6, 'P', FND_GLOBAL.USER_ID
                                 , SYSDATE);
                END IF;

                IF p_out_sec_activty_in_prd = 'TRUE'
                THEN
                    -- if statuary_ledger is Y then another line for the same CCId to report secondary ledger
                    IF    (UPPER (i.statuary_ledger) = 'Y')
                       OR (UPPER (i.statuary_ledger) = 'YES')
                    THEN
                        INSERT INTO XXDO.xxd_gl_account_balance_t (
                                        request_id,
                                        code_combination_id,
                                        file_name,
                                        entity_unique_identifier,
                                        account_number,
                                        brand,
                                        geo,
                                        channel,
                                        costcenter,
                                        intercompany,
                                        statuary_ledger,
                                        stat_ledger_flag,
                                        key9,
                                        key10,
                                        account_desc,
                                        account_reference1,
                                        financial_statement,
                                        account_type,
                                        acitve_account,
                                        activity_in_period,
                                        alt_currency,
                                        account_currency,
                                        period_end_date,
                                        gl_reporting_balance,
                                        gl_alt_balance,
                                        gl_account_balance,
                                        account_reference_2,
                                        account_reference_3,
                                        account_reference_4,
                                        account_reference_5,
                                        account_reference_6,
                                        attribute1,
                                        created_by,
                                        creation_date)
                             VALUES (l_request_id, i.ccid, l_file_name,
                                     i.entity_unique_identifier, i.account, i.brand, i.geo, i.channel, i.cost_center, i.intercompany, p_out_secondary_ledger, i.stat_ledger_flag, i.key9, i.key10, i.ACCOUNT_DESCRIPTION, i.ACCOUNT_REFERNCE, i.FINANCAL_STMT, i.account_type, NVL (i.acitve_account, p_out_sec_activty_in_prd), NVL (i.activity_in_period, p_out_sec_activty_in_prd), 'USD', --NULL,--NVL (i.alt_currency, p_out_alt_currency), --alt_currency
                                                                                                                                                                                                                                                                                                                                                                                              p_sec_curr_code, --p_out_alt_currency,--NVL (i.account_currency, p_out_primary_currency), --account_currency
                                                                                                                                                                                                                                                                                                                                                                                                               j.end_date, --period_end_date
                                                                                                                                                                                                                                                                                                                                                                                                                           NULL, --NVL (p_out_sec_gl_rpt_bal, p_out_sec_gl_acct_bal), --gl_reporting_balance
                                                                                                                                                                                                                                                                                                                                                                                                                                 NULL, --p_out_sec_gl_alt_bal,                  --gl_alt_balance
                                                                                                                                                                                                                                                                                                                                                                                                                                       p_out_sec_gl_acct_bal, -- gl_account_balance
                                                                                                                                                                                                                                                                                                                                                                                                                                                              i.ACCOUNT_REFERENCE_2, -- account_reference_2
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     i.ACCOUNT_REFERENCE_3, --account_reference_3
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            i.ACCOUNT_REFERENCE_4, i.ACCOUNT_REFERENCE_5, i.ACCOUNT_REFERENCE_6, 'S', FND_GLOBAL.USER_ID
                                     , SYSDATE);
                    END IF;
                ELSE
                    NULL;
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;   -- end loop writing data for both the period if applicable

        --  call procedure to write the data in file at the given location or if file name is not given then write into the log
        write_bal_file (l_request_id, p_file_path, l_file_name,
                        lv_ret_code, lv_ret_message);

        IF p_file_path IS NOT NULL
        THEN
            IF lv_ret_code = gn_error
            THEN
                p_retcode   := gn_error;
                p_errbuf    :=
                    'After write into account balance - ' || lv_ret_message;
                print_log (p_errbuf);
                raise_application_error (-20002, p_errbuf);
            END IF;

            check_file_exists (p_file_path     => p_file_path,
                               p_file_name     => l_file_name,
                               x_file_exists   => lb_file_exists,
                               x_file_length   => ln_file_length,
                               x_block_size    => ln_block_size);

            IF lb_file_exists
            THEN
                print_log (
                    'Account Balance is successfully created in the directory.');
                lv_ret_code      := NULL;
                lv_ret_message   := NULL;
            ELSE
                --If lb_file_exists is FALSE then do the below
                lv_ret_message   :=
                    SUBSTR (
                        'Account Balance file creation is not successful, Please check the issue.',
                        1,
                        2000);
                print_log (lv_ret_message);
                --Complete the program in error
                p_retcode   := gn_error;
                p_errbuf    := lv_ret_message;
            END IF;
        END IF;                                        --End of lb_file_exists
    END account_balance;
END XXD_GL_ACCT_RECON_BALANCE_PKG;
/
