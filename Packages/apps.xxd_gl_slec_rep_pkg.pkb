--
-- XXD_GL_SLEC_REP_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:49 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_SLEC_REP_PKG"
AS
    /******************************************************************************
     NAME: APPS.XXD_GL_SLEC_REP_PKG
     REP NAME: GL Secondary Ledger Entered Currency Report - Deckers

     REVISIONS:
     Ver       Date       Author          Description
     --------- ---------- --------------- ------------------------------------
     1.0       01/22/19   Madhav Dhurjaty Initial Version - CCR0007749
    ******************************************************************************/
    PROCEDURE get_ledger_ids (p_in_company IN VARCHAR2, x_primary_ledger_id OUT VARCHAR2, x_secondary_ledger_id OUT VARCHAR2)
    IS
    BEGIN
        SELECT ffv.attribute6, ffv.attribute8
          INTO x_primary_ledger_id, x_secondary_ledger_id
          FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
         WHERE     1 = 1
               AND ffvs.flex_value_set_id = ffv.flex_value_set_id
               AND ffvs.flex_value_set_name = 'DO_GL_COMPANY'
               AND ffv.flex_value = p_company;

        IF x_primary_ledger_id IS NULL OR x_secondary_ledger_id IS NULL
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Primary and Secondary Ledger IDs unavailable for the company:'
                || p_company);
            RAISE_APPLICATION_ERROR (
                -20300,
                   'Primary and Secondary Ledger IDs unavailable for the company:'
                || p_company);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in get_ledger_ids:' || SQLERRM);
            RAISE_APPLICATION_ERROR (
                -20301,
                SUBSTR ('Error in get_ledger_ids:' || SQLERRM, 1, 240));
    END get_ledger_ids;

    --
    --
    PROCEDURE set_period_set_name (p_ledger_id IN NUMBER)
    IS
    BEGIN
        SELECT period_set_name
          INTO g_period_set_name
          FROM gl_ledgers gll
         WHERE 1 = 1 AND ledger_id = p_ledger_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in set_period_set_name:' || SQLERRM);
    --            RAISE_APPLICATION_ERROR (-20301, SUBSTR('Error in get_ledger_ids:'||SQLERRM,1,240));
    END set_period_set_name;

    --
    --
    FUNCTION get_period_start_date (p_period_name IN VARCHAR2)
        RETURN DATE
    IS
        ld_period_start_date   DATE;
    BEGIN
        SELECT start_date
          INTO ld_period_start_date
          FROM gl_periods
         WHERE     1 = 1
               AND period_set_name = G_PERIOD_SET_NAME
               AND period_name = p_period_name;

        RETURN ld_period_start_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in get_period_start_date:' || SQLERRM);
            RETURN NULL;
    END get_period_start_date;

    --
    --
    FUNCTION get_period_end_date (p_period_name IN VARCHAR2)
        RETURN DATE
    IS
        ld_period_end_date   DATE;
    BEGIN
        SELECT end_date
          INTO ld_period_end_date
          FROM gl_periods
         WHERE     1 = 1
               AND period_set_name = G_PERIOD_SET_NAME
               AND period_name = p_period_name;

        RETURN ld_period_end_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in get_period_end_date:' || SQLERRM);
            RETURN NULL;
    END get_period_end_date;

    --
    --
    /*
    PROCEDURE insert_currencies (p_primary_ledger_id    IN   NUMBER
                                ,p_secondary_ledger_id  IN   NUMBER
                                ,p_start_date           IN   DATE
                                ,p_end_date             IN   DATE)
    AS
        CURSOR c_curr
            IS SELECT DISTINCT CURRENCY_CODE
                 FROM gl_balances
                WHERE 1=1
                  AND (ledger_id = p_primary_ledger_id OR  ledger_id = p_secondary_ledger_id )
                  AND period_name IN (SELECT period_name--, period_num
                                        FROM gl_periods
                                       WHERE period_set_name = g_period_set_name --'DO_FY_CALENDAR'--
                                         AND start_date >= p_start_date
                                         AND end_date <= p_end_date)
                ORDER BY 1;

        ln_count NUMBER := 0;

    BEGIN
        FOR i IN C_CURR
        LOOP
            ln_count := ln_count+1;
            INSERT INTO xxd_gl_slec_currencies_gt
                (currnum, currency_code)
            VALUES
                (ln_count, i.currency_code);
        END LOOP;

    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE(FND_FILE.LOG,'Error in insert_currencies:'||SQLERRM);
            RAISE_APPLICATION_ERROR (-20303, SUBSTR('Error in insert_currencies:'||SQLERRM,1,240));
    END insert_currencies;
    */
    --
    --
    FUNCTION get_first_period (p_ledger_id     IN NUMBER,
                               p_period_name   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_first_period   VARCHAR2 (30);
    BEGIN
        SELECT a.period_name
          INTO lv_first_period
          FROM gl_period_statuses a, gl_period_statuses b
         WHERE     a.application_id = 101
               AND b.application_id = 101
               AND a.ledger_id = p_ledger_id
               AND b.ledger_id = p_ledger_id
               AND a.period_type = b.period_type
               AND a.period_year = b.period_year
               AND b.period_name = p_period_name
               AND a.period_num =
                   (  SELECT MIN (c.period_num)
                        FROM gl_period_statuses c
                       WHERE     c.application_id = 101
                             AND c.ledger_id = p_ledger_id
                             AND c.period_year = a.period_year
                             AND c.period_type = a.period_type
                    GROUP BY c.period_year);

        RETURN lv_first_period;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Error in get_first_period :'
                || 'PERIOD:'
                || p_period_name
                || 'LEDID:'
                || p_ledger_id);
            RETURN NULL;
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in get_first_period :' || SQLERRM);
            RETURN NULL;
    END get_first_period;

    --
    --
    /*
    FUNCTION get_balance (p_ledger_id   IN   NUMBER
                         ,p_period_name IN   VARCHAR2
                         )
    RETURN NUMBER
    IS
        ln_balance   NUMBER;
    BEGIN
        SELECT

    END get_balance;*/
    --
    --
    /*
    PROCEDURE insert_staging
    AS
    BEGIN
        NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END insert_staging;
    */
    --
    --
    FUNCTION before_report
        RETURN BOOLEAN
    AS
        ld_period_from_start     DATE;
        ld_period_from_end       DATE;
        ld_period_to_start       DATE;
        ld_period_to_end         DATE;
        lv_primary_ledger_id     VARCHAR2 (30);
        lv_secondary_ledger_id   VARCHAR2 (30);
        lv_first_period          VARCHAR2 (15);
        lv_step                  VARCHAR2 (30);
        ex_no_ledger_ids         EXCEPTION;
        lv_warning_message       VARCHAR2 (2000) := NULL;
        lb_result                BOOLEAN;
        ln_count                 NUMBER := 0;


        CURSOR c_companies IS
              SELECT ffv.flex_value, attribute8 secondary_ledger_id, attribute6 primary_ledger_id
                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
               WHERE     1 = 1
                     AND ffvs.flex_value_set_id = ffv.flex_value_set_id
                     AND ffvs.flex_value_set_name = 'DO_GL_COMPANY'
                     AND ffv.enabled_flag = 'Y'
                     AND NVL (ffv.start_date_active, SYSDATE) <= SYSDATE
                     AND NVL (ffv.end_date_active, SYSDATE + 1) > SYSDATE
                     AND ffv.flex_value = NVL (P_COMPANY, ffv.flex_value)
            ORDER BY 1;

        CURSOR c_periods (p_start_date IN DATE, p_end_date IN DATE)
        IS
              SELECT period_name                                --, period_num
                FROM gl_periods
               WHERE     period_set_name = g_period_set_name --'DO_FY_CALENDAR'
                     AND start_date >= p_start_date
                     AND end_date <= p_end_date
            ORDER BY start_date;
    BEGIN
        lv_step   := '01';
        --Print Parameters
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'P_COMPANY:' || P_COMPANY);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'P_PERIOD_FROM:' || P_PERIOD_FROM);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'P_PERIOD_TO:' || P_PERIOD_TO);
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'P_INTERCOMPANY_ONLY:' || P_INTERCOMPANY_ONLY);
        FND_FILE.PUT_LINE (FND_FILE.LOG, 'P_PERIOD_TYPE:' || P_PERIOD_TYPE);

        EXECUTE IMMEDIATE 'TRUNCATE TABLE xxdo.xxd_gl_slec_rep_gt';

        FOR cur_companies IN c_companies
        LOOP
            --lv_warning_message := NULL;
            lv_primary_ledger_id     := cur_companies.primary_ledger_id;
            lv_secondary_ledger_id   := cur_companies.secondary_ledger_id;

            BEGIN
                --get_ledger_ids (cur_companies.flex_value, lv_primary_ledger_id, lv_secondary_ledger_id );
                IF    lv_primary_ledger_id IS NULL
                   OR lv_secondary_ledger_id IS NULL
                THEN
                    RAISE ex_no_ledger_ids;
                END IF;

                lv_step                := '02';

                set_period_set_name (lv_primary_ledger_id);
                lv_step                := '03';
                --Get Relevant values
                ld_period_from_start   :=
                    get_period_start_date (P_PERIOD_FROM);
                ld_period_from_end     := get_period_end_date (P_PERIOD_FROM);
                ld_period_to_start     := get_period_start_date (P_PERIOD_TO);
                ld_period_to_end       := get_period_end_date (P_PERIOD_TO);
                lv_step                := '03';

                --Check if periods are valid
                IF    (ld_period_from_start > ld_period_to_start)
                   OR (ld_period_from_end > ld_period_from_end)
                THEN
                    lv_step   := '04';
                    RAISE_APPLICATION_ERROR (
                        -20302,
                        'Invalid From and To periods. Please make sure To period is later than from period.');
                END IF;

                lv_step                := '05';

                /*
                insert_currencies (p_primary_ledger_id    => lv_primary_ledger_id
                                  ,p_secondary_ledger_id  => lv_secondary_ledger_id
                                  ,p_start_date           => ld_period_from_start
                                  ,p_end_date             => ld_period_to_end);
                */
                FOR i IN c_periods (ld_period_from_start, ld_period_to_end)
                LOOP
                    --Get first period
                    lv_step   :=
                           '06 - '
                        || i.period_name
                        || ' - '
                        || lv_primary_ledger_id;
                    lv_first_period   :=
                        get_first_period (
                            p_ledger_id     => lv_primary_ledger_id,
                            p_period_name   => i.period_name);

                    BEGIN
                        -----------------------------------------------------------------
                        --Inserting 01 - Secondary Total Balance (Entered Currency)
                        -----------------------------------------------------------------
                        lv_step   :=
                               '06.1 - '
                            || i.period_name
                            || ' - '
                            || lv_primary_ledger_id;

                        INSERT INTO xxdo.xxd_gl_slec_rep_gt (
                                        query_type,
                                        ledger_id,
                                        ledger_name,
                                        period_name,
                                        code_combination_id,
                                        concatenated_segments,
                                        currency_code,
                                        amount)
                              SELECT '01 - Secondary Total Balance (Entered Currency)' query_type, GLB.ledger_id, gll.name ledgername,
                                     GLB.period_name, GLB.code_combination_id, gcc.concatenated_segments,
                                     GLB.currency_code, DECODE (p_period_type,  'PTD', SUM (DECODE ('E',  'T', NVL (period_net_dr, 0) - NVL (period_net_cr, 0),  'S', NVL (period_net_dr, 0) - NVL (period_net_cr, 0),  'E', DECODE (GLB.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)),  'C', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))),  'YTD', SUM (DECODE (GLB.translated_flag, 'R', DECODE (GLB.period_name, i.period_name, NVL (period_net_dr, 0) - NVL (period_net_cr, 0) + NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0), DECODE (GLB.period_name, i.period_name, NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0) + NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0)))) amt
                                FROM gl_balances GLB, gl_code_combinations_kfv gcc, gl_ledgers gll
                               WHERE     1 = 1
                                     AND GLB.ledger_id = gll.ledger_id
                                     AND GLB.code_combination_id =
                                         gcc.code_combination_id
                                     AND GLB.period_name = i.period_name
                                     AND GLB.ledger_id = lv_secondary_ledger_id --2133
                                     AND gcc.segment1 =
                                         cur_companies.flex_value
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_INTERCOMPANY_ACCOUNTS'
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE
                                                     AND DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', ffv.flex_value,
                                                             1) =
                                                         DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', gcc.segment6,
                                                             1))
                            GROUP BY GLB.ledger_id, gll.name, GLB.period_name,
                                     GLB.code_combination_id, gcc.concatenated_segments, GLB.currency_code,
                                     '01 - Secondary Total Balance (Entered Currency)'
                            -----------------------------------------------------------------
                            --Inserting 02 - Local GAAP Adjustments
                            -----------------------------------------------------------------
                            UNION ALL
                              SELECT '02 - Local GAAP Adjustments' query_type, gll.ledger_id, gll.name ledgername,
                                     jl.period_name, jl.code_combination_id, gcc.concatenated_segments,
                                     jh.currency_code, SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0)) amt
                                FROM gl_je_lines jl, gl_je_headers jh, gl_code_combinations_kfv gcc,
                                     gl_ledgers gll
                               WHERE     1 = 1
                                     AND jl.je_header_id = jh.je_header_id
                                     AND jl.code_combination_id =
                                         gcc.code_combination_id
                                     AND jl.ledger_id = gll.ledger_id
                                     AND jh.status = 'P'
                                     AND jl.status = 'P'
                                     AND jh.period_name = i.period_name
                                     AND gcc.segment1 =
                                         cur_companies.flex_value
                                     AND DECODE (P_PERIOD_TYPE, 'PTD', 1, 2) =
                                         1
                                     AND jh.je_category IN
                                             (SELECT jc.je_category_name
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, gl_je_categories jc
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_JOURNAL_CATEGORIES'
                                                     AND ffv.flex_value =
                                                         jc.user_je_category_name
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND jc.language = 'US'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE)
                                     AND jh.ledger_id = lv_secondary_ledger_id
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_INTERCOMPANY_ACCOUNTS'
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE
                                                     AND DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', ffv.flex_value,
                                                             1) =
                                                         DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', gcc.segment6,
                                                             1))
                            GROUP BY gll.ledger_id, gll.name, jl.period_name,
                                     jl.code_combination_id, gcc.concatenated_segments, jh.currency_code
                            UNION
                              SELECT '02 - Local GAAP Adjustments' query_type, gll.ledger_id, gll.name ledgername,
                                     --jl.period_name,
                                     i.period_name period_name, jl.code_combination_id, gcc.concatenated_segments,
                                     jh.currency_code, SUM (NVL (entered_dr, 0) - NVL (entered_cr, 0)) amt
                                FROM gl_je_lines jl, gl_je_headers jh, gl_code_combinations_kfv gcc,
                                     gl_ledgers gll
                               WHERE     1 = 1
                                     AND jl.je_header_id = jh.je_header_id
                                     AND jl.code_combination_id =
                                         gcc.code_combination_id
                                     AND gcc.segment1 =
                                         cur_companies.flex_value
                                     AND jl.ledger_id = gll.ledger_id
                                     AND jh.status = 'P'
                                     AND jl.status = 'P'
                                     AND jl.effective_date >=
                                         (SELECT gp1.year_start_date
                                            FROM gl_periods gp1
                                           WHERE     1 = 1
                                                 AND gp1.period_set_name =
                                                     gll.period_set_name
                                                 AND gp1.period_name =
                                                     i.period_name)
                                     AND jl.effective_date <=
                                         (SELECT gp1.end_date
                                            FROM gl_periods gp1
                                           WHERE     1 = 1
                                                 AND gp1.period_set_name =
                                                     gll.period_set_name
                                                 AND gp1.period_name =
                                                     i.period_name)
                                     AND DECODE (P_PERIOD_TYPE, 'YTD', 1, 2) =
                                         1
                                     AND jh.je_category IN
                                             (SELECT jc.je_category_name
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, gl_je_categories jc
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_JOURNAL_CATEGORIES'
                                                     AND ffv.flex_value =
                                                         jc.user_je_category_name
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND jc.language = 'US'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE)
                                     AND jh.ledger_id = lv_secondary_ledger_id
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_INTERCOMPANY_ACCOUNTS'
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE
                                                     AND DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', ffv.flex_value,
                                                             1) =
                                                         DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', gcc.segment6,
                                                             1))
                            GROUP BY gll.ledger_id, gll.name, --jl.period_name,
                                                              i.period_name,
                                     jl.code_combination_id, gcc.concatenated_segments, jh.currency_code
                            -----------------------------------------------------------
                            --Inserting 04 - Primary Balances (Entered Currency)
                            -----------------------------------------------------------
                            UNION ALL
                              SELECT '04 - Primary Balances (Entered Currency)' query_type, GLB.ledger_id, gll.name ledgername,
                                     GLB.period_name, GLB.code_combination_id, gcc.concatenated_segments,
                                     GLB.currency_code, DECODE (p_period_type,  'PTD', SUM (DECODE ('E',  'T', NVL (period_net_dr, 0) - NVL (period_net_cr, 0),  'S', NVL (period_net_dr, 0) - NVL (period_net_cr, 0),  'E', DECODE (GLB.translated_flag, 'R', NVL (period_net_dr, 0) - NVL (period_net_cr, 0), NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0)),  'C', NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0))),  'YTD', SUM (DECODE (GLB.translated_flag, 'R', DECODE (GLB.period_name, i.period_name, NVL (period_net_dr, 0) - NVL (period_net_cr, 0) + NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0), DECODE (GLB.period_name, i.period_name, NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0) + NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0)))) amt
                                FROM gl_balances GLB, gl_code_combinations_kfv gcc, gl_ledgers gll
                               WHERE     1 = 1
                                     AND GLB.ledger_id = gll.ledger_id
                                     AND GLB.code_combination_id =
                                         gcc.code_combination_id
                                     AND GLB.period_name = i.period_name
                                     AND GLB.ledger_id = lv_primary_ledger_id --2133
                                     AND gcc.segment1 =
                                         cur_companies.flex_value
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_INTERCOMPANY_ACCOUNTS'
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE
                                                     AND DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', ffv.flex_value,
                                                             1) =
                                                         DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', gcc.segment6,
                                                             1))
                            GROUP BY GLB.ledger_id, gll.name, GLB.period_name,
                                     GLB.code_combination_id, gcc.concatenated_segments, GLB.currency_code
                            -----------------------------------------------------------
                            --Inserting 07 - Secondary YTD Balances (Accounted currency)
                            -----------------------------------------------------------
                            UNION ALL
                              SELECT '06 - Secondary YTD Balances (Accounted currency)' query_type, GLB.ledger_id, gll.name ledgername,
                                     GLB.period_name, GLB.code_combination_id, gcc.concatenated_segments,
                                     GLB.currency_code, DECODE ('T',  'T', SUM (DECODE (GLB.period_name, i.period_name, NVL (period_net_dr, 0) - NVL (period_net_cr, 0) + NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0)),  'S', SUM (DECODE (GLB.period_name, i.period_name, NVL (period_net_dr, 0) - NVL (period_net_cr, 0) + NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0)),  'E', SUM (DECODE (GLB.translated_flag, 'R', DECODE (GLB.period_name, i.period_name, NVL (period_net_dr, 0) - NVL (period_net_cr, 0) + NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr, 0) - NVL (begin_balance_cr, 0), 0), DECODE (GLB.period_name, i.period_name, NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0) + NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0))),  'C', SUM (DECODE (GLB.period_name, i.period_name, NVL (period_net_dr_beq, 0) - NVL (period_net_cr_beq, 0) + NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0) - DECODE (GLB.period_name, lv_first_period, NVL (begin_balance_dr_beq, 0) - NVL (begin_balance_cr_beq, 0), 0))) amt
                                FROM gl_balances GLB, gl_code_combinations_kfv gcc, gl_ledgers gll
                               WHERE     1 = 1
                                     AND GLB.ledger_id = gll.ledger_id
                                     AND GLB.code_combination_id =
                                         gcc.code_combination_id
                                     AND GLB.period_name = i.period_name
                                     AND GLB.ledger_id = lv_secondary_ledger_id --2051--2133
                                     AND gcc.segment1 =
                                         cur_companies.flex_value
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_INTERCOMPANY_ACCOUNTS'
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE
                                                     AND DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', ffv.flex_value,
                                                             1) =
                                                         DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', gcc.segment6,
                                                             1))
                            GROUP BY GLB.ledger_id, gll.name, GLB.period_name,
                                     GLB.code_combination_id, gcc.concatenated_segments, GLB.currency_code
                            ---------------------------------------------------------------
                            --Inserting 08 - Secondary YTD Adjustments (Accounted currency)
                            ---------------------------------------------------------------
                            UNION ALL
                              SELECT '07 - Secondary YTD Adjustments (Accounted currency)' query_type, gll.ledger_id, gll.name ledgername,
                                     i.period_name "period_name", jl.code_combination_id, gcc.concatenated_segments,
                                     jh.currency_code, SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)) amt
                                FROM gl_je_lines jl, gl_je_headers jh, gl_code_combinations_kfv gcc,
                                     gl_ledgers gll
                               WHERE     1 = 1
                                     AND jl.je_header_id = jh.je_header_id
                                     AND jl.code_combination_id =
                                         gcc.code_combination_id
                                     AND jl.ledger_id = gll.ledger_id
                                     AND gcc.segment1 =
                                         cur_companies.flex_value
                                     AND jh.status = 'P'
                                     AND jl.status = 'P'
                                     AND jl.effective_date >=
                                         (SELECT gp.year_start_date
                                            FROM gl_periods gp
                                           WHERE     gp.period_name =
                                                     i.period_name
                                                 AND gp.period_set_name =
                                                     gll.period_set_name)
                                     --AND jh.period_name = 'JAN-18'
                                     AND jl.effective_date <=
                                         (SELECT gp.end_date
                                            FROM gl_periods gp
                                           WHERE     gp.period_name =
                                                     i.period_name
                                                 AND gp.period_set_name =
                                                     gll.period_set_name)
                                     --AND   jh.je_category = '5'
                                     AND jh.je_category IN
                                             (SELECT jc.je_category_name
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv, gl_je_categories jc
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_JOURNAL_CATEGORIES'
                                                     AND ffv.flex_value =
                                                         jc.user_je_category_name
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND jc.language = 'US'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE)
                                     AND jh.ledger_id = lv_secondary_ledger_id
                                     AND gcc.gl_account_type IN ('R', 'E')
                                     AND EXISTS
                                             (SELECT 1
                                                FROM fnd_flex_value_sets ffvs, fnd_flex_values ffv
                                               WHERE     1 = 1
                                                     AND ffvs.flex_value_set_id =
                                                         ffv.flex_value_set_id
                                                     AND ffvs.flex_value_set_name =
                                                         'XXD_GL_SLEC_INTERCOMPANY_ACCOUNTS'
                                                     AND ffv.enabled_flag = 'Y'
                                                     AND NVL (
                                                             ffv.start_date_active,
                                                             SYSDATE) <=
                                                         SYSDATE
                                                     AND NVL (
                                                             ffv.end_date_active,
                                                             SYSDATE + 1) >
                                                         SYSDATE
                                                     AND DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', ffv.flex_value,
                                                             1) =
                                                         DECODE (
                                                             P_INTERCOMPANY_ONLY,
                                                             'Y', gcc.segment6,
                                                             1))
                            GROUP BY gll.ledger_id, gll.name, jl.period_name,
                                     jl.code_combination_id, gcc.concatenated_segments, jh.currency_code;

                        --COMMIT;
                        --Check if there are any 02 values exist
                        BEGIN
                            ln_count   := 0;

                            SELECT COUNT (1)
                              INTO ln_count
                              FROM xxdo.xxd_gl_slec_rep_gt
                             WHERE     1 = 1
                                   AND query_type =
                                       '02 - Local GAAP Adjustments'
                                   AND period_name = i.period_name
                                   AND ledger_id = lv_secondary_ledger_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_count   := 0;
                        END;

                        IF ln_count = 0
                        THEN
                            INSERT INTO xxdo.xxd_gl_slec_rep_gt (
                                            query_type,
                                            ledger_id,
                                            ledger_name,
                                            period_name,
                                            code_combination_id,
                                            concatenated_segments,
                                            currency_code,
                                            amount)
                                SELECT '02 - Local GAAP Adjustments' query_type, ledger_id, ledger_name,
                                       period_name, code_combination_id, concatenated_segments,
                                       currency_code, 0 amt
                                  FROM xxdo.xxd_gl_slec_rep_gt
                                 WHERE     1 = 1
                                       AND query_type =
                                           '01 - Secondary Total Balance (Entered Currency)';
                        END IF;

                        -----------------------------------------------------------------
                        --Inserting 03 - Secondary Net Balances (Entered Currency)
                        -----------------------------------------------------------------
                        --(A left outer join B) UNION (B left outer join A)
                        lv_step   :=
                               '06.6 - '
                            || i.period_name
                            || ' - '
                            || lv_primary_ledger_id;

                        INSERT INTO xxdo.xxd_gl_slec_rep_gt (
                                        query_type,
                                        ledger_id,
                                        ledger_name,
                                        period_name,
                                        code_combination_id,
                                        concatenated_segments,
                                        currency_code,
                                        amount)
                            SELECT x.query_type, x.ledger_id, x.ledger_name,
                                   x.period_name, x.code_combination_id, x.concatenated_segments,
                                   x.currency_code, x.amount
                              FROM (  SELECT '03 - Secondary Net Balances (Entered Currency)' query_type, a.ledger_id, a.ledger_name,
                                             a.period_name, a.code_combination_id, a.concatenated_segments,
                                             a.currency_code, SUM (NVL (a.amount, 0) - NVL (b.amount, 0)) amount
                                        FROM xxdo.xxd_gl_slec_rep_gt a, xxdo.xxd_gl_slec_rep_gt b
                                       WHERE     1 = 1
                                             AND a.ledger_id = b.ledger_id(+)
                                             AND a.period_name =
                                                 b.period_name(+)
                                             AND a.code_combination_id =
                                                 b.code_combination_id(+)
                                             AND a.currency_code =
                                                 b.currency_code(+)
                                             AND a.query_type =
                                                 '01 - Secondary Total Balance (Entered Currency)'
                                             AND b.query_type =
                                                 '02 - Local GAAP Adjustments'
                                    GROUP BY '03 - Secondary Net Balances (Entered Currency)', a.ledger_id, a.ledger_name,
                                             a.period_name, a.code_combination_id, a.concatenated_segments,
                                             a.currency_code
                                    UNION
                                      SELECT '03 - Secondary Net Balances (Entered Currency)' query_type, a.ledger_id, a.ledger_name,
                                             a.period_name, a.code_combination_id, a.concatenated_segments,
                                             a.currency_code, SUM (NVL (b.amount, 0) - NVL (a.amount, 0)) amount
                                        FROM xxdo.xxd_gl_slec_rep_gt a, xxdo.xxd_gl_slec_rep_gt b
                                       WHERE     1 = 1
                                             AND a.ledger_id = b.ledger_id(+)
                                             AND a.period_name =
                                                 b.period_name(+)
                                             AND a.code_combination_id =
                                                 b.code_combination_id(+)
                                             AND a.currency_code =
                                                 b.currency_code(+)
                                             AND a.query_type =
                                                 '02 - Local GAAP Adjustments'
                                             AND b.query_type =
                                                 '01 - Secondary Total Balance (Entered Currency)'
                                    GROUP BY '03 - Secondary Net Balances (Entered Currency)', a.ledger_id, a.ledger_name,
                                             a.period_name, a.code_combination_id, a.concatenated_segments,
                                             a.currency_code) x;

                        --COMMIT;
                        -----------------------------------------------------------------
                        --Inserting 05 - Differences (03 - 04)
                        -----------------------------------------------------------------
                        --(A left outer join B) UNION (B left outer join A)
                        INSERT INTO xxdo.xxd_gl_slec_rep_gt (
                                        query_type,
                                        ledger_id,
                                        ledger_name,
                                        period_name,
                                        code_combination_id,
                                        concatenated_segments,
                                        currency_code,
                                        amount)
                            SELECT x.query_type, x.ledger_id, x.ledger_name,
                                   x.period_name, x.code_combination_id, x.concatenated_segments,
                                   x.currency_code, x.amount
                              FROM (  SELECT '05 - Differences (03 - 04)' query_type, NULL ledger_id, NULL ledger_name,
                                             a.period_name, a.code_combination_id, a.concatenated_segments,
                                             a.currency_code, SUM (NVL (a.amount, 0) - NVL (b.amount, 0)) amount
                                        FROM xxdo.xxd_gl_slec_rep_gt a, xxdo.xxd_gl_slec_rep_gt b
                                       WHERE     1 = 1
                                             --AND a.ledger_id = b.ledger_id (+)
                                             AND a.period_name =
                                                 b.period_name(+)
                                             AND a.code_combination_id =
                                                 b.code_combination_id(+)
                                             AND a.currency_code =
                                                 b.currency_code(+)
                                             AND a.query_type =
                                                 '03 - Secondary Net Balances (Entered Currency)'
                                             AND b.query_type =
                                                 '04 - Primary Balances (Entered Currency)'
                                    GROUP BY '05 - Differences (03 - 04)', --a.ledger_id,
                                                                           --a.ledger_name,
                                                                           a.period_name, a.code_combination_id,
                                             a.concatenated_segments, a.currency_code
                                    UNION
                                      SELECT '05 - Differences (03 - 04)' query_type, NULL ledger_id, NULL ledger_name,
                                             a.period_name, a.code_combination_id, a.concatenated_segments,
                                             a.currency_code, SUM (NVL (b.amount, 0) - NVL (a.amount, 0)) amount
                                        FROM xxdo.xxd_gl_slec_rep_gt a, xxdo.xxd_gl_slec_rep_gt b
                                       WHERE     1 = 1
                                             --AND a.ledger_id = b.ledger_id (+)
                                             AND a.period_name =
                                                 b.period_name(+)
                                             AND a.code_combination_id =
                                                 b.code_combination_id(+)
                                             AND a.currency_code =
                                                 b.currency_code(+)
                                             AND a.query_type =
                                                 '04 - Primary Balances (Entered Currency)'
                                             AND b.query_type =
                                                 '03 - Secondary Net Balances (Entered Currency)'
                                    GROUP BY '05 - Differences (03 - 04)', --a.ledger_id,
                                                                           --a.ledger_name,
                                                                           a.period_name, a.code_combination_id,
                                             a.concatenated_segments, a.currency_code)
                                   x;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            FND_FILE.PUT_LINE (
                                FND_FILE.LOG,
                                   'Error in Inserting for Period:'
                                || i.period_name
                                || ' - '
                                || lv_step
                                || SQLERRM);
                    END;
                --COMMIT;
                END LOOP;
            EXCEPTION
                WHEN ex_no_ledger_ids
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Invalid Primary and/or Secondary Ledger ID for the Company :'
                        || cur_companies.flex_value);
                    lv_warning_message   :=
                           lv_warning_message
                        || 'Missing Primary and/or Secondary Ledger ID for the Company :'
                        || cur_companies.flex_value;
                WHEN OTHERS
                THEN
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Error for the Company :'
                        || cur_companies.flex_value
                        || ' - '
                        || SQLERRM);
            END;
        END LOOP;

        IF lv_warning_message IS NOT NULL
        THEN
            lb_result   :=
                fnd_concurrent.set_completion_status (
                    'WARNING',
                    'Missing Primary and/or Secondary Ledger ID for the Company. Please check log.');
        END IF;

        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                'Error in before_report:' || SQLERRM || ' - ' || lv_step);
            RAISE_APPLICATION_ERROR (
                -20303,
                SUBSTR (
                    'Error in before_report:' || SQLERRM || ' - ' || lv_step,
                    1,
                    240));
            RETURN FALSE;
    END before_report;

    --
    --
    FUNCTION after_report
        RETURN BOOLEAN
    AS
    BEGIN
        RETURN TRUE;
    EXCEPTION
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'Error in after_report:' || SQLERRM);
            RAISE_APPLICATION_ERROR (
                -20304,
                SUBSTR ('Error in after_report:' || SQLERRM, 1, 240));
            RETURN FALSE;
    END after_report;
END XXD_GL_SLEC_REP_PKG;
/
