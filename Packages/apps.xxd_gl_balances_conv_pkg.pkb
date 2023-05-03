--
-- XXD_GL_BALANCES_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:21 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.xxd_gl_balances_conv_pkg
-- +=======================================================================+
-- |                    Deckers BT Team                                    |
-- +=======================================================================+
-- |                                                                       |
-- | $Id: $                                                                |
-- |                                                                       |
-- | Description      : XXD_GL_BALANCES_CONV_PKG.sql                       |
-- |                                                                       |
-- |                                                                       |
-- | Purpose          : Script to create package spec for GL Balances      |
-- |                    Conversion                                         |
-- |                                                                       |
-- |Change Record:                                                         |
-- |===============                                                        |
-- |Version   Date        Author                Remarks                    |
-- |=======   ==========  =============        ============================|
-- | 1        21-APR-2015 BT Technology Team   Initial Version              |
-- +=======================================================================+
AS
    gc_submit   CONSTANT VARCHAR2 (10) := 'SUBMIT';

    PROCEDURE log_records (p_debug VARCHAR2, p_message VARCHAR2)
    IS
    BEGIN
        DBMS_OUTPUT.put_line (p_message);

        IF p_debug = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_message);
        END IF;
    END log_records;

    FUNCTION validate_period (p_posting_date VARCHAR2, p_period IN VARCHAR2)
        RETURN BOOLEAN
    /**********************************************************************************************
    *                                                                                             *
    * Function  Name       :  validate_period                                                     *
    *                                                                                             *
    * Description          :  Function to get check if period is open                             *
    *                                                                                             *
    * Parameters         Type       Description                                                   *                                                   *
    * ---------------    ----       ---------------------                                         *
    * p_posting_date     IN         Accounting Date                                               *
    *                                                                                             *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * 1.0      21-APR-2015    BT Technology Team         Initial creation                        *
    *                                                                                             *
    **********************************************************************************************/
    IS
        ln_period_open   NUMBER;
    BEGIN
        --
        log_records (
            gc_debug_flag,
            'Inside Function TO Check Whether the period is in open status');

        --
        SELECT 1
          INTO ln_period_open
          FROM gl_period_statuses
         WHERE     application_id =
                   (SELECT application_id
                      FROM apps.fnd_application
                     WHERE application_short_name = gc_appl_short_name)
               AND ledger_id = gn_ledger_id
               AND TO_DATE (p_posting_date, 'DD-MON-YY') BETWEEN start_date
                                                             AND end_date
               AND period_name = p_period
               AND closing_status = 'O';

        RETURN TRUE;
    EXCEPTION
        WHEN NO_DATA_FOUND OR TOO_MANY_ROWS
        THEN
            log_records (
                gc_debug_flag,
                'Inside NO_DATA_FOUND/TOO_MANY_ROWS in validate_period function');
            log_records (gc_debug_flag,
                         p_period || p_posting_date || gn_ledger_id);
            RETURN FALSE;
        WHEN OTHERS
        THEN
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 150)
                || ' Exception in validate_period function  ');
            RETURN FALSE;
    END validate_period;

    PROCEDURE update_balance_account
    IS
        CURSOR c_fetch_stg_acc_rec IS
              SELECT DECODE (SIGN (SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), 1, SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0)), 0) adj_accounted_cr, DECODE (SIGN (SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), -1, -(SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), 0) adj_accounted_dr, record_status,
                     stg.attribute15, stg.currency_code, stg.reference1,
                     category_name, user_je_source_name, period_name,
                     '190' segment1, gcc.segment2, gcc.segment3,
                     gcc.segment4, gcc.segment5, gcc.segment6,
                     gcc.segment7, gcc.segment8, functional_currency_code,
                     ledger_name, stg.ledger_id, accounting_date,
                     actual_flag, request_id
                FROM xxd_gl_balances_inface_stg_t stg, gl_code_combinations gcc, gl_ledgers ledgers
               WHERE     stg.currency_code != functional_currency_code
                     AND stg.attribute15 = 19
                     AND record_status = 'VALIDATED'
                     AND stg.attribute10 IS NULL
                     AND gcc.code_combination_id =
                         cum_trans_code_combination_id
                     AND ledgers.ledger_id = stg.ledger_id
            GROUP BY record_status, stg.attribute15, stg.currency_code,
                     stg.reference1, category_name, user_je_source_name,
                     period_name, functional_currency_code, ledger_name,
                     stg.ledger_id, accounting_date, actual_flag,
                     request_id, gcc.segment2, gcc.segment3,
                     gcc.segment4, gcc.segment5, gcc.segment6,
                     gcc.segment7, gcc.segment8
              HAVING SUM (accounted_cr) - SUM (accounted_dr) != 0
            --ORDER BY attribute15
            UNION
              SELECT DECODE (SIGN (SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), 1, SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0)), 0) adj_accounted_cr, DECODE (SIGN (SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), -1, -(SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), 0) adj_accounted_dr, record_status,
                     stg.attribute15, stg.currency_code, stg.reference1,
                     category_name, user_je_source_name, period_name,
                     gcc.segment1, gcc.segment2, gcc.segment3,
                     gcc.segment4, gcc.segment5, gcc.segment6,
                     gcc.segment7, gcc.segment8, functional_currency_code,
                     ledger_name, stg.ledger_id, accounting_date,
                     actual_flag, request_id
                FROM xxd_gl_balances_inface_stg_t stg, gl_code_combinations gcc, gl_ledgers ledgers
               WHERE     stg.currency_code != functional_currency_code
                     AND stg.attribute15 = 28
                     AND record_status = 'VALIDATED'
                     AND stg.attribute10 IS NULL
                     AND gcc.code_combination_id =
                         cum_trans_code_combination_id
                     AND ledgers.ledger_id = stg.ledger_id
            GROUP BY record_status, stg.attribute15, stg.currency_code,
                     stg.reference1, category_name, user_je_source_name,
                     period_name, functional_currency_code, ledger_name,
                     stg.ledger_id, accounting_date, actual_flag,
                     request_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8
              HAVING SUM (accounted_cr) - SUM (accounted_dr) != 0
            UNION
              SELECT DECODE (SIGN (SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), 1, SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0)), 0) adj_accounted_cr, DECODE (SIGN (SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), -1, -(SUM (NVL (accounted_dr, 0)) - SUM (NVL (accounted_cr, 0))), 0) adj_accounted_dr, record_status,
                     stg.attribute15, stg.currency_code, stg.reference1,
                     category_name, user_je_source_name, period_name,
                     gcc.segment1, gcc.segment2, gcc.segment3,
                     gcc.segment4, gcc.segment5, gcc.segment6,
                     gcc.segment7, gcc.segment8, functional_currency_code,
                     ledger_name, stg.ledger_id, accounting_date,
                     actual_flag, request_id
                FROM xxd_gl_balances_inface_stg_t stg, gl_code_combinations gcc, gl_ledgers ledgers
               WHERE     stg.currency_code != functional_currency_code
                     AND stg.attribute15 = 03
                     AND record_status = 'VALIDATED'
                     AND stg.attribute10 IS NULL
                     AND gcc.code_combination_id =
                         cum_trans_code_combination_id
                     AND ledgers.ledger_id = stg.ledger_id
            GROUP BY record_status, stg.attribute15, stg.currency_code,
                     stg.reference1, category_name, user_je_source_name,
                     period_name, functional_currency_code, ledger_name,
                     stg.ledger_id, accounting_date, actual_flag,
                     request_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8
              HAVING SUM (accounted_cr) - SUM (accounted_dr) != 0
            ORDER BY attribute15;
    BEGIN
        FOR ln_c_fetch_stg_acc_rec IN c_fetch_stg_acc_rec
        LOOP
            INSERT INTO xxd_gl_balances_inface_stg_t (
                            accounted_cr,
                            accounted_dr,
                            --  concatenated_segments,
                            --   currency_code,
                            --   actual_flag,
                            category_name,
                            user_je_source_name,
                            period_name,
                            record_status,
                            --  accounting_date,
                            currency_code,
                            functional_currency_code,
                            reference1,
                            segment1,
                            segment2,
                            segment3,
                            segment4,
                            segment5,
                            segment6,
                            segment7,
                            segment8,
                            --  ledger_category_code,
                            -- old_ledger_id
                            batch_id,
                            ledger_name,
                            ledger_id,
                            record_id,
                            attribute15,
                            accounting_date,
                            actual_flag,
                            attribute10,
                            request_id)
                 VALUES (ln_c_fetch_stg_acc_rec.adj_accounted_cr, ln_c_fetch_stg_acc_rec.adj_accounted_dr, --  concatenated_segments,
                                                                                                           --  ln_c_fetch_stg_acc_rec.currency_code,
                                                                                                           --  ln_c_fetch_stg_acc_rec.actual_flag,
                                                                                                           ln_c_fetch_stg_acc_rec.category_name, ln_c_fetch_stg_acc_rec.user_je_source_name, ln_c_fetch_stg_acc_rec.period_name, ln_c_fetch_stg_acc_rec.record_status, --  ln_c_fetch_stg_acc_rec.accounting_date,
                                                                                                                                                                                                                                                                       ln_c_fetch_stg_acc_rec.currency_code, ln_c_fetch_stg_acc_rec.functional_currency_code, ln_c_fetch_stg_acc_rec.reference1, ln_c_fetch_stg_acc_rec.segment1, ln_c_fetch_stg_acc_rec.segment2, ln_c_fetch_stg_acc_rec.segment3, ln_c_fetch_stg_acc_rec.segment4, ln_c_fetch_stg_acc_rec.segment5, ln_c_fetch_stg_acc_rec.segment6, ln_c_fetch_stg_acc_rec.segment7, ln_c_fetch_stg_acc_rec.segment8, xxd_conv.xxd_gl_balances_inface_stg_seq.NEXTVAL, ln_c_fetch_stg_acc_rec.ledger_name, ln_c_fetch_stg_acc_rec.ledger_id, xxd_gl_bal_id_s.NEXTVAL, ln_c_fetch_stg_acc_rec.attribute15, ln_c_fetch_stg_acc_rec.accounting_date, ln_c_fetch_stg_acc_rec.actual_flag
                         , 'Accounted', ln_c_fetch_stg_acc_rec.request_id);
        --log_records ('Y', 'Calling gl_balances_validation :'||ln_c_fetch_stg_acc_rec.currency_code);
        --log_records ('Y', 'accounted_cr :'||ln_c_fetch_stg_acc_rec.adj_accounted_cr);
        --log_records ('Y', 'accounted_dr :'||ln_c_fetch_stg_acc_rec.adj_accounted_dr);
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END update_balance_account;

    PROCEDURE validate_records (p_batch_id      IN     NUMBER,
                                p_debug_flag    IN     VARCHAR2,
                                p_ledger_name   IN     VARCHAR2,
                                x_ret_code         OUT VARCHAR2,
                                x_errbuf           OUT VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  validate_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the gl_interface program               *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * 1.0          24-Apr-2015     BT Technology Team   Initial creation                          *
    *                                                                                             *
    **********************************************************************************************/
    IS
        lc_currency_code       VARCHAR2 (30);
        ln_seg_id              NUMBER := 0;
        ln_err_cnt             NUMBER := 0;
        ln_ccid                NUMBER := -1;
        lr_gl_segments         apps.fnd_flex_ext.segmentarray;
        lc_proc_status         CHAR (1);
        lc_err_msg             VARCHAR2 (500);
        lc_proc_err_msg        VARCHAR2 (1000);
        ln_record_error_flag   NUMBER := 0;
        lc_conversion_type     VARCHAR2 (100);
        lc_ret_msg             VARCHAR2 (4000);
        lb_val_date_format     BOOLEAN := TRUE;
        ld_accounting_date     DATE := NULL;
        lc_conc_segs           VARCHAR2 (100);
        lc_new_conc_segs       VARCHAR2 (100);
        lc_coa_id              NUMBER;
        lc_category            VARCHAR2 (100);
        lc_error_message       VARCHAR2 (8000) := NULL;
        ln_flag                NUMBER := 0;
        lc_phase               VARCHAR2 (8000) := NULL;
        lc_seg1                VARCHAR2 (50 BYTE);
        lc_seg2                VARCHAR2 (50 BYTE);
        lc_seg3                VARCHAR2 (50 BYTE);
        lc_seg4                VARCHAR2 (50 BYTE);
        lc_seg5                VARCHAR2 (50 BYTE);
        lc_seg6                VARCHAR2 (50 BYTE);
        lc_seg7                VARCHAR2 (50 BYTE);
        lc_seg8                VARCHAR2 (50 BYTE);
        lc_concat_code         VARCHAR2 (100);
        lc_source_exists       VARCHAR2 (100);
        ln_category_cnt        NUMBER;
        ex_sum_invalid         EXCEPTION;
        ln_mismatch            NUMBER;
        ln_cnv_rate            NUMBER;
        ld_cnv_rdate           DATE;
        lv_prd_name            VARCHAR2 (50);
        ld_ac_date             DATE;
        ex_date_exc            EXCEPTION;
        fn_currency_code       VARCHAR2 (50);
        ln_nec_entered_dr      NUMBER;
        ln_ec_entered_dr       NUMBER;
        ln_ec_entered_cr       NUMBER;
        ln_nec_entered_cr      NUMBER;
        ln_neentered_dr        NUMBER;
        ln_neentered_cr        NUMBER;
        ln_eentered_dr         NUMBER;
        ln_eentered_cr         NUMBER;
        lc_cur_conv_type       VARCHAR2 (50);

        ----------------------------------------
        --Cursor to fetch the eligible records from the staging table
        --------------------------------------------------------------
        CURSOR c_fetch_stg_rec (cp_ledger_name VARCHAR2)
        IS
            SELECT xgpi.*
              FROM xxd_gl_balances_inface_stg_t xgpi
             WHERE     xgpi.record_status = gc_new_status
                   AND xgpi.batch_id = p_batch_id
                   AND xgpi.request_id = gn_conc_request_id;
    BEGIN
        gc_debug_flag       := p_debug_flag;
        x_ret_code          := gn_suc_const;
        -- x_valid_cnt:=0;
        gn_intf_record_id   := NULL;
        log_records (gc_debug_flag, ' Inside validate_records procedure ');
        log_records (gc_debug_flag,
                     ' batch ' || p_batch_id || gn_conc_request_id);

        FOR rec_fetch_stg_rec IN c_fetch_stg_rec (p_ledger_name)
        LOOP
            lc_seg1                := NULL;
            lc_seg2                := NULL;
            lc_seg3                := NULL;
            lc_seg4                := NULL;
            lc_seg5                := NULL;
            lc_seg6                := NULL;
            lc_seg7                := NULL;
            lc_seg8                := NULL;
            lc_error_message       := NULL;
            gn_ledger_id           := NULL;
            gn_intf_record_id      := rec_fetch_stg_rec.record_id;
            ln_record_error_flag   := 0;
            ln_cnv_rate            := 0;
            lb_val_date_format     := TRUE;
            log_records (
                gc_debug_flag,
                ' Interface Record Id ' || rec_fetch_stg_rec.record_id);
            lc_cur_conv_type       := NULL;

            ---------------------------------------------------------
            --Validation for currency
            ---------------------------------------------------------
            IF rec_fetch_stg_rec.currency_code IS NULL
            THEN
                ln_record_error_flag   := 1;
                log_records (gc_debug_flag,
                             'Currency Code is a mandatory field');
            ELSE
                BEGIN
                    SELECT currency_code
                      INTO lc_currency_code
                      FROM fnd_currencies
                     WHERE currency_code = rec_fetch_stg_rec.currency_code;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_record_error_flag   := 1;
                        log_records (gc_debug_flag,
                                     'Currency Code is Not Defined');
                        lc_phase               :=
                            'Currency Code is Not Defined';
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'Currency Code', NULL
                                                       , NULL);
                    WHEN OTHERS
                    THEN
                        ln_record_error_flag   := 1;
                        log_records (
                            gc_debug_flag,
                               SUBSTR (SQLERRM, 1, 150)
                            || ' Exception while validating Currency Code against FND_CURRENCIES');
                        lc_phase               :=
                               SUBSTR (SQLERRM, 1, 150)
                            || ' Exception while validating Currency Code against FND_CURRENCIES';
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'Currency Code', NULL
                                                       , NULL);
                END;
            END IF;                                     ---Currency Code check

            -------------------------------------------------------
            --Validation for source
            ------------------------------------------------------
            BEGIN
                SELECT COUNT (1)
                  INTO lc_source_exists
                  FROM gl_je_sources
                 WHERE UPPER (user_je_source_name) =
                       UPPER (rec_fetch_stg_rec.user_je_source_name);

                --
                log_records (
                    gc_debug_flag,
                    'Source Name : ' || rec_fetch_stg_rec.user_je_source_name);

                IF lc_source_exists != 1
                THEN
                    ln_record_error_flag   := 1;
                    log_records (
                        gc_debug_flag,
                        SUBSTR (SQLERRM, 1, 150) || ' user_je_source_name');
                    lc_phase               :=
                        SUBSTR (SQLERRM, 1, 150) || ' user_je_source_name';
                    ln_flag                := ln_flag + 1;
                    lc_error_message       :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                    xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                               lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                              --    SYSDATE,
                                                                                                                                                              gn_user_id, gn_conc_request_id, 'user_je_source_name', NULL
                                                   , NULL);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_record_error_flag   := 1;
                    log_records (
                        gc_debug_flag,
                        SUBSTR (SQLERRM, 1, 150) || ' user_je_source_name');
                    lc_phase               :=
                        SUBSTR (SQLERRM, 1, 150) || ' user_je_source_name';
                    ln_flag                := ln_flag + 1;
                    lc_error_message       :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                    xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                               lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                              --    SYSDATE,
                                                                                                                                                              gn_user_id, gn_conc_request_id, 'user_je_source_name', NULL
                                                   , NULL);
            END;

            --------------------------------------------------------------------------------------------------
            -- To Check Whether The Category Names
            -----------------------------------------------------------------------------------------------
            log_records (gc_debug_flag, 'Validating Category Names :  ');

            BEGIN
                SELECT COUNT (1)
                  INTO ln_category_cnt
                  FROM gl_je_categories
                 WHERE UPPER (user_je_category_name) =
                       UPPER (rec_fetch_stg_rec.category_name);

                --
                log_records (gc_debug_flag,
                             'Category Name count : ' || ln_category_cnt);

                IF ln_category_cnt != 1
                THEN
                    ln_record_error_flag   := 1;
                    log_records (
                        gc_debug_flag,
                        SUBSTR (SQLERRM, 1, 150) || ' category_name');
                    lc_phase               :=
                        SUBSTR (SQLERRM, 1, 150) || ' category_name';
                    ln_flag                := ln_flag + 1;
                    lc_error_message       :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                    xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                               lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                              --    SYSDATE,
                                                                                                                                                              gn_user_id, gn_conc_request_id, 'category_name', NULL
                                                   , NULL);
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ln_record_error_flag   := 1;
                    log_records (
                        gc_debug_flag,
                        SUBSTR (SQLERRM, 1, 150) || ' category_name');
                    lc_phase               :=
                        SUBSTR (SQLERRM, 1, 150) || ' category_name';
                    ln_flag                := ln_flag + 1;
                    lc_error_message       :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                    xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                               lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                              --    SYSDATE,
                                                                                                                                                              gn_user_id, gn_conc_request_id, 'category_name', NULL
                                                   , NULL);
            END;

            -----------------------------------------------------------------
            --Checking whether either of entered CR or entered DR is populated
            -------------------------------------------------------------------
            IF     rec_fetch_stg_rec.entered_cr IS NULL
               AND rec_fetch_stg_rec.entered_dr IS NULL
            THEN
                ln_record_error_flag   := 1;
                log_records (gc_debug_flag,
                             'Both entered CR and entered DR are null');
                lc_phase               :=
                    'Both entered CR and entered DR are null';
                ln_flag                := ln_flag + 1;
                lc_error_message       :=
                       lc_error_message
                    || TO_CHAR (ln_flag)
                    || '. '
                    || lc_phase
                    || ' ';
                xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                           lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                          --    SYSDATE,
                                                                                                                                                          gn_user_id, gn_conc_request_id, 'entered CR and entered DR ', NULL
                                               , NULL);
            END IF;

            /*  IF rec_fetch_stg_rec.functional_currency_code = rec_fetch_stg_rec.currency_code
               THEN

                  SELECT SUM (c_entered_cr), SUM (c_entered_dr), SUM (entered_cr),
                      SUM (entered_dr)
                      INTO ln_nec_entered_cr  ,ln_nec_entered_dr , ln_neentered_dr  , ln_neentered_cr
                      FROM xxd_gl_balances_inface_stg_t
                      WHERE functional_currency_code != currency_code
                      AND code_combination_id = rec_fetch_stg_rec.code_combination_id;
                rec_fetch_stg_rec.entered_dr :=  rec_fetch_stg_rec.entered_dr - ln_nec_entered_dr;
                rec_fetch_stg_rec.entered_cr :=  rec_fetch_stg_rec.entered_cr - ln_nec_entered_cr;
               END IF;
              */

            ----------------------------------------------------------
            --Fetch the code combination id from gl_code_combinations
            ---------------------------------------------------------
            lc_concat_code         := rec_fetch_stg_rec.concatenated_segments;

            -- lc_concat_code_s := replace(lc_concat_code,'.','-');
            IF lc_concat_code IS NOT NULL
            THEN
                SELECT SUBSTR (lc_concat_code,
                               1,
                                 INSTR (lc_concat_code, '.', 1,
                                        1)
                               - 1),
                       SUBSTR (lc_concat_code,
                                 INSTR (lc_concat_code, '.', 1,
                                        1)
                               + 1,
                               (  INSTR (lc_concat_code, '.', 1,
                                         2)
                                - INSTR (lc_concat_code, '.', 1,
                                         1)
                                - 1)),
                       SUBSTR (lc_concat_code,
                                 INSTR (lc_concat_code, '.', 1,
                                        2)
                               + 1,
                               (  INSTR (lc_concat_code, '.', 1,
                                         3)
                                - INSTR (lc_concat_code, '.', 1,
                                         2)
                                - 1)),
                       SUBSTR (lc_concat_code,
                                 INSTR (lc_concat_code,
                                        '.',
                                          INSTR (lc_concat_code, '.', 1,
                                                 1)
                                        + 1,
                                        2)
                               + 1)
                  INTO rec_fetch_stg_rec.segment1, rec_fetch_stg_rec.segment2, rec_fetch_stg_rec.segment3, rec_fetch_stg_rec.segment4
                  FROM DUAL;
            END IF;

            ---------------------------------------------------------------------------------
            --If the code combination does not exist in the system,validate individual segment
            --values before creating the code combination
            --If the Segment value was not valid then the record is errored out
            -----------------------------------------------------------------------------------
            log_records (gc_debug_flag, ' issue here 2  ');
            log_records (gc_debug_flag, ' issue here 2  ');

            IF lc_concat_code IS NOT NULL                          -- != '---'
            THEN
                BEGIN
                    lc_new_conc_segs   :=
                        xxd_common_utils.get_gl_code_combination (
                            rec_fetch_stg_rec.segment1,
                            rec_fetch_stg_rec.segment2,
                            rec_fetch_stg_rec.segment3,
                            rec_fetch_stg_rec.segment4);
                    log_records (gc_debug_flag,
                                 'new segment val' || lc_new_conc_segs);
                    --faraz
                    lc_new_conc_segs   :=
                        REPLACE (lc_new_conc_segs, '.', '-');

                    IF lc_new_conc_segs IS NOT NULL
                    THEN
                        SELECT SUBSTR (lc_new_conc_segs,
                                       0,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 1)
                                       - 1) seg1,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 1)
                                       + 1,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 2)
                                       - REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 1)
                                       - 1) seg2,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 2)
                                       + 1,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 3)
                                       - REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 2)
                                       - 1) seg3,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 3)
                                       + 1,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 4)
                                       - REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 3)
                                       - 1) seg4,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 4)
                                       + 1,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 5)
                                       - REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 4)
                                       - 1) seg5,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 5)
                                       + 1,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 6)
                                       - REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 5)
                                       - 1) seg6,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 6)
                                       + 1,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 7)
                                       - REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 6)
                                       - 1) seg7,
                               SUBSTR (lc_new_conc_segs,
                                         REGEXP_INSTR (lc_new_conc_segs, '-', 1
                                                       , 7)
                                       + 1) seg8
                          INTO lc_seg1, lc_seg2, lc_seg3, lc_seg4,
                                      lc_seg5, lc_seg6, lc_seg7,
                                      lc_seg8
                          FROM DUAL;
                    ELSE
                        ln_record_error_flag   := 1;
                        log_records (gc_debug_flag,
                                     'lc_conc_segs is invalid');
                        lc_phase               := 'lc_conc_segs is invalid';
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        log_records (
                            gc_debug_flag,
                               'Code combinbation does not exist'
                            || lc_new_conc_segs);
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'Segments- CCID', NULL
                                                       , NULL);
                    END IF;
                END;
            END IF;

            --Company IF
            IF     rec_fetch_stg_rec.attribute15 NOT IN (19, 28, 03)
               AND rec_fetch_stg_rec.old_ledger_name !=
                   'Deckers Group Consolidation'
            -- ,16,26
            THEN
                ------------------------------------------------------------
                --Validate Ledger Name
                ------------------------------------------------------------
                log_records (gc_debug_flag, ' here1 ');
                log_records (
                    gc_debug_flag,
                    ' old ledger name ' || rec_fetch_stg_rec.ledger_name);
                gc_ledger_name   := NULL;

                IF     lc_seg1 IS NOT NULL
                   AND rec_fetch_stg_rec.ledger_category_code = 'PRIMARY'
                THEN
                    IF lc_seg1 NOT IN (990, 980)
                    ---                    16,26 marked as Primary in select clause of extract but ALC data is coming   -- 16 -- 110 ---> Deckers US PRIMARY
                    THEN
                        BEGIN
                              SELECT gl.NAME
                                INTO gc_ledger_name
                                FROM gl_ledger_norm_seg_vals glsv, gl_ledgers gl
                               WHERE     gl.ledger_id = glsv.ledger_id
                                     AND gl.ledger_category_code = 'PRIMARY'
                                     --AND gl.NAME != 'Deckers Group Consolidation'
                                     AND glsv.legal_entity_id IS NOT NULL
                                     AND glsv.segment_value = lc_seg1
                            ORDER BY glsv.segment_value;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    gc_debug_flag,
                                       ' ledger '
                                    || rec_fetch_stg_rec.ledger_name
                                    || SQLERRM);
                                ln_record_error_flag   := 1;
                                lc_phase               :=
                                       'Invalid Ledger name1 -  '
                                    || rec_fetch_stg_rec.ledger_name;
                                ln_flag                := ln_flag + 1;
                                lc_error_message       :=
                                       TO_CHAR (ln_flag)
                                    || '. '
                                    || lc_phase
                                    || ' ';
                        END;
                    ELSIF lc_seg1 IN (990, 980)
                    THEN
                        BEGIN
                              SELECT gl.NAME
                                INTO gc_ledger_name
                                FROM gl_ledger_norm_seg_vals glsv, gl_ledgers gl
                               WHERE     gl.ledger_id = glsv.ledger_id
                                     AND gl.ledger_category_code = 'PRIMARY'
                                     --AND gl.NAME != 'Deckers Group Consolidation'
                                     --AND glsv.legal_entity_id IS NOT NULL
                                     AND glsv.segment_value = lc_seg1
                            ORDER BY glsv.segment_value;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    gc_debug_flag,
                                       ' ledger '
                                    || rec_fetch_stg_rec.ledger_name
                                    || SQLERRM);
                                ln_record_error_flag   := 1;
                                lc_phase               :=
                                       'Invalid Ledger name1 -  '
                                    || rec_fetch_stg_rec.ledger_name;
                                ln_flag                := ln_flag + 1;
                                lc_error_message       :=
                                       TO_CHAR (ln_flag)
                                    || '. '
                                    || lc_phase
                                    || ' ';
                        END;
                    END IF;

                    BEGIN
                        SELECT gls.ledger_id, gls.chart_of_accounts_id
                          INTO gn_ledger_id, gn_chart_of_accounts_id
                          FROM gl_ledgers gls
                         WHERE gls.NAME = gc_ledger_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_record_error_flag   := 1;
                            log_records (
                                gc_debug_flag,
                                'old Ledger name -  ' || rec_fetch_stg_rec.ledger_name);
                            log_records (
                                gc_debug_flag,
                                'Invalid Ledger name -  ' || gc_ledger_name);
                            lc_phase               :=
                                   'Invalid Ledger name2 -  '
                                || rec_fetch_stg_rec.ledger_name;
                            ln_flag                := ln_flag + 1;
                            lc_error_message       :=
                                   lc_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase
                                || ' ';
                            xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                       lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                      --    SYSDATE,
                                                                                                                                                                      gn_user_id, gn_conc_request_id, 'Ledger Name', NULL
                                                           , NULL);
                    END;
                ELSIF     lc_seg1 IS NOT NULL
                      AND rec_fetch_stg_rec.ledger_category_code = 'ALC'
                THEN
                    BEGIN
                        SELECT new_ledger
                          INTO gc_ledger_name
                          FROM xx_reporting
                         WHERE old_ledger_id =
                               rec_fetch_stg_rec.old_ledger_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_record_error_flag   := 1;
                            log_records (
                                gc_debug_flag,
                                'old_ledger_id -  ' || rec_fetch_stg_rec.old_ledger_id);
                            log_records (
                                gc_debug_flag,
                                   'Invalid Ledger name -  '
                                || rec_fetch_stg_rec.old_ledger_id);
                            lc_phase               :=
                                   'Invalid Ledger name2 -  '
                                || rec_fetch_stg_rec.old_ledger_id;
                            ln_flag                := ln_flag + 1;
                            lc_error_message       :=
                                   lc_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase
                                || ' ';
                            xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                       lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                      --    SYSDATE,
                                                                                                                                                                      gn_user_id, gn_conc_request_id, 'Ledger Name', NULL
                                                           , NULL);
                    END;
                ELSE
                    lc_phase   := 'Invalid segment value' || lc_seg1;
                    lc_error_message   :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                END IF;

                -- added for functional currency to be got from 12.2.3 instance
                BEGIN
                    SELECT ledger_id, currency_code
                      INTO gn_ledger_id, fn_currency_code
                      FROM gl_ledgers
                     WHERE NAME = gc_ledger_name;    --'Deckers China Primary'
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_record_error_flag   := 1;
                        log_records (gc_debug_flag,
                                     'functional currency -  ');
                        log_records (
                            gc_debug_flag,
                               'Invalid currency for Ledger  -  '
                            || gc_ledger_name);
                        lc_phase               :=
                               'Invalid currency for ledger -  '
                            || gc_ledger_name;
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'FN CURRENCY', NULL
                                                       , NULL);
                END;

                rec_fetch_stg_rec.functional_currency_code   :=
                    fn_currency_code;

                IF rec_fetch_stg_rec.functional_currency_code =
                   rec_fetch_stg_rec.currency_code
                THEN
                    rec_fetch_stg_rec.entered_dr     :=
                        rec_fetch_stg_rec.c_entered_dr;
                    rec_fetch_stg_rec.entered_cr     :=
                        rec_fetch_stg_rec.c_entered_cr;
                    rec_fetch_stg_rec.accounted_dr   := NULL;
                    rec_fetch_stg_rec.accounted_cr   := NULL;
                ELSE
                    rec_fetch_stg_rec.entered_dr   :=
                        rec_fetch_stg_rec.entered_dr;
                    rec_fetch_stg_rec.entered_cr   :=
                        rec_fetch_stg_rec.entered_cr;
                    rec_fetch_stg_rec.accounted_dr   :=
                        rec_fetch_stg_rec.c_entered_dr;
                    rec_fetch_stg_rec.accounted_cr   :=
                        rec_fetch_stg_rec.c_entered_cr;
                    log_records ('Y', 'currency equal' || gc_ledger_name);
                END IF;
            --Company elsif
            ELSIF     rec_fetch_stg_rec.attribute15 IN (19, 28, 03)
                  AND rec_fetch_stg_rec.ledger_category_code = 'ALC'
                  AND rec_fetch_stg_rec.old_ledger_name !=
                      'Deckers Group Consolidation'
            -- In  extract Primary data but column hardcoded to ALC is select  -- data==>Pri -->Rep
            THEN
                IF lc_seg1 IS NOT NULL
                THEN
                    IF rec_fetch_stg_rec.attribute15 = 19
                    THEN
                        gc_ledger_name   := 'Deckers China Reporting';
                    ELSIF rec_fetch_stg_rec.attribute15 = 28
                    THEN
                        gc_ledger_name   := 'Deckers Canada Reporting';
                    ELSIF rec_fetch_stg_rec.attribute15 = 03
                    THEN
                        gc_ledger_name   := 'Deckers Hong Kong Reporting';
                    END IF;

                    BEGIN
                        SELECT gls.ledger_id, gls.chart_of_accounts_id
                          INTO gn_ledger_id, gn_chart_of_accounts_id
                          FROM gl_ledgers gls
                         WHERE gls.NAME = gc_ledger_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_record_error_flag   := 1;
                            log_records (
                                gc_debug_flag,
                                'old Ledger name -  ' || rec_fetch_stg_rec.ledger_name);
                            log_records (
                                gc_debug_flag,
                                'Invalid Ledger name -  ' || gc_ledger_name);
                            lc_phase               :=
                                   'Invalid Ledger name2 -  '
                                || rec_fetch_stg_rec.ledger_name;
                            ln_flag                := ln_flag + 1;
                            lc_error_message       :=
                                   lc_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase
                                || ' ';
                            xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                       lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                      --    SYSDATE,
                                                                                                                                                                      gn_user_id, gn_conc_request_id, 'Ledger Name', NULL
                                                           , NULL);
                    END;
                ELSE
                    lc_phase   := 'Invalid segment value' || lc_seg1;
                    lc_error_message   :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                END IF;

                -- added for functional currency to be got from 12.2.3 instance
                BEGIN
                    SELECT currency_code
                      INTO fn_currency_code
                      FROM gl_ledgers
                     WHERE NAME = gc_ledger_name;    --'Deckers China Primary'
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_record_error_flag   := 1;
                        log_records (gc_debug_flag,
                                     'functional currency -  ');
                        log_records (
                            gc_debug_flag,
                               'Invalid currency for Ledger  -  '
                            || gc_ledger_name);
                        lc_phase               :=
                               'Invalid currency for ledger -  '
                            || gc_ledger_name;
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'FN CURRENCY', NULL
                                                       , NULL);
                END;

                rec_fetch_stg_rec.functional_currency_code   :=
                    fn_currency_code;

                IF rec_fetch_stg_rec.functional_currency_code =
                   rec_fetch_stg_rec.currency_code
                THEN
                    rec_fetch_stg_rec.entered_dr     :=
                        rec_fetch_stg_rec.c_entered_dr;
                    rec_fetch_stg_rec.entered_cr     :=
                        rec_fetch_stg_rec.c_entered_cr;
                    rec_fetch_stg_rec.accounted_dr   := NULL;
                    rec_fetch_stg_rec.accounted_cr   := NULL;
                ELSE
                    rec_fetch_stg_rec.entered_dr   :=
                        rec_fetch_stg_rec.entered_dr;
                    rec_fetch_stg_rec.entered_cr   :=
                        rec_fetch_stg_rec.entered_cr;
                    rec_fetch_stg_rec.accounted_dr   :=
                        rec_fetch_stg_rec.c_entered_dr;
                    rec_fetch_stg_rec.accounted_cr   :=
                        rec_fetch_stg_rec.c_entered_cr;
                END IF;
            --Company elsif
            ELSIF     rec_fetch_stg_rec.attribute15 IN (19, 28, 03)
                  AND rec_fetch_stg_rec.ledger_category_code != 'ALC'
                  AND rec_fetch_stg_rec.old_ledger_name !=
                      'Deckers Group Consolidation'
            THEN
                --log_records ('Y',
                --    ' old ledger name ' || rec_fetch_stg_rec.ledger_name
                -- );
                IF     lc_seg1 IS NOT NULL
                   AND rec_fetch_stg_rec.ledger_category_code = 'PRIMARY'
                THEN
                    IF lc_seg1 NOT IN (990, 980)
                    THEN
                        BEGIN
                              SELECT gl.NAME
                                INTO gc_ledger_name
                                FROM gl_ledger_norm_seg_vals glsv, gl_ledgers gl
                               WHERE     gl.ledger_id = glsv.ledger_id
                                     AND gl.ledger_category_code = 'PRIMARY'
                                     --AND gl.NAME != 'Deckers Group Consolidation'
                                     AND glsv.legal_entity_id IS NOT NULL
                                     AND glsv.segment_value = lc_seg1
                            ORDER BY glsv.segment_value;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    gc_debug_flag,
                                       ' ledger '
                                    || rec_fetch_stg_rec.ledger_name
                                    || SQLERRM);
                                ln_record_error_flag   := 1;
                                lc_phase               :=
                                       'Invalid Ledger name1 -  '
                                    || rec_fetch_stg_rec.ledger_name;
                                ln_flag                := ln_flag + 1;
                                lc_error_message       :=
                                       TO_CHAR (ln_flag)
                                    || '. '
                                    || lc_phase
                                    || ' ';
                        END;
                    ELSIF lc_seg1 IN (990, 980)
                    THEN
                        BEGIN
                              SELECT gl.NAME
                                INTO gc_ledger_name
                                FROM gl_ledger_norm_seg_vals glsv, gl_ledgers gl
                               WHERE     gl.ledger_id = glsv.ledger_id
                                     AND gl.ledger_category_code = 'PRIMARY'
                                     --AND gl.NAME != 'Deckers Group Consolidation'
                                     --AND glsv.legal_entity_id IS NOT NULL
                                     AND glsv.segment_value = lc_seg1
                            ORDER BY glsv.segment_value;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                log_records (
                                    gc_debug_flag,
                                       ' ledger '
                                    || rec_fetch_stg_rec.ledger_name
                                    || SQLERRM);
                                ln_record_error_flag   := 1;
                                lc_phase               :=
                                       'Invalid Ledger name1 -  '
                                    || rec_fetch_stg_rec.ledger_name;
                                ln_flag                := ln_flag + 1;
                                lc_error_message       :=
                                       TO_CHAR (ln_flag)
                                    || '. '
                                    || lc_phase
                                    || ' ';
                        END;
                    END IF;

                    BEGIN
                        SELECT gls.ledger_id, gls.chart_of_accounts_id
                          INTO gn_ledger_id, gn_chart_of_accounts_id
                          FROM gl_ledgers gls
                         WHERE gls.NAME = gc_ledger_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_record_error_flag   := 1;
                            log_records (
                                gc_debug_flag,
                                'old Ledger name -  ' || rec_fetch_stg_rec.ledger_name);
                            log_records (
                                gc_debug_flag,
                                'Invalid Ledger name -  ' || gc_ledger_name);
                            lc_phase               :=
                                   'Invalid Ledger name2 -  '
                                || rec_fetch_stg_rec.ledger_name;
                            ln_flag                := ln_flag + 1;
                            lc_error_message       :=
                                   lc_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase
                                || ' ';
                            xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                       lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                      --    SYSDATE,
                                                                                                                                                                      gn_user_id, gn_conc_request_id, 'Ledger Name', NULL
                                                           , NULL);
                    END;
                ELSE
                    lc_phase   := 'Invalid segment value' || lc_seg1;
                    lc_error_message   :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                END IF;

                -- added for functional currency to be got from 12.2.3 instance
                BEGIN
                    SELECT currency_code
                      INTO fn_currency_code
                      FROM gl_ledgers
                     WHERE NAME = gc_ledger_name;    --'Deckers China Primary'
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_record_error_flag   := 1;
                        log_records (gc_debug_flag,
                                     'functional currency -  ');
                        log_records (
                            gc_debug_flag,
                               'Invalid currency for Ledger  -  '
                            || gc_ledger_name);
                        lc_phase               :=
                               'Invalid currency for ledger -  '
                            || gc_ledger_name;
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'FN CURRENCY', NULL
                                                       , NULL);
                END;

                rec_fetch_stg_rec.functional_currency_code   :=
                    fn_currency_code;

                IF     rec_fetch_stg_rec.currency_code !=
                       rec_fetch_stg_rec.functional_currency_code
                   AND rec_fetch_stg_rec.currency_code != 'STAT'
                THEN
                    log_records (
                        gc_debug_flag,
                           rec_fetch_stg_rec.currency_code
                        || rec_fetch_stg_rec.functional_currency_code
                        || gc_ledger_name);


                    IF    lc_seg6 LIKE '1%'
                       OR lc_seg6 LIKE '2%'
                       OR lc_seg6 LIKE '3%'
                    THEN
                        BEGIN
                            SELECT conversion_rate, conversion_date, conversion_type
                              INTO ln_cnv_rate, ld_cnv_rdate, lc_cur_conv_type
                              FROM gl_daily_rates
                             WHERE     from_currency =
                                       rec_fetch_stg_rec.currency_code
                                   AND to_currency =
                                       rec_fetch_stg_rec.functional_currency_code
                                   AND conversion_type = 'Spot'
                                   AND conversion_date LIKE
                                           rec_fetch_stg_rec.accounting_date
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_record_error_flag   := 1;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception while Currency Rate Conversion');
                                lc_phase               :=
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception while Currency Rate Conversion';
                                ln_flag                := ln_flag + 1;
                                lc_error_message       :=
                                       lc_error_message
                                    || TO_CHAR (ln_flag)
                                    || '. '
                                    || lc_phase
                                    || ' ';
                                xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                           lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                          --    SYSDATE,
                                                                                                                                                                          gn_user_id, gn_conc_request_id, 'Currency Rate', NULL
                                                               , NULL);
                        END;
                    ELSIF     lc_seg6 NOT LIKE '1%'
                          AND lc_seg6 NOT LIKE '2%'
                          AND lc_seg6 NOT LIKE '3%'
                    THEN
                        /*log_records ('Y',
                                  'Conversion Rate Corp'||ln_cnv_rate
                                 );*/
                        BEGIN
                            SELECT conversion_rate, conversion_date, conversion_type
                              INTO ln_cnv_rate, ld_cnv_rdate, lc_cur_conv_type
                              FROM gl_daily_rates
                             WHERE     from_currency =
                                       rec_fetch_stg_rec.currency_code
                                   AND to_currency =
                                       rec_fetch_stg_rec.functional_currency_code
                                   AND conversion_type = 'Corporate'
                                   AND conversion_date LIKE
                                           rec_fetch_stg_rec.accounting_date
                                   AND ROWNUM = 1;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_record_error_flag   := 1;
                                log_records (
                                    gc_debug_flag,
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception while Currency Rate Conversion');
                                lc_phase               :=
                                       SUBSTR (SQLERRM, 1, 150)
                                    || ' Exception while Currency Rate Conversion';
                                ln_flag                := ln_flag + 1;
                                lc_error_message       :=
                                       lc_error_message
                                    || TO_CHAR (ln_flag)
                                    || '. '
                                    || lc_phase
                                    || ' ';
                                xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                           lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                          --    SYSDATE,
                                                                                                                                                                          gn_user_id, gn_conc_request_id, 'Currency Rate', NULL
                                                               , NULL);
                        END;
                    END IF;                                      -- Account if
                /*   ELSE
                    rec_fetch_stg_rec.accounted_dr := NULL;
                     rec_fetch_stg_rec.accounted_cr := NULL;*/
                END IF;                               -- comparing currency if

                /*log_records ('Y',
                         'Conversion Rate'||ln_cnv_rate
                        );
   */
                IF ln_cnv_rate != 0
                THEN
                    rec_fetch_stg_rec.accounted_dr   :=
                        rec_fetch_stg_rec.entered_dr * ln_cnv_rate;
                    rec_fetch_stg_rec.accounted_cr   :=
                        rec_fetch_stg_rec.entered_cr * ln_cnv_rate;
                END IF;

                rec_fetch_stg_rec.currency_conversion_rate   := ln_cnv_rate;
                rec_fetch_stg_rec.user_currency_conversion_type   :=
                    lc_cur_conv_type;
                rec_fetch_stg_rec.currency_conversion_date   :=
                    ld_cnv_rdate;
            --- Consolidate ledger
            ELSIF             --rec_fetch_stg_rec.attribute15 IN (99, 98)  and
                  rec_fetch_stg_rec.old_ledger_name =
                  'Deckers Group Consolidation'
            THEN
                ------------------------------------------------------------
                --Validate Ledger Name
                ------------------------------------------------------------
                log_records (gc_debug_flag, ' here1 ');
                log_records (
                    gc_debug_flag,
                    ' old ledger name ' || rec_fetch_stg_rec.ledger_name);
                gc_ledger_name   := NULL;

                IF     lc_seg1 IS NOT NULL
                   AND rec_fetch_stg_rec.ledger_category_code = 'PRIMARY'
                THEN
                    gc_ledger_name   := 'Deckers Group Consolidation';

                    BEGIN
                        SELECT gls.ledger_id, gls.chart_of_accounts_id
                          INTO gn_ledger_id, gn_chart_of_accounts_id
                          FROM gl_ledgers gls
                         WHERE gls.NAME = gc_ledger_name;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_record_error_flag   := 1;
                            log_records (
                                gc_debug_flag,
                                'old Ledger name -  ' || rec_fetch_stg_rec.ledger_name);
                            log_records (
                                gc_debug_flag,
                                'Invalid Ledger name -  ' || gc_ledger_name);
                            lc_phase               :=
                                   'Invalid Ledger name2 -  '
                                || rec_fetch_stg_rec.ledger_name;
                            ln_flag                := ln_flag + 1;
                            lc_error_message       :=
                                   lc_error_message
                                || TO_CHAR (ln_flag)
                                || '. '
                                || lc_phase
                                || ' ';
                            xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                       lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                      --    SYSDATE,
                                                                                                                                                                      gn_user_id, gn_conc_request_id, 'Ledger Name', NULL
                                                           , NULL);
                    END;
                ELSE
                    lc_phase   := 'Invalid segment value' || lc_seg1;
                    lc_error_message   :=
                           lc_error_message
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                END IF;

                -- added for functional currency to be got from 12.2.3 instance
                BEGIN
                    SELECT currency_code
                      INTO fn_currency_code
                      FROM gl_ledgers
                     WHERE NAME = gc_ledger_name;    --'Deckers China Primary'
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_record_error_flag   := 1;
                        log_records (gc_debug_flag,
                                     'functional currency -  ');
                        log_records (
                            gc_debug_flag,
                               'Invalid currency for Ledger  -  '
                            || gc_ledger_name);
                        lc_phase               :=
                               'Invalid currency for ledger -  '
                            || gc_ledger_name;
                        ln_flag                := ln_flag + 1;
                        lc_error_message       :=
                               lc_error_message
                            || TO_CHAR (ln_flag)
                            || '. '
                            || lc_phase
                            || ' ';
                        xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                                   lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                                  --    SYSDATE,
                                                                                                                                                                  gn_user_id, gn_conc_request_id, 'FN CURRENCY', NULL
                                                       , NULL);
                END;

                rec_fetch_stg_rec.functional_currency_code   :=
                    fn_currency_code;

                IF rec_fetch_stg_rec.functional_currency_code =
                   rec_fetch_stg_rec.currency_code
                THEN
                    rec_fetch_stg_rec.entered_dr     :=
                        rec_fetch_stg_rec.c_entered_dr;
                    rec_fetch_stg_rec.entered_cr     :=
                        rec_fetch_stg_rec.c_entered_cr;
                    rec_fetch_stg_rec.accounted_dr   := NULL;
                    rec_fetch_stg_rec.accounted_cr   := NULL;
                ELSE
                    rec_fetch_stg_rec.entered_dr   :=
                        rec_fetch_stg_rec.entered_dr;
                    rec_fetch_stg_rec.entered_cr   :=
                        rec_fetch_stg_rec.entered_cr;
                    rec_fetch_stg_rec.accounted_dr   :=
                        rec_fetch_stg_rec.c_entered_dr;
                    rec_fetch_stg_rec.accounted_cr   :=
                        rec_fetch_stg_rec.c_entered_cr;
                --log_records('Y','currency equal'||gc_ledger_name);
                END IF;
            END IF;                                     --- main if of company

            --------------------------------------------------
            --Check if accounting date is in an open period
            -------------------------------------------------
            IF rec_fetch_stg_rec.accounting_date IS NOT NULL
            THEN
                IF NOT validate_period (
                           p_posting_date   =>
                               rec_fetch_stg_rec.accounting_date,
                           p_period   => rec_fetch_stg_rec.period_name)
                THEN
                    ln_record_error_flag   := 1;
                    log_records (
                        gc_debug_flag,
                        ' Accounting Date Is not in an open period  ');
                    lc_phase               :=
                        ' Accounting Date Is not in an open period  ';
                    ln_flag                := ln_flag + 1;
                    lc_error_message       :=
                           lc_error_message
                        --SUBSTR(lc_error_message,1,2000)
                        || TO_CHAR (ln_flag)
                        || '. '
                        || lc_phase
                        || ' ';
                    xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                               lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                              --    SYSDATE,
                                                                                                                                                              gn_user_id, gn_conc_request_id, 'Accounting Date', NULL
                                                   , NULL);
                END IF;
            ELSE
                ln_record_error_flag   := 1;
                log_records (gc_debug_flag,
                             ' Accounting Date Is a Mandatory Field  ');
                lc_phase               :=
                    ' Accounting Date Is a Mandatory Field  ';
                ln_flag                := ln_flag + 1;
                lc_error_message       :=
                       lc_error_message
                    || TO_CHAR (ln_flag)
                    || '. '
                    || lc_phase
                    || ' ';
                xxd_common_utils.record_error ('GL', gn_org_id, 'Deckers Gl Balances Conversion Program ', --      SQLCODE,
                                                                                                           lc_phase, DBMS_UTILITY.format_error_backtrace, --   DBMS_UTILITY.format_call_stack,
                                                                                                                                                          --    SYSDATE,
                                                                                                                                                          gn_user_id, gn_conc_request_id, 'Accounting Date', NULL
                                               , NULL);
            END IF;

            --log_records('Y','ledger val'||gc_ledger_name);
            ------------------------------------------------------------
            --Updating staging table with the validation status
            -----------------------------------------------------------
            IF ln_record_error_flag = 1
            THEN
                UPDATE xxd_gl_balances_inface_stg_t
                   SET ledger_id = gn_ledger_id, chart_of_accounts_id = lc_coa_id --gn_chart_of_accounts_id
                                                                                 , record_status = gc_error_status,
                       error_msg = lc_error_message, --code_combination_id = ln_ccid,
                                                     ledger_name = gc_ledger_name, attribute1 = rec_fetch_stg_rec.ledger_name,
                       segment1 = lc_seg1, segment2 = lc_seg2, segment3 = lc_seg3,
                       segment4 = lc_seg4, segment5 = lc_seg5, segment6 = lc_seg6,
                       segment7 = lc_seg7, segment8 = lc_seg8, accounted_cr = rec_fetch_stg_rec.accounted_cr,
                       accounted_dr = rec_fetch_stg_rec.accounted_dr, entered_dr = rec_fetch_stg_rec.entered_dr, entered_cr = rec_fetch_stg_rec.entered_cr,
                       reference1 = rec_fetch_stg_rec.reference1, currency_conversion_rate = rec_fetch_stg_rec.currency_conversion_rate, user_currency_conversion_type = rec_fetch_stg_rec.user_currency_conversion_type,
                       currency_conversion_date = rec_fetch_stg_rec.currency_conversion_date, functional_currency_code = rec_fetch_stg_rec.functional_currency_code
                 WHERE record_id = rec_fetch_stg_rec.record_id;

                ln_err_cnt   := ln_err_cnt + 1;
            ELSE
                UPDATE xxd_gl_balances_inface_stg_t
                   SET ledger_id = gn_ledger_id, chart_of_accounts_id = lc_coa_id --gn_chart_of_accounts_id
                                                                                 , record_status = gc_validate_status--     ,set_of_books_id        =gn_ledger_id
                                                                                                                     ,
                       --code_combination_id = ln_ccid,
                       ledger_name = gc_ledger_name, segment1 = lc_seg1, segment2 = lc_seg2,
                       segment3 = lc_seg3, segment4 = lc_seg4, segment5 = lc_seg5,
                       segment6 = lc_seg6, segment7 = lc_seg7, segment8 = lc_seg8,
                       accounted_cr = rec_fetch_stg_rec.accounted_cr, accounted_dr = rec_fetch_stg_rec.accounted_dr, entered_dr = rec_fetch_stg_rec.entered_dr,
                       entered_cr = rec_fetch_stg_rec.entered_cr, reference1 = rec_fetch_stg_rec.reference1, currency_conversion_rate = rec_fetch_stg_rec.currency_conversion_rate,
                       user_currency_conversion_type = rec_fetch_stg_rec.user_currency_conversion_type, currency_conversion_date = rec_fetch_stg_rec.currency_conversion_date, functional_currency_code = rec_fetch_stg_rec.functional_currency_code
                 -- functional currency based on new ledger
                 /*               ,segment6               =gc_Segment6
                                ,segment7               =gc_Segment7
                                ,segment8               =gc_Segment8*/
                 WHERE record_id = rec_fetch_stg_rec.record_id;
            --  x_valid_cnt:=x_valid_cnt+1;
            END IF;                                   --ln_record_error_flag=1

            COMMIT;
        END LOOP;

        IF ln_err_cnt > 0
        THEN
            x_ret_code   := gn_warn_const;
        END IF;
    EXCEPTION
        WHEN ex_date_exc
        THEN
            x_errbuf     := SQLERRM;
            x_ret_code   := 1;
            log_records (gc_debug_flag,
                         SUBSTR (SQLERRM, 1, 250) || 'Period is not Open');
        WHEN ex_sum_invalid
        THEN
            log_records (gc_debug_flag,
                         SUBSTR (SQLERRM, 1, 250) || ' Sum mismatch');
        WHEN OTHERS
        THEN
            IF c_fetch_stg_rec%ISOPEN
            THEN
                CLOSE c_fetch_stg_rec;
            END IF;

            x_ret_code   := gn_err_const;
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in validate_records procedure');
    END validate_records;

    PROCEDURE transfer_records (p_batch_id IN NUMBER, p_period IN VARCHAR2, x_ret_code OUT VARCHAR2, x_errbuf OUT VARCHAR2, p_group_id IN NUMBER, p_parent_request_id IN NUMBER
                                , p_ledger_name IN VARCHAR2)
    /**********************************************************************************************
    *                                                                                             *
    * Procedure Name       :  transfer_records                                                    *
    *                                                                                             *
    * Description          :  This procedure will populate the gl_interface program               *
    *                                                                                             *
    *                                                                                             *
    * Change History                                                                              *
    * -----------------                                                                           *
    * Version       Date            Author                 Description                            *
    * -------       ----------      -----------------      ---------------------------            *
    * Draft1a      24-Apr-2015    BT Technology Team      Initial creation                          *
    *                                                                                             *
    **********************************************************************************************/
    IS
        TYPE type_gl_val_t IS TABLE OF gl_interface%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_gl_val_type         type_gl_val_t;
        ln_valid_rec_cnt       NUMBER := 0;
        ln_count               NUMBER := 0;
        ln_int_run_id          NUMBER;
        l_bulk_errors          NUMBER := 0;
        ex_bulk_exceptions     EXCEPTION;
        PRAGMA EXCEPTION_INIT (ex_bulk_exceptions, -24381);
        ex_program_exception   EXCEPTION;
        lc_start_date          VARCHAR2 (15);
        lc_end_date            VARCHAR2 (15);
        l_chk_cnt              NUMBER := 0;
        ln_parent_request_id   NUMBER;

        --------------------------------------------------------
        --Cursor to fetch the valid records from staging table
        ----------------------------------------------------------
        CURSOR c_get_valid_rec (cp_period        VARCHAR2,
                                cp_batch_id      NUMBER,
                                cp_ledger_name   VARCHAR2)
        IS
            SELECT xgpi.*
              FROM xxd_gl_balances_inface_stg_t xgpi
             WHERE     xgpi.record_status = gc_validate_status
                   AND xgpi.period_name = cp_period
                   AND xgpi.batch_id = cp_batch_id;
    BEGIN
        x_ret_code   := gn_suc_const;
        log_records (gc_debug_flag, 'Start of transfer_records procedure');
        SAVEPOINT insert_table;
        lt_gl_val_type.DELETE;
        log_records (gc_debug_flag, p_period);
        log_records (gc_debug_flag, 'before inserting in interface table ');

        FOR rec_get_valid_rec
            IN c_get_valid_rec (p_period, p_batch_id, p_ledger_name)
        LOOP
            ln_count                                                  := ln_count + 1;
            ln_valid_rec_cnt                                          := c_get_valid_rec%ROWCOUNT;
            --
            log_records (gc_debug_flag, 'Row count :' || ln_valid_rec_cnt);
            lt_gl_val_type (ln_valid_rec_cnt).status                  := gc_new_status;
            lt_gl_val_type (ln_valid_rec_cnt).ledger_id               :=
                rec_get_valid_rec.ledger_id;
            lt_gl_val_type (ln_valid_rec_cnt).accounting_date         :=
                rec_get_valid_rec.accounting_date;
            -- TO_DATE (sysdate-701, 'DD-MON-YY');
            -- TO_DATE(rec_get_valid_rec.accounting_date,'DD-MON-YY');
            lt_gl_val_type (ln_valid_rec_cnt).currency_code           :=
                rec_get_valid_rec.currency_code;
            lt_gl_val_type (ln_valid_rec_cnt).date_created            := gd_date;
            lt_gl_val_type (ln_valid_rec_cnt).created_by              := gn_user_id;
            lt_gl_val_type (ln_valid_rec_cnt).actual_flag             :=
                rec_get_valid_rec.actual_flag;
            lt_gl_val_type (ln_valid_rec_cnt).user_je_category_name   :=
                rec_get_valid_rec.category_name;
            lt_gl_val_type (ln_valid_rec_cnt).user_je_source_name     :=
                rec_get_valid_rec.user_je_source_name;
            lt_gl_val_type (ln_valid_rec_cnt).segment1                :=
                rec_get_valid_rec.segment1;
            lt_gl_val_type (ln_valid_rec_cnt).segment2                :=
                rec_get_valid_rec.segment2;
            lt_gl_val_type (ln_valid_rec_cnt).segment3                :=
                rec_get_valid_rec.segment3;
            lt_gl_val_type (ln_valid_rec_cnt).segment4                :=
                rec_get_valid_rec.segment4;
            lt_gl_val_type (ln_valid_rec_cnt).segment5                :=
                rec_get_valid_rec.segment5;
            lt_gl_val_type (ln_valid_rec_cnt).segment6                :=
                rec_get_valid_rec.segment6;
            lt_gl_val_type (ln_valid_rec_cnt).segment7                :=
                rec_get_valid_rec.segment7;
            lt_gl_val_type (ln_valid_rec_cnt).segment8                :=
                rec_get_valid_rec.segment8;
            --lt_gl_val_type(ln_valid_rec_cnt).transaction_date                  :=  TO_DATE(rec_get_valid_rec.transaction_date,'mm/dd/yyyy');
            lt_gl_val_type (ln_valid_rec_cnt).entered_dr              :=
                rec_get_valid_rec.entered_dr;
            lt_gl_val_type (ln_valid_rec_cnt).entered_cr              :=
                rec_get_valid_rec.entered_cr;
            lt_gl_val_type (ln_valid_rec_cnt).accounted_dr            :=
                rec_get_valid_rec.accounted_dr;
            lt_gl_val_type (ln_valid_rec_cnt).accounted_cr            :=
                rec_get_valid_rec.accounted_cr;
            --   lt_gl_val_type (ln_valid_rec_cnt).code_combination_id :=
            --                                rec_get_valid_rec.code_combination_id;
            lt_gl_val_type (ln_valid_rec_cnt).period_name             :=
                rec_get_valid_rec.period_name;
            lt_gl_val_type (ln_valid_rec_cnt).GROUP_ID                :=
                p_group_id;
            lt_gl_val_type (ln_valid_rec_cnt).reference30             :=
                rec_get_valid_rec.record_id;
            lt_gl_val_type (ln_valid_rec_cnt).reference1              :=
                rec_get_valid_rec.reference1;
            lt_gl_val_type (ln_valid_rec_cnt).set_of_books_id         := -1;
            --  ln_parent_request_id := rec_get_valid_rec.request_id;
            ln_parent_request_id                                      :=
                p_parent_request_id;

            IF rec_get_valid_rec.attribute10 IS NOT NULL
            THEN                              -- for calculated accout journal
                --lt_gl_val_type (ln_valid_rec_cnt).currency_conversion_rate :=1;
                --rec_get_valid_rec.currency_conversion_rate;
                --lt_gl_val_type (ln_valid_rec_cnt).user_currency_conversion_type := 'User';
                -- rec_get_valid_rec.user_currency_conversion_type;
                --lt_gl_val_type (ln_valid_rec_cnt).currency_conversion_date :=
                                        --  rec_get_valid_rec.accounting_date;
