--
-- XXD_GL_PJE_ROLL_FORWARD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_PJE_ROLL_FORWARD_PKG"
AS
    PROCEDURE LOG (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            --         DBMS_OUTPUT.put_line (pv_msgtxt_in);
            fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.LOG, pv_msgtxt_in);
        END IF;
    END LOG;

    -- +---------------------------------------------+
    -- | Procedure to print messages or notes in the |
    -- | OUTPUT file of the concurrent program       |
    -- +---------------------------------------------+

    PROCEDURE output (pv_msgtxt_in IN VARCHAR2)
    IS
    BEGIN
        IF fnd_global.conc_login_id = -1
        THEN
            DBMS_OUTPUT.put_line (pv_msgtxt_in);
        ELSE
            fnd_file.put_line (fnd_file.output, pv_msgtxt_in);
        END IF;
    END output;

    FUNCTION tab_space (pv_text IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_text   VARCHAR2 (4000) := NVL (pv_text, 'Not Defined');
    BEGIN
        lv_text   := lv_text || CHR (9);
        -- DBMS_OUTPUT.put_line (lv_text);

        RETURN lv_text;
    END tab_space;

    PROCEDURE proc_roll_forward_detail (pn_ledger_id NUMBER, pv_currency_code VARCHAR2, pv_period_name VARCHAR2, pv_je_source VARCHAR2, pv_je_category VARCHAR2, pv_period_close_from_dt DATE
                                        , pv_period_close_to_dt DATE)
    AS
        lv_period_close_date    DATE;
        ln_ledger_count         NUMBER := 0;
        lc_doc_sequence_value   VARCHAR2 (300) := NULL;

        --    type category_typ  is table of varchar2(2000) index by binary_integer;
        --    category_tbl category_typ:=category_typ('Manual', 'Spreadsheet');
        --lv_category varchar2:= category_typ('Manual', 'Spreadsheet');
        CURSOR cur_sel_detail (pn_ledger_id NUMBER, pv_currency_code VARCHAR2, pv_period_name VARCHAR2, pv_je_source VARCHAR2, pv_je_category VARCHAR2, pv_period_close_from_dt DATE
                               , pv_period_close_to_dt DATE)
        IS
            (  SELECT jh.doc_sequence_value, cc.segment1, ffvl.description Account_description,
                      cc.concatenated_segments, SUM (JL.accounted_DR) TOT_DR, SUM (JL.accounted_CR) TOT_CR
                 FROM gl_je_headers JH, GL_JE_LINES JL, GL_CODE_COMBINATIONS_KFV CC,
                      fnd_flex_values_vl ffvl, fnd_flex_value_sets ffvs
                WHERE --Start modification for CR 230,by BT Tech Team on 9-Dec-15
                          JH.ledger_id = pn_ledger_id
                      --End modification for CR 230,by BT Tech Team on 9-Dec-15
                      AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                      AND JL.CODE_COMBINATION_ID = CC.CODE_COMBINATION_ID
                      AND CC.ENABLED_FLAG = 'Y'
                      AND ffvs.FLEX_VALUE_SET_NAME = 'DO_GL_ACCOUNT'
                      AND ffvl.enabled_flag = 'Y'
                      AND ffvl.flex_value_set_id = ffvs.flex_value_set_id
                      AND ffvl.flex_value = cc.segment6
                      AND JH.PERIOD_NAME = NVL (pv_PERIOD_NAME, jh.period_name)
                      AND jh.status = 'P'
                      AND jh.je_category = NVL (pv_je_category, jh.je_category)
                      AND jh.je_source = NVL (pv_je_source, jh.je_source)
                      --Start modification for CR 230,by BT Tech Team on 9-Dec-15
                      AND jh.je_category NOT IN
                              (SELECT je_category_name
                                 FROM gl_je_categories
                                WHERE USER_JE_CATEGORY_NAME LIKE '%Consol%')
                      AND jh.je_source NOT IN
                              (SELECT je_source_name
                                 FROM gl_je_sources
                                WHERE USER_JE_SOURCE_NAME LIKE '%Consol%')
                      --End modification for CR 230,by BT Tech Team on 9-Dec-15
                      /*AND jh.je_category IN
                             CASE
                                WHEN pv_je_category = '5'
                                THEN
                                   '5' --JE_CATEGORY 5 = 'Manual'--user_je_category_name
                                WHEN pv_je_category =
                                        'Revaluation'
                                THEN
                                   'Revaluation'
                                WHEN pv_je_category =
                                        'Elimination'
                                THEN
                                   'Elimination'
                                WHEN pv_je_category IS NULL
                                THEN
                                   CASE jh.je_category
                                      WHEN '5'
                                      THEN
                                         '5'
                                      WHEN 'Revaluation'
                                      THEN
                                         'Revaluation'
                                      WHEN 'Elimination'
                                      THEN
                                         'Elimination'
                                   END
                             END
                      AND jh.je_source IN
                             CASE
                                WHEN pv_je_source = 'Manual'
                                THEN
                                   'Manual'
                                WHEN pv_je_source =
                                        'Spreadsheet'
                                THEN
                                   'Spreadsheet'
                                WHEN pv_je_source IS NULL
                                THEN
                                   CASE jh.je_source
                                      WHEN 'Manual'
                                      THEN
                                         'Manual'
                                      WHEN 'Spreadsheet'
                                      THEN
                                         'Spreadsheet'
                                   END
                             END*/
                      --AND CC.CODE_COMBINATION_ID = 14040
                      AND jh.ledger_id = NVL (pn_ledger_id, jh.ledger_id) --2022
                      --  Commented for Defect#588                 AND jh.currency_code =
                      --  Commented for Defect#588                        NVL (pv_currency_code, jh.currency_code)
                      AND JH.CREATION_DATE BETWEEN pv_period_close_from_dt
                                               AND NVL (pv_period_close_to_dt,
                                                        --                             (SELECT time_stamp
                                                        --                                FROM xxd_common_mapping_lines_tbl
                                                        --                               WHERE     period_name = pv_period_name
                                                        --                                     AND ROWNUM = 1)
                                                        SYSDATE)
             GROUP BY jh.doc_sequence_value, cc.segment1, ffvl.description,
                      cc.concatenated_segments
             UNION
             SELECT ds.doc_sequence_value, NULL, NULL,
                    NULL, NULL, NULL
               FROM FND_DOC_SEQUENCE_ASSIGNMENTS dsa, gl_doc_sequence_audit ds
              WHERE     dsa.set_of_books_id = pn_ledger_id
                    AND dsa.application_id =
                        (SELECT application_id
                           FROM fnd_application
                          WHERE application_short_name = 'SQLGL')
                    AND dsa.doc_sequence_id = ds.doc_sequence_id
                    AND dsa.end_date IS NULL
                    AND dsa.category_code =
                        NVL (pv_je_category, dsa.category_code)
                    --                 AND dsa.category_code =
                    --                        CASE
                    --                           WHEN NVL (pv_je_category, '5') = '5' THEN '5'
                    --                        END
                    AND ds.CREATION_DATE BETWEEN pv_period_close_from_dt
                                             AND NVL (pv_period_close_to_dt,
                                                      --                             (SELECT time_stamp
                                                      --                                FROM xxd_common_mapping_lines_tbl
                                                      --                               WHERE     period_name = pv_period_name
                                                      --                                     AND ROWNUM = 1)
                                                      SYSDATE)
                    AND ds.doc_sequence_value NOT IN
                            (SELECT gjh.doc_sequence_value
                               FROM gl_je_headers gjh
                              WHERE     gjh.je_category = '5'
                                    AND gjh.doc_sequence_value =
                                        ds.doc_sequence_value
                                    AND gjh.doc_sequence_id =
                                        ds.doc_sequence_id))
            ORDER BY 1;

        --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
        CURSOR cur_get_ledger_name (cp_ledger_id NUMBER)
        IS
            SELECT led.NAME ledger_name, led.ledger_id
              FROM gl_ledgers led, gl_ledger_set_norm_assign gla
             WHERE     led.ledger_id = gla.ledger_id
                   AND NVL (gla.status_code, 'X') <> 'D'
                   AND gla.ledger_set_id = cp_ledger_id;

        TYPE c1_ledger_type IS TABLE OF cur_get_ledger_name%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab               c1_ledger_type;
    --End  modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1

    BEGIN
        --      lv_period_close_date :=
        --         TO_CHAR (pv_period_close_date, 'YYYY/MM/DD HH24:Mi:ss');
        --      lv_period_close_date :=
        --         FND_DATE.canonical_to_date (lv_period_close_date); --to_date(to_char(trunc(pv_period_close_date),'YYYY/MM/DD'),'DD/MM/YYYY');
        output (
               'AJE#'
            || CHR (9)
            || 'COMPANY'
            || CHR (9)
            || 'ACCOUNT DESCRIPTION'
            || CHR (9)
            || 'GL'
            || CHR (9)
            || 'Debit'
            || CHR (9)
            || 'Credit');

        --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
        BEGIN
            SELECT COUNT ('X')
              INTO ln_ledger_count
              FROM gl_ledgers led, gl_ledger_set_norm_assign gla
             WHERE     led.ledger_id = gla.ledger_id
                   AND NVL (gla.status_code, 'X') <> 'D'
                   AND gla.ledger_set_id = pn_ledger_id;

            LOG ('ln_ledger_count' || ln_ledger_count);
        EXCEPTION
            WHEN OTHERS
            THEN
                LOG ('Error while getting ln_ledger_count' || SQLERRM);
        END;

        IF ln_ledger_count > 0
        THEN
            OPEN cur_get_ledger_name (cp_ledger_id => pn_ledger_id);

            FETCH cur_get_ledger_name BULK COLLECT INTO lt_c1_tab;

            CLOSE cur_get_ledger_name;
        END IF;

        -- Start Changes by BT Technology Team on 16 Dec 15
        --lt_c1_tab.delete;

        -- End Changes by BT Technology Team on 16 Dec 15

        IF lt_c1_tab.COUNT > 0
        THEN
            FOR j IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
            LOOP
                --End modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1

                LOG (' from ledger set ledger id' || lt_c1_tab (j).ledger_id);

                FOR rec_sel_detail
                    IN cur_sel_detail ( --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
                                       --pn_ledger_id,
                                       lt_c1_tab (j).ledger_id, --End modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
                                                                pv_currency_code, pv_period_name, pv_je_source, pv_je_category, pv_period_close_from_dt
                                       , pv_period_close_to_dt)
                LOOP
                    IF rec_sel_detail.doc_sequence_value IS NULL
                    THEN
                        lc_doc_sequence_value   :=
                            rec_sel_detail.doc_sequence_value;
                    ELSE
                        lc_doc_sequence_value   :=
                               rec_sel_detail.doc_sequence_value
                            || '-'
                            || lt_c1_tab (j).ledger_name;
                    END IF;

                    output (
                           lc_doc_sequence_value --Added for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
                        || CHR (9)
                        || rec_sel_detail.segment1
                        || CHR (9)
                        || rec_sel_detail.Account_description
                        || CHR (9)
                        || rec_sel_detail.concatenated_segments
                        || CHR (9)
                        || rec_sel_detail.TOT_DR
                        || CHR (9)
                        || rec_sel_detail.TOT_CR);
                END LOOP;
            --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
            END LOOP;
        ELSE
            FOR rec_sel_detail IN cur_sel_detail (pn_ledger_id, pv_currency_code, pv_period_name, pv_je_source, pv_je_category, pv_period_close_from_dt
                                                  , pv_period_close_to_dt)
            LOOP
                output (
                       rec_sel_detail.doc_sequence_value
                    || CHR (9)
                    || rec_sel_detail.segment1
                    || CHR (9)
                    || rec_sel_detail.Account_description
                    || CHR (9)
                    || rec_sel_detail.concatenated_segments
                    || CHR (9)
                    || rec_sel_detail.TOT_DR
                    || CHR (9)
                    || rec_sel_detail.TOT_CR);
            END LOOP;
        END IF;
    --End modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1

    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                   'Error while displaying PJE Roll Forward Detial report - '
                || SQLERRM);
    END;


    PROCEDURE proc_roll_forward_summary (pv_period_type VARCHAR2, pv_currency_type VARCHAR2 DEFAULT 'E', pn_ledger_id NUMBER, pv_currency_code VARCHAR2, pv_period_name VARCHAR2, pv_je_source VARCHAR2, pv_je_category VARCHAR2, pv_period_close_from_dt DATE, pv_period_close_to_dt DATE
                                         , pv_row_set_name VARCHAR2)
    AS
        lv_prev_period_name     VARCHAR2 (50);
        lv_qtr_period_name      VARCHAR2 (50);
        lv_ytd_period_name      VARCHAR2 (50);
        ln_count                NUMBER (15);
        lv_doc_sequences        VARCHAR2 (4000) := NULL;
        ln_doc_seq_cnt          NUMBER (22) := 1;
        ln_ledger_count         NUMBER := 0;
        lc_doc_sequence_value   VARCHAR2 (3000) := NULL;

        TYPE doc_seq_rec_typ IS RECORD
        (
            sl_no           NUMBER (10),
            doc_sequence    XXD_GL_PJE_SUMMARY_GT.doc_sequence_value%TYPE
        );

        TYPE doc_seq_tab_typ IS TABLE OF doc_seq_rec_typ
            INDEX BY BINARY_INTEGER;

        doc_seq_tab             doc_seq_tab_typ;

        ln_doc_seq_sl_no        NUMBER (22);
        lv_acc_head_rec         VARCHAR2 (4000) := NULL;
        ln_sl_no                NUMBER (22) := 0;
        ln_sl_no_intial         NUMBER (22) := 0;
        ln_max_sl_no            NUMBER (22) := 0;
        ln_max_sl_no_intial     NUMBER (22) := 0;
        ln_opening_balance      NUMBER (22, 4);
        ln_closing_balance      NUMBER (22, 4);
        ln_total_OB             NUMBER (22, 4);
        ln_total_CB             NUMBER (22, 4);
        lv_currency_type        VARCHAR2 (1);
        lv_cb_pos               VARCHAR2 (4000);

        CURSOR cur_summary (pv_period_type VARCHAR2, pv_currency_type VARCHAR2 DEFAULT 'E', pn_ledger_id NUMBER, pv_currency_code VARCHAR2, pv_period_name VARCHAR2, --pv_period_name     VARCHAR2,
                                                                                                                                                                     pv_je_source VARCHAR2, pv_je_category VARCHAR2, pv_period_close_from_dt DATE, pv_period_close_to_dt DATE
                            , pv_row_set_name VARCHAR2)
        IS
              SELECT summary.ledger_id, summary.group_name, summary.group_sequence,
                     summary.group_name account_heads, summary.sequence, detail.doc_sequence_value,
                     detail.total_amount journal_amount, SUM (summary.BEGIN_BALANCE) begin_balance, SUM (NVL (summary.BEGIN_BALANCE, 0) + (NVL (summary.PERIOD_DR, 0) - NVL (summary.PERIOD_CR, 0))) closing_balance
                FROM (      --start changes by BT Technology team on 16 Dec 15
                        SELECT                        --LR.TARGET_LEDGER_NAME,
                               l.ledger_id, CC.SEGMENT6, cc.code_combination_id,
                               fcs.group_name account_heads, fcs.sequence, fcs.group_sequence,
                               fcs.group_name, DECODE (pv_PERIOD_type,  'PTD', SUM (period_net_dr - period_net_cr),  'QTD', SUM (Quarter_to_date_dr - Quarter_to_date_cr),  'YTD', SUM (begin_balance_dr - begin_balance_cr)) BEGIN_BALANCE, SUM (period_net_dr) PERIOD_DR,
                               SUM (period_net_cr) PERIOD_CR
                          FROM GL_BALANCES BAL, GL_CODE_COMBINATIONS CC, GL_LEDGERS L,
                               --           GL_LEDGER_SET_ASSIGNMENTS ASG,
                               --GL_LEDGER_RELATIONSHIPS LR,            -- Change made by Karan
                               APPS.XXD_GL_FSG_CONS_SUMMARY_V fcs
                         WHERE     BAL.ACTUAL_FLAG = 'A'
                               -- AND BAL.CURRENCY_CODE = RESULTING_CURRENCY
                               AND BAL.PERIOD_NAME = pv_PERIOD_NAME -- Change made by Karan
                               /*      (pv_PERIOD_NAME,
                                      DECODE (
                                         pv_PERIOD_type,
                                         'PTD', pv_PERIOD_NAME,
                                         'QTD', APPS.XXD_RETURN_PERIOD_PKG.XXD_RETURN_QUARTER_FUNC (
                                                   pv_PERIOD_NAME),
                                         'YTD', APPS.XXD_RETURN_PERIOD_PKG.XXD_RETURN_first_period_func (
                                                   pv_PERIOD_NAME))) */
                               AND BAL.CODE_COMBINATION_ID =
                                   CC.CODE_COMBINATION_ID
                               -- AND CC.CHART_OF_ACCOUNTS_ID = STRUCT_NUM
                               AND CC.TEMPLATE_ID IS NULL
                               AND CC.SUMMARY_FLAG = 'N'
                               AND BAL.LEDGER_ID = pn_ledger_id --- Change made by Karan
                               --start changes by BT Technology on 30 Mar 2015 XXD_GL_FSG_CONS_SUMMARY_V should be independent of rowset_name
                               AND fcs.rowset_name =
                                   NVL (pv_row_set_name, fcs.rowset_name)
                               --End changes by BT Technology on 30 Mar 2015 XXD_GL_FSG_CONS_SUMMARY_V should be independent of rowset_name
                               AND cc.segment1 BETWEEN fcs.segment1_low
                                                   AND fcs.segment1_high
                               AND cc.segment2 BETWEEN fcs.segment2_low
                                                   AND fcs.segment2_high
                               AND cc.segment3 BETWEEN fcs.segment3_low
                                                   AND fcs.segment3_high
                               AND cc.segment4 BETWEEN fcs.segment4_low
                                                   AND fcs.segment4_high
                               AND cc.segment5 BETWEEN fcs.segment5_low
                                                   AND fcs.segment5_high
                               AND cc.segment6 BETWEEN fcs.segment6_low
                                                   AND fcs.segment6_high
                               AND cc.segment7 BETWEEN fcs.segment7_low
                                                   AND fcs.segment7_high
                               AND cc.segment8 BETWEEN fcs.segment8_low
                                                   AND fcs.segment8_high
                               --and cc.code_combination_id in  (4129,4130)
                               -- AND ASG.LEDGER_SET_ID(+)= L.LEDGER_ID
                               -- AND LR.TARGET_LEDGER_ID = NVL(ASG.LEDGER_ID, L.LEDGER_ID)
                               -- AND LR.SOURCE_LEDGER_ID = NVL(ASG.LEDGER_ID, L.LEDGER_ID)
                               --Commented for Defect#588                                AND LR.TARGET_CURRENCY_CODE = pv_currency_code
                               AND L.LEDGER_ID = BAL.LEDGER_ID -- Change made by Karan
                      -- AND LR.TARGET_LEDGER_ID = BAL.LEDGER_ID            -- Commented by Karan
                      --and fcs.group_name = 'COGS'
                      GROUP BY l.ledger_id, CC.SEGMENT6, cc.code_combination_id,
                               -- fcs.account_heads,
                               fcs.sequence, fcs.group_sequence, fcs.group_name -- End Changes bt BT Technology team on 16 Dec 15
                                                                               )
                     summary
                     FULL OUTER JOIN
                     (  SELECT ledger_id, doc_sequence_value, group_name Account_heads,
                               sequence, group_sequence, group_name,
                               SUM (tot_dr) - SUM (tot_cr) TOTAL_AMOUNT
                          FROM ((  SELECT jh.ledger_id, jh.doc_sequence_value, ffvl.description Account_description,
                                          JL.CODE_COMBINATION_ID, SUM (NVL (JL.accounted_DR, 0)) TOT_DR, SUM (NVL (JL.accounted_CR, 0)) TOT_CR,
                                          fcs.group_name Account_heads, fcs.sequence, fcs.group_sequence,
                                          fcs.group_name
                                     --                   case when jl.segment6 between fcs.segment6_low and fcs.segment6_high
                                     --                   then fcs.segment6_low
                                     FROM gl_je_headers JH, GL_JE_LINES JL, GL_CODE_COMBINATIONS CC,
                                          fnd_flex_values_vl ffvl, fnd_flex_value_sets ffvs, XXD_GL_FSG_CONS_SUMMARY_V fcs
                                    --where period_name = pv_PERIOD_NAME
                                    WHERE     jh.ledger_id = pn_ledger_id
                                          AND JH.JE_HEADER_ID = JL.JE_HEADER_ID
                                          AND JL.CODE_COMBINATION_ID =
                                              CC.CODE_COMBINATION_ID
                                          AND CC.ENABLED_FLAG = 'Y'
                                          AND ffvs.FLEX_VALUE_SET_NAME =
                                              'DO_GL_ACCOUNT'
                                          AND ffvl.enabled_flag = 'Y'
                                          AND ffvl.flex_value_set_id =
                                              ffvs.flex_value_set_id
                                          AND ffvl.flex_value = cc.segment6
                                          AND JH.PERIOD_NAME =
                                              NVL (pv_PERIOD_NAME, jh.period_name)
                                          AND jh.status = 'P'
                                          --start changes by BT Technology on 30 Mar 2015 XXD_GL_FSG_CONS_SUMMARY_V should be independent of rowset_name
                                          AND fcs.rowset_name =
                                              NVL (pv_row_set_name,
                                                   fcs.rowset_name)
                                          --End changes by BT Technology on 30 Mar 2015 XXD_GL_FSG_CONS_SUMMARY_V should be independent of rowset_name
                                          AND cc.segment1 BETWEEN fcs.segment1_low
                                                              AND fcs.segment1_high
                                          AND cc.segment2 BETWEEN fcs.segment2_low
                                                              AND fcs.segment2_high
                                          AND cc.segment3 BETWEEN fcs.segment3_low
                                                              AND fcs.segment3_high
                                          AND cc.segment4 BETWEEN fcs.segment4_low
                                                              AND fcs.segment4_high
                                          AND cc.segment5 BETWEEN fcs.segment5_low
                                                              AND fcs.segment5_high
                                          AND cc.segment6 BETWEEN fcs.segment6_low
                                                              AND fcs.segment6_high
                                          AND cc.segment7 BETWEEN fcs.segment7_low
                                                              AND fcs.segment7_high
                                          AND cc.segment8 BETWEEN fcs.segment8_low
                                                              AND fcs.segment8_high
                                          --start changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                          AND jh.je_category =
                                              NVL (pv_je_category, jh.je_category)
                                          AND jh.je_source =
                                              NVL (pv_je_source, jh.je_source)
                                          --Start modification for CR 230,by BT Tech Team on 9-Dec-15
                                          AND jh.je_category NOT IN
                                                  (SELECT je_category_name
                                                     FROM gl_je_categories
                                                    WHERE USER_JE_CATEGORY_NAME LIKE
                                                              '%Consol%')
                                          AND jh.je_source NOT IN
                                                  (SELECT je_source_name
                                                     FROM gl_je_sources
                                                    WHERE USER_JE_SOURCE_NAME LIKE
                                                              '%Consol%')
                                          --End modification for CR 230,by BT Tech Team on 9-Dec-15
                                          /*AND jh.je_category IN
                                                 CASE
                                                    WHEN pv_je_category = '5'
                                                    THEN
                                                       '5' --JE_CATEGORY 5 = 'Manual'--user_je_category_name
                                                    WHEN pv_je_category =
                                                            'Revaluation'
                                                    THEN
                                                       'Revaluation'
                                                    WHEN pv_je_category =
                                                            'Elimination'
                                                    THEN
                                                       'Elimination'
                                                    WHEN pv_je_category IS NULL
                                                    THEN
                                                       CASE jh.je_category
                                                          WHEN '5'
                                                          THEN
                                                             '5'
                                                          WHEN 'Revaluation'
                                                          THEN
                                                             'Revaluation'
                                                          WHEN 'Elimination'
                                                          THEN
                                                             'Elimination'
                                                       END
                                                 END
                                          AND jh.je_source IN
                                                 CASE
                                                    WHEN pv_je_source = 'Manual'
                                                    THEN
                                                       'Manual'
                                                    WHEN pv_je_source =
                                                            'Spreadsheet'
                                                    THEN
                                                       'Spreadsheet'
                                                    WHEN pv_je_source IS NULL
                                                    THEN
                                                       CASE jh.je_source
                                                          WHEN 'Manual'
                                                          THEN
                                                             'Manual'
                                                          WHEN 'Spreadsheet'
                                                          THEN
                                                             'Spreadsheet'
                                                       END
                                                 END*/


                                          --Endt changes v2.1 by BT Technology --Not to restrict specific categories or specific sources
                                          --AND CC.CODE_COMBINATION_ID = 14040
                                          --2022
                                          --Commented for Defect#588                                            AND jh.currency_code =
                                          --Commented for Defect#588                                                   NVL (pv_currency_code,
                                          --Commented for Defect#588                                                       jh.currency_code)
                                          AND JH.CREATION_DATE BETWEEN pv_period_close_from_dt
                                                                   AND NVL (
                                                                           pv_period_close_to_dt,
                                                                           --                             (SELECT time_stamp
                                                                           --                                FROM xxd_common_mapping_lines_tbl
                                                                           --                               WHERE     period_name = pv_period_name
                                                                           --                                     AND ROWNUM = 1)
                                                                           SYSDATE)
                                 GROUP BY jh.ledger_id, jh.doc_sequence_value, ffvl.description,
                                          JL.CODE_COMBINATION_ID, -- fcs.Account_heads,
                                                                  fcs.sequence, fcs.group_sequence,
                                          fcs.group_name, --                                         --start changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                                          jh.je_category, jh.je_source
                                 --End changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                 UNION
                                 SELECT dsa.set_of_books_id, ds.doc_sequence_value, NULL,
                                        NULL, NULL, NULL,
                                        NULL, NULL, NULL,
                                        NULL
                                   FROM FND_DOC_SEQUENCE_ASSIGNMENTS dsa, gl_doc_sequence_audit ds
                                  WHERE     dsa.set_of_books_id = pn_ledger_id
                                        AND dsa.application_id =
                                            (SELECT application_id
                                               FROM fnd_application
                                              WHERE application_short_name =
                                                    'SQLGL')
                                        AND dsa.doc_sequence_id =
                                            ds.doc_sequence_id
                                        AND dsa.category_code =
                                            NVL (pv_je_category,
                                                 dsa.category_code)
                                        --start changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                        /*CASE
                                           WHEN NVL (pv_je_category, '5') =
                                                   '5'
                                           THEN
                                              '5'
                                        END*/
                                        --End changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                        AND dsa.end_date IS NULL
                                        --start changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                        AND ds.CREATION_DATE BETWEEN pv_period_close_from_dt
                                                                 AND NVL (
                                                                         pv_period_close_to_dt,
                                                                         --                             (SELECT time_stamp
                                                                         --                                FROM xxd_common_mapping_lines_tbl
                                                                         --                               WHERE     period_name = pv_period_name
                                                                         --                                     AND ROWNUM = 1)
                                                                         SYSDATE)
                                        --End changes v2.1 by BT Technology on 30 Mar 2015 --Not to restrict specific categories or specific sources
                                        AND ds.doc_sequence_value NOT IN
                                                (SELECT gjh.doc_sequence_value
                                                   FROM gl_je_headers gjh
                                                  WHERE     gjh.je_category = '5'
                                                        AND gjh.doc_sequence_value =
                                                            ds.doc_sequence_value
                                                        AND gjh.doc_sequence_id =
                                                            ds.doc_sequence_id)))
                      GROUP BY ledger_id, doc_sequence_value, -- Account_heads,
                                                              sequence,
                               group_sequence, group_name) detail
                         ON     summary.ledger_id = detail.ledger_id
                            AND summary.account_heads = detail.account_heads
                            AND summary.group_sequence = detail.group_sequence
                            AND summary.sequence = detail.sequence
            GROUP BY summary.ledger_id, summary.group_name, summary.group_sequence,
                     --                  summary.account_heads,
                     summary.sequence, detail.doc_sequence_value, detail.total_amount
            ORDER BY summary.sequence;

        --      (nvl(summary.BEGIN_BALANCE,0));


        CURSOR CUR_doc_sequence IS
              SELECT DISTINCT doc_sequence_value
                FROM XXD_GL_PJE_SUMMARY_GT
            ORDER BY 1;

        CURSOR CUR_ACC_GORUP IS
              SELECT DISTINCT group_sequence, group_name
                FROM XXD_GL_PJE_SUMMARY_GT
               WHERE group_name IS NOT NULL
            ORDER BY group_sequence;

        CURSOR CUR_ACC_heads (pv_group_name VARCHAR2)
        IS
              SELECT DISTINCT Sequence_acct_Heads, account_heads
                FROM XXD_GL_PJE_SUMMARY_GT
               WHERE group_name = pv_group_name AND account_heads IS NOT NULL
            ORDER BY Sequence_acct_Heads;

        CURSOR CUR_jrnl_amt (pv_group_head VARCHAR2--         ,
                                                   --         pv_acc_head      VARCHAR2
                                                   )
        IS
              SELECT account_heads, doc_sequence_value, SUM (journal_amount) journal_amount
                FROM XXD_GL_PJE_SUMMARY_GT
               WHERE group_name = pv_group_head --            AND account_heads = pv_acc_head --                     and doc_sequence_value is not null
                                                --AND doc_sequence_value = pv_doc_sequence
                                                AND journal_amount IS NOT NULL
            GROUP BY group_name, account_heads, doc_sequence_value
            ORDER BY TO_CHAR (doc_sequence_value);

        --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
        CURSOR cur_get_ledger_name (cp_ledger_id NUMBER)
        IS
            SELECT led.NAME ledger_name, led.ledger_id
              FROM gl_ledgers led, gl_ledger_set_norm_assign gla
             WHERE     led.ledger_id = gla.ledger_id
                   AND NVL (gla.status_code, 'X') <> 'D'
                   AND gla.ledger_set_id = cp_ledger_id;

        TYPE c1_ledger_type IS TABLE OF cur_get_ledger_name%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lt_c1_tab               c1_ledger_type;
    --End  modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1


    BEGIN
        --lv_prev_period_name :=   XXD_RETURN_PERIOD_PKG.XXD_RETURN_PREV_PRD_FUNC (PV_PERIOD_NAME);
        --lv_qtr_period_name :=  XXD_RETURN_PERIOD_PKG.XXD_RETURN_QUARTER_FUNC (lv_prev_period_name);
        --      lv_ytd_period_name :=  XXD_RETURN_PERIOD_PKG.XXD_RETURN_first_period_func (lv_prev_period_name);

        lv_currency_type   := NVL (pv_currency_type, 'E');

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_PJE_SUMMARY_GT');

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_PJE_DOC_SEQ_GT');


        LOG (
               'Parameters - '
            || pv_period_type
            || '-'
            || pv_currency_type
            || '-'
            || pn_ledger_id
            || '-'
            || pv_currency_code
            || '-'
            || pv_period_name
            || '-'
            || pv_je_source
            || '-'
            || pv_je_category
            || '-'
            || pv_period_close_from_dt
            || '-'
            || pv_period_close_to_dt
            || '-'
            || pv_row_set_name);

        --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
        BEGIN
            SELECT COUNT ('X')
              INTO ln_ledger_count
              FROM gl_ledgers led, gl_ledger_set_norm_assign gla
             WHERE     led.ledger_id = gla.ledger_id
                   AND NVL (gla.status_code, 'X') <> 'D'
                   AND gla.ledger_set_id = pn_ledger_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                LOG ('Error while getting ln_ledger_count' || SQLERRM);
        END;

        IF ln_ledger_count > 0
        THEN
            OPEN cur_get_ledger_name (cp_ledger_id => pn_ledger_id);

            FETCH cur_get_ledger_name BULK COLLECT INTO lt_c1_tab;

            CLOSE cur_get_ledger_name;
        END IF;

        -- Start Changes by BT Technology Team on 16 Dec 15
        --      lt_c1_tab.delete;

        -- End Changes by BT Technology Team on 16 Dec 15

        IF lt_c1_tab.COUNT > 0
        THEN
            FOR j IN lt_c1_tab.FIRST .. lt_c1_tab.LAST
            LOOP
                --End modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1

                LOG ('Ram ledger_id ' || lt_c1_tab (j).ledger_id);

                FOR rec_summary IN cur_summary (pv_period_type, lv_currency_type, --Start modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
                                                                                  --  pn_ledger_id,
                                                                                  lt_c1_tab (j).ledger_id, --End modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
                                                                                                           pv_currency_code, pv_period_name, --lv_prev_period_name,
                                                                                                                                             pv_je_source, pv_je_category, pv_period_close_from_dt, pv_period_close_to_dt
                                                , pv_row_set_name)
                LOOP
                    -- Start modification by BT Technology Team on 11-Dec-2015
                    lc_doc_sequence_value   := NULL;

                    -- End modification by BT Technology Team on 11-Dec-2015
                    IF rec_summary.doc_sequence_value IS NULL
                    THEN
                        lc_doc_sequence_value   :=
                            TO_CHAR (rec_summary.doc_sequence_value);
                    ELSE
                        lc_doc_sequence_value   :=
                               rec_summary.doc_sequence_value
                            || '-'
                            || lt_c1_tab (j).ledger_name;
                    END IF;


                    INSERT INTO XXD_GL_PJE_SUMMARY_GT (ledger_id,
                                                       group_name,
                                                       group_sequence,
                                                       account_heads,
                                                       doc_sequence_value,
                                                       journal_amount,
                                                       closing_balance,
                                                       Sequence_acct_Heads)
                             VALUES (rec_summary.ledger_id,
                                     rec_summary.group_name,
                                     rec_summary.group_sequence,
                                     rec_summary.account_heads,
                                     lc_doc_sequence_value, --Added for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1
                                     rec_summary.journal_amount,
                                     rec_summary.closing_balance,
                                     rec_summary.sequence);

                    LOG (
                        'rec_summary.closing_balance ' || rec_summary.closing_balance);
                    LOG (
                        'rec_summary.begin balance ' || rec_summary.begin_balance);
                    LOG (
                           'rec_summary.doc_sequence_value '
                        || lc_doc_sequence_value);
                --log('rec_summary.opening_balance '||rec_summary.opening_balance);--opening_balance

                END LOOP;

                COMMIT;
            END LOOP;
        ELSE
            FOR rec_summary IN cur_summary (pv_period_type, lv_currency_type, pn_ledger_id, pv_currency_code, pv_period_name, --lv_prev_period_name,
                                                                                                                              pv_je_source, pv_je_category, pv_period_close_from_dt, pv_period_close_to_dt
                                            , pv_row_set_name)
            LOOP
                INSERT INTO XXD_GL_PJE_SUMMARY_GT (ledger_id,
                                                   group_name,
                                                   group_sequence,
                                                   account_heads,
                                                   doc_sequence_value,
                                                   journal_amount,
                                                   closing_balance,
                                                   Sequence_acct_Heads)
                         VALUES (rec_summary.ledger_id,
                                 rec_summary.group_name,
                                 rec_summary.group_sequence,
                                 rec_summary.account_heads,
                                 TO_CHAR (rec_summary.doc_sequence_value),
                                 rec_summary.journal_amount,
                                 rec_summary.closing_balance,
                                 rec_summary.sequence);

                LOG (
                    'rec_summary.closing_balance ' || rec_summary.closing_balance);
                LOG (
                    'rec_summary.begin balance ' || rec_summary.begin_balance);
                LOG (
                    'rec_summary.doc_sequence_value ' || rec_summary.doc_sequence_value);
            --log('rec_summary.opening_balance '||rec_summary.opening_balance);--opening_balance

            END LOOP;

            COMMIT;
        END IF;

        --End modification for CR 230,BT Tech Team,Dt 3-Dec-15,V1.1



        SELECT COUNT (*) INTO ln_count FROM XXD_GL_PJE_SUMMARY_GT;

        LOG ('Count in Temporary Table' || ln_count);

        IF ln_count >= 1
        THEN
            output (CHR (9) || CHR (9) || 'Document Sequence');

            --output ('Account Head' || CHR (9) || 'Opening Balance' || CHR (10));

            FOR rec_doc_sequence IN cur_doc_sequence
            LOOP
                lv_doc_sequences                     :=
                       lv_doc_sequences
                    || rec_doc_sequence.doc_sequence_value
                    || CHR (9);
                doc_seq_tab (ln_doc_seq_cnt).sl_no   := ln_doc_seq_cnt;
                doc_seq_tab (ln_doc_seq_cnt).doc_sequence   :=
                    rec_doc_sequence.doc_sequence_value;
                ln_doc_seq_cnt                       :=
                    ln_doc_seq_cnt + 1;
            END LOOP;



            BEGIN
                INSERT INTO XXD_GL_PJE_DOC_SEQ_GT
                    SELECT ROWNUM, doc_Sequence_value
                      FROM (  SELECT DISTINCT doc_sequence_value
                                FROM XXD_GL_PJE_SUMMARY_GT
                            ORDER BY TO_CHAR (doc_sequence_value));

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    LOG (
                           'Error while Inserting into XXD_GL_PJE_DOC_SEQ_GT table'
                        || SQLERRM);
            END;

            output (
                   'Account Head'
                || CHR (9)
                || 'Balance Before PCD'
                || CHR (9)
                || lv_doc_sequences
                || 'Closing Balance');

            BEGIN
                FOR rec_acc_gorup IN cur_acc_gorup
                LOOP
                    --               FOR rec_acc_heads IN cur_acc_heads (rec_acc_gorup.group_name)
                    --               LOOP
                    --                  LOG (rec_acc_gorup.group_name);
                    --                  LOG (rec_acc_heads.account_heads);

                    BEGIN
                        IF lt_c1_tab.COUNT > 1
                        THEN
                            -- Start modification by BT Technology Team on 16-Dec-15
                            --                        SELECT   MIN (NVL (closing_balance, 0))

                            --                        SELECT SUM (NVL (closing_balance, 0)) -- End modification by BT Technology Team on 16-Dec-15
                            --                               - SUM (NVL (journal_amount, 0)),
                            --                               MAX (closing_balance)
                            --                          INTO ln_opening_balance, ln_closing_balance
                            --                          FROM XXD_GL_PJE_SUMMARY_GT
                            --                         WHERE     group_name = rec_acc_gorup.group_name
                            --                               AND account_heads =
                            --                                      rec_acc_heads.account_heads
                            --                               AND ledger_id =
                            --                                      (SELECT ledger_id
                            --                                         FROM gl_ledgers
                            --                                        WHERE name =
                            --                                                 'Deckers Group Consolidation'); -- Added by BT Technology Team on 16 Dec 15

                            SELECT cls_query.cls_bal, cls_query.cls_bal - opn_query.jrnl_amt
                              INTO ln_closing_balance, ln_opening_balance
                              FROM (  SELECT SUM (closing_balance) cls_bal, cls.group_name, cls.account_heads
                                        FROM XXD_GL_PJE_SUMMARY_GT cls
                                       WHERE     group_name =
                                                 rec_acc_gorup.group_name
                                             --                                         AND account_heads =
                                             --                                                rec_acc_heads.account_heads
                                             AND ledger_id =
                                                 (SELECT ledger_id
                                                    FROM gl_ledgers
                                                   WHERE name =
                                                         'Deckers Group Consolidation')
                                    GROUP BY cls.group_name, cls.account_heads)
                                   cls_query,
                                   (  SELECT SUM (NVL (journal_amount, 0)) jrnl_amt, opn.group_name, opn.account_heads
                                        FROM XXD_GL_PJE_SUMMARY_GT opn
                                       WHERE group_name =
                                             rec_acc_gorup.group_name
                                    --                                         AND account_heads =
                                    --                                                rec_acc_heads.account_heads
                                    GROUP BY opn.group_name, opn.account_heads)
                                   opn_query
                             WHERE     cls_query.group_name =
                                       opn_query.group_name
                                   AND cls_query.account_heads =
                                       opn_query.account_heads;
                        ELSE
                            -- Start modification by BT Technology Team on 16-Dec-15
                            --                        SELECT   MIN (NVL (closing_balance, 0))
                            SELECT SUM (NVL (closing_balance, 0)) -- End modification by BT Technology Team on 16-Dec-15
                                                                  - SUM (NVL (journal_amount, 0)), MAX (closing_balance)
                              INTO ln_opening_balance, ln_closing_balance
                              FROM XXD_GL_PJE_SUMMARY_GT
                             WHERE group_name = rec_acc_gorup.group_name --                               AND account_heads =
           --                                      rec_acc_heads.account_heads
                            ;
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            LOG (
                                   'Error while extracting opening balance - '
                                || SQLERRM);
                    END;

                    --                SELECT  closing_balance INTO ln_opening_balance
                    --                FROM XXD_GL_PJE_SUMMARY_GT
                    --                wHERE  group_name = rec_acc_gorup.group_name
                    --                AND account_heads = rec_acc_heads.account_heads
                    --                and rownum =1;
                    --log('ln_opening_balance and lv_jounral_amt is - '||ln_opening_balance||' and '||lv_jounral_amt);
                    --group by group_name, account_heads;
                    ln_sl_no_intial       := 0;

                    FOR rec_jrnl_amt IN CUR_jrnl_amt (rec_acc_gorup.group_name --                     ,
           --                                      rec_acc_heads.account_heads
                                                    )
                    LOOP
                        --ln_sl_no_intial :=0;
                        BEGIN
                            SELECT sl_no
                              INTO ln_sl_no
                              FROM XXD_GL_PJE_DOC_SEQ_GT
                             --start changes by BT Technology Team on 14 Dec 15 --Added NVL
                             WHERE NVL (doc_sequence_value, 'PJE') =
                                   NVL (rec_jrnl_amt.doc_sequence_value,
                                        'PJE');
                        --start changes by BT Technology Team on 14 Dec 15
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                --                           LOG (
                                --                                 'No Document Sequence found for Account Head - '
                                --                              || rec_acc_heads.account_heads);
                                ln_sl_no   := ln_sl_no_intial + 1;
                            WHEN OTHERS
                            THEN
                                --                           LOG (
                                --                                 'No document Sequence found for Account Head - '
                                --                              || rec_acc_heads.account_heads);
                                NULL;
                        END;

                        IF ln_sl_no_intial = 0 AND ln_sl_no != 0
                        THEN
                            FOR i IN 1 .. ln_sl_no
                            LOOP
                                lv_acc_head_rec   :=
                                    lv_acc_head_rec || CHR (9);
                            END LOOP;

                            ln_sl_no_intial       := ln_sl_no;
                            ln_max_sl_no_intial   := ln_sl_no;
                        --log('ln_sl_no_intial  1'||ln_sl_no_intial);
                        ELSE
                            FOR i IN ln_sl_no_intial + 1 .. ln_sl_no
                            LOOP
                                lv_acc_head_rec   :=
                                    lv_acc_head_rec || CHR (9);
                            END LOOP;

                            ln_sl_no_intial       := ln_sl_no;
                            ln_max_sl_no_intial   := ln_sl_no;
                        --log('ln_sl_no_intial 2'||ln_sl_no_intial);
                        END IF;

                        lv_acc_head_rec   :=
                            lv_acc_head_rec || rec_jrnl_amt.journal_amount;
                        LOG ('lv_acc_head_rec ' || lv_acc_head_rec);
                        --ln_sl_no_intial := ln_sl_no_intial+1;
                        LOG ('ln_sl_no_intial ' || ln_sl_no_intial);
                    END LOOP;

                    --lOGIC to print closing balance


                    BEGIN
                        SELECT MAX (sl_no)
                          INTO ln_max_sl_no
                          FROM XXD_GL_PJE_DOC_SEQ_GT;

                        FOR i IN ln_max_sl_no_intial + 1 .. ln_max_sl_no
                        LOOP
                            lv_acc_head_rec   := lv_acc_head_rec || CHR (9);
                        END LOOP;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            LOG (
                                   'Error while fetching max of document sequence position '
                                || SQLERRM);
                    END;

                    ln_max_sl_no_intial   := 0;
                    --log('ln_sl_no_intial 3'||ln_sl_no_intial);

                    output (
                           --                        rec_acc_heads.account_heads
                           rec_acc_gorup.group_name
                        || CHR (9)
                        || Ln_opening_balance                      -- ||chr(9)
                        || lv_acc_head_rec
                        || CHR (9)
                        || ln_closing_balance);

                    --apps.helloworld (lv_acc_head_rec);

                    lv_acc_head_rec       := NULL;
                END LOOP;


                --logic to calculate Total of Opening Balance
                --            BEGIN
                --               IF lt_c1_tab.COUNT > 1
                --               THEN
                --                  SELECT SUM (ln_total_ob) ln_total_ob
                --                    INTO ln_total_OB
                --                    FROM (  SELECT   MAX ( (NVL (closing_balance, 0)))
                --                                   - SUM (NVL (journal_amount, 0))
                --                                      ln_total_ob
                --                              FROM XXD_GL_PJE_SUMMARY_GT
                --                             WHERE     group_name = rec_acc_gorup.group_name
                --                                   AND ledger_id =
                --                                          (SELECT ledger_id
                --                                             FROM gl_ledgers
                --                                            WHERE name =
                --                                                     'Deckers Group Consolidation')
                --                          GROUP BY ACCOUNT_HEADS);
                --               ELSE
                --                  SELECT SUM (ln_total_ob) ln_total_ob
                --                    INTO ln_total_OB
                --                    FROM (  SELECT   MAX ( (NVL (closing_balance, 0)))
                --                                   - SUM (NVL (journal_amount, 0))
                --                                      ln_total_ob
                --                              FROM XXD_GL_PJE_SUMMARY_GT
                --                             WHERE group_name = rec_acc_gorup.group_name
                --                          GROUP BY ACCOUNT_HEADS);
                --               END IF;
                --            EXCEPTION
                --               WHEN OTHERS
                --               THEN
                --                  LOG (
                --                        'Error while calcualting Sum('
                --                     || rec_acc_gorup.group_name
                --                     || ') '
                --                     || SQLERRM);
                --            END;
                --
                --
                --            --logic to calculate toatal of closing balance
                --
                --            BEGIN
                --               IF lt_c1_tab.COUNT > 1
                --               THEN
                --                  SELECT SUM (ln_total_cb) ln_total_ob
                --                    INTO ln_total_cB
                --                    FROM (  SELECT MAX ( (NVL (closing_balance, 0)))
                --                                      ln_total_cb
                --                              FROM XXD_GL_PJE_SUMMARY_GT
                --                             WHERE     group_name = rec_acc_gorup.group_name
                --                                   AND ledger_id =
                --                                          (SELECT ledger_id
                --                                             FROM gl_ledgers
                --                                            WHERE name =
                --                                                     'Deckers Group Consolidation')
                --                          GROUP BY ACCOUNT_HEADS);
                --               ELSE
                --                  SELECT SUM (ln_total_cb) ln_total_ob
                --                    INTO ln_total_cB
                --                    FROM (  SELECT MAX ( (NVL (closing_balance, 0)))
                --                                      ln_total_cb
                --                              FROM XXD_GL_PJE_SUMMARY_GT
                --                             WHERE group_name = rec_acc_gorup.group_name
                --                          GROUP BY ACCOUNT_HEADS);
                --               END IF;
                --
                --               LOG ('ln_max_sl_no =>' || ln_max_sl_no);
                --
                --               FOR i IN 2 .. ln_max_sl_no
                --               LOOP
                --                  lv_cb_pos := lv_cb_pos || CHR (9);
                --               END LOOP;
                --
                --               lv_cb_pos := lv_cb_pos || ln_total_cB;
                --            EXCEPTION
                --               WHEN OTHERS
                --               THEN
                --                  LOG (
                --                        'Error while calcualting Closing balance Sum('
                --                     || rec_acc_gorup.group_name
                --                     || ') '
                --                     || SQLERRM);
                --            END;



                --               output (
                --                     rec_acc_gorup.group_name
                --                  || CHR (9)
                --                  || ln_total_OB
                --                  || CHR (9)
                --                  || CHR (9)
                --                  || lv_cb_pos);
                lv_cb_pos   := NULL;
            --            END LOOP;
            END;
        --select doc_seq_tab.sl_no into ln_doc_seq_sl_no from dual where doc_seq_tab.doc_sequence = 1;
        --output(ln_doc_seq_sl_no);
        END IF;
    /*
    if ln_count >=1 then
    /*l_layout_status :=
          apps.fnd_request.add_layout (template_appl_name   => 'XXDO',
                                       template_code        => 'XLAACCPB01',
                                       template_language    => 'en',
                                       template_territory   => 'US',
                                       output_format        => 'EXCEL');

       /* Submitting the Create Accounting Program by fnd request
       l_request_id :=
          fnd_request.submit_request ('XXDO',
                                      'XXD_GL_PJE_SUMMARY_RPT1',
                                      'Deckers GL PJE Roll Forward Summary Report',
                                      SYSDATE,
                                      FALSE,
                                      rec_create_acct.application_id,
                                      rec_create_acct.application_id,
                                      'Y',
                                      rec_create_acct.ledger_id,    --Ledger
                                      i_srce_code,        --Process Category
                                      TO_CHAR (l_jrnl_date, 'YYYY/MM/DD'), --End Date
                                      'Y',
                                      'Y',
                                      'F',                 --Accounting Mode
                                      'Y',
                                      'N',                      --Error only
                                      'D', --'S',--'N',                         --Report
                                      'Y',                  --Transfer to GL
                                      NULL,
                                      NULL,
    end if;*/

    EXCEPTION
        WHEN OTHERS
        THEN
            LOG (
                   'Error while displayin PJE Roll Forward Summary Report - '
                || SQLERRM);
    END;

    /* FUNCTION proc_roll_forward_summary_rpt
        RETURN BOOLEAN
     IS
     BEGIN
        proc_roll_forward_summary (pv_period_type,
                                   pv_currency_type,
                                   pn_ledger_id,
                                   pv_currency_code,
                                   pv_period_name,
                                   pv_je_source,
                                   pv_je_category,
                                   pv_period_close_date);

        RETURN TRUE;
     EXCEPTION
        WHEN OTHERS
        THEN
           LOG (
                 'Error while displayin PJE Roll Forward Summary Report - '
              || SQLERRM);
           RETURN FALSE;
     END;
  */

    PROCEDURE proc_roll_forward_main (errbuff                   OUT VARCHAR2,
                                      retcode                   OUT NUMBER,
                                      pv_ledger_name                VARCHAR2,
                                      pn_ledger_id                  NUMBER,
                                      pv_currency_code              VARCHAR2,
                                      Pv_report_level               VARCHAR2, -- SUMMARY OR DETAIL
                                      pv_dummy_param                VARCHAR2,
                                      pv_balance_type               VARCHAR2,
                                      pv_period_name                VARCHAR2,
                                      pv_je_source                  VARCHAR2,
                                      pv_je_category                VARCHAR2,
                                      pv_period_close_from_dt       VARCHAR2,
                                      pv_period_close_to_dt         VARCHAR2,
                                      pv_row_set_name               VARCHAR2)
    AS
        lv_period_close_char      VARCHAR2 (20);
        ld_period_close_date      DATE;
        ld_period_close_from_dt   DATE;
        ld_period_close_to_dt     DATE;
    BEGIN
        LOG (pv_period_close_date);
        lv_period_close_char   :=
            TO_CHAR (TO_DATE (pv_period_close_date, 'YYYY/MM/DD HH24:Mi:ss'),
                     'MM/DD/YYYY HH24:Mi:ss');
        LOG (lv_period_close_char);

        ld_period_close_from_dt   :=
            FND_DATE.CANONICAL_TO_DATE (pv_period_close_from_dt); --FND_DATE.canonical_to_date(lv_period_close_char);--to_date(lv_period_close_char, 'DD/MM/YYYY HH24:Mi:ss');--FND_DATE.canonical_to_date(lv_period_close_char);

        ld_period_close_to_dt   :=
            FND_DATE.CANONICAL_TO_DATE (pv_period_close_to_dt);
        LOG (ld_period_close_date);

        IF Pv_report_level = 'Detail'
        THEN
            proc_roll_forward_detail (pn_ledger_id, pv_currency_code, pv_period_name, pv_je_source, pv_je_category, ld_period_close_from_dt
                                      , ld_period_close_to_dt);
        ELSIF Pv_report_level = 'Summary'
        THEN
            proc_roll_forward_summary (pv_balance_type, NULL, pn_ledger_id,
                                       pv_currency_code, pv_period_name, pv_je_source, pv_je_category, ld_period_close_from_dt, ld_period_close_to_dt
                                       , pv_row_set_name);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            LOG ('Exception Others at @proc_roll_forward_main ' || SQLERRM);
    END proc_roll_forward_main;
END;
/
