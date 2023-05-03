--
-- XXD_GL_TRIAL_BALANCE_FILE  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:48 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_TRIAL_BALANCE_FILE"
IS
    /****************************************************************************************
    * Package      : XXD_GL_TRIAL_BALANCE_FILE
    * Design       : This package will be used fetch the GL trail balances and send it to blackline
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 24-Apr-2020  1.0        Shivanshu Talwar     Initial Version
    -- 10-Nov-2020  1.1        Aravind Kannuri      Changes as per CCR0009030
    ******************************************************************************************/
    gc_delimeter   VARCHAR2 (10) := ' | ';


    PROCEDURE fetch_gl_balances (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pv_send_to_bl IN VARCHAR2
                                 , pv_file_path IN VARCHAR2)
    IS
        l_include_style         VARCHAR2 (10) := 'Y';
        l_ret_val               NUMBER := 0;
        l_from_date             DATE;
        l_to_date               DATE;
        l_show_land_cost        VARCHAR2 (30);
        l_custom_cost           VARCHAR2 (20);
        l_regions               VARCHAR2 (20);
        l_region_ou             VARCHAR2 (240);
        v_subject               VARCHAR2 (100);
        l_style                 VARCHAR2 (240);
        l_style_code            VARCHAR2 (240);
        v_employee_order        VARCHAR2 (30);
        v_discount_code         VARCHAR2 (30);
        v_def_mail_recips       apps.do_mail_utils.tbl_recips;
        ex_no_recips            EXCEPTION;
        ex_no_sender            EXCEPTION;
        ex_no_data_found        EXCEPTION;

        CURSOR c_cur_balances IS
            SELECT ffv.attribute1 Entity_Unique_Identifier, --gcc.concatenated_segments Account_Number,  --Commented as per CCR0009030
                                                            NVL (ffv.attribute28, gcc.concatenated_segments) Account_Number, --Added as per CCR0009030
                                                                                                                             ffv.attribute10 key3,
                   ffv.attribute11 key4, ffv.attribute12 key5, ffv.attribute13 key6,
                   ffv.attribute14 key7, ffv.attribute15 key8, ffv.attribute16 key9,
                   ffv.attribute17 key10, ffv.attribute18 Account_Description, ffv.attribute19 Account_Ref,
                   ffv.attribute20 Financial_statement, ffv.attribute21 Account_type, ffv.attribute22 Active_Account,
                   ffv.attribute23 Activity_in_Period, ffv.attribute24 Alternate_currency, gl.Currency_code Account_Currency,
                   gp.end_Date Period_End_Date, NULL Gl_reporting_bal, NULL Gl_alternative_bal,
                   NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) GL_Account_Balance
              FROM apps.gl_balances b, apps.gl_code_combinations_kfv gcc, apps.gl_periods gp,
                   apps.gl_ledgers gl, apps.fnd_flex_values ffv
             WHERE     b.code_combination_id = gcc.code_combination_id
                   AND ffv.flex_value_set_id IN
                           (SELECT flex_value_set_id
                              FROM fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'DO_BL_ACCOUNT_BALANCE')
                   AND ffv.ENABLED_FLAG = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND ffv.SUMMARY_FLAG = 'N'
                   AND NVL (ffv.ATTRIBUTE2, gcc.segment1) = gcc.segment1
                   AND NVL (ffv.ATTRIBUTE3, gcc.segment2) = gcc.segment2
                   AND NVL (ffv.ATTRIBUTE4, gcc.segment3) = gcc.segment3
                   AND NVL (ffv.ATTRIBUTE5, gcc.segment4) = gcc.segment4
                   AND NVL (ffv.ATTRIBUTE6, gcc.segment5) = gcc.segment5
                   AND NVL (ffv.ATTRIBUTE7, gcc.segment6) = gcc.segment6
                   AND NVL (ffv.ATTRIBUTE8, gcc.segment7) = gcc.segment7
                   AND NVL (ffv.ATTRIBUTE9, gcc.segment8) = gcc.segment8
                   AND actual_flag = 'A'
                   AND gl.ledger_category_code = 'PRIMARY'
                   AND gl.ledger_id <> '2081'
                   AND gl.ledger_id = b.ledger_id
                   AND gp.period_set_name = 'DO_FY_CALENDAR'
                   -- AND concatenated_segments ='180.1000.705.100.3100.61006.180.1000'
                   AND TRUNC (SYSDATE) BETWEEN gp.start_date AND gp.end_date
                   /*AND (     NVL (b.period_net_dr, 0)
                           - NVL (b.period_net_cr, 0) <> 0
                        OR   NVL (b.begin_balance_dr, 0)
                           - NVL (b.begin_balance_cr, 0)
                           + NVL (b.period_net_dr, 0)
                           - NVL (b.period_net_cr, 0) <> 0)*/
                   AND b.period_name = gp.period_name                      --(
                   AND b.currency_code = gl.currency_code
                   AND gcc.summary_flag = 'N'
                   AND NVL (ffv.ATTRIBUTE27, 'N') <> 'Y'
            UNION
              SELECT ffv.attribute1 Entity_Unique_Identifier, --gcc.concatenated_segments Account_Number,
                                                              /* -- Start Commented as per CCR0009030
                                                                 ffv.ATTRIBUTE2
                                                              || '.'
                                                              || ffv.ATTRIBUTE3
                                                              || '.'
                                                              || ffv.ATTRIBUTE4
                                                              || '.'
                                                              || ffv.ATTRIBUTE5
                                                              || '.'
                                                              || ffv.ATTRIBUTE6
                                                              || '.'
                                                              || ffv.ATTRIBUTE7
                                                              || '.'
                                                              || ffv.ATTRIBUTE8
                                                              || '.'
                                                              || ffv.ATTRIBUTE9
                                                                 Account_Number,
                                                  */
                                                              -- End Commented as per CCR0009030
                                                              -- Start Added as per CCR0009030
                                                              NVL (ffv.attribute28, ffv.ATTRIBUTE2 || '.' || ffv.ATTRIBUTE3 || '.' || ffv.ATTRIBUTE4 || '.' || ffv.ATTRIBUTE5 || '.' || ffv.ATTRIBUTE6 || '.' || ffv.ATTRIBUTE7 || '.' || ffv.ATTRIBUTE8 || '.' || ffv.ATTRIBUTE9) Account_Number, -- End Added as per CCR0009030
                                                                                                                                                                                                                                                                                                   ffv.attribute10 key3,
                     ffv.attribute11 key4, ffv.attribute12 key5, ffv.attribute13 key6,
                     ffv.attribute14 key7, ffv.attribute15 key8, ffv.attribute16 key9,
                     ffv.attribute17 key10, ffv.attribute18 Account_Description, ffv.attribute19 Account_Ref,
                     ffv.attribute20 Financial_statement, ffv.attribute21 Account_type, ffv.attribute22 Active_Account,
                     ffv.attribute23 Activity_in_Period, ffv.attribute24 Alternate_currency, gl.Currency_code Account_Currency,
                     gp.end_Date Period_End_Date, NULL Gl_reporting_bal, NULL Gl_alternative_bal,
                     SUM (NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0)) GL_Account_Balance
                FROM apps.gl_balances b, apps.gl_code_combinations_kfv gcc, apps.gl_periods gp,
                     apps.gl_ledgers gl, apps.fnd_flex_values ffv
               WHERE     b.code_combination_id = gcc.code_combination_id
                     AND ffv.flex_value_set_id IN
                             (SELECT flex_value_set_id
                                FROM fnd_flex_value_sets
                               WHERE flex_value_set_name =
                                     'DO_BL_ACCOUNT_BALANCE')
                     AND ffv.ENABLED_FLAG = 'Y'
                     AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                     AND NVL (ffv.end_date_active, SYSDATE)
                     AND ffv.SUMMARY_FLAG = 'N'
                     AND NVL (ffv.ATTRIBUTE2, gcc.segment1) = gcc.segment1
                     AND NVL (ffv.ATTRIBUTE3, gcc.segment2) = gcc.segment2
                     AND NVL (ffv.ATTRIBUTE4, gcc.segment3) = gcc.segment3
                     AND NVL (ffv.ATTRIBUTE5, gcc.segment4) = gcc.segment4
                     AND NVL (ffv.ATTRIBUTE6, gcc.segment5) = gcc.segment5
                     AND NVL (ffv.ATTRIBUTE7, gcc.segment6) = gcc.segment6
                     AND NVL (ffv.ATTRIBUTE8, gcc.segment7) = gcc.segment7
                     AND NVL (ffv.ATTRIBUTE9, gcc.segment8) = gcc.segment8
                     AND actual_flag = 'A'
                     AND gl.ledger_category_code = 'PRIMARY'
                     AND gl.ledger_id <> '2081'
                     AND gl.ledger_id = b.ledger_id
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     -- AND concatenated_segments ='180.1000.705.100.3100.61006.180.1000'
                     AND TRUNC (SYSDATE) BETWEEN gp.start_date AND gp.end_date
                     /*AND (     NVL (b.period_net_dr, 0)
                             - NVL (b.period_net_cr, 0) <> 0
                          OR   NVL (b.begin_balance_dr, 0)
                             - NVL (b.begin_balance_cr, 0)
                             + NVL (b.period_net_dr, 0)
                             - NVL (b.period_net_cr, 0) <> 0)*/
                     AND b.period_name = gp.period_name                    --(
                     AND b.currency_code = gl.currency_code
                     AND gcc.summary_flag = 'N'
                     AND NVL (ffv.ATTRIBUTE27, 'N') = 'Y'
            GROUP BY ffv.attribute1, NVL (ffv.attribute28, ffv.ATTRIBUTE2 || '.' || ffv.ATTRIBUTE3 || '.' || ffv.ATTRIBUTE4 || '.' || ffv.ATTRIBUTE5 || '.' || ffv.ATTRIBUTE6 || '.' || ffv.ATTRIBUTE7 || '.' || ffv.ATTRIBUTE8 || '.' || ffv.ATTRIBUTE9), ffv.attribute10,
                     ffv.attribute11, ffv.attribute12, ffv.attribute13,
                     ffv.attribute14, ffv.attribute15, ffv.attribute16,
                     ffv.attribute17, ffv.attribute18, ffv.attribute19,
                     ffv.attribute20, ffv.attribute21, ffv.attribute22,
                     ffv.attribute23, ffv.attribute24, gl.Currency_code,
                     gp.end_Date, 'GL Reporting Balance', 'GL Alternate Balance';



        CURSOR c_previous_month_bal IS
            SELECT ffv.attribute1 Entity_Unique_Identifier, --gcc.concatenated_segments Account_Number,   --Commented as per CCR0009030
                                                            NVL (ffv.attribute28, gcc.concatenated_segments) Account_Number, --Added as per CCR0009030
                                                                                                                             ffv.attribute10 key3,
                   ffv.attribute11 key4, ffv.attribute12 key5, ffv.attribute13 key6,
                   ffv.attribute14 key7, ffv.attribute15 key8, ffv.attribute16 key9,
                   ffv.attribute17 key10, ffv.attribute18 Account_Description, ffv.attribute19 Account_Ref,
                   ffv.attribute20 Financial_statement, ffv.attribute21 Account_type, ffv.attribute22 Active_Account,
                   ffv.attribute23 Activity_in_Period, ffv.attribute24 Alternate_currency, gl.Currency_code Account_Currency,
                   gp.end_Date Period_End_Date, NULL Gl_reporting_bal, NULL Gl_alternative_bal,
                   NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0) GL_Account_Balance
              FROM apps.gl_balances b, apps.gl_code_combinations_kfv gcc, apps.gl_periods gp,
                   apps.gl_ledgers gl, apps.fnd_flex_values ffv
             WHERE     b.code_combination_id = gcc.code_combination_id
                   AND ffv.flex_value_set_id IN
                           (SELECT flex_value_set_id
                              FROM fnd_flex_value_sets
                             WHERE flex_value_set_name =
                                   'DO_BL_ACCOUNT_BALANCE')
                   AND ffv.ENABLED_FLAG = 'Y'
                   AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                   AND NVL (ffv.end_date_active, SYSDATE)
                   AND ffv.SUMMARY_FLAG = 'N'
                   AND NVL (ffv.ATTRIBUTE2, gcc.segment1) = gcc.segment1
                   AND NVL (ffv.ATTRIBUTE3, gcc.segment2) = gcc.segment2
                   AND NVL (ffv.ATTRIBUTE4, gcc.segment3) = gcc.segment3
                   AND NVL (ffv.ATTRIBUTE5, gcc.segment4) = gcc.segment4
                   AND NVL (ffv.ATTRIBUTE6, gcc.segment5) = gcc.segment5
                   AND NVL (ffv.ATTRIBUTE7, gcc.segment6) = gcc.segment6
                   AND NVL (ffv.ATTRIBUTE8, gcc.segment7) = gcc.segment7
                   AND NVL (ffv.ATTRIBUTE9, gcc.segment8) = gcc.segment8
                   AND actual_flag = 'A'
                   AND gl.ledger_category_code = 'PRIMARY'
                   AND gl.ledger_id <> '2081'
                   AND gl.ledger_id = b.ledger_id
                   AND gp.period_set_name = 'DO_FY_CALENDAR'
                   AND TO_CHAR (SYSDATE, 'MON') <>
                       TO_CHAR (SYSDATE - TO_NUMBER (ffv.attribute26), 'MON')
                   AND TRUNC (SYSDATE - TO_NUMBER (ffv.attribute26)) BETWEEN gp.start_date
                                                                         AND gp.end_date
                   /*AND (     NVL (b.period_net_dr, 0)
                           - NVL (b.period_net_cr, 0) <> 0
                        OR   NVL (b.begin_balance_dr, 0)
                           - NVL (b.begin_balance_cr, 0)
                           + NVL (b.period_net_dr, 0)
                           - NVL (b.period_net_cr, 0) <> 0)*/
                   AND b.period_name = gp.period_name                      --(
                   AND b.currency_code = gl.currency_code
                   AND ffv.attribute26 IS NOT NULL
                   AND gcc.summary_flag = 'N'
                   AND NVL (ffv.ATTRIBUTE27, 'N') <> 'Y'
            UNION
              SELECT ffv.attribute1 Entity_Unique_Identifier, --gcc.concatenated_segments Account_Number,
                                                              /* -- Start Commented as per CCR0009030
                                                                 ffv.ATTRIBUTE2
                                                              || '.'
                                                              || ffv.ATTRIBUTE3
                                                              || '.'
                                                              || ffv.ATTRIBUTE4
                                                              || '.'
                                                              || ffv.ATTRIBUTE5
                                                              || '.'
                                                              || ffv.ATTRIBUTE6
                                                              || '.'
                                                              || ffv.ATTRIBUTE7
                                                              || '.'
                                                              || ffv.ATTRIBUTE8
                                                              || '.'
                                                              || ffv.ATTRIBUTE9
                                                                 Account_Number,
                                                     */
                                                              -- End Commented as per CCR0009030
                                                              -- Start Added as per CCR0009030
                                                              NVL (ffv.attribute28, ffv.ATTRIBUTE2 || '.' || ffv.ATTRIBUTE3 || '.' || ffv.ATTRIBUTE4 || '.' || ffv.ATTRIBUTE5 || '.' || ffv.ATTRIBUTE6 || '.' || ffv.ATTRIBUTE7 || '.' || ffv.ATTRIBUTE8 || '.' || ffv.ATTRIBUTE9) Account_Number, -- End Added as per CCR0009030
                                                                                                                                                                                                                                                                                                   ffv.attribute10 key3,
                     ffv.attribute11 key4, ffv.attribute12 key5, ffv.attribute13 key6,
                     ffv.attribute14 key7, ffv.attribute15 key8, ffv.attribute16 key9,
                     ffv.attribute17 key10, ffv.attribute18 Account_Description, ffv.attribute19 Account_Ref,
                     ffv.attribute20 Financial_statement, ffv.attribute21 Account_type, ffv.attribute22 Active_Account,
                     ffv.attribute23 Activity_in_Period, ffv.attribute24 Alternate_currency, gl.Currency_code Account_Currency,
                     gp.end_Date Period_End_Date, NULL Gl_reporting_bal, NULL Gl_alternative_bal,
                     SUM (NVL (b.begin_balance_dr, 0) - NVL (b.begin_balance_cr, 0) + NVL (b.period_net_dr, 0) - NVL (b.period_net_cr, 0)) GL_Account_Balance
                FROM apps.gl_balances b, apps.gl_code_combinations_kfv gcc, apps.gl_periods gp,
                     apps.gl_ledgers gl, apps.fnd_flex_values ffv
               WHERE     b.code_combination_id = gcc.code_combination_id
                     AND ffv.flex_value_set_id IN
                             (SELECT flex_value_set_id
                                FROM fnd_flex_value_sets
                               WHERE flex_value_set_name =
                                     'DO_BL_ACCOUNT_BALANCE')
                     AND ffv.ENABLED_FLAG = 'Y'
                     AND ffv.SUMMARY_FLAG = 'N'
                     AND NVL (ffv.ATTRIBUTE2, gcc.segment1) = gcc.segment1
                     AND NVL (ffv.ATTRIBUTE3, gcc.segment2) = gcc.segment2
                     AND NVL (ffv.ATTRIBUTE4, gcc.segment3) = gcc.segment3
                     AND NVL (ffv.ATTRIBUTE5, gcc.segment4) = gcc.segment4
                     AND NVL (ffv.ATTRIBUTE6, gcc.segment5) = gcc.segment5
                     AND NVL (ffv.ATTRIBUTE7, gcc.segment6) = gcc.segment6
                     AND NVL (ffv.ATTRIBUTE8, gcc.segment7) = gcc.segment7
                     AND NVL (ffv.ATTRIBUTE9, gcc.segment8) = gcc.segment8
                     AND actual_flag = 'A'
                     AND SYSDATE BETWEEN NVL (ffv.start_date_active, SYSDATE)
                                     AND NVL (ffv.end_date_active, SYSDATE)
                     AND gl.ledger_category_code = 'PRIMARY'
                     AND gl.ledger_id <> '2081'
                     AND gl.ledger_id = b.ledger_id
                     AND gp.period_set_name = 'DO_FY_CALENDAR'
                     AND TO_CHAR (SYSDATE, 'MON') <>
                         TO_CHAR (SYSDATE - TO_NUMBER (ffv.attribute26), 'MON')
                     AND TRUNC (SYSDATE - TO_NUMBER (ffv.attribute26)) BETWEEN gp.start_date
                                                                           AND gp.end_date
                     /*AND (     NVL (b.period_net_dr, 0)
                             - NVL (b.period_net_cr, 0) <> 0
                          OR   NVL (b.begin_balance_dr, 0)
                             - NVL (b.begin_balance_cr, 0)
                             + NVL (b.period_net_dr, 0)
                             - NVL (b.period_net_cr, 0) <> 0)*/
                     AND b.period_name = gp.period_name                    --(
                     AND b.currency_code = gl.currency_code
                     AND gcc.summary_flag = 'N'
                     AND NVL (ffv.ATTRIBUTE27, 'N') = 'Y'
            GROUP BY ffv.attribute1, NVL (ffv.attribute28, ffv.ATTRIBUTE2 || '.' || ffv.ATTRIBUTE3 || '.' || ffv.ATTRIBUTE4 || '.' || ffv.ATTRIBUTE5 || '.' || ffv.ATTRIBUTE6 || '.' || ffv.ATTRIBUTE7 || '.' || ffv.ATTRIBUTE8 || '.' || ffv.ATTRIBUTE9), ffv.attribute10,
                     ffv.attribute11, ffv.attribute12, ffv.attribute13,
                     ffv.attribute14, ffv.attribute15, ffv.attribute16,
                     ffv.attribute17, ffv.attribute18, ffv.attribute19,
                     ffv.attribute20, ffv.attribute21, ffv.attribute22,
                     ffv.attribute23, ffv.attribute24, gl.Currency_code,
                     gp.end_Date, 'GL Reporting Balance', 'GL Alternate Balance';



        l_start_date            DATE;
        l_end_date              DATE;
        ld_date                 DATE;
        lv_file_path            VARCHAR2 (360) := pv_file_path;
        lv_output_file          UTL_FILE.file_type;
        lv_outbound_cur_file    VARCHAR2 (360)
            := 'GL_BAL_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        lv_outbound_prev_file   VARCHAR2 (360)
            := 'GL_BAL_Previuos_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        lv_ver                  VARCHAR2 (32767) := NULL;
        lv_line                 VARCHAR2 (32767) := NULL;
        lv_line1                VARCHAR2 (32767) := NULL;
        lv_output               VARCHAR2 (360);
        lv_output1              VARCHAR2 (360);
        lv_delimiter            VARCHAR2 (1) := CHR (9);
        lv_file_delimiter       VARCHAR2 (1) := ',';
        ln_valid_dir            NUMBER;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Start Time: ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        fnd_file.put_line (fnd_file.LOG,
                           'Send to Black Line: ' || pv_send_to_bl);

        fnd_file.put_line (fnd_file.LOG, 'Path: ' || lv_file_path);


        SELECT COUNT (1)
          INTO ln_valid_dir
          FROM dba_directories
         WHERE DIRECTORY_NAME = lv_file_path;

        IF ln_valid_dir = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Invalid DBA directory : ' || lv_file_path);
            errbuf    := 'Invalid DBA directory :';
            retcode   := 2;
            GOTO end_prog;
        END IF;


        lv_delimiter   := CHR (9);
        lv_ver         :=
               'Entity_Unique_Identifier'
            || lv_delimiter
            || 'Account_Number'
            || lv_delimiter
            || 'Key3'
            || lv_delimiter
            || 'Key4'
            || lv_delimiter
            || 'Key5'
            || lv_delimiter
            || 'Key6'
            || lv_delimiter
            || 'Key7'
            || lv_delimiter
            || 'Key8'
            || lv_delimiter
            || 'Key9'
            || lv_delimiter
            || 'Key10'
            || lv_delimiter
            || 'Account Description'
            || lv_delimiter
            || 'Account Reference'
            || lv_delimiter
            || 'Financial Statement'
            || lv_delimiter
            || 'Account Type'
            || lv_delimiter
            || 'Active Account'
            || lv_delimiter
            || 'Activity in Period'
            || lv_delimiter
            || 'Alternate Currenc'
            || lv_delimiter
            || 'Account Currency'
            || lv_delimiter
            || 'Period End Date'
            || lv_delimiter
            || 'GL Reporting Balance'
            || lv_delimiter
            || 'GL Alternate Balance'
            || lv_delimiter
            || 'GL Account Balance';

        --Printing Output
        lv_output      :=
            '***GL Trial Balance Output file will be sent to BlackLine***';
        apps.fnd_file.put_line (apps.fnd_file.output, lv_output);

        --Writing into a file
        IF pv_send_to_bl = 'Y'
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
        FOR i IN c_cur_balances
        LOOP
            BEGIN
                lv_delimiter   := CHR (9);
                lv_line        :=
                       REPLACE (i.Entity_Unique_Identifier, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key3, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key4, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key5, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key6, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key7, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key8, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key9, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key10, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Description, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Ref, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Financial_statement, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_type, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Active_Account, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Activity_in_Period, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Alternate_currency, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Currency, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Period_End_Date, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Gl_reporting_bal, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Gl_alternative_bal, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.GL_Account_Balance, CHR (9), ' ');


                --apps.fnd_file.put_line (apps.fnd_file.output, lv_line);

                IF pv_send_to_bl = 'Y'
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
                    apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Account Number :' || i.Account_Number
                                               , l_debug_level => 1);
            END;
        END LOOP;



        IF pv_send_to_bl = 'Y'
        THEN
            UTL_FILE.fclose (lv_output_file);
            UTL_FILE.frename (
                src_location    => lv_file_path,
                src_filename    => lv_outbound_cur_file || '.tmp',
                dest_location   => lv_file_path,
                dest_filename   => lv_outbound_cur_file || '.csv',
                overwrite       => TRUE);
        END IF;


        --Writing into a file
        IF pv_send_to_bl = 'Y'
        THEN
            lv_output_file   :=
                UTL_FILE.fopen (lv_file_path, lv_outbound_prev_file || '.tmp', 'W' --opening the file in write mode
                                , 32767);

            IF UTL_FILE.is_open (lv_output_file)
            THEN
                lv_ver   := REPLACE (lv_ver, lv_delimiter, lv_file_delimiter);
                UTL_FILE.put_line (lv_output_file, lv_ver);
            END IF;
        END IF;


        /* LOOP THROUGH GL BALANCES */
        FOR i IN c_previous_month_bal
        LOOP
            BEGIN
                lv_delimiter   := CHR (9);
                lv_line1       :=
                       REPLACE (i.Entity_Unique_Identifier, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Number, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key3, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key4, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key5, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key6, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key7, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key8, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key9, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.key10, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Description, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Ref, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Financial_statement, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_type, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Active_Account, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Activity_in_Period, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Alternate_currency, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Account_Currency, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Period_End_Date, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Gl_reporting_bal, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.Gl_alternative_bal, CHR (9), ' ')
                    || lv_delimiter
                    || REPLACE (i.GL_Account_Balance, CHR (9), ' ');


                --apps.fnd_file.put_line (apps.fnd_file.output, lv_line1);

                IF pv_send_to_bl = 'Y'
                THEN
                    IF UTL_FILE.is_open (lv_output_file)
                    THEN
                        lv_line1   :=
                            REPLACE (lv_line1,
                                     lv_delimiter,
                                     lv_file_delimiter);
                        UTL_FILE.put_line (lv_output_file, lv_line1);
                    END IF;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM || 'Account Number :' || i.Account_Number
                                               , l_debug_level => 1);
            END;
        END LOOP;



        IF pv_send_to_bl = 'Y'
        THEN
            UTL_FILE.fclose (lv_output_file);
            UTL_FILE.frename (
                src_location    => lv_file_path,
                src_filename    => lv_outbound_prev_file || '.tmp',
                dest_location   => lv_file_path,
                dest_filename   => lv_outbound_prev_file || '.csv',
                overwrite       => TRUE);
        END IF;

       <<end_prog>>
        NULL;
    EXCEPTION
        WHEN UTL_FILE.invalid_path
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'INVALID_PATH: File location or filename was invalid.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_mode
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'INVALID_MODE: The open_mode parameter in FOPEN was invalid.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_filehandle
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'INVALID_FILEHANDLE: The file handle was invalid.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_operation
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'INVALID_OPERATION: The file could not be opened or operated on as requested.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.read_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'READ_ERROR: An operating system error occurred during the read operation.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.write_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'WRITE_ERROR: An operating system error occurred during the write operation.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.internal_error
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'INTERNAL_ERROR: An unspecified error in PL/SQL.'
                                       , l_debug_level => 1);
        WHEN UTL_FILE.invalid_filename
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'INVALID_FILENAME: The filename parameter is invalid.'
                                       , l_debug_level => 1);
        WHEN ex_no_data_found
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'There are no international invoices for the specified month.'
                                       , l_debug_level => 1);
        WHEN ex_no_recips
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'There were no recipients configured to receive the alert'
                                       , l_debug_level => 1);
        WHEN ex_no_sender
        THEN
            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'There is no sender configured. Check the profile value DO_DEF_ALERT_SENDER'
                                       , l_debug_level => 1);
        WHEN OTHERS
        THEN
            IF UTL_FILE.is_open (lv_output_file)
            THEN
                UTL_FILE.fclose (lv_output_file);
            END IF;

            apps.do_debug_utils.WRITE (l_debug_loc => apps.do_debug_utils.debug_conc_output, v_application_id => 'XXD_GL_TRIAL_BALANCE_FILE.FETCH_GL_BALANCES', v_debug_text => CHR (10) || 'Global exception handler hit (' || SQLCODE || '): ' || SQLERRM
                                       , l_debug_level => 1);
    END FETCH_GL_BALANCES;
END XXD_GL_TRIAL_BALANCE_FILE;
/