-- lt_gl_val_type (ln_valid_rec_cnt).attribute10 :=
                                           --   rec_get_valid_rec.attribute10;
                lt_gl_val_type (ln_valid_rec_cnt).entered_dr   := 0;
                lt_gl_val_type (ln_valid_rec_cnt).entered_cr   := 0;
            END IF;
        END LOOP;

        l_chk_cnt    := lt_gl_val_type.COUNT;
        log_records (gc_debug_flag, l_chk_cnt);

        -------------------------------------------------------------------
        -- do a bulk insert into the gl_interface table for the batch
        ----------------------------------------------------------------
        FORALL ln_cnt IN 1 .. lt_gl_val_type.COUNT SAVE EXCEPTIONS
            INSERT INTO gl_interface
                 VALUES lt_gl_val_type (ln_cnt);

        -------------------------------------------------------------------
        --Update the records that have been transferred to GL_INTERFACE
        --as PROCESSED in staging table
        -------------------------------------------------------------------
        log_records (gc_debug_flag, 'request id' || p_parent_request_id);


        UPDATE xxd_conv.xxd_gl_balances_inface_stg_t xgpi
           SET xgpi.record_status   = 'PROCESSED'
         WHERE     1 = 1              --xgpi.request_id = ln_parent_request_id
               AND xgpi.record_id IN (SELECT DISTINCT reference30
                                        FROM gl_interface
                                       WHERE status = 'NEW');

        -- WHERE record_id = rec_fetch_stg_rec.record_id;
        log_records (gc_debug_flag, 'request id' || p_parent_request_id);
        COMMIT;
    --x_rec_count := ln_valid_rec_cnt;
    EXCEPTION
        WHEN ex_program_exception
        THEN
            ROLLBACK TO insert_table;
            x_ret_code   := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
        WHEN ex_bulk_exceptions
        THEN
            ROLLBACK TO insert_table;
            l_bulk_errors   := SQL%BULK_EXCEPTIONS.COUNT;
            x_ret_code      := gn_err_const;

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;

            FOR l_errcnt IN 1 .. l_bulk_errors
            LOOP
                log_records (
                    gc_debug_flag,
                       SQLERRM (-SQL%BULK_EXCEPTIONS (l_errcnt).ERROR_CODE)
                    || ' Exception in transfer_records procedure ');
            END LOOP;
        WHEN OTHERS
        THEN
            ROLLBACK TO insert_table;
            log_records (
                gc_debug_flag,
                   SUBSTR (SQLERRM, 1, 250)
                || ' Exception in transfer_records procedure');

            IF c_get_valid_rec%ISOPEN
            THEN
                CLOSE c_get_valid_rec;
            END IF;
    END transfer_records;

    --truncte_stage_tables
    PROCEDURE truncte_stage_tables (x_ret_code      OUT VARCHAR2,
                                    x_return_mesg   OUT VARCHAR2)
    AS
        lx_return_mesg   VARCHAR2 (2000);
    BEGIN
        --x_ret_code   := gn_suc_const;
        fnd_file.put_line (
            fnd_file.LOG,
            'Working on truncte_stage_tables to purge the data');

        EXECUTE IMMEDIATE 'truncate table XXD_CONV.XXD_GL_BALANCES_INFACE_STG_T ';

        fnd_file.put_line (fnd_file.LOG, 'Truncate Stage Table Complete');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_err_const;
    --x_errbuf   := SQLERRM;
    --fnd_file.put_line (fnd_file.LOG,'Truncate Stage Table Exception t' || x_errbuf);
    --         xxd_common_utils.record_error
    --                                    ('AR',
    --                                     gn_org_id,
    --                                     'Deckers AR Customer Conversion Program',
    --                                   --  SQLCODE,
    --                                     SQLERRM,
    --                                     DBMS_UTILITY.format_error_backtrace,
    --                                  --   DBMS_UTILITY.format_call_stack,
    --                                  --   SYSDATE,
    --                                    gn_user_id,
    --                                     gn_conc_request_id,
    --                                      'truncte_stage_tables'
    --                                     ,NULL
    --                                     ,x_return_mesg);
    END truncte_stage_tables;

    PROCEDURE extract_1206_data (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_summary_detail IN VARCHAR2
                                 , p_period IN VARCHAR2)
    IS
        procedure_name         CONSTANT VARCHAR2 (30) := 'EXTRACT_R12';
        lv_error_stage                  VARCHAR2 (50) := NULL;
        ln_record_count                 NUMBER := 0;
        ln_target_org_id                NUMBER := 0;
        ld_start_date                   DATE;
        ld_end_date                     DATE;
        cr                              NUMBER;

        -- lv_string                 LONG;
        -- ln_start_date             VARCHAR2;
        -- ln_end_date               VARCHAR2;
        CURSOR lcu_gl_balance_data (cp_period VARCHAR2)
        IS
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, '31-DEC-13' end_date,
                   functional_currency_code, segment1, ledger_category_code,
                   ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) entered_dr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) entered_cr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = 'JAN-14'
                             AND gl.ledger_id = bal.ledger_id
                             AND gl_cc.chart_of_accounts_id = 50181
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             -- AND gl_cc.segment1 IN ('98', '99')
                             --AND gl_cc.segment3 = '11223'
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME = 'Deckers Group Consolidation'
                             AND gl.ledger_category_code != 'SECONDARY'
                             AND bal.template_id IS NULL
                             --    and (bal.period_net_dr_beq - bal.period_net_cr_beq)!=0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, '31-DEC-13' end_date,
                   functional_currency_code, segment1, ledger_category_code,
                   ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) entered_dr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) entered_cr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = 'JAN-14'
                             AND gl.ledger_id = bal.ledger_id
                             AND gl_cc.chart_of_accounts_id = 50181
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl_cc.segment1 NOT IN (01, 02, 11,
                                                        12, 15, 19,
                                                        28, 33, 45,
                                                        48, 10, 06,
                                                        07, 09, 20,
                                                        03)
                             AND gl_cc.segment1 NOT IN (16, 26)
                             -- as only data from rep led goes to primary
                             AND periods.period_set_name = 'Deckers FY Cal'
                             --     AND gl.NAME != 'Deckers Group Consolidation'
                             AND gl.NAME NOT IN
                                     ('Deckers Group Consolidation', 'Deckers Corporate Set of Books')
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code != 'SECONDARY'
                             --    and (bal.begin_balance_dr_beq - bal.begin_balance_cr_beq)!=0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            --  (entered_cr != 0 OR entered_dr != 0);--
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, '31-DEC-13' end_date,
                   functional_currency_code, segment1, ledger_category_code,
                   ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) entered_dr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) entered_cr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = 'JAN-14'
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME = 'Deckers Corporate Set of Books'
                             AND gl_cc.segment1 IN (01, 02, 11,
                                                    12, 15, 19,
                                                    28, 33, 45,
                                                    48, 10, 06,
                                                    07, 09, 20,
                                                    03)
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code != 'SECONDARY'
                             --AND gl.NAME != 'Deckers Group Consolidation'
                             --  and (bal.begin_balance_dr_beq - bal.begin_balance_cr_beq)!=0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, '31-DEC-13' end_date,
                   functional_currency_code, segment1, ledger_category_code,
                   ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) entered_dr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) entered_cr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             gl_cc.segment1, 'PRIMARY' ledger_category_code, gl.ledger_id,
                             gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = 'JAN-14'
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND gl_cc.segment1 IN (16, 26)
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME NOT IN
                                     ('Deckers Group Consolidation', 'Deckers Corporate Set of Books')
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code = 'ALC'
                             -- and (bal.begin_balance_dr_beq - bal.begin_balance_cr_beq)!=0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, '31-DEC-13' end_date,
                   functional_currency_code, segment1, 'ALC' ledger_category_code,
                   ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0))), 0) entered_dr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0)))), 0) entered_cr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             -- 'CNY' functional_currency_code,
                             gl_cc.segment1, periods.period_name, ledger_category_code,
                             gl.ledger_id, gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = 'JAN-14'
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME = 'Deckers Corporate Set of Books'
                             AND gl_cc.segment1 IN (19, 28, 03)
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code != 'SECONDARY'
                             --   and (bal.begin_balance_dr_beq - bal.begin_balance_cr_beq)!=0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, ledger_category_code, gl.ledger_id,
                             gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0;

        CURSOR lcu_gl_balance_data_month (cp_period VARCHAR2)
        IS
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, end_date,
                   period_name, functional_currency_code, segment1,
                   ledger_category_code, ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) entered_cr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) entered_dr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             gl_cc.segment1, periods.period_name, periods.end_date,
                             ledger_category_code, gl.ledger_id, gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = cp_period
                             AND gl.ledger_id = bal.ledger_id
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             -- AND gl_cc.segment1 IN ('98', '99')
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME = 'Deckers Group Consolidation'
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code != 'SECONDARY'
                             AND (bal.period_net_dr_beq - bal.period_net_cr_beq) !=
                                 0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, periods.end_date, ledger_category_code,
                             gl.ledger_id, gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, end_date,
                   period_name, functional_currency_code, segment1,
                   ledger_category_code, ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) entered_cr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) entered_dr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             -- 'CNY' functional_currency_code,
                             gl_cc.segment1, periods.period_name, periods.end_date,
                             ledger_category_code, gl.ledger_id, gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = cp_period
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND gl_cc.segment1 NOT IN (01, 02, 11,
                                                        12, 15, 19,
                                                        28, 33, 45,
                                                        48, 10, 06,
                                                        07, 09, 20,
                                                        03)
                             AND gl_cc.segment1 NOT IN (16, 26)
                             -- as only data from rep led goes to primary
                             AND periods.period_set_name = 'Deckers FY Cal'
                             --     AND gl.NAME != 'Deckers Group Consolidation'
                             AND gl.NAME NOT IN
                                     ('Deckers Group Consolidation', 'Deckers Corporate Set of Books')
                             AND bal.template_id IS NULL
                             --  AND bal.currency_code = gl.currency_code
                             --  AND gl_cc.segment1 = '19'
                             AND gl.ledger_category_code != 'SECONDARY'
                             AND (bal.period_net_dr_beq - bal.period_net_cr_beq) !=
                                 0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, periods.end_date, ledger_category_code,
                             gl.ledger_id, gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            --(entered_cr != 0 OR entered_dr != 0)
            -- and code_combination_id=521790
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, end_date,
                   period_name, functional_currency_code, segment1,
                   ledger_category_code, ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) entered_cr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) entered_dr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             -- 'CNY' functional_currency_code,
                             gl_cc.segment1, periods.period_name, periods.end_date,
                             ledger_category_code, gl.ledger_id, gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = cp_period
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME = 'Deckers Corporate Set of Books'
                             AND gl_cc.segment1 IN (01, 02, 11,
                                                    12, 15, 19,
                                                    28, 33, 45,
                                                    48, 10, 06,
                                                    07, 09, 20,
                                                    03)
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code != 'SECONDARY'
                             --AND gl_cc.code_combination_id=3999
                             --and gl.ledger_id =1
                             AND (bal.period_net_dr_beq - bal.period_net_cr_beq) !=
                                 0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, periods.end_date, ledger_category_code,
                             gl.ledger_id, gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, end_date,
                   period_name, functional_currency_code, segment1,
                   ledger_category_code, ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) entered_cr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) entered_dr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             -- 'CNY' functional_currency_code,
                             gl_cc.segment1, periods.period_name, periods.end_date,
                             'PRIMARY' ledger_category_code, gl.ledger_id, gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = cp_period
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND gl_cc.segment1 IN (16, 26)
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME NOT IN
                                     ('Deckers Group Consolidation', 'Deckers Corporate Set of Books')
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code = 'ALC'
                             AND (bal.period_net_dr_beq - bal.period_net_cr_beq) !=
                                 0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, periods.end_date, ledger_category_code,
                             gl.ledger_id, gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            UNION
            SELECT cr, dr, entered_dr,
                   entered_cr, code_combination_id, currency_code,
                   actual_flag, concatenated_segments, end_date,
                   period_name, functional_currency_code, segment1,
                   'ALC' ledger_category_code, ledger_id, NAME
              FROM (  SELECT DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) cr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) dr, DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), -1, -(SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 0) entered_cr,
                             DECODE (SIGN (SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)))), 1, SUM (DECODE (bal.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))), 0) entered_dr, gl_cc.code_combination_id, bal.currency_code,
                             actual_flag, gl_cc.concatenated_segments, gl.currency_code functional_currency_code,
                             -- 'CNY' functional_currency_code,
                             gl_cc.segment1, periods.period_name, periods.end_date,
                             ledger_category_code, gl.ledger_id, gl.NAME
                        FROM gl_balances@bt_read_1206 bal, gl_code_combinations_kfv@bt_read_1206 gl_cc, gl_ledgers@bt_read_1206 gl,
                             gl_ledger_set_assignments@bt_read_1206 asg, gl_periods@bt_read_1206 periods, gl_ledger_relationships@bt_read_1206 lr
                       WHERE     actual_flag = 'A'
                             AND periods.period_name = cp_period
                             AND gl.ledger_id = bal.ledger_id
                             --  AND gl.ledger_id = 1                -- For Corporate USD
                             AND gl_cc.chart_of_accounts_id = 50181
                             -- Not needed to be safe
                             AND periods.period_name = bal.period_name
                             AND gl_cc.code_combination_id =
                                 bal.code_combination_id
                             AND periods.period_set_name = 'Deckers FY Cal'
                             AND gl.NAME = 'Deckers Corporate Set of Books'
                             AND gl_cc.segment1 IN (19, 28, 03)
                             AND bal.template_id IS NULL
                             AND gl.ledger_category_code != 'SECONDARY'
                             --AND gl_cc.code_combination_id=3999
                             --and gl.ledger_id =1
                             AND (bal.period_net_dr_beq - bal.period_net_cr_beq) !=
                                 0
                             AND asg.ledger_set_id(+) = gl.ledger_id
                             AND lr.target_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.source_ledger_id =
                                 NVL (asg.ledger_id, gl.ledger_id)
                             AND lr.target_currency_code = gl.currency_code
                             AND lr.source_ledger_id = bal.ledger_id
                             AND lr.target_ledger_id = bal.ledger_id
                    GROUP BY gl_cc.code_combination_id, gl_cc.concatenated_segments, bal.currency_code,
                             actual_flag, periods.period_name, gl.currency_code,
                             gl_cc.segment1, periods.end_date, ledger_category_code,
                             gl.ledger_id, gl.NAME)
             WHERE dr - cr != 0 OR entered_dr - entered_cr != 0
            ORDER BY segment1;

        TYPE xxd_gl_balances_stg_tab IS TABLE OF lcu_gl_balance_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE xxd_gl_balances_month_stg_tab
            IS TABLE OF lcu_gl_balance_data_month%ROWTYPE
            INDEX BY BINARY_INTEGER;

        ltt_gl_balances_stg_rec         xxd_gl_balances_stg_tab;
        ltt_gl_balances_month_stg_rec   xxd_gl_balances_month_stg_tab;
    BEGIN
        ltt_gl_balances_stg_rec.DELETE;

        IF p_period = 'DEC-13'
        THEN
            log_records (gc_debug_flag, 'entered currency cur');

            -- lc_start_date:=to_char(to_date(fnd_date.canonical_to_date(p_period_start_date)),'MON-YYYY');
            --log_records (gc_debug_flag,'date'||lc_start_date);
            OPEN lcu_gl_balance_data (p_period);

            LOOP
                ltt_gl_balances_stg_rec.DELETE;

                FETCH lcu_gl_balance_data
                    BULK COLLECT INTO ltt_gl_balances_stg_rec
                    LIMIT 1000;

                FORALL i IN 1 .. ltt_gl_balances_stg_rec.COUNT
                    INSERT INTO xxd_gl_balances_inface_stg_t (
                                    entered_cr,
                                    entered_dr,
                                    concatenated_segments,
                                    currency_code,
                                    actual_flag,
                                    category_name,
                                    user_je_source_name,
                                    period_name,
                                    record_status,
                                    accounting_date,
                                    functional_currency_code,
                                    reference1,
                                    segment1,
                                    attribute15,
                                    code_combination_id,
                                    c_entered_cr,
                                    c_entered_dr,
                                    ledger_category_code,
                                    old_ledger_id,
                                    old_ledger_name)
                             VALUES (
                                        ltt_gl_balances_stg_rec (i).entered_cr,
                                        ltt_gl_balances_stg_rec (i).entered_dr,
                                        ltt_gl_balances_stg_rec (i).concatenated_segments,
                                        ltt_gl_balances_stg_rec (i).currency_code,
                                        ltt_gl_balances_stg_rec (i).actual_flag,
                                        'Conversion',
                                        'Conversion',
                                        'DEC-13',
                                        'NEW',
                                        ltt_gl_balances_stg_rec (i).end_date,
                                        ltt_gl_balances_stg_rec (i).functional_currency_code,
                                           ltt_gl_balances_stg_rec (i).segment1
                                        || 'DEC-13'
                                        || ltt_gl_balances_stg_rec (i).currency_code,
                                        ltt_gl_balances_stg_rec (i).segment1,
                                        ltt_gl_balances_stg_rec (i).segment1,
                                        ltt_gl_balances_stg_rec (i).code_combination_id,
                                        ltt_gl_balances_stg_rec (i).cr,
                                        ltt_gl_balances_stg_rec (i).dr,
                                        ltt_gl_balances_stg_rec (i).ledger_category_code,
                                        ltt_gl_balances_stg_rec (i).ledger_id,
                                        ltt_gl_balances_stg_rec (i).NAME);

                --  gtt_gl_balances_stg_rec(i).record_id := XXD_GL_BAL_ID_S.NEXTVAL;
                UPDATE xxd_gl_balances_inface_stg_t
                   SET record_id   = xxd_gl_bal_id_s.NEXTVAL;

                --WHERE je_line_num = gtt_gl_balances_stg_rec(i).je_line_num;
                ltt_gl_balances_stg_rec.DELETE;
                COMMIT;
                EXIT WHEN lcu_gl_balance_data%NOTFOUND;
            END LOOP;

            CLOSE lcu_gl_balance_data;
        ELSE
            log_records (gc_debug_flag, 'entered detail monthly');

            OPEN lcu_gl_balance_data_month (p_period);

            LOOP
                ltt_gl_balances_month_stg_rec.DELETE;

                FETCH lcu_gl_balance_data_month
                    BULK COLLECT INTO ltt_gl_balances_month_stg_rec
                    LIMIT 1000;

                FORALL i IN 1 .. ltt_gl_balances_month_stg_rec.COUNT
                    INSERT INTO xxd_gl_balances_inface_stg_t (
                                    entered_cr,
                                    entered_dr,
                                    concatenated_segments,
                                    currency_code,
                                    actual_flag,
                                    -- ledger_name,
                                    accounting_date,
                                    category_name,
                                    user_je_source_name,
                                    period_name,
                                    record_status,
                                    functional_currency_code,
                                    reference1,
                                    segment1,
                                    attribute15,
                                    code_combination_id,
                                    c_entered_cr,
                                    c_entered_dr,
                                    ledger_category_code,
                                    old_ledger_id,
                                    old_ledger_name)
                             VALUES (
                                        ltt_gl_balances_month_stg_rec (i).entered_cr,
                                        ltt_gl_balances_month_stg_rec (i).entered_dr,
                                        ltt_gl_balances_month_stg_rec (i).concatenated_segments,
                                        ltt_gl_balances_month_stg_rec (i).currency_code,
                                        ltt_gl_balances_month_stg_rec (i).actual_flag,
                                        --  ltt_gl_balances_month_stg_rec (i).ledger_name,
                                        ltt_gl_balances_month_stg_rec (i).end_date,
                                        'Conversion',
                                        'Conversion',
                                        ltt_gl_balances_month_stg_rec (i).period_name,
                                        'NEW',
                                        ltt_gl_balances_month_stg_rec (i).functional_currency_code,
                                           ltt_gl_balances_month_stg_rec (i).segment1
                                        || ltt_gl_balances_month_stg_rec (i).period_name
                                        || ltt_gl_balances_month_stg_rec (i).currency_code,
                                        ltt_gl_balances_month_stg_rec (i).segment1,
                                        ltt_gl_balances_month_stg_rec (i).segment1,
                                        ltt_gl_balances_month_stg_rec (i).code_combination_id,
                                        ltt_gl_balances_month_stg_rec (i).cr,
                                        ltt_gl_balances_month_stg_rec (i).dr,
                                        ltt_gl_balances_month_stg_rec (i).ledger_category_code,
                                        ltt_gl_balances_month_stg_rec (i).ledger_id,
                                        ltt_gl_balances_month_stg_rec (i).NAME);

                UPDATE xxd_gl_balances_inface_stg_t
                   SET record_id   = xxd_gl_bal_id_s.NEXTVAL;

                --WHERE je_line_num = gtt_gl_balances_stg_rec(i).je_line_num;
                ltt_gl_balances_month_stg_rec.DELETE;
                COMMIT;
                EXIT WHEN lcu_gl_balance_data_month%NOTFOUND;
            END LOOP;

            CLOSE lcu_gl_balance_data_month;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Inserting record In '
                || lv_error_stage
                || ' : '
                || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'Exception ' || SQLERRM);
    END extract_1206_data;

    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY NUMBER, p_process_level IN VARCHAR2, p_no_of_process IN VARCHAR2, p_debug_flag IN VARCHAR2, p_summary_detail IN VARCHAR2
                    , p_period IN VARCHAR2, p_ledger_name IN VARCHAR2)
    AS
        ln_parent_request_id   NUMBER := fnd_global.conc_request_id;
        ln_valid_rec_cnt       NUMBER;
        ln_request_id          NUMBER := 0;
        lc_phase               VARCHAR2 (200);
        lc_status              VARCHAR2 (200);
        lc_dev_phase           VARCHAR2 (200);
        lc_dev_status          VARCHAR2 (200);
        lc_message             VARCHAR2 (200);
        ln_ret_code            NUMBER;
        lc_err_buff            VARCHAR2 (1000);
        ln_count               NUMBER;
        ln_cntr                NUMBER := 0;
        lb_wait                BOOLEAN;
        lx_return_mesg         VARCHAR2 (2000);
        ex_invalid_para        EXCEPTION;
        ex_no_records          EXCEPTION;

        TYPE hdr_batch_id_t IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        ln_hdr_batch_id        hdr_batch_id_t;

        TYPE request_table IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_req_id               request_table;
    BEGIN
        gc_debug_flag   := p_debug_flag;
        log_records (gc_debug_flag, 'p_summary_detail' || p_summary_detail);

        IF p_process_level = gc_extract_only
        THEN
            log_records (gc_debug_flag, 'Procedure extract_main');
            truncte_stage_tables (x_ret_code      => x_retcode,
                                  x_return_mesg   => x_errbuf);
            log_records (gc_debug_flag,
                         'Woking on extract the data for the Currency ');
            extract_1206_data (x_errbuf => x_errbuf, x_retcode => x_retcode, p_summary_detail => p_summary_detail
                               , p_period => p_period);
            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                'After the Extraction of data from GL Balances View');
        --Validation Process starts here.

        --Validation Process starts here.
        ELSIF (p_process_level = gc_validate_only)
        THEN
            /*===========================================================================================================

            Added the below mentioned lines for the 'Validate' option

            ==============================================================================================================*/
            fnd_file.put_line (fnd_file.LOG,
                               'Call Procedure create_batch_prc.');

            UPDATE xxd_gl_balances_inface_stg_t
               SET batch_id = NULL, record_status = 'NEW', error_msg = NULL
             WHERE record_status IN ('ERROR', 'NEW', 'VALIDATED');

            COMMIT;

            SELECT COUNT (*)
              INTO ln_valid_rec_cnt
              FROM xxd_gl_balances_inface_stg_t
             WHERE batch_id IS NULL AND record_status = gc_new_status;

            --write_log ('Creating Batch id and update  XXD_AR_CUST_INT_STG_T');
            -- Create batches of records and assign batch id
            IF ln_valid_rec_cnt = 0
            THEN
                -- x_retcode := 1;
                RAISE ex_no_records;
            END IF;

            FOR i IN 1 .. p_no_of_process
            LOOP
                BEGIN
                    SELECT xxd_conv.xxd_gl_balances_inface_stg_seq.NEXTVAL
                      INTO ln_hdr_batch_id (i)
                      FROM DUAL;

                    log_records (
                        gc_debug_flag,
                        'ln_hdr_batch_id(i) := ' || ln_hdr_batch_id (i));
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_hdr_batch_id (i + 1)   := ln_hdr_batch_id (i) + 1;
                END;

                log_records (gc_debug_flag,
                             ' ln_valid_rec_cnt := ' || ln_valid_rec_cnt);
                log_records (
                    gc_debug_flag,
                       'ceil( ln_valid_rec_cnt/p_no_of_process) := '
                    || CEIL (ln_valid_rec_cnt / p_no_of_process));

                UPDATE xxd_gl_balances_inface_stg_t
                   SET batch_id = ln_hdr_batch_id (i), request_id = ln_parent_request_id
                 WHERE     batch_id IS NULL
                       AND ROWNUM <=
                           CEIL (ln_valid_rec_cnt / p_no_of_process)
                       AND record_status = gc_new_status;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_GL_BALANCES_INFACE_STG_T');
        /*===========================================================================================================

       Added the below mentioned lines for the 'load' option

       ==============================================================================================================*/
        ELSIF (p_process_level = gc_load_only)
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Loading Process Initiated');
            fnd_file.put_line (fnd_file.LOG,
                               'Call Procedure min_max_batch_prc');
            log_records (
                gc_debug_flag,
                'Fetching batch id from XXD_GL_BALANCES_INFACE_STG_T stage to call worker process');
            ln_cntr   := 0;

            BEGIN
                SELECT gl_je_batches_s.NEXTVAL INTO gn_group_id FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    log_records (
                        gc_debug_flag,
                           SUBSTR (SQLERRM, 1, 150)
                        || ' Exception fetching group id in transfer_records procedure ');
            -- RAISE ex_program_exception;
            END;

            FOR i
                IN (SELECT DISTINCT batch_id
                      FROM xxd_gl_balances_inface_stg_t
                     WHERE     batch_id IS NOT NULL
                           AND record_status = gc_validate_status)
            LOOP
                ln_cntr                     := ln_cntr + 1;
                ln_hdr_batch_id (ln_cntr)   := i.batch_id;
            END LOOP;

            log_records (
                gc_debug_flag,
                'completed updating Batch id in  XXD_GL_BALANCES_INFACE_STG_T ');
        END IF;

        COMMIT;

        IF ln_hdr_batch_id.COUNT > 0
        THEN
            log_records (
                gc_debug_flag,
                   'Calling XXD_GL_BALANCES_CONV_WRK in batch '
                || ln_hdr_batch_id.COUNT);

            FOR i IN ln_hdr_batch_id.FIRST .. ln_hdr_batch_id.LAST
            LOOP
                SELECT COUNT (*)
                  INTO ln_cntr
                  FROM xxd_gl_balances_inface_stg_t
                 WHERE batch_id = ln_hdr_batch_id (i);

                IF ln_cntr > 0
                THEN
                    BEGIN
                        log_records (
                            gc_debug_flag,
                               'Calling Worker process for batch id ln_hdr_batch_id(i) := '
                            || ln_hdr_batch_id (i));
                        ln_request_id   :=
                            apps.fnd_request.submit_request ('XXDCONV', 'XXD_GL_BALANCES_CONV_WRK', '', '', FALSE, gc_debug_flag, p_process_level, ln_hdr_batch_id (i), ln_parent_request_id, p_summary_detail, p_period, gn_group_id
                                                             , p_ledger_name);
                        log_records (gc_debug_flag,
                                     'v_request_id := ' || ln_request_id);

                        IF ln_request_id > 0
                        THEN
                            l_req_id (i)   := ln_request_id;
                            COMMIT;
                        ELSE
                            ROLLBACK;
                        END IF;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_GL error'
                                || SQLERRM);
                        WHEN OTHERS
                        THEN
                            x_retcode   := 2;
                            x_errbuf    := x_errbuf || SQLERRM;
                            log_records (
                                gc_debug_flag,
                                   'Calling WAIT FOR REQUEST XXD_GL_CHILD_CONV error'
                                || SQLERRM);
                    END;
                END IF;
            END LOOP;

            log_records (gc_debug_flag,
                         'GL in batch ' || ln_hdr_batch_id.COUNT);
            log_records (
                gc_debug_flag,
                'Calling WAIT FOR REQUEST XXD_GL_CHILD_CONV to complete');

            FOR rec IN l_req_id.FIRST .. l_req_id.LAST
            LOOP
                IF l_req_id (rec) > 0
                THEN
                    LOOP
                        lc_dev_phase    := NULL;
                        lc_dev_status   := NULL;
                        lb_wait         :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_req_id (rec)--ln_concurrent_request_id
                                                              ,
                                INTERVAL     => 1,
                                max_wait     => 1,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);

                        IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END LOOP;
        END IF;

        IF p_process_level = gc_validate_only
        THEN
            update_balance_account;
        --log_records('Y','Calling Update');
        END IF;
    EXCEPTION
        WHEN ex_invalid_para
        THEN
            x_errbuf    :=
                'PARAMETRS entered are not as ACCORDING TO REQUIREMENT';
            x_retcode   := 1;
        WHEN ex_no_records
        THEN
            x_errbuf    := 'No records to validate';
            x_retcode   := 1;
        WHEN OTHERS
        THEN
            x_errbuf    := SUBSTR (SQLERRM, 1, 500);
            x_retcode   := 2;
            log_records (gc_debug_flag, 'MAIN EXCEPTION' || SQLERRM);
    END main;

    --XXD_GL_BALANCES_CONV_WRK
    PROCEDURE gl_balance_child (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, p_debug_flag IN VARCHAR2 DEFAULT 'N', p_action IN VARCHAR2, p_batch_id IN NUMBER, p_parent_request_id IN NUMBER, p_summary_detail IN VARCHAR2, p_period IN VARCHAR2, p_group_id IN NUMBER
                                , p_ledger_name IN VARCHAR2)
    AS
        le_invalid_param    EXCEPTION;
        --      ln_new_ou_id                hr_operating_units.organization_id%TYPE;   --:= fnd_profile.value('ORG_ID');
        -- This is required in release 12 R12
        ln_request_id       NUMBER := 0;
        lc_username         fnd_user.user_name%TYPE;
        lc_operating_unit   hr_operating_units.NAME%TYPE;
        lc_cust_num         VARCHAR2 (5);
        lc_pri_flag         VARCHAR2 (1);
        ld_start_date       DATE;
        ln_ins              NUMBER := 0;
        --ln_request_id             NUMBER                     := 0;
        lc_phase            VARCHAR2 (200);
        lc_status           VARCHAR2 (200);
        lc_dev_phase        VARCHAR2 (200);
        lc_dev_status       VARCHAR2 (200);
        lb_wait             BOOLEAN;
        lc_message          VARCHAR2 (200);
        ln_ret_code         NUMBER;
        lc_err_buff         VARCHAR2 (1000);
        ln_count            NUMBER;
        l_target_org_id     NUMBER;
        lc_retcode          NUMBER;
        ln_iface_run_id     NUMBER;
        ln_cnt              NUMBER := 0;
    BEGIN
        gc_debug_flag        := p_debug_flag;

        --      gn_conc_request_id :=  p_parent_request_id;
        --g_err_tbl_type.delete;
        BEGIN
            SELECT user_name
              INTO lc_username
              FROM fnd_user
             WHERE user_id = fnd_global.user_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_username   := NULL;
        END;

        BEGIN
            SELECT NAME
              INTO lc_operating_unit
              FROM hr_operating_units
             WHERE organization_id = fnd_profile.VALUE ('ORG_ID');
        EXCEPTION
            WHEN OTHERS
            THEN
                lc_operating_unit   := NULL;
        END;

        -- Validation Process for Price List Import
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '***************     '
            || lc_operating_unit
            || '***************** ');
        fnd_file.put_line (
            fnd_file.LOG,
            '*************************************************************************** ');
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Busines Unit:'
            || lc_operating_unit);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Run By      :'
            || lc_username);
        --      fnd_file.put_line (fnd_file.LOG, '                                         Run Date    :' || TO_CHAR (gd_sys_date, 'DD-MON-YYYY HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Request ID  :'
            || fnd_global.conc_request_id);
        fnd_file.put_line (
            fnd_file.LOG,
               '                                         Batch ID    :'
            || p_batch_id);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        fnd_file.new_line (fnd_file.LOG, 1);
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        log_records (gc_debug_flag,
                     '******** START of GL Balances Import Program ******');
        log_records (
            gc_debug_flag,
            '+---------------------------------------------------------------------------+');
        gc_debug_flag        := p_debug_flag;
        --gn_org_id        := 0;
        gn_conc_request_id   := p_parent_request_id;

        -- gn_request_id                 := p_parent_request_id;
        --      l_target_org_id := get_targetorg_id(p_org_name => p_org_name);
        --      gn_org_id := NVL(l_target_org_id,gn_org_id);
        IF p_action = gc_validate_only
        THEN
            log_records (gc_debug_flag, 'Calling gl_balances_validation :');
            validate_records (p_batch_id      => p_batch_id,
                              p_debug_flag    => gc_debug_flag,
                              p_ledger_name   => p_ledger_name,
                              x_ret_code      => lc_retcode,
                              x_errbuf        => lc_err_buff);
            log_records (p_debug_flag, 'Return error code :' || lc_retcode);
            log_records (p_debug_flag,
                         'Return error message :' || lc_err_buff);
            retcode   := lc_retcode;
        --   IF ln_cnt = 0
        --update_balance_account;
        --ln_cnt :=1;
        --END IF;
        ELSIF p_action = gc_load_only
        THEN
            log_records (gc_debug_flag, 'B4:');
            transfer_records (p_batch_id => p_batch_id, p_period => p_period, x_ret_code => retcode, x_errbuf => errbuf, p_group_id => p_group_id, p_parent_request_id => gn_conc_request_id
                              , p_ledger_name => p_ledger_name);
            log_records (p_debug_flag, 'Return error code :' || lc_retcode);
            log_records (p_debug_flag,
                         'Return error message :' || lc_err_buff);
            retcode   := lc_retcode;
            log_records (gc_debug_flag, 'After:');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.output,
                               'Exception Raised During GL Balances Program');
            retcode   := 2;
            errbuf    := errbuf || SQLERRM;
    END gl_balance_child;
END xxd_gl_balances_conv_pkg;
/
