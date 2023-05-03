--
-- XXD_GL_JOURNALS_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_GL_JOURNALS_EXTRACT_PKG"
AS
    /****************************************************************************************
 * Package      : XXD_GL_JOURNALS_EXTRACT_PKG
 * Design       : This package will be used to fetch the Journal details and send to blackline
 * Notes        :
 * Modification :
 -- ======================================================================================
 -- Date         Version#   Name                    Comments
 -- ======================================================================================
 -- 03-Mar-2021  1.0        Showkath Ali            Initial Version
 -- 23-Jun-2021  1.1        Showkath Ali            CCR0009423
 -- 25-NOV-2021  1.2        Showkath Ali            CCR0009740
 ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    -- Modifed to init G variable from input params

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    gn_error          CONSTANT NUMBER := 2;


    FUNCTION get_account_info (pn_ccids IN VARCHAR2, pv_info IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ccidsegment   VARCHAR2 (50);
    BEGIN
        IF pv_info = 'Company'
        THEN
            BEGIN
                SELECT gcc.segment1
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Brand'
        THEN
            BEGIN
                SELECT gcc.segment2
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Geo'
        THEN
            BEGIN
                SELECT gcc.segment3
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Channel'
        THEN
            BEGIN
                SELECT gcc.segment4
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Cost_Center'
        THEN
            BEGIN
                SELECT gcc.segment5
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Account'
        THEN
            BEGIN
                SELECT gcc.segment6
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'IC'
        THEN
            BEGIN
                SELECT gcc.segment7
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        --fnd_file.put_line(fnd_file.log,'ccid'||pn_ccids);
        --fnd_file.put_line(fnd_file.log,'lv_ccidsegment'||lv_ccidsegment);
        ELSIF pv_info = 'Future'
        THEN
            BEGIN
                SELECT gcc.segment8
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Enabled'
        THEN
            BEGIN
                SELECT gcc.enabled_flag
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Type'
        THEN
            BEGIN
                SELECT gcc.gl_account_type
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSIF pv_info = 'Combo'
        THEN
            BEGIN
                SELECT gcc.concatenated_segments
                  INTO lv_ccidsegment
                  FROM apps.gl_code_combinations_kfv gcc
                 WHERE gcc.code_combination_id = pn_ccids;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_ccidsegment   := NULL;
            END;
        ELSE
            lv_ccidsegment   := NULL;
        END IF;

        RETURN lv_ccidsegment;
    END get_account_info;

    ---
    --
    FUNCTION get_file_path (p_period_set_name        IN VARCHAR2,
                            p_period_name            IN VARCHAR2,
                            p_geo                    IN VARCHAR2,
                            p_vs_unique_identifier   IN VARCHAR2,
                            p_company                IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_region        VARCHAR2 (20);
        lv_region_geo    VARCHAR2 (20);
        lv_description   VARCHAR2 (32767);
    BEGIN
        BEGIN
            SELECT ffvl.attribute10
              INTO lv_region
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'DO_GL_COMPANY'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value = p_company;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_region   := NULL;
        END;

        BEGIN
            SELECT ffvl.attribute1
              INTO lv_region_geo
              FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
             WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                   AND fvs.flex_value_set_name = 'DO_GL_GEO'
                   AND NVL (TRUNC (ffvl.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (ffvl.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND ffvl.enabled_flag = 'Y'
                   AND ffvl.flex_value = p_geo;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_region_geo   := NULL;
        END;

        IF NVL (lv_region, lv_region_geo) = 'EMEA'
        THEN
            BEGIN
                SELECT SUBSTR (
                           DECODE (
                               (SELECT attribute31_2
                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                 WHERE vs_line_identifier =
                                       p_vs_unique_identifier),
                               '', '',                          -- 1.1 changes
                                  (SELECT attribute31_2
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          p_vs_unique_identifier)
                               || (SELECT attribute9
                                     FROM apps.fnd_flex_values_vl
                                    WHERE     flex_value_set_id = 1015911
                                          AND flex_value = p_company
                                          AND attribute9 IS NOT NULL) -- DO_GL_COMPANY
                               || get_period_year (p_period_set_name,
                                                   p_period_name)
                               || '\'
                               || get_period_num (p_period_set_name,
                                                  p_period_name)
                               || '.'
                               || p_period_name
                               || (SELECT attribute32_2
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          p_vs_unique_identifier)),
                           1,
                           2000)
                  INTO lv_description
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_description   := NULL;
            END;
        ELSIF NVL (lv_region, lv_region_geo) = 'APAC'
        THEN
            BEGIN
                SELECT SUBSTR (
                           DECODE (
                               (SELECT attribute33_2
                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                 WHERE vs_line_identifier =
                                       p_vs_unique_identifier),
                               '', '',                           --1.1 changes
                                  (SELECT attribute33_2
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          p_vs_unique_identifier)
                               || (SELECT attribute9
                                     FROM apps.fnd_flex_values_vl
                                    WHERE     flex_value_set_id = 1015911
                                          AND flex_value = p_company
                                          AND attribute9 IS NOT NULL) -- DO_GL_COMPANY
                               || get_period_year (p_period_set_name,
                                                   p_period_name)
                               || '\'
                               || get_period_num (p_period_set_name,
                                                  p_period_name)
                               || '.'
                               || p_period_name
                               || (SELECT attribute34_2
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          p_vs_unique_identifier)),
                           1,
                           2000)
                  INTO lv_description
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_description   := NULL;
            END;
        ELSIF NVL (lv_region, lv_region_geo) = 'NA'
        THEN
            BEGIN
                SELECT SUBSTR (
                           DECODE (
                               (SELECT attribute35_2
                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                 WHERE vs_line_identifier =
                                       p_vs_unique_identifier),
                               '', '',                           --1.1 changes
                                  (SELECT attribute35_2
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          p_vs_unique_identifier)
                               || (SELECT attribute9
                                     FROM apps.fnd_flex_values_vl
                                    WHERE     flex_value_set_id = 1015911
                                          AND flex_value = p_company
                                          AND attribute9 IS NOT NULL) -- DO_GL_COMPANY
                               || get_period_year (p_period_set_name,
                                                   p_period_name)
                               || '\'
                               || get_period_num (p_period_set_name,
                                                  p_period_name)
                               || '.'
                               || p_period_name
                               || (SELECT attribute36_2
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          p_vs_unique_identifier)),
                           1,
                           2000)
                  INTO lv_description
                  FROM DUAL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_description   := NULL;
            END;
        ELSE
            lv_description   := NULL;
        END IF;

        RETURN lv_description;
    END get_file_path;

    --
    FUNCTION get_elegible_journal (pn_ccid         IN NUMBER,
                                   pv_period       IN VARCHAR2,
                                   p_ledger_type   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ccid_exists   VARCHAR2 (10);
        ln_count         NUMBER;
        ln_count1        NUMBER;
    BEGIN
        IF p_ledger_type = 'Primary'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM DUAL
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_journals_extract_t
                                 WHERE     1 = 1
                                       AND ccid = pn_ccid
                                       AND period_name = pv_period
                                       AND statuary_ledger IS NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;

            IF NVL (ln_count, 0) > 0
            THEN
                lv_ccid_exists   := 'TRUE';
            ELSE
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_count1
                      FROM DUAL
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_gl_account_balance_t a, xxdo.xxd_gl_period_name_gt b
                                     WHERE     1 = 1
                                           AND b.ledger_id = 2036 -- since period end date is same for all ledgers in custom table we are using 2036
                                           AND code_combination_id = pn_ccid
                                           AND TO_DATE (a.period_end_date,
                                                        'MM-DD-RRRR') =
                                               TO_DATE (b.period_end_date,
                                                        'DD-MON-YY')
                                           AND code_combination_id
                                                   IS NOT NULL
                                           AND stat_ledger_flag IS NULL);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_count1   := 0;
                END;

                IF NVL (ln_count1, 0) > 0
                THEN
                    lv_ccid_exists   := 'TRUE';
                ELSE
                    lv_ccid_exists   := 'FALSE';
                END IF;
            END IF;
        ELSE                                                  -- p_ledger_type
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM DUAL
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_journals_extract_t
                                 WHERE     1 = 1
                                       AND ccid = pn_ccid
                                       AND period_name = pv_period
                                       AND statuary_ledger IS NOT NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;

            IF NVL (ln_count, 0) > 0
            THEN
                lv_ccid_exists   := 'TRUE';
            ELSE
                BEGIN
                    SELECT COUNT (1)
                      INTO ln_count1
                      FROM DUAL
                     WHERE     1 = 1
                           AND EXISTS
                                   (SELECT 1
                                      FROM xxdo.xxd_gl_account_balance_t a, xxdo.xxd_gl_period_name_gt b
                                     WHERE     1 = 1
                                           AND b.ledger_id = 2036 -- since period end date is same for all ledgers in custom table we are using 2036
                                           AND code_combination_id = pn_ccid
                                           AND TO_DATE (a.period_end_date,
                                                        'MM-DD-RRRR') =
                                               TO_DATE (b.period_end_date,
                                                        'DD-MON-YY')
                                           AND code_combination_id
                                                   IS NOT NULL
                                           AND stat_ledger_flag IS NOT NULL);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_count1   := 0;
                END;

                IF NVL (ln_count1, 0) > 0
                THEN
                    lv_ccid_exists   := 'TRUE';
                ELSE
                    lv_ccid_exists   := 'FALSE';
                END IF;
            END IF;
        END IF;                                                --p_ledger_type

        RETURN lv_ccid_exists;
    END get_elegible_journal;

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

    --
    FUNCTION get_period_year (p_period_set_name   IN VARCHAR2,
                              p_period            IN VARCHAR2)
        RETURN NUMBER
    IS
        x_period_year   NUMBER;
    BEGIN
        IF p_period_set_name = 'DO_FY_CALENDAR'
        THEN
            BEGIN
                SELECT gp1.period_year
                  INTO x_period_year
                  FROM apps.gl_periods gp1
                 WHERE     gp1.period_name = p_period
                       AND gp1.period_set_name = 'DO_FY_CALENDAR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_period_year   := NULL;
            END;
        ELSE
            BEGIN
                SELECT gp.period_year
                  INTO x_period_year
                  FROM apps.gl_periods gp, apps.gl_periods gp1
                 WHERE     gp1.period_name = p_period
                       AND gp1.start_date = gp.start_date
                       AND gp.period_set_name = 'DO_CY_CALENDAR'
                       AND gp1.period_set_name = 'DO_FY_CALENDAR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_period_year   := NULL;
            END;
        END IF;

        RETURN x_period_year;
    END;


    FUNCTION get_period_num (p_period_set_name   IN VARCHAR2,
                             p_period            IN VARCHAR2)
        RETURN NUMBER
    IS
        x_period_num   NUMBER;
    BEGIN
        IF p_period_set_name = 'DO_FY_CALENDAR'
        THEN
            BEGIN
                SELECT gp1.period_num
                  INTO x_period_num
                  FROM apps.gl_periods gp1
                 WHERE     gp1.period_name = p_period
                       AND gp1.period_set_name = 'DO_FY_CALENDAR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_period_num   := NULL;
            END;
        ELSE
            BEGIN
                SELECT gp.period_num
                  INTO x_period_num
                  FROM apps.gl_periods gp, apps.gl_periods gp1
                 WHERE     gp1.period_name = p_period
                       AND gp1.start_date = gp.start_date
                       AND gp.period_set_name = 'DO_CY_CALENDAR'
                       AND gp1.period_set_name = 'DO_FY_CALENDAR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_period_num   := NULL;
            END;
        END IF;

        RETURN x_period_num;
    END;

    FUNCTION get_period_name (p_period_set_name IN VARCHAR2, p_period IN VARCHAR2, p_current_period IN VARCHAR2
                              , p_previous_period IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_current_period    VARCHAR2 (30);
        lv_previous_period   VARCHAR2 (30);
        lv_period            VARCHAR2 (30);
    BEGIN
        -- query to fetch current period_name
        IF p_period IS NULL
        THEN
            BEGIN
                SELECT period_name
                  INTO lv_current_period
                  FROM gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND TRUNC (SYSDATE) BETWEEN start_date AND end_date -- current month
                                                                          ;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_current_period   := NULL;
            END;
        ELSE
            lv_current_period   := p_period;
        END IF;

        -- query to fetch previous period_name

        IF p_period IS NULL
        THEN
            BEGIN
                SELECT period_name
                  INTO lv_previous_period
                  FROM gl_periods
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND TRUNC (ADD_MONTHS (TRUNC (SYSDATE, 'mm'), -1)) BETWEEN start_date
                                                                              AND end_date; -- previous month
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_previous_period   := NULL;
            END;
        ELSE
            SELECT (SELECT period_name
                      FROM gl_periods b
                     WHERE     period_set_name = 'DO_FY_CALENDAR'
                           AND TRUNC (
                                   ADD_MONTHS (TRUNC (a.start_date, 'mm'),
                                               -1)) BETWEEN start_date
                                                        AND end_date)
              INTO lv_previous_period
              FROM gl_periods a
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_name = p_period;
        END IF;

        IF p_period_set_name = 'DO_FY_CALENDAR'
        THEN
            IF     NVL (p_current_period, 'N') = 'Y'
               AND NVL (p_previous_period, 'N') = 'N'
            THEN
                lv_period   := lv_current_period;
            ELSIF     NVL (p_current_period, 'N') = 'N'
                  AND NVL (p_previous_period, 'N') = 'Y'
            THEN
                lv_period   := lv_previous_period;
            ELSIF     NVL (p_current_period, 'N') = 'N'
                  AND NVL (p_previous_period, 'N') = 'N'
                  AND p_period IS NOT NULL
            THEN
                lv_period   := p_period;
            ELSE
                lv_period   := NULL;
            END IF;
        ELSIF p_period_set_name = 'DO_CY_CALENDAR'
        THEN
            IF     NVL (p_current_period, 'N') = 'Y'
               AND NVL (p_previous_period, 'N') = 'N'
            THEN
                lv_period   := get_secondary_period (lv_current_period);
            ELSIF     NVL (p_current_period, 'N') = 'N'
                  AND NVL (p_previous_period, 'N') = 'Y'
            THEN
                lv_period   := get_secondary_period (lv_previous_period);
            ELSIF     NVL (p_current_period, 'N') = 'N'
                  AND NVL (p_previous_period, 'N') = 'N'
                  AND p_period IS NOT NULL
            THEN
                lv_period   := get_secondary_period (p_period);
            ELSE
                lv_period   := NULL;
            END IF;
        END IF;

        RETURN lv_period;
    END;

    FUNCTION get_secondary_period (p_period_name IN VARCHAR2)
        RETURN VARCHAR2
    IS
        x_period_name   VARCHAR2 (20);
    BEGIN
        BEGIN
            SELECT gp.period_name
              INTO x_period_name
              FROM apps.gl_periods gp, apps.gl_periods gp1
             WHERE     gp1.period_name = p_period_name
                   AND gp1.start_date = gp.start_date
                   AND gp.period_set_name = 'DO_CY_CALENDAR'
                   AND gp1.period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                x_period_name   := NULL;
        END;

        RETURN x_period_name;
    END;

    FUNCTION get_uniq_iden_period (p_in_period      IN VARCHAR2,
                                   p_close_method   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        lv_ytd_period   VARCHAR2 (10);
        lv_qtd_period   VARCHAR2 (10);
        lv_mtd_period   VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT (SELECT period_name
                      FROM gl_periods b
                     WHERE     b.start_date = a.year_start_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       year_start_period,
                   (SELECT period_name
                      FROM gl_periods b
                     WHERE     b.start_date = a.quarter_start_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       year_start_period,
                   (SELECT period_name
                      FROM gl_periods b
                     WHERE     b.start_date = a.start_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       year_start_period
              INTO lv_ytd_period, lv_qtd_period, lv_mtd_period
              FROM gl_periods a
             WHERE     period_name = p_in_period
                   AND period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ytd_period   := NULL;
                lv_qtd_period   := NULL;
                lv_mtd_period   := NULL;
        END;

        --

        IF NVL (p_close_method, 'MTD') = 'YTD'
        THEN
            RETURN lv_ytd_period;
        ELSIF NVL (p_close_method, 'MTD') = 'QTD'
        THEN
            RETURN lv_qtd_period;
        ELSIF NVL (p_close_method, 'MTD') = 'MTD'
        THEN
            RETURN lv_mtd_period;
        ELSIF NVL (p_close_method, 'MTD') = 'N'
        THEN
            RETURN NULL;
        ELSE
            RETURN NULL;
        END IF;
    END get_uniq_iden_period;

    --

    PROCEDURE get_eligible_ccid (p_in_ccid IN NUMBER, p_in_period IN VARCHAR2, p_ledger_type IN VARCHAR2, p_out_activty_in_prd1 OUT VARCHAR2, p_out_active_acct OUT VARCHAR2, p_out_pri_gl_acct_bal OUT NUMBER
                                 , p_out_primary_currency OUT VARCHAR2)
    IS
        l_secondary_ledger        NUMBER;
        l_bl_alt_curr_flag        VARCHAR2 (10);
        p_pri_ledger_id           NUMBER;
        p_pri_gl_acct_bal_begin   NUMBER;
        p_activity                NUMBER;
        ln_count                  NUMBER;
    BEGIN
        p_out_active_acct        := NULL;
        p_out_activty_in_prd1    := NULL;
        p_out_pri_gl_acct_bal    := NULL;
        p_out_primary_currency   := NULL;

        -- PICK THE SECONDARY LEDGER/ atl currency flag From THE COMPANY DFF
        IF p_ledger_type = 'Primary'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM DUAL
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_account_balance_t a, xxdo.xxd_gl_period_name_gt b
                                 WHERE     1 = 1
                                       AND b.ledger_id = 2036 -- since period end date is same for all ledgers in custom table we are using 2036
                                       AND code_combination_id = p_in_ccid
                                       AND TO_DATE (a.period_end_date,
                                                    'MM-DD-RRRR') =
                                           TO_DATE (b.period_end_date,
                                                    'DD-MON-YY')
                                       AND code_combination_id IS NOT NULL
                                       AND stat_ledger_flag IS NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;

            fnd_file.put_line (fnd_file.LOG, 'p_in_ccid' || p_in_ccid);
            fnd_file.put_line (fnd_file.LOG, 'Count' || ln_count);

            IF NVL (ln_count, 0) = 0
            THEN
                --       PIRMARY BALANCE
                BEGIN
                    SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)), (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal, b.currency_code,
                           b.ledger_id
                      INTO p_pri_gl_acct_bal_begin, p_out_pri_gl_acct_bal, p_out_primary_currency, p_pri_ledger_id
                      -- p_activity
                      FROM gl_balances gb, gl_ledgers b
                     WHERE     period_name = p_in_period
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.ledger_id <> 2081
                           AND b.currency_code = gb.currency_code
                           AND ledger_category_code = 'PRIMARY';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_pri_gl_acct_bal_begin' || p_pri_gl_acct_bal_begin);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_out_pri_gl_acct_bal' || p_out_pri_gl_acct_bal);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;

                BEGIN
                    SELECT DECODE (enabled_flag, 'Y', 'TRUE', 'FALSE')
                      INTO p_out_active_acct
                      FROM gl_code_combinations
                     WHERE code_combination_id = p_in_ccid;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_out_active_acct' || p_out_active_acct);

                    IF p_out_active_acct = 'TRUE'
                    THEN                         -- AND HAS ACTIVITY IN PERIOD
                        IF p_pri_gl_acct_bal_begin <> 0
                        THEN
                            p_out_activty_in_prd1   := 'TRUE';
                        ELSE
                            fnd_file.put_line (fnd_file.LOG,
                                               'Inside activity check');

                            SELECT COUNT (1)
                              INTO p_activity
                              FROM DUAL
                             WHERE     1 = 1
                                   AND EXISTS
                                           (SELECT 1
                                              FROM gl_ledgers gll, gl_je_lines gjl
                                             WHERE     gll.ledger_id <> 2081
                                                   AND gjl.code_combination_id =
                                                       p_in_ccid
                                                   AND gjl.ledger_id =
                                                       gll.ledger_id
                                                   AND gjl.period_name =
                                                       p_in_period
                                                   --AND b.ledger_id = gll.ledger_id
                                                   AND gll.ledger_category_code =
                                                       'PRIMARY'
                                                   AND gjl.status = 'P'
                                                   AND NOT EXISTS
                                                           (SELECT 1
                                                              FROM apps.gl_je_headers gjh
                                                             WHERE     gjh.je_header_id =
                                                                       gjl.je_header_id
                                                                   AND gjh.je_category =
                                                                       'Revaluation'
                                                                   AND je_source =
                                                                       'Revaluation'));

                            fnd_file.put_line (fnd_file.LOG,
                                               'p_activity ' || p_activity);

                            IF NVL (p_activity, 0) > 0 -- p_pri_gl_acct_bal_begin = 0 AND
                            THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'inside p_activity >0');
                                p_out_activty_in_prd1   := 'TRUE';
                            ELSIF     p_pri_gl_acct_bal_begin = 0
                                  AND p_out_pri_gl_acct_bal <> 0
                                  AND p_activity = 0 --AND p_closing_bal = 'YES'
                            THEN
                                fnd_file.put_line (fnd_file.LOG,
                                                   'inside ending bal');
                                p_out_activty_in_prd1   := 'TRUE';
                            ELSE
                                fnd_file.put_line (fnd_file.LOG,
                                                   'inside false ');
                                p_out_activty_in_prd1   := 'FALSE';
                            END IF;
                        END IF;
                    ELSIF p_out_active_acct = 'FALSE'
                    THEN
                        IF    p_pri_gl_acct_bal_begin <> 0
                           OR p_out_pri_gl_acct_bal <> 0
                        THEN
                            p_out_activty_in_prd1   := 'TRUE';
                        ELSE
                            p_out_activty_in_prd1   := 'FALSE';
                        END IF;
                    END IF;
                END;
            ELSE                                                  -- count = 1
                fnd_file.put_line (fnd_file.LOG,
                                   'inside srinath table condition bal');
                p_out_activty_in_prd1   := 'TRUE';
            END IF;
        -- for secondary records

        ELSIF p_ledger_type = 'Secondary'
        THEN
            BEGIN
                SELECT COUNT (1)
                  INTO ln_count
                  FROM DUAL
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_account_balance_t a, xxdo.xxd_gl_period_name_gt b
                                 WHERE     1 = 1
                                       AND b.ledger_id = 2036 -- since period end date is same for all ledgers in custom table we are using 2036
                                       AND code_combination_id = p_in_ccid
                                       AND TO_DATE (a.period_end_date,
                                                    'MM-DD-RRRR') =
                                           TO_DATE (b.period_end_date,
                                                    'DD-MON-YY')
                                       AND code_combination_id IS NOT NULL
                                       AND stat_ledger_flag IS NOT NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_count   := 0;
            END;

            IF NVL (ln_count, 0) = 0
            THEN
                -- Secondary Balances
                BEGIN
                    SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)), (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0) + (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))) end_bal, b.currency_code,
                           b.ledger_id
                      INTO p_pri_gl_acct_bal_begin, p_out_pri_gl_acct_bal, p_out_primary_currency, p_pri_ledger_id
                      --,
                      -- p_activity
                      FROM gl_balances gb, gl_ledgers b
                     WHERE     period_name = p_in_period
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

                BEGIN
                    SELECT DECODE (enabled_flag, 'Y', 'TRUE', 'FALSE')
                      INTO p_out_active_acct
                      FROM gl_code_combinations
                     WHERE code_combination_id = p_in_ccid;

                    IF p_out_active_acct = 'TRUE'
                    THEN                         -- AND HAS ACTIVITY IN PERIOD
                        IF p_pri_gl_acct_bal_begin <> 0
                        THEN
                            p_out_activty_in_prd1   := 'TRUE';
                        ELSE
                            SELECT COUNT (1)
                              INTO p_activity
                              FROM DUAL
                             WHERE     1 = 1
                                   AND EXISTS
                                           (SELECT 1
                                              FROM gl_ledgers gll, gl_je_lines gjl
                                             WHERE     gll.ledger_id <> 2081
                                                   AND gjl.code_combination_id =
                                                       p_in_ccid
                                                   AND gjl.ledger_id =
                                                       gll.ledger_id
                                                   AND gjl.period_name =
                                                       p_in_period
                                                   -- AND b.ledger_id = gll.ledger_id
                                                   AND gll.ledger_category_code =
                                                       'SECONDARY'
                                                   AND gjl.status = 'P'
                                                   AND NOT EXISTS
                                                           (SELECT 1
                                                              FROM apps.gl_je_headers gjh
                                                             WHERE     gjh.je_header_id =
                                                                       gjl.je_header_id
                                                                   AND gjh.je_category =
                                                                       'Revaluation'
                                                                   AND je_source =
                                                                       'Revaluation'));

                            IF NVL (p_activity, 0) > 0 -- p_pri_gl_acct_bal_begin = 0 AND
                            THEN
                                p_out_activty_in_prd1   := 'TRUE';
                            ELSIF     p_pri_gl_acct_bal_begin = 0
                                  AND p_out_pri_gl_acct_bal <> 0
                                  AND p_activity = 0 --AND p_closing_bal = 'YES'
                            THEN
                                p_out_activty_in_prd1   := 'TRUE';
                            ELSE
                                p_out_activty_in_prd1   := 'FALSE';
                            END IF;
                        END IF;
                    ELSIF p_out_active_acct = 'FALSE'
                    THEN
                        IF    p_pri_gl_acct_bal_begin <> 0
                           OR p_out_pri_gl_acct_bal <> 0
                        THEN
                            p_out_activty_in_prd1   := 'TRUE';
                        ELSE
                            p_out_activty_in_prd1   := 'FALSE';
                        END IF;
                    END IF;
                END;
            ELSE                                                  -- count = 1
                p_out_activty_in_prd1   := 'TRUE';
            END IF;
        END IF;                                                 -- ledger_type
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_eligible_ccid;


    -- ======================================================================================
    -- Function to get alternate ledger amount
    -- ======================================================================================

    FUNCTION get_rep_ledger_amt (p_period             IN VARCHAR2,
                                 p_in_ccid            IN VARCHAR2,
                                 p_ledger_id          IN NUMBER,
                                 p_parent_header_id   IN NUMBER,
                                 p_line_num           IN NUMBER)
        RETURN NUMBER
    IS
        l_out_pri_gl_alt_bal   NUMBER := NULL;
        l_secondary_ledger     NUMBER;
        l_bl_alt_curr_flag     VARCHAR2 (1);
    BEGIN
        BEGIN
            SELECT (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
              INTO l_out_pri_gl_alt_bal
              FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
             WHERE     1 = 1
                   AND gb.period_name = p_period
                   AND gh.je_header_id = gb.je_header_id
                   AND gb.code_combination_id = p_in_ccid
                   AND gb.ledger_id = b.ledger_id
                   AND b.ledger_id <> 2081
                   AND gh.parent_je_header_id = p_parent_header_id
                   AND ledger_category_code = 'ALC'
                   AND gb.je_line_num = p_line_num;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_out_pri_gl_alt_bal   := NULL;
            WHEN OTHERS
            THEN
                l_out_pri_gl_alt_bal   := NULL;
        END;

        RETURN l_out_pri_gl_alt_bal;
    END get_rep_ledger_amt;

    -- ======================================================================================
    -- Function to get secondary ledger amount
    -- ======================================================================================

    FUNCTION get_sec_ledget_amt (p_period IN VARCHAR2, p_in_ccid IN VARCHAR2, p_in_company IN NUMBER, p_ledger_id IN NUMBER, p_parent_header_id IN NUMBER, p_line_num IN NUMBER
                                 , p_in_alt_currency IN VARCHAR2)
        RETURN NUMBER
    IS
        l_out_pri_gl_alt_bal   NUMBER := NULL;
        l_secondary_ledger     NUMBER;
        l_bl_alt_curr_flag     VARCHAR2 (1);
    BEGIN
        -- PICK THE SECONDARY LEDGER/ atl currency flag From THE COMPANY DFF
        BEGIN
            SELECT TO_NUMBER (b.attribute8), b.attribute1
              INTO l_secondary_ledger, l_bl_alt_curr_flag
              FROM fnd_flex_value_sets a, fnd_flex_values b, gl_ledgers c
             WHERE     a.flex_value_set_name = 'DO_GL_COMPANY'
                   AND a.flex_value_set_id = b.flex_value_set_id
                   AND b.attribute8 = ledger_id
                   AND flex_value = p_in_company;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_secondary_ledger   := NULL;
                l_bl_alt_curr_flag   := NULL;
        END;

        IF p_in_alt_currency IS NULL
        THEN
            IF NVL (l_bl_alt_curr_flag, 'N') = 'Y'
            THEN
                BEGIN
                    SELECT (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                      INTO l_out_pri_gl_alt_bal
                      FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
                     WHERE     1 = 1
                           AND (gb.period_name = get_secondary_period (p_period) AND b.period_set_name = 'DO_CY_CALENDAR' OR gb.period_name = p_period AND b.period_set_name = 'DO_FY_CALENDAR')
                           AND gh.je_header_id = gb.je_header_id
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.ledger_id = l_secondary_ledger
                           AND b.ledger_category_code <> 'ALC'
                           AND b.ledger_id <> 2081
                           AND gh.parent_je_header_id = p_parent_header_id
                           AND gb.je_line_num = p_line_num;

                    RETURN l_out_pri_gl_alt_bal;
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_out_pri_gl_alt_bal   := NULL;
                        RETURN l_out_pri_gl_alt_bal;
                    WHEN OTHERS
                    THEN
                        l_out_pri_gl_alt_bal   := NULL;
                        RETURN l_out_pri_gl_alt_bal;
                END;
            END IF;
        ELSE -- p_in_alt_currency is not null i.e vs has the alternate currency entered
            BEGIN
                SELECT (NVL (entered_dr, 0) - NVL (entered_cr, 0))
                  INTO l_out_pri_gl_alt_bal
                  FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
                 WHERE     1 = 1
                       AND gb.period_name = p_period
                       AND gh.je_header_id = gb.je_header_id
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.ledger_id <> 2081
                       AND b.ledger_category_code <> 'ALC'
                       AND gh.je_header_id = p_parent_header_id
                       AND gb.je_line_num = p_line_num
                       AND gh.currency_code = UPPER (p_in_alt_currency);

                RETURN l_out_pri_gl_alt_bal;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_out_pri_gl_alt_bal   := NULL;
                    RETURN l_out_pri_gl_alt_bal;
            END;
        END IF;

        RETURN l_out_pri_gl_alt_bal;
    END get_sec_ledget_amt;

    -- ======================================================================================
    -- Function to get close date based on closing method
    -- ======================================================================================

    FUNCTION get_close_date (p_close_method   IN VARCHAR2,
                             p_period_name    IN VARCHAR2)
        RETURN DATE
    IS
        ld_ytd_date   DATE := NULL;
        ld_qtd_date   DATE := NULL;
        ld_mtd_date   DATE := NULL;
    BEGIN
        BEGIN
            SELECT (SELECT DISTINCT year_start_date
                      FROM gl_periods
                     WHERE     period_year IN
                                   (TO_CHAR (a.year_start_date, 'YYYY') + 2)
                           AND period_set_name = 'DO_FY_CALENDAR') ytd_date,
                   TO_DATE (
                         ADD_MONTHS (
                             TRUNC (a.quarter_start_date, 'Y') - 1,
                               TO_NUMBER (
                                   TO_CHAR (a.quarter_start_date, 'Q'))
                             * 3)
                       + 1,
                       'DD-MON-YY') qtd_date,
                   TO_DATE (a.end_date + 1, 'DD-MON-YY') mtd_date
              INTO ld_ytd_date, ld_qtd_date, ld_mtd_date
              FROM gl_periods a
             WHERE     period_name = p_period_name
                   AND period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ld_ytd_date   := NULL;
                ld_qtd_date   := NULL;
                ld_mtd_date   := NULL;
            WHEN OTHERS
            THEN
                ld_ytd_date   := NULL;
                ld_qtd_date   := NULL;
                ld_mtd_date   := NULL;
        END;

        IF NVL (p_close_method, 'MTD') = 'YTD'
        THEN
            RETURN ld_ytd_date;
        ELSIF NVL (p_close_method, 'MTD') = 'QTD'
        THEN
            RETURN ld_qtd_date;
        ELSIF NVL (p_close_method, 'MTD') = 'MTD'
        THEN
            RETURN ld_mtd_date;
        ELSIF NVL (p_close_method, 'MTD') = 'N'
        THEN
            RETURN NULL;
        ELSE
            RETURN NULL;
        END IF;
    END get_close_date;

    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

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
        UTL_FILE.fgetattr (location      => p_file_path,
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

            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
    END check_file_exists;

    -- ======================================================================================
    -- This procedure is used to write the file in file path
    -- ======================================================================================

    PROCEDURE write_extract_file (p_request_id NUMBER, p_file_path IN VARCHAR2, p_file_name IN VARCHAR2, p_source_type IN VARCHAR2, p_override_lastrun IN VARCHAR2, p_ledger_type IN VARCHAR2, p_override_definition IN VARCHAR2, --1.1
                                                                                                                                                                                                                                  P_last_run_date IN VARCHAR2, p_LAST_RUN_DATE_REVAL IN VARCHAR2, p_last_run_date_subled IN VARCHAR2, p_last_run_date_sec IN VARCHAR2, p_LAST_RUN_DATE_REVAL_sec IN VARCHAR2
                                  , p_last_run_date_subled_sec IN VARCHAR2, --1.1
                                                                            x_ret_code OUT VARCHAR2, x_ret_message OUT VARCHAR2)
    IS
        CURSOR write_account_balance IS
            SELECT company || CHR (9) || account || CHR (9) || brand || CHR (9) || geo || CHR (9) || channel || CHR (9) || costcenter || CHR (9) || intercompany || CHR (9) || futureuse || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || unique_identifier || CHR (9) || origination_date || CHR (9) || open_date || CHR (9) || close_date || CHR (9) || item_type || CHR (9) || item_sub_types || CHR (9) || item_summary || CHR (9) || item_impact_code || CHR (9) || item_class || CHR (9) || adjustment_destination || CHR (9) || item_editable_by_preparers || CHR (9) || description || CHR (9) || reference || CHR (9) || item_total || CHR (9) || reference_field1 || CHR (9) || reference_field2 || CHR (9) || reference_field3 || CHR (9) || reference_field4 || CHR (9) || reference_field5 || CHR (9) || alternate_currency_amount || CHR (9) || reporting_currency_amount || CHR (9) || glaccount_currency_amount || CHR (9) || transact_currency_amount || CHR (9) || item_currency line
              FROM xxdo.xxd_gl_journals_extract_t
             WHERE     1 = 1
                   AND request_id = p_request_id
                   AND alternate_currency_amount IS NULL;



        CURSOR write_account_bal_alt_amt IS
            SELECT company || CHR (9) || account || CHR (9) || brand || CHR (9) || geo || CHR (9) || channel || CHR (9) || costcenter || CHR (9) || intercompany || CHR (9) || futureuse || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || unique_identifier || CHR (9) || origination_date || CHR (9) || open_date || CHR (9) || close_date || CHR (9) || item_type || CHR (9) || item_sub_types || CHR (9) || item_summary || CHR (9) || item_impact_code || CHR (9) || item_class || CHR (9) || adjustment_destination || CHR (9) || item_editable_by_preparers || CHR (9) || description || CHR (9) || reference || CHR (9) || item_total || CHR (9) || reference_field1 || CHR (9) || reference_field2 || CHR (9) || reference_field3 || CHR (9) || reference_field4 || CHR (9) || reference_field5 || CHR (9) || alternate_currency_amount || CHR (9) || reporting_currency_amount || CHR (9) || glaccount_currency_amount || CHR (9) || transact_currency_amount || CHR (9) || item_currency line1
              FROM xxdo.xxd_gl_journals_extract_t
             WHERE     1 = 1
                   AND request_id = p_request_id
                   AND alternate_currency_amount IS NOT NULL;

        CURSOR write_account_balance_all IS
            SELECT company || CHR (9) || account || CHR (9) || brand || CHR (9) || geo || CHR (9) || channel || CHR (9) || costcenter || CHR (9) || intercompany || CHR (9) || futureuse || CHR (9) || key9 || CHR (9) || key10 || CHR (9) || unique_identifier || CHR (9) || origination_date || CHR (9) || open_date || CHR (9) || close_date || CHR (9) || item_type || CHR (9) || item_sub_types || CHR (9) || item_summary || CHR (9) || item_impact_code || CHR (9) || item_class || CHR (9) || adjustment_destination || CHR (9) || item_editable_by_preparers || CHR (9) || description || CHR (9) || reference || CHR (9) || item_total || CHR (9) || reference_field1 || CHR (9) || reference_field2 || CHR (9) || reference_field3 || CHR (9) || reference_field4 || CHR (9) || reference_field5 || CHR (9) || alternate_currency_amount || CHR (9) || reporting_currency_amount || CHR (9) || glaccount_currency_amount || CHR (9) || transact_currency_amount || CHR (9) || item_currency line
              FROM xxdo.xxd_gl_journals_extract_t
             WHERE 1 = 1 AND request_id = p_request_id;

        CURSOR update_gl_lines (p_last_update_date IN VARCHAR2)
        IS
            --SELECT a.*
            SELECT DISTINCT a.je_header_id, a.code_combination_id        --1.1
              FROM apps.gl_je_lines a,
                   (SELECT DISTINCT ccid
                      FROM xxdo.xxd_gl_journals_extract_t b
                     WHERE     request_id = p_request_id
                           AND report_type IN ('DETAIL-NR', 'SUMMARY-NR')) b
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_headers_ext_t
                             WHERE     je_header_id = a.je_header_id
                                   AND reversed_je_header_id IS NOT NULL)
                   AND code_combination_id = b.ccid
                   --AND global_attribute1 IS NULL --1.2
                   AND a.last_update_date >=
                       NVL (
                           TO_DATE (p_last_update_date,
                                    'RRRR/MM/DD HH24:MI:SS'),
                           SYSDATE)
            UNION ALL
            --SELECT a.*
            SELECT DISTINCT a.je_header_id, a.code_combination_id        --1.1
              FROM apps.gl_je_lines a,
                   (SELECT DISTINCT ccid
                      FROM xxdo.xxd_gl_journals_extract_t b
                     WHERE     request_id = p_request_id
                           --AND report_type IN ('DETAIL', 'SUMMARY')) b --1.2
                           AND report_type IN ('DETAIL', 'SUMMARY', 'REVAL'))
                   b                                                    -- 1.2
             WHERE     1 = 1
                   AND EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_headers_ext_t
                             WHERE je_header_id = a.je_header_id)
                   AND code_combination_id = b.ccid
                   -- AND global_attribute1 IS NULL --1.2
                   AND a.last_update_date >=
                       NVL (
                           TO_DATE (p_last_update_date,
                                    'RRRR/MM/DD HH24:MI:SS'),
                           SYSDATE);


        --DEFINE VARIABLES

        lv_file_path          VARCHAR2 (360) := p_file_path;
        lv_output_file        UTL_FILE.file_type;
        lv_output_file1       UTL_FILE.file_type;
        lv_outbound_file      VARCHAR2 (360) := p_file_name;
        lv_err_msg            VARCHAR2 (2000) := NULL;
        lv_line               VARCHAR2 (32767) := NULL;
        lv_last_update_date   VARCHAR2 (1000);                           --1.1
        lv_request_info       VARCHAR2 (100);                            --1.1

        TYPE lines_tbl_typ IS TABLE OF update_gl_lines%ROWTYPE;



        l_lines_tbl_typ       lines_tbl_typ;
    BEGIN
        IF lv_file_path IS NULL
        THEN                                            -- WRITE INTO FND LOGS
            FOR i IN write_account_balance_all
            LOOP
                lv_line   := i.line;
                fnd_file.put_line (fnd_file.output, lv_line);
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

                --1.1 changes start
                -- query to get the request start date from request table
                BEGIN
                    SELECT TO_CHAR (fcr.actual_start_date, 'YYYY/MM/DD HH24:MI:SS')
                      INTO lv_request_info
                      FROM apps.fnd_concurrent_requests fcr
                     WHERE request_id = p_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_request_info   := NULL;
                END;

                --1.1 changes end

                IF     NVL (p_override_lastrun, 'N') = 'N'
                   AND NVL (p_override_definition, 'N') = 'N'
                THEN
                    -- update last run date in value set
                    IF p_ledger_type = 'Primary'
                    THEN
                        IF p_source_type = 'Manual'
                        THEN
                            BEGIN
                                UPDATE apps.fnd_flex_values ffvl
                                   SET ffvl.attribute1 = NVL (lv_request_info, TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'))
                                 WHERE     1 = 1
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_GL_JL_EXTRACT_LASTRUN_V')
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exp- Updation As-of-Date failed in Valueset ');
                            END;
                        ELSIF p_source_type = 'Revaluation'
                        THEN
                            BEGIN
                                UPDATE apps.fnd_flex_values ffvl
                                   SET ffvl.attribute2 = NVL (lv_request_info, TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'))
                                 WHERE     1 = 1
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_GL_JL_EXTRACT_LASTRUN_V')
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exp- Updation As-of-Date failed in Valueset ');
                            END;
                        ELSIF p_source_type = 'Subledger'
                        THEN
                            BEGIN
                                UPDATE apps.fnd_flex_values ffvl
                                   SET ffvl.attribute3 = NVL (lv_request_info, TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'))
                                 WHERE     1 = 1
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_GL_JL_EXTRACT_LASTRUN_V')
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exp- Updation As-of-Date failed in Valueset ');
                            END;
                        END IF;
                    ELSIF p_ledger_type = 'Secondary'
                    THEN
                        IF p_source_type = 'Manual'
                        THEN
                            BEGIN
                                UPDATE apps.fnd_flex_values ffvl
                                   SET ffvl.attribute4 = NVL (lv_request_info, TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'))
                                 WHERE     1 = 1
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_GL_JL_EXTRACT_LASTRUN_V')
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exp- Updation As-of-Date failed in Valueset ');
                            END;
                        ELSIF p_source_type = 'Revaluation'
                        THEN
                            BEGIN
                                UPDATE apps.fnd_flex_values ffvl
                                   SET ffvl.attribute5 = NVL (lv_request_info, TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'))
                                 WHERE     1 = 1
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_GL_JL_EXTRACT_LASTRUN_V')
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exp- Updation As-of-Date failed in Valueset ');
                            END;
                        ELSIF p_source_type = 'Subledger'
                        THEN
                            BEGIN
                                UPDATE apps.fnd_flex_values ffvl
                                   SET ffvl.attribute6 = NVL (lv_request_info, TO_CHAR (SYSDATE, 'YYYY/MM/DD HH24:MI:SS'))
                                 WHERE     1 = 1
                                       AND ffvl.flex_value_set_id =
                                           (SELECT flex_value_set_id
                                              FROM apps.fnd_flex_value_sets
                                             WHERE flex_value_set_name =
                                                   'XXD_GL_JL_EXTRACT_LASTRUN_V')
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y';

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Exp- Updation As-of-Date failed in Valueset ');
                            END;
                        END IF;
                    END IF;                                    --p_ledger_type
                END IF;                                  -- p_override_lastrun
            ELSE
                lv_err_msg      :=
                    SUBSTR (
                           'Error in Opening the Journal Extract data file for writing. Error is : '
                        || SQLERRM,
                        1,
                        2000);
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                x_ret_code      := gn_error;
                x_ret_message   := lv_err_msg;
                RETURN;
            END IF;

            UTL_FILE.fclose (lv_output_file);
            -- file without alternate amount
            -- WRITE INTO BL FOLDER
            lv_output_file1   :=
                UTL_FILE.fopen (lv_file_path, 'Items_alt' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS') || '.txt', 'W' --opening the file in write mode
                                , 32767);

            IF UTL_FILE.is_open (lv_output_file1)
            THEN
                FOR i IN write_account_bal_alt_amt
                LOOP
                    lv_line   := i.line1;
                    UTL_FILE.put_line (lv_output_file1, lv_line);
                END LOOP;
            END IF;

            UTL_FILE.fclose (lv_output_file1);
        END IF;

        --1.1  changes start
        BEGIN
            IF p_ledger_type = 'Primary'
            THEN
                IF p_source_type = 'Manual'
                THEN
                    lv_last_update_date   := p_last_run_date;
                ELSIF p_source_type = 'Revaluation'
                THEN
                    lv_last_update_date   := p_LAST_RUN_DATE_REVAL;
                ELSIF p_source_type = 'Subledger'
                THEN
                    lv_last_update_date   := p_last_run_date_subled;
                ELSE
                    lv_last_update_date   := NULL;
                END IF;
            ELSIF p_ledger_type = 'Secondary'
            THEN
                IF p_source_type = 'Manual'
                THEN
                    lv_last_update_date   := p_last_run_date_sec;
                ELSIF p_source_type = 'Revaluation'
                THEN
                    lv_last_update_date   := p_LAST_RUN_DATE_REVAL_sec;
                ELSIF p_source_type = 'Subledger'
                THEN
                    lv_last_update_date   := p_last_run_date_subled_sec;
                ELSE
                    lv_last_update_date   := NULL;
                END IF;
            END IF;
        END;

        IF p_file_path IS NOT NULL
        THEN
            OPEN update_gl_lines (lv_last_update_date);                  --1.1

           <<lines>>
            LOOP
                FETCH update_gl_lines
                    BULK COLLECT INTO l_lines_tbl_typ
                    LIMIT 1000;

                EXIT lines WHEN l_lines_tbl_typ.COUNT = 0;

                BEGIN
                    FORALL i IN l_lines_tbl_typ.FIRST .. l_lines_tbl_typ.LAST
                        /* UPDATE gl_je_lines
                            SET global_attribute1 = 'Y',
              last_updated_by = gn_user_id, --1.1
                                last_update_date = SYSDATE --1.1
                          WHERE     je_header_id =
                                    l_lines_tbl_typ (i).je_header_id
                                AND je_line_num =
                                    l_lines_tbl_typ (i).je_line_num;*/
                        --1.1
                        --1.1 changes start --
                        INSERT INTO xxdo.xxd_gl_je_lines_ext_t (
                                        je_header_id,
                                        code_combination_id,
                                        request_id,
                                        creation_date)
                             VALUES (l_lines_tbl_typ (i).je_header_id, l_lines_tbl_typ (i).code_combination_id, gn_request_id
                                     , SYSDATE);

                    --1.1  changes end

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        FND_FILE.PUT_LINE (
                            FND_FILE.LOG,
                               -- 'Updation of gl_je_lines failed - ' || SQLERRM);
                               'Insertion of xxd_gl_je_lines_ext_t failed - '
                            || SQLERRM);
                END;
            END LOOP;

            CLOSE update_gl_lines;

            -- update the custom table
            BEGIN
                UPDATE xxdo.xxd_gl_journals_extract_t
                   SET sent_to_blackline = 'Y', file_name = p_file_name
                 WHERE request_id = p_request_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Failed to update sent to blackline flag' || SQLERRM);
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
    END write_extract_file;

    -- ======================================================================================
    -- This procedure is used to get the account balances
    -- ======================================================================================

    PROCEDURE get_jl_ccid_values (p_in_ccid IN NUMBER, p_in_company IN NUMBER, p_in_alt_currency IN VARCHAR2, p_in_period IN VARCHAR2, p_header_id IN NUMBER, p_line_num IN NUMBER, p_out_activty_in_prd OUT VARCHAR2, p_out_active_acct OUT VARCHAR2, p_out_pri_gl_rpt_bal OUT NUMBER, p_out_pri_gl_alt_bal OUT NUMBER, p_out_pri_gl_acct_bal OUT NUMBER, p_out_sec_gl_rpt_bal OUT NUMBER, p_out_sec_gl_alt_bal OUT NUMBER, p_out_sec_gl_acct_bal OUT NUMBER, p_out_alt_currency OUT VARCHAR2
                                  , p_out_primary_currency OUT VARCHAR2)
    IS
        l_secondary_ledger        NUMBER;
        l_bl_alt_curr_flag        VARCHAR2 (10);
        p_pri_ledger_id           NUMBER;
        p_pri_gl_acct_bal_begin   NUMBER;
    BEGIN
        -- PICK THE SECONDARY LEDGER/ atl currency flag From THE COMPANY DFF
        BEGIN
            SELECT c.currency_code, TO_NUMBER (b.attribute8), b.attribute1
              INTO p_out_alt_currency, l_secondary_ledger, l_bl_alt_curr_flag
              FROM fnd_flex_value_sets a, fnd_flex_values b, gl_ledgers c
             WHERE     a.flex_value_set_name = 'DO_GL_COMPANY'
                   AND a.flex_value_set_id = b.flex_value_set_id
                   AND b.attribute8 = ledger_id
                   AND flex_value = p_in_company;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- PIRMARY BALANCE

        BEGIN
              SELECT SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)), b.currency_code, b.ledger_id
                INTO p_out_pri_gl_acct_bal, p_out_primary_currency, p_pri_ledger_id
                FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
               WHERE     gb.period_name = p_in_period
                     AND gh.je_header_id = gb.je_header_id
                     AND gb.code_combination_id = p_in_ccid
                     AND gb.ledger_id = b.ledger_id
                     AND b.ledger_id <> 2081
                     AND b.currency_code = gh.currency_code
                     AND ledger_category_code = 'PRIMARY'
                     AND gb.je_header_id = NVL (p_header_id, gb.je_header_id)
                     AND gb.je_line_num = NVL (p_line_num, gb.je_line_num)
            GROUP BY b.currency_code, b.ledger_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- if Y company dff lvel, take the ledger id associated as secondary ledger in the balancing segment and check the currency of gl_ledgers,
        --          then get the accounted amount of that currency

        IF p_in_alt_currency IS NULL
        THEN
            IF l_bl_alt_curr_flag = 'Y'
            THEN
                BEGIN
                    SELECT SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                      INTO p_out_pri_gl_alt_bal
                      FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
                     WHERE     gb.period_name = p_in_period
                           AND gh.je_header_id = gb.je_header_id
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.ledger_id = l_secondary_ledger
                           AND b.ledger_id <> 2081
                           AND gb.je_header_id =
                               NVL (p_header_id, gb.je_header_id)
                           AND gb.je_line_num =
                               NVL (p_line_num, gb.je_line_num)
                           AND gh.currency_code =
                               (SELECT currency_code
                                  FROM gl_ledgers
                                 WHERE ledger_id = l_secondary_ledger);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        ELSE -- p_in_alt_currency is not null i.e vs has the alternate currency entered
            BEGIN
                SELECT SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                  INTO p_out_pri_gl_alt_bal
                  FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
                 WHERE     gb.period_name = p_in_period
                       AND gh.je_header_id = gb.je_header_id
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.ledger_id <> 2081
                       AND ledger_category_code = 'PRIMARY'
                       AND gb.je_header_id =
                           NVL (p_header_id, gb.je_header_id)
                       AND gb.je_line_num = NVL (p_line_num, gb.je_line_num)
                       AND gh.currency_code = UPPER (p_in_alt_currency);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        -- REPORTING LEDGER

        BEGIN
            SELECT SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
              INTO p_out_pri_gl_rpt_bal
              FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
             WHERE     gb.period_name = p_in_period
                   AND gh.je_header_id = gb.je_header_id
                   AND gb.code_combination_id = p_in_ccid
                   AND gb.ledger_id = b.ledger_id
                   AND b.ledger_id <> 2081
                   AND b.currency_code = gh.currency_code
                   AND gb.je_header_id = NVL (p_header_id, gb.je_header_id)
                   AND gb.je_line_num = NVL (p_line_num, gb.je_line_num)
                   AND ledger_category_code = 'ALC';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- SECONDARY LEDGER

        BEGIN
            SELECT SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
              INTO p_out_sec_gl_acct_bal
              FROM gl_je_headers gh, gl_je_lines gb, gl_ledgers b
             WHERE     gb.period_name = p_in_period
                   AND gh.je_header_id = gb.je_header_id
                   AND gb.code_combination_id = p_in_ccid
                   AND gb.ledger_id = b.ledger_id
                   AND b.ledger_id <> 2081
                   AND b.ledger_id = l_secondary_ledger
                   AND gb.je_header_id = NVL (p_header_id, gb.je_header_id)
                   AND gb.je_line_num = NVL (p_line_num, gb.je_line_num)
                   AND ledger_category_code = 'SECONDARY';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_jl_ccid_values;

    -- ======================================================================================
    -- This procedure is used to get the account balances
    -- ======================================================================================

    PROCEDURE get_ccid_values (p_in_ccid IN NUMBER, p_in_company IN NUMBER, p_in_alt_currency IN VARCHAR2, p_in_period IN VARCHAR2, p_close_method IN VARCHAR2, p_out_activty_in_prd OUT VARCHAR2, p_out_active_acct OUT VARCHAR2, p_out_pri_gl_rpt_bal OUT NUMBER, p_out_pri_gl_alt_bal OUT NUMBER, p_out_pri_gl_acct_bal OUT NUMBER, p_out_sec_gl_rpt_bal OUT NUMBER, p_out_sec_gl_alt_bal OUT NUMBER
                               , p_out_sec_gl_acct_bal OUT NUMBER, p_out_alt_currency OUT VARCHAR2, p_out_primary_currency OUT VARCHAR2)
    IS
        l_secondary_ledger        NUMBER;
        l_bl_alt_curr_flag        VARCHAR2 (10);
        p_pri_ledger_id           NUMBER;
        p_pri_gl_acct_bal_begin   NUMBER;
        lv_ytd_period             VARCHAR2 (10);
        lv_qtd_period             VARCHAR2 (10);
        lv_mtd_period             VARCHAR2 (10);
    BEGIN
        -- query to check close method and fetch the date to get opening balance.
        BEGIN
            SELECT (SELECT period_name
                      FROM gl_periods b
                     WHERE     b.start_date = a.year_start_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       year_start_period,
                   (SELECT period_name
                      FROM gl_periods b
                     WHERE     b.start_date = a.quarter_start_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       year_start_period,
                   (SELECT period_name
                      FROM gl_periods b
                     WHERE     b.start_date = a.start_date
                           AND period_set_name = 'DO_FY_CALENDAR')
                       year_start_period
              INTO lv_ytd_period, lv_qtd_period, lv_mtd_period
              FROM gl_periods a
             WHERE     period_name = p_in_period
                   AND period_set_name = 'DO_FY_CALENDAR';
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- PICK THE SECONDARY LEDGER/ atl currency flag From THE COMPANY DFF

        BEGIN
            SELECT c.currency_code, TO_NUMBER (b.attribute8), b.attribute1
              INTO p_out_alt_currency, l_secondary_ledger, l_bl_alt_curr_flag
              FROM fnd_flex_value_sets a, fnd_flex_values b, gl_ledgers c
             WHERE     a.flex_value_set_name = 'DO_GL_COMPANY'
                   AND a.flex_value_set_id = b.flex_value_set_id
                   AND b.attribute8 = ledger_id
                   AND flex_value = p_in_company;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        -- PIRMARY BALANCE

        IF NVL (p_close_method, 'MTD') = 'NA'
        THEN
            p_out_pri_gl_acct_bal   := NULL;
        ELSE
            BEGIN
                SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)), b.currency_code, b.ledger_id
                  INTO p_out_pri_gl_acct_bal, p_out_primary_currency, p_pri_ledger_id
                  FROM gl_balances gb, gl_ledgers b
                 WHERE     1 = 1
                       AND ((period_name = lv_ytd_period AND NVL (p_close_method, 'MTD') = 'YTD') OR (period_name = lv_qtd_period AND NVL (p_close_method, 'MTD') = 'QTD') OR (period_name = lv_mtd_period AND NVL (p_close_method, 'MTD') = 'MTD'))
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

        -- if Y company dff lvel, take the ledger id associated as secondary ledger in the balancing segment and check the currency of gl_ledgers,
        --          then get the accounted amount of that currency

        IF NVL (p_close_method, 'MTD') = 'NA'
        THEN
            p_out_pri_gl_alt_bal   := NULL;
        ELSE
            IF p_in_alt_currency IS NULL
            THEN
                IF l_bl_alt_curr_flag = 'Y'
                THEN
                    BEGIN
                        SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)) begin_bal
                          INTO p_out_pri_gl_alt_bal
                          FROM gl_balances gb, gl_ledgers b
                         WHERE     ((period_name = lv_ytd_period AND NVL (p_close_method, 'MTD') = 'YTD') OR (period_name = lv_qtd_period AND NVL (p_close_method, 'MTD') = 'QTD') OR (period_name = lv_mtd_period AND NVL (p_close_method, 'MTD') = 'MTD'))
                               AND gb.code_combination_id = p_in_ccid
                               AND gb.ledger_id = b.ledger_id
                               AND b.ledger_id <> 2081
                               AND b.ledger_id = l_secondary_ledger
                               AND gb.currency_code =
                                   (SELECT currency_code
                                      FROM gl_ledgers
                                     WHERE ledger_id = l_secondary_ledger);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                END IF;
            ELSE -- p_in_alt_currency is not null i.e vs has the alternate currency entered
                BEGIN
                    SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)) begin_bal
                      INTO p_out_pri_gl_alt_bal
                      FROM gl_balances gb, gl_ledgers b
                     WHERE     ((period_name = lv_ytd_period AND NVL (p_close_method, 'MTD') = 'YTD') OR (period_name = lv_qtd_period AND NVL (p_close_method, 'MTD') = 'QTD') OR (period_name = lv_mtd_period AND NVL (p_close_method, 'MTD') = 'MTD'))
                           AND gb.code_combination_id = p_in_ccid
                           AND gb.ledger_id = b.ledger_id
                           AND b.ledger_id <> 2081
                           AND ledger_category_code = 'PRIMARY'
                           AND gb.currency_code = UPPER (p_in_alt_currency);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        END IF;

        -- REPORTING LEDGER

        IF NVL (p_close_method, 'MTD') = 'NA'
        THEN
            p_out_pri_gl_rpt_bal   := NULL;
        ELSE
            BEGIN
                SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)) end_bal
                  INTO p_out_pri_gl_rpt_bal
                  FROM gl_balances gb, gl_ledgers b
                 WHERE     ((period_name = lv_ytd_period AND NVL (p_close_method, 'MTD') = 'YTD') OR (period_name = lv_qtd_period AND NVL (p_close_method, 'MTD') = 'QTD') OR (period_name = lv_mtd_period AND NVL (p_close_method, 'MTD') = 'MTD'))
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.ledger_id <> 2081
                       AND b.currency_code = gb.currency_code
                       AND ledger_category_code = 'ALC';
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        -- SECONDARY LEDGER

        IF NVL (p_close_method, 'MTD') = 'NA'
        THEN
            p_out_sec_gl_acct_bal   := NULL;
        ELSE
            BEGIN
                SELECT (NVL (gb.begin_balance_dr, 0) - NVL (gb.begin_balance_cr, 0)) end_bal
                  INTO p_out_sec_gl_acct_bal
                  FROM gl_balances gb, gl_ledgers b
                 WHERE     ((period_name = lv_ytd_period AND NVL (p_close_method, 'MTD') = 'YTD') OR (period_name = lv_qtd_period AND NVL (p_close_method, 'MTD') = 'QTD') OR (period_name = lv_mtd_period AND NVL (p_close_method, 'MTD') = 'MTD'))
                       AND gb.code_combination_id = p_in_ccid
                       AND gb.ledger_id = b.ledger_id
                       AND b.ledger_id <> 2081
                       AND b.ledger_id = l_secondary_ledger
                       AND b.currency_code = gb.currency_code
                       AND ledger_category_code = 'SECONDARY';
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        IF    p_out_pri_gl_acct_bal > 0
           OR     p_pri_gl_acct_bal_begin > 0
              AND p_out_pri_gl_acct_bal <> p_pri_gl_acct_bal_begin
        THEN
            p_out_activty_in_prd   := 'TRUE';
        ELSE
            p_out_activty_in_prd   := 'FALSE';
        END IF;

        SELECT DECODE (enabled_flag, 'Y', 'TRUE', 'FALSE')
          INTO p_out_active_acct
          FROM gl_code_combinations
         WHERE code_combination_id = p_in_ccid;

        IF (p_out_active_acct = 'FALSE' AND p_out_activty_in_prd = 'TRUE')
        THEN                                     -- AND HAS ACTIVITY IN PERIOD
            p_out_active_acct   := 'TRUE';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            NULL;
    END get_ccid_values;

    -- ======================================================================================
    -- This procedure is used to insert the eligible journals into custom table
    -- ======================================================================================

    PROCEDURE insert_prc (p_ledger_type             IN     VARCHAR2,
                          p_ledger_id               IN     NUMBER,
                          p_period                  IN     VARCHAR2,
                          p_open_balances_only      IN     VARCHAR2,
                          p_summerize_sub_ledger    IN     VARCHAR2,
                          p_summerize_manual        IN     VARCHAR2,
                          p_account_from            IN     VARCHAR2,
                          p_account_to              IN     VARCHAR2,
                          p_file_path               IN     VARCHAR2,
                          p_current_period          IN     VARCHAR2,
                          p_previous_period         IN     VARCHAR2,
                          p_override_lastrun        IN     VARCHAR2,
                          p_override_definition     IN     VARCHAR2,
                          p_file_path_only          IN     VARCHAR2,
                          p_jl_creation_date_from   IN     VARCHAR2,
                          p_jl_creation_date_to     IN     VARCHAR,
                          p_source                  IN     VARCHAR2,
                          p_category                IN     VARCHAR2,
                          p_source_type             IN     VARCHAR2,
                          p_errbuf                     OUT VARCHAR2,
                          p_retcode                    OUT NUMBER)
    IS
        -- This cursor is when p_override_definition = 'N'
        -- due toperformance issue removed secondary ledgers from the below cursor and created new cursor

        CURSOR eligible_journals_det (l_last_run_date IN VARCHAR2, L_LAST_RUN_DATE_REVAL IN VARCHAR2, l_last_run_date_subled IN VARCHAR2)
        IS
            -- first cursor is for manual detail
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           DECODE (gjh.reversed_je_header_id,
                                   '', gjc.user_je_category_name,
                                   'Reverse-' || gjc.user_je_category_name)))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   xxd_gl_journals_extract_pkg.get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       xxd_gl_journals_extract_pkg.get_rep_ledger_amt (
                           gp.period_name,
                           gcc.code_combination_id,
                           led.ledger_id,
                           gjh.je_header_id,
                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   NVL (ccid_table.summarize_manual, 'DETAIL')
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end
                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND NVL (ccid_table.summarize_manual, 'DETAIL') IN
                           ('DETAIL', 'DETAIL-NR')
                   AND NVL (gjc.attribute2, 'N') = 'Y'
                   AND ((gjh.reversed_je_header_id IS NOT NULL AND NVL (ccid_table.summarize_manual, 'DETAIL') = 'DETAIL-NR') OR (1 = 1 AND NVL (ccid_table.summarize_manual, 'DETAIL') = 'DETAIL'))
                   AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) -- AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                             --    NVL (SYSDATE, gjl.last_update_date) --1.1
                                                                                                                                                                                                                                                                                                                                                                                                             AND NVL (p_override_lastrun, 'N') = 'N'))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Manual'
                   AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                   AND gjs.je_source_name <> 'Revaluation'
            -- the below union is for manual - summary
            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     ccid_table.summarize_manual
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end
                     AND gjh.reversed_je_header_id IS NULL -- for non-reversal
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND NVL (ccid_table.summarize_manual, 'DETAIL') IN
                             ('SUMMARY', 'SUMMARY-NR')
                     AND NVL (gjc.attribute2, 'N') = 'Y'
                     AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                               -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                               AND NVL (p_override_lastrun, 'N') = 'N'))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Manual'
                     AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2, ccid_table.summarize_manual
            -- union for reversal manual summary

            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || 'Reverse' || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'Reverse-' || gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     ccid_table.summarize_manual
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end
                     AND gjh.reversed_je_header_id IS NOT NULL -- for reversal
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND NVL (ccid_table.summarize_manual, 'DETAIL') =
                         'SUMMARY'
                     AND NVL (gjc.attribute2, 'N') = 'Y'
                     AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                               --NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                               AND NVL (p_override_lastrun, 'N') = 'N'))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Manual'
                     AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2, ccid_table.summarize_manual
            -- the below union is for detail  revaluation
            UNION ALL
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   /*TO_CHAR (get_close_date (('MTD'), gp.period_name),
                            'MM/DD/YYYY')
                       close_date,*/
                   -- 1.1
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,                                      -- 1.1
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           gjc.user_je_category_name))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       get_rep_ledger_amt (gp.period_name,
                                           gcc.code_combination_id,
                                           led.ledger_id,
                                           gjh.je_header_id,
                                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   'REVAL'
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end
                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND gjc.je_category_name = 'Revaluation'
                   AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date_reval, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) -- AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                                   -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                                   AND NVL (p_override_lastrun, 'N') = 'N'))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Revaluation'
                   AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                   --------------
                   AND ((((ccid_table.summerize_reve = 'NON-REVERSAL' AND gjh.reversed_je_header_id IS NULL) AND p_ledger_type = 'Primary') OR (ccid_table.summerize_reve = 'ALL' AND 1 = 1 AND p_ledger_type = 'Primary')) OR ((ccid_table.sec_summ_reve = 'NON-REVERSAL' AND gjh.reversed_je_header_id IS NULL) AND p_ledger_type = 'Secondary') OR (ccid_table.sec_summ_reve = 'ALL' AND 1 = 1 AND p_ledger_type = 'Secondary'))
                   AND NVL (ccid_table.summerize_reve, 'NA') <> 'NA'
                   AND gjs.je_source_name = 'Revaluation'
            UNION ALL
            -- The below union is for detail Sub ledger
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           gjc.user_je_category_name))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   xxd_gl_journals_extract_pkg.get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       xxd_gl_journals_extract_pkg.get_rep_ledger_amt (
                           gp.period_name,
                           gcc.code_combination_id,
                           led.ledger_id,
                           gjh.je_header_id,
                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   'DETAIL'
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, XXDO.XXD_GL_JE_LINES_SUBLED_T gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end
                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND NVL (ccid_table.sumarize_subledger, 'DETAIL') =
                       'DETAIL'
                   AND NVL (gjc.attribute2, 'N') = 'N'
                   AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date_subled, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) -- AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                                    -- NVL (SYSDATE, gjl.last_update_date) --1.1
                                                                                                                                                                                                                                                                                                                                                                                                                    AND NVL (p_override_lastrun, 'N') = 'N'))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Subledger'
                   AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                   AND gjs.je_source_name <> 'Revaluation'
            -- The below union is for summary subledger
            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     'SUMMARY'
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, XXDO.XXD_GL_JE_LINES_SUBLED_T gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND NVL (ccid_table.sumarize_subledger, 'DETAIL') =
                         'SUMMARY'
                     AND NVL (gjc.attribute2, 'N') = 'N'
                     AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date_subled, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) -- AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                                      -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                                      AND NVL (p_override_lastrun, 'N') = 'N'))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Subledger'
                     AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2;

        -- The below cursor is for open_balance_only
        CURSOR open_balances_only IS
            SELECT /*+parallel(8)*/
                   gcc.code_combination_id
                       ccid,
                   NULL
                       je_header_id,
                   NULL
                       je_line_num,
                   gp.period_name,
                   gll.ledger_id,
                   gll.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   DECODE (
                       p_ledger_type,
                       'Primary', (SELECT attribute43
                                     FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                    WHERE vs_line_identifier =
                                          acc_ext.vs_unique_identifier),
                       'Secondary', (SELECT attribute49
                                       FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                      WHERE vs_line_identifier =
                                            acc_ext.vs_unique_identifier))
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   DECODE (
                       p_ledger_type,
                       'Primary', (   REPLACE (
                                          (get_uniq_iden_period (
                                               gp.period_name,
                                               (DECODE (
                                                    p_ledger_type,
                                                    'Primary', (SELECT attribute43
                                                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                                 WHERE vs_line_identifier =
                                                                       acc_ext.vs_unique_identifier),
                                                    'Secondary', (SELECT attribute49
                                                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                                   WHERE vs_line_identifier =
                                                                         acc_ext.vs_unique_identifier))))),
                                          '-',
                                          '')
                                   || gcc.code_combination_id),
                       (   REPLACE (
                               (get_uniq_iden_period (
                                    gp.period_name,
                                    (DECODE (
                                         p_ledger_type,
                                         'Primary', (SELECT attribute43
                                                       FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                      WHERE vs_line_identifier =
                                                            acc_ext.vs_unique_identifier),
                                         'Secondary', (SELECT attribute49
                                                         FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                        WHERE vs_line_identifier =
                                                              acc_ext.vs_unique_identifier))))),
                               '-',
                               '')
                        || gcc.code_combination_id
                        || 'STAT'))
                       unique_identifier,
                   TO_CHAR (gp.start_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.start_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (
                       get_close_date (
                           (SELECT attribute43
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           xgp.period_name),
                       'MM/DD/YYYY')
                       close_date,
                   'General'
                       item_type,
                   'OpeningBalance'
                       item_sub_types,
                   NULL
                       item_summary,
                   NULL
                       item_impact_code,
                   'L'
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       (   'Opening Balance'
                        || ' '
                        || REPLACE (
                               (get_uniq_iden_period (
                                    xgp.period_name,
                                    (DECODE (
                                         p_ledger_type,
                                         'Primary', (SELECT attribute43
                                                       FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                      WHERE vs_line_identifier =
                                                            acc_ext.vs_unique_identifier),
                                         'Secondary', (SELECT attribute49
                                                         FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                        WHERE vs_line_identifier =
                                                              acc_ext.vs_unique_identifier))))),
                               '-',
                               '')
                        || ' '
                        || gcc.code_combination_id),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   NULL
                       item_amount_alt_curr,
                   NULL
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   (NVL (gb.period_net_dr, 0) - NVL (gb.period_net_cr, 0))
                       item_amount_transact_currency,
                   gll.currency_code
                       item_currency,
                   NULL
                       file_path,
                   'OPEN'
                       report_type
              FROM apps.gl_balances gb, apps.gl_ledgers gll, apps.gl_code_combinations_kfv gcc,
                   apps.gl_period_statuses gp, xxdo.xxd_gl_acc_recon_extract_t acc_ext, xxdo.xxd_gl_ccid_identify_t ccid_table,
                   xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gb.code_combination_id
                   AND gb.ledger_id = gll.ledger_id
                   AND gb.code_combination_id = gcc.code_combination_id
                   AND gb.currency_code = gll.currency_code
                   AND gp.application_id = 101
                   AND acc_ext.extract_level = 2
                   AND acc_ext.ccid IS NOT NULL
                   AND gll.ledger_id <> 2081
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND acc_ext.ccid = gcc.code_combination_id
                   AND gb.period_name = gp.period_name
                   AND gp.ledger_id = gb.ledger_id
                   AND gb.ledger_id = NVL (p_ledger_id, gb.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 1),
                                            gcc.segment1)
                   AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 1),
                                            gcc.segment1)
                   AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 2),
                                            gcc.segment2)
                   AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 2),
                                            gcc.segment2)
                   AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 3),
                                            gcc.segment3)
                   AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 3),
                                            gcc.segment3)
                   AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 4),
                                            gcc.segment4)
                   AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 4),
                                            gcc.segment4)
                   AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 5),
                                            gcc.segment5)
                   AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 5),
                                            gcc.segment5)
                   AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 6),
                                            gcc.segment6)
                   AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 6),
                                            gcc.segment6)
                   AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 7),
                                            gcc.segment7)
                   AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 7),
                                            gcc.segment7)
                   AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 8),
                                            gcc.segment8)
                   AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 8),
                                            gcc.segment8)
                   AND NVL (p_open_balances_only, 'N') = 'Y'
                   AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY'))
                   AND ((p_ledger_type = 'Primary' AND NVL (ccid_table.open_balance_type, 'No') <> 'No') OR (p_ledger_type = 'Secondary' AND NVL (ccid_table.sec_open_bal_typ, 'No') <> 'No'));

        -- query for file path only
        CURSOR filepath_only_cur IS
              SELECT ----
                     MIN (ccid) ccid, NULL je_header_id, NULL je_line_num,
                     period_name, ledger_id, name,
                     /*  min( entity_unique_identifier) entity_unique_identifier,
                        MIN( account) account,
                       MIN(brand) brand,
                       MIN( geo) geo,
                        MIN(channel) channel,
                        MIN(costcenter) costcenter,
                        MIN(intercompany) intercompany,
                        MIN(futureuse) futureuse,*/
                     --1.1
                     get_account_info (MIN (ccid), 'Company') entity_unique_identifier, get_account_info (MIN (ccid), 'Account') account, get_account_info (MIN (ccid), 'Brand') brand,
                     get_account_info (MIN (ccid), 'Geo') geo, get_account_info (MIN (ccid), 'Channel') channel, get_account_info (MIN (ccid), 'Cost_Center') costcenter,
                     get_account_info (MIN (ccid), 'IC') intercompany, get_account_info (MIN (ccid), 'Future') futureuse, --1.1
                                                                                                                          NULL key9,
                     NULL key10, ccid_method, NULL alt_currency,
                     close_method, statuary_ledger, --

                                                    unique_identifier,
                     origination_date, open_date, close_date,
                     'General' item_type, 'filepath' item_sub_types, NULL item_summary,
                     NULL item_impact_code, 'L' item_class, 'G' adjustment_destination,
                     'FALSE' item_editable_by_preparers, description, NULL reference,
                     NULL item_total, NULL reference_field1, NULL reference_field2,
                     NULL reference_field3, NULL reference_field4, NULL reference_field5,
                     NULL item_amount_alt_curr, NULL item_amount_reporting_currency, NULL item_amount_glaccount_currency,
                     item_amount_transact_currency, item_currency, file_path,
                     'PATH' report_type
                ----
                FROM (  SELECT MIN (gcc.code_combination_id)
                                   ccid,
                               NULL
                                   je_header_id,
                               NULL
                                   je_line_num,
                               gp.period_name,
                               gll.ledger_id,
                               gll.name,
                               /* get_account_info (MIN (gcc.code_combination_id),'Company') entity_unique_identifier,
                                get_account_info (MIN (gcc.code_combination_id),'Account') account,
                                get_account_info (MIN (gcc.code_combination_id), 'Brand')  brand,
                                get_account_info (MIN (gcc.code_combination_id), 'Geo')   geo,
                                get_account_info (MIN (gcc.code_combination_id), 'Channel')  channel,
                                get_account_info (MIN (gcc.code_combination_id),  'Cost_Center') costcenter,
                                get_account_info (MIN (gcc.code_combination_id), 'IC') intercompany,
                                get_account_info (MIN (gcc.code_combination_id), 'Future')futureuse,*/
                               --1.1
                               NULL
                                   key9,
                               NULL
                                   key10,
                               DECODE (
                                   p_ledger_type,
                                   'Primary', (SELECT attribute43
                                                 FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                WHERE vs_line_identifier =
                                                      acc_ext.vs_unique_identifier),
                                   'Secondary', (SELECT attribute49
                                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                  WHERE vs_line_identifier =
                                                        acc_ext.vs_unique_identifier))
                                   ccid_method,
                               NULL
                                   alt_currency,
                               (SELECT close_method
                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                 WHERE vs_line_identifier =
                                       acc_ext.vs_unique_identifier)
                                   close_method,
                               (SELECT statuary_ledger
                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                 WHERE vs_line_identifier =
                                       acc_ext.vs_unique_identifier)
                                   statuary_ledger,
                               --
                               DECODE (
                                   p_ledger_type,
                                   'Primary', (REPLACE ((gp.period_name) || DECODE (a.bl_account_group_name, --1.1
                                                                                                             '', TO_CHAR (acc_ext.ccid), 'GRP' || NVL (a.attribute30_2, gcc.segment1) || REPLACE (a.bl_account_group_name, --1.1
                                                                                                                                                                                                                           ' ', '')) || 'PATH', '-', '')),
                                   (REPLACE ((gp.period_name) || DECODE (a.bl_account_group_name, --1.1
                                                                                                  '', TO_CHAR (acc_ext.ccid), 'GRP' || NVL (a.attribute30_2, gcc.segment1) || REPLACE (a.bl_account_group_name, ' ', '')) --1.1
                                                                                                                                                                                                                          || 'STAT' || 'PATH', '-', '')))
                                   unique_identifier,
                               TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                                   origination_date,
                               TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                                   open_date,
                               TO_CHAR ((gp.end_date + 1), 'MM/DD/YYYY')
                                   close_date,
                               'General'
                                   item_type,
                               'filepath'
                                   item_sub_types,
                               NULL
                                   item_summary,
                               NULL
                                   item_impact_code,
                               'L'
                                   item_class,
                               'G'
                                   adjustment_destination,
                               'FALSE'
                                   item_editable_by_preparers,
                               MIN (
                                   NVL (
                                       SUBSTR (
                                           (SELECT DECODE (
                                                       attribute44,
                                                       '', '',
                                                          --
                                                          attribute44
                                                       || (SELECT attribute9
                                                             FROM apps.fnd_flex_values_vl
                                                            WHERE     flex_value_set_id =
                                                                      1015911
                                                                  AND flex_value =
                                                                      gcc.segment1
                                                                  AND attribute9
                                                                          IS NOT NULL) -- DO_GL_COMPANY
                                                       || xxd_gl_journals_extract_pkg.get_period_year (
                                                              gll.period_set_name,
                                                              gps.period_name)
                                                       || '\'
                                                       || xxd_gl_journals_extract_pkg.get_period_num (
                                                              gll.period_set_name,
                                                              gps.period_name)
                                                       || '.'
                                                       || gps.period_name
                                                       || (SELECT attribute45
                                                             FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                                            WHERE vs_line_identifier =
                                                                  acc_ext.vs_unique_identifier)) --
                                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                             WHERE vs_line_identifier =
                                                   acc_ext.vs_unique_identifier),
                                           1,
                                           2000),
                                       SUBSTR (xxd_gl_journals_extract_pkg.get_file_path (
                                                   gll.period_set_name,
                                                   gps.period_name,
                                                   gcc.segment3,
                                                   acc_ext.vs_unique_identifier,
                                                   gcc.segment1),
                                               1,
                                               2000)))
                                   description,
                               NULL
                                   reference,
                               NULL
                                   item_total,
                               NULL
                                   reference_field1,
                               NULL
                                   reference_field2,
                               NULL
                                   reference_field3,
                               NULL
                                   reference_field4,
                               NULL
                                   reference_field5,
                               NULL
                                   item_amount_alt_curr,
                               NULL
                                   item_amount_reporting_currency,
                               NULL
                                   item_amount_glaccount_currency,
                               0
                                   item_amount_transact_currency,
                               gll.currency_code
                                   item_currency,
                               (SELECT attribute44
                                  FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                 WHERE vs_line_identifier =
                                       acc_ext.vs_unique_identifier)
                                   file_path,
                               'PATH'
                                   report_type
                          FROM apps.gl_balances gb, apps.gl_ledgers gll, apps.gl_code_combinations_kfv gcc,
                               apps.gl_periods gps, apps.gl_period_statuses gp, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                               xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.xxd_gl_period_name_gt xgp, apps.xxd_gl_bl_acct_bal_vs_attrs_v a
                         WHERE     1 = 1
                               AND ccid_table.ccid = gb.code_combination_id
                               AND gb.ledger_id = gll.ledger_id
                               AND gb.code_combination_id =
                                   gcc.code_combination_id
                               AND gb.currency_code = gll.currency_code
                               AND gp.application_id = 101
                               AND gll.ledger_id <> 2081
                               --AND gps.period_set_name = 'DO_FY_CALENDAR'
                               AND acc_ext.ccid = gcc.code_combination_id
                               AND gb.period_name = gp.period_name
                               AND gb.period_name = gps.period_name
                               AND gp.ledger_id = gb.ledger_id
                               AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY'))
                               AND acc_ext.extract_level = 2
                               AND acc_ext.vs_unique_identifier IS NOT NULL
                               AND gb.ledger_id = NVL (p_ledger_id, gb.ledger_id)
                               AND xgp.ledger_id = gll.ledger_id
                               AND gb.period_name = xgp.period_name
                               AND gll.period_set_name = gps.period_set_name
                               AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 1),
                                                        gcc.segment1)
                               AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 1),
                                                        gcc.segment1)
                               AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 2),
                                                        gcc.segment2)
                               AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 2),
                                                        gcc.segment2)
                               AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 3),
                                                        gcc.segment3)
                               AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 3),
                                                        gcc.segment3)
                               AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 4),
                                                        gcc.segment4)
                               AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 4),
                                                        gcc.segment4)
                               AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 5),
                                                        gcc.segment5)
                               AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 5),
                                                        gcc.segment5)
                               AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 6),
                                                        gcc.segment6)
                               AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 6),
                                                        gcc.segment6)
                               AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 7),
                                                        gcc.segment7)
                               AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 7),
                                                        gcc.segment7)
                               AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                                       , 8),
                                                        gcc.segment8)
                               AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                                       , 8),
                                                        gcc.segment8)
                               AND NVL (p_file_path_only, 'N') = 'Y'
                               AND (ccid_table.file_path IS NOT NULL OR ccid_table.file_path_EMEA IS NOT NULL OR ccid_table.file_path_apac IS NOT NULL OR ccid_table.file_path_na IS NOT NULL)
                               AND a.vs_line_identifier =
                                   acc_ext.vs_unique_identifier
                               AND acc_ext.ccid IS NOT NULL
                               AND NOT EXISTS
                                       (SELECT 1
                                          FROM xxdo.xxd_gl_journals_extract_t c
                                         WHERE     1 = 1
                                               AND c.report_type = 'PATH'
                                               AND c.sent_to_blackline
                                                       IS NOT NULL
                                               AND c.period_name =
                                                   gps.period_name
                                               --AND c.ccid = acc_ext.ccid
                                               AND c.unique_identifier =
                                                   DECODE (
                                                       p_ledger_type,
                                                       'Primary', (REPLACE ((gp.period_name) || DECODE (a.bl_account_group_name, --1.1
                                                                                                                                 '', TO_CHAR (acc_ext.ccid), 'GRP' || NVL (a.attribute30_2, gcc.segment1) || REPLACE (a.bl_account_group_name, --1.1
                                                                                                                                                                                                                                               ' ', '')) || 'PATH', '-', '')),
                                                       (REPLACE ((gp.period_name) || DECODE (a.bl_account_group_name, --1.1
                                                                                                                      '', TO_CHAR (acc_ext.ccid), 'GRP' || NVL (a.attribute30_2, gcc.segment1) || REPLACE (a.bl_account_group_name, --1.1
                                                                                                                                                                                                                                    ' ', '')) || 'STAT' || 'PATH', '-', ''))))
                      GROUP BY gp.period_name, gll.ledger_id, gll.name,
                               --gcc.segment1,
                               acc_ext.vs_unique_identifier, -- ccid_method,
                                                             /*
                                                             a.bl_account_group_name,--1.1
                                                             acc_ext.ccid),
                                                             a.attribute30_2,*/
                                                             TO_CHAR (gp.end_date, 'MM/DD/YYYY'), TO_CHAR ((gp.end_date + 1), 'MM/DD/YYYY'),
                               attribute44, gll.currency_code, DECODE (p_ledger_type, 'Primary', (REPLACE ((gp.period_name) || DECODE (a.bl_account_group_name, --1.1
                                                                                                                                                                '', TO_CHAR (acc_ext.ccid), 'GRP' || NVL (a.attribute30_2, gcc.segment1) || REPLACE (a.bl_account_group_name, --1.1
                                                                                                                                                                                                                                                                              ' ', '')) || 'PATH', '-', '')), (REPLACE ((gp.period_name) || DECODE (a.bl_account_group_name, --1.1
                                                                                                                                                                                                                                                                                                                                                                             '', TO_CHAR (acc_ext.ccid), 'GRP' || NVL (a.attribute30_2, gcc.segment1) || REPLACE (a.bl_account_group_name, ' ', '')) --1.1
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     || 'STAT' || 'PATH', '-', ''))))
                     a
               WHERE 1 = 1
            GROUP BY period_name, ledger_id, name,
                     ccid_method, close_method, statuary_ledger,
                     unique_identifier, origination_date, open_date,
                     close_date, description, item_amount_transact_currency,
                     item_currency, file_path;

        -- the below cursor for override_defination is N and ledger_type is SECONDARY
        --Due to performance issue seperated the secondary ledger from the above query
        CURSOR eligible_journals_det_sec (l_last_run_date IN VARCHAR2, L_LAST_RUN_DATE_REVAL IN VARCHAR2, l_last_run_date_subled IN VARCHAR2)
        IS
            -- first cursor is for manual detail
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           DECODE (gjh.reversed_je_header_id,
                                   '', gjc.user_je_category_name,
                                   'Reverse-' || gjc.user_je_category_name)))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   xxd_gl_journals_extract_pkg.get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       xxd_gl_journals_extract_pkg.get_rep_ledger_amt (
                           gp.period_name,
                           gcc.code_combination_id,
                           led.ledger_id,
                           gjh.je_header_id,
                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   NVL (ccid_table.sec_sum_manual, 'DETAIL')
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end
                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND NVL (ccid_table.sec_sum_manual, 'DETAIL') IN
                           ('DETAIL', 'DETAIL-NR')
                   AND NVL (gjc.attribute2, 'N') = 'Y'
                   AND ((gjh.reversed_je_header_id IS NOT NULL AND NVL (ccid_table.sec_sum_manual, 'DETAIL') = 'DETAIL-NR') OR (1 = 1 AND NVL (ccid_table.sec_sum_manual, 'DETAIL') = 'DETAIL'))
                   AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                             -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                             AND NVL (p_override_lastrun, 'N') = 'N'))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Manual'
                   AND p_ledger_type = 'Secondary'
                   AND ccid_table.statuary_ledger = 'Y'
                   AND ledger_category_code = 'SECONDARY'
                   AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')
                   AND gjs.je_source_name <> 'Revaluation'
            -- the below union is for manual - summary
            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     ccid_table.sec_sum_manual
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end
                     AND gjh.reversed_je_header_id IS NULL -- for non-reversal
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND NVL (ccid_table.sec_sum_manual, 'DETAIL') IN
                             ('SUMMARY', 'SUMMARY-NR')
                     AND NVL (gjc.attribute2, 'N') = 'Y'
                     AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                               -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                               AND NVL (p_override_lastrun, 'N') = 'N'))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Manual'
                     AND p_ledger_type = 'Secondary'
                     AND ccid_table.statuary_ledger = 'Y'
                     AND ledger_category_code = 'SECONDARY'
                     AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2, ccid_table.sec_sum_manual
            -- union for reversal manual summary

            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || 'Reverse' || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'Reverse-' || gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     ccid_table.sec_sum_manual
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end
                     AND gjh.reversed_je_header_id IS NOT NULL -- for reversal
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND NVL (ccid_table.sec_sum_manual, 'DETAIL') = 'SUMMARY'
                     AND NVL (gjc.attribute2, 'N') = 'Y'
                     AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) -- AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                               -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                               AND NVL (p_override_lastrun, 'N') = 'N'))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Manual'
                     AND p_ledger_type = 'Secondary'
                     AND ccid_table.statuary_ledger = 'Y'
                     AND ledger_category_code = 'SECONDARY'
                     AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2, ccid_table.sec_sum_manual
            -- the below union is for detail  revaluation
            UNION ALL
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (get_close_date (('MTD'), gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           gjc.user_je_category_name))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       get_rep_ledger_amt (gp.period_name,
                                           gcc.code_combination_id,
                                           led.ledger_id,
                                           gjh.je_header_id,
                                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   'REVAL'
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end
                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND gjc.je_category_name = 'Revaluation'
                   AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date_reval, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                                   --  NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                                   AND NVL (p_override_lastrun, 'N') = 'N'))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Revaluation'
                   AND p_ledger_type = 'Secondary'
                   AND ccid_table.statuary_ledger = 'Y'
                   AND ledger_category_code = 'SECONDARY'
                   AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')
                   --------------
                   AND ((ccid_table.sec_summ_reve = 'NON-REVERSAL' AND gjh.reversed_je_header_id IS NULL AND p_ledger_type = 'Secondary') OR (ccid_table.sec_summ_reve = 'ALL' AND 1 = 1 AND p_ledger_type = 'Secondary'))
                   AND NVL (ccid_table.sec_summ_reve, 'NA') <> 'NA'
                   AND gjs.je_source_name = 'Revaluation'
            UNION ALL
            -- The below union is for detail Sub ledger
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           gjc.user_je_category_name))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   xxd_gl_journals_extract_pkg.get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       xxd_gl_journals_extract_pkg.get_rep_ledger_amt (
                           gp.period_name,
                           gcc.code_combination_id,
                           led.ledger_id,
                           gjh.je_header_id,
                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   'DETAIL'
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, XXDO.XXD_GL_JE_LINES_SUBLED_T gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end
                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND NVL (ccid_table.sec_sum_subledger, 'DETAIL') =
                       'DETAIL'
                   AND NVL (gjc.attribute2, 'N') = 'N'
                   AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date_subled, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                                    -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                                    AND NVL (p_override_lastrun, 'N') = 'N'))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Subledger'
                   AND p_ledger_type = 'Secondary'
                   AND ccid_table.statuary_ledger = 'Y'
                   AND ledger_category_code = 'SECONDARY'
                   AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')
                   AND gjs.je_source_name <> 'Revaluation'
            -- The below union is for summary subledger
            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     'SUMMARY'
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, XXDO.XXD_GL_JE_LINES_SUBLED_T gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND NVL (ccid_table.sec_sum_subledger, 'DETAIL') =
                         'SUMMARY'
                     AND NVL (gjc.attribute2, 'N') = 'N'
                     AND ((gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND NVL (p_override_lastrun, 'N') = 'Y') OR (gjl.last_update_date >= NVL (TO_DATE (l_last_run_date_subled, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) --AND gjl.last_update_date <=
                                                                                                                                                                                                                                                                                                                                                                                                                      -- NVL (SYSDATE, gjl.last_update_date)--1.1
                                                                                                                                                                                                                                                                                                                                                                                                                      AND NVL (p_override_lastrun, 'N') = 'N'))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Subledger'
                     AND p_ledger_type = 'Secondary'
                     AND ccid_table.statuary_ledger = 'Y'
                     AND ledger_category_code = 'SECONDARY'
                     AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2;


        -- seconday cursor end
        --

        -- the below cursor is for override_defination marked as Y
        CURSOR eligible_journals_det_override IS
            -- first cursor is for manual detail
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           DECODE (gjh.reversed_je_header_id,
                                   '', gjc.user_je_category_name,
                                   'Reverse-' || gjc.user_je_category_name)))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   xxd_gl_journals_extract_pkg.get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       xxd_gl_journals_extract_pkg.get_rep_ledger_amt (
                           gp.period_name,
                           gcc.code_combination_id,
                           led.ledger_id,
                           gjh.je_header_id,
                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   NVL (ccid_table.summarize_manual, 'DETAIL')
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end

                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 1),
                                            gcc.segment1)
                   AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 1),
                                            gcc.segment1)
                   AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 2),
                                            gcc.segment2)
                   AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 2),
                                            gcc.segment2)
                   AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 3),
                                            gcc.segment3)
                   AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 3),
                                            gcc.segment3)
                   AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 4),
                                            gcc.segment4)
                   AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 4),
                                            gcc.segment4)
                   AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 5),
                                            gcc.segment5)
                   AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 5),
                                            gcc.segment5)
                   AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 6),
                                            gcc.segment6)
                   AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 6),
                                            gcc.segment6)
                   AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 7),
                                            gcc.segment7)
                   AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 7),
                                            gcc.segment7)
                   AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 8),
                                            gcc.segment8)
                   AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 8),
                                            gcc.segment8)
                   AND NVL (p_summerize_manual, 'DETAIL') IN
                           ('DETAIL', 'DETAIL-NR')
                   AND NVL (gjc.attribute2, 'N') = 'Y'
                   AND ((gjh.reversed_je_header_id IS NOT NULL AND NVL (ccid_table.summarize_manual, 'DETAIL') = 'DETAIL-NR') OR (1 = 1 AND NVL (ccid_table.summarize_manual, 'DETAIL') = 'DETAIL'))
                   AND (gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Manual'
                   AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                   AND gjs.je_source_name <> 'Revaluation'
            -- the below union is for manual - summary
            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     ccid_table.summarize_manual
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end

                     AND gjh.reversed_je_header_id IS NULL -- for non-reversal
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 1),
                                              gcc.segment1)
                     AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 1),
                                              gcc.segment1)
                     AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 2),
                                              gcc.segment2)
                     AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 2),
                                              gcc.segment2)
                     AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 3),
                                              gcc.segment3)
                     AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 3),
                                              gcc.segment3)
                     AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 4),
                                              gcc.segment4)
                     AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 4),
                                              gcc.segment4)
                     AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 5),
                                              gcc.segment5)
                     AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 5),
                                              gcc.segment5)
                     AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 6),
                                              gcc.segment6)
                     AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 6),
                                              gcc.segment6)
                     AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 7),
                                              gcc.segment7)
                     AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 7),
                                              gcc.segment7)
                     AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 8),
                                              gcc.segment8)
                     AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 8),
                                              gcc.segment8)
                     AND NVL (p_summerize_manual, 'DETAIL') IN
                             ('SUMMARY', 'SUMMARY-NR')
                     AND NVL (gjc.attribute2, 'N') = 'Y'
                     AND (gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Manual'
                     AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2, ccid_table.summarize_manual
            -- union for reversal manual summary

            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || 'Reverse' || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'Reverse-' || gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     ccid_table.summarize_manual
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, apps.gl_je_lines gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end

                     AND gjh.reversed_je_header_id IS NOT NULL -- for reversal
                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 1),
                                              gcc.segment1)
                     AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 1),
                                              gcc.segment1)
                     AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 2),
                                              gcc.segment2)
                     AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 2),
                                              gcc.segment2)
                     AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 3),
                                              gcc.segment3)
                     AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 3),
                                              gcc.segment3)
                     AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 4),
                                              gcc.segment4)
                     AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 4),
                                              gcc.segment4)
                     AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 5),
                                              gcc.segment5)
                     AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 5),
                                              gcc.segment5)
                     AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 6),
                                              gcc.segment6)
                     AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 6),
                                              gcc.segment6)
                     AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 7),
                                              gcc.segment7)
                     AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 7),
                                              gcc.segment7)
                     AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 8),
                                              gcc.segment8)
                     AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 8),
                                              gcc.segment8)
                     AND NVL (p_summerize_manual, 'DETAIL') = 'SUMMARY'
                     AND NVL (gjc.attribute2, 'N') = 'Y'
                     AND (gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Manual'
                     AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2, ccid_table.summarize_manual
            UNION ALL
            -- The below union is for detail Sub ledger
            SELECT gcc.code_combination_id
                       ccid,
                   gjl.je_header_id,
                   gjl.je_line_num,
                   gjl.period_name,
                   gjl.ledger_id,
                   led.name,
                   gcc.segment1
                       entity_unique_identifier,
                   gcc.segment6
                       account,
                   gcc.segment2
                       brand,
                   gcc.segment3
                       geo,
                   gcc.segment4
                       channel,
                   gcc.segment5
                       costcenter,
                   gcc.segment7
                       intercompany,
                   gcc.segment8
                       futureuse,
                   NULL
                       key9,
                   NULL
                       key10,
                   NULL
                       ccid_method,
                   (SELECT alt_currency
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       alt_currency,
                   (SELECT close_method
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       close_method,
                   (SELECT statuary_ledger
                      FROM xxd_gl_bl_acct_bal_vs_attrs_v
                     WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                       statuary_ledger,
                   ('JN' || gjh.doc_sequence_value || 'JL' || je_line_num || 'JH' || gjh.je_header_id)
                       unique_identifier,
                   TO_CHAR (gjh.default_effective_date, 'MM/DD/YYYY')
                       origination_date,
                   TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                       open_date,
                   TO_CHAR (xxd_gl_journals_extract_pkg.get_close_date (
                                (SELECT close_method
                                   FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                  WHERE vs_line_identifier =
                                        acc_ext.vs_unique_identifier),
                                gp.period_name),
                            'MM/DD/YYYY')
                       close_date,
                   NVL (
                       (SELECT item_type
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier),
                       'General')
                       item_type,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                       NVL (
                           (SELECT sub_type
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           gjc.user_je_category_name))
                       item_sub_types,
                   NULL
                       item_summary,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                       (SELECT attribute50
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_impact_code,
                   NVL (
                       (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                       NVL (
                           (SELECT item_class
                              FROM xxd_gl_bl_acct_bal_vs_attrs_v
                             WHERE vs_line_identifier =
                                   acc_ext.vs_unique_identifier),
                           'L'))
                       item_class,
                   'G'
                       adjustment_destination,
                   'FALSE'
                       item_editable_by_preparers,
                   SUBSTR (
                       ('JL' || ' ' || gjh.doc_sequence_value || '-' || 'JL' || ' ' || je_line_num || '-' || 'JL' || ' ' || SUBSTR (gjb.name, 1, 65) || '-' || 'JL' || ' ' || gjl.description),
                       1,
                       2000)
                       description,
                   NULL
                       reference,
                   NULL
                       item_total,
                   NULL
                       reference_field1,
                   NULL
                       reference_field2,
                   NULL
                       reference_field3,
                   NULL
                       reference_field4,
                   NULL
                       reference_field5,
                   xxd_gl_journals_extract_pkg.get_sec_ledget_amt (
                       gp.period_name,
                       gcc.code_combination_id,
                       (gcc.segment1),
                       led.ledger_id,
                       gjh.je_header_id,
                       gjl.je_line_num,
                       (SELECT alt_currency
                          FROM xxd_gl_bl_acct_bal_vs_attrs_v
                         WHERE vs_line_identifier =
                               acc_ext.vs_unique_identifier))
                       item_amount_alt_curr,
                   DECODE (
                       led.currency_code,
                       'USD', (NVL (accounted_dr, 0) - NVL (accounted_cr, 0)),
                       xxd_gl_journals_extract_pkg.get_rep_ledger_amt (
                           gp.period_name,
                           gcc.code_combination_id,
                           led.ledger_id,
                           gjh.je_header_id,
                           gjl.je_line_num))
                       item_amount_reporting_currency,
                   NULL
                       item_amount_glaccount_currency,
                   NVL (accounted_dr, 0) - NVL (accounted_cr, 0)
                       item_amount_transact_currency,
                   led.currency_code
                       item_currency,
                   NULL
                       file_path,
                   'DETAIL'
                       report_type
              FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, XXDO.XXD_GL_JE_LINES_SUBLED_T gjl,
                   --xxdo.xxd_gl_je_lines_ext_t       gjl,
                   apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                   apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                   apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
             WHERE     1 = 1
                   AND ccid_table.ccid = gjl.code_combination_id
                   AND gjh.je_header_id = gjl.je_header_id
                   AND gjh.period_name = gjl.period_name
                   AND gcc.code_combination_id = gjl.code_combination_id
                   AND gp.ledger_id = gjh.ledger_id
                   AND gp.application_id = 101
                   AND led.ledger_id <> 2081
                   AND gp.period_name = gjh.period_name
                   AND gjh.je_batch_id = gjb.je_batch_id
                   AND gjl.ledger_id = led.ledger_id
                   AND acc_ext.ccid IS NOT NULL
                   AND gjh.je_source = gjs.je_source_name
                   AND gjc.je_category_name = gjh.je_category
                   AND acc_ext.ccid = gcc.code_combination_id
                   -- 1.1 changes start
                   --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxdo.xxd_gl_je_lines_ext_t a
                             WHERE     a.je_header_id = gjl.je_header_id
                                   AND a.code_combination_id =
                                       gjl.code_combination_id)
                   -- 1.1 changes end

                   AND acc_ext.extract_level = 2
                   AND acc_ext.vs_unique_identifier IS NOT NULL
                   AND gjh.status = 'P'
                   AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                   AND xgp.ledger_id = gp.ledger_id
                   AND gp.period_name = xgp.period_name
                   AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 1),
                                            gcc.segment1)
                   AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 1),
                                            gcc.segment1)
                   AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 2),
                                            gcc.segment2)
                   AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 2),
                                            gcc.segment2)
                   AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 3),
                                            gcc.segment3)
                   AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 3),
                                            gcc.segment3)
                   AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 4),
                                            gcc.segment4)
                   AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 4),
                                            gcc.segment4)
                   AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 5),
                                            gcc.segment5)
                   AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 5),
                                            gcc.segment5)
                   AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 6),
                                            gcc.segment6)
                   AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 6),
                                            gcc.segment6)
                   AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 7),
                                            gcc.segment7)
                   AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 7),
                                            gcc.segment7)
                   AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                           , 8),
                                            gcc.segment8)
                   AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                           , 8),
                                            gcc.segment8)
                   AND NVL (p_summerize_sub_ledger, 'DETAIL') = 'DETAIL'
                   AND NVL (gjc.attribute2, 'N') = 'N'
                   AND (gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date))
                   AND gjs.user_je_source_name =
                       NVL (p_source, gjs.user_je_source_name)
                   AND gjc.user_je_category_name =
                       NVL (p_category, gjc.user_je_category_name)
                   AND p_source_type = 'Subledger'
                   AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                   AND gjs.je_source_name <> 'Revaluation'
            -- The below union is for summary subledger
            UNION ALL
              SELECT gcc.code_combination_id
                         ccid,
                     NULL
                         je_header_id,
                     NULL
                         je_line_num,
                     gjl.period_name,
                     gjl.ledger_id,
                     led.name,
                     gcc.segment1
                         entity_unique_identifier,
                     gcc.segment6
                         account,
                     gcc.segment2
                         brand,
                     gcc.segment3
                         geo,
                     gcc.segment4
                         channel,
                     gcc.segment5
                         costcenter,
                     gcc.segment7
                         intercompany,
                     gcc.segment8
                         futureuse,
                     NULL
                         key9,
                     NULL
                         key10,
                     NULL
                         ccid_method,
                     (SELECT alt_currency
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         alt_currency,
                     (SELECT close_method
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         close_method,
                     (SELECT statuary_ledger
                        FROM xxd_gl_bl_acct_bal_vs_attrs_v
                       WHERE vs_line_identifier = acc_ext.vs_unique_identifier)
                         statuary_ledger,
                     REPLACE (
                         (gjs.user_je_source_name || gjc.user_je_category_name || gcc.code_combination_id || REPLACE (gp.period_name, '-', '') || TO_CHAR (SYSDATE, 'DDMONYYYYHHMISS')),
                         '-',
                         '')
                         unique_identifier,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         origination_date,
                     TO_CHAR (gp.end_date, 'MM/DD/YYYY')
                         open_date,
                     TO_CHAR (
                         get_close_date (
                             (SELECT close_method
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier),
                             gp.period_name),
                         'MM/DD/YYYY')
                         close_date,
                     NVL (
                         (SELECT item_type
                            FROM xxd_gl_bl_acct_bal_vs_attrs_v
                           WHERE vs_line_identifier =
                                 acc_ext.vs_unique_identifier),
                         'General')
                         item_type,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute8, '')),
                             NVL (
                                 (SELECT sub_type
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 gjc.user_je_category_name)))
                         item_sub_types,
                     NULL
                         item_summary,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute9, '')),
                             (SELECT attribute50
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_impact_code,
                     MIN (
                         NVL (
                             (DECODE (gjc.attribute2, 'Y', gjl.attribute10, '')),
                             NVL (
                                 (SELECT item_class
                                    FROM xxd_gl_bl_acct_bal_vs_attrs_v
                                   WHERE vs_line_identifier =
                                         acc_ext.vs_unique_identifier),
                                 'L')))
                         item_class,
                     'G'
                         adjustment_destination,
                     'FALSE'
                         item_editable_by_preparers,
                     SUBSTR (
                         (gjs.user_je_source_name || ' ' || gjc.user_je_category_name || ' ' || gcc.code_combination_id),
                         1,
                         2000)
                         description,
                     NULL
                         reference,
                     NULL
                         item_total,
                     NULL
                         reference_field1,
                     NULL
                         reference_field2,
                     NULL
                         reference_field3,
                     NULL
                         reference_field4,
                     NULL
                         reference_field5,
                     SUM (
                         get_sec_ledget_amt (
                             gp.period_name,
                             gcc.code_combination_id,
                             (gcc.segment1),
                             led.ledger_id,
                             gjh.je_header_id,
                             gjl.je_line_num,
                             (SELECT alt_currency
                                FROM xxd_gl_bl_acct_bal_vs_attrs_v
                               WHERE vs_line_identifier =
                                     acc_ext.vs_unique_identifier)))
                         item_amount_alt_curr,
                     DECODE (
                         led.currency_code,
                         'USD', SUM (
                                      NVL (accounted_dr, 0)
                                    - NVL (accounted_cr, 0)),
                         SUM (
                             get_rep_ledger_amt (gp.period_name,
                                                 gcc.code_combination_id,
                                                 led.ledger_id,
                                                 gjh.je_header_id,
                                                 gjl.je_line_num)))
                         item_amount_reporting_currency,
                     NULL
                         item_amount_glaccount_currency,
                     SUM (NVL (accounted_dr, 0) - NVL (accounted_cr, 0))
                         item_amount_transact_currency,
                     led.currency_code
                         item_currency,
                     NULL
                         file_path,
                     'SUMMARY'
                         report_type
                FROM xxdo.xxd_gl_ccid_je_t ccid_table, xxdo.XXD_GL_JE_HEADERS_EXT_T gjh, XXDO.XXD_GL_JE_LINES_SUBLED_T gjl,
                     --xxdo.xxd_gl_je_lines_ext_t       gjl,
                     apps.gl_code_combinations_kfv gcc, apps.gl_period_statuses gp, apps.gl_je_batches gjb,
                     apps.gl_je_sources gjs, apps.gl_je_categories gjc, xxdo.xxd_gl_acc_recon_extract_t acc_ext,
                     apps.gl_ledgers led, xxdo.xxd_gl_period_name_gt xgp
               WHERE     1 = 1
                     AND ccid_table.ccid = gjl.code_combination_id
                     AND gjh.je_header_id = gjl.je_header_id
                     AND gjh.period_name = gjl.period_name
                     AND gcc.code_combination_id = gjl.code_combination_id
                     AND gp.ledger_id = gjh.ledger_id
                     AND gp.application_id = 101
                     AND led.ledger_id <> 2081
                     AND gp.period_name = gjh.period_name
                     AND gjh.je_batch_id = gjb.je_batch_id
                     AND gjl.ledger_id = led.ledger_id
                     AND acc_ext.ccid IS NOT NULL
                     AND gjh.je_source = gjs.je_source_name
                     AND gjc.je_category_name = gjh.je_category
                     AND acc_ext.ccid = gcc.code_combination_id
                     -- 1.1 changes start
                     --AND NVL (gjl.global_attribute1, 'N') <> 'Y' -- sent to blackline flag
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxdo.xxd_gl_je_lines_ext_t a
                               WHERE     a.je_header_id = gjl.je_header_id
                                     AND a.code_combination_id =
                                         gjl.code_combination_id)
                     -- 1.1 changes end

                     AND acc_ext.extract_level = 2
                     AND acc_ext.vs_unique_identifier IS NOT NULL
                     AND gjh.status = 'P'
                     AND gjl.ledger_id = NVL (p_ledger_id, gjl.ledger_id)
                     AND xgp.ledger_id = gp.ledger_id
                     AND gp.period_name = xgp.period_name
                     AND gcc.segment1 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 1),
                                              gcc.segment1)
                     AND gcc.segment1 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 1),
                                              gcc.segment1)
                     AND gcc.segment2 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 2),
                                              gcc.segment2)
                     AND gcc.segment2 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 2),
                                              gcc.segment2)
                     AND gcc.segment3 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 3),
                                              gcc.segment3)
                     AND gcc.segment3 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 3),
                                              gcc.segment3)
                     AND gcc.segment4 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 4),
                                              gcc.segment4)
                     AND gcc.segment4 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 4),
                                              gcc.segment4)
                     AND gcc.segment5 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 5),
                                              gcc.segment5)
                     AND gcc.segment5 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 5),
                                              gcc.segment5)
                     AND gcc.segment6 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 6),
                                              gcc.segment6)
                     AND gcc.segment6 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 6),
                                              gcc.segment6)
                     AND gcc.segment7 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 7),
                                              gcc.segment7)
                     AND gcc.segment7 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 7),
                                              gcc.segment7)
                     AND gcc.segment8 >= NVL (REGEXP_SUBSTR (p_account_from, '[^.]+', 1
                                                             , 8),
                                              gcc.segment8)
                     AND gcc.segment8 <= NVL (REGEXP_SUBSTR (p_account_to, '[^.]+', 1
                                                             , 8),
                                              gcc.segment8)
                     AND NVL (p_summerize_sub_ledger, 'DETAIL') = 'SUMMARY'
                     AND NVL (gjc.attribute2, 'N') = 'N'
                     AND (gjl.last_update_date >= NVL (TO_DATE (p_jl_creation_date_from, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date) AND gjl.last_update_date <= NVL (TO_DATE (p_jl_creation_date_to, 'RRRR/MM/DD HH24:MI:SS'), gjl.last_update_date))
                     AND gjs.user_je_source_name =
                         NVL (p_source, gjs.user_je_source_name)
                     AND gjc.user_je_category_name =
                         NVL (p_category, gjc.user_je_category_name)
                     AND p_source_type = 'Subledger'
                     AND ((p_ledger_type = 'Primary' AND ledger_category_code = 'PRIMARY' AND ccid_table.fy_eligible = 'TRUE') OR (p_ledger_type = 'Secondary' AND ccid_table.statuary_ledger = 'Y' AND ledger_category_code = 'SECONDARY' AND (ccid_table.sec_fy_eligible = 'TRUE' OR ccid_table.sec_cy_eligible = 'TRUE')))
                     AND gjs.je_source_name <> 'Revaluation'
            GROUP BY gcc.code_combination_id, gcc.segment1, gcc.segment2,
                     gcc.segment3, gcc.segment4, gcc.segment5,
                     gcc.segment6, gcc.segment7, gcc.segment8,
                     gp.end_date, led.currency_code, gjs.user_je_source_name,
                     gjc.user_je_category_name, gp.period_name, acc_ext.vs_unique_identifier,
                     gjl.ledger_id, led.name, gjl.period_name,
                     gjc.user_je_category_name, gjc.attribute2;


        v_cur_recs_counter           NUMBER := 0; -- To count total number of records in the cursor
        v_sql_rowcount               NUMBER := 0; -- To count total number of actual rows updated

        p_out_activty_in_prd         VARCHAR2 (240);
        p_out_begin_balance          NUMBER;
        p_out_closing_balance        NUMBER;
        p_alt_currency               VARCHAR2 (240);
        p_out_primary_currency       VARCHAR2 (240);
        p_out_pri_gl_rpt_bal         NUMBER;
        p_out_pri_gl_alt_bal         NUMBER;
        p_out_pri_gl_acct_bal        NUMBER;
        p_out_sec_gl_rpt_bal         NUMBER;
        p_out_sec_gl_alt_bal         NUMBER;
        p_out_sec_gl_acct_bal        NUMBER;
        p_out_active_acct            VARCHAR2 (240);
        p_out_alt_currency           VARCHAR2 (100);
        l_file_name                  VARCHAR2 (240);
        lv_ret_code                  VARCHAR2 (30) := NULL;
        lv_ret_message               VARCHAR2 (2000) := NULL;
        lv_outbound_cur_file         VARCHAR2 (360)
            := 'Items_' || TO_CHAR (SYSDATE, 'YYYYMMDDHH24MISS');
        lb_file_exists               BOOLEAN;
        ln_file_length               NUMBER := NULL;
        ln_block_size                NUMBER := NULL;
        lv_current_period            VARCHAR2 (10);
        lv_previous_period           VARCHAR2 (10);
        l_item_impact_code           VARCHAR2 (50);
        l_last_run_date              VARCHAR2 (20);
        p_out_activty_in_perd        VARCHAR2 (240);
        p_out_active_account         VARCHAR2 (240);
        p_out_pri_gl_account_bal     NUMBER;
        p_out_pri_currency           VARCHAR2 (100);
        l_reporting_amount           NUMBER;
        p_out_activty_in_prd1        VARCHAR2 (240);
        lv_eligible_journal          VARCHAR2 (10);
        l_last_run_date_reval        VARCHAR2 (20);
        l_last_run_date_subled       VARCHAR2 (20);
        lv_eligible                  VARCHAR2 (10);
        l_last_run_date_sec          VARCHAR2 (20);
        l_last_run_date_reval_sec    VARCHAR2 (20);
        l_last_run_date_subled_sec   VARCHAR2 (20);

        --Create a table type on the cursor
        TYPE tb_rec IS TABLE OF eligible_journals_det%ROWTYPE;

        --Define a variable of that table type
        v_tb_rec                     tb_rec;
        v_cur_recs_counter           NUMBER := 0; -- To count total number of records in the cursor
        v_sql_rowcount               NUMBER := 0; -- To count total number of actual rows updated
        v_bulk_limit                 NUMBER := 500;
        ld_request_startdate         DATE;                               --1.1
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Insert_prc');

        --EXECUTE IMMEDIATE ('ALTER SESSION SET optimizer_features_enable='||'11.2.0.4');
        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_PERIOD_NAME_GT');

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_CCID_IDENTIFY_T');

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_CCID_JE_T');

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_JE_HEADERS_EXT_T');

        -- This table is not truncating reason: we are using to store success records
        -- to fix the global_attribute1 issue we are loading the data in custom table
        -- in oracle while reversing the journals global_attribute1 is automatically copied
        --EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_JE_LINES_EXT_T'); -- 1.1

        EXECUTE IMMEDIATE ('TRUNCATE TABLE XXDO.XXD_GL_JE_LINES_SUBLED_T');



        BEGIN
            -- inserting the data into global temporary table
            INSERT INTO xxdo.xxd_gl_period_name_gt
                (SELECT gll.ledger_id,
                        get_period_name (gll.period_set_name, p_period, p_current_period
                                         , p_previous_period)
                            period_name,
                        (SELECT end_date
                           FROM gl_periods gp
                          WHERE     gp.period_set_name = gll.period_set_name
                                AND period_name =
                                    get_period_name (gll.period_set_name, p_period, p_current_period
                                                     , p_previous_period))
                            end_date,
                        gll.ledger_category_code
                   FROM apps.gl_ledgers gll
                  WHERE gll.ledger_category_code IN ('PRIMARY', 'ALC')
                 UNION ALL
                 SELECT gll.ledger_id,
                        get_period_name (gll.period_set_name, p_period, p_current_period
                                         , p_previous_period)
                            period_name,
                        (SELECT end_date
                           FROM gl_periods gp
                          WHERE     gp.period_set_name = gll.period_set_name
                                AND period_name =
                                    get_period_name (gll.period_set_name, p_period, p_current_period
                                                     , p_previous_period))
                            end_date,
                        gll.ledger_category_code
                   FROM apps.gl_ledgers gll
                  WHERE     gll.ledger_category_code = 'SECONDARY'
                        AND gll.ledger_id IN
                                (SELECT b.attribute8
                                   FROM fnd_flex_value_sets a, fnd_flex_values b
                                  WHERE     a.flex_value_set_name =
                                            'DO_GL_COMPANY'
                                        AND a.flex_value_set_id =
                                            b.flex_value_set_id
                                        AND b.attribute8 IS NOT NULL
                                        AND b.summary_flag = 'N'
                                        AND b.enabled_flag = 'Y'));

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Data inserted into period name table count = '
                || SQL%ROWCOUNT);

            -- Insert into CCID Idenify Table
            INSERT INTO xxdo.xxd_gl_ccid_identify_t
                SELECT b.ccid,
                       a.sumarize_subledger,
                       a.summarize_manual,
                       a.attribute42 summerize_reve,
                       a.attribute43 open_balance_type,
                       a.attribute46 sec_sum_subledger,
                       a.attribute47 sec_sum_manual,
                       a.attribute48 sec_summ_reve,
                       a.attribute49 sec_open_bal_typ,
                       a.attribute44 file_path,
                       a.statuary_ledger,
                       xxd_gl_journals_extract_pkg.get_elegible_journal (
                           b.ccid,
                           (SELECT period_name
                              FROM xxdo.xxd_gl_period_name_gt xgp
                             WHERE ledger_id = 2036),
                           'Primary') fy_eligible,
                       xxd_gl_journals_extract_pkg.get_elegible_journal (
                           b.ccid,
                           (SELECT period_name
                              FROM xxdo.xxd_gl_period_name_gt xgp
                             WHERE ledger_id = 2047),
                           'Secondary') sec_cy_eligible,
                       xxd_gl_journals_extract_pkg.get_elegible_journal (
                           b.ccid,
                           (SELECT period_name
                              FROM xxdo.xxd_gl_period_name_gt xgp
                             WHERE ledger_id = 2036),
                           'Secondary') sec_fy_eligible,
                       SYSDATE,
                       a.attribute31_2 file_path_emea,
                       a.attribute33_2 file_path_apac,
                       a.attribute35_2 file_path_na
                  FROM xxd_gl_bl_acct_bal_vs_attrs_v a, xxdo.xxd_gl_acc_recon_extract_t b
                 WHERE     a.vs_line_identifier = b.vs_unique_identifier
                       AND b.extract_level = 2
                       AND b.vs_unique_identifier IS NOT NULL
                       AND b.ccid IS NOT NULL;

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                'Data inserted into CCID table count = ' || SQL%ROWCOUNT);

            -- Insert into CCID Idenify Table with only Eligible JE
            INSERT INTO xxdo.xxd_gl_ccid_je_t
                SELECT *
                  FROM xxdo.xxd_gl_ccid_identify_t
                 WHERE     1 = 1
                       AND (fy_eligible = 'TRUE' OR sec_fy_eligible = 'TRUE' OR sec_cy_eligible = 'TRUE');

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Data inserted into CCID Eligible JE table count = '
                || SQL%ROWCOUNT);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Insertion failed for GTT' || SQLERRM);
        END;

        --1.1 changes start
        -- query to get the request start date from request table
        BEGIN
            SELECT (fcr.actual_start_date)
              INTO ld_request_startdate
              FROM apps.fnd_concurrent_requests fcr
             WHERE request_id = gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ld_request_startdate   := NULL;
        END;

        --1.1 changes end

        -- Insert into gl_je_headers data into custom table
        IF p_source_type = 'Manual'
        THEN
            BEGIN
                INSERT INTO xxdo.xxd_gl_je_headers_ext_t
                    SELECT gjh.*
                      FROM apps.gl_je_headers gjh, apps.gl_je_categories gjc, xxdo.xxd_gl_period_name_gt xgp
                     WHERE     gjh.ledger_id = xgp.ledger_id
                           AND gjh.period_name = xgp.period_name
                           AND gjh.status = 'P'
                           AND gjc.attribute2 = 'Y'
                           AND gjh.je_category = gjc.JE_CATEGORY_NAME
                           AND ledger_type = UPPER (p_ledger_type)
                           AND p_source_type = 'Manual'
                           AND gjh.posted_date <=
                               NVL (ld_request_startdate, SYSDATE);      --1.1

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.put_line (
                        fnd_file.LOG,
                           'Insertion failed for xxd_gl_je_headers_ext_t'
                        || SQLERRM);
            END;
        ELSIF p_source_type = 'Revaluation'
        THEN
            BEGIN
                INSERT INTO xxdo.xxd_gl_je_headers_ext_t
                    SELECT gjh.*
                      FROM apps.gl_je_headers gjh, apps.gl_je_categories gjc, xxdo.xxd_gl_period_name_gt xgp
                     WHERE     gjh.ledger_id = xgp.ledger_id
                           AND gjh.period_name = xgp.period_name
                           AND gjh.status = 'P'
                           AND gjc.attribute2 IS NULL
                           AND gjh.je_category = gjc.JE_CATEGORY_NAME
                           AND ledger_type = UPPER (p_ledger_type)
                           AND p_source_type = 'Revaluation'
                           AND gjc.je_category_name = 'Revaluation'
                           AND gjh.posted_date <=
                               NVL (ld_request_startdate, SYSDATE);      --1.1

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.put_line (
                        fnd_file.LOG,
                           'Insertion failed for xxd_gl_je_headers_ext_t'
                        || SQLERRM);
            END;
        ELSIF p_source_type = 'Subledger'
        THEN
            BEGIN
                INSERT INTO xxdo.xxd_gl_je_headers_ext_t
                    SELECT /*+parallel(8)*/
                           gjh.*
                      FROM apps.gl_je_headers gjh, apps.gl_je_categories gjc, xxdo.xxd_gl_period_name_gt xgp
                     WHERE     gjh.ledger_id = xgp.ledger_id
                           AND gjh.period_name = xgp.period_name
                           AND gjh.status = 'P'
                           AND gjc.attribute2 IS NULL
                           AND gjh.je_category = gjc.JE_CATEGORY_NAME
                           AND ledger_type = UPPER (p_ledger_type)
                           AND p_source_type = 'Subledger'
                           AND gjh.posted_date <=
                               NVL (ld_request_startdate, SYSDATE)       --1.1
                           AND gjh.je_source <> 'Revaluation';          -- 1.2

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.put_line (
                        fnd_file.LOG,
                           'Insertion failed for xxd_gl_je_headers_ext_t'
                        || SQLERRM);
            END;
        END IF;

        -- insert into gl_je_lines data into custom table
        --Commented as part of 1.1 changes
        /*BEGIN
            INSERT INTO xxdo.xxd_gl_je_lines_ext_t
                SELECT je_header_id,
                       je_line_num,
                       ledger_id,
                       code_combination_id,
                       period_name,
                       global_attribute1
                  FROM apps.gl_je_lines  a,
                       (SELECT DISTINCT ccid
                          FROM xxdo.xxd_gl_journals_extract_t b
                         WHERE request_id = gn_request_id) b
                 WHERE     1 = 1
                       AND EXISTS
                               (SELECT 1
                                  FROM xxdo.xxd_gl_je_headers_ext_t
                                 WHERE je_header_id = a.je_header_id)
                       AND code_combination_id = b.ccid
                       AND global_attribute1 IS NULL;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.put_line (
                    fnd_file.LOG,
                    'Insertion failed for xxd_gl_je_lines_ext_t' || SQLERRM);
        END;*/

        -- file name logic

        IF p_file_path IS NOT NULL
        THEN
            l_file_name   := lv_outbound_cur_file || '.txt';
        END IF;

        IF P_LEdgER_type = 'Primary'
        THEN
            IF p_source_type = 'Manual'
            --
            THEN
                BEGIN
                    SELECT (ffvl.attribute1)
                      INTO l_last_run_date
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_JL_EXTRACT_LASTRUN_V'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Last run date is:' || l_last_run_date);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_last_run_date   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to fetch last run date from the value set :');
                END;
            ELSIF p_source_type = 'Revaluation'
            THEN
                BEGIN
                    SELECT (ffvl.attribute2)
                      INTO l_last_run_date_reval
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_JL_EXTRACT_LASTRUN_V'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Last run date is:' || l_last_run_date_reval);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_last_run_date_reval   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to fetch last run date from the value set :');
                END;
            ELSIF p_source_type = 'Subledger'
            THEN
                BEGIN
                    SELECT (ffvl.attribute3)
                      INTO l_last_run_date_subled
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_JL_EXTRACT_LASTRUN_V'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Last run date is:' || l_last_run_date_subled);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_last_run_date_subled   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to fetch last run date from the value set :');
                END;
            END IF;
        ELSIF p_ledger_type = 'Secondary'
        THEN
            IF p_source_type = 'Manual'
            THEN
                BEGIN
                    SELECT (ffvl.attribute4)
                      INTO l_last_run_date_sec
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_JL_EXTRACT_LASTRUN_V'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Last run date is:' || l_last_run_date_sec);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_last_run_date_sec   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to fetch last run date from the value set :');
                END;
            ELSIF p_source_type = 'Revaluation'
            THEN
                BEGIN
                    SELECT (ffvl.attribute5)
                      INTO l_last_run_date_reval_sec
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_JL_EXTRACT_LASTRUN_V'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Last run date is:' || l_last_run_date_reval_sec);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_last_run_date_reval_sec   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to fetch last run date from the value set :');
                END;
            ELSIF p_source_type = 'Subledger'
            THEN
                BEGIN
                    SELECT (ffvl.attribute6)
                      INTO l_last_run_date_subled_sec
                      FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                     WHERE     fvs.flex_value_set_id = ffvl.flex_value_set_id
                           AND fvs.flex_value_set_name =
                               'XXD_GL_JL_EXTRACT_LASTRUN_V'
                           AND NVL (TRUNC (ffvl.start_date_active),
                                    TRUNC (SYSDATE)) <=
                               TRUNC (SYSDATE)
                           AND NVL (TRUNC (ffvl.end_date_active),
                                    TRUNC (SYSDATE)) >=
                               TRUNC (SYSDATE)
                           AND ffvl.enabled_flag = 'Y';

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Last run date is:' || l_last_run_date_subled_sec);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_last_run_date_subled_sec   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to fetch last run date from the value set :');
                END;
            END IF;
        END IF;

        IF p_source_type = 'Subledger'
        THEN
            BEGIN
                INSERT INTO XXDO.XXD_GL_JE_LINES_SUBLED_T
                    SELECT /*+parallel(8)*/
                           gjl.je_header_id, gjl.je_line_num, gjl.period_name,
                           gjl.ledger_id, gjl.attribute8, gjl.attribute9,
                           gjl.attribute10, gjl.description, gjl.code_combination_id,
                           gjl.status, gjl.global_attribute1, gjl.accounted_dr,
                           gjl.accounted_cr, gjl.entered_dr, gjl.entered_cr,
                           gjl.last_update_date, gjl.creation_date, gjl.effective_date
                      FROM apps.gl_je_lines gjl,
                           (SELECT *
                              FROM xxdo.xxd_gl_ccid_je_t
                             WHERE 1 = 1 AND SUMARIZE_SUBLEDGER <> 'NA')
                           ccidneed,
                           XXDO.xxd_gl_period_name_gt xgp
                     WHERE     1 = 1
                           AND gjl.period_name = xgp.period_name
                           AND gjl.global_attribute1 IS NULL
                           AND gjl.code_combination_id = ccidneed.ccid
                           --and gjl.status = 'P'
                           AND gjl.ledger_id = xgp.ledger_id
                           AND xgp.ledger_type = UPPER (p_ledger_type);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    FND_FILE.put_line (
                        fnd_file.LOG,
                           'Insertion failed for XXD_GL_JE_LINES_SUBLED_T'
                        || SQLERRM);
            END;
        END IF;


        IF NVL (p_override_definition, 'N') = 'N'
        THEN
            IF NVL (p_open_balances_only, 'N') = 'Y'
            THEN
                -- for open balances
                FOR i IN open_balances_only
                LOOP
                    get_eligible_ccid (i.ccid, i.period_name, p_ledger_type,
                                       p_out_activty_in_prd1, p_out_active_acct, p_out_pri_gl_acct_bal
                                       , p_out_primary_currency);

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_out_activty_in_prd' || p_out_activty_in_prd);

                    IF NVL (p_out_activty_in_prd1, 'FALSE') = 'TRUE' -- p_out_activty_in_prd
                    THEN
                        -- get the account balances
                        get_ccid_values (i.ccid,
                                         i.entity_unique_identifier,
                                         i.alt_currency,
                                         i.period_name,
                                         i.ccid_method,
                                         p_out_activty_in_prd,
                                         p_out_active_acct,
                                         p_out_pri_gl_rpt_bal,
                                         p_out_pri_gl_alt_bal,
                                         p_out_pri_gl_acct_bal,
                                         p_out_sec_gl_rpt_bal,
                                         p_out_sec_gl_alt_bal,
                                         p_out_sec_gl_acct_bal,
                                         p_out_alt_currency,
                                         p_out_primary_currency);

                        IF i.item_currency = 'USD'
                        THEN
                            l_reporting_amount   := p_out_pri_gl_acct_bal;
                        ELSE
                            l_reporting_amount   := p_out_pri_gl_rpt_bal;
                        END IF;
                    END IF;

                    IF p_ledger_type = 'Primary'
                    THEN
                        IF (p_out_activty_in_prd1 = 'TRUE')
                        THEN
                            BEGIN
                                INSERT INTO xxdo.xxd_gl_journals_extract_t
                                         VALUES (
                                                    i.ccid,
                                                    i.entity_unique_identifier,
                                                    i.account,
                                                    i.brand,
                                                    i.geo,
                                                    i.channel,
                                                    i.costcenter,
                                                    i.intercompany,
                                                    NULL,
                                                    i.key9,
                                                    i.key10,
                                                    NULL,
                                                    i.unique_identifier,
                                                    i.origination_date,
                                                    i.open_date,
                                                    i.close_date,
                                                    i.item_type,
                                                    i.item_sub_types,
                                                    i.item_summary,
                                                    CASE
                                                        WHEN i.item_class =
                                                             'R'
                                                        THEN
                                                            i.item_impact_code
                                                        ELSE
                                                            NULL
                                                    END,
                                                    i.item_class,
                                                    i.adjustment_destination,
                                                    CASE
                                                        WHEN i.close_date
                                                                 IS NULL
                                                        THEN
                                                            'TRUE'
                                                        ELSE
                                                            i.item_editable_by_preparers
                                                    END,
                                                    i.description,
                                                    i.reference,
                                                    i.item_total,
                                                    i.reference_field1,
                                                    i.reference_field2,
                                                    i.reference_field3,
                                                    i.reference_field4,
                                                    i.reference_field5,
                                                    p_out_pri_gl_alt_bal,
                                                    l_reporting_amount,
                                                    i.item_amount_glaccount_currency,
                                                    NVL (
                                                        p_out_pri_gl_acct_bal,
                                                        0),
                                                    i.item_currency,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    i.period_name,
                                                    i.ledger_id,
                                                    i.alt_currency,
                                                    i.close_method,
                                                    NULL,
                                                    NULL,
                                                    i.report_type);

                                COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Inserted the values in Custom Table for CCID:'
                                    || i.ccid);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'insertion failed for xxd_gl_journals_extract_t Table'
                                        || SQLERRM);
                            END;
                        END IF;
                    ELSIF p_ledger_type = 'Secondary'
                    THEN
                        IF i.statuary_ledger = 'Y'
                        THEN
                            IF (NVL (p_open_balances_only, 'N') = 'Y')
                            THEN
                                BEGIN
                                    INSERT INTO xxdo.xxd_gl_journals_extract_t
                                             VALUES (
                                                        i.ccid,
                                                        i.entity_unique_identifier,
                                                        i.account,
                                                        i.brand,
                                                        i.geo,
                                                        i.channel,
                                                        i.costcenter,
                                                        i.intercompany,
                                                        CASE
                                                            WHEN NVL (
                                                                     i.statuary_ledger,
                                                                     'N') =
                                                                 'Y'
                                                            THEN
                                                                i.name
                                                            ELSE
                                                                NULL
                                                        END,
                                                        i.key9,
                                                        i.key10,
                                                        i.statuary_ledger,
                                                        i.unique_identifier,
                                                        i.origination_date,
                                                        i.open_date,
                                                        i.close_date,
                                                        i.item_type,
                                                        i.item_sub_types,
                                                        i.item_summary,
                                                        CASE
                                                            WHEN i.item_class =
                                                                 'R'
                                                            THEN
                                                                i.item_impact_code
                                                            ELSE
                                                                NULL
                                                        END,
                                                        i.item_class,
                                                        i.adjustment_destination,
                                                        CASE
                                                            WHEN i.close_date
                                                                     IS NULL
                                                            THEN
                                                                'TRUE'
                                                            ELSE
                                                                i.item_editable_by_preparers
                                                        END,
                                                        i.description,
                                                        i.reference,
                                                        i.item_total,
                                                        i.reference_field1,
                                                        i.reference_field2,
                                                        i.reference_field3,
                                                        i.reference_field4,
                                                        i.reference_field5,
                                                        NULL,
                                                        l_reporting_amount,
                                                        i.item_amount_glaccount_currency,
                                                        NVL (
                                                            p_out_sec_gl_acct_bal,
                                                            0),
                                                        i.item_currency,
                                                        gn_request_id,
                                                        SYSDATE,
                                                        gn_user_id,
                                                        SYSDATE,
                                                        gn_user_id,
                                                        i.period_name,
                                                        i.ledger_id,
                                                        i.alt_currency,
                                                        i.close_method,
                                                        NULL,
                                                        NULL,
                                                        i.report_type);

                                    COMMIT;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Inserted the values in Custom Table');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'insertion failed for xxd_gl_journals_extract_t Table'
                                            || SQLERRM);
                                END;
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
            ELSIF NVL (p_file_path_only, 'N') = 'Y'
            THEN
                FOR i IN filepath_only_cur
                LOOP
                    lv_eligible   :=
                        get_elegible_journal (i.ccid,
                                              i.period_name,
                                              p_ledger_type);

                    --    fnd_file.put_line(fnd_file.log,'ccid:'||i.ccid);
                    --fnd_file.put_line(fnd_file.log,'costcenter:'||i.costcenter);



                    IF p_ledger_type = 'Primary'
                    THEN
                        IF (p_file_Path_only = 'Y' AND lv_eligible = 'TRUE' AND i.description IS NOT NULL) --1.1 change
                        THEN
                            BEGIN
                                INSERT INTO xxdo.xxd_gl_journals_extract_t
                                         VALUES (
                                                    i.ccid,
                                                    i.entity_unique_identifier,
                                                    i.account,
                                                    i.brand,
                                                    i.geo,
                                                    i.channel,
                                                    i.costcenter,
                                                    i.intercompany,
                                                    NULL,
                                                    i.key9,
                                                    i.key10,
                                                    NULL,
                                                    i.unique_identifier,
                                                    i.origination_date,
                                                    i.open_date,
                                                    i.close_date,
                                                    i.item_type,
                                                    i.item_sub_types,
                                                    i.item_summary,
                                                    CASE
                                                        WHEN i.item_class =
                                                             'R'
                                                        THEN
                                                            i.item_impact_code
                                                        ELSE
                                                            NULL
                                                    END,
                                                    i.item_class,
                                                    i.adjustment_destination,
                                                    CASE
                                                        WHEN i.close_date
                                                                 IS NULL
                                                        THEN
                                                            'TRUE'
                                                        ELSE
                                                            i.item_editable_by_preparers
                                                    END,
                                                    i.description,
                                                    i.reference,
                                                    i.item_total,
                                                    i.reference_field1,
                                                    i.reference_field2,
                                                    i.reference_field3,
                                                    i.reference_field4,
                                                    i.reference_field5,
                                                    NULL,
                                                    NULL,
                                                    i.item_amount_glaccount_currency,
                                                    0,
                                                    i.item_currency,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    i.period_name,
                                                    i.ledger_id,
                                                    i.alt_currency,
                                                    i.close_method,
                                                    NULL,
                                                    NULL,
                                                    i.report_type);

                                COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Inserted the values in Custom Table');
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                                        || SQLERRM);
                            END;
                        END IF;
                    ELSIF p_ledger_type = 'Secondary'
                    THEN
                        IF i.statuary_ledger = 'Y'
                        THEN
                            IF (p_file_Path_only = 'Y' AND lv_eligible = 'TRUE')
                            THEN
                                BEGIN
                                    INSERT INTO xxdo.xxd_gl_journals_extract_t
                                             VALUES (
                                                        i.ccid,
                                                        i.entity_unique_identifier,
                                                        i.account,
                                                        i.brand,
                                                        i.geo,
                                                        i.channel,
                                                        i.costcenter,
                                                        i.intercompany,
                                                        CASE
                                                            WHEN NVL (
                                                                     i.statuary_ledger,
                                                                     'N') =
                                                                 'Y'
                                                            THEN
                                                                i.name
                                                            ELSE
                                                                NULL
                                                        END,
                                                        i.key9,
                                                        i.key10,
                                                        i.statuary_ledger,
                                                        i.unique_identifier,
                                                        i.origination_date,
                                                        i.open_date,
                                                        i.close_date,
                                                        i.item_type,
                                                        i.item_sub_types,
                                                        i.item_summary,
                                                        CASE
                                                            WHEN i.item_class =
                                                                 'R'
                                                            THEN
                                                                i.item_impact_code
                                                            ELSE
                                                                NULL
                                                        END,
                                                        i.item_class,
                                                        i.adjustment_destination,
                                                        CASE
                                                            WHEN i.close_date
                                                                     IS NULL
                                                            THEN
                                                                'TRUE'
                                                            ELSE
                                                                i.item_editable_by_preparers
                                                        END,
                                                        i.description,
                                                        i.reference,
                                                        i.item_total,
                                                        i.reference_field1,
                                                        i.reference_field2,
                                                        i.reference_field3,
                                                        i.reference_field4,
                                                        i.reference_field5,
                                                        NULL,
                                                        NULL,
                                                        i.item_amount_glaccount_currency,
                                                        0,
                                                        i.item_currency,
                                                        gn_request_id,
                                                        SYSDATE,
                                                        gn_user_id,
                                                        SYSDATE,
                                                        gn_user_id,
                                                        i.period_name,
                                                        i.ledger_id,
                                                        i.alt_currency,
                                                        i.close_method,
                                                        NULL,
                                                        NULL,
                                                        i.report_type);

                                    COMMIT;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Inserted the values in Custom Table');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                                            || SQLERRM);
                                END;
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
            ELSE                                               -- for journals
                --
                IF p_ledger_type = 'Primary'
                THEN
                    OPEN eligible_journals_det (l_last_run_date,
                                                L_LAST_RUN_DATE_REVAL,
                                                l_last_run_date_subled);

                    LOOP
                        FETCH eligible_journals_det
                            BULK COLLECT INTO v_tb_rec
                            LIMIT v_bulk_limit;



                        BEGIN
                            FORALL i IN 1 .. v_tb_rec.COUNT
                                INSERT INTO xxdo.xxd_gl_journals_extract_t
                                         VALUES (
                                                    v_tb_rec (i).ccid,
                                                    v_tb_rec (i).entity_unique_identifier,
                                                    v_tb_rec (i).account,
                                                    v_tb_rec (i).brand,
                                                    v_tb_rec (i).geo,
                                                    v_tb_rec (i).channel,
                                                    v_tb_rec (i).costcenter,
                                                    v_tb_rec (i).intercompany,
                                                    NULL,
                                                    v_tb_rec (i).key9,
                                                    v_tb_rec (i).key10,
                                                    NULL,
                                                    v_tb_rec (i).unique_identifier,
                                                    v_tb_rec (i).origination_date,
                                                    v_tb_rec (i).open_date,
                                                    v_tb_rec (i).close_date,
                                                    v_tb_rec (i).item_type,
                                                    v_tb_rec (i).item_sub_types,
                                                    v_tb_rec (i).item_summary,
                                                    CASE
                                                        WHEN v_tb_rec (i).item_class =
                                                             'R'
                                                        THEN
                                                            v_tb_rec (i).item_impact_code
                                                        ELSE
                                                            NULL
                                                    END,
                                                    v_tb_rec (i).item_class,
                                                    v_tb_rec (i).adjustment_destination,
                                                    CASE
                                                        WHEN v_tb_rec (i).close_date
                                                                 IS NULL
                                                        THEN
                                                            'TRUE'
                                                        ELSE
                                                            v_tb_rec (i).item_editable_by_preparers
                                                    END,
                                                    v_tb_rec (i).description,
                                                    v_tb_rec (i).reference,
                                                    v_tb_rec (i).item_total,
                                                    v_tb_rec (i).reference_field1,
                                                    v_tb_rec (i).reference_field2,
                                                    v_tb_rec (i).reference_field3,
                                                    v_tb_rec (i).reference_field4,
                                                    v_tb_rec (i).reference_field5,
                                                    v_tb_rec (i).item_amount_alt_curr,
                                                    v_tb_rec (i).item_amount_reporting_currency,
                                                    v_tb_rec (i).item_amount_glaccount_currency,
                                                    v_tb_rec (i).item_amount_transact_currency,
                                                    v_tb_rec (i).item_currency,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    v_tb_rec (i).period_name,
                                                    v_tb_rec (i).ledger_id,
                                                    v_tb_rec (i).alt_currency,
                                                    v_tb_rec (i).close_method,
                                                    NULL,
                                                    NULL,
                                                    v_tb_rec (i).report_type);

                            COMMIT;
                            EXIT WHEN eligible_journals_det%NOTFOUND;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Inserted the values in Custom Table');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                                    || SQLERRM);
                        END;
                    END LOOP;

                    CLOSE eligible_journals_det;
                ELSIF p_ledger_type = 'Secondary'
                THEN
                    OPEN eligible_journals_det_sec (
                        l_last_run_date_sec,
                        L_LAST_RUN_DATE_REVAL_sec,
                        l_last_run_date_subled_sec);


                    LOOP
                        FETCH eligible_journals_det_sec
                            BULK COLLECT INTO v_tb_rec
                            LIMIT v_bulk_limit;


                        BEGIN
                            FORALL i IN 1 .. v_tb_rec.COUNT
                                INSERT INTO xxdo.xxd_gl_journals_extract_t
                                         VALUES (
                                                    v_tb_rec (i).ccid,
                                                    v_tb_rec (i).entity_unique_identifier,
                                                    v_tb_rec (i).account,
                                                    v_tb_rec (i).brand,
                                                    v_tb_rec (i).geo,
                                                    v_tb_rec (i).channel,
                                                    v_tb_rec (i).costcenter,
                                                    v_tb_rec (i).intercompany,
                                                    CASE
                                                        WHEN NVL (
                                                                 v_tb_rec (i).statuary_ledger,
                                                                 'N') =
                                                             'Y'
                                                        THEN
                                                            v_tb_rec (i).name
                                                        ELSE
                                                            NULL
                                                    END,
                                                    v_tb_rec (i).key9,
                                                    v_tb_rec (i).key10,
                                                    v_tb_rec (i).statuary_ledger,
                                                    v_tb_rec (i).unique_identifier,
                                                    v_tb_rec (i).origination_date,
                                                    v_tb_rec (i).open_date,
                                                    v_tb_rec (i).close_date,
                                                    v_tb_rec (i).item_type,
                                                    v_tb_rec (i).item_sub_types,
                                                    v_tb_rec (i).item_summary,
                                                    CASE
                                                        WHEN v_tb_rec (i).item_class =
                                                             'R'
                                                        THEN
                                                            v_tb_rec (i).item_impact_code
                                                        ELSE
                                                            NULL
                                                    END,
                                                    v_tb_rec (i).item_class,
                                                    v_tb_rec (i).adjustment_destination,
                                                    CASE
                                                        WHEN v_tb_rec (i).close_date
                                                                 IS NULL
                                                        THEN
                                                            'TRUE'
                                                        ELSE
                                                            v_tb_rec (i).item_editable_by_preparers
                                                    END,
                                                    v_tb_rec (i).description,
                                                    v_tb_rec (i).reference,
                                                    v_tb_rec (i).item_total,
                                                    v_tb_rec (i).reference_field1,
                                                    v_tb_rec (i).reference_field2,
                                                    v_tb_rec (i).reference_field3,
                                                    v_tb_rec (i).reference_field4,
                                                    v_tb_rec (i).reference_field5,
                                                    NULL,
                                                    v_tb_rec (i).item_amount_reporting_currency,
                                                    v_tb_rec (i).item_amount_glaccount_currency,
                                                    v_tb_rec (i).item_amount_transact_currency,
                                                    v_tb_rec (i).item_currency,
                                                    gn_request_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    SYSDATE,
                                                    gn_user_id,
                                                    v_tb_rec (i).period_name,
                                                    v_tb_rec (i).ledger_id,
                                                    v_tb_rec (i).alt_currency,
                                                    v_tb_rec (i).close_method,
                                                    NULL,
                                                    NULL,
                                                    v_tb_rec (i).report_type);

                            COMMIT;
                            EXIT WHEN eligible_journals_det_sec%NOTFOUND;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Inserted the values in Custom Table');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                                    || SQLERRM);
                        END;
                    -- END IF;
                    END LOOP;

                    CLOSE eligible_journals_det_sec;
                END IF;
            END IF;
        ELSE                                            -- ovveride definition
            --
            IF p_ledger_type = 'Primary'
            THEN
                OPEN eligible_journals_det_override;

                LOOP
                    FETCH eligible_journals_det_override
                        BULK COLLECT INTO v_tb_rec
                        LIMIT v_bulk_limit;



                    BEGIN
                        FORALL i IN 1 .. v_tb_rec.COUNT
                            INSERT INTO xxdo.xxd_gl_journals_extract_t
                                     VALUES (
                                                v_tb_rec (i).ccid,
                                                v_tb_rec (i).entity_unique_identifier,
                                                v_tb_rec (i).account,
                                                v_tb_rec (i).brand,
                                                v_tb_rec (i).geo,
                                                v_tb_rec (i).channel,
                                                v_tb_rec (i).costcenter,
                                                v_tb_rec (i).intercompany,
                                                NULL,
                                                v_tb_rec (i).key9,
                                                v_tb_rec (i).key10,
                                                NULL,
                                                v_tb_rec (i).unique_identifier,
                                                v_tb_rec (i).origination_date,
                                                v_tb_rec (i).open_date,
                                                v_tb_rec (i).close_date,
                                                v_tb_rec (i).item_type,
                                                v_tb_rec (i).item_sub_types,
                                                v_tb_rec (i).item_summary,
                                                CASE
                                                    WHEN v_tb_rec (i).item_class =
                                                         'R'
                                                    THEN
                                                        v_tb_rec (i).item_impact_code
                                                    ELSE
                                                        NULL
                                                END,
                                                v_tb_rec (i).item_class,
                                                v_tb_rec (i).adjustment_destination,
                                                CASE
                                                    WHEN v_tb_rec (i).close_date
                                                             IS NULL
                                                    THEN
                                                        'TRUE'
                                                    ELSE
                                                        v_tb_rec (i).item_editable_by_preparers
                                                END,
                                                v_tb_rec (i).description,
                                                v_tb_rec (i).reference,
                                                v_tb_rec (i).item_total,
                                                v_tb_rec (i).reference_field1,
                                                v_tb_rec (i).reference_field2,
                                                v_tb_rec (i).reference_field3,
                                                v_tb_rec (i).reference_field4,
                                                v_tb_rec (i).reference_field5,
                                                v_tb_rec (i).item_amount_alt_curr,
                                                v_tb_rec (i).item_amount_reporting_currency,
                                                v_tb_rec (i).item_amount_glaccount_currency,
                                                v_tb_rec (i).item_amount_transact_currency,
                                                v_tb_rec (i).item_currency,
                                                gn_request_id,
                                                SYSDATE,
                                                gn_user_id,
                                                SYSDATE,
                                                gn_user_id,
                                                v_tb_rec (i).period_name,
                                                v_tb_rec (i).ledger_id,
                                                v_tb_rec (i).alt_currency,
                                                v_tb_rec (i).close_method,
                                                NULL,
                                                NULL,
                                                v_tb_rec (i).report_type);

                        COMMIT;
                        EXIT WHEN eligible_journals_det_override%NOTFOUND;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Inserted the values in Custom Table');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                                || SQLERRM);
                    END;
                END LOOP;

                CLOSE eligible_journals_det_override;
            ELSIF p_ledger_type = 'Secondary'
            THEN
                OPEN eligible_journals_det_override;


                LOOP
                    FETCH eligible_journals_det_override
                        BULK COLLECT INTO v_tb_rec
                        LIMIT v_bulk_limit;


                    BEGIN
                        FORALL i IN 1 .. v_tb_rec.COUNT
                            INSERT INTO xxdo.xxd_gl_journals_extract_t
                                     VALUES (
                                                v_tb_rec (i).ccid,
                                                v_tb_rec (i).entity_unique_identifier,
                                                v_tb_rec (i).account,
                                                v_tb_rec (i).brand,
                                                v_tb_rec (i).geo,
                                                v_tb_rec (i).channel,
                                                v_tb_rec (i).costcenter,
                                                v_tb_rec (i).intercompany,
                                                CASE
                                                    WHEN NVL (
                                                             v_tb_rec (i).statuary_ledger,
                                                             'N') =
                                                         'Y'
                                                    THEN
                                                        v_tb_rec (i).name
                                                    ELSE
                                                        NULL
                                                END,
                                                v_tb_rec (i).key9,
                                                v_tb_rec (i).key10,
                                                v_tb_rec (i).statuary_ledger,
                                                v_tb_rec (i).unique_identifier,
                                                v_tb_rec (i).origination_date,
                                                v_tb_rec (i).open_date,
                                                v_tb_rec (i).close_date,
                                                v_tb_rec (i).item_type,
                                                v_tb_rec (i).item_sub_types,
                                                v_tb_rec (i).item_summary,
                                                CASE
                                                    WHEN v_tb_rec (i).item_class =
                                                         'R'
                                                    THEN
                                                        v_tb_rec (i).item_impact_code
                                                    ELSE
                                                        NULL
                                                END,
                                                v_tb_rec (i).item_class,
                                                v_tb_rec (i).adjustment_destination,
                                                CASE
                                                    WHEN v_tb_rec (i).close_date
                                                             IS NULL
                                                    THEN
                                                        'TRUE'
                                                    ELSE
                                                        v_tb_rec (i).item_editable_by_preparers
                                                END,
                                                v_tb_rec (i).description,
                                                v_tb_rec (i).reference,
                                                v_tb_rec (i).item_total,
                                                v_tb_rec (i).reference_field1,
                                                v_tb_rec (i).reference_field2,
                                                v_tb_rec (i).reference_field3,
                                                v_tb_rec (i).reference_field4,
                                                v_tb_rec (i).reference_field5,
                                                NULL,
                                                v_tb_rec (i).item_amount_reporting_currency,
                                                v_tb_rec (i).item_amount_glaccount_currency,
                                                v_tb_rec (i).item_amount_transact_currency,
                                                v_tb_rec (i).item_currency,
                                                gn_request_id,
                                                SYSDATE,
                                                gn_user_id,
                                                SYSDATE,
                                                gn_user_id,
                                                v_tb_rec (i).period_name,
                                                v_tb_rec (i).ledger_id,
                                                v_tb_rec (i).alt_currency,
                                                v_tb_rec (i).close_method,
                                                NULL,
                                                NULL,
                                                v_tb_rec (i).report_type);

                        COMMIT;
                        EXIT WHEN eligible_journals_det_override%NOTFOUND;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Inserted the values in Custom Table');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'insertion failed for XXD_INV_GIVR_COST_DETLS_T Table'
                                || SQLERRM);
                    END;
                -- END IF;
                END LOOP;

                CLOSE eligible_journals_det_override;
            END IF;
        --END IF;

        --
        END IF;


        --  call procedure to write the data in file at the given location or if file name is not given then write into the log

        write_extract_file (gn_request_id,
                            p_file_path,
                            l_file_name,
                            p_source_type,
                            p_override_lastrun,
                            p_ledger_type,
                            p_override_definition,
                            --1.1
                            l_last_run_date,
                            L_LAST_RUN_DATE_REVAL,
                            l_last_run_date_subled,
                            l_last_run_date_sec,
                            L_LAST_RUN_DATE_REVAL_sec,
                            l_last_run_date_subled_sec,
                            --1.1
                            lv_ret_code,
                            lv_ret_message);

        IF p_file_path IS NOT NULL
        THEN
            IF lv_ret_code = gn_error
            THEN
                p_retcode   := gn_error;
                p_errbuf    :=
                    'After write into account balance - ' || lv_ret_message;
                fnd_file.put_line (fnd_file.LOG, p_errbuf);
                raise_application_error (-20002, p_errbuf);
            END IF;

            check_file_exists (p_file_path     => p_file_path,
                               p_file_name     => l_file_name,
                               x_file_exists   => lb_file_exists,
                               x_file_length   => ln_file_length,
                               x_block_size    => ln_block_size);

            IF lb_file_exists
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
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
                fnd_file.put_line (fnd_file.LOG, lv_ret_message);
                --Complete the program in error
                p_retcode   := gn_error;
                p_errbuf    := lv_ret_message;
            END IF;
        END IF;
    END insert_prc;

    -- =====================================================================================================
    -- This procedure is Main procedure calling from concurrent program: Deckers GL Journals Extract Program
    -- =====================================================================================================

    PROCEDURE main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_ledger_type IN VARCHAR2, p_access_set_id IN NUMBER, p_ledger_name IN VARCHAR2, p_ledger_id IN NUMBER, p_chart_of_accounts_id IN NUMBER, p_ledger_currency IN VARCHAR2, p_period IN VARCHAR2, p_account_from IN VARCHAR2, p_account_to IN VARCHAR2, p_previous_period IN VARCHAR2, p_current_period IN VARCHAR2, p_jl_creation_date_from IN VARCHAR2, p_jl_creation_date_to IN VARCHAR2, p_summerize_sub_ledger IN VARCHAR2, p_summerize_manual IN VARCHAR2, p_open_balances_only IN VARCHAR2, -- this parameter is only for getting open balances its a seperate flavour of report
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_incremental_output IN VARCHAR2, p_file_path IN VARCHAR2, -- to send the file to given file path
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_override_lastrun IN VARCHAR2, -- to override the last run stored in value set
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            p_override_definition IN VARCHAR2, p_file_path_only IN VARCHAR2, -- this parameter is only for p_file_Path_only its a seperate flavour of report
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             p_source IN VARCHAR2
                    , p_category IN VARCHAR2, p_source_type IN VARCHAR2 -- this parameter to fileter the source type ex: subledger, manual
                                                                       )
    AS
    BEGIN
        -- Printing all the parameters
        fnd_file.put_line (fnd_file.LOG,
                           'Deckers GL Journals extract Program.....');
        fnd_file.put_line (fnd_file.LOG, 'Parameters Are.....');
        fnd_file.put_line (fnd_file.LOG, '-------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'p_access_set_id 				    :' || p_access_set_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_ledger_name 						:' || p_ledger_name);
        fnd_file.put_line (fnd_file.LOG, 'p_ledger_id						:' || p_ledger_id);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_chart_of_accounts_id             :' || p_chart_of_accounts_id);
        fnd_file.put_line (fnd_file.LOG,
                           'p_ledger_currency					:' || p_ledger_currency);
        fnd_file.put_line (fnd_file.LOG,
                           'p_period        					:' || p_period);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_account_from                     :' || p_account_from);
        fnd_file.put_line (fnd_file.LOG,
                           'p_account_to    					:' || p_account_to);
        fnd_file.put_line (fnd_file.LOG,
                           'p_previous_period					:' || p_previous_period);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_current_period                   :' || p_current_period);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_jl_creation_date_from            :' || p_jl_creation_date_from);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_jl_creation_date_to              :' || p_jl_creation_date_to);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_summerize_sub_ledger             :' || p_summerize_sub_ledger);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_summerize_manual	                :' || p_summerize_manual);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_open_balances_only               :' || p_open_balances_only);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_incremental_output               :' || p_incremental_output);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_file_path                        :' || p_file_path);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_override_lastrun                 :' || p_override_lastrun);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_override_definition              :' || p_override_definition);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_file_path_only                   :' || p_file_path_only);
        fnd_file.put_line (fnd_file.LOG,
                           'p_source   	                    :' || p_source);
        fnd_file.put_line (fnd_file.LOG,
                           'p_category		                    :' || p_category);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_source_type                      :' || p_source_type);
        -- Procedure to fetch and insert all the eligible records
        insert_prc (p_ledger_type, p_ledger_id, p_period,
                    p_open_balances_only, p_summerize_sub_ledger, p_summerize_manual, p_account_from, p_account_to, p_file_path, p_current_period, p_previous_period, p_override_lastrun, p_override_definition, p_file_path_only, p_jl_creation_date_from, p_jl_creation_date_to, p_source, p_category
                    , p_source_type, p_errbuf, p_retcode);
    END main;
END xxd_gl_journals_extract_pkg;
/
