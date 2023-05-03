--
-- XXD_GL_FX_ANALYSIS_RPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_FX_ANALYSIS_RPT_PKG"
IS
    gc_default_ledger_id   NUMBER := 2036;
    gc_debug_enable        VARCHAR2 (1) := 'Y';

    PROCEDURE LOG (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    --      PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            IF fnd_global.conc_login_id = -1
            THEN
                DBMS_OUTPUT.put_line (p_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, p_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in log=' || SQLERRM);
    END LOG;

    PROCEDURE PRINT (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    --      PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            IF fnd_global.conc_login_id = -1
            THEN
                DBMS_OUTPUT.put_line (p_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, p_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in log=' || SQLERRM);
    END PRINT;

    FUNCTION get_period_names (pv_FROM_PERIOD   VARCHAR2,
                               pv_to_period     VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR cur_period_names (pv_from_period   VARCHAR2,
                                 pv_to_period     VARCHAR2)
        IS
            SELECT period_name
              FROM gl_periods
             WHERE     1 = 1
                   AND period_set_name = 'DO_FY_CALENDAR'
                   AND start_date >=
                       (SELECT start_date
                          FROM gl_periods
                         WHERE     1 = 1
                               AND period_name = pv_from_period
                               AND period_set_name = 'DO_FY_CALENDAR')
                   AND end_date <=
                       (SELECT end_date
                          FROM gl_periods
                         WHERE     1 = 1
                               AND period_name = pv_to_period
                               AND period_set_name = 'DO_FY_CALENDAR');

        lv_period_names   VARCHAR2 (2000) := '';
        ln_count          NUMBER := 0;
    BEGIN
        SELECT COUNT (period_name)
          INTO ln_count
          FROM gl_periods
         WHERE     1 = 1
               AND period_set_name = 'DO_FY_CALENDAR'
               AND start_date >=
                   (SELECT start_date
                      FROM gl_periods
                     WHERE     1 = 1
                           AND period_name = pv_from_period
                           AND period_set_name = 'DO_FY_CALENDAR')
               AND end_date <=
                   (SELECT end_date
                      FROM gl_periods
                     WHERE     1 = 1
                           AND period_name = pv_to_period
                           AND period_set_name = 'DO_FY_CALENDAR');

        lv_period_names   := ' AND gjh.period_name in (';

        FOR rec_period_names
            IN cur_period_names (pv_from_period, pv_to_period)
        LOOP
            IF ln_count != cur_period_names%ROWCOUNT
            THEN
                lv_period_names   :=
                       --               lv_period_names || '''' || rec_period_names.period_name || ''',';
                       lv_period_names
                    || ''''
                    || rec_period_names.period_name
                    || ''',';
            ELSE
                lv_period_names   :=
                       lv_period_names
                    || ''''
                    || rec_period_names.period_name
                    || ''')';
            END IF;
        END LOOP;

        RETURN lv_period_names;

        DBMS_OUTPUT.put_line ('lv_period_names - ' || lv_period_names);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    PROCEDURE proc_main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pn_ledger_id NUMBER, pv_FROM_PERIOD VARCHAR2, pv_to_period VARCHAR2, pv_source VARCHAR2, pv_category VARCHAR2, pv_rate_type VARCHAR2, pd_rate_from_date VARCHAR2, pd_rate_to_date VARCHAR2, pv_mode VARCHAR2, pv_reval_only VARCHAR2
                         , pv_from_account VARCHAR2, pv_to_account VARCHAR2)
    IS
        ld_rate_from_date   DATE;
        ld_rate_to_date     DATE;



        CURSOR CUR_COMB IS
            SELECT DISTINCT code_combination_id
              FROM gl_je_headers gjh, gl_je_lines gjl, gl_ledgers gll,
                   GL_LEDGER_SET_ASSIGNMENTS ASG, GL_LEDGER_RELATIONSHIPS LR
             WHERE     1 = 1
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.je_source = 'Revaluation'
                   AND gjh.je_category = 'Revaluation'
                   AND GLL.LEDGER_ID = pn_ledger_id
                   AND ASG.LEDGER_SET_ID(+) = GLL.LEDGER_ID
                   AND LR.TARGET_LEDGER_ID =
                       NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                   AND LR.SOURCE_LEDGER_ID =
                       NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                   --                 AND LR.TARGET_CURRENCY_CODE = gll.currency_code
                   AND LR.SOURCE_LEDGER_ID = gjh.LEDGER_ID
                   AND LR.TARGET_LEDGER_ID = gjh.LEDGER_ID
                   AND gjh.status = 'P'
                   AND gjl.code_combination_id IN
                           (SELECT code_combination_id
                              FROM gl_code_combinations gcc
                             WHERE     1 = 1
                                   AND segment6 BETWEEN NVL (pv_from_account,
                                                             gcc.segment6)
                                                    AND NVL (pv_to_account,
                                                             gcc.segment6))
                   AND gjh.period_name IN
                           (SELECT period_name
                              FROM gl.gl_period_statuses
                             WHERE     1 = 1
                                   AND application_id = 101
                                   AND set_of_books_id = gc_default_ledger_id
                                   AND start_date >=
                                       (SELECT start_date
                                          FROM gl_period_statuses
                                         WHERE     1 = 1
                                               AND period_name =
                                                   pv_from_period
                                               AND application_id = 101
                                               AND set_of_books_id =
                                                   gc_default_ledger_id)
                                   AND end_date <=
                                       (SELECT end_date
                                          FROM gl_period_statuses
                                         WHERE     1 = 1
                                               AND period_name = pv_to_period
                                               AND application_id = 101
                                               AND set_of_books_id =
                                                   gc_default_ledger_id));


        CURSOR cur_reval_only (pn_ccid NUMBER)
        IS
              SELECT name, rpt_mode, CCID,
                     ledger_currency_code, Entered_currency, SUM (Total_entered) total_entered,
                     SUM (change_in_fx) change_in_fx, SUM (total_entered * change_in_fx) recalculated_value, SUM (revalue_in_gl) revalue_in_gl,
                     SUM (((total_entered * change_in_fx) - revalue_in_gl)) Difference
                FROM (  SELECT lr.target_ledger_name
                                   name,
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       gcck.concatenated_segments)
                                   rpt_mode,
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       GLB.code_combination_id)
                                   CCID,
                               lr.target_currency_code
                                   ledger_currency_code,
                               GLB.currency_code
                                   Entered_currency,
                               DECODE (
                                   GLB.currency_code,
                                   lr.target_currency_code, (SUM (BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) + SUM (period_net_dr_BEQ - period_net_cr_BEQ)),
                                   (SUM (begin_balance_dr - begin_balance_cr) + SUM (period_net_dr - period_net_cr)))
                                   Total_entered,
                                 apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_to_date
                                                                , pv_rate_type)
                               - apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_from_date
                                                                , pv_rate_type)
                                   Change_in_fx,
                               0
                                   revalue_in_gl
                          FROM gl_balances GLB, gl_code_combinations_kfv gcck, gl_ledgers gll,
                               GL_LEDGER_SET_ASSIGNMENTS ASG, GL_LEDGER_RELATIONSHIPS LR
                         WHERE     1 = 1
                               AND GLB.code_combination_id =
                                   gcck.code_combination_id
                               AND gcck.code_combination_id =
                                   NVL (pn_ccid, gcck.code_combination_id)
                               --                 AND glb.ledger_id = gll.ledger_id
                               AND gcck.SUMMARY_FLAG = 'N'
                               AND gcck.TEMPLATE_ID IS NULL
                               AND gcck.segment6 BETWEEN NVL (pv_from_account,
                                                              gcck.segment6)
                                                     AND NVL (pv_to_account,
                                                              gcck.segment6)
                               AND GLB.period_name = pv_to_period
                               --                 AND GLB.ledger_id = pn_ledger_id
                               AND GLL.LEDGER_ID = pn_ledger_id
                               AND ASG.LEDGER_SET_ID(+) = GLL.LEDGER_ID
                               AND LR.TARGET_LEDGER_ID =
                                   NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                               AND LR.SOURCE_LEDGER_ID =
                                   NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                               --                 AND LR.TARGET_CURRENCY_CODE = gll.currency_code
                               AND LR.SOURCE_LEDGER_ID = GLB.LEDGER_ID
                               AND LR.TARGET_LEDGER_ID = GLB.LEDGER_ID
                      GROUP BY lr.target_ledger_name,
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       gcck.concatenated_segments),
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       GLB.code_combination_id),
                               lr.target_currency_code,
                               --                 gcck..concatenated_segments,
                               GLB.currency_code,
                                 apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_to_date
                                                                , pv_rate_type)
                               - apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_from_date
                                                                , pv_rate_type)
                      UNION ALL
                      (  SELECT lr.target_ledger_name, DECODE (pv_mode, 'SUMMARY', NULL, gcck.concatenated_segments) rpt_mode, DECODE (pv_mode, 'SUMMARY', NULL, gjl.code_combination_id) CCID,
                                lr.target_currency_code ledger_currency_code, gjh.currency_code, 0 total_entered,
                                0 change_in_fx, SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)) revalue_in_gl -- gjh.period_name, XXD_GL_FX_ANALYSIS_RPT_PKG.get_period_names(pv_from_period, pv_to_period)--,
                           FROM gl_je_headers gjh, gl_je_lines gjl, gl_ledgers gll,
                                GL_LEDGER_SET_ASSIGNMENTS ASG, GL_LEDGER_RELATIONSHIPS LR, gl_code_combinations_kfv gcck
                          WHERE     1 = 1
                                AND gjh.je_header_id = gjl.je_header_id
                                AND gjh.ledger_id = gjl.ledger_id
                                AND gjh.period_name = gjl.period_name
                                AND gjh.je_source = pv_source
                                AND ((pv_category IS NOT NULL AND gjh.je_category = pv_category) OR (pv_category IS NULL AND 1 = 1))
                                --                 AND gjh.ledger_id = pn_ledger_id
                                AND GLL.LEDGER_ID = pn_ledger_id
                                AND gjl.code_combination_id =
                                    gcck.code_combination_id
                                AND gcck.code_combination_id =
                                    NVL (pn_ccid, gcck.code_combination_id)
                                --                   AND gll.chart_of_accounts_id = gcck.chart_of_accounts_id
                                AND gcck.SUMMARY_FLAG = 'N'
                                AND gcck.TEMPLATE_ID IS NULL
                                AND gcck.segment6 BETWEEN NVL (pv_from_account,
                                                               gcck.segment6)
                                                      AND NVL (pv_to_account,
                                                               gcck.segment6)
                                AND ASG.LEDGER_SET_ID(+) = GLL.LEDGER_ID
                                AND LR.TARGET_LEDGER_ID =
                                    NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                                AND LR.SOURCE_LEDGER_ID =
                                    NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                                --                 AND LR.TARGET_CURRENCY_CODE = gll.currency_code
                                AND gjh.ledger_id = gll.ledger_id
                                AND LR.SOURCE_LEDGER_ID = gjh.LEDGER_ID
                                AND LR.TARGET_LEDGER_ID = gjh.LEDGER_ID --2036
                                AND gjh.status = 'P'
                                AND gjh.period_name IN
                                        (SELECT period_name
                                           FROM gl.gl_period_statuses
                                          WHERE     1 = 1
                                                AND application_id = 101
                                                AND set_of_books_id =
                                                    gc_default_ledger_id
                                                AND start_date >=
                                                    (SELECT start_date
                                                       FROM gl_period_statuses
                                                      WHERE     1 = 1
                                                            AND period_name =
                                                                pv_from_period
                                                            AND application_id =
                                                                101
                                                            AND set_of_books_id =
                                                                gc_default_ledger_id)
                                                AND end_date <=
                                                    (SELECT end_date
                                                       FROM gl_period_statuses
                                                      WHERE     1 = 1
                                                            AND period_name =
                                                                pv_to_period
                                                            AND application_id =
                                                                101
                                                            AND set_of_books_id =
                                                                gc_default_ledger_id))
                       GROUP BY lr.target_ledger_name, DECODE (pv_mode, 'SUMMARY', NULL, gcck.concatenated_segments), DECODE (pv_mode, 'SUMMARY', NULL, gjl.code_combination_id),
                                gjh.currency_code, lr.target_currency_code))
            GROUP BY name, rpt_mode, CCID,
                     ledger_currency_code, Entered_currency
            ORDER BY 1, 4, 5;



        CURSOR cur_main IS
              SELECT name, rpt_mode, CCID,
                     ledger_currency_code, Entered_currency, SUM (Total_entered) total_entered,
                     SUM (change_in_fx) change_in_fx, SUM (total_entered * change_in_fx) recalculated_value, SUM (revalue_in_gl) revalue_in_gl,
                     SUM (((total_entered * change_in_fx) - revalue_in_gl)) Difference
                FROM (  SELECT lr.target_ledger_name
                                   name,
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       gcck.concatenated_segments)
                                   rpt_mode,
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       GLB.code_combination_id)
                                   CCID,
                               lr.target_currency_code
                                   ledger_currency_code,
                               GLB.currency_code
                                   Entered_currency,
                               DECODE (
                                   GLB.currency_code,
                                   lr.target_currency_code, (SUM (BEGIN_BALANCE_DR_BEQ - BEGIN_BALANCE_CR_BEQ) + SUM (period_net_dr_BEQ - period_net_cr_BEQ)),
                                   (SUM (begin_balance_dr - begin_balance_cr) + SUM (period_net_dr - period_net_cr)))
                                   Total_entered,
                                 apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_to_date
                                                                , pv_rate_type)
                               - apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_from_date
                                                                , pv_rate_type)
                                   Change_in_fx,
                               0
                                   revalue_in_gl
                          FROM gl_balances GLB, gl_code_combinations_kfv gcck, gl_ledgers gll,
                               GL_LEDGER_SET_ASSIGNMENTS ASG, GL_LEDGER_RELATIONSHIPS LR
                         WHERE     1 = 1
                               AND GLB.code_combination_id =
                                   gcck.code_combination_id
                               --                            AND gcck..code_combination_id = pn_ccid
                               --                 AND glb.ledger_id = gll.ledger_id
                               AND gcck.SUMMARY_FLAG = 'N'
                               AND gcck.TEMPLATE_ID IS NULL
                               AND gcck.segment6 BETWEEN NVL (pv_from_account,
                                                              gcck.segment6)
                                                     AND NVL (pv_to_account,
                                                              gcck.segment6)
                               AND GLB.period_name = pv_to_period
                               --                 AND GLB.ledger_id = pn_ledger_id
                               AND GLL.LEDGER_ID = pn_ledger_id
                               AND ASG.LEDGER_SET_ID(+) = GLL.LEDGER_ID
                               AND LR.TARGET_LEDGER_ID =
                                   NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                               AND LR.SOURCE_LEDGER_ID =
                                   NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                               --                 AND LR.TARGET_CURRENCY_CODE = gll.currency_code
                               AND LR.SOURCE_LEDGER_ID = GLB.LEDGER_ID
                               AND LR.TARGET_LEDGER_ID = GLB.LEDGER_ID
                      GROUP BY lr.target_ledger_name,
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       gcck.concatenated_segments),
                               DECODE (pv_mode,
                                       'SUMMARY', NULL,
                                       GLB.code_combination_id),
                               lr.target_currency_code,
                               --                 gcck..concatenated_segments,
                               GLB.currency_code,
                                 apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_to_date
                                                                , pv_rate_type)
                               - apps.gl_currency_api.get_rate (GLB.ledger_id, GLB.currency_code, ld_rate_from_date
                                                                , pv_rate_type)
                      UNION ALL
                      (  SELECT lr.target_ledger_name, DECODE (pv_mode, 'SUMMARY', NULL, gcck.concatenated_segments) rpt_mode, DECODE (pv_mode, 'SUMMARY', NULL, gjl.code_combination_id) CCID,
                                lr.target_currency_code ledger_currency_code, gjh.currency_code, 0 total_entered,
                                0 change_in_fx, SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)) revalue_in_gl -- gjh.period_name, XXD_GL_FX_ANALYSIS_RPT_PKG.get_period_names(pv_from_period, pv_to_period)--,
                           FROM gl_je_headers gjh, gl_je_lines gjl, gl_ledgers gll,
                                GL_LEDGER_SET_ASSIGNMENTS ASG, GL_LEDGER_RELATIONSHIPS LR, gl_code_combinations_kfv gcck
                          WHERE     1 = 1
                                AND gjh.je_header_id = gjl.je_header_id
                                AND gjh.ledger_id = gjl.ledger_id
                                AND gjh.period_name = gjl.period_name
                                AND gjh.je_source = pv_source
                                AND ((pv_category IS NOT NULL AND gjh.je_category = pv_category) OR (pv_category IS NULL AND 1 = 1))
                                --                 AND gjh.ledger_id = pn_ledger_id
                                AND GLL.LEDGER_ID = pn_ledger_id
                                AND gjl.code_combination_id =
                                    gcck.code_combination_id
                                --                   AND gll.chart_of_accounts_id = gcck.chart_of_accounts_id
                                AND gcck.SUMMARY_FLAG = 'N'
                                AND gcck.TEMPLATE_ID IS NULL
                                AND gcck.segment6 BETWEEN NVL (pv_from_account,
                                                               gcck.segment6)
                                                      AND NVL (pv_to_account,
                                                               gcck.segment6)
                                AND ASG.LEDGER_SET_ID(+) = GLL.LEDGER_ID
                                AND LR.TARGET_LEDGER_ID =
                                    NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                                AND LR.SOURCE_LEDGER_ID =
                                    NVL (ASG.LEDGER_ID, GLL.LEDGER_ID)
                                --                 AND LR.TARGET_CURRENCY_CODE = gll.currency_code
                                AND gjh.ledger_id = gll.ledger_id
                                AND LR.SOURCE_LEDGER_ID = gjh.LEDGER_ID
                                AND LR.TARGET_LEDGER_ID = gjh.LEDGER_ID --2036
                                AND gjh.status = 'P'
                                AND gjh.period_name IN
                                        (SELECT period_name
                                           FROM gl.gl_period_statuses
                                          WHERE     1 = 1
                                                AND application_id = 101
                                                AND set_of_books_id =
                                                    gc_default_ledger_id
                                                AND start_date >=
                                                    (SELECT start_date
                                                       FROM gl_period_statuses
                                                      WHERE     1 = 1
                                                            AND period_name =
                                                                pv_from_period
                                                            AND application_id =
                                                                101
                                                            AND set_of_books_id =
                                                                gc_default_ledger_id)
                                                AND end_date <=
                                                    (SELECT end_date
                                                       FROM gl_period_statuses
                                                      WHERE     1 = 1
                                                            AND period_name =
                                                                pv_to_period
                                                            AND application_id =
                                                                101
                                                            AND set_of_books_id =
                                                                gc_default_ledger_id))
                       GROUP BY lr.target_ledger_name, DECODE (pv_mode, 'SUMMARY', NULL, gcck.concatenated_segments), DECODE (pv_mode, 'SUMMARY', NULL, gjl.code_combination_id),
                                gjh.currency_code, lr.target_currency_code))
            GROUP BY name, rpt_mode, CCID,
                     ledger_currency_code, Entered_currency
            ORDER BY 1, 4, 5;
    BEGIN
        ld_rate_from_date   :=
            TO_DATE (pd_rate_from_date, 'RRRR/MM/DD HH24:mi:ss');
        ld_rate_to_date   :=
            TO_DATE (pd_rate_to_date, 'RRRR/MM/DD HH24:mi:ss');

        IF pv_mode = 'DETAIL'
        THEN
            PRINT (
                   'Ledger'
                || CHR (9)
                || 'GL Combinations'
                || CHR (9)
                || 'Ledger Currency'
                || CHR (9)
                || 'Entered Currency'
                || CHR (9)
                || 'Total Entered'
                || CHR (9)
                || 'Exchange Rate Difference'
                || CHR (9)
                || 'Revalue Amt (Total Entered * Rate Difference)'
                || CHR (9)
                || 'Actual Revalue Amt'
                || CHR (9)
                || 'Revalue Difference');
        ELSE
            PRINT (
                   'Ledger'
                || CHR (9)
                || 'Ledger Currency'
                || CHR (9)
                || 'Entered Currency'
                || CHR (9)
                || 'Total Entered'
                || CHR (9)
                || 'Exchange Rate Difference'
                || CHR (9)
                || 'Revalue Amt (Total Entered * Rate Difference)'
                || CHR (9)
                || 'Actual Revalue Amt'
                || CHR (9)
                || 'Revalue Difference');
        END IF;

        --      FOR rec_cur_comb IN cur_comb
        --      LOOP
        IF pv_mode = 'DETAIL'
        THEN
            IF pv_reval_only = 'Y'
            THEN
                --            IF pv_from_account IS NOT NULL OR pv_to_account IS NOT NULL
                --            THEN
                FOR rec_comb IN cur_comb
                LOOP
                    FOR rec_reval_only
                        IN cur_reval_only (rec_comb.code_combination_id)
                    LOOP
                        PRINT (
                               REPLACE (rec_reval_only.name, CHR (9), ' ')
                            || CHR (9)
                            || rec_reval_only.rpt_mode
                            || CHR (9)
                            ||    --                      rec_reval_only.CCID,
                               rec_reval_only.ledger_currency_code
                            || CHR (9)
                            || rec_reval_only.Entered_currency
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.Total_entered,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.change_in_fx,
                                   'FM9G999G999G999G999G999G999G999G990D00000000000000000000PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.recalculated_value,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.revalue_in_gl,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.Difference,
                                   'FM9G999G999G999G999G999G999G999G990D00PT'));
                    END LOOP;
                END LOOP;
            --            ELSE
            --               FOR rec_reval_only
            --                  IN cur_reval_only (null)
            --               LOOP
            --                  PRINT (
            --                        REPLACE (rec_reval_only.name, CHR (9), ' ')
            --                     || CHR (9)
            --                     || rec_reval_only.rpt_mode
            --                     || CHR (9)
            --                     ||           --                      rec_reval_only.CCID,
            --                       rec_reval_only.ledger_currency_code
            --                     || CHR (9)
            --                     || rec_reval_only.Entered_currency
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.Total_entered,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT')
            --                     || CHR (9)
            --                     || TO_CHAR (
            --                           rec_reval_only.change_in_fx,
            --                           'FM9G999G999G999G999G999G999G999G990D00000000000000000000PT')
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.recalculated_value,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT')
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.revalue_in_gl,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT')
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.Difference,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT'));
            --               END LOOP;
            --            END IF;
            ELSE
                FOR rec_main IN cur_main
                LOOP
                    PRINT (
                           REPLACE (rec_main.name, CHR (9), ' ')
                        || CHR (9)
                        || rec_main.rpt_mode
                        || CHR (9)
                        ||      --                      rec_main.CCID||'|'||--
                           rec_main.ledger_currency_code
                        || CHR (9)
                        || rec_main.Entered_currency
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.Total_entered,
                               'FM9G999G999G999G999G999G999G999G990D00PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.change_in_fx,
                               'FM9G999G999G999G999G999G999G999G990D00000000000000000000PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.recalculated_value,
                               'FM9G999G999G999G999G999G999G999G990D00PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.revalue_in_gl,
                               'FM9G999G999G999G999G999G999G999G990D00PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.Difference,
                               'FM9G999G999G999G999G999G999G999G990D00PT'));
                END LOOP;
            END IF;
        ELSE
            IF pv_reval_only = 'Y'
            THEN
                --            IF pv_from_account IS NOT NULL OR pv_to_account IS NOT NULL
                --            THEN
                FOR rec_comb IN cur_comb
                LOOP
                    FOR rec_reval_only
                        IN cur_reval_only (rec_comb.code_combination_id)
                    LOOP
                        PRINT (
                               REPLACE (rec_reval_only.name, CHR (9), ' ')
                            || CHR (9)
                            || rec_reval_only.ledger_currency_code
                            || CHR (9)
                            || rec_reval_only.Entered_currency
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.Total_entered,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.change_in_fx,
                                   'FM9G999G999G999G999G999G999G999G990D00000000000000000000PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.recalculated_value,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.revalue_in_gl,
                                   'FM9G999G999G999G999G999G999G999G990D00PT')
                            || CHR (9)
                            || TO_CHAR (
                                   rec_reval_only.Difference,
                                   'FM9G999G999G999G999G999G999G999G990D00PT'));
                    END LOOP;
                END LOOP;
            --            ELSE
            --               FOR rec_reval_only
            --                  IN cur_reval_only (null)
            --               LOOP
            --                  PRINT (
            --                        REPLACE (rec_reval_only.name, CHR (9), ' ')
            --                     || CHR (9)
            --                     || rec_reval_only.ledger_currency_code
            --                     || CHR (9)
            --                     || rec_reval_only.Entered_currency
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.Total_entered,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT')
            --                     || CHR (9)
            --                     || TO_CHAR (
            --                           rec_reval_only.change_in_fx,
            --                           'FM9G999G999G999G999G999G999G999G990D00000000000000000000PT')
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.recalculated_value,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT')
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.revalue_in_gl,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT')
            --                     || CHR (9)
            --                     || TO_CHAR (rec_reval_only.Difference,
            --                                 'FM9G999G999G999G999G999G999G999G990D00PT'));
            --               END LOOP;
            --            END IF;
            ELSE
                FOR rec_main IN cur_main
                LOOP
                    PRINT (
                           REPLACE (rec_main.name, CHR (9), ' ')
                        || CHR (9)
                        || rec_main.ledger_currency_code
                        || CHR (9)
                        || rec_main.Entered_currency
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.Total_entered,
                               'FM9G999G999G999G999G999G999G999G990D00PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.change_in_fx,
                               'FM9G999G999G999G999G999G999G999G990D00000000000000000000PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.recalculated_value,
                               'FM9G999G999G999G999G999G999G999G990D00PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.revalue_in_gl,
                               'FM9G999G999G999G999G999G999G999G990D00PT')
                        || CHR (9)
                        || TO_CHAR (
                               rec_main.Difference,
                               'FM9G999G999G999G999G999G999G999G990D00PT'));
                END LOOP;
            END IF;
        END IF;
    --      END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG ('Error @PROC_MAIN' || SQLERRM);
    END;
END XXD_GL_FX_ANALYSIS_RPT_PKG;
/
