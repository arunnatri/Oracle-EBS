--
-- XXD_FA_ARO_ASSET_OBLI_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_ARO_ASSET_OBLI_PKG"
AS
    /****************************************************************************************
       * Package      : XXD_FA_ARO_ASSET_OBLI_PKG
       * Design       : This package will be used to fetch the ARO asset obligation report
       * Notes        :
    * Modification :
       -- ======================================================================================
       -- Date         Version#   Name                    Comments
       -- ======================================================================================
       -- 31-Aug-2021  1.0        Showkath Ali            Initial Version
       -- 05-Jan-2023  1.1        SHowkath Ali            CCR0010389
       *******************************************************************************************/
    -- ======================================================================================
    -- Global Variable decleration
    -- ======================================================================================

    gn_user_id        CONSTANT NUMBER := fnd_global.user_id;
    gn_login_id       CONSTANT NUMBER := fnd_global.login_id;
    gn_org_id         CONSTANT NUMBER := fnd_global.org_id;
    gn_resp_id        CONSTANT NUMBER := fnd_global.resp_id;
    gn_resp_appl_id   CONSTANT NUMBER := fnd_global.resp_appl_id;
    gn_request_id     CONSTANT NUMBER := fnd_global.conc_request_id;
    ex_no_recips               EXCEPTION;
    gn_error          CONSTANT NUMBER := 2;
    gv_delimeter               VARCHAR2 (1) := '|';

    -- ======================================================================================
    -- Procedure for Override
    -- ======================================================================================
    PROCEDURE oveeride_existing_records (pv_program_mode IN VARCHAR2, pv_region IN VARCHAR2, pv_asset_book IN VARCHAR2, p_financial_year IN VARCHAR2, pv_balance_type IN VARCHAR2, sent_to_blackline IN VARCHAR2
                                         , pv_status OUT VARCHAR2)
    AS
    BEGIN
        IF pv_program_mode = 'Override' AND pv_balance_type = 'PTD'
        THEN
            BEGIN
                DELETE FROM
                    xxdo.xxd_fa_aro_ptd_values_t a
                      WHERE     pv_financial_year = p_financial_year
                            AND asset_book = pv_asset_book;

                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Successfully deleted the records from custom table for the asset_book:'
                    || pv_asset_book
                    || '-'
                    || 'For the financial year:'
                    || pv_financial_year);

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Reprocessing the records for the asset_book:'
                    || pv_asset_book
                    || '-'
                    || 'For the financial year:'
                    || pv_financial_year);

                pv_status   := 'S';
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to delete the records from custom table for the asset_book:'
                        || pv_asset_book
                        || '-'
                        || 'For the financial year:'
                        || pv_financial_year
                        || '-'
                        || SQLERRM);

                    pv_status   := 'E';
            END;
        END IF;
    END oveeride_existing_records;

    -- ======================================================================================
    -- Function to calculate ARO if Traget ARO is changed for no adj assets
    -- ======================================================================================

    FUNCTION calc_per_mon_aro_for_noadj (p_asset_id IN NUMBER, p_asset_number IN VARCHAR2, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER, p_year_end_date IN DATE, p_fin_period_counter IN NUMBER, p_extra_months IN NUMBER, p_curr_month_per_counter IN NUMBER, p_current_cost IN NUMBER
                                         , p_months_pre IN NUMBER)
        RETURN NUMBER
    IS
        --Variable Declaration

        ld_date_effective             DATE;
        ld_date_ineffective           DATE;
        ln_life_in_months             NUMBER;
        ln_cost                       NUMBER;
        ld_prorate_date               DATE;
        ld_date_placed_in_service     DATE;
        ln_count                      NUMBER := 0;
        ln_pre_aro_cost               NUMBER := 0;
        ln_pre_months                 NUMBER := 0;
        ln_per_month_acc              NUMBER := 0;
        ld_start_date                 DATE;
        ln_difference                 NUMBER := 0;
        ln_months_adj                 NUMBER := 0;
        ln_tot_acc_adj                NUMBER := 0;
        ln_tot_liability_ly           NUMBER := 0;
        ld_year_end_date              DATE := p_year_end_date;
        ln_accertion_addition_table   NUMBER;
        ln_count_of_life_from_table   NUMBER;
        ln_acc_addition               NUMBER;
        ln_count_curr                 NUMBER := 0;
        ln_start_counter              NUMBER := 0;
        ln_end_counter                NUMBER := 0;
        ln_acc_add_sum_from_table     NUMBER := 0;
    BEGIN
        -- Query to get Accredition Addition before current period
        BEGIN
            SELECT total_liability_cy - p_current_cost
              INTO ln_acc_add_sum_from_table
              FROM xxdo.xxd_fa_aro_ptd_values_t
             WHERE     asset_number = p_asset_number
                   AND period_counter = p_curr_month_per_counter - 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_acc_add_sum_from_table   := NULL;
            WHEN OTHERS
            THEN
                ln_acc_add_sum_from_table   := NULL;
        END;

        IF ln_acc_add_sum_from_table IS NULL
        THEN
            ln_acc_addition   := NULL;
            RETURN ln_acc_addition;
        ELSE
            fnd_file.put_line (fnd_file.LOG, '--------------------------');
            fnd_file.put_line (
                fnd_file.LOG,
                'IN Procedure of ARO Calculation from Table for no adj assets');
            fnd_file.put_line (fnd_file.LOG,
                               'Asset Number:' || p_asset_number);
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE asset_id = p_asset_id AND date_ineffective IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference     :=
                p_target_aro - ln_cost - ln_acc_add_sum_from_table;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);
            ln_per_month_acc   :=
                ln_difference / (ln_life_in_months - NVL (p_months_pre, 0));
            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);
            ln_acc_addition   := ln_per_month_acc;
            RETURN ln_acc_addition;
        END IF;                    --IF ln_acc_add_sum_from_table IS NULL THEN
    END calc_per_mon_aro_for_noadj;


    -- ======================================================================================
    -- Function to calculate ARO if Traget ARO is changed for adjustment assets
    -- ======================================================================================

    FUNCTION calc_per_mon_aro_tgt_cnged (
        p_asset_id                 IN NUMBER,
        p_asset_number             IN VARCHAR2,
        p_asset_book               IN VARCHAR2,
        p_target_aro               IN NUMBER,
        p_year_end_date            IN DATE,
        p_fin_period_counter       IN NUMBER,
        p_extra_months             IN NUMBER,
        p_curr_month_per_counter   IN NUMBER,
        p_current_cost             IN NUMBER,
        p_months_pre               IN NUMBER,
        p_tot_liability_ly         IN NUMBER)
        RETURN NUMBER
    IS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fab.asset_number,
                     fb.book_type_code,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     -- TRUNC(fth.date_effective) date_effective,
                     TRUNC (fb.prorate_date)
                         prorate_date,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.prorate_date) BETWEEN calendar_period_open_date
                                                             AND calendar_period_open_date
                             AND book_type_code = fa.book_type_code)
                         prorate_period,
                     (SELECT period_counter
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.prorate_date) BETWEEN calendar_period_open_date
                                                             AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         prorate_period_counter,
                     --
                     TRUNC (fb.date_effective)
                         date_effective,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_effective) BETWEEN calendar_period_open_date
                                                               AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         effective_period,
                     (SELECT period_counter
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_effective) BETWEEN calendar_period_open_date
                                                               AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         effective_period_counter,
                     ---
                     TRUNC (fb.date_ineffective)
                         date_ineffective,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_ineffective) BETWEEN calendar_period_open_date
                                                                 AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         ineffective_period,
                     (SELECT period_counter - 1
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_ineffective) BETWEEN calendar_period_open_date
                                                                 AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         ineffective_period_counter
                FROM fa_transaction_headers fth, fa_adjustments fa, fa_books fb,
                     fa_additions fab
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fab.asset_id = fb.asset_id
                     AND fb.transaction_header_id_in = fa.transaction_header_id
                     AND fth.transaction_type_code IN
                             ('ADJUSTMENT', 'ADDITION')
                     AND fth.asset_id = p_asset_id
                     AND fa.period_counter_adjusted <= p_fin_period_counter
                     --AND fa.period_counter_adjusted >= p_fin_start_period_counter
                     AND fb.cost <> 0
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, --TRUNC(fth.date_effective),
                                        TRUNC (fb.prorate_date), TRUNC (fb.date_effective),
                     TRUNC (fb.date_ineffective), fb.book_type_code, fab.asset_number
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective             DATE;
        ld_date_ineffective           DATE;
        ln_life_in_months             NUMBER;
        ln_cost                       NUMBER;
        ld_prorate_date               DATE;
        ld_date_placed_in_service     DATE;
        ln_count                      NUMBER := 0;
        ln_pre_aro_cost               NUMBER := 0;
        ln_pre_months                 NUMBER := 0;
        ln_per_month_acc              NUMBER := 0;
        ld_start_date                 DATE;
        ln_difference                 NUMBER := 0;
        ln_months_adj                 NUMBER := 0;
        ln_tot_acc_adj                NUMBER := 0;
        ln_tot_liability_ly           NUMBER := 0;
        ld_year_end_date              DATE := p_year_end_date;
        ln_accertion_addition_table   NUMBER;
        ln_count_of_life_from_table   NUMBER;
        ln_acc_addition               NUMBER;
        ln_count_curr                 NUMBER := 0;
        ln_start_counter              NUMBER := 0;
        ln_end_counter                NUMBER := 0;
        ln_acc_add_sum_from_table     NUMBER := 0;
    BEGIN
        -- Query to get Accredition Addition before current period
        /*  BEGIN
              SELECT
                  total_liability_cy - p_current_cost
              INTO ln_acc_add_sum_from_table
              FROM
                  xxdo.xxd_fa_aro_ptd_values_t
              WHERE
                  asset_number = p_asset_number
                  AND period_counter = p_curr_month_per_counter - 1;

          EXCEPTION
              WHEN no_data_found THEN
                  ln_acc_add_sum_from_table := NULL;
              WHEN OTHERS THEN
                  ln_acc_add_sum_from_table := NULL;
          END;*/
        BEGIN
            ln_acc_add_sum_from_table   :=
                p_tot_liability_ly - p_current_cost;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_acc_add_sum_from_table   := NULL;
            WHEN OTHERS
            THEN
                ln_acc_add_sum_from_table   := NULL;
        END;

        IF ln_acc_add_sum_from_table IS NULL
        THEN
            ln_acc_addition   := NULL;
            RETURN ln_acc_addition;
        ELSE
            FOR i IN get_adjustments
            LOOP
                ln_count   := ln_count + 1;

                IF ln_count = 1
                THEN
                    ln_start_counter   := i.prorate_period_counter;
                    ln_end_counter     := i.ineffective_period_counter;
                ELSE
                    ln_start_counter   := i.effective_period_counter;
                    ln_end_counter     :=
                        NVL (i.ineffective_period_counter,
                             (p_curr_month_per_counter + 1));
                END IF;

                IF p_curr_month_per_counter BETWEEN ln_start_counter
                                                AND ln_end_counter
                THEN
                    ln_count_curr   := ln_count_curr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       '--------------------------');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'IN Procedure of ARO Calculation from Table');
                    fnd_file.put_line (fnd_file.LOG,
                                       'Asset Number:' || p_asset_id);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Total Target ARO:' || p_target_aro);

                    -- Query to fetch current cost and life of the asset
                    BEGIN
                        SELECT date_effective, date_ineffective, life_in_months,
                               cost, prorate_date, date_placed_in_service
                          INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                                ld_prorate_date, ld_date_placed_in_service
                          FROM fa_books
                         WHERE     asset_id = i.asset_id
                               AND transaction_header_id_in =
                                   i.transaction_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ld_date_effective           := NULL;
                            ld_date_ineffective         := NULL;
                            ln_life_in_months           := NULL;
                            ln_cost                     := NULL;
                            ld_prorate_date             := NULL;
                            ld_date_placed_in_service   := NULL;
                    END;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'date_effective:' || ld_date_effective);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'date_ineffective:' || ld_date_ineffective);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'life_in_months:' || ln_life_in_months);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Current Cost:' || ln_cost);
                    fnd_file.put_line (fnd_file.LOG,
                                       'ld_prorate_date:' || ld_prorate_date);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'ld_date_placed_in_service:'
                        || ld_date_placed_in_service);
                    ln_difference   := p_target_aro - p_tot_liability_ly;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Difference AMount is:' || ln_difference);
                    fnd_file.put_line (fnd_file.LOG,
                                       'p_months_pre:' || p_months_pre);
                    fnd_file.put_line (fnd_file.LOG,
                                       'p_extra_months:' || p_extra_months);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'p_tot_liability_ly:' || p_tot_liability_ly);

                    -- IF ln_count = 1 THEN
                    --     ln_per_month_acc := ln_difference / ( ln_life_in_months - nvl(p_months_pre, 0) );
                    -- ELSE
                    ln_per_month_acc   :=
                          ln_difference
                        / ((ln_life_in_months - NVL (p_months_pre, 0)) + NVL (p_extra_months, 0));
                    -- END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Per month Accre is:' || ln_per_month_acc);
                ELSE
                    fnd_file.put_line (fnd_file.LOG,
                                       'Not in current adjustment');
                END IF; -- IF p_curr_month_per_counter BETWEEN ln_start_counter and ln_end_counter THEN
            END LOOP;

            ln_acc_addition   := ln_per_month_acc;
            RETURN ln_acc_addition;
        END IF;                    --IF ln_acc_add_sum_from_table IS NULL THEN
    END calc_per_mon_aro_tgt_cnged;

    PROCEDURE insert_report_records (pv_program_mode IN VARCHAR2, pv_region IN VARCHAR2, pv_asset_book IN VARCHAR2, p_financial_year IN VARCHAR2, pv_balance_type IN VARCHAR2, sent_to_blackline IN VARCHAR2
                                     , pv_period_name IN VARCHAR2)
    AS
        CURSOR get_ytd_records IS
              SELECT asset_number,
                     asset_description,
                     'YTD' || '-' || pv_financial_year accertion_balance_type,
                     cost_center,
                     MIN (pv_aro_at_establishment) pv_aro_at_establishment,
                     -- MIN(total_liability_ly) total_liability_ly,
                     (SELECT total_liability_ly
                        FROM (
                            (  SELECT total_liability_ly
                                 FROM xxdo.xxd_fa_aro_ptd_values_t b
                                WHERE     b.asset_number = a.asset_number
                                      AND b.period_year = a.period_year
                             ORDER BY period_num))
                       WHERE ROWNUM = 1) total_liability_ly,
                     MIN (pv_aro_addition) pv_aro_addition,
                     SUM (accertion_addition) accertion_addition,
                     (SELECT SUM (deletions)
                        FROM xxdo.xxd_fa_aro_ptd_values_t c
                       WHERE     1 = 1
                             AND c.asset_number = a.asset_number
                             AND period_counter <=
                                 (SELECT period_counter
                                    FROM (
                                        (  SELECT period_counter
                                             FROM xxdo.xxd_fa_aro_ptd_values_t b
                                            WHERE     b.asset_number =
                                                      a.asset_number
                                                  AND b.period_year =
                                                      a.period_year
                                         ORDER BY period_num DESC))
                                   WHERE ROWNUM = 1)) deletions,
                     (SELECT gain_or_loss
                        FROM (
                            (  SELECT gain_or_loss
                                 FROM xxdo.xxd_fa_aro_ptd_values_t b
                                WHERE     b.asset_number = a.asset_number
                                      AND b.period_year = a.period_year
                             ORDER BY period_num DESC))
                       WHERE ROWNUM = 1) gain_or_loss,
                     -- MAX(total_liability_cy) total_liability_cy,
                     (SELECT total_liability_cy
                        FROM (
                            (  SELECT total_liability_cy
                                 FROM xxdo.xxd_fa_aro_ptd_values_t b
                                WHERE     b.asset_number = a.asset_number
                                      AND b.period_year = a.period_year
                             ORDER BY period_num DESC))
                       WHERE ROWNUM = 1) total_liability_cy,
                     --total_target_aro,
                     (SELECT total_target_aro
                        FROM (
                            (  SELECT total_target_aro
                                 FROM xxdo.xxd_fa_aro_ptd_values_t b
                                WHERE     b.asset_number = a.asset_number
                                      AND b.period_year = a.period_year
                             ORDER BY period_num DESC))
                       WHERE ROWNUM = 1) total_target_aro,
                     asset_date_retired,                                    --
                     (SELECT SUM (tear_down_expense)
                        FROM xxdo.xxd_fa_aro_ptd_values_t c
                       WHERE     1 = 1
                             AND c.asset_number = a.asset_number
                             AND period_counter <=
                                 (SELECT period_counter
                                    FROM (
                                        (  SELECT period_counter
                                             FROM xxdo.xxd_fa_aro_ptd_values_t b
                                            WHERE     b.asset_number =
                                                      a.asset_number
                                                  AND b.period_year =
                                                      a.period_year
                                         ORDER BY period_num DESC))
                                   WHERE ROWNUM = 1)) tear_down_expense,    --
                     NULL period_num,                                       --
                     period_year,
                     pv_financial_year,
                     asset_book,
                     NULL period_name,
                     NULL created_by,
                     NULL creation_date,
                     NULL last_updated_by,
                     NULL last_update_date,
                     NULL request_id,
                     NULL program_mode,
                     NULL sent_to_blackline,
                     NULL sent_to_gl
                FROM xxdo.xxd_fa_aro_ptd_values_t a
               WHERE     pv_financial_year = p_financial_year
                     AND asset_book = pv_asset_book
            GROUP BY asset_number, asset_description, pv_financial_year,
                     cost_center, --deletions,
                                  -- gain_or_loss,
                                  --total_target_aro,--,
                                  asset_date_retired, --tear_down_expense,
                                                      period_year,
                     pv_financial_year, asset_book
            ORDER BY asset_number, period_num;

        CURSOR get_ptd_records IS
            SELECT asset_number,
                   asset_description,
                   accertion_balance_type,
                   cost_center,
                   pv_aro_at_establishment,
                   total_liability_ly,
                   pv_aro_addition,
                   accertion_addition,
                   (SELECT SUM (deletions)
                      FROM xxdo.xxd_fa_aro_ptd_values_t c
                     WHERE     1 = 1
                           AND c.asset_number = a.asset_number
                           AND c.period_counter <= a.period_counter)
                       deletions,
                   gain_or_loss,
                   total_liability_cy,
                   total_target_aro,
                   asset_date_retired,                                      --
                   (SELECT SUM (tear_down_expense)
                      FROM xxdo.xxd_fa_aro_ptd_values_t c
                     WHERE     1 = 1
                           AND c.asset_number = a.asset_number
                           AND period_counter <= a.period_counter)
                       tear_down_expense,                                   --
                   period_num,
                   period_year,
                   pv_financial_year,
                   asset_book,
                   period_name,
                   created_by,
                   creation_date,
                   last_updated_by,
                   last_update_date,
                   request_id,
                   program_mode,
                   sent_to_blackline,
                   sent_to_gl,
                   total_net_liability
              FROM xxdo.xxd_fa_aro_ptd_values_t a
             WHERE     pv_financial_year = p_financial_year
                   AND asset_book = pv_asset_book;

        CURSOR get_mtd_records IS
            SELECT asset_number,
                   asset_description,
                   accertion_balance_type,
                   cost_center,
                   pv_aro_at_establishment,
                   total_liability_ly,
                   pv_aro_addition,
                   accertion_addition,
                   (SELECT SUM (deletions)
                      FROM xxdo.xxd_fa_aro_ptd_values_t c
                     WHERE     1 = 1
                           AND c.asset_number = a.asset_number
                           AND c.period_counter <= a.period_counter)
                       deletions,
                   gain_or_loss,
                   total_liability_cy,
                   total_target_aro,
                   asset_date_retired,                                      --
                   (SELECT SUM (tear_down_expense)
                      FROM xxdo.xxd_fa_aro_ptd_values_t c
                     WHERE     1 = 1
                           AND c.asset_number = a.asset_number
                           AND period_counter <= a.period_counter)
                       tear_down_expense,                                   --
                   period_num,
                   period_year,
                   pv_financial_year,
                   asset_book,
                   period_name,
                   created_by,
                   creation_date,
                   last_updated_by,
                   last_update_date,
                   request_id,
                   program_mode,
                   sent_to_blackline,
                   sent_to_gl,
                   total_net_liability
              FROM xxdo.xxd_fa_aro_ptd_values_t a
             WHERE     1 = 1
                   --pv_financial_year = p_financial_year
                   AND asset_book = pv_asset_book
                   AND period_name = pv_period_name;

        ln_net_liability   NUMBER := 0;
    BEGIN
        IF pv_balance_type = 'YTD'
        THEN
            FOR i IN get_ytd_records
            LOOP
                ln_net_liability   :=
                      NVL (i.total_liability_cy, 0)
                    - NVL (i.deletions, 0)
                    - NVL (i.gain_or_loss, 0);

                IF ln_net_liability <= 0
                THEN
                    ln_net_liability   := 0;
                ELSE
                    ln_net_liability   := ln_net_liability;
                END IF;

                BEGIN
                    INSERT INTO xxdo.xxd_fa_aro_obli_report_gt
                             VALUES (
                                        i.asset_number,
                                        i.asset_description,
                                        i.accertion_balance_type,
                                        i.cost_center,
                                        i.pv_aro_at_establishment,
                                        CASE
                                            WHEN i.pv_aro_addition IS NULL
                                            THEN
                                                i.total_liability_ly
                                            ELSE
                                                NULL
                                        END,
                                        i.pv_aro_addition,
                                        i.accertion_addition,
                                        i.deletions,
                                        i.gain_or_loss,
                                        i.total_liability_cy,
                                        i.total_target_aro,
                                        i.asset_date_retired,
                                        i.tear_down_expense,
                                        NULL,
                                        NULL,
                                        i.period_num,
                                        i.asset_book,
                                        i.period_name,
                                        i.created_by,
                                        i.creation_date,
                                        i.last_updated_by,
                                        i.last_update_date,
                                        i.request_id,
                                        i.program_mode,
                                        i.sent_to_blackline,
                                        i.sent_to_gl,
                                        ln_net_liability);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the data in custom table:'
                            || SQLERRM);
                END;
            END LOOP;
        ELSIF pv_balance_type = 'PTD'
        THEN
            FOR i IN get_ptd_records
            LOOP
                IF i.total_net_liability <= 0
                THEN
                    ln_net_liability   := 0;
                ELSE
                    ln_net_liability   := i.total_net_liability;
                END IF;

                BEGIN
                    INSERT INTO xxdo.xxd_fa_aro_obli_report_gt
                         VALUES (i.asset_number, i.asset_description, i.accertion_balance_type, i.cost_center, i.pv_aro_at_establishment, i.total_liability_ly, i.pv_aro_addition, i.accertion_addition, i.deletions, i.gain_or_loss, i.total_liability_cy, i.total_target_aro, i.asset_date_retired, i.tear_down_expense, NULL, NULL, i.period_num, i.asset_book, i.period_name, i.created_by, i.creation_date, i.last_updated_by, i.last_update_date, i.request_id, i.program_mode, i.sent_to_blackline, i.sent_to_gl
                                 , ln_net_liability);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the data in custom table:'
                            || SQLERRM);
                END;
            END LOOP;
        ELSIF pv_balance_type = 'MTD'
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG, 'Inside MTD Report Condition');

            FOR i IN get_mtd_records
            LOOP
                IF i.total_net_liability <= 0
                THEN
                    ln_net_liability   := 0;
                ELSE
                    ln_net_liability   := i.total_net_liability;
                END IF;

                BEGIN
                    INSERT INTO xxdo.xxd_fa_aro_obli_report_gt
                         VALUES (i.asset_number, i.asset_description, i.accertion_balance_type, i.cost_center, i.pv_aro_at_establishment, i.total_liability_ly, i.pv_aro_addition, i.accertion_addition, i.deletions, i.gain_or_loss, i.total_liability_cy, i.total_target_aro, i.asset_date_retired, i.tear_down_expense, NULL, NULL, i.period_num, i.asset_book, i.period_name, i.created_by, i.creation_date, i.last_updated_by, i.last_update_date, i.request_id, i.program_mode, i.sent_to_blackline, i.sent_to_gl
                                 , ln_net_liability);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Failed to insert the data in custom table:'
                            || SQLERRM);
                END;
            END LOOP;
        END IF;
    END insert_report_records;

    FUNCTION get_liab_from_table (p_asset_number IN VARCHAR2, p_year IN NUMBER, p_curr_month_per_counter IN NUMBER)
        RETURN NUMBER
    AS
        ln_table_liability_cy   NUMBER;
    BEGIN
        -- get the last year balance from table
        BEGIN
            SELECT total_liability_cy
              INTO ln_table_liability_cy
              FROM xxdo.xxd_fa_aro_ptd_values_t
             WHERE     asset_number = p_asset_number
                   AND period_counter = p_curr_month_per_counter - 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_table_liability_cy   := NULL;
        END;

        RETURN ln_table_liability_cy;
    END get_liab_from_table;

    FUNCTION calculate_adj_total_lib_ly_b_ret (p_asset_id IN NUMBER, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER, p_year_start_date IN DATE, p_fin_per_counter IN NUMBER, p_extra_months IN NUMBER
                                               , p_current_cost IN NUMBER)
        RETURN NUMBER
    AS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     TRUNC (fth.date_effective)
                         date_effective
                FROM fa_transaction_headers fth, fa_adjustments fa
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fth.transaction_type_code IN (--  'ADJUSTMENT',
                                                       'ADDITION')
                     AND fth.asset_id = p_asset_id
            --AND fa.period_counter_adjusted <= p_fin_per_counter
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, TRUNC (fth.date_effective)
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective           DATE;
        ld_date_ineffective         DATE;
        ln_life_in_months           NUMBER;
        ln_cost                     NUMBER;
        ld_prorate_date             DATE;
        ld_date_placed_in_service   DATE;
        ln_count                    NUMBER := 0;
        ln_pre_aro_cost             NUMBER := 0;
        ln_pre_months               NUMBER := 0;
        ln_per_month_acc            NUMBER := 0;
        ld_start_date               DATE;
        ln_difference               NUMBER := 0;
        ln_months_adj               NUMBER := 0;
        ln_tot_acc_adj              NUMBER := 0;
        ln_tot_liability_ly         NUMBER := 0;
    BEGIN
        FOR i IN get_adjustments
        LOOP
            ln_count         := ln_count + 1;
            fnd_file.put_line (fnd_file.LOG, '--------------------------');
            fnd_file.put_line (fnd_file.LOG,
                               'Calculating Total Liability b ret');
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE     asset_id = i.asset_id
                       AND transaction_header_id_in = i.transaction_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference    := p_target_aro - ln_cost - ln_pre_aro_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);

            IF ln_count = 1
            THEN
                ln_per_month_acc   := ln_difference / ln_life_in_months;
            ELSE
                ln_per_month_acc   :=
                      ln_difference
                    / ((ln_life_in_months - ln_pre_months) + NVL (p_extra_months, 0));
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);

            IF ln_count = 1
            THEN
                ld_start_date   := ld_prorate_date;
            ELSE
                ld_start_date   := ld_date_effective;
            END IF;

            -- query to get number of months

            BEGIN
                SELECT ROUND (MONTHS_BETWEEN (p_year_start_date, ld_start_date))
                  INTO ln_months_adj
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months for Asset:'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_months_adj   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to fetch Before Adjustment months for Asset:'
                        || i.asset_id
                        || '-'
                        || SQLERRM);
            END;

            IF ln_count = 1
            THEN
                ln_pre_months   := ln_months_adj;
            ELSE
                IF (ln_pre_months + ln_months_adj) >
                   (ln_life_in_months + NVL (p_extra_months, 0))
                THEN
                    ln_months_adj   :=
                          (ln_life_in_months - ln_pre_months)
                        + NVL (p_extra_months, 0);
                    ln_pre_months   :=
                          ln_pre_months
                        + (ln_life_in_months - ln_pre_months)
                        + NVL (p_extra_months, 0);
                ELSE
                    ln_pre_months   := ln_pre_months + ln_months_adj;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months correcting for Asset :'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            END IF;

            ln_tot_acc_adj   := ln_per_month_acc * ln_months_adj;
            fnd_file.put_line (fnd_file.LOG,
                               'Total Accre:' || ln_tot_acc_adj);

            -- assigning the total cost of adjustment
            IF ln_count = 1
            THEN
                ln_pre_aro_cost   := ln_tot_acc_adj;
            ELSE
                ln_pre_aro_cost   := ln_pre_aro_cost + ln_tot_acc_adj;
            END IF;

            -- Calculating total liability of asset

            IF ln_count = 1
            THEN
                ln_tot_liability_ly   := p_current_cost + ln_tot_acc_adj;
            ELSE
                ln_tot_liability_ly   := ln_tot_liability_ly + ln_tot_acc_adj;
            END IF;

            fnd_file.put_line (fnd_file.LOG, '--------------------------');
        END LOOP;

        RETURN ln_tot_liability_ly;
    END calculate_adj_total_lib_ly_b_ret;

    FUNCTION calculate_adj_total_lib_ly_ret (p_asset_id IN NUMBER, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER, p_year_start_date IN DATE, p_fin_per_counter IN NUMBER, p_extra_months IN NUMBER
                                             , p_current_cost IN NUMBER)
        RETURN NUMBER
    AS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     TRUNC (fth.date_effective)
                         date_effective
                FROM fa_transaction_headers fth, fa_adjustments fa
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fth.transaction_type_code IN
                             ('ADJUSTMENT', 'ADDITION')
                     AND fth.asset_id = p_asset_id
                     AND fa.period_counter_adjusted <= p_fin_per_counter
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, TRUNC (fth.date_effective)
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective           DATE;
        ld_date_ineffective         DATE;
        ln_life_in_months           NUMBER;
        ln_cost                     NUMBER;
        ld_prorate_date             DATE;
        ld_date_placed_in_service   DATE;
        ln_count                    NUMBER := 0;
        ln_pre_aro_cost             NUMBER := 0;
        ln_pre_months               NUMBER := 0;
        ln_per_month_acc            NUMBER := 0;
        ld_start_date               DATE;
        ln_difference               NUMBER := 0;
        ln_months_adj               NUMBER := 0;
        ln_tot_acc_adj              NUMBER := 0;
        ln_tot_liability_ly         NUMBER := 0;
    BEGIN
        FOR i IN get_adjustments
        LOOP
            ln_count         := ln_count + 1;
            fnd_file.put_line (fnd_file.LOG, '--------------------------');
            fnd_file.put_line (fnd_file.LOG,
                               'Calculating Total Liability Ret');
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE     asset_id = i.asset_id
                       AND transaction_header_id_in = i.transaction_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference    := p_target_aro - ln_cost - ln_pre_aro_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);

            IF ln_count = 1
            THEN
                ln_per_month_acc   := ln_difference / ln_life_in_months;
            ELSE
                ln_per_month_acc   :=
                      ln_difference
                    / ((ln_life_in_months - ln_pre_months) + NVL (p_extra_months, 0));
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);

            IF ln_count = 1
            THEN
                ld_start_date   := ld_prorate_date;
            ELSE
                ld_start_date   := ld_date_effective;
            END IF;

            -- query to get number of months

            BEGIN
                SELECT ROUND (MONTHS_BETWEEN (NVL (ld_date_ineffective, p_year_start_date), ld_start_date))
                  INTO ln_months_adj
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months for Asset:'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_months_adj   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to fetch Before Adjustment months for Asset:'
                        || i.asset_id
                        || '-'
                        || SQLERRM);
            END;

            IF ln_count = 1
            THEN
                ln_pre_months   := ln_months_adj;
            ELSE
                IF (ln_pre_months + ln_months_adj) >
                   (ln_life_in_months + NVL (p_extra_months, 0))
                THEN
                    ln_months_adj   := (ln_life_in_months - ln_pre_months);
                    ln_pre_months   :=
                          ln_pre_months
                        + (ln_life_in_months - ln_pre_months)
                        + NVL (p_extra_months, 0);
                ELSE
                    ln_pre_months   := ln_pre_months + ln_months_adj;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months correcting for Asset :'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            END IF;

            ln_tot_acc_adj   := ln_per_month_acc * ln_months_adj;
            fnd_file.put_line (fnd_file.LOG,
                               'Total Accre:' || ln_tot_acc_adj);

            -- assigning the total cost of adjustment
            IF ln_count = 1
            THEN
                ln_pre_aro_cost   := ln_tot_acc_adj;
            ELSE
                ln_pre_aro_cost   := ln_pre_aro_cost + ln_tot_acc_adj;
            END IF;

            -- Calculating total liability of asset

            IF ln_count = 1
            THEN
                ln_tot_liability_ly   := p_current_cost + ln_tot_acc_adj;
            ELSE
                ln_tot_liability_ly   := ln_tot_liability_ly + ln_tot_acc_adj;
            END IF;

            fnd_file.put_line (fnd_file.LOG, '--------------------------');
        END LOOP;

        RETURN ln_tot_liability_ly;
    END calculate_adj_total_lib_ly_ret;

    -- ======================================================================================
    -- This Function is used to calculate the ARO per month for the report
    -- ======================================================================================

    PROCEDURE calculate_per_month_aro_b (p_asset_id IN NUMBER, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER
                                         , p_year_end_date IN DATE, p_fin_period_counter IN NUMBER, p_extra_months IN NUMBER)
    AS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fb.book_type_code,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     --TRUNC(fth.date_effective),
                     TRUNC (fb.prorate_date)
                         prorate_date,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.prorate_date) BETWEEN calendar_period_open_date
                                                             AND calendar_period_open_date
                             AND book_type_code = fa.book_type_code)
                         prorate_period,
                     (SELECT period_counter
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.prorate_date) BETWEEN calendar_period_open_date
                                                             AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         prorate_period_counter,
                     --
                     TRUNC (fb.date_effective)
                         date_effective,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_effective) BETWEEN calendar_period_open_date
                                                               AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         effective_period,
                     (SELECT period_counter
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_effective) BETWEEN calendar_period_open_date
                                                               AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         effective_period_counter,
                     ---
                     TRUNC (fb.date_ineffective)
                         date_ineffective,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_ineffective) BETWEEN calendar_period_open_date
                                                                 AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         ineffective_period,
                     (SELECT period_counter - 1
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_ineffective) BETWEEN calendar_period_open_date
                                                                 AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         ineffective_period_counter
                FROM fa_transaction_headers fth, fa_adjustments fa, fa_books fb
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fb.transaction_header_id_in = fa.transaction_header_id
                     AND fth.transaction_type_code IN (-- 'ADJUSTMENT',
                                                       'ADDITION')
                     AND fth.asset_id = p_asset_id
            -- AND fa.period_counter_adjusted <= p_fin_period_counter
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, --TRUNC(fth.date_effective),
                                        TRUNC (fb.prorate_date), TRUNC (fb.date_effective),
                     TRUNC (fb.date_ineffective), fb.book_type_code
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective           DATE;
        ld_date_ineffective         DATE;
        ln_life_in_months           NUMBER;
        ln_cost                     NUMBER;
        ld_prorate_date             DATE;
        ld_date_placed_in_service   DATE;
        ln_count                    NUMBER := 0;
        ln_pre_aro_cost             NUMBER := 0;
        ln_pre_months               NUMBER := 0;
        ln_per_month_acc            NUMBER := 0;
        ld_start_date               DATE;
        ln_difference               NUMBER := 0;
        ln_months_adj               NUMBER := 0;
        ln_tot_acc_adj              NUMBER := 0;
        ln_tot_liability_ly         NUMBER := 0;
        ld_year_end_date            DATE := p_year_end_date;
    BEGIN
        FOR i IN get_adjustments
        LOOP
            ln_count         := ln_count + 1;
            fnd_file.put_line (fnd_file.LOG,
                               '--------------------------' || p_target_aro);
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE     asset_id = i.asset_id
                       AND transaction_header_id_in = i.transaction_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference    := p_target_aro - ln_cost - ln_pre_aro_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);

            IF ln_count = 1
            THEN
                ln_per_month_acc   := ln_difference / ln_life_in_months;
            ELSE
                ln_per_month_acc   :=
                      ln_difference
                    / ((ln_life_in_months - ln_pre_months) + NVL (p_extra_months, 0));
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);

            IF ln_count = 1
            THEN
                ld_start_date   := ld_prorate_date;
            ELSE
                ld_start_date   := ld_date_effective;
            END IF;

            -- query to get number of months

            BEGIN
                SELECT ROUND (MONTHS_BETWEEN (NVL (ld_date_ineffective, p_year_end_date), ld_start_date))
                  INTO ln_months_adj
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months for Asset:'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_months_adj   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to fetch Before Adjustment months for Asset:'
                        || i.asset_id
                        || '-'
                        || SQLERRM);
            END;

            IF ln_count = 1
            THEN
                ln_pre_months   := ln_months_adj;
            ELSE
                ln_pre_months   := ln_pre_months + ln_months_adj;
            END IF;

            ln_tot_acc_adj   := ln_per_month_acc * ln_months_adj;

            -- assigning the total cost of adjustment
            IF ln_count = 1
            THEN
                ln_pre_aro_cost   := ln_tot_acc_adj;
            ELSE
                ln_pre_aro_cost   := ln_pre_aro_cost + ln_tot_acc_adj;
            END IF;

            -- Calculating total liability of asset

            IF ln_count = 1
            THEN
                ln_tot_liability_ly   := ln_cost + ln_tot_acc_adj;
            ELSE
                ln_tot_liability_ly   := ln_tot_liability_ly + ln_tot_acc_adj;
            END IF;

            BEGIN
                INSERT INTO xxdo.xxd_fa_adjustment_data_t
                         VALUES (
                                    ln_count,
                                    p_asset_id,
                                    i.book_type_code,
                                    CASE
                                        WHEN ln_count = 1 THEN i.prorate_date
                                        ELSE i.date_effective
                                    END,
                                    NVL (i.date_ineffective,
                                         ld_year_end_date),
                                    CASE
                                        WHEN ln_count = 1
                                        THEN
                                            i.prorate_period
                                        ELSE
                                            i.effective_period
                                    END,
                                    i.ineffective_period,
                                    CASE
                                        WHEN ln_count = 1
                                        THEN
                                            i.prorate_period_counter
                                        ELSE
                                            i.effective_period_counter
                                    END,
                                    NVL (i.ineffective_period_counter,
                                         p_fin_period_counter),
                                    ln_per_month_acc,
                                    gn_request_id);

                COMMIT;
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    END calculate_per_month_aro_b;

    -- ======================================================================================
    -- This Function is used to get the total liabikity till Last year the report
    -- ======================================================================================

    FUNCTION calculate_adj_total_lib_ly_b (p_asset_id IN NUMBER, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER, p_year_start_date IN DATE, p_fin_per_counter IN NUMBER, p_extra_months IN NUMBER
                                           , p_current_cost IN NUMBER)
        RETURN NUMBER
    AS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     TRUNC (fth.date_effective)
                         date_effective
                FROM fa_transaction_headers fth, fa_adjustments fa
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fth.transaction_type_code IN (--  'ADJUSTMENT',
                                                       'ADDITION')
                     AND fth.asset_id = p_asset_id
            --AND fa.period_counter_adjusted <= p_fin_per_counter
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, TRUNC (fth.date_effective)
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective           DATE;
        ld_date_ineffective         DATE;
        ln_life_in_months           NUMBER;
        ln_cost                     NUMBER;
        ld_prorate_date             DATE;
        ld_date_placed_in_service   DATE;
        ln_count                    NUMBER := 0;
        ln_pre_aro_cost             NUMBER := 0;
        ln_pre_months               NUMBER := 0;
        ln_per_month_acc            NUMBER := 0;
        ld_start_date               DATE;
        ln_difference               NUMBER := 0;
        ln_months_adj               NUMBER := 0;
        ln_tot_acc_adj              NUMBER := 0;
        ln_tot_liability_ly         NUMBER := 0;
    BEGIN
        FOR i IN get_adjustments
        LOOP
            ln_count         := ln_count + 1;
            fnd_file.put_line (fnd_file.LOG, '--------------------------');
            fnd_file.put_line (fnd_file.LOG, 'Calculating Total Liability b');
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE     asset_id = i.asset_id
                       AND transaction_header_id_in = i.transaction_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference    := p_target_aro - ln_cost - ln_pre_aro_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);

            IF ln_count = 1
            THEN
                ln_per_month_acc   := ln_difference / ln_life_in_months;
            ELSE
                ln_per_month_acc   :=
                      ln_difference
                    / ((ln_life_in_months - ln_pre_months) + NVL (p_extra_months, 0));
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);

            IF ln_count = 1
            THEN
                ld_start_date   := ld_prorate_date;
            ELSE
                ld_start_date   := ld_date_effective;
            END IF;

            -- query to get number of months

            BEGIN
                SELECT ROUND (MONTHS_BETWEEN (p_year_start_date, ld_start_date))
                  INTO ln_months_adj
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months for Asset:'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_months_adj   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to fetch Before Adjustment months for Asset:'
                        || i.asset_id
                        || '-'
                        || SQLERRM);
            END;

            IF ln_count = 1
            THEN
                ln_pre_months   := ln_months_adj;
            ELSE
                ln_pre_months   := ln_pre_months + ln_months_adj;
            END IF;

            ln_tot_acc_adj   := ln_per_month_acc * ln_months_adj;
            fnd_file.put_line (fnd_file.LOG,
                               'Total Accre:' || ln_tot_acc_adj);

            -- assigning the total cost of adjustment
            IF ln_count = 1
            THEN
                ln_pre_aro_cost   := ln_tot_acc_adj;
            ELSE
                ln_pre_aro_cost   := ln_pre_aro_cost + ln_tot_acc_adj;
            END IF;

            -- Calculating total liability of asset

            IF ln_count = 1
            THEN
                ln_tot_liability_ly   := p_current_cost + ln_tot_acc_adj;
            ELSE
                ln_tot_liability_ly   := ln_tot_liability_ly + ln_tot_acc_adj;
            END IF;

            fnd_file.put_line (fnd_file.LOG, '--------------------------');
        END LOOP;

        RETURN ln_tot_liability_ly;
    END calculate_adj_total_lib_ly_b;

    -- ======================================================================================
    -- This function is used to return tear down expense from into table
    -- ======================================================================================

    FUNCTION get_tear_down (p_asset_number IN VARCHAR2, p_cost_center IN NUMBER, ln_book_company IN NUMBER)
        RETURN NUMBER
    IS
        ln_amount   NUMBER;
    BEGIN
        BEGIN
            SELECT invoice_amount
              INTO ln_amount
              FROM xxdo.xxd_fa_tear_down_data_t
             WHERE asset_number = p_asset_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_amount   := NULL;
        END;

        BEGIN
            UPDATE xxdo.xxd_fa_tear_down_data_t
               SET mapped_flag   = 'Y'
             WHERE asset_number = p_asset_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                NULL;
        END;

        RETURN ln_amount;

        IF ln_amount IS NULL
        THEN
            BEGIN
                SELECT SUM (invoice_amount)
                  INTO ln_amount
                  FROM xxdo.xxd_fa_tear_down_data_t
                 WHERE cost_center = p_cost_center AND cost_center <> 1000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_amount   := NULL;
            END;

            BEGIN
                UPDATE xxdo.xxd_fa_tear_down_data_t
                   SET mapped_flag   = 'Y'
                 WHERE cost_center = p_cost_center;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            RETURN ln_amount;
        END IF;
    END get_tear_down;

    -- ======================================================================================
    -- This procedure is used to load tear down expense data into table
    -- ======================================================================================

    PROCEDURE load_tear_down_data (p_book_company IN NUMBER, pd_start_date IN DATE, pd_end_date IN DATE)
    AS
        CURSOR load_tear_down_data_cur IS
              SELECT ship_to_location_id, location_name, asset_number,
                     company, cost_center, account,
                     SUM (invoice_amount) amount
                FROM (SELECT DISTINCT
                             aila.ship_to_location_id,
                             (SELECT location_code
                                FROM hr_locations_all
                               WHERE location_id =
                                     aila.ship_to_location_id)
                                 location_name,
                             (aia.invoice_amount),
                             (SELECT attribute5
                                FROM hr_locations_all
                               WHERE location_id = aila.ship_to_location_id)
                                 asset_number,
                             gcc.segment1
                                 company,
                             gcc.segment5
                                 cost_center,
                             gcc.segment6
                                 account
                        FROM apps.ap_invoices_all aia, apps.ap_invoice_lines_all aila, apps.ap_invoice_distributions_all aida,
                             apps.hr_operating_units hou, apps.ap_suppliers asa, apps.xla_events xe,
                             apps.xla_ae_headers xah, apps.xla_ae_lines xal, apps.gl_code_combinations gcc
                       WHERE     1 = 1
                             AND aia.invoice_id = aila.invoice_id
                             AND aia.invoice_id = aida.invoice_id
                             AND aia.vendor_id = asa.vendor_id
                             AND xe.event_id = aida.accounting_event_id
                             AND xe.event_id = xah.event_id
                             AND xe.entity_id = xah.entity_id
                             AND xah.ledger_id = aia.set_of_books_id
                             AND xah.ae_header_id = xal.ae_header_id
                             AND xal.accounting_class_code IN
                                     ('ITEM EXPENSE', 'CHARGE')
                             AND aila.ship_to_location_id IS NOT NULL
                             AND hou.organization_id = aia.org_id
                             AND xal.code_combination_id =
                                 gcc.code_combination_id
                             AND aia.invoice_amount <> 0
                             AND gcc.segment6 IN
                                     (SELECT ffvl.flex_value
                                        FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                       WHERE     fvs.flex_value_set_id =
                                                 ffvl.flex_value_set_id
                                             AND fvs.flex_value_set_name =
                                                 'XXD_FA_ARO_TEAR_DOWN_ACCTS_VS'
                                             AND NVL (
                                                     TRUNC (
                                                         ffvl.start_date_active),
                                                     TRUNC (SYSDATE)) <=
                                                 TRUNC (SYSDATE)
                                             AND NVL (
                                                     TRUNC (
                                                         ffvl.end_date_active),
                                                     TRUNC (SYSDATE)) >=
                                                 TRUNC (SYSDATE)
                                             AND ffvl.enabled_flag = 'Y')
                             --'66412'
                             AND gcc.segment1 =
                                 NVL (p_book_company, gcc.segment1)
                             AND xah.accounting_date BETWEEN pd_start_date
                                                         AND pd_end_date)
               WHERE 1 = 1
            GROUP BY ship_to_location_id, location_name, asset_number,
                     company, cost_center, account;
    BEGIN
        FND_FILE.PUT_LINE (FND_FILE.LOG,
                           'Inside Tear down calculation Procedure');


        FOR i IN load_tear_down_data_cur
        LOOP
            BEGIN
                INSERT INTO xxdo.xxd_fa_tear_down_data_t
                     VALUES (i.ship_to_location_id, i.location_name, i.asset_number, i.company, i.cost_center, i.account
                             , i.amount, NULL);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    END load_tear_down_data;

    -- ======================================================================================
    -- This Function is used to get the cost center
    -- ======================================================================================

    FUNCTION get_cost_center (p_asset_id IN NUMBER, p_ledger_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_cost_center   NUMBER := 0;
    BEGIN
        BEGIN
            SELECT DISTINCT gcc.segment5
              INTO ln_cost_center
              FROM apps.fa_transaction_headers fth, apps.xla_events xe, apps.xla_ae_headers xah,
                   apps.xla_ae_lines xal, apps.gl_code_combinations gcc
             WHERE     1 = 1
                   AND xe.event_id = fth.event_id
                   AND xe.event_id = xah.event_id
                   AND xe.entity_id = xah.entity_id
                   AND xah.ae_header_id = xal.ae_header_id
                   AND xal.accounting_class_code = 'ASSET'
                   AND xal.code_combination_id = gcc.code_combination_id
                   AND asset_id = p_asset_id
                   AND xal.ledger_id = p_ledger_id
                   AND fth.transaction_header_id =
                       (SELECT MAX (transaction_header_id)
                          FROM fa_transaction_headers
                         WHERE asset_id = p_asset_id AND event_id IS NOT NULL);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_cost_center   := NULL;
            WHEN TOO_MANY_ROWS
            THEN
                ln_cost_center   := NULL;
            WHEN OTHERS
            THEN
                ln_cost_center   := NULL;
        END;

        IF ln_cost_center IS NULL
        THEN
            BEGIN
                SELECT DISTINCT gcc.segment5
                  INTO ln_cost_center
                  FROM apps.fa_deprn_detail fth, apps.xla_events xe, apps.xla_ae_headers xah,
                       apps.xla_ae_lines xal, apps.gl_code_combinations gcc
                 WHERE     1 = 1
                       AND xe.event_id = fth.event_id
                       AND xe.event_id = xah.event_id
                       AND xe.entity_id = xah.entity_id
                       AND xah.ae_header_id = xal.ae_header_id
                       AND xal.accounting_class_code = 'ASSET'
                       AND xal.code_combination_id = gcc.code_combination_id
                       AND asset_id = p_asset_id
                       AND xal.ledger_id = p_ledger_id
                       AND fth.period_counter =
                           (SELECT MAX (period_counter)
                              FROM fa_deprn_detail
                             WHERE     asset_id = p_asset_id
                                   AND deprn_source_code = 'D'
                                   AND event_id IS NOT NULL);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_cost_center   := NULL;
            END;
        END IF;

        RETURN ln_cost_center;
    END get_cost_center;

    -- ======================================================================================
    -- This Function is used to calculate the ARO per month for the report
    -- ======================================================================================

    PROCEDURE calculate_per_month_aro (p_asset_id IN NUMBER, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER
                                       , p_year_end_date IN DATE, p_fin_period_counter IN NUMBER, p_extra_months IN NUMBER)
    AS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fb.book_type_code,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     -- TRUNC(fth.date_effective) date_effective,
                     TRUNC (fb.prorate_date)
                         prorate_date,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.prorate_date) BETWEEN calendar_period_open_date
                                                             AND calendar_period_open_date
                             AND book_type_code = fa.book_type_code)
                         prorate_period,
                     (SELECT period_counter
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.prorate_date) BETWEEN calendar_period_open_date
                                                             AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         prorate_period_counter,
                     --
                     TRUNC (fb.date_effective)
                         date_effective,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_effective) BETWEEN calendar_period_open_date
                                                               AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         effective_period,
                     (SELECT period_counter
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_effective) BETWEEN calendar_period_open_date
                                                               AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         effective_period_counter,
                     ---
                     TRUNC (fb.date_ineffective)
                         date_ineffective,
                     (SELECT period_name
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_ineffective) BETWEEN calendar_period_open_date
                                                                 AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         ineffective_period,
                     (SELECT period_counter - 1
                        FROM fa_deprn_periods a
                       WHERE     TRUNC (fb.date_ineffective) BETWEEN calendar_period_open_date
                                                                 AND calendar_period_close_date
                             AND book_type_code = fa.book_type_code)
                         ineffective_period_counter
                FROM fa_transaction_headers fth, fa_adjustments fa, fa_books fb
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fb.transaction_header_id_in = fa.transaction_header_id
                     AND fth.transaction_type_code IN
                             ('ADJUSTMENT', 'ADDITION')
                     AND fth.asset_id = p_asset_id
                     AND fa.period_counter_adjusted <= p_fin_period_counter
                     AND fb.cost <> 0
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, --TRUNC(fth.date_effective),
                                        TRUNC (fb.prorate_date), TRUNC (fb.date_effective),
                     TRUNC (fb.date_ineffective), fb.book_type_code
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective           DATE;
        ld_date_ineffective         DATE;
        ln_life_in_months           NUMBER;
        ln_cost                     NUMBER;
        ld_prorate_date             DATE;
        ld_date_placed_in_service   DATE;
        ln_count                    NUMBER := 0;
        ln_pre_aro_cost             NUMBER := 0;
        ln_pre_months               NUMBER := 0;
        ln_per_month_acc            NUMBER := 0;
        ld_start_date               DATE;
        ln_difference               NUMBER := 0;
        ln_months_adj               NUMBER := 0;
        ln_tot_acc_adj              NUMBER := 0;
        ln_tot_liability_ly         NUMBER := 0;
        ld_year_end_date            DATE := p_year_end_date;
    BEGIN
        FOR i IN get_adjustments
        LOOP
            ln_count         := ln_count + 1;
            fnd_file.put_line (fnd_file.LOG,
                               '--------------------------' || p_target_aro);
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE     asset_id = i.asset_id
                       AND transaction_header_id_in = i.transaction_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference    := p_target_aro - ln_cost - ln_pre_aro_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);

            IF ln_count = 1
            THEN
                ln_per_month_acc   := ln_difference / ln_life_in_months;
            ELSE
                ln_per_month_acc   :=
                      ln_difference
                    / ((ln_life_in_months - ln_pre_months) + NVL (p_extra_months, 0));
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);

            IF ln_count = 1
            THEN
                ld_start_date   := ld_prorate_date;
            ELSE
                ld_start_date   := ld_date_effective;
            END IF;

            -- query to get number of months

            BEGIN
                SELECT ROUND (MONTHS_BETWEEN (NVL (ld_date_ineffective, p_year_end_date), ld_start_date))
                  INTO ln_months_adj
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months for Asset:'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_months_adj   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to fetch Before Adjustment months for Asset:'
                        || i.asset_id
                        || '-'
                        || SQLERRM);
            END;

            IF ln_count = 1
            THEN
                ln_pre_months   := ln_months_adj;
            ELSE
                ln_pre_months   := ln_pre_months + ln_months_adj;
            END IF;

            ln_tot_acc_adj   := ln_per_month_acc * ln_months_adj;

            -- assigning the total cost of adjustment
            IF ln_count = 1
            THEN
                ln_pre_aro_cost   := ln_tot_acc_adj;
            ELSE
                ln_pre_aro_cost   := ln_pre_aro_cost + ln_tot_acc_adj;
            END IF;

            -- Calculating total liability of asset

            IF ln_count = 1
            THEN
                ln_tot_liability_ly   := ln_cost + ln_tot_acc_adj;
            ELSE
                ln_tot_liability_ly   := ln_tot_liability_ly + ln_tot_acc_adj;
            END IF;

            BEGIN
                INSERT INTO xxdo.xxd_fa_adjustment_data_t
                         VALUES (
                                    ln_count,
                                    p_asset_id,
                                    i.book_type_code,
                                    CASE
                                        WHEN ln_count = 1 THEN i.prorate_date
                                        ELSE i.date_effective
                                    END,
                                    NVL (i.date_ineffective,
                                         ld_year_end_date),
                                    CASE
                                        WHEN ln_count = 1
                                        THEN
                                            i.prorate_period
                                        ELSE
                                            i.effective_period
                                    END,
                                    i.ineffective_period,
                                    CASE
                                        WHEN ln_count = 1
                                        THEN
                                            i.prorate_period_counter
                                        ELSE
                                            i.effective_period_counter
                                    END,
                                    NVL (i.ineffective_period_counter,
                                         p_fin_period_counter),
                                    ln_per_month_acc,
                                    gn_request_id);

                COMMIT;
                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END LOOP;
    END calculate_per_month_aro;

    -- ======================================================================================
    -- This Function is used to get the total liabikity till Last year the report
    -- ======================================================================================

    FUNCTION calculate_adj_total_lib_ly (p_asset_id IN NUMBER, p_asset_book IN VARCHAR2, p_target_aro IN NUMBER, p_year_start_date IN DATE, p_fin_per_counter IN NUMBER, p_extra_months IN NUMBER
                                         , p_current_cost IN NUMBER)
        RETURN NUMBER
    AS
        CURSOR get_adjustments                                             --(
                               -- p_asset_id IN NUBER
                               --   )

                               IS
              SELECT fth.transaction_type_code,
                     MAX (fa.transaction_header_id)
                         transaction_header_id,
                     fa.asset_id,
                     fa.period_counter_adjusted
                         period_counter,
                     (SELECT period_name
                        FROM fa_deprn_periods
                       WHERE     period_counter = fa.period_counter_adjusted
                             AND book_type_code = fa.book_type_code)
                         period_name,
                     TRUNC (fth.date_effective)
                         date_effective
                FROM fa_transaction_headers fth, fa_adjustments fa
               WHERE     fth.transaction_header_id = fa.transaction_header_id
                     AND fth.transaction_type_code IN
                             ('ADJUSTMENT', 'ADDITION')
                     AND fth.asset_id = p_asset_id
                     AND fa.period_counter_adjusted <= p_fin_per_counter
            GROUP BY fth.transaction_type_code, fa.asset_id, fa.period_counter_adjusted,
                     fa.book_type_code, TRUNC (fth.date_effective)
            ORDER BY transaction_header_id;

        --Variable Declaration

        ld_date_effective           DATE;
        ld_date_ineffective         DATE;
        ln_life_in_months           NUMBER;
        ln_cost                     NUMBER;
        ld_prorate_date             DATE;
        ld_date_placed_in_service   DATE;
        ln_count                    NUMBER := 0;
        ln_pre_aro_cost             NUMBER := 0;
        ln_pre_months               NUMBER := 0;
        ln_per_month_acc            NUMBER := 0;
        ld_start_date               DATE;
        ln_difference               NUMBER := 0;
        ln_months_adj               NUMBER := 0;
        ln_tot_acc_adj              NUMBER := 0;
        ln_tot_liability_ly         NUMBER := 0;
    BEGIN
        FOR i IN get_adjustments
        LOOP
            ln_count         := ln_count + 1;
            fnd_file.put_line (fnd_file.LOG, '--------------------------');
            fnd_file.put_line (fnd_file.LOG, 'Calculating Total Liability');
            fnd_file.put_line (fnd_file.LOG, 'Asset Number:' || p_asset_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Total Target ARO:' || p_target_aro);

            -- Query to fetch current cost and life of the asset
            BEGIN
                SELECT date_effective, date_ineffective, life_in_months,
                       cost, prorate_date, date_placed_in_service
                  INTO ld_date_effective, ld_date_ineffective, ln_life_in_months, ln_cost,
                                        ld_prorate_date, ld_date_placed_in_service
                  FROM fa_books
                 WHERE     asset_id = i.asset_id
                       AND transaction_header_id_in = i.transaction_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ld_date_effective           := NULL;
                    ld_date_ineffective         := NULL;
                    ln_life_in_months           := NULL;
                    ln_cost                     := NULL;
                    ld_prorate_date             := NULL;
                    ld_date_placed_in_service   := NULL;
            END;

            fnd_file.put_line (fnd_file.LOG,
                               'date_effective:' || ld_date_effective);
            fnd_file.put_line (fnd_file.LOG,
                               'date_ineffective:' || ld_date_ineffective);
            fnd_file.put_line (fnd_file.LOG,
                               'life_in_months:' || ln_life_in_months);
            fnd_file.put_line (fnd_file.LOG, 'Current Cost:' || ln_cost);
            fnd_file.put_line (fnd_file.LOG,
                               'ld_prorate_date:' || ld_prorate_date);
            fnd_file.put_line (
                fnd_file.LOG,
                'ld_date_placed_in_service:' || ld_date_placed_in_service);
            ln_difference    := p_target_aro - ln_cost - ln_pre_aro_cost;
            fnd_file.put_line (fnd_file.LOG,
                               'Difference AMount is:' || ln_difference);

            IF ln_count = 1
            THEN
                ln_per_month_acc   := ln_difference / ln_life_in_months;
            ELSE
                ln_per_month_acc   :=
                      ln_difference
                    / ((ln_life_in_months - ln_pre_months) + NVL (p_extra_months, 0));
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'Per month Accre is:' || ln_per_month_acc);

            IF ln_count = 1
            THEN
                ld_start_date   := ld_prorate_date;
            ELSE
                ld_start_date   := ld_date_effective;
            END IF;

            -- query to get number of months

            BEGIN
                SELECT ROUND (MONTHS_BETWEEN (NVL (ld_date_ineffective, p_year_start_date), ld_start_date))
                  INTO ln_months_adj
                  FROM DUAL;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Before Adjustment months for Asset:'
                    || i.asset_id
                    || '-'
                    || ln_months_adj);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_months_adj   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to fetch Before Adjustment months for Asset:'
                        || i.asset_id
                        || '-'
                        || SQLERRM);
            END;

            IF ln_count = 1
            THEN
                ln_pre_months   := ln_months_adj;
            ELSE
                ln_pre_months   := ln_pre_months + ln_months_adj;
            END IF;

            ln_tot_acc_adj   := ln_per_month_acc * ln_months_adj;
            fnd_file.put_line (fnd_file.LOG,
                               'Total Accre:' || ln_tot_acc_adj);

            -- assigning the total cost of adjustment
            IF ln_count = 1
            THEN
                ln_pre_aro_cost   := ln_tot_acc_adj;
            ELSE
                ln_pre_aro_cost   := ln_pre_aro_cost + ln_tot_acc_adj;
            END IF;

            -- Calculating total liability of asset

            IF ln_count = 1
            THEN
                ln_tot_liability_ly   := p_current_cost + ln_tot_acc_adj;
            ELSE
                ln_tot_liability_ly   := ln_tot_liability_ly + ln_tot_acc_adj;
            END IF;

            fnd_file.put_line (fnd_file.LOG, '--------------------------');
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'ln_tot_liability_ly:' || ln_tot_liability_ly);
        RETURN ln_tot_liability_ly;
    END calculate_adj_total_lib_ly;

    PROCEDURE generate_report (pv_program_mode IN VARCHAR2, pv_region IN VARCHAR2, pv_asset_book IN VARCHAR2, pv_financial_year IN VARCHAR2, pv_balance_type IN VARCHAR2, sent_to_blackline IN VARCHAR2
                               , pv_mtd_period_name IN VARCHAR2)
    AS
        CURSOR get_aro_records IS SELECT * FROM xxdo.xxd_fa_aro_obli_t;

        CURSOR qtd_balance_periods (p_period_year IN NUMBER, p_start_period_num IN NUMBER, p_end_period_num IN NUMBER)
        IS
            /* SELECT
                 period_name,
                 start_date,
                 end_date,
                 period_num,
                 period_year,
                 (
                     SELECT
                         period_counter
                     FROM
                         fa_deprn_periods
                     WHERE
                         period_name = gp.period_name
                         AND book_type_code = pv_asset_book
                 ) period_counter
             FROM
                 gl_periods gp
             WHERE
                 period_year = p_period_year
                 AND period_set_name = 'DO_FY_CALENDAR'
                 AND NOT EXISTS (
                     SELECT
                         1
                     FROM
                         gl_period_statuses gps
                     WHERE
                         gps.period_name = gp.period_name
                         AND closing_status IN (
                             'F',
                             'N',
                             'O'
                         )
                         AND application_id = 101
                         AND ledger_id = 2036
                 )
                 AND period_num BETWEEN p_start_period_num AND p_end_period_num
                 AND period_name = nvl(pv_mtd_period_name, period_name);*/
            -- commented for 1.1
            SELECT period_name,
                   start_date,
                   end_date,
                   period_num,
                   period_year,
                   (SELECT period_counter
                      FROM apps.fa_deprn_periods
                     WHERE     period_name = gp.period_name
                           AND book_type_code = pv_asset_book) period_counter
              FROM apps.gl_periods gp
             WHERE     period_year = p_period_year
                   AND period_set_name = 'DO_FY_CALENDAR'
                   AND EXISTS
                           (SELECT 1
                              FROM apps.fa_deprn_periods gps
                             WHERE     gps.period_name = gp.period_name
                                   AND book_type_code = pv_asset_book
                                   AND period_close_date IS NOT NULL)
                   AND period_num BETWEEN p_start_period_num
                                      AND p_end_period_num
                   AND period_name = NVL (pv_mtd_period_name, period_name); -- 1.1


        ln_asset_start_per_num           NUMBER;
        ln_asset_start_per_year          NUMBER;
        current_yr_end_period            VARCHAR2 (20);
        curr_yr_period_num               NUMBER;
        curr_yr_period_year              NUMBER;
        ln_period_num_start              NUMBER;
        ln_period_year                   NUMBER;
        ln_period_num_end                NUMBER;
        lv_transaction_type_code         VARCHAR2 (30);
        ---------------------
        ln_accertion_addition            NUMBER := NULL;
        ln_tot_liability_ly              NUMBER;
        ln_deletion_check                NUMBER;
        ln_deletions                     NUMBER;
        ln_tot_liability_cy              NUMBER;
        ln_ptd_aro_addition              NUMBER;
        ln_asset_placed_month_count      NUMBER;
        ln_ptd_tot_liability_ly          NUMBER := 0;
        ln_ptd_tot_liability_ly0         NUMBER;
        ln_ptd_tot_liability_ly1         NUMBER;
        lv_current_fy                    VARCHAR2 (20);
        lv_last_fy                       VARCHAR2 (20);
        lv_sysdate                       VARCHAR2 (20);
        ln_count                         NUMBER := 0;
        ln_nbv                           NUMBER := 0;
        ln_adj_count                     NUMBER := 0;
        ln_liab_count                    NUMBER := 0;
        ln_asset_life_before_adj         NUMBER := 0;
        ld_adj_entered                   DATE;
        tot_acc_before_adj               NUMBER := 0;
        ln_difference                    NUMBER := 0;
        ln_per_month_amt_bef_adj         NUMBER := 0;
        ln_pre_adj_months                NUMBER := 0;
        ln_diff_amount_after             NUMBER := 0;
        ln_post_adj_months               NUMBER := 0;
        ln_acc_per_mon_aft_adj           NUMBER := 0;
        ln_post_adj_asset_life           NUMBER := 0;
        ln_tot_acc_after_adj             NUMBER := 0;
        ln_extra_months_post             NUMBER := 0;
        lv_nbv_period                    VARCHAR2 (20);
        max_nbv_period                   VARCHAR2 (20);
        ln_asset_cost_before_adj         NUMBER := 0;
        ln_asset_per_num                 NUMBER := 0;
        ln_asset_per_year                NUMBER := 0;
        ln_min_period_counter            NUMBER := 0;
        ln_fin_period_counter            NUMBER := 0;
        ln_ret_month_cost                NUMBER := 0;
        ln_ret_life_in_months            NUMBER := 0;
        ln_ret_cost                      NUMBER := 0;
        ln_transaction_header_id         NUMBER := 0;
        ld_date_effective                DATE;
        ln_tot_liab_ly                   NUMBER := 0;
        ln_parameter_period_counter      NUMBER := 0;
        ln_cursor_count                  NUMBER := 0;
        ln_cost_center                   NUMBER := 0;
        ln_accertion_addition_ytd        NUMBER := 0;
        ln_ytd_tot_liability_ly          NUMBER := 0;
        ln_period_exist_count            NUMBER := 0;
        ln_tear_down_amount              NUMBER := 0;
        ln_ledger_id                     NUMBER := 0;
        ln_book_company                  NUMBER := 0;
        lv_adj                           VARCHAR2 (1);
        -- ln_liab_count                  NUMBER := 0;
        ln_liab_counter                  NUMBER := 0;
        lv_lia_transaction_type_code     VARCHAR2 (100);
        lv_adj_lib                       VARCHAR2 (1);
        max_nbv_period_counter           NUMBER := 0;
        max_nbv_exp_period_counter       NUMBER := 0;
        ln_ytd_tot_liability_table       NUMBER := 0;
        ln_ptd_tot_liability_table       NUMBER := 0;
        ln_months_pre                    NUMBER := 0;
        ln_accertion_addition_table      NUMBER := 0;
        lv_financial_year                VARCHAR2 (50);
        lv_curr_fin_year                 VARCHAR2 (50);
        lv_curr_fin_period_year          NUMBER;
        ln_curr_year_count               NUMBER;
        lv_curr_fin_period               VARCHAR2 (50);
        lv_financial_year_rep            VARCHAR2 (50);
        ln_gain_or_loss_count            NUMBER;
        ln_gain_or_loss                  NUMBER;
        ln_ptd_tot_liability_table_pre   NUMBER;
        ln_nbv_count                     NUMBER := 0;
        ln_table_liability_cy_NBV        NUMBER := 0;
        ln_tear_down_count               NUMBER := 0;
        ln_total_net_liability           NUMBER := 0;
    BEGIN
        -- Query to fetch the current financial year
        BEGIN
            SELECT period_name, period_year
              INTO lv_curr_fin_year, lv_curr_fin_period_year
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_num = 12
                   AND period_year =
                       (SELECT period_year
                          FROM gl_periods
                         WHERE     period_set_name = 'DO_FY_CALENDAR'
                               AND SYSDATE BETWEEN start_date AND end_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_curr_fin_year          := NULL;
                lv_curr_fin_period_year   := NULL;
        END;

        IF pv_financial_year = lv_curr_fin_year OR pv_balance_type = 'MTD'
        THEN
            ln_curr_year_count   := 1;

            IF pv_balance_type = 'MTD'
            THEN
                lv_curr_fin_period   := pv_mtd_period_name;
            ELSE
                BEGIN
                    SELECT period_name
                      INTO lv_curr_fin_period
                      FROM (  SELECT period_name, 'Draft' program_mode
                                FROM gl_periods gp
                               WHERE     period_set_name = 'DO_FY_CALENDAR'
                                     AND period_year =
                                         (SELECT period_year
                                            FROM gl_periods
                                           WHERE     period_set_name =
                                                     'DO_FY_CALENDAR'
                                                 AND SYSDATE BETWEEN start_date
                                                                 AND end_date)
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM gl_period_statuses gps
                                               WHERE     gps.period_name =
                                                         gp.period_name
                                                     AND closing_status IN
                                                             ('F', 'N', 'O')
                                                     AND application_id = 101
                                                     AND ledger_id = 2036)
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM xxdo.xxd_fa_aro_ptd_values_t a
                                               WHERE a.pv_financial_year =
                                                     gp.period_name)
                            ORDER BY period_num)
                     WHERE ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_curr_fin_period   := NULL;
                END;
            END IF;
        ELSE
            ln_curr_year_count   := 0;
        END IF;

        IF ln_curr_year_count = 1
        THEN
            lv_financial_year_rep   := lv_curr_fin_period;
        ELSE
            lv_financial_year_rep   := pv_financial_year;
        END IF;

        -- Query to fetch the current financial year date and last financial year date

        BEGIN
            SELECT TO_CHAR (end_date, 'MM/DD/YYYY'), TO_CHAR (year_start_date - 1, 'MM/DD/YYYY'), TO_CHAR (SYSDATE, 'DD-MON-yyyy')
              INTO lv_current_fy, lv_last_fy, lv_sysdate
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_name = lv_financial_year_rep;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_current_fy   := NULL;
                lv_last_fy      := NULL;
        END;

        -- query to get ledger_id

        BEGIN
            SELECT gcc.segment1
              INTO ln_book_company
              FROM fa_book_controls fbc, gl_code_combinations gcc
             WHERE     1 = 1
                   AND gcc.code_combination_id =
                       fbc.flexbuilder_defaults_ccid
                   AND book_type_code = pv_asset_book;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_book_company   := NULL;
            WHEN OTHERS
            THEN
                ln_book_company   := NULL;
        END;

        -- load tear down data

        -- load_tear_down_data(ln_book_company);
        ln_tear_down_count   := 0;

        FOR i IN get_aro_records
        LOOP
            -- query to get start period and end period
            BEGIN
                SELECT gp.period_num, gp.period_year
                  INTO ln_asset_start_per_num, ln_asset_start_per_year
                  FROM fa_books fab, gl_periods gp
                 WHERE     fab.book_type_code = i.book_type_code
                       AND fab.date_ineffective IS NULL
                       AND fab.asset_id = i.asset_id
                       AND date_placed_in_service BETWEEN start_date
                                                      AND end_date
                       AND period_set_name = 'DO_FY_CALENDAR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_asset_start_per_num    := NULL;
                    ln_asset_start_per_year   := NULL;
            END;

            -- query to fetch current sysdate financial period

            BEGIN
                SELECT gp.period_name
                  INTO current_yr_end_period
                  FROM gl_periods gp
                 WHERE     period_set_name = 'DO_FY_CALENDAR'
                       AND period_num = 12
                       AND period_year =
                           (SELECT period_year
                              FROM gl_periods
                             WHERE     SYSDATE BETWEEN start_date
                                                   AND end_date
                                   AND period_set_name = 'DO_FY_CALENDAR');
            EXCEPTION
                WHEN OTHERS
                THEN
                    current_yr_end_period   := NULL;
            END;

            --

            BEGIN
                SELECT gp.period_num, gp.period_year
                  INTO curr_yr_period_num, curr_yr_period_year
                  FROM gl_periods gp
                 WHERE     1 = 1
                       AND SYSDATE BETWEEN start_date AND end_date
                       AND period_set_name = 'DO_FY_CALENDAR';
            EXCEPTION
                WHEN OTHERS
                THEN
                    curr_yr_period_num    := NULL;
                    curr_yr_period_year   := NULL;
            END;

            IF NVL (i.current_yr, 0) = 1
            THEN                           -- asset placed in report runnig yr
                ln_period_num_start   := ln_asset_start_per_num;
                ln_period_year        := i.period_year;

                IF lv_financial_year_rep = current_yr_end_period
                THEN
                    ln_period_num_end   := curr_yr_period_num;
                ELSE
                    ln_period_num_end   := 12;
                END IF;
            ELSE
                ln_period_num_start   := 1;
                ln_period_year        := i.period_year;

                IF lv_financial_year_rep = current_yr_end_period
                THEN
                    ln_period_num_end   := curr_yr_period_num;
                ELSE
                    ln_period_num_end   := 12;
                END IF;
            END IF;

            --END LOOP;

            BEGIN
                SELECT period_counter
                  INTO ln_parameter_period_counter
                  FROM fa_deprn_periods
                 WHERE     period_name = lv_financial_year_rep
                       AND book_type_code = i.book_type_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_parameter_period_counter   := NULL;
            END;

            -- query to check year start date period counter

            BEGIN
                SELECT period_counter
                  INTO ln_liab_counter
                  FROM fa_deprn_periods a
                 WHERE     i.year_start_date BETWEEN calendar_period_open_date
                                                 AND calendar_period_close_date
                       AND book_type_code = i.book_type_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_liab_counter   := NULL;
            END;

            --- showkath
            -- Query to check Adjustment exist or not

            BEGIN
                  SELECT fth.transaction_type_code, COUNT (fa.asset_id)
                    INTO lv_lia_transaction_type_code, ln_liab_count
                    FROM fa_transaction_headers fth, fa_adjustments fa
                   WHERE     fth.transaction_header_id =
                             fa.transaction_header_id
                         AND fth.transaction_type_code IN ('ADJUSTMENT')
                         AND fth.asset_id = i.asset_id
                         AND fa.period_counter_adjusted <= ln_liab_counter
                GROUP BY fth.transaction_type_code;

                IF i.asset_date_retired IS NULL
                THEN
                    lv_adj_lib   := 'A';
                ELSE
                    lv_adj_lib   := 'C';
                END IF;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    -- check the adjustment overall
                    BEGIN
                          SELECT fth.transaction_type_code, COUNT (fa.asset_id)
                            INTO lv_lia_transaction_type_code, ln_liab_count
                            FROM fa_transaction_headers fth, fa_adjustments fa
                           WHERE     fth.transaction_header_id =
                                     fa.transaction_header_id
                                 AND fth.transaction_type_code IN
                                         ('ADJUSTMENT')
                                 AND fth.asset_id = i.asset_id
                        --AND fa.period_counter_adjusted <= ln_parameter_period_counter
                        GROUP BY fth.transaction_type_code;

                        IF i.asset_date_retired IS NULL
                        THEN
                            lv_adj_lib   := 'B';
                        ELSE
                            lv_adj_lib   := 'D';
                        END IF;
                    --

                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_lia_transaction_type_code   := NULL;
                            ln_liab_count                  := 0;
                        WHEN OTHERS
                        THEN
                            lv_lia_transaction_type_code   := NULL;
                            ln_liab_count                  := 0;
                    END;
                WHEN OTHERS
                THEN
                    lv_transaction_type_code   := NULL;
                    ln_adj_count               := 0;
            END;

            -- showkath

            -- Query to check Adjustment exist or not

            BEGIN
                  SELECT fth.transaction_type_code, COUNT (fa.asset_id)
                    INTO lv_transaction_type_code, ln_adj_count
                    FROM fa_transaction_headers fth, fa_adjustments fa
                   WHERE     fth.transaction_header_id =
                             fa.transaction_header_id
                         AND fth.transaction_type_code IN ('ADJUSTMENT')
                         AND fth.asset_id = i.asset_id
                         AND fa.period_counter_adjusted <=
                             ln_parameter_period_counter
                GROUP BY fth.transaction_type_code;

                lv_adj   := 'A';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    -- check the adjustment overall
                    BEGIN
                          SELECT fth.transaction_type_code, COUNT (fa.asset_id)
                            INTO lv_transaction_type_code, ln_adj_count
                            FROM fa_transaction_headers fth, fa_adjustments fa
                           WHERE     fth.transaction_header_id =
                                     fa.transaction_header_id
                                 AND fth.transaction_type_code IN
                                         ('ADJUSTMENT')
                                 AND fth.asset_id = i.asset_id
                        --AND fa.period_counter_adjusted <= ln_parameter_period_counter
                        GROUP BY fth.transaction_type_code;

                        lv_adj   := 'B';
                    --
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_transaction_type_code   := NULL;
                            ln_adj_count               := 0;
                        WHEN OTHERS
                        THEN
                            lv_transaction_type_code   := NULL;
                            ln_adj_count               := 0;
                    END;
                --
                WHEN OTHERS
                THEN
                    lv_transaction_type_code   := NULL;
                    ln_adj_count               := 0;
            END;

            IF NVL (ln_adj_count, 0) > 0 AND lv_adj = 'A'
            THEN
                calculate_per_month_aro (i.asset_id,
                                         i.book_type_code,
                                         i.total_target_aro,
                                         i.year_end_date,
                                         ln_parameter_period_counter,
                                         i.extra_months_after);
            ELSIF NVL (ln_adj_count, 0) > 0 AND lv_adj = 'B'
            THEN
                calculate_per_month_aro_b (i.asset_id,
                                           i.book_type_code,
                                           i.total_target_aro,
                                           i.year_end_date,
                                           ln_parameter_period_counter,
                                           i.extra_months_after);
            END IF;

            IF NVL (ln_liab_counter, 0) > 0 AND lv_adj_lib = 'A'
            THEN
                ln_tot_liab_ly   :=
                    calculate_adj_total_lib_ly (i.asset_id, i.book_type_code, i.total_target_aro, i.year_start_date, ln_liab_counter, i.extra_months_after
                                                , i.current_cost);
            ELSIF NVL (ln_liab_counter, 0) > 0 AND lv_adj_lib = 'B'
            THEN
                ln_tot_liab_ly   :=
                    calculate_adj_total_lib_ly_b (i.asset_id, i.book_type_code, i.total_target_aro, i.year_start_date, ln_liab_counter, i.extra_months_after
                                                  , i.current_cost);
            ELSIF NVL (ln_liab_counter, 0) > 0 AND lv_adj_lib = 'C'
            THEN
                ln_tot_liab_ly   :=
                    calculate_adj_total_lib_ly_ret (i.asset_id, i.book_type_code, i.total_target_aro, i.year_start_date, ln_liab_counter, i.extra_months_after
                                                    , i.current_cost);
            ELSIF NVL (ln_liab_counter, 0) > 0 AND lv_adj_lib = 'D'
            THEN
                ln_tot_liab_ly   :=
                    calculate_adj_total_lib_ly_b_ret (i.asset_id, i.book_type_code, i.total_target_aro, i.year_start_date, ln_liab_counter, i.extra_months_after
                                                      , i.current_cost);
            END IF;

            -- query to get ledger_id

            BEGIN
                SELECT set_of_books_id
                  INTO ln_ledger_id
                  FROM fa_book_controls fbc, gl_code_combinations gcc
                 WHERE     1 = 1
                       AND gcc.code_combination_id =
                           fbc.flexbuilder_defaults_ccid
                       AND book_type_code = pv_asset_book;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_ledger_id   := 2036;
            END;

            -- function to get cost center

            ln_cost_center               := get_cost_center (i.asset_id, ln_ledger_id);
            ln_nbv_count                 := 0;
            ln_cursor_count              := 0;
            ln_accertion_addition_ytd    := 0;
            ln_ptd_tot_liability_table   := 0;
            ln_gain_or_loss_count        := 0;
            ln_gain_or_loss              := 0;
            ln_tot_liability_cy          := NULL;
            ln_tear_down_amount          := NULL;

            FOR j
                IN qtd_balance_periods (ln_period_year,
                                        ln_period_num_start,
                                        ln_period_num_end)
            LOOP
                -- load tear down data one time
                ln_tear_down_count   := ln_tear_down_count + 1;

                IF ln_tear_down_count = 1
                THEN
                    load_tear_down_data (ln_book_company,
                                         j.start_date,
                                         j.end_date);
                END IF;

                -- query to check net book value of asset
                ln_cursor_count      := ln_cursor_count + 1;

                BEGIN
                    SELECT MIN (fdp.period_name), MIN (fdp.period_counter)
                      INTO lv_nbv_period, ln_min_period_counter
                      FROM fa_deprn_detail fdd, fa_deprn_periods fdp
                     WHERE     fdd.period_counter = fdp.period_counter
                           AND fdd.asset_id = i.asset_id
                           AND fdp.book_type_code = i.book_type_code;

                    fnd_file.put_line (fnd_file.LOG,
                                       'lv_nbv_period:' || lv_nbv_period);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'ln_min_period_counter:' || ln_min_period_counter);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_nbv_period           := NULL;
                        ln_min_period_counter   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'In exception of lv_nbv_period:' || lv_nbv_period);
                END;

                BEGIN
                    SELECT DISTINCT period_counter
                      INTO ln_fin_period_counter
                      FROM fa_deprn_periods
                     WHERE period_name = j.period_name;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'ln_fin_period_counter:' || ln_fin_period_counter);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_fin_period_counter   := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'In Exception ln_fin_period_counter:'
                            || ln_fin_period_counter);
                END;

                --  IF pv_financial_year < lv_nbv_period THEN

                IF NVL (ln_fin_period_counter, 0) <
                   NVL (ln_min_period_counter, 0)
                THEN
                    ln_nbv   := 1;
                ELSE
                    BEGIN
                        SELECT (fb.original_cost - NVL (fdd.deprn_reserve, 0)) net_book_value
                          INTO ln_nbv
                          FROM fa_deprn_detail fdd, fa_distribution_history fdhi, fa_books fb
                         WHERE     fdd.asset_id = i.asset_id
                               AND fb.book_type_code = i.book_type_code
                               AND fb.asset_id = fdd.asset_id
                               AND deprn_amount <> 0
                               AND fdd.period_counter =
                                   (SELECT DISTINCT (fddi.period_counter)
                                      FROM fa_deprn_detail fddi, fa_deprn_periods fdp
                                     WHERE     fddi.asset_id = fdd.asset_id
                                           -- AND fddi.distribution_id = fdd.distribution_id
                                           --AND fddi.distribution_id = fdhi.distribution_id
                                           AND fdp.period_counter =
                                               fddi.period_counter
                                           AND fdp.period_name =
                                               j.period_name --pv_financial_year
                                           AND fdp.book_type_code =
                                               i.book_type_code)
                               AND fdd.distribution_id = fdhi.distribution_id
                               AND fb.date_ineffective IS NULL
                               AND ROWNUM = 1;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            SELECT (fb.original_cost - NVL (fdd.deprn_reserve, 0)) net_book_value
                              INTO ln_nbv
                              FROM fa_deprn_detail fdd, fa_distribution_history fdhi, fa_books fb
                             WHERE     fdd.asset_id = i.asset_id
                                   AND fb.book_type_code = i.book_type_code
                                   AND fb.asset_id = fdd.asset_id
                                   --AND deprn_amount <>0
                                   AND period_counter =
                                       (SELECT MAX (period_counter)
                                          FROM fa_deprn_detail fddi
                                         WHERE asset_id = fdd.asset_id--  AND fddi.distribution_id = fdd.distribution_id
                                                                      --  AND fddi.distribution_id = fdhi.distribution_id
                                                                      )
                                   AND fdd.distribution_id =
                                       fdhi.distribution_id
                                   AND ROWNUM = 1
                                   AND fb.date_ineffective IS NULL;
                        WHEN OTHERS
                        THEN
                            ln_nbv   := 0;
                    END;
                END IF;

                BEGIN
                    SELECT period_name, period_counter, period_counter + NVL (i.extra_months_after, 0)
                      INTO max_nbv_period, max_nbv_period_counter, max_nbv_exp_period_counter
                      FROM fa_deprn_periods
                     WHERE     period_counter =
                               (SELECT MAX (fdd.period_counter)
                                  FROM fa_deprn_detail fdd
                                 WHERE     1 = 1
                                       AND fdd.asset_id = i.asset_id
                                       AND fdd.book_type_code =
                                           i.book_type_code
                                       AND deprn_reserve <> 0               --
                                                             )
                           AND book_type_code = i.book_type_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        max_nbv_period               := NULL;
                        max_nbv_period_counter       := NULL;
                        max_nbv_exp_period_counter   := NULL;
                END;

                IF j.period_counter >
                   max_nbv_period_counter + NVL (i.extra_months_after, 0)
                THEN                                               -- showkath
                    ln_nbv   := 0;
                END IF;

                IF     NVL (i.extra_months_after, 0) <> 0
                   AND j.period_counter = max_nbv_exp_period_counter
                THEN
                    ln_nbv   := 1;
                END IF;

                IF     ln_nbv = 0
                   AND j.period_counter <> NVL (max_nbv_period_counter, 0)
                THEN
                    ln_nbv_count                  := ln_nbv_count + 1;
                    ln_asset_cost_before_adj      := i.pv_aro_at_establishment;
                    -- ln_ptd_tot_liability_ly := i.total_target_aro;
                    ln_accertion_addition_table   := 0;
                    ln_accertion_addition         := 0;
                    ln_accertion_addition_ytd     :=
                        ln_accertion_addition_ytd + 0;

                    -- query to get the previos period closing balance
                    BEGIN
                        SELECT total_liability_cy
                          INTO ln_table_liability_cy_NBV
                          FROM xxdo.xxd_fa_aro_ptd_values_t
                         WHERE     asset_number = i.asset_number
                               AND period_counter = j.period_counter - 1;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_table_liability_cy_NBV   := NULL;
                    END;

                    --IF ln_nbv_count = 1 THEN
                    ln_ptd_tot_liability_ly       :=
                        NVL (ln_tot_liability_cy, i.total_target_aro); --checksh

                    IF pv_balance_type = 'MTD'
                    THEN
                        ln_ptd_tot_liability_table   :=
                            NVL (ln_table_liability_cy_NBV,
                                 i.total_target_aro);
                    ELSE
                        ln_ptd_tot_liability_table   :=
                            NVL (ln_tot_liability_cy, i.total_target_aro);
                    END IF;

                    /* ELSE
         ln_ptd_tot_liability_ly:= i.total_target_aro;
                        ln_ptd_tot_liability_table := i.total_target_aro;
         END IF;*/
                    -- END IF;
                    -- END IF;

                    --
                    IF ln_cursor_count = 1
                    THEN
                        IF NVL (i.current_yr, 0) = 1
                        THEN
                            ln_ytd_tot_liability_ly   := NULL;
                        ELSE
                            ln_ytd_tot_liability_ly   := i.total_target_aro;
                        END IF;
                    END IF;

                    ln_deletions                  := 0;

                    ln_tear_down_amount           :=
                        get_tear_down (i.asset_number,
                                       ln_cost_center,
                                       ln_book_company);



                    IF ln_cursor_count = 1
                    THEN
                        ln_tot_liability_cy   :=
                            ROUND (
                                (NVL (ln_ptd_tot_liability_table, ln_ptd_tot_liability_ly) + NVL (i.pv_aro_addition, 0) + NVL (ln_accertion_addition, 0)),
                                2);
                    ELSE
                        ln_tot_liability_cy   :=
                            ROUND (
                                (NVL (ln_ptd_tot_liability_table, ln_ptd_tot_liability_ly) + NVL (ln_accertion_addition, 0)),
                                2);
                    END IF;

                    IF i.asset_date_retired IS NOT NULL
                    THEN
                        ln_gain_or_loss   :=
                              ln_tot_liability_cy
                            - NVL (ln_tear_down_amount, 0);
                    ELSE
                        ln_gain_or_loss   := NULL;
                    END IF;


                    ln_total_net_liability        :=
                          NVL (ln_tot_liability_cy, 0)
                        - NVL (ln_gain_or_loss, 0)
                        - NVL (ln_tear_down_amount, 0);
                ELSE
                    -- adjustment changes
                    -- check wheather the adjument was made for this asset
                    IF     NVL (ln_adj_count, 0) > 0
                       AND NVL (i.total_target_aro, 0) <> 0
                    THEN
                        IF ln_cursor_count = 1
                        THEN
                            IF NVL (i.current_yr, 0) = 1
                            THEN
                                ln_ptd_tot_liability_ly      := NULL;
                                ln_ptd_tot_liability_table   := NULL;
                            ELSE
                                ln_ptd_tot_liability_table   :=
                                    get_liab_from_table (i.asset_number,
                                                         i.period_year,
                                                         j.period_counter);
                                ln_ptd_tot_liability_ly   :=
                                    ROUND (ln_tot_liab_ly, 2);
                            END IF;
                        ELSE
                            ln_ptd_tot_liability_ly   := ln_tot_liability_cy;
                            ln_ptd_tot_liability_table   :=
                                ln_tot_liability_cy;
                        END IF;

                        IF ln_cursor_count = 1
                        THEN
                            ln_months_pre   := i.months_pre;
                        ELSE
                            ln_months_pre   := ln_months_pre + 1;
                        END IF;

                        -- ln_accertion_addition

                        ln_accertion_addition_table   :=
                            ROUND (
                                calc_per_mon_aro_tgt_cnged (
                                    i.asset_id,
                                    i.asset_number,
                                    i.book_type_code,
                                    i.total_target_aro,
                                    i.year_end_date,
                                    ln_parameter_period_counter,
                                    i.extra_months_after,
                                    j.period_counter,
                                    i.current_cost,
                                    ln_months_pre,
                                    ln_ptd_tot_liability_table),
                                2);

                        BEGIN
                            SELECT ROUND (per_month_acc, 2)
                              INTO ln_accertion_addition
                              FROM xxdo.xxd_fa_adjustment_data_t
                             WHERE     j.period_counter BETWEEN adj_start_counter
                                                            AND adj_end_counter
                                   AND asset_id = i.asset_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_accertion_addition   := NULL;
                        END;

                        IF i.asset_date_retired IS NOT NULL
                        THEN
                            IF j.period_counter > i.retirement_counter
                            THEN
                                ln_accertion_addition         := 0;
                                ln_accertion_addition_table   := 0;
                            END IF;
                        END IF;

                        IF ln_cursor_count = 1
                        THEN
                            ln_accertion_addition_ytd   :=
                                NVL (ln_accertion_addition, 0);

                            IF NVL (i.current_yr, 0) = 1
                            THEN
                                ln_ytd_tot_liability_ly      := NULL;
                                ln_ytd_tot_liability_table   := NULL;
                            ELSE
                                ln_ytd_tot_liability_ly   :=
                                    ln_ptd_tot_liability_ly;
                                ln_ytd_tot_liability_table   :=
                                    ln_ptd_tot_liability_table;
                            END IF;
                        ELSE
                            ln_accertion_addition_ytd   :=
                                  ln_accertion_addition_ytd
                                + NVL (ln_accertion_addition, 0);
                        END IF;

                        ln_tear_down_amount   :=
                            get_tear_down (i.asset_number,
                                           ln_cost_center,
                                           ln_book_company);
                    ELSE                              -- no adjustment changes
                        ln_ptd_tot_liability_ly   := 0;

                        IF ln_cursor_count = 1
                        THEN
                            IF NVL (i.current_yr, 0) = 1
                            THEN
                                ln_ptd_tot_liability_ly      := NULL;
                                ln_ptd_tot_liability_table   := NULL;
                            ELSE
                                ln_ptd_tot_liability_table   :=
                                    get_liab_from_table (i.asset_number,
                                                         i.period_year,
                                                         j.period_counter);
                                ln_ptd_tot_liability_ly   :=
                                    ROUND (
                                          i.pv_aro_at_establishment
                                        + (i.months_pre * i.per_month_cost),
                                        2);
                            END IF;
                        ELSE
                            ln_ptd_tot_liability_ly   := ln_tot_liability_cy;
                            ln_ptd_tot_liability_table   :=
                                ln_tot_liability_cy;
                        END IF;

                        IF ln_cursor_count = 1
                        THEN
                            ln_months_pre   := i.months_pre;
                        ELSE
                            ln_months_pre   := ln_months_pre + 1;
                        END IF;

                        ln_accertion_addition_table   :=
                            ROUND (
                                calc_per_mon_aro_for_noadj (i.asset_id, i.asset_number, i.book_type_code, i.total_target_aro, i.year_end_date, ln_parameter_period_counter, i.extra_months_after, j.period_counter, i.current_cost
                                                            , ln_months_pre),
                                2);

                        ln_accertion_addition     := i.per_month_cost;

                        IF i.asset_date_retired IS NOT NULL
                        THEN
                            IF j.period_counter > i.retirement_counter
                            THEN
                                ln_accertion_addition   := 0;
                            END IF;
                        END IF;

                        IF ln_cursor_count = 1
                        THEN
                            ln_accertion_addition_ytd   :=
                                NVL (ln_accertion_addition, 0);

                            IF NVL (i.current_yr, 0) = 1
                            THEN
                                ln_ytd_tot_liability_ly      := NULL;
                                ln_ytd_tot_liability_table   := NULL;
                            ELSE
                                ln_ytd_tot_liability_ly   :=
                                    ln_ptd_tot_liability_ly;
                                ln_ytd_tot_liability_table   :=
                                    ln_ptd_tot_liability_table;
                            END IF;
                        ELSE
                            ln_accertion_addition_ytd   :=
                                ROUND (
                                      ln_accertion_addition_ytd
                                    + ln_accertion_addition,
                                    2);
                        END IF;

                        ln_tear_down_amount       :=
                            get_tear_down (i.asset_number,
                                           ln_cost_center,
                                           ln_book_company);
                    END IF;

                    IF ln_cursor_count = 1
                    THEN
                        ln_tot_liability_cy   :=
                            ROUND (
                                (NVL (ln_ptd_tot_liability_table, NVL (ln_ptd_tot_liability_ly, 0)) + NVL (i.pv_aro_addition, 0) + NVL (ln_accertion_addition_table, NVL (ln_accertion_addition, 0))),
                                2);
                    ELSE
                        ln_tot_liability_cy   :=
                            ROUND (
                                (NVL (ln_ptd_tot_liability_table, NVL (ln_ptd_tot_liability_ly, 0)) + NVL (ln_accertion_addition_table, NVL (ln_accertion_addition, 0))),
                                2);
                    END IF;

                    -- adjustment changes end


                    NULL;
                END IF;

                IF i.asset_date_retired IS NOT NULL
                THEN
                    ln_gain_or_loss_count   := ln_gain_or_loss_count + 1;

                    IF ln_gain_or_loss_count = 1
                    THEN
                        ln_gain_or_loss   :=
                              ln_tot_liability_cy
                            - NVL (ln_tear_down_amount, 0);
                    ELSE
                        ln_gain_or_loss   := NULL;
                    END IF;
                END IF;

                ln_total_net_liability   :=
                      NVL (ln_tot_liability_cy, 0)
                    - NVL (ln_gain_or_loss, 0)
                    - NVL (ln_tear_down_amount, 0);

                -- Query to fetch the current financial year

                IF pv_balance_type = 'MTD'
                THEN
                    BEGIN
                        SELECT period_name
                          INTO lv_financial_year
                          FROM gl_periods
                         WHERE     period_set_name = 'DO_FY_CALENDAR'
                               AND period_num = 12
                               AND period_year =
                                   (SELECT period_year
                                      FROM gl_periods
                                     WHERE     period_set_name =
                                               'DO_FY_CALENDAR'
                                           AND period_name =
                                               pv_mtd_period_name--AND SYSDATE BETWEEN start_date AND end_date
                                                                 );
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lv_financial_year   := NULL;
                    END;
                END IF;

                -- Values for insertion

                IF pv_balance_type IN ('PTD', 'MTD')
                THEN
                    BEGIN
                        INSERT INTO xxdo.xxd_fa_aro_obli_report_gt
                                 VALUES (
                                            i.asset_number,
                                            i.asset_description,
                                            'PTD' || '-' || j.end_date,
                                            ln_cost_center,
                                            i.pv_aro_at_establishment,     --,
                                            NVL (ln_ptd_tot_liability_table,
                                                 ln_ptd_tot_liability_ly),
                                            CASE
                                                WHEN ln_cursor_count = 1
                                                THEN
                                                    i.pv_aro_addition
                                                ELSE
                                                    NULL
                                            END,
                                            --i.pv_aro_addition,--
                                            NVL (ln_accertion_addition_table,
                                                 ln_accertion_addition),
                                            ln_tear_down_amount,            --
                                            ln_gain_or_loss,                --
                                            ln_tot_liability_cy,
                                            i.total_target_aro,
                                            i.asset_date_retired,
                                            ln_tear_down_amount,
                                            lv_last_fy,                   -- ,
                                            lv_current_fy,
                                            j.period_num,
                                            i.book_type_code,
                                            j.period_name,
                                            gn_login_id,
                                            SYSDATE,
                                            gn_login_id,
                                            SYSDATE,
                                            gn_request_id,
                                            pv_program_mode,
                                            sent_to_blackline,
                                            NULL,
                                            CASE
                                                WHEN ln_total_net_liability <=
                                                     0
                                                THEN
                                                    0
                                                ELSE
                                                    ln_total_net_liability
                                            END);

                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;

                    IF pv_program_mode IN ('Final', 'Oveeride')
                    THEN
                        -- query to get the period is exist or not
                        BEGIN
                            SELECT COUNT (1)
                              INTO ln_period_exist_count
                              FROM xxdo.xxd_fa_aro_ptd_values_t custom
                             WHERE     period_name = j.period_name
                                   AND asset_number = i.asset_number
                                   AND custom.pv_financial_year =
                                       lv_financial_year_rep;
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_period_exist_count   := NULL;
                            WHEN OTHERS
                            THEN
                                ln_period_exist_count   := NULL;
                        END;

                        -- insert the records in main table to use to post the journals

                        IF NVL (ln_period_exist_count, 0) > 0
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Data is already exist in custom table for the Financial year:'
                                || pv_financial_year);
                        ELSE
                            BEGIN
                                INSERT INTO xxdo.xxd_fa_aro_ptd_values_t
                                         VALUES (
                                                    i.asset_number,
                                                    i.asset_description,
                                                       'PTD'
                                                    || '-'
                                                    || j.end_date,
                                                    ln_cost_center,
                                                    i.pv_aro_at_establishment,
                                                    NVL (
                                                        ln_ptd_tot_liability_table,
                                                        ln_ptd_tot_liability_ly), -- showkath
                                                    CASE
                                                        WHEN ln_cursor_count =
                                                             1
                                                        THEN
                                                            i.pv_aro_addition
                                                        ELSE
                                                            NULL
                                                    END,
                                                    --i.pv_aro_addition,--
                                                    NVL (
                                                        ln_accertion_addition_table,
                                                        ln_accertion_addition),
                                                    ln_tear_down_amount,    --
                                                    ln_gain_or_loss,        --
                                                    ln_tot_liability_cy,
                                                    i.total_target_aro,
                                                    i.asset_date_retired,
                                                    ln_tear_down_amount,
                                                    j.period_num,
                                                    j.period_year,
                                                    NVL (pv_financial_year,
                                                         lv_financial_year),
                                                    i.book_type_code,
                                                    j.period_name,
                                                    j.period_counter,
                                                    pv_region,
                                                    gn_login_id,
                                                    SYSDATE,
                                                    gn_login_id,
                                                    SYSDATE,
                                                    gn_request_id,
                                                    pv_program_mode,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    NULL,
                                                    sent_to_blackline,
                                                    NULL,
                                                    CASE
                                                        WHEN ln_total_net_liability <=
                                                             0
                                                        THEN
                                                            0
                                                        ELSE
                                                            ln_total_net_liability
                                                    END);

                                COMMIT;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    NULL;
                            END;                                            --
                        END IF;          --IF NVL(ln_period_exist_count,0) > 0
                    END IF;                --IF pv_program_mode = 'Final' THEN
                END IF;                                     -- PTD changes end
            END LOOP;                                              -- PTD LOOP

            -- YTD changes

            IF pv_balance_type = 'YTD'
            THEN
                IF NVL (i.current_yr, 0) = 1
                THEN
                    ln_tot_liability_cy   :=
                        ROUND (
                            (NVL (ln_ytd_tot_liability_table, NVL (ln_ytd_tot_liability_ly, 0)) + NVL (i.pv_aro_addition, 0) + NVL (ln_accertion_addition_ytd, 0)),
                            2);
                ELSE
                    ln_tot_liability_cy   :=
                        ROUND (
                            (NVL (ln_ytd_tot_liability_table, NVL (ln_ytd_tot_liability_ly, 0)) + NVL (ln_accertion_addition_ytd, 0)),
                            2);
                END IF;

                ln_tear_down_amount   :=
                    get_tear_down (i.asset_number,
                                   ln_cost_center,
                                   ln_book_company);

                BEGIN
                    INSERT INTO xxdo.xxd_fa_aro_obli_report_gt
                             VALUES (
                                        i.asset_number,
                                        i.asset_description,
                                        i.accretion_balance_type,
                                        ln_cost_center,
                                        i.pv_aro_at_establishment,
                                        NVL (ln_ytd_tot_liability_table,
                                             ln_ytd_tot_liability_ly), -- showkath
                                        CASE
                                            WHEN NVL (i.current_yr, 0) = 1
                                            THEN
                                                i.pv_aro_addition
                                            ELSE
                                                NULL
                                        END,
                                        --i.pv_aro_addition,--
                                        ln_accertion_addition_ytd,
                                        ln_tear_down_amount,                --
                                        NULL,                               --
                                        ln_tot_liability_cy,
                                        i.total_target_aro,
                                        i.asset_date_retired,
                                        ln_tear_down_amount,
                                        lv_last_fy,             -- , -- ,    ,
                                        lv_current_fy,
                                        i.period_num,
                                        i.book_type_code,
                                        i.period_name,
                                        gn_login_id,
                                        SYSDATE,
                                        gn_login_id,
                                        SYSDATE,
                                        gn_request_id,
                                        pv_program_mode,
                                        sent_to_blackline,
                                        NULL,
                                        CASE
                                            WHEN ln_total_net_liability <= 0
                                            THEN
                                                0
                                            ELSE
                                                ln_total_net_liability
                                        END);

                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        NULL;
                END;
            END IF;
        END LOOP;
    END generate_report;

    -- ======================================================================================
    -- This procedure is used to insert the eleigible records in custom table
    -- ======================================================================================

    PROCEDURE insert_eligible_records (pv_program_mode IN VARCHAR2, pv_region IN VARCHAR2, pv_asset_book IN VARCHAR2, pv_financial_year IN VARCHAR2, pv_balance_type IN VARCHAR2, sent_to_blackline IN VARCHAR2
                                       , pv_mtd_period_name IN VARCHAR2)
    AS
        CURSOR fa_eligible_aro_asset_cur (p_curr_period         IN VARCHAR2,
                                          p_curr_period_count   IN NUMBER)
        IS
            SELECT ad.asset_number,
                   ad.asset_id,
                   fc.segment1
                       major_category,                                      --
                   ad.description
                       asset_description,
                   fb.book_type_code,
                   fb.cost
                       current_cost,
                   fb.life_in_months
                       asset_life,
                   ROUND (fb.original_cost, 2)
                       original_cost,
                   ROUND (fb.cost, 2)
                       pv_aro_at_establishment,
                   ROUND ((ad.attribute4 - fb.cost) / fb.life_in_months, 2)
                       per_month_cost,
                   CEIL (
                       (SELECT MONTHS_BETWEEN (year_start_date, prorate_date) FROM DUAL))
                       months_pre,
                   CEIL (
                       (SELECT MONTHS_BETWEEN (year_end_date, prorate_date) FROM DUAL))
                       months_curr,
                   (SELECT ROUND (fab.cost, 2)
                      FROM fa_books fab
                     WHERE     fab.book_type_code = fb.book_type_code
                           AND fab.date_ineffective IS NULL
                           AND fab.asset_id = ad.asset_id
                           AND date_placed_in_service BETWEEN year_start_date
                                                          AND year_end_date)
                       pv_aro_addition,
                   (pv_balance_type) || '-' || year_end_date
                       accretion_balance_type,
                   ad.attribute4
                       total_target_aro,
                   ad.attribute5
                       extra_months_after,
                   date_placed_in_service,
                   fb.prorate_date,
                   (SELECT fa_retrmnt.date_retired
                      FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add
                     WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                           AND fa_add.asset_number = ad.asset_number
                           AND flb.lookup_code =
                               fa_retrmnt.retirement_type_code
                           AND flb.lookup_type = 'RETIREMENT'
                           AND flb.language = 'US')
                       asset_date_retired,
                   gp.year_start_date,
                   gp.year_end_date,
                   gp.period_year,
                   ((SELECT period_num
                       FROM gl_periods
                      WHERE     period_set_name = 'DO_FY_CALENDAR'
                            AND fb.prorate_date BETWEEN start_date
                                                    AND end_date))
                       period_num,
                   gp.period_name,
                   (SELECT 1
                      FROM fa_books fab
                     WHERE     fab.book_type_code = fb.book_type_code
                           AND fab.date_ineffective IS NULL
                           AND fab.asset_id = ad.asset_id
                           AND date_placed_in_service BETWEEN year_start_date
                                                          AND year_end_date)
                       current_yr,
                   asset_reg.region,
                   asset_reg.book_type_code
                       vs_book_type_code,
                   (SELECT fdp.period_counter
                      FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add,
                           fa_deprn_periods fdp
                     WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                           AND fa_add.asset_number = ad.asset_number
                           AND flb.lookup_code =
                               fa_retrmnt.retirement_type_code
                           AND flb.lookup_type = 'RETIREMENT'
                           AND flb.language = 'US'
                           AND fa_retrmnt.date_retired BETWEEN calendar_period_open_date
                                                           AND calendar_period_close_date
                           AND fdp.book_type_code = fb.book_type_code)
                       retirement_period_counter,
                   (SELECT period_counter
                      FROM fa_deprn_periods
                     WHERE     gp.year_start_date BETWEEN calendar_period_open_date
                                                      AND calendar_period_close_date
                           AND book_type_code = fb.book_type_code)
                       para_period_counter,
                   NULL
                       REINSTATEMENT_count
              FROM fa_additions ad,
                   fa_categories fc,
                   fa_books fb,
                   fa_deprn_periods fdp,
                   (SELECT year_start_date, ADD_MONTHS (year_start_date, 12) - 1 year_end_date, period_name,
                           period_year, period_num
                      FROM gl_periods
                     WHERE 1 = 1 AND period_set_name = 'DO_FY_CALENDAR') gp,
                   xxd_fa_aro_book_region_v asset_reg
             WHERE     1 = 1
                   AND ad.asset_category_id = fc.category_id
                   AND ad.asset_id = fb.asset_id
                   AND fdp.book_type_code = fb.book_type_code
                   AND fb.date_ineffective IS NULL
                   AND gp.period_name = fdp.period_name
                   AND fdp.period_name = pv_financial_year
                   AND (   segment1 = 'ARO'
                        OR EXISTS
                               (SELECT 1
                                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     fvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND fvs.flex_value_set_name =
                                           'DO_ARO_ASSETS'
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y'
                                       AND ffvl.flex_value = ad.asset_number))
                   AND asset_reg.book_type_code(+) = fb.book_type_code
                   AND (region = pv_region AND asset_reg.book_type_code = NVL (pv_asset_book, asset_reg.book_type_code) OR (pv_region = 'ALL' AND 1 = 1))
                   AND prorate_date <= year_end_date
                   AND NOT EXISTS
                           (SELECT 1
                              FROM fa_transaction_headers
                             WHERE     transaction_type_code =
                                       'FULL RETIREMENT'
                                   AND asset_id = ad.asset_id)
                   AND p_curr_period_count = 0
            UNION ALL
            SELECT asset_number, asset_id, major_category,
                   asset_description, book_type_code, current_cost,
                   asset_life, original_cost, pv_aro_at_establishment,
                   per_month_cost, months_pre, months_curr,
                   pv_aro_addition, accretion_balance_type, total_target_aro,
                   extra_months_after, date_placed_in_service, prorate_date,
                   asset_date_retired, year_start_date, year_end_date,
                   period_year, period_num, period_name,
                   current_yr, region, vs_book_type_code,
                   retirement_period_counter, para_period_counter, REINSTATEMENT_count
              FROM (SELECT ad.asset_number,
                           ad.asset_id,
                           fc.segment1
                               major_category,
                           ad.description
                               asset_description,
                           fb.book_type_code,
                           fb.cost
                               current_cost,
                           fb.life_in_months
                               asset_life,
                           ROUND (fb.original_cost, 2)
                               original_cost,
                           ROUND (fb.cost, 2)
                               pv_aro_at_establishment,
                           ROUND (
                               (ad.attribute4 - fb.cost) / fb.life_in_months,
                               2)
                               per_month_cost,
                           CEIL (
                               (SELECT MONTHS_BETWEEN (year_start_date, prorate_date) FROM DUAL))
                               months_pre,
                           CEIL (
                               (SELECT MONTHS_BETWEEN (year_end_date, prorate_date) FROM DUAL))
                               months_curr,
                           (SELECT ROUND (fab.original_cost, 2)
                              FROM fa_books fab
                             WHERE     fab.book_type_code = fb.book_type_code
                                   AND fab.date_ineffective IS NULL
                                   AND fab.asset_id = ad.asset_id
                                   AND date_placed_in_service BETWEEN year_start_date
                                                                  AND year_end_date)
                               pv_aro_addition,
                           (pv_balance_type) || '-' || year_end_date
                               accretion_balance_type,
                           ad.attribute4
                               total_target_aro,
                           ad.attribute5
                               extra_months_after,
                           date_placed_in_service,
                           fb.prorate_date,
                           (SELECT fa_retrmnt.date_retired
                              FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add
                             WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                                   AND fa_add.asset_number = ad.asset_number
                                   AND flb.lookup_code =
                                       fa_retrmnt.retirement_type_code
                                   AND flb.lookup_type = 'RETIREMENT'
                                   AND flb.language = 'US')
                               asset_date_retired,
                           gp.year_start_date,
                           gp.year_end_date,
                           gp.period_year,
                           ((SELECT period_num
                               FROM gl_periods
                              WHERE     period_set_name = 'DO_FY_CALENDAR'
                                    AND fb.prorate_date BETWEEN start_date
                                                            AND end_date))
                               period_num,
                           gp.period_name,
                           (SELECT 1
                              FROM fa_books fab
                             WHERE     fab.book_type_code = fb.book_type_code
                                   AND fab.date_ineffective IS NULL
                                   AND fab.asset_id = ad.asset_id
                                   AND date_placed_in_service BETWEEN year_start_date
                                                                  AND year_end_date)
                               current_yr,
                           asset_reg.region,
                           asset_reg.book_type_code
                               vs_book_type_code,
                           (SELECT fdp.period_counter
                              FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add,
                                   fa_deprn_periods fdp
                             WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                                   AND fa_add.asset_number = ad.asset_number
                                   AND flb.lookup_code =
                                       fa_retrmnt.retirement_type_code
                                   AND flb.lookup_type = 'RETIREMENT'
                                   AND flb.language = 'US'
                                   AND fa_retrmnt.date_retired BETWEEN calendar_period_open_date
                                                                   AND calendar_period_close_date
                                   AND fdp.book_type_code = fb.book_type_code)
                               retirement_period_counter,
                           (SELECT period_counter
                              FROM fa_deprn_periods
                             WHERE     gp.year_start_date BETWEEN calendar_period_open_date
                                                              AND calendar_period_close_date
                                   AND book_type_code = fb.book_type_code)
                               para_period_counter,
                           (SELECT 1
                              FROM fa_transaction_headers
                             WHERE     transaction_type_code =
                                       'REINSTATEMENT'
                                   AND asset_id = ad.asset_id)
                               REINSTATEMENT_count
                      FROM fa_additions ad,
                           fa_categories fc,
                           fa_books fb,
                           fa_deprn_periods fdp,
                           (SELECT year_start_date, ADD_MONTHS (year_start_date, 12) - 1 year_end_date, period_name,
                                   period_year, period_num
                              FROM gl_periods
                             WHERE     1 = 1
                                   AND period_set_name = 'DO_FY_CALENDAR') gp,
                           xxd_fa_aro_book_region_v asset_reg
                     WHERE     1 = 1
                           AND ad.asset_category_id = fc.category_id
                           AND ad.asset_id = fb.asset_id
                           AND fdp.book_type_code = fb.book_type_code
                           -- AND fb.date_ineffective IS NULL
                           AND gp.period_name = fdp.period_name
                           AND fdp.period_name = pv_financial_year
                           AND (   segment1 = 'ARO'
                                OR EXISTS
                                       (SELECT 1
                                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                         WHERE     fvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND fvs.flex_value_set_name =
                                                   'DO_ARO_ASSETS'
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.start_date_active),
                                                       TRUNC (SYSDATE)) <=
                                                   TRUNC (SYSDATE)
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.end_date_active),
                                                       TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND ffvl.enabled_flag = 'Y'
                                               AND ffvl.flex_value =
                                                   ad.asset_number))
                           AND asset_reg.book_type_code(+) =
                               fb.book_type_code
                           AND (region = pv_region AND asset_reg.book_type_code = NVL (pv_asset_book, asset_reg.book_type_code) OR (pv_region = 'ALL' AND 1 = 1))
                           AND prorate_date <= year_end_date
                           AND transaction_header_id_out IN
                                   (SELECT transaction_header_id
                                      FROM fa_transaction_headers fth
                                     WHERE     transaction_type_code =
                                               'FULL RETIREMENT'
                                           AND fth.asset_id = fb.asset_id)
                           AND EXISTS
                                   (SELECT 1
                                      FROM fa_transaction_headers
                                     WHERE     transaction_type_code =
                                               'FULL RETIREMENT'
                                           AND asset_id = ad.asset_id))
             WHERE     1 = 1
                   AND (retirement_period_counter >= para_period_counter OR REINSTATEMENT_count >= 1)
                   AND p_curr_period_count = 0
            UNION ALL
            SELECT ad.asset_number,
                   ad.asset_id,
                   fc.segment1
                       major_category,                                      --
                   ad.description
                       asset_description,
                   fb.book_type_code,
                   fb.cost
                       current_cost,
                   fb.life_in_months
                       asset_life,
                   ROUND (fb.original_cost, 2)
                       original_cost,
                   ROUND (fb.cost, 2)
                       pv_aro_at_establishment,
                   ROUND ((ad.attribute4 - fb.cost) / fb.life_in_months, 2)
                       per_month_cost,
                   CEIL (
                       (SELECT MONTHS_BETWEEN (calendar_period_open_date, prorate_date) FROM DUAL))
                       months_pre,
                   CEIL (
                       (SELECT MONTHS_BETWEEN (calendar_period_close_date, prorate_date) FROM DUAL))
                       months_curr,
                   (SELECT ROUND (fab.cost, 2)
                      FROM fa_books fab
                     WHERE     fab.book_type_code = fb.book_type_code
                           AND fab.date_ineffective IS NULL
                           AND fab.asset_id = ad.asset_id
                           AND date_placed_in_service BETWEEN calendar_period_open_date
                                                          AND calendar_period_close_date)
                       pv_aro_addition,
                   (pv_balance_type) || '-' || year_end_date
                       accretion_balance_type,
                   ad.attribute4
                       total_target_aro,
                   ad.attribute5
                       extra_months_after,
                   date_placed_in_service,
                   fb.prorate_date,
                   (SELECT fa_retrmnt.date_retired
                      FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add
                     WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                           AND fa_add.asset_number = ad.asset_number
                           AND flb.lookup_code =
                               fa_retrmnt.retirement_type_code
                           AND flb.lookup_type = 'RETIREMENT'
                           AND flb.language = 'US')
                       asset_date_retired,
                   gp.year_start_date,
                   gp.year_end_date,
                   gp.period_year,
                   ((SELECT period_num
                       FROM gl_periods
                      WHERE     period_set_name = 'DO_FY_CALENDAR'
                            AND fb.prorate_date BETWEEN start_date
                                                    AND end_date))
                       period_num,
                   gp.period_name,
                   (SELECT 1
                      FROM fa_books fab
                     WHERE     fab.book_type_code = fb.book_type_code
                           AND fab.date_ineffective IS NULL
                           AND fab.asset_id = ad.asset_id
                           AND date_placed_in_service BETWEEN calendar_period_open_date
                                                          AND calendar_period_close_date)
                       current_yr,                                  -- checksh
                   asset_reg.region,
                   asset_reg.book_type_code
                       vs_book_type_code,
                   (SELECT fdp.period_counter
                      FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add,
                           fa_deprn_periods fdp
                     WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                           AND fa_add.asset_number = ad.asset_number
                           AND flb.lookup_code =
                               fa_retrmnt.retirement_type_code
                           AND flb.lookup_type = 'RETIREMENT'
                           AND flb.language = 'US'
                           AND fa_retrmnt.date_retired BETWEEN calendar_period_open_date
                                                           AND calendar_period_close_date
                           AND fdp.book_type_code = fb.book_type_code)
                       retirement_period_counter,
                   (SELECT period_counter
                      FROM fa_deprn_periods
                     WHERE     gp.year_start_date BETWEEN calendar_period_open_date
                                                      AND calendar_period_close_date
                           AND book_type_code = fb.book_type_code)
                       para_period_counter,
                   NULL
                       REINSTATEMENT_count
              FROM fa_additions ad,
                   fa_categories fc,
                   fa_books fb,
                   fa_deprn_periods fdp,
                   (SELECT year_start_date, ADD_MONTHS (year_start_date, 12) - 1 year_end_date, period_name,
                           period_year, period_num
                      FROM gl_periods
                     WHERE 1 = 1 AND period_set_name = 'DO_FY_CALENDAR') gp,
                   xxd_fa_aro_book_region_v asset_reg
             WHERE     1 = 1
                   AND ad.asset_category_id = fc.category_id
                   AND ad.asset_id = fb.asset_id
                   AND fdp.book_type_code = fb.book_type_code
                   AND fb.date_ineffective IS NULL
                   AND gp.period_name = fdp.period_name
                   AND fdp.period_name = p_curr_period
                   AND (   segment1 = 'ARO'
                        OR EXISTS
                               (SELECT 1
                                  FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                 WHERE     fvs.flex_value_set_id =
                                           ffvl.flex_value_set_id
                                       AND fvs.flex_value_set_name =
                                           'DO_ARO_ASSETS'
                                       AND NVL (
                                               TRUNC (ffvl.start_date_active),
                                               TRUNC (SYSDATE)) <=
                                           TRUNC (SYSDATE)
                                       AND NVL (TRUNC (ffvl.end_date_active),
                                                TRUNC (SYSDATE)) >=
                                           TRUNC (SYSDATE)
                                       AND ffvl.enabled_flag = 'Y'
                                       AND ffvl.flex_value = ad.asset_number))
                   AND asset_reg.book_type_code(+) = fb.book_type_code
                   AND (region = pv_region AND asset_reg.book_type_code = NVL (pv_asset_book, asset_reg.book_type_code) OR (pv_region = 'ALL' AND 1 = 1))
                   AND prorate_date <= calendar_period_close_date
                   AND NOT EXISTS
                           (SELECT 1
                              FROM fa_transaction_headers
                             WHERE     transaction_type_code =
                                       'FULL RETIREMENT'
                                   AND asset_id = ad.asset_id)
                   AND p_curr_period_count = 1
            UNION ALL
            SELECT asset_number, asset_id, major_category,
                   asset_description, book_type_code, current_cost,
                   asset_life, original_cost, pv_aro_at_establishment,
                   per_month_cost, months_pre, months_curr,
                   pv_aro_addition, accretion_balance_type, total_target_aro,
                   extra_months_after, date_placed_in_service, prorate_date,
                   asset_date_retired, year_start_date, year_end_date,
                   period_year, period_num, period_name,
                   current_yr, region, vs_book_type_code,
                   retirement_period_counter, para_period_counter, REINSTATEMENT_count
              FROM (SELECT ad.asset_number,
                           ad.asset_id,
                           fc.segment1
                               major_category,
                           ad.description
                               asset_description,
                           fb.book_type_code,
                           fb.cost
                               current_cost,
                           fb.life_in_months
                               asset_life,
                           ROUND (fb.original_cost, 2)
                               original_cost,
                           ROUND (fb.cost, 2)
                               pv_aro_at_establishment,
                           ROUND (
                               (ad.attribute4 - fb.cost) / fb.life_in_months,
                               2)
                               per_month_cost,
                           CEIL (
                               (SELECT MONTHS_BETWEEN (calendar_period_open_date, prorate_date) FROM DUAL))
                               months_pre,
                           CEIL (
                               (SELECT MONTHS_BETWEEN (calendar_period_close_date, prorate_date) FROM DUAL))
                               months_curr,
                           (SELECT ROUND (fab.original_cost, 2)
                              FROM fa_books fab
                             WHERE     fab.book_type_code = fb.book_type_code
                                   AND fab.date_ineffective IS NULL
                                   AND fab.asset_id = ad.asset_id
                                   AND date_placed_in_service BETWEEN calendar_period_open_date
                                                                  AND calendar_period_close_date)
                               pv_aro_addition,
                           (pv_balance_type) || '-' || year_end_date
                               accretion_balance_type,
                           ad.attribute4
                               total_target_aro,
                           ad.attribute5
                               extra_months_after,
                           date_placed_in_service,
                           fb.prorate_date,
                           (SELECT fa_retrmnt.date_retired
                              FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add
                             WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                                   AND fa_add.asset_number = ad.asset_number
                                   AND flb.lookup_code =
                                       fa_retrmnt.retirement_type_code
                                   AND flb.lookup_type = 'RETIREMENT'
                                   AND flb.language = 'US')
                               asset_date_retired,
                           gp.year_start_date,
                           gp.year_end_date,
                           gp.period_year,
                           ((SELECT period_num
                               FROM gl_periods
                              WHERE     period_set_name = 'DO_FY_CALENDAR'
                                    AND fb.prorate_date BETWEEN start_date
                                                            AND end_date))
                               period_num,
                           gp.period_name,
                           (SELECT 1
                              FROM fa_books fab
                             WHERE     fab.book_type_code = fb.book_type_code
                                   AND fab.date_ineffective IS NULL
                                   AND fab.asset_id = ad.asset_id
                                   AND date_placed_in_service BETWEEN calendar_period_open_date
                                                                  AND calendar_period_close_date)
                               current_yr,
                           asset_reg.region,
                           asset_reg.book_type_code
                               vs_book_type_code,
                           (SELECT fdp.period_counter
                              FROM fa_retirements fa_retrmnt, fa_lookups_tl flb, fa_additions fa_add,
                                   fa_deprn_periods fdp
                             WHERE     fa_retrmnt.asset_id = fa_add.asset_id
                                   AND fa_add.asset_number = ad.asset_number
                                   AND flb.lookup_code =
                                       fa_retrmnt.retirement_type_code
                                   AND flb.lookup_type = 'RETIREMENT'
                                   AND flb.language = 'US'
                                   AND fa_retrmnt.date_retired BETWEEN calendar_period_open_date
                                                                   AND calendar_period_close_date
                                   AND fdp.book_type_code = fb.book_type_code)
                               retirement_period_counter,
                           (SELECT period_counter
                              FROM fa_deprn_periods
                             WHERE     gp.year_start_date BETWEEN calendar_period_open_date
                                                              AND calendar_period_close_date
                                   AND book_type_code = fb.book_type_code)
                               para_period_counter,
                           (SELECT 1
                              FROM fa_transaction_headers
                             WHERE     transaction_type_code =
                                       'REINSTATEMENT'
                                   AND asset_id = ad.asset_id)
                               REINSTATEMENT_count
                      FROM fa_additions ad,
                           fa_categories fc,
                           fa_books fb,
                           fa_deprn_periods fdp,
                           (SELECT year_start_date, ADD_MONTHS (year_start_date, 12) - 1 year_end_date, period_name,
                                   period_year, period_num
                              FROM gl_periods
                             WHERE     1 = 1
                                   AND period_set_name = 'DO_FY_CALENDAR') gp,
                           xxd_fa_aro_book_region_v asset_reg
                     WHERE     1 = 1
                           AND ad.asset_category_id = fc.category_id
                           AND ad.asset_id = fb.asset_id
                           AND fdp.book_type_code = fb.book_type_code
                           -- AND fb.date_ineffective IS NULL
                           AND gp.period_name = fdp.period_name
                           AND fdp.period_name = p_curr_period
                           AND (   segment1 = 'ARO'
                                OR EXISTS
                                       (SELECT 1
                                          FROM apps.fnd_flex_value_sets fvs, apps.fnd_flex_values_vl ffvl
                                         WHERE     fvs.flex_value_set_id =
                                                   ffvl.flex_value_set_id
                                               AND fvs.flex_value_set_name =
                                                   'DO_ARO_ASSETS'
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.start_date_active),
                                                       TRUNC (SYSDATE)) <=
                                                   TRUNC (SYSDATE)
                                               AND NVL (
                                                       TRUNC (
                                                           ffvl.end_date_active),
                                                       TRUNC (SYSDATE)) >=
                                                   TRUNC (SYSDATE)
                                               AND ffvl.enabled_flag = 'Y'
                                               AND ffvl.flex_value =
                                                   ad.asset_number))
                           AND asset_reg.book_type_code(+) =
                               fb.book_type_code
                           AND (region = pv_region AND asset_reg.book_type_code = NVL (pv_asset_book, asset_reg.book_type_code) OR (pv_region = 'ALL' AND 1 = 1))
                           AND prorate_date <= calendar_period_close_date
                           AND transaction_header_id_out IN
                                   (SELECT transaction_header_id
                                      FROM fa_transaction_headers fth
                                     WHERE     transaction_type_code =
                                               'FULL RETIREMENT'
                                           AND fth.asset_id = fb.asset_id)
                           AND EXISTS
                                   (SELECT 1
                                      FROM fa_transaction_headers
                                     WHERE     transaction_type_code =
                                               'FULL RETIREMENT'
                                           AND asset_id = ad.asset_id))
             WHERE     1 = 1
                   AND (retirement_period_counter >= para_period_counter OR REINSTATEMENT_count >= 1)
                   AND p_curr_period_count = 1
            ORDER BY asset_number;

        ln_accertion_addition         NUMBER := NULL;
        ln_tot_liability_ly           NUMBER;
        ln_deletion_check             NUMBER;
        ln_deletions                  NUMBER;
        ln_tot_liability_cy           NUMBER;
        ln_ptd_aro_addition           NUMBER;
        ln_asset_placed_month_count   NUMBER;
        ln_ptd_tot_liability_ly       NUMBER;
        ln_ptd_tot_liability_ly0      NUMBER;
        ln_ptd_tot_liability_ly1      NUMBER;
        lv_current_fy                 VARCHAR2 (20);
        lv_last_fy                    VARCHAR2 (20);
        lv_sysdate                    VARCHAR2 (20);
        ln_count                      NUMBER := 0;
        ln_nbv                        NUMBER := 0;
        ln_adj_count                  NUMBER := 0;
        ln_asset_life_before_adj      NUMBER := 0;
        ld_adj_entered                DATE;
        tot_acc_before_adj            NUMBER := 0;
        ln_difference                 NUMBER := 0;
        ln_per_month_amt_bef_adj      NUMBER := 0;
        ln_pre_adj_months             NUMBER := 0;
        ln_diff_amount_after          NUMBER := 0;
        ln_post_adj_months            NUMBER := 0;
        ln_acc_per_mon_aft_adj        NUMBER := 0;
        ln_post_adj_asset_life        NUMBER := 0;
        ln_tot_acc_after_adj          NUMBER := 0;
        ln_extra_months_post          NUMBER := 0;
        v_msg                         VARCHAR2 (4000);
        lv_curr_fin_year              VARCHAR2 (100);
        lv_curr_fin_period_year       NUMBER;
        lv_curr_fin_period            VARCHAR2 (100);
        ln_curr_year_count            NUMBER;
        ln_current_cost               NUMBER;
    BEGIN
        -- Query to fetch the current financial year
        BEGIN
            SELECT period_name, period_year
              INTO lv_curr_fin_year, lv_curr_fin_period_year
              FROM gl_periods
             WHERE     period_set_name = 'DO_FY_CALENDAR'
                   AND period_num = 12
                   AND period_year =
                       (SELECT period_year
                          FROM gl_periods
                         WHERE     period_set_name = 'DO_FY_CALENDAR'
                               AND SYSDATE BETWEEN start_date AND end_date);
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_curr_fin_year          := NULL;
                lv_curr_fin_period_year   := NULL;
        END;

        IF pv_financial_year = lv_curr_fin_year OR pv_balance_type = 'MTD'
        THEN
            ln_curr_year_count   := 1;

            IF pv_balance_type = 'MTD'
            THEN
                lv_curr_fin_period   := pv_mtd_period_name;
            ELSE
                BEGIN
                    SELECT period_name
                      INTO lv_curr_fin_period
                      FROM (  SELECT period_name, 'Draft' program_mode
                                FROM gl_periods gp
                               WHERE     period_set_name = 'DO_FY_CALENDAR'
                                     AND period_year =
                                         (SELECT period_year
                                            FROM gl_periods
                                           WHERE     period_set_name =
                                                     'DO_FY_CALENDAR'
                                                 AND SYSDATE BETWEEN start_date
                                                                 AND end_date)
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM gl_period_statuses gps
                                               WHERE     gps.period_name =
                                                         gp.period_name
                                                     AND closing_status IN
                                                             ('F', 'N', 'O')
                                                     AND application_id = 101
                                                     AND ledger_id = 2036)
                                     AND NOT EXISTS
                                             (SELECT 1
                                                FROM xxdo.xxd_fa_aro_ptd_values_t a
                                               WHERE a.pv_financial_year =
                                                     gp.period_name)
                            ORDER BY period_num)
                     WHERE ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lv_curr_fin_period   := NULL;
                END;
            END IF;
        ELSE
            ln_curr_year_count   := 0;
        END IF;

        fnd_file.put_line (fnd_file.LOG, '');

        FOR i
            IN fa_eligible_aro_asset_cur (lv_curr_fin_period,
                                          ln_curr_year_count)
        LOOP
            BEGIN
                BEGIN
                    SELECT cost
                      INTO ln_current_cost
                      FROM (  SELECT cost
                                FROM fa_books
                               WHERE asset_id = i.asset_id AND cost <> 0
                            ORDER BY transaction_header_id_in DESC)
                     WHERE ROWNUM = 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_current_cost   := 0;
                END;

                INSERT INTO xxdo.xxd_fa_aro_obli_t
                         VALUES (
                                    i.asset_number,
                                    i.asset_id,
                                    i.major_category,
                                    i.asset_description,
                                    i.book_type_code,
                                    CASE
                                        WHEN i.current_cost = 0
                                        THEN
                                            ln_current_cost
                                        ELSE
                                            i.current_cost
                                    END,
                                    i.asset_life,
                                    CASE
                                        WHEN i.pv_aro_at_establishment = 0
                                        THEN
                                            ln_current_cost
                                        ELSE
                                            i.pv_aro_at_establishment
                                    END,
                                    i.per_month_cost,
                                    i.months_pre,
                                    i.months_curr,
                                    i.pv_aro_addition,
                                    i.accretion_balance_type,
                                    i.total_target_aro,
                                    i.extra_months_after,
                                    i.date_placed_in_service,
                                    i.asset_date_retired,
                                    i.year_start_date,
                                    i.year_end_date,
                                    i.period_year,
                                    i.period_num,
                                    NULL,               --i.asset_period_num ,
                                    NULL,                --i.nbv_period_name ,
                                    i.period_name,
                                    i.current_yr,
                                    i.region,
                                    i.vs_book_type_code,
                                    NULL,                    --i.cost_center ,
                                    gn_login_id,
                                    SYSDATE,
                                    gn_login_id,
                                    SYSDATE,
                                    gn_request_id,
                                    i.original_cost,
                                    i.retirement_period_counter);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Failed to insert the data in custom table'
                        || SQLERRM);
                    v_msg   :=
                           'Failed to insert the data in custom table'
                        || SQLERRM;
            END;
        END LOOP;
    END insert_eligible_records;

    -- ======================================================================================
    -- This procedure is used to call package from XML FILE
    -- ======================================================================================

    FUNCTION main (pv_program_mode IN VARCHAR2, pv_region IN VARCHAR2, pv_asset_book IN VARCHAR2, pv_financial_year IN VARCHAR2, pv_balance_type IN VARCHAR2, sent_to_blackline IN VARCHAR2
                   , pv_mtd_period_name IN VARCHAR2)
        RETURN BOOLEAN
    AS
        lv_status   VARCHAR2 (10);
    BEGIN
        -- Truncating the table
        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_FA_ARO_OBLI_T';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_FA_ADJUSTMENT_DATA_T';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_FA_ARO_OBLI_REPORT_GT';

        EXECUTE IMMEDIATE 'TRUNCATE TABLE XXDO.XXD_FA_TEAR_DOWN_DATA_T';

        --xxdo.xxd_fa_adjustment_data_t
        -- Display Report parameters
        fnd_file.put_line (fnd_file.LOG,
                           'pv_program_mode:' || pv_program_mode);
        fnd_file.put_line (fnd_file.LOG, 'pv_region:' || pv_region);
        fnd_file.put_line (fnd_file.LOG, 'pv_asset_book:' || pv_asset_book);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_financial_year:' || pv_financial_year);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_balance_type:' || pv_balance_type);
        fnd_file.put_line (fnd_file.LOG,
                           'sent_to_blackline:' || sent_to_blackline);
        fnd_file.put_line (fnd_file.LOG,
                           'pv_mtd_period_name:' || pv_mtd_period_name);

        IF pv_program_mode IN ('Draft', 'Final')
        THEN
            insert_eligible_records (pv_program_mode, pv_region, pv_asset_book, pv_financial_year, pv_balance_type, sent_to_blackline
                                     , pv_mtd_period_name);
            generate_report (pv_program_mode, pv_region, pv_asset_book,
                             pv_financial_year, pv_balance_type, sent_to_blackline
                             , pv_mtd_period_name);
        ELSIF pv_program_mode = 'Report'
        THEN
            insert_report_records (pv_program_mode, pv_region, pv_asset_book,
                                   pv_financial_year, pv_balance_type, sent_to_blackline
                                   , pv_mtd_period_name);
        ELSIF pv_program_mode = 'Oveeride'
        THEN
            oveeride_existing_records (pv_program_mode, pv_region, pv_asset_book, pv_financial_year, pv_balance_type, sent_to_blackline
                                       , lv_status);

            IF NVL (lv_status, 'N') = 'S'
            THEN
                insert_eligible_records (pv_program_mode, pv_region, pv_asset_book, pv_financial_year, pv_balance_type, sent_to_blackline
                                         , pv_mtd_period_name);
                generate_report (pv_program_mode, pv_region, pv_asset_book,
                                 pv_financial_year, pv_balance_type, sent_to_blackline
                                 , pv_mtd_period_name);
            END IF;
        END IF;

        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
            RETURN (TRUE);
    END main;
END xxd_fa_aro_asset_obli_pkg;
/
