--
-- XXD_FA_ROLL_FWD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_ROLL_FWD_PKG"
AS
    /***********************************************************************************
     *$header :                                                                        *
     *                                                                                 *
     * AUTHORS : Srinath Siricilla                                                     *
     *                                                                                 *
     * PURPOSE : Used for Fixed Assets Reports                                         *
     *                                                                                 *
     * PARAMETERS :                                                                    *
     *                                                                                 *
     * DATE : 01-Dec-2013                                                              *
     *                                                                                 *
     * Assumptions:                                                                    *
     *                                                                                 *
    -- Start changes by BT Technology Team v4.0 on 10-Nov-2014                         *
     * Vsn   Change Date Changed By           Change Description                       *
     * ----- ----------- -------------------  -------------------------------------    *
     * History                                                                         *
     * 1.0   01-Dec-2013 Srinath Siricilla    Initial Creation                         *
     * 2.0   31-May-2014 Srinath Siricilla    Added Capitalized Column and NBV logic   *
     * 3.0   16-Oct-2014 BT Technology Team   Retrofitted the program                  *
     * 4.0   10-Nov-2014 BT Technology Team   Retrofitted the program and NBV logic    *
     * 4.1   19-Dec-2014 BT Technology Team   Added columns for Fixed assets and added *
     *                                        CIP section to the report                *
     * 5.0   07-JUL-2015 Showkath Ali         Modified package for new changes         *
     * 6.0   17-JUN-2016 Infosys              Modified for INC0299211.                 *
     * 7.0   06-JUL-2016 Infosys              Modified for ending balance              *
     * 8.0   25-JUL-2016 Infosys              Modified for DFCT0011357.                *
     * 9.0   02-Nov-2016 Infosys              Modified for INC0320339                  *
     * 10.0  13-Aug-2019 Showkath Ali         Added Project type parameter(CCR0008086) *
     * 11.0  10-Sep-2021 Damodara Gupta       Added New Column-XLA Segments(CCR0009036)*
     **********************************************************************************/
    --Defining Global variable for Set of Books ID (SOB_ID) retrofit
    g_set_of_books_id   NUMBER (10);

    -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;

        RETURN;
    END print_log_prc;

    -- End changes by BT Technology Team v4.1 on 18-Dec-2014

    FUNCTION xxd_fa_return_sob_id_fnc (pn_book       IN VARCHAR2,
                                       pn_currency      VARCHAR2)
        RETURN NUMBER
    IS
        v_sob_id    NUMBER (10);
        v_sob_id1   NUMBER (10);
    BEGIN
        SELECT set_of_books_id
          INTO v_sob_id
          FROM fa_mc_book_controls
         WHERE book_type_code = pn_book -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                                        --and (primary_currency_code = pn_currency or currency_code = pn_currency);
                                        AND currency_code = pn_currency; --To Fetch Reporting Currency SOB id

        -- End changes by BT Technology Team v4.1 on 18-Dec-2014
        RETURN v_sob_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            SELECT set_of_books_id
              INTO v_sob_id1
              FROM fa_book_controls
             WHERE book_type_code = pn_book;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   '@xxd_return_sob_id_fnc:- No Data Found. Hence  returning v_sob_id1 - '
                || v_sob_id1);

            RETURN v_sob_id1;
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error @xxd_return_sob_id_fnc:- Other Exception ' || SQLERRM);

            RETURN NULL;
    END;

    FUNCTION xxd_fa_set_client_info_fnc (p_sob_id IN VARCHAR2)
        RETURN NUMBER
    IS
        v_user_env          VARCHAR2 (100);
        v_string            VARCHAR2 (100);
        v_set_of_books_id   VARCHAR2 (100);
        v_set_user_env      VARCHAR2 (100);
    BEGIN
        SELECT USERENV ('CLIENT_INFO') INTO v_user_env FROM DUAL;

        SELECT SUBSTR (v_user_env, 0, 44) INTO v_string FROM DUAL;

        --fnd_file.put_line(fnd_file.log,'Environment:'||v_user_env);

        v_set_user_env   := v_string || p_sob_id;

        --       select substr(v_user_env,55) into v_string from dual;
        --
        --       v_set_user_env := v_set_user_env || v_string;

        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'v_set_user_env:' || v_set_user_env);*/

        DBMS_APPLICATION_INFO.set_client_info (v_set_user_env);

        SELECT TO_NUMBER (SUBSTR (USERENV ('CLIENT_INFO'), 45, 10))
          INTO v_set_of_books_id
          FROM DUAL;

        RETURN v_set_of_books_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                   'Error @xxd_fa_set_client_info_fnc:- Other Exception '
                || SQLERRM);
            RETURN NULL;
    END;


    PROCEDURE xxd_fa_update_impairment (pn_asset_id NUMBER, pn_book VARCHAR2)
    IS
        v_impair_amount    NUMBER;
        v_impair_amount1   NUMBER;
        v_asset_id         NUMBER;
        v_asset_id1        NUMBER;
        v_book_type        VARCHAR2 (15);                            --NUMBER;
        v_book_type1       VARCHAR2 (15);                            --NUMBER;
        ln_count           NUMBER;
        location_seg       VARCHAR2 (154);                              --v4.1
    BEGIN
        BEGIN
            SELECT DISTINCT fa.asset_id, fi.impairment_amount, fcb.book_type_code
              INTO v_asset_id, v_impair_amount, v_book_type
              FROM apps.fa_additions fa, apps.fa_asset_history fah, apps.fa_category_books fcb,
                   apps.fa_impairments fi
             WHERE     fa.asset_id = fah.asset_id
                   --AND fa.asset_category_id = fah.category_id
                   AND fcb.category_id = fa.asset_category_id
                   AND fa.asset_id = pn_asset_id
                   AND fa.asset_id = fi.asset_id
                   AND fcb.book_type_code = pn_book
                   AND fah.date_ineffective IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    SELECT DISTINCT fa.asset_id, fi.impairment_amount, fcb.book_type_code
                      INTO v_asset_id1, v_impair_amount1, v_book_type1
                      FROM apps.fa_additions fa, apps.fa_asset_history fah, fa_category_books fcb,
                           apps.fa_impairments fi
                     WHERE     fa.asset_id = fah.asset_id
                           AND fa.asset_id = fi.asset_id
                           AND fcb.category_id = fa.asset_category_id
                           AND fa.asset_id = pn_asset_id
                           AND fcb.book_type_code = pn_book
                           AND fah.asset_type IN ('CIP', 'CAPITALIZED');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_impair_amount1   := NULL; --Added by BT Technology Team v4.1 on 24-Dec-2014
                /*fnd_file.put_line (
                   fnd_file.LOG,
                   '02 - Select' || v_impair_amount1 || SQLERRM);*/
                END;
            WHEN OTHERS
            THEN
                --fnd_file.put_line(fnd_file.LOG,' Asset Doesnot exists: '||pn_asset_id||' Corresponding to Book :'||pn_book);
                v_impair_amount    := NULL;
                v_impair_amount1   := NULL;
        END;

        -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
        BEGIN
            SELECT fkv.concatenated_segments
              INTO location_seg
              FROM fa_locations_kfv fkv
             WHERE location_id = (SELECT location_id
                                    FROM (  SELECT location_id
                                              FROM fa_distribution_history
                                             WHERE asset_id = pn_asset_id
                                          ORDER BY date_ineffective DESC)
                                   WHERE ROWNUM = 1);

            UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
               SET location   = location_seg
             WHERE rep1.asset_id = pn_asset_id AND location IS NULL;

            -- print_log_prc('Asset loc update for asset: '||pn_asset_id||' and location is : '||location_seg ||' Count is:'||SQL%ROWCOUNT);
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                location_seg   := NULL;
        --print_log_prc('Asset loc update for asset: '||pn_asset_id||' Err : '||SQLERRM);
        END;

        -- End changes by BT Technology Team v4.1 on 18-Dec-2014



        IF v_impair_amount IS NOT NULL
        THEN
            ln_count   := 0;

              SELECT COUNT (*)
                INTO ln_count
                FROM xxdo.xxd_fa_roll_fwd_rep_t
               WHERE asset_id = v_asset_id
            GROUP BY asset_id;



            IF ln_count > 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                   SET impairment   = v_impair_amount
                 WHERE rep1.asset_id = v_asset_id AND rep1.end_year > 0;
            ELSIF ln_count = 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                   SET impairment   = v_impair_amount
                 WHERE rep1.asset_id = v_asset_id;
            END IF;

            COMMIT;
        ELSIF v_impair_amount IS NULL AND v_impair_amount1 IS NOT NULL
        THEN
            BEGIN
                ln_count   := 0;

                  SELECT COUNT (*)
                    INTO ln_count
                    FROM xxdo.xxd_fa_roll_fwd_rep_t
                   WHERE asset_id = v_asset_id1
                GROUP BY asset_id;



                IF ln_count > 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'4 - Count1>1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                       SET impairment   = v_impair_amount1
                     WHERE rep1.asset_id = v_asset_id1 AND rep1.end_year > 0;
                ELSIF ln_count = 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'5 - Count1=1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                       SET impairment   = v_impair_amount1 --v_cost - v_dep_reserve
                     WHERE rep1.asset_id = v_asset_id1;
                END IF;

                COMMIT;
            END;
        END IF;
    END;



    PROCEDURE xxd_fa_update_impairment_sum (pn_asset_id   NUMBER,
                                            pn_book       VARCHAR2)
    IS
        v_impair_amount    NUMBER;
        v_impair_amount1   NUMBER;
        v_asset_id         NUMBER;
        v_asset_id1        NUMBER;
        v_book_type        VARCHAR2 (15);                            --NUMBER;
        v_book_type1       VARCHAR2 (15);                            --NUMBER;
        ln_count           NUMBER;
    BEGIN
        BEGIN
            SELECT DISTINCT fa.asset_id, fi.impairment_amount, fcb.book_type_code
              INTO v_asset_id, v_impair_amount, v_book_type
              FROM apps.fa_additions fa, apps.fa_asset_history fah, apps.fa_category_books fcb,
                   apps.fa_impairments fi
             WHERE     fa.asset_id = fah.asset_id
                   --AND fa.asset_category_id = fah.category_id
                   AND fcb.category_id = fa.asset_category_id
                   AND fa.asset_id = pn_asset_id
                   AND fa.asset_id = fi.asset_id
                   AND fcb.book_type_code = pn_book
                   AND fah.date_ineffective IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    SELECT DISTINCT fa.asset_id, fi.impairment_amount, fcb.book_type_code
                      INTO v_asset_id1, v_impair_amount1, v_book_type1
                      FROM apps.fa_additions fa, apps.fa_asset_history fah, fa_category_books fcb,
                           apps.fa_impairments fi
                     WHERE     fa.asset_id = fah.asset_id
                           AND fa.asset_id = fi.asset_id
                           AND fcb.category_id = fa.asset_category_id
                           AND fa.asset_id = pn_asset_id
                           AND fcb.book_type_code = pn_book
                           AND fah.asset_type IN ('CIP', 'CAPITALIZED');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                        /*fnd_file.put_line (
                           fnd_file.LOG,
                           '03 - Select' || v_impair_amount1 || SQLERRM);*/
                        v_impair_amount    := NULL;
                        v_impair_amount1   := NULL;
                -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                END;
            --fnd_file.put_line(fnd_file.LOG,'02 - Select'||vn_asset_id1);



            WHEN OTHERS
            THEN
                --fnd_file.put_line(fnd_file.LOG,' Asset Doesnot exists: '||pn_asset_id||' Corresponding to Book :'||pn_book);
                v_impair_amount    := NULL;
                v_impair_amount1   := NULL;
        END;


        IF v_impair_amount IS NOT NULL
        THEN
            ln_count   := 0;

              SELECT COUNT (*)
                INTO ln_count
                FROM xxdo.xxd_fa_roll_fwd_rep_sum_t
               WHERE asset_id = v_asset_id
            GROUP BY asset_id;


            IF ln_count > 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                   SET impairment   = v_impair_amount
                 WHERE rep1.asset_id = v_asset_id AND rep1.end_year > 0;
            ELSIF ln_count = 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                   SET impairment   = v_impair_amount
                 WHERE rep1.asset_id = v_asset_id;
            END IF;

            COMMIT;
        ELSIF v_impair_amount IS NULL AND v_impair_amount1 IS NOT NULL
        THEN
            BEGIN
                ln_count   := 0;

                  SELECT COUNT (*)
                    INTO ln_count
                    FROM xxdo.xxd_fa_roll_fwd_rep_sum_t --xxd_fa_roll_fwd_rep_t v4.1
                   WHERE asset_id = v_asset_id1
                GROUP BY asset_id;

                IF ln_count > 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'4 - Count1>1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                       SET impairment   = v_impair_amount1
                     WHERE rep1.asset_id = v_asset_id1 AND rep1.end_year > 0;
                ELSIF ln_count = 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'5 - Count1=1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                       SET impairment   = v_impair_amount1 --v_cost - v_dep_reserve
                     WHERE rep1.asset_id = v_asset_id1;
                END IF;

                COMMIT;
            END;
        END IF;
    END;

    -- End changes by BT Technology Team v4.0 on 10-Nov-2014

    -- Start changes by BT Technology Team v4.1 on 26-Dec-2014

    PROCEDURE get_project_cip_prc (p_called_from IN VARCHAR2, p_book IN VARCHAR2, p_currency IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2, p_begin_spot_rate IN NUMBER, p_end_spot_rate IN NUMBER, p_begin_bal_tot OUT NUMBER, p_begin_spot_tot OUT NUMBER, p_begin_trans_tot OUT NUMBER, p_additions_tot OUT NUMBER, p_capitalizations_tot OUT NUMBER, p_end_bal_tot OUT NUMBER, p_end_spot_tot OUT NUMBER, p_end_trans_tot OUT NUMBER
                                   , p_net_trans_tot OUT NUMBER)
    IS
        ln_begin_bal             NUMBER;
        ln_begin_bal_fun         NUMBER;
        ln_begin_bal_spot        NUMBER;
        ln_begin_trans           NUMBER;
        ln_additions             NUMBER;
        ln_additions_fun         NUMBER;
        ln_capital_fun           NUMBER;
        ln_capitalizations       NUMBER;
        ln_end_bal               NUMBER;
        ln_end_bal_fun           NUMBER;
        ln_end_bal_spot          NUMBER;
        ln_end_trans             NUMBER;
        ln_net_trans             NUMBER;
        ln_begin_bal_tot         NUMBER := 0;
        ln_begin_bal_fun_tot     NUMBER := 0;
        ln_begin_bal_spot_tot    NUMBER := 0;
        ln_begin_trans_tot       NUMBER := 0;
        ln_additions_tot         NUMBER := 0;
        --ln_additions_fun_tot     NUMBER := 0;
        --ln_capital_fun_tot       NUMBER := 0;
        ln_capitalizations_tot   NUMBER := 0;
        ln_end_bal_tot           NUMBER := 0;
        ln_end_bal_fun_tot       NUMBER := 0;
        ln_end_bal_spot_tot      NUMBER := 0;
        ln_end_trans_tot         NUMBER := 0;
        ln_net_trans_tot         NUMBER := 0;
        ld_begin_date            DATE;
        ld_end_date              DATE;
        ln_begin_spot_rate       NUMBER;
        ln_end_spot_rate         NUMBER;
        ln_conversion_rate       NUMBER;      -- added by showkath on 31/07/15
        l_func_currency          VARCHAR2 (10); --added by showkath on 01/DEC/15
        ln_begin_bal_fun_add     NUMBER;
        ln_begin_bal_fun_cap     NUMBER;
        ln_end_bal_fun_add       NUMBER;
        ln_end_bal_fun_cap       NUMBER;

        ln_from_period_ctr       NUMBER;          -- Added by Infosys for 6.0.
        ln_to_period_ctr         NUMBER;          -- Added by Infosys for 6.0.
    BEGIN
        print_log_prc ('Print CIP details');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, 'Project CIP Section');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');


        FOR rec
            IN (SELECT book_type_code
                  FROM fa_book_controls
                 WHERE     book_type_code = NVL (p_book, book_type_code)
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE)
        LOOP
            BEGIN
                SELECT calendar_period_open_date
                  INTO ld_begin_date
                  FROM fa_deprn_periods
                 WHERE     period_name = p_from_period
                       AND book_type_code = rec.book_type_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ld_begin_date   := NULL;
                    print_log_prc ('Error fetching ld_begin_date:');
            END;

            BEGIN
                SELECT calendar_period_close_date
                  INTO ld_end_date
                  FROM fa_deprn_periods
                 WHERE     period_name = p_to_period
                       AND book_type_code = rec.book_type_code;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    ld_end_date   := NULL;
                    print_log_prc ('Error fetching ld_end_date:');
            END;

            --START changes by showkath on 12/01/2015 to fix net fx translation requirement
            BEGIN
                SELECT currency_code
                  INTO l_func_currency
                  FROM gl_sets_of_books gsob, fa_book_controls fbc
                 WHERE     gsob.set_of_books_id = fbc.set_of_books_id
                       AND fbc.book_type_code = rec.book_type_code
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_func_currency   := NULL;
            END;

            --changes by showkath on 12/01/2015 to fix net fx translation requirement

            IF (p_currency <> l_func_currency)
            THEN
                BEGIN
                    SELECT conversion_rate
                      INTO ln_begin_spot_rate
                      FROM gl_daily_rates
                     WHERE     from_currency =
                               (SELECT currency_code
                                  FROM gl_sets_of_books gsob, fa_book_controls fbc
                                 WHERE     gsob.set_of_books_id =
                                           fbc.set_of_books_id
                                       AND fbc.book_type_code =
                                           rec.book_type_code
                                       AND NVL (date_ineffective,
                                                SYSDATE + 1) >
                                           SYSDATE)
                           AND to_currency = 'USD'
                           --AND TRUNC (conversion_date) = TRUNC (TO_DATE (p_from_period, 'MON-YY') - 1)
                           AND TRUNC (conversion_date) =
                               (SELECT TRUNC (calendar_period_open_date) - 1
                                  FROM fa_deprn_periods
                                 WHERE     period_name = p_from_period
                                       AND book_type_code =
                                           rec.book_type_code)
                           AND conversion_type = 'Spot';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_begin_spot_rate   := NULL;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Spot rate is not defined');
                --RETCODE :=2;
                --EXIT;
                END;

                BEGIN
                    SELECT conversion_rate
                      INTO ln_end_spot_rate
                      FROM gl_daily_rates
                     WHERE     from_currency =
                               (SELECT currency_code
                                  FROM gl_sets_of_books gsob, fa_book_controls fbc
                                 WHERE     gsob.set_of_books_id =
                                           fbc.set_of_books_id
                                       AND fbc.book_type_code =
                                           rec.book_type_code
                                       AND NVL (date_ineffective,
                                                SYSDATE + 1) >
                                           SYSDATE)
                           AND to_currency = 'USD'
                           AND TRUNC (conversion_date) =
                               (SELECT TRUNC (calendar_period_close_date)
                                  FROM fa_deprn_periods
                                 WHERE     period_name = p_to_period
                                       AND book_type_code =
                                           rec.book_type_code)
                           AND conversion_type = 'Spot';
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        ln_end_spot_rate   := NULL;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Spot rate is not defined');
                END;
            ELSE
                ln_begin_spot_rate   := NULL;             --p_begin_spot_rate;
                ln_end_spot_rate     := NULL;               --p_end_spot_rate;
            END IF;


            IF (ld_begin_date IS NOT NULL AND ld_end_date IS NOT NULL)
            THEN
                BEGIN
                    SELECT SUM (NVL (project_burdened_cost, 0)), SUM (NVL (acct_burdened_cost, 0))
                      INTO ln_begin_bal, ln_begin_bal_fun
                      FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                           pa_expenditures_all x, pa_project_types_all pt
                     WHERE     t.project_id = p.project_id
                           AND ei.project_id = p.project_id
                           AND p.project_type = pt.project_type
                           AND p.org_id = pt.org_id
                           AND ei.task_id = t.task_id
                           AND ei.expenditure_id = x.expenditure_id
                           AND ei.org_id =
                               (SELECT org_id
                                  FROM pa_implementations_all
                                 WHERE book_type_code = rec.book_type_code)
                           AND ei.expenditure_item_date < ld_begin_date
                           AND DECODE (pt.project_type_class_code,
                                       'CAPITAL', ei.billable_flag,
                                       NULL) =
                               'Y'
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM pa_project_asset_line_details pald, pa_project_asset_lines_all pal
                                     WHERE     1 = 1
                                           AND ei.expenditure_item_id =
                                               pald.expenditure_item_id
                                           AND pald.project_asset_line_detail_id =
                                               pal.project_asset_line_detail_id
                                           AND pal.project_id = ei.project_id
                                           --AND pal.task_id = ei.task_id
                                           AND pal.fa_period_name IS NOT NULL
                                           AND pal.org_id = ei.org_id
                                           AND pal.transfer_status_code = 'T'
                                           -- AND pal.gl_date <ld_begin_date  -- Commented for 8.0.
                                           -- BEGIN : Added for 8.0.
                                           AND ((SELECT calendar_period_open_date
                                                   FROM fa_deprn_periods
                                                  WHERE     period_name =
                                                            pal.fa_period_name
                                                        AND book_type_code =
                                                            rec.book_type_code) <
                                                ld_begin_date)-- END : Added for 8.0.
                                                              );

                    fnd_file.put_line (fnd_file.LOG,
                                       'cip begin balance' || ln_begin_bal);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'cip begin func balance' || ln_begin_bal_fun);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                            'Error fetching Begin Balance:' || SQLERRM);
                END;

                BEGIN
                    SELECT SUM (NVL (project_burdened_cost, 0)), SUM (NVL (acct_burdened_cost, 0))
                      INTO ln_end_bal, ln_end_bal_fun
                      FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                           pa_expenditures_all x, pa_project_types_all pt
                     WHERE     t.project_id = p.project_id
                           AND ei.project_id = p.project_id
                           AND p.project_type = pt.project_type
                           AND p.org_id = pt.org_id
                           AND ei.task_id = t.task_id
                           AND ei.expenditure_id = x.expenditure_id
                           AND ei.org_id =
                               (SELECT org_id
                                  FROM pa_implementations_all
                                 WHERE book_type_code = rec.book_type_code)
                           AND ei.expenditure_item_date <= ld_end_date
                           AND DECODE (pt.project_type_class_code,
                                       'CAPITAL', ei.billable_flag,
                                       NULL) =
                               'Y'
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM pa_project_asset_line_details pald, pa_project_asset_lines_all pal
                                     WHERE     1 = 1
                                           AND ei.expenditure_item_id =
                                               pald.expenditure_item_id
                                           AND pald.project_asset_line_detail_id =
                                               pal.project_asset_line_detail_id
                                           AND pal.project_id = ei.project_id
                                           --AND pal.task_id = ei.task_id
                                           AND pal.fa_period_name IS NOT NULL
                                           AND pal.org_id = ei.org_id
                                           AND pal.transfer_status_code = 'T'
                                           AND pal.gl_date <= ld_end_date);

                    fnd_file.put_line (fnd_file.LOG,
                                       'cip ending balance' || ln_end_bal);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'cip ending func balance' || ln_end_bal_fun);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                            'Error fetching End Balance:' || SQLERRM);
                END;

                BEGIN
                    SELECT SUM (NVL (burden_cost, 0) * gdr.conversion_rate), SUM (NVL (burden_cost, 0))
                      INTO ln_additions_fun, ln_additions
                      FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                           pa_expenditures_all x, pa_project_types_all pt, pa_implementations_all pia,
                           gl_daily_rates gdr
                     WHERE     t.project_id = p.project_id
                           AND ei.project_id = p.project_id
                           AND p.project_type = pt.project_type
                           AND p.org_id = pt.org_id
                           AND ei.task_id = t.task_id
                           AND ei.expenditure_id = x.expenditure_id
                           AND ei.org_id = pia.org_id
                           AND gdr.conversion_type(+) = 'Corporate'
                           AND gdr.from_currency(+) = l_func_currency
                           AND gdr.to_currency(+) = p_currency
                           AND gdr.conversion_date(+) =
                               TRUNC (ei.expenditure_item_date)
                           AND pia.book_type_code(+) = rec.book_type_code
                           AND ei.expenditure_item_date BETWEEN ld_begin_date
                                                            AND ld_end_date
                           AND DECODE (pt.project_type_class_code,
                                       'CAPITAL', ei.billable_flag,
                                       NULL) =
                               'Y';

                    IF ln_additions_fun IS NULL
                    THEN
                        print_log_prc (
                               'Corporate rate not defined between '
                            || l_func_currency
                            || ' and '
                            || p_currency);
                    END IF;

                    print_log_prc (
                           'ln_additions: '
                        || ln_additions
                        || ' ln_additions_fun '
                        || ln_additions_fun);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                            'Error fetching Additions:' || SQLERRM);
                END;

                -- START : Added by Infosys for 6.0.
                BEGIN
                    ln_from_period_ctr   := NULL;

                    SELECT period_counter
                      INTO ln_from_period_ctr
                      FROM fa_deprn_periods
                     WHERE     book_type_code = rec.book_type_code
                           AND period_name = p_from_period;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                               'Error fetching period counter for Book : '
                            || rec.book_type_code
                            || '. Period : '
                            || p_from_period);
                END;

                BEGIN
                    ln_to_period_ctr   := NULL;

                    SELECT period_counter
                      INTO ln_to_period_ctr
                      FROM fa_deprn_periods
                     WHERE     book_type_code = rec.book_type_code
                           AND period_name = p_to_period;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                               'Error fetching period counter for Book : '
                            || rec.book_type_code
                            || '. Period : '
                            || p_to_period);
                END;

                -- END : Added by Infosys for 6.0.

                BEGIN
                    SELECT SUM (pal.current_asset_cost) * -1 amt, SUM (pal.current_asset_cost * gdr.conversion_rate) * -1 conv_amt
                      INTO ln_capitalizations, ln_capital_fun
                      FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                           pa_project_types_all pta, gl_daily_rates gdr
                     WHERE     1 = 1
                           AND pal.transfer_status_code = 'T'
                           AND pal.org_id = pia.org_id
                           AND pia.book_type_code = rec.book_type_code
                           AND pal.project_id = ppa.project_id
                           AND pal.org_id = ppa.org_id
                           AND ppa.project_type = pta.project_type
                           AND ppa.org_id = pta.org_id
                           AND gdr.conversion_date(+) = TRUNC (gl_date)
                           AND gdr.conversion_type(+) = 'Corporate'
                           AND gdr.from_currency(+) = l_func_currency
                           AND gdr.to_currency(+) = p_currency
                           --  AND TRUNC (gl_date) BETWEEN ld_begin_date AND ld_end_date -- Commented by Infosys for 6.0.
                           --  AND fa_period_name IS NOT NULL;    -- Modified by Infosys for 6.0.
                           AND fa_period_name IN
                                   (SELECT period_name
                                      FROM fa_deprn_periods
                                     WHERE     book_type_code =
                                               rec.book_type_code
                                           AND period_counter BETWEEN ln_from_period_ctr
                                                                  AND ln_to_period_ctr);

                    IF ln_capital_fun IS NULL
                    THEN
                        print_log_prc (
                               'Corporate rate not defined between '
                            || l_func_currency
                            || ' and '
                            || p_currency);
                    END IF;

                    print_log_prc (
                           'ln_capitalizations: '
                        || ln_capitalizations
                        || ' ln_capital_fun '
                        || ln_capital_fun);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                            'Error fetching Capitalization:' || SQLERRM);
                END;

                IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                THEN
                    ln_begin_bal_spot   :=
                          NVL (ln_begin_bal_fun, 0)
                        * NVL (ln_begin_spot_rate, 1);
                    ln_end_bal_spot   :=
                        NVL (ln_end_bal_fun, 0) * NVL (ln_end_spot_rate, 1);
                ELSE
                    ln_begin_bal_spot   :=
                        ln_begin_bal_fun * ln_begin_spot_rate;
                    ln_begin_trans    := ln_begin_bal_spot - ln_begin_bal;
                    ln_end_bal_spot   := ln_end_bal_fun * ln_end_spot_rate;
                    ln_end_trans      := ln_end_bal_spot - ln_end_bal;
                END IF;

                IF (p_currency <> NVL (l_func_currency, 'X'))
                THEN
                    --               ln_additions := ln_additions * NVL (ln_conversion_rate, 1);
                    --               ln_capitalizations := ln_capitalizations * NVL (ln_conversion_rate, 1);
                    ln_additions         := ln_additions_fun;
                    ln_capitalizations   := ln_capital_fun;
                    ln_net_trans         := NULL;
                    ln_net_trans         :=
                          NVL (ln_end_bal_spot, 0)
                        - (NVL ((ln_begin_bal_spot), 0) + NVL (ln_additions, 0) + NVL (ln_capitalizations, 0));
                ELSE
                    ln_net_trans   := NULL;
                END IF;

                ln_end_bal_spot   :=
                      NVL (ln_begin_bal_spot, 0)
                    + NVL (ln_additions, 0)
                    + NVL (ln_capitalizations, 0);
                ln_end_bal_fun   :=
                      NVL (ln_begin_bal_fun, 0)
                    + NVL (ln_additions, 0)
                    + NVL (ln_capitalizations, 0);


                IF (ln_end_bal_fun IS NOT NULL OR ln_begin_bal_fun IS NOT NULL) --(ln_begin_bal IS NOT NULL OR ln_end_bal IS NOT NULL)
                THEN
                    IF (p_called_from = 'SUMMARY')
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               rec.book_type_code
                            || CHR (9)
                            || TO_CHAR (TO_DATE (p_from_period, 'MON-RR'),
                                        'MON-RRRR')
                            || CHR (9)
                            || TO_CHAR (TO_DATE (p_to_period, 'MON-RRRR'),
                                        'MON-RRRR')
                            || CHR (9)
                            || p_currency
                            || CHR (9)
                            || 'Project Based CIP'
                            || CHR (9)
                            || '12160'
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            --|| to_char(ln_begin_bal, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)                                       --commented by Showkath v5.0 on 07-Jul-2015
                            || TO_CHAR (ln_begin_bal_fun,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_begin_bal_spot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            --|| to_char(ln_begin_trans, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)                                         --commented by Showkath v5.0 on 07-Jul-2015
                            || TO_CHAR (ln_additions, 'FM999G999G999G999D99')
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || TO_CHAR (ln_capitalizations,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            --|| to_char(ln_end_bal, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)                                     --commented by Showkath v5.0 on 07-Jul-2015
                            || TO_CHAR (ln_end_bal_fun,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_end_bal_spot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)                                       --commented by Showkath v5.0 on 07-Jul-2015
                            || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL);
                    --START ::Commented the CIP part as part of INC0320339  on 02 -Nov-2016
                    /* ELSE
                        apps.fnd_file.put_line (
                           apps.fnd_file.output,
                              rec.book_type_code
                           || CHR (9)
                           || TO_CHAR (TO_DATE (p_from_period, 'MON-RR'),
                                       'MON-RRRR')          --TO_CHAR(v_period_from)
                           || CHR (9)
                           || TO_CHAR (TO_DATE (p_to_period, 'MON-RRRR'),
                                       'MON-RRRR')            --TO_CHAR(v_period_to)
                           || CHR (9)
                           || p_currency
                           || CHR (9)
                           || 'Project Based CIP'
                           || CHR (9)
                           || '12160'
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           --|| to_char(ln_begin_bal, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                           --|| CHR (9)                                       --commented by Showkath v5.0 on 07-Jul-2015
                           || TO_CHAR (ln_begin_bal_fun, 'FM999G999G999G999D99')
                           || CHR (9)
                           || TO_CHAR (ln_begin_bal_spot, 'FM999G999G999G999D99')
                           || CHR (9)
                           --|| to_char(ln_begin_trans, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                           --|| CHR (9)                                         --commented by Showkath v5.0 on 07-Jul-2015
                           || TO_CHAR (ln_additions, 'FM999G999G999G999D99')
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || TO_CHAR (ln_capitalizations, 'FM999G999G999G999D99')
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           --|| to_char(ln_end_bal, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                           --|| CHR (9)                                     --commented by Showkath v5.0 on 07-Jul-2015
                           || TO_CHAR (ln_end_bal_fun, 'FM999G999G999G999D99')
                           || CHR (9)
                           || TO_CHAR (ln_end_bal_spot, 'FM999G999G999G999D99')
                           || CHR (9)
                           --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 07-Jul-2015
                           --|| CHR (9)                                       --commented by Showkath v5.0 on 07-Jul-2015
                           || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')
                           || CHR (9)
                           || NULL
                           || CHR (9)
                           || NULL);*/
                    --START ::Commented the CIP part as part of INC0320339  on 02 -Nov-2016
                    END IF;

                    ln_begin_bal_tot   :=
                        NVL (ln_begin_bal_tot, 0) + NVL (ln_begin_bal, 0);
                    ln_begin_bal_fun_tot   :=
                          NVL (ln_begin_bal_fun_tot, 0)
                        + NVL (ln_begin_bal_fun, 0);
                    ln_begin_bal_spot_tot   :=
                          NVL (ln_begin_bal_spot_tot, 0)
                        + NVL (ln_begin_bal_spot, 0);
                    ln_begin_trans_tot   :=
                        NVL (ln_begin_trans_tot, 0) + NVL (ln_begin_trans, 0);
                    ln_additions_tot   :=
                        NVL (ln_additions_tot, 0) + NVL (ln_additions, 0);
                    ln_capitalizations_tot   :=
                          NVL (ln_capitalizations_tot, 0)
                        + NVL ((ln_capitalizations * -1), 0);
                    ln_end_bal_tot   :=
                        NVL (ln_end_bal_tot, 0) + NVL (ln_end_bal, 0);
                    ln_end_bal_fun_tot   :=
                        NVL (ln_end_bal_fun_tot, 0) + NVL (ln_end_bal_fun, 0);
                    ln_end_bal_spot_tot   :=
                          NVL (ln_end_bal_spot_tot, 0)
                        + NVL (ln_end_bal_spot, 0);
                    ln_end_trans_tot   :=
                        NVL (ln_end_trans_tot, 0) + NVL (ln_end_trans, 0);
                    ln_net_trans_tot   :=
                        NVL (ln_net_trans_tot, 0) + NVL (ln_net_trans, 0);
                END IF;
            END IF;
        END LOOP;

        ln_capitalizations_tot   := ln_capitalizations_tot * -1;

        IF (p_called_from = 'SUMMARY')
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || 'TOTAL Project CIP: '
                || CHR (9)
                --|| to_char(ln_begin_bal_tot, 'FM999G999G999G999D99') --commented by Showkath v5.0 on 15-Jul-2015
                --|| CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_begin_bal_spot_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_begin_trans_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
                --|| CHR (9)
                || TO_CHAR (ln_additions_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_capitalizations_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                --|| to_char(ln_end_bal_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
                --|| CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_end_bal_spot_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_end_trans_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
                --|| CHR (9)
                || TO_CHAR (ln_net_trans_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL);
        --START ::Commented the CIP part as part of INC0320339  on 02 -Nov-2016
        /* ELSE
            apps.fnd_file.put_line (
               apps.fnd_file.output,
                  NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || 'TOTAL Project CIP: '
               || CHR (9)
               --|| to_char(ln_begin_bal_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
               --|| CHR (9)
               || NULL
               || CHR (9)
               || TO_CHAR (ln_begin_bal_spot_tot, 'FM999G999G999G999D99')
               || CHR (9)
               --|| to_char(ln_begin_trans_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
               --|| CHR (9)
               || TO_CHAR (ln_additions_tot, 'FM999G999G999G999D99')
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               --|| TO_CHAR (ln_capitalizations, 'FM999G999G999G999D99')
               || TO_CHAR (ln_capitalizations_tot, 'FM999G999G999G999D99')
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL
               || CHR (9)
               --|| to_char(ln_end_bal_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
               --|| CHR (9)
               || NULL
               || CHR (9)
               || TO_CHAR (ln_end_bal_spot_tot, 'FM999G999G999G999D99')
               || CHR (9)
               --|| to_char(ln_end_trans_tot, 'FM999G999G999G999D99')--commented by Showkath v5.0 on 15-Jul-2015
               --|| CHR (9)
               || TO_CHAR (ln_net_trans_tot, 'FM999G999G999G999D99')
               || CHR (9)
               || NULL
               || CHR (9)
               || NULL);*/
        --END ::Commented the CIP part as part of INC0320339  on 02 -Nov-2016
        END IF;

        p_begin_bal_tot          := ln_begin_bal_tot;
        p_begin_spot_tot         := ln_begin_bal_spot_tot;
        p_begin_trans_tot        := ln_begin_trans_tot;
        p_additions_tot          := ln_additions_tot;
        p_capitalizations_tot    := ln_capitalizations_tot;
        p_end_bal_tot            := ln_end_bal_tot;
        p_end_spot_tot           := ln_end_bal_spot_tot;
        p_end_trans_tot          := ln_end_trans_tot;
        p_net_trans_tot          := ln_net_trans_tot;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc ('Error in get_project_cip_prc:' || SQLERRM);
    END;

    -- End changes by BT Technology Team v4.1 on 26-Dec-2014

    PROCEDURE xxd_fa_rsvldg_proc (book IN VARCHAR2, period IN VARCHAR2)
    IS
        operation           VARCHAR2 (200);
        dist_book           VARCHAR2 (15);
        ucd                 DATE;
        upc                 NUMBER;
        tod                 DATE;
        tpc                 NUMBER;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
        v_set_of_books_id   VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        EXECUTE IMMEDIATE 'truncate table XXDO.XXD_FA_ROLL_RSV_LEDGER_T';

        BEGIN
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;
            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        operation   := 'Selecting Book and Period information';

        IF (h_reporting_flag = 'R')
        THEN
              SELECT bc.distribution_source_book dbk, NVL (dp.period_close_date, SYSDATE) ucd, dp.period_counter upc,
                     MIN (dp_fy.period_open_date) tod, MIN (dp_fy.period_counter) tpc
                INTO dist_book, ucd, upc, tod,
                              tpc
                FROM fa_deprn_periods_mrc_v dp, fa_deprn_periods_mrc_v dp_fy, fa_book_controls_mrc_v bc
               WHERE     dp.book_type_code = book
                     AND dp.period_name = period
                     AND dp_fy.book_type_code = book
                     AND dp_fy.fiscal_year = dp.fiscal_year
                     AND bc.book_type_code = book
            GROUP BY bc.distribution_source_book, dp.period_close_date, dp.period_counter;
        ELSE
              SELECT bc.distribution_source_book dbk, NVL (dp.period_close_date, SYSDATE) ucd, dp.period_counter upc,
                     MIN (dp_fy.period_open_date) tod, MIN (dp_fy.period_counter) tpc
                INTO dist_book, ucd, upc, tod,
                              tpc
                FROM fa_deprn_periods dp, fa_deprn_periods dp_fy, fa_book_controls bc
               WHERE     dp.book_type_code = book
                     AND dp.period_name = period
                     AND dp_fy.book_type_code = book
                     AND dp_fy.fiscal_year = dp.fiscal_year
                     AND bc.book_type_code = book
            GROUP BY bc.distribution_source_book, dp.period_close_date, dp.period_counter;
        END IF;

        operation   := 'Inserting into xxdo.XXD_FA_ROLL_RSV_LEDGER_T';


        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective,
                                reserve_acct)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd_bonus.cost cost,
                           DECODE (dd_bonus.period_counter, upc, dd_bonus.deprn_amount - dd_bonus.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd_bonus.period_counter), 1, 0, dd_bonus.ytd_deprn - dd_bonus.bonus_ytd_deprn) ytd_deprn, dd_bonus.deprn_reserve - dd_bonus.bonus_deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd_bonus.period_counter,
                           NVL (th.date_effective, ucd), ''
                      FROM fa_deprn_detail_mrc_v dd_bonus, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books_mrc_v books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CIP', 'CAPITALIZED')
                           AND dd_bonus.book_type_code = book
                           AND dd_bonus.distribution_id = dh.distribution_id
                           AND dd_bonus.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                    UNION ALL
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.bonus_deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, 0 cost,
                           DECODE (dd.period_counter, upc, dd.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.bonus_ytd_deprn) ytd_deprn, dd.bonus_deprn_reserve deprn_reserve,
                           0 percent, 'B' t_type, dd.period_counter,
                           NVL (th.date_effective, ucd), cb.bonus_deprn_expense_acct
                      FROM fa_deprn_detail_mrc_v dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books_mrc_v books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CIP', 'CAPITALIZED')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND books.bonus_rule IS NOT NULL
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective,
                                reserve_acct)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd_bonus.cost cost,
                           DECODE (dd_bonus.period_counter, upc, dd_bonus.deprn_amount - dd_bonus.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd_bonus.period_counter), 1, 0, dd_bonus.ytd_deprn - dd_bonus.bonus_ytd_deprn) ytd_deprn, dd_bonus.deprn_reserve - dd_bonus.bonus_deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd_bonus.period_counter,
                           NVL (th.date_effective, ucd), ''
                      FROM fa_deprn_detail dd_bonus, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                           AND dd_bonus.book_type_code = book
                           AND dd_bonus.distribution_id = dh.distribution_id
                           AND dd_bonus.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                    UNION ALL
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.bonus_deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, 0 cost,
                           DECODE (dd.period_counter, upc, dd.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.bonus_ytd_deprn) ytd_deprn, dd.bonus_deprn_reserve deprn_reserve,
                           0 percent, 'B' t_type, dd.period_counter,
                           NVL (th.date_effective, ucd), cb.bonus_deprn_expense_acct
                      FROM fa_deprn_detail dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CIP', 'CAPITALIZED') --,'CIP')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND books.bonus_rule IS NOT NULL
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod;
            END IF;
        ELSIF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            -- Insert Non-Group Details
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (asset_id, dh_ccid, deprn_reserve_acct, date_placed_in_service, method_code, life, rate, capacity, cost, deprn_amount, ytd_deprn, deprn_reserve, percent, transaction_type, period_counter
                                                           , date_effective)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd.cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd.period_counter,
                           NVL (th.date_effective, ucd)
                      FROM fa_deprn_detail_mrc_v dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books_mrc_v books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE             -- start cua - exclude the group Assets
                               books.group_asset_id IS NULL
                           AND                                      -- end cua
                               cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                           AND         -- start cua - exclude the group Assets
                               books.group_asset_id IS NULL;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (asset_id, dh_ccid, deprn_reserve_acct, date_placed_in_service, method_code, life, rate, capacity, cost, deprn_amount, ytd_deprn, deprn_reserve, percent, transaction_type, period_counter
                                                           , date_effective)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd.cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd.period_counter,
                           NVL (th.date_effective, ucd)
                      FROM fa_deprn_detail dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE             -- start cua - exclude the group Assets
                               books.group_asset_id IS NULL
                           AND cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                           AND books.group_asset_id IS NULL;
            -- start cua - exclude the group Assets
            END IF;

            -- end cua

            -- Insert the Group Depreciation Details
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (asset_id, dh_ccid, deprn_reserve_acct, date_placed_in_service, method_code, life, rate, capacity, cost, deprn_amount, ytd_deprn, deprn_reserve, percent, transaction_type, period_counter
                                                           , date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid ch_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, gar.deprn_method_code method, gar.life_in_months life,
                           gar.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary_mrc_v dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_deprn_periods_mrc_v dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gad.super_group_id IS NULL
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;      -- mwoodwar
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (asset_id, dh_ccid, deprn_reserve_acct, date_placed_in_service, method_code, life, rate, capacity, cost, deprn_amount, ytd_deprn, deprn_reserve, percent, transaction_type, period_counter
                                                           , date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid ch_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, gar.deprn_method_code method, gar.life_in_months life,
                           gar.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_deprn_periods dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gad.super_group_id IS NULL
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           -- mwoodwar
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;      -- mwoodwar
            END IF;

            -- Insert the SuperGroup Depreciation Details
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (asset_id, dh_ccid, deprn_reserve_acct, date_placed_in_service, method_code, life, rate, capacity, cost, deprn_amount, ytd_deprn, deprn_reserve, percent, transaction_type, period_counter
                                                           , date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid dh_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, sgr.deprn_method_code method, gar.life_in_months life,
                           sgr.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary_mrc_v dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_super_group_rules sgr, fa_deprn_periods_mrc_v dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.super_group_id = sgr.super_group_id
                           AND gad.book_type_code = sgr.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date
                           AND sgr.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (sgr.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_t (asset_id, dh_ccid, deprn_reserve_acct, date_placed_in_service, method_code, life, rate, capacity, cost, deprn_amount, ytd_deprn, deprn_reserve, percent, transaction_type, period_counter
                                                           , date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid dh_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, sgr.deprn_method_code method, gar.life_in_months life,
                           sgr.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_super_group_rules sgr, fa_deprn_periods dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.super_group_id = sgr.super_group_id
                           AND gad.book_type_code = sgr.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date
                           AND sgr.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (sgr.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;
            END IF;
        END IF;                                             --end of CRL check

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error is: ' || SUBSTR (SQLERRM, 1, 200));
    END xxd_fa_rsvldg_proc;

    PROCEDURE get_balance (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                           , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2)
    IS
        p_date              DATE := period_date;
        a_date              DATE := additions_date;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --Commented by B T Technology v 4.0  on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;

            v_sob_id            := g_set_of_books_id;

            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            -- commented to display all columns for any reporting_flag by showkath 11/19/2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'In side the query1'
                        || 'distribution Book:'
                        || distribution_source_book
                        || ''
                        || 'book:'
                        || book
                        || ' '
                        || 'period pc:'
                        || period_pc
                        || ' '
                        || 'earliest_pc:'
                        || earliest_pc
                        || ''
                        || 'period_date:'
                        || period_date
                        || ' '
                        || 'additions_date :'
                        || additions_date
                        || ' report_type:'
                        || report_type
                        || 'balance_type'
                        || balance_type
                        || 'g from currency:'
                        || g_from_currency
                        || ' g to currency:'
                        || g_to_currency);

                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                        SELECT /*+ ORDERED */
                               dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve) * conversion_rate, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                                                                            report_type
                          FROM fa_deprn_detail dd, fa_distribution_history dh, fa_asset_history ah,
                               fa_category_books cb, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                           fa_books bk,
                               fa_deprn_periods fdp, gl_daily_rates gdr
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               AND fdp.book_type_code = book
                               AND fdp.period_counter = dd.period_counter
                               AND gdr.conversion_date =
                                   DECODE (
                                       begin_or_end,
                                       'BEGIN', fdp.calendar_period_open_date,
                                       fdp.calendar_period_close_date)
                               AND gdr.conversion_type = 'Spot'  --'Corporate'
                               AND gdr.from_currency = g_from_currency
                               AND gdr.to_currency = g_to_currency
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND fkv.location_id = dh.location_id
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'In side the query2'
                        || 'distribution Book:'
                        || distribution_source_book
                        || ''
                        || 'book:'
                        || book
                        || ' '
                        || 'period pc:'
                        || period_pc
                        || ' '
                        || 'earliest_pc:'
                        || earliest_pc
                        || ''
                        || 'period_date:'
                        || period_date
                        || ' '
                        || 'additions_date :'
                        || additions_date
                        || ' report_type:'
                        || report_type
                        || 'balance_type'
                        || balance_type
                        || 'g from currency:'
                        || g_from_currency
                        || ' g to currency:'
                        || g_to_currency);

                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                        SELECT /*+ ORDERED */
                               dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                          report_type
                          FROM fa_deprn_detail dd, fa_distribution_history dh, fa_asset_history ah,
                               fa_category_books cb, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                           fa_books bk
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND fkv.location_id = dh.location_id
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                END IF;
            END;
        --END IF;
        --END IF;
        ELSIF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            -- commented to display all columns for any reporting_flag by showkath 11/19/2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'In side the query3'
                        || 'distribution Book:'
                        || distribution_source_book
                        || ''
                        || 'book:'
                        || book
                        || ' '
                        || 'period pc:'
                        || period_pc
                        || ' '
                        || 'earliest_pc:'
                        || earliest_pc
                        || ''
                        || 'period_date:'
                        || period_date
                        || ' '
                        || 'additions_date :'
                        || additions_date
                        || ' report_type:'
                        || report_type
                        || 'balance_type'
                        || balance_type
                        || 'g from currency:'
                        || g_from_currency
                        || ' g to currency:'
                        || g_to_currency);

                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                        SELECT dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve) * conversion_rate, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                                                                            report_type
                          FROM fa_distribution_history dh, fa_deprn_detail dd, fa_asset_history ah,
                               fa_category_books cb, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                           fa_books bk,
                               fa_deprn_periods fdp, gl_daily_rates gdr
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               AND fdp.book_type_code = book
                               AND fdp.period_counter = DD.period_counter
                               AND gdr.conversion_date =
                                   DECODE (
                                       begin_or_end,
                                       'BEGIN', fdp.calendar_period_open_date,
                                       fdp.calendar_period_close_date)
                               AND gdr.conversion_type = 'Spot'  --'Corporate'
                               AND gdr.from_currency = g_from_currency
                               AND gdr.to_currency = g_to_currency
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (
                                       report_type,
                                       'CIP COST', dd.deprn_source_code,
                                       DECODE (begin_or_end,
                                               'BEGIN', dd.deprn_source_code,
                                               'D')) =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND fkv.location_id = dh.location_id
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL
                               -- start of CUA - This is to exclude the Group Asset Members
                               AND bk.group_asset_id IS NULL;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'In side the query4'
                        || 'distribution Book:'
                        || distribution_source_book
                        || ''
                        || 'book:'
                        || book
                        || ' '
                        || 'period pc:'
                        || period_pc
                        || ' '
                        || 'earliest_pc:'
                        || earliest_pc
                        || ''
                        || 'period_date:'
                        || period_date
                        || ' '
                        || 'additions_date :'
                        || additions_date
                        || ' report_type:'
                        || report_type
                        || 'balance_type'
                        || balance_type
                        || 'g from currency:'
                        || g_from_currency
                        || ' g to currency:'
                        || g_to_currency);

                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                        SELECT dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                          report_type
                          FROM fa_distribution_history dh, fa_deprn_detail dd, fa_asset_history ah,
                               fa_category_books cb, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                           fa_books bk
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (
                                       report_type,
                                       'CIP COST', dd.deprn_source_code,
                                       DECODE (begin_or_end,
                                               'BEGIN', dd.deprn_source_code,
                                               'D')) =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND fkv.location_id = dh.location_id
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL
                               -- start of CUA - This is to exclude the Group Asset Members
                               AND bk.group_asset_id IS NULL;
                END IF;
            END;
        --END IF;

        -- end of cua
        END IF;
    END get_balance;

    PROCEDURE get_balance_group_begin (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                       , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2)
    IS
        p_date              DATE := period_date;
        a_date              DATE := additions_date;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            --h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --         Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;

            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF (report_type NOT IN ('RESERVE'))
            THEN
                BEGIN
                    IF g_from_currency <> g_to_currency
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'In side the query5'
                            || 'distribution Book:'
                            || distribution_source_book
                            || ''
                            || 'book:'
                            || book
                            || ' '
                            || 'period pc:'
                            || period_pc
                            || ' '
                            || 'earliest_pc:'
                            || earliest_pc
                            || ''
                            || 'period_date:'
                            || period_date
                            || ' '
                            || 'additions_date :'
                            || additions_date
                            || ' report_type:'
                            || report_type
                            || 'balance_type'
                            || balance_type);

                        INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                        asset_id,
                                        distribution_ccid,
                                        adjustment_ccid,
                                        category_books_account,
                                        source_type_code,
                                        amount,
                                        amount_nonf,
                                        report_type,
                                        location)
                            SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                                   NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                                   DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve) * conversion_rate, report_type, fkv.concatenated_segments
                              FROM fa_books bk, fa_category_books cb, fa_asset_history ah,
                                   fa_deprn_detail dd, fa_distribution_history dh, fa_group_asset_default gad,
                                   fa_deprn_periods fdp, gl_daily_rates gdr, fa_locations_kfv fkv --Madhav 12/6
                             WHERE     gad.book_type_code = bk.book_type_code
                                   AND fdp.book_type_code = bk.book_type_code
                                   AND fdp.period_counter = DD.period_counter
                                   AND gdr.conversion_date =
                                       DECODE (
                                           begin_or_end,
                                           'BEGIN',   fdp.calendar_period_open_date
                                                    - 1,
                                           fdp.calendar_period_close_date)
                                   AND gdr.conversion_type = 'Spot' --'Corporate'
                                   AND gdr.from_currency = g_from_currency
                                   AND gdr.to_currency = g_to_currency
                                   AND gad.group_asset_id = bk.group_asset_id
                                   AND -- This is to include only the Group Asset Members
                                       bk.group_asset_id IS NOT NULL
                                   AND dh.book_type_code =
                                       distribution_source_book
                                   AND DECODE (dd.deprn_source_code,
                                               'D', p_date,
                                               a_date) BETWEEN dh.date_effective
                                                           AND NVL (
                                                                   dh.date_ineffective,
                                                                   SYSDATE)
                                   AND dd.asset_id = dh.asset_id
                                   AND dd.book_type_code = book
                                   AND dd.distribution_id =
                                       dh.distribution_id
                                   AND dd.period_counter <= period_pc
                                   AND DECODE (begin_or_end,
                                               'BEGIN', dd.deprn_source_code,
                                               'D') =
                                       dd.deprn_source_code
                                   AND dd.period_counter =
                                       (SELECT MAX (sub_dd.period_counter)
                                          FROM fa_deprn_detail sub_dd
                                         WHERE     sub_dd.book_type_code =
                                                   book
                                               AND sub_dd.distribution_id =
                                                   dh.distribution_id
                                               AND sub_dd.period_counter <=
                                                   period_pc)
                                   AND ah.asset_id = dh.asset_id
                                   AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                   AND DECODE (dd.deprn_source_code,
                                               'D', p_date,
                                               a_date) BETWEEN ah.date_effective
                                                           AND NVL (
                                                                   ah.date_ineffective,
                                                                   SYSDATE)
                                   AND cb.category_id = ah.category_id
                                   AND cb.book_type_code = book
                                   AND bk.book_type_code = book
                                   AND fkv.location_id = dh.location_id
                                   AND bk.asset_id = dd.asset_id
                                   AND (bk.transaction_header_id_in =
                                        (SELECT MIN (fab.transaction_header_id_in)
                                           FROM fa_books_groups bg, fa_books fab
                                          WHERE     bg.group_asset_id =
                                                    NVL (bk.group_asset_id,
                                                         -2)
                                                AND bg.book_type_code =
                                                    fab.book_type_code
                                                AND fab.transaction_header_id_in <=
                                                    bg.transaction_header_id_in
                                                AND NVL (
                                                        fab.transaction_header_id_out,
                                                        bg.transaction_header_id_in) >=
                                                    bg.transaction_header_id_in
                                                AND bg.period_counter =
                                                    period_pc + 1
                                                AND fab.asset_id =
                                                    bk.asset_id
                                                AND fab.book_type_code =
                                                    bk.book_type_code
                                                AND bg.beginning_balance_flag
                                                        IS NOT NULL))
                                   AND DECODE (
                                           report_type,
                                           'COST', DECODE (
                                                       ah.asset_type,
                                                       'CAPITALIZED', cb.asset_cost_acct,
                                                       NULL),
                                           'CIP COST', DECODE (
                                                           ah.asset_type,
                                                           'CIP', cb.cip_cost_acct,
                                                           NULL),
                                           'RESERVE', cb.deprn_reserve_acct,
                                           'REVAL RESERVE', cb.reval_reserve_acct)
                                           IS NOT NULL;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'In side the query6'
                            || 'distribution Book:'
                            || distribution_source_book
                            || ''
                            || 'book:'
                            || book
                            || ' '
                            || 'period pc:'
                            || period_pc
                            || ' '
                            || 'earliest_pc:'
                            || earliest_pc
                            || ''
                            || 'period_date:'
                            || period_date
                            || ' '
                            || 'additions_date :'
                            || additions_date
                            || ' report_type:'
                            || report_type
                            || 'balance_type'
                            || balance_type);

                        INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                        asset_id,
                                        distribution_ccid,
                                        adjustment_ccid,
                                        category_books_account,
                                        source_type_code,
                                        amount,
                                        report_type,
                                        location)
                            SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                                   NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                                   report_type, fkv.concatenated_segments
                              FROM fa_books bk, fa_category_books cb, fa_asset_history ah,
                                   fa_deprn_detail dd, fa_distribution_history dh, fa_group_asset_default gad,
                                   fa_locations_kfv fkv
                             WHERE     gad.book_type_code = bk.book_type_code
                                   AND gad.group_asset_id = bk.group_asset_id
                                   AND fkv.location_id = dh.location_id
                                   AND -- This is to include only the Group Asset Members
                                       bk.group_asset_id IS NOT NULL
                                   AND dh.book_type_code =
                                       distribution_source_book
                                   AND DECODE (dd.deprn_source_code,
                                               'D', p_date,
                                               a_date) BETWEEN dh.date_effective
                                                           AND NVL (
                                                                   dh.date_ineffective,
                                                                   SYSDATE)
                                   AND dd.asset_id = dh.asset_id
                                   AND dd.book_type_code = book
                                   AND dd.distribution_id =
                                       dh.distribution_id
                                   AND dd.period_counter <= period_pc
                                   AND DECODE (begin_or_end,
                                               'BEGIN', dd.deprn_source_code,
                                               'D') =
                                       dd.deprn_source_code
                                   AND dd.period_counter =
                                       (SELECT MAX (sub_dd.period_counter)
                                          FROM fa_deprn_detail sub_dd
                                         WHERE     sub_dd.book_type_code =
                                                   book
                                               AND sub_dd.distribution_id =
                                                   dh.distribution_id
                                               AND sub_dd.period_counter <=
                                                   period_pc)
                                   AND ah.asset_id = dh.asset_id
                                   AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                   AND DECODE (dd.deprn_source_code,
                                               'D', p_date,
                                               a_date) BETWEEN ah.date_effective
                                                           AND NVL (
                                                                   ah.date_ineffective,
                                                                   SYSDATE)
                                   AND cb.category_id = ah.category_id
                                   AND cb.book_type_code = book
                                   AND bk.book_type_code = book
                                   AND bk.asset_id = dd.asset_id
                                   AND (bk.transaction_header_id_in =
                                        (SELECT MIN (fab.transaction_header_id_in)
                                           FROM fa_books_groups bg, fa_books fab
                                          WHERE     bg.group_asset_id =
                                                    NVL (bk.group_asset_id,
                                                         -2)
                                                AND bg.book_type_code =
                                                    fab.book_type_code
                                                AND fab.transaction_header_id_in <=
                                                    bg.transaction_header_id_in
                                                AND NVL (
                                                        fab.transaction_header_id_out,
                                                        bg.transaction_header_id_in) >=
                                                    bg.transaction_header_id_in
                                                AND bg.period_counter =
                                                    period_pc + 1
                                                AND fab.asset_id =
                                                    bk.asset_id
                                                AND fab.book_type_code =
                                                    bk.book_type_code
                                                AND bg.beginning_balance_flag
                                                        IS NOT NULL))
                                   AND DECODE (
                                           report_type,
                                           'COST', DECODE (
                                                       ah.asset_type,
                                                       'CAPITALIZED', cb.asset_cost_acct,
                                                       NULL),
                                           'CIP COST', DECODE (
                                                           ah.asset_type,
                                                           'CIP', cb.cip_cost_acct,
                                                           NULL),
                                           'RESERVE', cb.deprn_reserve_acct,
                                           'REVAL RESERVE', cb.reval_reserve_acct)
                                           IS NOT NULL;
                    END IF;
                --END IF;
                END;
            ELSE
                BEGIN
                    IF g_from_currency <> g_to_currency
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'In side the query7'
                            || 'distribution Book:'
                            || distribution_source_book
                            || ''
                            || 'book:'
                            || book
                            || ' '
                            || 'period pc:'
                            || period_pc
                            || ' '
                            || 'earliest_pc:'
                            || earliest_pc
                            || ''
                            || 'period_date:'
                            || period_date
                            || ' '
                            || 'additions_date :'
                            || additions_date
                            || ' report_type:'
                            || report_type
                            || 'balance_type'
                            || balance_type);

                        INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                        asset_id,
                                        distribution_ccid,
                                        adjustment_ccid,
                                        category_books_account,
                                        source_type_code,
                                        amount,
                                        amount_nonf,
                                        report_type)
                            SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                   NULL, 'BEGIN', dd.deprn_reserve,
                                   dd.deprn_reserve * conversion_rate, report_type
                              FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                                   fa_deprn_periods fdp, gl_daily_rates gdr
                             WHERE     dd.book_type_code = book
                                   AND fdp.book_type_code = dd.book_type_code
                                   AND fdp.period_counter = dd.period_counter
                                   AND gdr.conversion_date =
                                       DECODE (
                                           begin_or_end,
                                           'BEGIN',   fdp.calendar_period_open_date
                                                    - 1,
                                           fdp.calendar_period_close_date)
                                   AND gdr.conversion_type = 'Spot' --'Corporate'
                                   AND gdr.from_currency = g_from_currency
                                   AND gdr.to_currency = g_to_currency
                                   AND dd.asset_id = gar.group_asset_id
                                   AND gar.book_type_code = dd.book_type_code
                                   AND gad.book_type_code =
                                       gar.book_type_code
                                   AND gad.group_asset_id =
                                       gar.group_asset_id
                                   AND dd.period_counter =
                                       (SELECT MAX (dd_sub.period_counter)
                                          FROM fa_deprn_detail dd_sub
                                         WHERE     dd_sub.book_type_code =
                                                   book
                                               AND dd_sub.asset_id =
                                                   gar.group_asset_id
                                               AND dd_sub.period_counter <=
                                                   period_pc);
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'In side the query8'
                            || 'distribution Book:'
                            || distribution_source_book
                            || ''
                            || 'book:'
                            || book
                            || ' '
                            || 'period pc:'
                            || period_pc
                            || ' '
                            || 'earliest_pc:'
                            || earliest_pc
                            || ''
                            || 'period_date:'
                            || period_date
                            || ' '
                            || 'additions_date :'
                            || additions_date
                            || ' report_type:'
                            || report_type
                            || 'balance_type'
                            || balance_type);

                        INSERT INTO xxdo.xxd_fa_roll_fwd_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                            SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                   NULL, 'BEGIN', dd.deprn_reserve,
                                   report_type
                              FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad
                             WHERE     dd.book_type_code = book
                                   AND dd.asset_id = gar.group_asset_id
                                   AND gar.book_type_code = dd.book_type_code
                                   AND gad.book_type_code =
                                       gar.book_type_code
                                   AND gad.group_asset_id =
                                       gar.group_asset_id
                                   AND dd.period_counter =
                                       (SELECT MAX (dd_sub.period_counter)
                                          FROM fa_deprn_detail dd_sub
                                         WHERE     dd_sub.book_type_code =
                                                   book
                                               AND dd_sub.asset_id =
                                                   gar.group_asset_id
                                               AND dd_sub.period_counter <=
                                                   period_pc);
                    END IF;
                END;
            -- END IF;
            --NULL;
            END IF;
        END IF;                                             --end of CRL check
    END get_balance_group_begin;

    PROCEDURE get_balance_group_end (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                     , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2)
    IS
        p_date              DATE := period_date;
        a_date              DATE := additions_date;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            --h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF report_type NOT IN ('RESERVE')
            THEN
                BEGIN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    report_type,
                                    location)
                        SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                               NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               report_type, fkv.concatenated_segments
                          FROM fa_books bk, fa_category_books cb, fa_asset_history ah,
                               fa_deprn_detail dd, fa_distribution_history dh, fa_group_asset_default gad,
                               fa_locations_kfv fkv
                         WHERE     gad.book_type_code = bk.book_type_code
                               AND gad.group_asset_id = bk.group_asset_id
                               AND fkv.location_id = dh.location_id
                               -- This is to include only the Group Asset Members
                               AND bk.group_asset_id IS NOT NULL
                               AND dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = book
                               AND bk.book_type_code = book
                               AND bk.asset_id = dd.asset_id
                               AND (bk.transaction_header_id_in =
                                    (SELECT MIN (fab.transaction_header_id_in)
                                       FROM fa_books_groups bg, fa_books fab
                                      WHERE     bg.group_asset_id =
                                                NVL (bk.group_asset_id, -2)
                                            AND bg.book_type_code =
                                                fab.book_type_code
                                            AND fab.transaction_header_id_in <=
                                                bg.transaction_header_id_in
                                            AND NVL (
                                                    fab.transaction_header_id_out,
                                                    bg.transaction_header_id_in) >=
                                                bg.transaction_header_id_in
                                            AND bg.period_counter =
                                                period_pc + 1
                                            AND fab.asset_id = bk.asset_id
                                            AND fab.book_type_code =
                                                bk.book_type_code
                                            AND bg.beginning_balance_flag
                                                    IS NOT NULL))
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                END;
            --END IF;
            ELSE
                BEGIN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                        , report_type)
                        SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                               NULL, 'END', dd.deprn_reserve,
                               report_type
                          FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad
                         WHERE     dd.book_type_code = book
                               AND dd.asset_id = gar.group_asset_id
                               AND gar.book_type_code = dd.book_type_code
                               AND gad.book_type_code = gar.book_type_code
                               AND gad.group_asset_id = gar.group_asset_id
                               AND dd.period_counter =
                                   (SELECT MAX (dd_sub.period_counter)
                                      FROM fa_deprn_detail dd_sub
                                     WHERE     dd_sub.book_type_code = book
                                           AND dd_sub.asset_id =
                                               gar.group_asset_id
                                           AND dd_sub.period_counter <=
                                               period_pc);
                END;
            --END IF;
            END IF;
        END IF;                                            -- end of CRL check
    END get_balance_group_end;

    PROCEDURE get_adjustments (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                               , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2)
    IS
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);

            /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'h_set_of_books_id:' || h_set_of_books_id);*/


            IF (h_set_of_books_id = -1)
            THEN
                h_set_of_books_id   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            SELECT set_of_books_id
              INTO h_set_of_books_id
              FROM fa_book_controls
             WHERE book_type_code = book;

            h_reporting_flag   := 'P';
        END IF;

        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount * conversion_rate) amount_nonf, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                                           report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                 fa_transaction_headers th, fa_asset_history ah, fa_adjustments aj,
                                 xla_ae_headers headers, xla_ae_lines lines, xla_distribution_links links,
                                 fa_deprn_periods fdp, gl_daily_rates gdr
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter =
                                     aj.period_counter_created
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                                 AND fkv.location_id = dh.location_id --Added by BT Technology Team v4.1 on 18-Dec-2014
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                 report_type;
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                            report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                 fa_transaction_headers th, fa_asset_history ah, fa_adjustments aj,
                                 xla_ae_headers headers, xla_ae_lines lines, xla_distribution_links links
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                                 AND fkv.location_id = dh.location_id --Added by BT Technology Team v4.1 on 18-Dec-2014
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                 report_type;
                END IF;
            END;
        --END IF;
        ELSIF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount * conversion_rate), fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                               report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                 fa_transaction_headers th, fa_asset_history ah, fa_adjustments aj,
                                 xla_ae_headers headers, xla_ae_lines lines, xla_distribution_links links,
                                 fa_deprn_periods fdp, gl_daily_rates gdr
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter =
                                     aj.period_counter_created
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 -- start of cua
                                 AND NOT EXISTS
                                         (SELECT 'x'
                                            FROM fa_books bks
                                           WHERE     bks.book_type_code = book
                                                 AND bks.asset_id = aj.asset_id
                                                 AND bks.group_asset_id
                                                         IS NOT NULL
                                                 AND bks.date_ineffective
                                                         IS NOT NULL)
                                 -- end of cua
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                                 AND fkv.location_id = dh.location_id --Added by BT Technology Team v4.1 on 18-Dec-2014
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                 report_type;
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                            report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                 fa_transaction_headers th, fa_asset_history ah, fa_adjustments aj,
                                 xla_ae_headers headers, xla_ae_lines lines, xla_distribution_links links
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 -- start of cua
                                 AND NOT EXISTS
                                         (SELECT 'x'
                                            FROM fa_books bks
                                           WHERE     bks.book_type_code = book
                                                 AND bks.asset_id = aj.asset_id
                                                 AND bks.group_asset_id
                                                         IS NOT NULL
                                                 AND bks.date_ineffective
                                                         IS NOT NULL)
                                 -- end of cua
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                                 AND fkv.location_id = dh.location_id --Added by BT Technology Team v4.1 on 18-Dec-2014
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                 report_type;
                END IF;
            END;
        --END IF;
        END IF;

        IF report_type = 'RESERVE'
        THEN
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, NULL,
                                 cb.deprn_reserve_acct, 'ADDITION', SUM (dd.deprn_reserve),
                                 fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                            report_type
                            FROM fa_distribution_history dh, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                   fa_category_books cb,
                                 fa_asset_history ah, fa_deprn_detail dd, fa_deprn_periods fdp,
                                 gl_daily_rates gdr
                           WHERE     NOT EXISTS
                                         (SELECT asset_id
                                            FROM xxdo.xxd_fa_roll_fwd_t
                                           WHERE     asset_id = dh.asset_id
                                                 AND distribution_ccid =
                                                     dh.code_combination_id
                                                 AND source_type_code =
                                                     'ADDITION')
                                 AND dd.book_type_code = book
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter = DD.period_counter
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 AND (dd.period_counter + 1) BETWEEN period1_pc
                                                                 AND period2_pc
                                 AND dd.deprn_source_code = 'B'
                                 AND dd.asset_id = dh.asset_id
                                 AND dd.deprn_reserve != 0
                                 AND dd.distribution_id = dh.distribution_id
                                 AND dh.asset_id = ah.asset_id
                                 AND ah.date_effective <
                                     NVL (dh.date_ineffective, SYSDATE)
                                 AND NVL (dh.date_ineffective, SYSDATE) <=
                                     NVL (ah.date_ineffective, SYSDATE)
                                 AND dd.book_type_code = cb.book_type_code
                                 AND ah.category_id = cb.category_id
                                 AND fkv.location_id = dh.location_id --Added by BT Technology Team v4.1 on 18-Dec-2014
                        GROUP BY dh.asset_id, dh.code_combination_id, cb.deprn_reserve_acct,
                                 fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                            report_type;
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    location, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, NULL,
                                 cb.deprn_reserve_acct, 'ADDITION', SUM (dd.deprn_reserve),
                                 fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                            report_type
                            FROM fa_distribution_history dh, fa_locations_kfv fkv, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                   fa_category_books cb,
                                 fa_asset_history ah, fa_deprn_detail dd
                           WHERE     NOT EXISTS
                                         (SELECT asset_id
                                            FROM xxdo.xxd_fa_roll_fwd_t
                                           WHERE     asset_id = dh.asset_id
                                                 AND distribution_ccid =
                                                     dh.code_combination_id
                                                 AND source_type_code =
                                                     'ADDITION')
                                 AND dd.book_type_code = book
                                 AND (dd.period_counter + 1) BETWEEN period1_pc
                                                                 AND period2_pc
                                 AND dd.deprn_source_code = 'B'
                                 AND dd.asset_id = dh.asset_id
                                 AND dd.deprn_reserve != 0
                                 AND dd.distribution_id = dh.distribution_id
                                 AND dh.asset_id = ah.asset_id
                                 AND ah.date_effective <
                                     NVL (dh.date_ineffective, SYSDATE)
                                 AND NVL (dh.date_ineffective, SYSDATE) <=
                                     NVL (ah.date_ineffective, SYSDATE)
                                 AND dd.book_type_code = cb.book_type_code
                                 AND ah.category_id = cb.category_id
                                 AND fkv.location_id = dh.location_id --Added by BT Technology Team v4.1 on 18-Dec-2014
                        GROUP BY dh.asset_id, dh.code_combination_id, cb.deprn_reserve_acct,
                                 fkv.concatenated_segments, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                            report_type;
                END IF;
            END;
        -- END IF;
        END IF;
    END get_adjustments;

    PROCEDURE get_adjustments_for_group (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                                         , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2)
    IS
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);

            /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'h_set_of_books_id:' || h_set_of_books_id);*/



            IF (h_set_of_books_id = -1)
            THEN
                h_set_of_books_id   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            SELECT set_of_books_id
              INTO h_set_of_books_id
              FROM fa_book_controls
             WHERE book_type_code = book;

            h_reporting_flag   := 'P';
        END IF;

        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            BEGIN
                INSERT INTO xxdo.xxd_fa_roll_fwd_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                    , report_type)
                      SELECT aj.asset_id, gad.deprn_expense_acct_ccid, DECODE (aj.adjustment_type, 'COST', gad.asset_cost_acct_ccid, lines.code_combination_id),
                             NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                             report_type
                        FROM fa_lookups rt, fa_adjustments aj, fa_books bk,
                             fa_group_asset_default gad, xla_ae_headers headers, xla_ae_lines lines,
                             xla_distribution_links links
                       WHERE     bk.asset_id = aj.asset_id
                             AND bk.book_type_code = book
                             AND bk.group_asset_id = gad.group_asset_id
                             AND bk.book_type_code = gad.book_type_code
                             AND bk.date_ineffective IS NULL
                             AND aj.asset_id IN
                                     (SELECT asset_id
                                        FROM fa_books
                                       WHERE     group_asset_id IS NOT NULL
                                             AND date_ineffective IS NULL)
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND rt.lookup_code = report_type
                             AND aj.asset_id = bk.asset_id
                             AND aj.book_type_code = book
                             AND aj.adjustment_type IN
                                     (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                             AND aj.period_counter_created BETWEEN period1_pc
                                                               AND period2_pc
                             AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                 0
                             AND links.source_distribution_id_num_1 =
                                 aj.transaction_header_id
                             AND links.source_distribution_id_num_2 =
                                 aj.adjustment_line_id
                             AND links.application_id = 140
                             AND links.source_distribution_type = 'TRX'
                             AND headers.application_id = 140
                             AND headers.ae_header_id = links.ae_header_id
                             AND headers.ledger_id = h_set_of_books_id
                             AND lines.ae_header_id = links.ae_header_id
                             AND lines.ae_line_num = links.ae_line_num
                             AND lines.application_id = 140
                    GROUP BY aj.asset_id, gad.deprn_expense_acct_ccid, DECODE (aj.adjustment_type, 'COST', gad.asset_cost_acct_ccid, lines.code_combination_id),
                             aj.source_type_code, report_type;
            END;
        -- END IF;
        END IF;
    END get_adjustments_for_group;

    PROCEDURE get_deprn_effects (book                       IN VARCHAR2,
                                 distribution_source_book   IN VARCHAR2,
                                 period1_pc                 IN NUMBER,
                                 period2_pc                 IN NUMBER,
                                 report_type                IN VARCHAR2)
    IS
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        BEGIN
            IF g_to_currency <> g_from_currency
            THEN
                INSERT INTO xxdo.xxd_fa_roll_fwd_t (asset_id,
                                                    distribution_ccid,
                                                    adjustment_ccid,
                                                    category_books_account,
                                                    source_type_code,
                                                    amount,
                                                    amount_nonf,
                                                    report_type,
                                                    location)
                      SELECT dh.asset_id, dh.code_combination_id, NULL,
                             DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (dd.deprn_source_code, 'D', 'DEPRECIATION', 'ADDITION'), SUM (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - DECODE (adj.debit_credit_flag, 'DR', 1, -1) * NVL (adj.adjustment_amount, 0),  'REVAL RESERVE', -dd.reval_amortization)),
                             SUM (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - DECODE (adj.debit_credit_flag, 'DR', 1, -1) * NVL (adj.adjustment_amount, 0),  'REVAL RESERVE', -dd.reval_amortization) * conversion_rate), report_type, fkv.concatenated_segments
                        FROM fa_lookups_b rt, fa_category_books cb, fa_distribution_history dh,
                             fa_asset_history ah, fa_deprn_detail dd, fa_deprn_periods dp,
                             fa_adjustments adj, fa_deprn_periods fdp, gl_daily_rates gdr,
                             fa_locations_kfv fkv
                       WHERE     dh.book_type_code = distribution_source_book
                             AND fkv.location_id = dh.location_id
                             AND fdp.book_type_code = book
                             AND fdp.period_counter = dd.period_counter
                             AND gdr.conversion_date =
                                 fdp.calendar_period_open_date
                             AND gdr.conversion_type = 'Corporate'
                             AND gdr.from_currency = g_from_currency
                             AND gdr.to_currency = g_to_currency
                             AND ah.asset_id = dh.asset_id
                             AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                             AND ah.date_effective <
                                 NVL (dh.date_ineffective, SYSDATE)
                             AND NVL (dh.date_ineffective, SYSDATE) <=
                                 NVL (ah.date_ineffective, SYSDATE)
                             AND cb.category_id = ah.category_id
                             AND cb.book_type_code = book
                             AND ((dd.deprn_source_code = 'B' AND (dd.period_counter + 1) < period2_pc) OR (dd.deprn_source_code = 'D'))
                             AND dd.book_type_code || '' = book
                             AND dd.asset_id = dh.asset_id
                             AND dd.distribution_id = dh.distribution_id
                             AND dd.period_counter BETWEEN period1_pc
                                                       AND period2_pc
                             AND dp.book_type_code = dd.book_type_code
                             AND dp.period_counter = dd.period_counter
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND DECODE (
                                     rt.lookup_code,
                                     'RESERVE', cb.deprn_reserve_acct,
                                     'REVAL RESERVE', cb.reval_reserve_acct)
                                     IS NOT NULL
                             AND (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount,  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0 OR DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - NVL (dd.deprn_adjustment_amount, 0),  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0)
                             AND adj.asset_id(+) = dd.asset_id
                             AND adj.book_type_code(+) = dd.book_type_code
                             AND adj.period_counter_created(+) =
                                 dd.period_counter
                             AND adj.distribution_id(+) = dd.distribution_id
                             AND adj.source_type_code(+) = 'REVALUATION'
                             AND adj.adjustment_type(+) = 'EXPENSE'
                             AND adj.adjustment_amount(+) <> 0
                    GROUP BY dh.asset_id, dh.code_combination_id, DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct),
                             dd.deprn_source_code, report_type, fkv.concatenated_segments;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_fwd_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                    , report_type, location)
                      SELECT dh.asset_id, dh.code_combination_id, NULL,
                             DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (dd.deprn_source_code, 'D', 'DEPRECIATION', 'ADDITION'), SUM (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - DECODE (adj.debit_credit_flag, 'DR', 1, -1) * NVL (adj.adjustment_amount, 0),  'REVAL RESERVE', -dd.reval_amortization)),
                             report_type, fkv.concatenated_segments
                        FROM fa_lookups_b rt, fa_category_books cb, fa_distribution_history dh,
                             fa_asset_history ah, fa_deprn_detail dd, fa_deprn_periods dp,
                             fa_adjustments adj, fa_locations_kfv fkv
                       WHERE     dh.book_type_code = distribution_source_book
                             AND fkv.location_id = dh.location_id
                             AND ah.asset_id = dh.asset_id
                             AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                             AND ah.date_effective <
                                 NVL (dh.date_ineffective, SYSDATE)
                             AND NVL (dh.date_ineffective, SYSDATE) <=
                                 NVL (ah.date_ineffective, SYSDATE)
                             AND cb.category_id = ah.category_id
                             AND cb.book_type_code = book
                             AND ((dd.deprn_source_code = 'B' AND (dd.period_counter + 1) < period2_pc) OR (dd.deprn_source_code = 'D'))
                             AND dd.book_type_code || '' = book
                             AND dd.asset_id = dh.asset_id
                             AND dd.distribution_id = dh.distribution_id
                             AND dd.period_counter BETWEEN period1_pc
                                                       AND period2_pc
                             AND dp.book_type_code = dd.book_type_code
                             AND dp.period_counter = dd.period_counter
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND DECODE (
                                     rt.lookup_code,
                                     'RESERVE', cb.deprn_reserve_acct,
                                     'REVAL RESERVE', cb.reval_reserve_acct)
                                     IS NOT NULL
                             AND (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount,  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0 OR DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - NVL (dd.deprn_adjustment_amount, 0),  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0)
                             AND adj.asset_id(+) = dd.asset_id
                             AND adj.book_type_code(+) = dd.book_type_code
                             AND adj.period_counter_created(+) =
                                 dd.period_counter
                             AND adj.distribution_id(+) = dd.distribution_id
                             AND adj.source_type_code(+) = 'REVALUATION'
                             AND adj.adjustment_type(+) = 'EXPENSE'
                             AND adj.adjustment_amount(+) <> 0
                    GROUP BY dh.asset_id, dh.code_combination_id, DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct),
                             dd.deprn_source_code, report_type, fkv.concatenated_segments;
            END IF;
        END;

        --END IF;

        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf,
                                    report_type)
                          SELECT dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', SUM (dd.deprn_amount),
                                 SUM (dd.deprn_amount * conversion_rate), report_type
                            FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                                 fa_deprn_periods fdp, gl_daily_rates gdr
                           WHERE     dd.book_type_code = book
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter = dd.period_counter
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 AND dd.asset_id = gar.group_asset_id
                                 AND gar.book_type_code = dd.book_type_code
                                 AND gad.book_type_code = gar.book_type_code
                                 AND gad.group_asset_id = gar.group_asset_id
                                 AND dd.period_counter BETWEEN period1_pc
                                                           AND period2_pc
                        GROUP BY dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', report_type;
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                        , report_type)
                          SELECT dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', SUM (dd.deprn_amount),
                                 report_type
                            FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad
                           WHERE     dd.book_type_code = book
                                 AND dd.asset_id = gar.group_asset_id
                                 AND gar.book_type_code = dd.book_type_code
                                 AND gad.book_type_code = gar.book_type_code
                                 AND gad.group_asset_id = gar.group_asset_id
                                 AND dd.period_counter BETWEEN period1_pc
                                                           AND period2_pc
                        GROUP BY dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', report_type;
                END IF;
            END;
        -- END IF;
        END IF;                                            -- end of CRL check
    END get_deprn_effects;

    PROCEDURE insert_info (book IN VARCHAR2, start_period_name IN VARCHAR2, end_period_name IN VARCHAR2
                           , report_type IN VARCHAR2, adj_mode IN VARCHAR2)
    IS
        period1_pc                 NUMBER;
        period1_pod                DATE;
        period1_pcd                DATE;
        period2_pc                 NUMBER;
        period2_pcd                DATE;
        distribution_source_book   VARCHAR2 (15);
        balance_type               VARCHAR2 (2);
        h_set_of_books_id          NUMBER;
        h_reporting_flag           VARCHAR2 (1);
        v_sob_id                   VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        IF (h_reporting_flag = 'R')
        THEN
            SELECT p1.period_counter, p1.period_open_date, NVL (p1.period_close_date, SYSDATE),
                   p2.period_counter, NVL (p2.period_close_date, SYSDATE), bc.distribution_source_book
              INTO period1_pc, period1_pod, period1_pcd, period2_pc,
                             period2_pcd, distribution_source_book
              FROM fa_deprn_periods_mrc_v p1, fa_deprn_periods_mrc_v p2, fa_book_controls_mrc_v bc
             WHERE     bc.book_type_code = book
                   AND p1.book_type_code = book
                   AND p1.period_name = start_period_name
                   AND p2.book_type_code = book
                   AND p2.period_name = end_period_name;
        ELSE
            SELECT p1.period_counter, p1.period_open_date, NVL (p1.period_close_date, SYSDATE),
                   p2.period_counter, NVL (p2.period_close_date, SYSDATE), bc.distribution_source_book
              INTO period1_pc, period1_pod, period1_pcd, period2_pc,
                             period2_pcd, distribution_source_book
              FROM fa_deprn_periods p1, fa_deprn_periods p2, fa_book_controls bc
             WHERE     bc.book_type_code = book
                   AND p1.book_type_code = book
                   AND p1.period_name = start_period_name
                   AND p2.book_type_code = book
                   AND p2.period_name = end_period_name;
        END IF;

        IF (report_type = 'RESERVE' OR report_type = 'REVAL RESERVE')
        THEN
            balance_type   := 'CR';                                    --'CR';
        ELSE
            balance_type   := 'DR';                                    --'DR';
        END IF;

        DELETE FROM fa_lookups_b
              WHERE lookup_type = 'REPORT TYPE' AND lookup_code = report_type;

        DELETE FROM fa_lookups_tl
              WHERE lookup_type = 'REPORT TYPE' AND lookup_code = report_type;

        INSERT INTO fa_lookups_b (lookup_type, lookup_code, last_updated_by,
                                  last_update_date, enabled_flag)
             VALUES ('REPORT TYPE', report_type, 1,
                     SYSDATE, 'Y');

        INSERT INTO fa_lookups_tl (lookup_type, lookup_code, meaning,
                                   last_update_date, last_updated_by, language
                                   , source_lang)
            SELECT 'REPORT TYPE', report_type, report_type,
                   SYSDATE, 1, l.language_code,
                   USERENV ('LANG')
              FROM fnd_languages l
             WHERE     l.installed_flag IN ('I', 'B')
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM fa_lookups_tl t
                             WHERE     t.lookup_type = 'REPORT TYPE'
                                   AND t.lookup_code = report_type
                                   AND t.language = l.language_code);

        /* Get Beginning Balance */
        /* Use Period1_PC-1, to get balance as of end of period immediately
        preceding Period1_PC */
        get_balance (book, distribution_source_book, period1_pc - 1,
                     period1_pc - 1, period1_pod, period1_pcd,
                     report_type, balance_type, 'BEGIN');

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            get_balance_group_begin (book, distribution_source_book, period1_pc - 1, period1_pc - 1, period1_pod, period1_pcd
                                     , report_type, balance_type, 'BEGIN');
        END IF;

        /* Get Ending Balance */
        get_balance (book, distribution_source_book, period2_pc,
                     period1_pc - 1, period2_pcd, period2_pcd,
                     report_type, balance_type, 'END');

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            get_balance_group_end (book, distribution_source_book, period2_pc, period1_pc - 1, period2_pcd, period2_pcd
                                   , report_type, balance_type, 'END');
        END IF;

        get_adjustments (book, distribution_source_book, period1_pc,
                         period2_pc, report_type, balance_type);

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            get_adjustments_for_group (book,
                                       distribution_source_book,
                                       period1_pc,
                                       period2_pc,
                                       report_type,
                                       balance_type);
        END IF;

        IF (report_type = 'RESERVE' OR report_type = 'REVAL RESERVE')
        THEN
            get_deprn_effects (book, distribution_source_book, period1_pc,
                               period2_pc, report_type);
        END IF;
    END insert_info;

    FUNCTION xxd_fa_cap_asset (pn_asset_id IN NUMBER, p_book IN VARCHAR2)
        RETURN NUMBER
    IS
        vn_asset_id   NUMBER;
    BEGIN
        SELECT DISTINCT fa.asset_id
          INTO vn_asset_id
          FROM apps.fa_additions fa, apps.fa_asset_history fah, fa_category_books fcb,
               pa_project_assets_all apa
         WHERE     fa.asset_id = fah.asset_id
               AND fa.asset_category_id = fah.category_id
               AND fcb.category_id = fa.asset_category_id
               AND fa.asset_id = pn_asset_id
               AND fcb.book_type_code = p_book
               --AND fah.date_ineffective IS NOT NULL
               AND apa.asset_number = fa.asset_number
               --AND REVERSAL_DATE is NULL
               AND reverse_flag = 'N'
               AND FAH.ASSET_TYPE = 'CAPITALIZED';

        fnd_file.put_line (fnd_file.LOG, 'Project CIP Asset:' || pn_asset_id);

        RETURN vn_asset_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            SELECT DISTINCT fah.asset_id
              INTO vn_asset_id
              FROM fa_asset_history fah, fa_books fb
             WHERE     fah.asset_id = fb.asset_id
                   AND fah.transaction_header_id_in =
                       fb.transaction_header_id_in
                   AND fb.book_type_code = p_book
                   AND fah.asset_type = 'CIP'
                   AND fah.asset_id = pn_asset_id;

            RETURN vn_asset_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Project CIP Asset:' || pn_asset_id);
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    FUNCTION xxd_fa_depreciation_cost (pn_asset_id         IN NUMBER,
                                       pv_book_type_code   IN VARCHAR2)
        RETURN NUMBER
    IS
        dummy_num               NUMBER := 0;
        dummy_char              VARCHAR2 (2000);
        dummy_bool              BOOLEAN;
        ln_asset_id             NUMBER := pn_asset_id;
        lv_book_type_code       VARCHAR2 (20) := pv_book_type_code;
        ln_deprn_reserve        NUMBER := 0;
        --BT 1.1
        l_log_level_rec         fa_api_types.log_level_rec_type;
        ln_ytd_impairment       NUMBER;
        ln_impairment_amount    NUMBER;
        ln_capital_adjustment   NUMBER;
        ln_general_fund         NUMBER;
        ln_impairment_rsv       NUMBER;
        h_set_of_books_id       NUMBER;
        h_reporting_flag        VARCHAR2 (1);
        v_sob_id                VARCHAR2 (100);
    --End BT 1.1
    BEGIN
        BEGIN
            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            SELECT set_of_books_id
              INTO h_set_of_books_id
              FROM fa_book_controls
             WHERE book_type_code = lv_book_type_code;

            h_reporting_flag   := 'P';
        END IF;

        apps.fa_query_balances_pkg.query_balances (
            x_asset_id                => ln_asset_id,
            x_book                    => lv_book_type_code,
            x_period_ctr              => 0,
            x_dist_id                 => 0,
            x_run_mode                => 'STANDARD',
            x_cost                    => dummy_num,
            x_deprn_rsv               => ln_deprn_reserve,
            x_reval_rsv               => dummy_num,
            x_ytd_deprn               => dummy_num,
            x_ytd_reval_exp           => dummy_num,
            x_reval_deprn_exp         => dummy_num,
            x_deprn_exp               => dummy_num,
            x_reval_amo               => dummy_num,
            x_prod                    => dummy_num,
            x_ytd_prod                => dummy_num,
            x_ltd_prod                => dummy_num,
            x_adj_cost                => dummy_num,
            x_reval_amo_basis         => dummy_num,
            x_bonus_rate              => dummy_num,
            x_deprn_source_code       => dummy_char,
            x_adjusted_flag           => dummy_bool,
            x_transaction_header_id   => -1,
            x_bonus_deprn_rsv         => dummy_num,
            x_bonus_ytd_deprn         => dummy_num,
            x_bonus_deprn_amount      => dummy_num                    --BT 1.1
                                                  ,
            x_impairment_rsv          => ln_impairment_rsv,
            x_ytd_impairment          => ln_ytd_impairment,
            x_impairment_amount       => ln_impairment_amount,
            x_capital_adjustment      => ln_capital_adjustment,
            x_general_fund            => ln_general_fund,
            x_mrc_sob_type_code       => h_reporting_flag,
            x_set_of_books_id         => h_set_of_books_id,
            p_log_level_rec           => l_log_level_rec          --End BT 1.1
                                                        );
        RETURN (NVL (ln_deprn_reserve, 0));
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                'Function Returned Exception: ' || SUBSTR (SQLERRM, 1, 200));
            RETURN (0);
    END;

    PROCEDURE xxd_fa_net_book_value (pn_asset_id IN NUMBER, pn_book VARCHAR2)
    IS
        vn_asset_id     NUMBER;
        vn_asset_id1    NUMBER;
        ln_count        NUMBER;
        v_cost          NUMBER;
        v_dep_reserve   NUMBER;
        v_nbv           NUMBER;
        v_impairment    NUMBER;                                         --v4.1
    --Retrofit v 4.0 on 13 Nov 2014
    BEGIN
        BEGIN
            vn_asset_id   := NULL;

            SELECT DISTINCT fa.asset_id
              INTO vn_asset_id
              FROM apps.fa_additions fa, apps.fa_asset_history fah, apps.fa_category_books fcb
             WHERE     fa.asset_id = fah.asset_id
                   --AND fa.asset_category_id = fah.category_id
                   AND fcb.category_id = fa.asset_category_id
                   AND fa.asset_id = pn_asset_id
                   AND fcb.book_type_code = pn_book
                   AND fah.date_ineffective IS NOT NULL;
        --fnd_file.put_line (fnd_file.LOG, '01 - Select' || vn_asset_id);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    vn_asset_id1   := NULL;

                    SELECT DISTINCT fa.asset_id
                      INTO vn_asset_id1
                      FROM apps.fa_additions fa, apps.fa_asset_history fah, fa_category_books fcb
                     WHERE     fa.asset_id = fah.asset_id
                           --AND fa.asset_category_id = fah.category_id
                           AND fcb.category_id = fa.asset_category_id
                           AND fa.asset_id = pn_asset_id
                           AND fcb.book_type_code = pn_book
                           AND fah.asset_type IN ('CIP', 'CAPITALIZED');
                --fnd_file.put_line(fnd_file.LOG,'02 - Select'||vn_asset_id1);
                END;
            WHEN OTHERS
            THEN
                --fnd_file.put_line(fnd_file.LOG,' Asset Doesnot exists: '||pn_asset_id||' Corresponding to Book :'||pn_book);
                vn_asset_id    := NULL;
                vn_asset_id1   := NULL;
        END;

        -- Start changes by BT Technology Team v4.1 on 02-JAN-2015
        BEGIN
            SELECT SUM (NVL (xfr.impairment, 0))
              INTO v_impairment
              FROM xxdo.xxd_fa_roll_fwd_rep_t xfr
             WHERE xfr.asset_id = pn_asset_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_impairment   := 0;
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception Occured while Calculating Impairment:'
                    || SUBSTR (SQLERRM, 1, 200));
        END;

        -- End changes by BT Technology Team v4.1 on 02-JAN-2015

        IF vn_asset_id IS NOT NULL
        THEN
            ln_count   := 0;

              SELECT COUNT (*)
                INTO ln_count
                FROM xxdo.xxd_fa_roll_fwd_rep_t
               WHERE asset_id = vn_asset_id
            GROUP BY asset_id;

            --fnd_file.put_line(fnd_file.LOG,'1 - Select'||vn_asset_id||'2 - Count'||ln_count);



            BEGIN
                SELECT SUM (gt1.cost) - SUM (gt1.deprn_reserve)
                  -- - SUM (NVL (xfr.impairment, 0)) -- Retrofit v 4.0 13 Nov 2014(NBV = cost - deprn_reserve-impairment)
                  INTO v_nbv
                  FROM xxdo.xxd_fa_roll_rsv_ledger_t gt1                   --,
                 --xxdo.xxd_fa_roll_fwd_rep_t xfr
                 WHERE       /*xfr.asset_id = gt1.asset_id
                       AND*/
                       gt1.asset_id = vn_asset_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_nbv   := 0;
                    apps.fnd_file.put_line (
                        fnd_file.LOG,
                           'Exception Occured while Calculating Cost :'
                        || SUBSTR (SQLERRM, 1, 200));
            END;

            IF ln_count > 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                   SET net_book_value   = v_nbv - v_impairment          --v4.1
                 WHERE rep1.asset_id = vn_asset_id AND rep1.end_year > 0;
            ELSIF ln_count = 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                   SET net_book_value   = v_nbv - v_impairment --v4.1            --v_cost - v_dep_reserve
                 WHERE rep1.asset_id = vn_asset_id;
            END IF;

            COMMIT;
        ELSIF vn_asset_id IS NULL AND vn_asset_id1 IS NOT NULL
        THEN
            BEGIN
                ln_count   := 0;

                  SELECT COUNT (*)
                    INTO ln_count
                    FROM xxdo.xxd_fa_roll_fwd_rep_t
                   WHERE asset_id = vn_asset_id1
                GROUP BY asset_id;

                --fnd_file.put_line(fnd_file.LOG,'01 - Select'||vn_asset_id||'02 - Count'||ln_count);

                BEGIN
                    SELECT SUM (gt1.cost) - SUM (gt1.deprn_reserve)
                      -- - SUM (NVL (xfr.impairment, 0)) -- Retrofit v 4.0 13 Nov 2014(NBV = cost - deprn_reserve-impairment)
                      INTO v_nbv
                      FROM xxdo.xxd_fa_roll_rsv_ledger_t gt1               --,
                     --xxdo.xxd_fa_roll_fwd_rep_t xfr
                     WHERE 1 = 1               --  gt1.asset_id = xfr.asset_id
                                 AND gt1.asset_id = vn_asset_id1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_nbv   := 0;
                        apps.fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception Occured while Calculating Cost1 :'
                            || SUBSTR (SQLERRM, 1, 200));
                END;

                IF ln_count > 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'4 - Count1>1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                       SET net_book_value   = v_nbv - v_impairment      --v4.1
                     WHERE rep1.asset_id = vn_asset_id1 AND rep1.end_year > 0;
                ELSIF ln_count = 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'5 - Count1=1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_t rep1
                       SET net_book_value   = v_nbv - v_impairment --v4.1        --v_cost - v_dep_reserve
                     WHERE rep1.asset_id = vn_asset_id1;
                END IF;

                COMMIT;
            END;
        END IF;
    END;

    PROCEDURE xxd_fa_net_book_value_sum (pn_asset_id   IN NUMBER,
                                         pn_book          VARCHAR2)
    IS
        vn_asset_id     NUMBER;
        vn_asset_id1    NUMBER;
        ln_count        NUMBER;
        v_cost          NUMBER;
        v_dep_reserve   NUMBER;
        v_nbv           NUMBER;
        v_impairment    NUMBER;                                         --v4.1
    BEGIN
        BEGIN
            vn_asset_id   := NULL;

            SELECT DISTINCT fa.asset_id
              INTO vn_asset_id
              FROM apps.fa_additions fa, apps.fa_asset_history fah, fa_category_books fcb
             WHERE     fa.asset_id = fah.asset_id
                   --AND fa.asset_category_id = fah.category_id
                   AND fcb.category_id = fa.asset_category_id
                   AND fa.asset_id = pn_asset_id
                   AND fcb.book_type_code = pn_book
                   AND fah.date_ineffective IS NOT NULL;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                BEGIN
                    vn_asset_id1   := NULL;

                    SELECT DISTINCT fa.asset_id
                      INTO vn_asset_id1
                      FROM apps.fa_additions fa, apps.fa_asset_history fah, fa_category_books fcb
                     WHERE     fa.asset_id = fah.asset_id
                           --AND fa.asset_category_id = fah.category_id
                           AND fcb.category_id = fa.asset_category_id
                           AND fa.asset_id = pn_asset_id
                           AND fcb.book_type_code = pn_book
                           AND fah.asset_type IN ('CIP', 'CAPITALIZED');
                END;
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       ' Asset Doesnot exists: '
                    || pn_asset_id
                    || ' Corresponding to Book :'
                    || pn_book);
                vn_asset_id    := NULL;
                vn_asset_id1   := NULL;
        END;

        -- Start changes by BT Technology Team v4.1 on 02-JAN-2015
        BEGIN
            SELECT SUM (NVL (xfr.impairment, 0))
              INTO v_impairment
              FROM xxdo.xxd_fa_roll_fwd_rep_sum_t xfr
             WHERE xfr.asset_id = pn_asset_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                v_impairment   := 0;
                apps.fnd_file.put_line (
                    fnd_file.LOG,
                       'Exception Occured while Calculating Impairment :'
                    || SUBSTR (SQLERRM, 1, 200));
        END;

        -- End changes by BT Technology Team v4.1 on 02-JAN-2015

        IF vn_asset_id IS NOT NULL
        THEN
            ln_count   := 0;

              SELECT COUNT (*)
                INTO ln_count
                FROM xxdo.xxd_fa_roll_fwd_rep_sum_t
               WHERE asset_id = vn_asset_id
            GROUP BY asset_id;

            BEGIN
                SELECT SUM (gt1.cost) - SUM (gt1.deprn_reserve)
                  -- - SUM (NVL (xfrs.impairment, 0)) -- Retrofit v 4.0 13 Nov 2014(NBV = cost - deprn_reserve-impairment)
                  INTO v_nbv
                  FROM xxdo.xxd_fa_roll_rsv_ledger_sum_t gt1               --,
                 --xxdo.xxd_fa_roll_fwd_rep_sum_t xfrs
                 WHERE /* gt1.asset_id = xfrs.asset_id
                    AND*/
                       gt1.asset_id = vn_asset_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    v_nbv   := 0;
            --apps.fnd_file.put_line(fnd_file.log,'Exception Occured while Calculating Cost :'||substr(sqlerrm,1,200));
            END;

            IF ln_count > 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                   SET net_book_value   = v_nbv - v_impairment          --v4.1
                 WHERE     rep1.asset_id = vn_asset_id
                       AND rep1.report_type = 'COST'
                       AND rep1.end_year > 0;
            ELSIF ln_count = 1
            THEN
                UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                   SET net_book_value   = v_nbv - v_impairment --v4.1          --v_cost - v_dep_reserve
                 WHERE rep1.asset_id = vn_asset_id;
            END IF;

            COMMIT;
        ELSIF vn_asset_id IS NULL AND vn_asset_id1 IS NOT NULL
        THEN
            BEGIN
                ln_count   := 0;

                  SELECT COUNT (*)
                    INTO ln_count
                    FROM xxdo.xxd_fa_roll_fwd_rep_sum_t
                   WHERE asset_id = vn_asset_id1
                GROUP BY asset_id;

                BEGIN
                    SELECT SUM (gt1.cost) - SUM (gt1.deprn_reserve)
                      -- - SUM (NVL (xfrs.impairment, 0)) -- Retrofit v 4.0 13 Nov 2014(NBV = cost - deprn_reserve-impairment)
                      INTO v_nbv
                      FROM xxdo.xxd_fa_roll_rsv_ledger_sum_t gt1           --,
                     --xxdo.xxd_fa_roll_fwd_rep_sum_t xfrs
                     WHERE /*  gt1.asset_id = xfrs.asset_id
                         AND*/
                           gt1.asset_id = vn_asset_id1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        v_nbv   := 0;
                        apps.fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception Occured while Calculating Cost1 :'
                            || SUBSTR (SQLERRM, 1, 200));
                END;

                IF ln_count > 1
                THEN
                    --fnd_file.put_line(fnd_file.LOG,'4 - Count1>1'||vn_asset_id1);
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                       SET net_book_value   = v_nbv - v_impairment      --v4.1
                     WHERE rep1.asset_id = vn_asset_id1 AND rep1.end_year > 0;
                --AND rep1.REPORT_TYPE = 'COST';
                ELSIF ln_count = 1
                THEN
                    UPDATE xxdo.xxd_fa_roll_fwd_rep_sum_t rep1
                       SET net_book_value   = v_nbv - v_impairment --v4.1         --v_cost - v_dep_reserve
                     WHERE rep1.asset_id = vn_asset_id1;

                    COMMIT;
                END IF;
            END;
        END IF;
    END;

    PROCEDURE main_detail (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_book IN VARCHAR2, p_currency IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2
                           , p_subtotal IN VARCHAR2, p_subtotal_value IN VARCHAR2, p_project_type IN VARCHAR2) -- CCR0008086
    AS
        v_num                           NUMBER := 0;
        v_supplier                      VARCHAR2 (100);
        -- v_cost NUMBER;
        v_current_period_depreciation   NUMBER;
        v_ending_dpereciation_reserve   NUMBER;
        v_net_book_value                NUMBER;
        v_report_date                   VARCHAR2 (30);
        v_asset_count                   NUMBER;
        v_prior_year                    NUMBER;
        v_begining_yr_deprn             NUMBER;
        v_ytd_deprn_transfer            NUMBER;
        v_ytd_deprn                     NUMBER;
        v_cost_total                    NUMBER;
        v_current_period_deprn_total    NUMBER;
        v_ytd_deprn_total               NUMBER;
        v_ending_deprn_reserve_total    NUMBER;
        v_net_book_value_total          NUMBER;
        v_begin_yr_deprn_total          NUMBER;
        v_ending_total                  NUMBER;
        v_begin_total                   NUMBER;
        v_addition_total                NUMBER;
        v_adjustment_total              NUMBER;
        v_retirement_total              NUMBER;
        v_reclass_total                 NUMBER;
        v_transfer_total                NUMBER;
        v_revaluation_total             NUMBER;
        v_custodian                     VARCHAR2 (50);
        v_cost                          NUMBER;
        v_dep_reserve                   NUMBER;
        v_location_id                   NUMBER;
        v_location_flexfield            VARCHAR2 (100);
        v_depreciation_account          VARCHAR2 (100);
        v_null_count                    NUMBER := 0;
        v_asset_num                     NUMBER;
        v_period_from                   VARCHAR2 (20);
        v_date_in_service               DATE;                  --VARCHAR2(20);
        v_method_code                   VARCHAR2 (20);
        v_life                          NUMBER;
        --v_period_from VARCHAR2(20);
        v_period_to                     VARCHAR2 (20);

        --v_net_book_value NUMBER;

        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
        ln_begin_spot_rate              NUMBER;
        ln_end_spot_rate                NUMBER;
        ln_begin_spot                   NUMBER;
        ln_begin_trans                  NUMBER;
        ln_end_spot                     NUMBER;
        ln_end_trans                    NUMBER;
        ln_net_trans                    NUMBER;

        ln_begin_grd_tot                NUMBER := 0;
        ln_begin_spot_grd_tot           NUMBER := 0;
        ln_begin_trans_grd_tot          NUMBER := 0;
        ln_addition_grd_tot             NUMBER := 0;

        ln_adjustment_grd_tot           NUMBER := 0;
        ln_retirement_grd_tot           NUMBER := 0;
        ln_revaluation_grd_tot          NUMBER := 0;
        ln_reclass_grd_tot              NUMBER := 0;
        ln_transfer_grd_tot             NUMBER := 0;

        ln_capitalization_grd_tot       NUMBER := 0;
        ln_end_grd_tot                  NUMBER := 0;
        ln_end_spot_grd_tot             NUMBER := 0;
        ln_end_trans_grd_tot            NUMBER := 0;
        ln_net_trans_grd_tot            NUMBER := 0;
        ln_net_book_val_grd_tot         NUMBER := 0;
        ln_impairment_tot               NUMBER := 0;


        ln_begin_cip_tot                NUMBER;
        ln_begin_spot_cip_tot           NUMBER;
        ln_begin_trans_cip_tot          NUMBER;
        ln_addition_cip_tot             NUMBER;
        ln_capitalization_cip_tot       NUMBER;
        ln_end_cip_tot                  NUMBER;
        ln_end_spot_cip_tot             NUMBER;
        ln_end_trans_cip_tot            NUMBER;
        ln_net_trans_cip_tot            NUMBER;
        l_period_from                   VARCHAR2 (30);
        l_period_to                     VARCHAR2 (30);
        h_set_of_books_id               NUMBER;
        h_reporting_flag                VARCHAR2 (1);
        -- added by Showkath v5.0 on 07-Jul-2015 begin
        ln_conversion_rate              NUMBER;
        ln_addition                     NUMBER;
        ln_adjustment                   NUMBER;
        ln_retirement                   NUMBER;
        ln_capitalization               NUMBER;
        ln_revaluation                  NUMBER;
        ln_reclass                      NUMBER;
        ln_transfer                     NUMBER;
        l_testing                       VARCHAR2 (10);
        --added by Showkath v5.0 on 07-Jul-2015 end
        l_func_currency                 VARCHAR2 (10); -- added by showkath on 01-DEC-2015
        l_category                      VARCHAR2 (30); -- added by showkath on 01-DEC-2015
        l_func_currency_spot            VARCHAR2 (10); -- added by showkath on 01-DEC-2015
        l_cnt                           NUMBER;

        -- End changes by BT Technology Team v4.1 on 24-Dec-2014

        -- Begin Changes CCR0009036
        CURSOR data_cur IS
              SELECT rownumber, book, period_from,
                     period_to, currency, asset_category,
                     asset_cost_account, asset_cost_comb, cost_center,
                     brand, asset_number, description,
                     custodian, location, date_placed_in_service,
                     deprn_method, life_yr_mo, begin_year_fun,
                     begin_year_spot, addition, adjustment,
                     retirement, capitalization, revaluation,
                     reclass, transfer, end_year_fun,
                     end_year_spot, net_trans
                FROM XXDO.XXD_FA_ROLL_FWD_REP_XML_T
            ORDER BY rownumber;

        output_row                      data_cur%ROWTYPE;

        -- End Changes CCR0009036

        CURSOR c_net_book (p_book IN VARCHAR2)
        IS
            SELECT DISTINCT book, period_from, period_to,
                            asset_id
              FROM xxdo.xxd_fa_roll_fwd_rep_t
             WHERE book = p_book;

        -- BEGIN Changes CCR0009036
        CURSOR c_header (cp_book IN VARCHAR2, p_currency IN VARCHAR2)
        IS
            /*SELECT asset_category,
                   asset_cost_account,
                   cost_center,
                   asset_category_attrib1 brand,
                   asset_number,
                   location, --Added by BT Technology Team v4.1 on 24-Dec-2014
                   description,
                   parent_asset,
                   begin1 begin_year,
                   begin2 begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                   addition,
                   adjustment,
                   retirement,
                   capitalization,
                   revaluation,
                   reclass,
                   transfer,
                   addition_nonf,
                   adjustment_nonf,
                   retirement_nonf,
                   capitalization_nonf,
                   revaluation_nonf,
                   reclass_nonf,
                   transfer_nonf,
                   end1 end_year,
                   end2 end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                   report_type,
                   asset_id,
                   impairment,
                   net_book_value
              FROM (  SELECT DISTINCT
                                -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
                                --fc.segment1 || '-' || fc.segment2 asset_category,
                                fc.segment1
                             || '.'
                             || fc.segment2
                             || '.'
                             || fc.segment3
                                asset_category,
                             --NVL (rsv1.category_books_account, cc_adjust.segment3) asset_cost_account,
                             NVL (rsv1.category_books_account, cc_adjust.segment6)
                                asset_cost_account,
                             --max(cc.segment2) cost_center,
                             --cc.segment2 cost_center,
                             cc.segment5 cost_center,
                             --fc.attribute1 asset_category_attrib1,
                             fc.segment3 asset_category_attrib1,
                             -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                             ad.asset_number,
                             rsv1.location, --Added by BT Technology Team v4.1 on 24-Dec-2014
                             ad.description,
                             ad.parent_asset_id parent_asset,
                             NVL (
                                SUM (
                                   NVL (
                                      DECODE (rsv1.source_type_code,
                                              'BEGIN', NVL (rsv1.amount, 0),
                                              NULL),
                                      0)),
                                0)
                                begin1,
                             -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                             NVL2 (
                                ln_begin_spot_rate,
                                NVL (
                                   SUM (
                                      NVL (
                                         DECODE (
                                            rsv1.source_type_code,
                                            'BEGIN', NVL (rsv1.amount_fun, 0),
                                            NULL),
                                         0)),
                                   0),
                                NULL)
                                begin2,
                               -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                               SUM (
                                  DECODE (
                                     rsv1.source_type_code,
                                     DECODE (rsv1.report_type,
                                             'COST', 'ADDITION',
                                             'CIP ADDITION'), NVL (rsv1.amount, 0),
                                     NULL))
                             + DECODE (
                                  ad.asset_id,
                                  apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                     ad.asset_id,
                                     cp_book), SUM (
                                                  DECODE (
                                                     rsv1.source_type_code,
                                                     DECODE (rsv1.report_type,
                                                             'COST', 'ADDITION'), -NVL (
                                                                                      rsv1.amount,
                                                                                      0),
                                                     0)),
                                  0)
                                addition,
                             SUM (
                                DECODE (
                                   rsv1.source_type_code,
                                   DECODE (rsv1.report_type,
                                           'COST', 'ADJUSTMENT',
                                           'CIP ADJUSTMENT'), NVL (rsv1.amount, 0),
                                   NULL))
                                adjustment,
                             SUM (
                                DECODE (
                                   rsv1.source_type_code,
                                   DECODE (rsv1.report_type,
                                           'COST', 'RETIREMENT',
                                           'CIP RETIREMENT'), NVL (rsv1.amount, 0),
                                   NULL))
                                retirement,
                             DECODE (
                                ad.asset_id,
                                apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                   ad.asset_id,
                                   cp_book), SUM (
                                                DECODE (
                                                   rsv1.source_type_code,
                                                   DECODE (rsv1.report_type,
                                                           'CIP COST', 'ADDITION',
                                                           'COST', 'ADDITION'), NVL (
                                                                                   rsv1.amount,
                                                                                   0),
                                                   NULL)),
                                NULL)
                                capitalization,
                             SUM (
                                DECODE (rsv1.source_type_code,
                                        'REVALUATION', NVL (rsv1.amount, 0),
                                        NULL))
                                revaluation,
                             SUM (
                                DECODE (rsv1.source_type_code,
                                        'RECLASS', NVL (rsv1.amount, 0),
                                        NULL))
                                reclass,
                             SUM (
                                DECODE (rsv1.source_type_code,
                                        'TRANSFER', NVL (rsv1.amount, 0),
                                        NULL))
                                transfer,
                               SUM (
                                  DECODE (
                                     rsv1.source_type_code,
                                     DECODE (rsv1.report_type,
                                             'COST', 'ADDITION',
                                             'CIP ADDITION'), NVL (
                                                                 rsv1.amount_nonf,
                                                                 0),
                                     NULL))
                             + DECODE (
                                  ad.asset_id,
                                  apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                     ad.asset_id,
                                     cp_book), SUM (
                                                  DECODE (
                                                     rsv1.source_type_code,
                                                     DECODE (rsv1.report_type,
                                                             'COST', 'ADDITION'), -NVL (
                                                                                      rsv1.amount_nonf,
                                                                                      0),
                                                     0)),
                                  0)
                                addition_nonf,
                             SUM (
                                DECODE (
                                   rsv1.source_type_code,
                                   DECODE (rsv1.report_type,
                                           'COST', 'ADJUSTMENT',
                                           'CIP ADJUSTMENT'), NVL (
                                                                 rsv1.amount_nonf,
                                                                 0),
                                   NULL))
                                adjustment_nonf,
                             SUM (
                                DECODE (
                                   rsv1.source_type_code,
                                   DECODE (rsv1.report_type,
                                           'COST', 'RETIREMENT',
                                           'CIP RETIREMENT'), NVL (
                                                                 rsv1.amount_nonf,
                                                                 0),
                                   NULL))
                                retirement_nonf,
                             DECODE (
                                ad.asset_id,
                                apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                   ad.asset_id,
                                   cp_book), SUM (
                                                DECODE (
                                                   rsv1.source_type_code,
                                                   DECODE (rsv1.report_type,
                                                           'CIP COST', 'ADDITION',
                                                           'COST', 'ADDITION'), NVL (
                                                                                   rsv1.amount_nonf,
                                                                                   0),
                                                   NULL)),
                                NULL)
                                capitalization_nonf,
                             SUM (
                                DECODE (rsv1.source_type_code,
                                        'REVALUATION', NVL (rsv1.amount_nonf, 0),
                                        NULL))
                                revaluation_nonf,
                             SUM (
                                DECODE (rsv1.source_type_code,
                                        'RECLASS', NVL (rsv1.amount_nonf, 0),
                                        NULL))
                                reclass_nonf,
                             SUM (
                                DECODE (rsv1.source_type_code,
                                        'TRANSFER', NVL (rsv1.amount_nonf, 0),
                                        NULL))
                                transfer_nonf,
                             SUM (
                                NVL (
                                   DECODE (rsv1.source_type_code,
                                           'END', NVL (rsv1.amount, 0),
                                           NULL),
                                   0))
                                end1,
                             -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                             NVL2 (
                                ln_begin_spot_rate,
                                SUM (
                                   NVL (
                                      DECODE (rsv1.source_type_code,
                                              'END', NVL (rsv1.amount_fun, 0),
                                              NULL),
                                      0)),
                                NULL)
                                end2,
                             -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                             rsv1.report_type,
                             ad.asset_id,
                             0 impairment,
                             0 net_book_value
                        FROM xxdo.xxd_fa_roll_fwd_t rsv1,
                             fa_additions ad,
                             fa_categories fc,
                             fa_category_books fcb,
                             gl_code_combinations_kfv cc,
                             gl_code_combinations_kfv cc_cost,
                             gl_code_combinations cc_adjust
                       WHERE     1 = 1
                             AND rsv1.asset_id = ad.asset_id
                             AND ad.asset_category_id = fc.category_id
                             AND fc.category_id = fcb.category_id
                             AND fcb.book_type_code = cp_book       --p_book v4.1
                             AND fcb.asset_cost_account_ccid =
                                    cc_cost.code_combination_id
                             AND cc_adjust.code_combination_id(+) =
                                    rsv1.adjustment_ccid
                             AND cc.code_combination_id = rsv1.distribution_ccid
           AND ((fc.attribute2 = p_project_type) OR (fc.attribute2 IS NULL AND p_project_type = 'Non Special' ) OR (1=1 AND NVL(p_project_type,'All') = 'All' ) ) --CCR0008086
                             -- and ad.asset_id = 12159
                             AND DECODE (
                                    p_subtotal,
                                    'AC', DECODE (p_subtotal_value,
                                                  NULL, TO_CHAR (1),
                                                  --TO_CHAR (fc.category_id) --Commented by BT Technology Team v3.0
                                                  TO_CHAR (fc.segment1 /*|| '.'
                                                                       || fc.segment2
                                                                       || '.'
                                                                       || fc.segment3*/
                                 /* ) --Added by BT Technology Team v3.0
                                   ),
'ACC', DECODE (
          p_subtotal_value,
          NULL, TO_CHAR (1),
          NVL (
             TO_CHAR (
                rsv1.category_books_account),
             --TO_CHAR (cc_adjust.segment3)--Commented by BT Technology Team v3.0
             TO_CHAR (cc_adjust.segment6) --Added by BT Technology Team v3.0
                                         )),
'CC', DECODE (p_subtotal_value,
              NULL, TO_CHAR (1),
              --TO_CHAR (cc.segment2) --Commented by BT Technology Team v3.0
              TO_CHAR (cc.segment5) --Added by BT Technology Team v3.0
                                   ),
-- Start changes by BT Technology Team v3.0 on 21-Oct-2014
/*'PA', DECODE (p_subtotal_value,
              NULL, TO_CHAR (1),
              TO_CHAR (ad.parent_asset_id))) =*/
                /*'BD', DECODE (p_subtotal_value,
                              NULL, TO_CHAR (1),
                              TO_CHAR (fc.segment3))) =
                -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                DECODE (p_subtotal_value,
                        NULL, TO_CHAR (1),
                        p_subtotal_value)
GROUP BY -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
            --Commented and added by BT Technology Team v3.0
            --fc.segment1 || '-' || fc.segment2,
            fc.segment1
         || '.'
         || fc.segment2
         || '.'
         || fc.segment3,
         NVL (rsv1.category_books_account, --cc_adjust.segment3),
              cc_adjust.segment6),
         --cc.segment2,
         cc.segment5,
         --fc.attribute1,
         fc.segment3,
         -- End changes by BT Technology Team v3.0 on 21-Oct-2014
         ad.asset_number,
         rsv1.location, --Added by BT Technology Team v4.1 on 24-Dec-2014
         ad.description,
         fc.segment2,
         ad.parent_asset_id,
         rsv1.report_type,
         ad.asset_id
ORDER BY DECODE (p_subtotal,
                 'AC', asset_category,
                 'ACC', asset_cost_account,
                 'CC', cost_center,
                 -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
                 --'PA', parent_asset
                 'BD', asset_category_attrib1 -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                                             ),
         ad.asset_number);*/
            SELECT asset_category, asset_xla_comb, asset_cost_account,
                   cost_center, asset_category_attrib1 brand, asset_number,
                   location, description, parent_asset,
                   begin1 begin_year, begin2 begin_year_fun, addition,
                   adjustment, retirement, capitalization,
                   revaluation, reclass, transfer,
                   addition_nonf, adjustment_nonf, retirement_nonf,
                   capitalization_nonf, revaluation_nonf, reclass_nonf,
                   transfer_nonf, end1 end_year, end2 end_year_fun,
                   report_type, asset_id, impairment,
                   net_book_value
              FROM (  SELECT DISTINCT
                                fc.segment1
                             || '.'
                             || fc.segment2
                             || '.'
                             || fc.segment3
                                 asset_category,
                             (SELECT gcc1.concatenated_segments
                                FROM gl_code_combinations_kfv gcc1
                               WHERE     gcc1.code_combination_id =
                                         rsv1.adjustment_ccid
                                     AND gcc1.enabled_flag = 'Y')
                                 asset_xla_comb,
                             NVL (rsv1.category_books_account,
                                  cc_adjust.segment6)
                                 asset_cost_account,
                             cc.segment5
                                 cost_center,
                             fc.segment3
                                 asset_category_attrib1,
                             ad.asset_number,
                             rsv1.location,
                             ad.description,
                             ad.parent_asset_id
                                 parent_asset,
                             NVL (
                                 SUM (
                                     NVL (
                                         DECODE (rsv1.source_type_code,
                                                 'BEGIN', NVL (rsv1.amount, 0),
                                                 NULL),
                                         0)),
                                 0)
                                 begin1,
                             NVL2 (
                                 ln_begin_spot_rate,
                                 NVL (
                                     SUM (
                                         NVL (
                                             DECODE (
                                                 rsv1.source_type_code,
                                                 'BEGIN', NVL (rsv1.amount_fun,
                                                               0),
                                                 NULL),
                                             0)),
                                     0),
                                 NULL)
                                 begin2,
                               SUM (
                                   DECODE (
                                       rsv1.source_type_code,
                                       DECODE (rsv1.report_type,
                                               'COST', 'ADDITION',
                                               'CIP ADDITION'), NVL (
                                                                    rsv1.amount,
                                                                    0),
                                       NULL))
                             + DECODE (
                                   ad.asset_id,
                                   apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                       ad.asset_id,
                                       cp_book), SUM (
                                                     DECODE (
                                                         rsv1.source_type_code,
                                                         DECODE (
                                                             rsv1.report_type,
                                                             'COST', 'ADDITION'), -NVL (
                                                                                       rsv1.amount,
                                                                                       0),
                                                         0)),
                                   0)
                                 addition,
                             SUM (
                                 DECODE (
                                     rsv1.source_type_code,
                                     DECODE (rsv1.report_type,
                                             'COST', 'ADJUSTMENT',
                                             'CIP ADJUSTMENT'), NVL (
                                                                    rsv1.amount,
                                                                    0),
                                     NULL))
                                 adjustment,
                             SUM (
                                 DECODE (
                                     rsv1.source_type_code,
                                     DECODE (rsv1.report_type,
                                             'COST', 'RETIREMENT',
                                             'CIP RETIREMENT'), NVL (
                                                                    rsv1.amount,
                                                                    0),
                                     NULL))
                                 retirement,
                             DECODE (
                                 ad.asset_id,
                                 apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                     ad.asset_id,
                                     cp_book), SUM (
                                                   DECODE (
                                                       rsv1.source_type_code,
                                                       DECODE (
                                                           rsv1.report_type,
                                                           'CIP COST', 'ADDITION',
                                                           'COST', 'ADDITION'), NVL (
                                                                                    rsv1.amount,
                                                                                    0),
                                                       NULL)),
                                 NULL)
                                 capitalization,
                             SUM (
                                 DECODE (rsv1.source_type_code,
                                         'REVALUATION', NVL (rsv1.amount, 0),
                                         NULL))
                                 revaluation,
                             SUM (
                                 DECODE (rsv1.source_type_code,
                                         'RECLASS', NVL (rsv1.amount, 0),
                                         NULL))
                                 reclass,
                             SUM (
                                 DECODE (rsv1.source_type_code,
                                         'TRANSFER', NVL (rsv1.amount, 0),
                                         NULL))
                                 transfer,
                               SUM (
                                   DECODE (
                                       rsv1.source_type_code,
                                       DECODE (rsv1.report_type,
                                               'COST', 'ADDITION',
                                               'CIP ADDITION'), NVL (
                                                                    rsv1.amount_nonf,
                                                                    0),
                                       NULL))
                             + DECODE (
                                   ad.asset_id,
                                   apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                       ad.asset_id,
                                       cp_book), SUM (
                                                     DECODE (
                                                         rsv1.source_type_code,
                                                         DECODE (
                                                             rsv1.report_type,
                                                             'COST', 'ADDITION'), -NVL (
                                                                                       rsv1.amount_nonf,
                                                                                       0),
                                                         0)),
                                   0)
                                 addition_nonf,
                             SUM (
                                 DECODE (
                                     rsv1.source_type_code,
                                     DECODE (rsv1.report_type,
                                             'COST', 'ADJUSTMENT',
                                             'CIP ADJUSTMENT'), NVL (
                                                                    rsv1.amount_nonf,
                                                                    0),
                                     NULL))
                                 adjustment_nonf,
                             SUM (
                                 DECODE (
                                     rsv1.source_type_code,
                                     DECODE (rsv1.report_type,
                                             'COST', 'RETIREMENT',
                                             'CIP RETIREMENT'), NVL (
                                                                    rsv1.amount_nonf,
                                                                    0),
                                     NULL))
                                 retirement_nonf,
                             DECODE (
                                 ad.asset_id,
                                 apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (
                                     ad.asset_id,
                                     cp_book), SUM (
                                                   DECODE (
                                                       rsv1.source_type_code,
                                                       DECODE (
                                                           rsv1.report_type,
                                                           'CIP COST', 'ADDITION',
                                                           'COST', 'ADDITION'), NVL (
                                                                                    rsv1.amount_nonf,
                                                                                    0),
                                                       NULL)),
                                 NULL)
                                 capitalization_nonf,
                             SUM (
                                 DECODE (
                                     rsv1.source_type_code,
                                     'REVALUATION', NVL (rsv1.amount_nonf, 0),
                                     NULL))
                                 revaluation_nonf,
                             SUM (
                                 DECODE (rsv1.source_type_code,
                                         'RECLASS', NVL (rsv1.amount_nonf, 0),
                                         NULL))
                                 reclass_nonf,
                             SUM (
                                 DECODE (rsv1.source_type_code,
                                         'TRANSFER', NVL (rsv1.amount_nonf, 0),
                                         NULL))
                                 transfer_nonf,
                             SUM (
                                 NVL (
                                     DECODE (rsv1.source_type_code,
                                             'END', NVL (rsv1.amount, 0),
                                             NULL),
                                     0))
                                 end1,
                             NVL2 (
                                 ln_begin_spot_rate,
                                 SUM (
                                     NVL (
                                         DECODE (
                                             rsv1.source_type_code,
                                             'END', NVL (rsv1.amount_fun, 0),
                                             NULL),
                                         0)),
                                 NULL)
                                 end2,
                             rsv1.report_type,
                             ad.asset_id,
                             0
                                 impairment,
                             0
                                 net_book_value
                        FROM xxdo.xxd_fa_roll_fwd_t rsv1, fa_additions ad, fa_categories fc,
                             fa_category_books fcb, gl_code_combinations_kfv cc, gl_code_combinations_kfv cc_cost,
                             gl_code_combinations cc_adjust
                       WHERE     1 = 1
                             AND rsv1.asset_id = ad.asset_id
                             AND ad.asset_category_id = fc.category_id
                             AND fc.category_id = fcb.category_id
                             AND fcb.book_type_code = cp_book
                             AND fcb.asset_cost_account_ccid =
                                 cc_cost.code_combination_id
                             AND cc_adjust.code_combination_id(+) =
                                 rsv1.adjustment_ccid
                             AND cc.code_combination_id =
                                 rsv1.distribution_ccid
                             AND ((fc.attribute2 = p_project_type) OR (fc.attribute2 IS NULL AND p_project_type = 'Non Special') OR (1 = 1 AND NVL (p_project_type, 'All') = 'All'))
                             AND DECODE (
                                     p_subtotal,
                                     'AC', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   TO_CHAR (fc.segment1)),
                                     'ACC', DECODE (
                                                p_subtotal_value,
                                                NULL, TO_CHAR (1),
                                                NVL (
                                                    TO_CHAR (
                                                        rsv1.category_books_account),
                                                    TO_CHAR (
                                                        cc_adjust.segment6))),
                                     'CC', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   TO_CHAR (cc.segment5)),
                                     'BD', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   TO_CHAR (fc.segment3))) =
                                 DECODE (p_subtotal_value,
                                         NULL, TO_CHAR (1),
                                         p_subtotal_value)
                    GROUP BY fc.segment1 || '.' || fc.segment2 || '.' || fc.segment3, NVL (rsv1.category_books_account, cc_adjust.segment6), rsv1.adjustment_ccid,
                             cc.segment5, fc.segment3, ad.asset_number,
                             rsv1.location, ad.description, fc.segment2,
                             ad.parent_asset_id, rsv1.report_type, ad.asset_id
                    ORDER BY DECODE (p_subtotal,  'AC', asset_category,  'ACC', asset_cost_account,  'CC', cost_center,  'BD', asset_category_attrib1), ad.asset_number);

        -- END Changes CCR0009036

        CURSOR c_dis IS
            SELECT DISTINCT
                   DECODE (p_subtotal,  -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                        --'AC', asset_category,
                                        'AC', SUBSTR (asset_category, 1, INSTR (asset_category, '.') - 1),  -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                            'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset --Commented by BT Technology Team v3.0
                                                                                                                                                            'BD', brand --Added by BT Technology Team v3.0
                                                                                                                                                                       ) info
              FROM xxdo.xxd_fa_roll_fwd_rep_t;

        CURSOR c_dis1 (c_1 VARCHAR2)
        IS
              SELECT DECODE (p_subtotal,  'AC', 'Asset Category',  'ACC', 'Cost Account',  'CC', 'Cost Center',  --'PA', 'Parent Asset' --Commented by BT Technology Team v3.0
                                                                                                                 'BD', 'Brand' --Added by BT Technology Team v3.0
                                                                                                                              ) info1, DECODE (p_subtotal,  -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                            --'AC', asset_category,
                                                                                                                                                            'AC', SUBSTR (asset_category, 1, INSTR (asset_category, '.') - 1),  -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                                                                                                'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset--Commented by BT Technology Team v3.0
                                                                                                                                                                                                                                                                                'BD', brand --Added by BT Technology Team v3.0
                                                                                                                                                                                                                                                                                           ) info, SUM (begin_year) begin_year,
                     SUM (begin_year_fun) begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                          SUM (addition) addition, SUM (adjustment) adjustment,
                     SUM (retirement) retirement, SUM (capitalization) capitalization, SUM (revaluation) revaluation,
                     SUM (reclass) reclass, SUM (transfer) transfer, SUM (addition_nonf) addition_nonf,
                     SUM (adjustment_nonf) adjustment_nonf, SUM (retirement_nonf) retirement_nonf, SUM (capitalization_nonf) capitalization_nonf,
                     SUM (revaluation_nonf) revaluation_nonf, SUM (reclass_nonf) reclass_nonf, SUM (transfer_nonf) transfer_nonf,
                     SUM (end_year) end_year, SUM (end_year_fun) end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                               SUM (impairment) impairment,
                     SUM (net_book_value) net_book_value
                FROM xxdo.xxd_fa_roll_fwd_rep_t
               WHERE DECODE (
                         p_subtotal,
                         -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                         --'AC', asset_category,
                         'AC', SUBSTR (asset_category,
                                       1,
                                       INSTR (asset_category, '.') - 1),
                         -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                         'ACC', asset_cost_account,
                         'CC', cost_center,
                         --'PA', parent_asset --Commented by BT Technology Team v3.0
                         'BD', brand        --Added by BT Technology Team v3.0
                                    ) =
                     c_1
            GROUP BY DECODE (p_subtotal,  -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                                          --'AC', asset_category,
                                          'AC', SUBSTR (asset_category, 1, INSTR (asset_category, '.') - 1),  -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                              'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset --Commented by BT Technology Team v3.0
                                                                                                                                                              'BD', brand --Added by BT Technology Team v3.0
                                                                                                                                                                         );

        CURSOR c_output (c_1 VARCHAR2)
        IS
            SELECT book, period_from, period_to,
                   currency, asset_category, asset_cost_comb, -- Added as per CCR0009036
                   cost_center, asset_cost_account, brand,
                   asset_number, location, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                           description,
                   custodian, parent_asset, begin_year,
                   begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                   addition, adjustment,
                   retirement, capitalization, revaluation,
                   reclass, transfer, addition_nonf,
                   adjustment_nonf, retirement_nonf, capitalization_nonf,
                   revaluation_nonf, reclass_nonf, transfer_nonf,
                   end_year, end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                           report_type,
                   asset_id, impairment, net_book_value
              FROM xxdo.xxd_fa_roll_fwd_rep_t
             WHERE DECODE (
                       p_subtotal,
                       -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                       --'AC', asset_category,
                       'AC', SUBSTR (asset_category,
                                     1,
                                     INSTR (asset_category, '.') - 1),
                       -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                       'ACC', asset_cost_account,
                       'CC', cost_center,
                       --'PA', parent_asset --Commented by BT Technology Team v3.0
                       'BD', brand          --Added by BT Technology Team v3.0
                                  ) =
                   c_1;

        CURSOR c_total IS
            SELECT SUM (begin_year) begin_year_tot, SUM (begin_year_fun) begin_year_fun_tot, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                             SUM (addition) addition_tot,
                   SUM (adjustment) adjustment_tot, SUM (retirement) retirement_tot, SUM (capitalization) capitalization_tot,
                   SUM (revaluation) revaluation_tot, SUM (reclass) reclass_tot, SUM (transfer) transfer_tot,
                   SUM (addition_nonf) addition_tot_nonf, SUM (adjustment_nonf) adjustment_tot_nonf, SUM (retirement_nonf) retirement_tot_nonf,
                   SUM (capitalization_nonf) capitalization_tot_nonf, SUM (revaluation_nonf) revaluation_tot_nonf, SUM (reclass_nonf) reclass_tot_nonf,
                   SUM (transfer_nonf) transfer_tot_nonf, SUM (end_year) end_year_tot, SUM (end_year_fun) end_year_fun_tot, --Added by BT Technology Team v4.1 on 24-Dec-2014
                   SUM (impairment) impairment_tot, SUM (net_book_value) net_book_value_tot
              FROM xxdo.xxd_fa_roll_fwd_rep_t;
    BEGIN
        --EXECUTE IMMEDIATE 'Truncate table xxdo.xxd_fa_roll_fwd_rep_t';

        -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
        --EXECUTE IMMEDIATE 'Truncate table xxdo.xxd_fa_roll_fwd_t';
        /*
              BEGIN
                 SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                   INTO v_report_date
                   FROM sys.DUAL;
              END;

              apps.fnd_file.put_line (apps.fnd_file.output, 'DECKERS CORPORATION');
              apps.fnd_file.put_line (
                 apps.fnd_file.output,
                 -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                 --'Report Name :Fixed Assets RollForward Detail - Deckers');
                 'Report Name :Deckers FA Roll Forward Detail Cost Report'); --Commented by showkath on 12/01 as per requirement
              --'Report Name :FA Roll Forward Detail Cost Report'); --added by showkath on 12/01 as per requirement
              -- End changes by BT Technology Team v4.1 on 26-Dec-2014
              apps.fnd_file.put_line (apps.fnd_file.output,
                                      'Report Date - :' || v_report_date);
              apps.fnd_file.put_line (apps.fnd_file.output,
                                      'Starting Period is: ' || p_from_period);
              apps.fnd_file.put_line (apps.fnd_file.output,
                                      'Ending Period is: ' || p_to_period);
              apps.fnd_file.put_line (apps.fnd_file.output,
                                      'Subtotal By : ' || p_subtotal);
              apps.fnd_file.put_line (apps.fnd_file.output,
                                      'Subtotal By Value: ' || p_subtotal_value);
           apps.fnd_file.put_line (apps.fnd_file.output,
                                      'Project Type: ' || p_project_type);
              apps.fnd_file.put_line (apps.fnd_file.output, ' ');
              apps.fnd_file.put_line (apps.fnd_file.output, 'Fixed Asset Section');

              apps.fnd_file.put_line (
                 apps.fnd_file.output,
                    'Book'
                 || CHR (9)
                 || 'Starting Period'
                 || CHR (9)
                 || 'Ending Period'
                 || CHR (9)
                 || 'Currency'
                 || CHR (9)
                 || 'Asset Category'
                 || CHR (9)
                 || 'Asset Cost Account'
                 || CHR (9)
                 || 'Asset Code Combination'                     -- Added as per CCR0009036
                 || CHR (9)                                      -- Added as per CCR0009036
                 || 'Depreciation Cost Center'                   --'Asset Cost Center'
                 || CHR (9)
                 || 'Asset Brand'
                 || CHR (9)
                 || 'Asset Number'
                 || CHR (9)
                 || 'Asset Description'
                 || CHR (9)
                 || 'Asset Custodian'
                 -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
                 /*|| CHR (9)
                 || 'Asset Parent'*/
        /*        || CHR (9)
                || 'Location'
                -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                || CHR (9)
                || 'Date Placed In Service'
                || CHR (9)
                || 'Depreciation Method'
                || CHR (9)
                || 'Life Yr.Mo'
                || CHR (9)
                --|| 'Begin Balance' --  commented by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)         --  commented by Showkath v5.0 on 07-Jul-2015
                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                || 'Begin Balance in <Functional Currency>'
                || CHR (9)
                || 'Begin Balance <'
                || p_currency
                || '> at Spot Rate'
                || CHR (9)
                --|| 'Begin FX Translation' --  commented by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)                --  commented by Showkath v5.0 on 07-Jul-2015
                -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                || 'Additions'
                || CHR (9)
                || 'Adjustments'
                || CHR (9)
                || 'Retirements'
                || CHR (9)
                || 'Capitalization'
                || CHR (9)
                || 'Revaluation'
                || CHR (9)
                || 'Reclasses'
                || CHR (9)
                || 'Transfers'
                || CHR (9)
                --|| 'Ending Balance' --  commented by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)          --  commented by Showkath v5.0 on 07-Jul-2015
                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                || 'End Balance in <Functional Currency>'
                || CHR (9)
                || 'End Balance <'
                || p_currency
                || '> at Spot Rate'
                || CHR (9)
                --|| 'End FX Translation'  --  commented by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)               --  commented by Showkath v5.0 on 07-Jul-2015
                || 'Net FX Translation'
                || CHR (9)   -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                          --|| 'Impairment'      --  commented by Showkath v5.0 on 07-Jul-2015
                          --|| CHR (9)           --  commented by Showkath v5.0 on 07-Jul-2015
                          --|| 'Net Book Value'  --  commented by Showkath v5.0 on 07-Jul-2015
                );


       */


        FOR m
            IN (SELECT book_type_code
                  FROM fa_book_controls
                 WHERE     book_type_code = NVL (p_book, book_type_code)
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE)
        LOOP
            BEGIN
                SELECT period_name
                  INTO l_period_from
                  FROM fa_deprn_periods
                 WHERE     book_type_code = m.book_type_code
                       AND period_name = p_from_period;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_period_from   := NULL;
            END;

            BEGIN
                SELECT period_name
                  INTO l_period_to
                  FROM fa_deprn_periods
                 WHERE     book_type_code = m.book_type_code
                       AND period_name = p_to_period;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_period_to   := NULL;
            END;


            BEGIN
                SELECT currency_code
                  INTO g_from_currency
                  FROM gl_sets_of_books gsob, fa_book_controls fbc
                 WHERE     gsob.set_of_books_id = fbc.set_of_books_id
                       AND fbc.book_type_code = m.book_type_code
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;


            IF (l_period_from IS NOT NULL AND l_period_to IS NOT NULL)
            THEN
                -- End changes by BT Technology Team v4.1 on 26-Dec-2014

                -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                EXECUTE IMMEDIATE 'Truncate table xxdo.xxd_fa_roll_fwd_rep_t';

                -- End changes by BT Technology Team v4.1 on 26-Dec-2014

                --Retrofit assgnment of sob_id  by BT Technology team 10 Nov 14
                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                --g_set_of_books_id := xxd_fa_return_sob_id_fnc (p_book, p_currency);
                g_set_of_books_id   :=
                    xxd_fa_return_sob_id_fnc (m.book_type_code, p_currency);

                fnd_file.put_line (fnd_file.LOG,
                                   'g_set_of_books_id:' || g_set_of_books_id);

                -- Start changes by BT Technology Team v4.2 on 26-Dec-2014
                BEGIN
                    h_set_of_books_id   :=
                        xxd_fa_set_client_info_fnc (g_set_of_books_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        h_set_of_books_id   := NULL;
                END;

                fnd_file.put_line (
                    fnd_file.LOG,
                    ' h_set_of_books_id:' || h_set_of_books_id);

                IF (h_set_of_books_id IS NOT NULL)
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           ' h_set_of_books_id is not null:'
                        || h_set_of_books_id);

                    IF NOT fa_cache_pkg.fazcsob (
                               x_set_of_books_id     => h_set_of_books_id,
                               x_mrc_sob_type_code   => h_reporting_flag)
                    THEN
                        RAISE fnd_api.g_exc_unexpected_error;
                    END IF;
                ELSE
                    h_reporting_flag   := 'P';
                END IF;

                fnd_file.put_line (fnd_file.LOG,
                                   ' h_reporting_flag:' || h_reporting_flag);

                -- End changes by BT Technology Team v4.2 on 26-Dec-2014

                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'p_book:' || p_book);
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'p_period:' || p_to_period);
                /*run FA_RSVLDG_PROC*/
                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                xxd_fa_roll_fwd_pkg.xxd_fa_rsvldg_proc (m.book_type_code --p_book
                                                                        ,
                                                        l_period_to); --p_to_period);

                -- Commented and moved above for v4.1 on 26-Dec-2014
                /*BEGIN
                   SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                     INTO v_report_date
                     FROM sys.DUAL;
                END;*/

                -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                --Moved the code outside m loop
                EXECUTE IMMEDIATE 'Truncate table xxdo.xxd_fa_roll_fwd_t';

                -- End changes by BT Technology Team v4.1 on 26-Dec-2014

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                insert_info (book => m.book_type_code,               --p_book,
                                                       start_period_name => l_period_from, --p_from_period,
                                                                                           end_period_name => l_period_to
                             ,                                  --p_to_period,
                               report_type => 'CIP COST', adj_mode => NULL);

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                insert_info (book => m.book_type_code,               --p_book,
                                                       start_period_name => l_period_from, --p_from_period,
                                                                                           end_period_name => l_period_to
                             ,                                  --p_to_period,
                               report_type => 'COST', adj_mode => NULL);

                -- Begin Changes CCR0009036

                BEGIN
                    SELECT COUNT (1) INTO l_cnt FROM xxdo.xxd_fa_roll_fwd_t;

                    apps.fnd_file.put_line (apps.fnd_file.LOG, l_cnt);

                    UPDATE xxdo.xxd_fa_roll_fwd_t u
                       SET adjustment_ccid   =
                               (SELECT s.adjustment_ccid
                                  FROM xxdo.xxd_fa_roll_fwd_t s
                                 WHERE     s.distribution_ccid =
                                           u.distribution_ccid
                                       AND s.asset_id = u.asset_id
                                       AND s.source_type_code NOT IN
                                               ('BEGIN', 'END')
                                       AND ROWNUM = 1)
                     WHERE     u.adjustment_ccid IS NULL
                           AND u.source_type_code IN ('BEGIN', 'END');

                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           SQL%ROWCOUNT
                        || ' Records updated with Adjustment CCID');
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Exception Occured while updating the Adjustment CCID');
                END;

                BEGIN
                    UPDATE xxdo.xxd_fa_roll_fwd_t u
                       SET adjustment_ccid   =
                               (SELECT lines.code_combination_id
                                  FROM fa_lookups rt, fa_distribution_history dh, fa_transaction_headers th,
                                       fa_asset_history ah, fa_adjustments aj, xla_ae_headers headers,
                                       xla_ae_lines lines, xla_distribution_links links
                                 -- fa_deprn_periods fdp
                                 WHERE     rt.lookup_type = 'REPORT TYPE'
                                       AND rt.lookup_code = u.report_type
                                       -- AND fdp.book_type_code = m.book_type_code
                                       -- AND fdp.period_counter = aj.period_counter_created
                                       AND dh.book_type_code =
                                           m.book_type_code
                                       AND aj.asset_id = dh.asset_id
                                       AND aj.book_type_code =
                                           m.book_type_code
                                       AND aj.distribution_id =
                                           dh.distribution_id
                                       AND aj.adjustment_type IN
                                               (u.report_type, DECODE (u.report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                       --                           AND aj.period_counter_created BETWEEN period1_pc
                                       --                                                             AND period2_pc
                                       AND th.transaction_header_id =
                                           aj.transaction_header_id
                                       AND ah.asset_id = dh.asset_id
                                       AND ((ah.asset_type != 'EXPENSED' AND u.report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND u.report_type IN ('RESERVE', 'REVAL RESERVE')))
                                       AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                        AND NVL (
                                                                                  ah.transaction_header_id_out
                                                                                - 1,
                                                                                th.transaction_header_id)
                                       AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                           0
                                       AND links.source_distribution_id_num_1 =
                                           aj.transaction_header_id
                                       AND links.source_distribution_id_num_2 =
                                           aj.adjustment_line_id
                                       AND links.application_id = 140
                                       AND links.source_distribution_type =
                                           'TRX'
                                       AND headers.application_id = 140
                                       AND headers.ae_header_id =
                                           links.ae_header_id
                                       AND headers.ledger_id =
                                           h_set_of_books_id
                                       AND lines.ae_header_id =
                                           links.ae_header_id
                                       AND lines.ae_line_num =
                                           links.ae_line_num
                                       AND lines.application_id = 140
                                       AND dh.code_combination_id =
                                           u.distribution_ccid
                                       AND dh.asset_id = u.asset_id
                                       AND ROWNUM = 1)
                     WHERE     u.source_type_code IN ('BEGIN', 'END')
                           AND u.adjustment_ccid IS NULL;

                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           SQL%ROWCOUNT
                        || ' Records updated with Adjustment CCID');
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        apps.fnd_file.put_line (
                            apps.fnd_file.LOG,
                            'Exception Occured while updating the Adjustment CCID');
                END;

                -- End Changes CCR0009036

                --START changes by showkath on 12/01/2015 to fix net fx translation requirement
                BEGIN
                    SELECT currency_code
                      INTO l_func_currency_spot
                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                     WHERE     gsob.set_of_books_id = fbc.set_of_books_id
                           AND fbc.book_type_code = m.book_type_code
                           AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_func_currency   := NULL;
                END;

                g_from_currency   := l_func_currency_spot;

                --            g_to_currency := p_currency;


                --END changes by showkath on 12/01/2015 to fix net fx translation requirement
                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                --IF (p_currency = 'USD')--Changes by showkath on 12/01/2015
                IF (p_currency <> l_func_currency_spot)
                THEN
                    BEGIN
                        SELECT conversion_rate
                          INTO ln_begin_spot_rate
                          FROM gl_daily_rates
                         WHERE     from_currency =
                                   (SELECT currency_code
                                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                                     WHERE     gsob.set_of_books_id =
                                               fbc.set_of_books_id
                                           AND fbc.book_type_code =
                                               m.book_type_code
                                           AND NVL (date_ineffective,
                                                    SYSDATE + 1) >
                                               SYSDATE)
                               AND to_currency = 'USD'
                               --AND TRUNC (conversion_date) = TRUNC (TO_DATE (p_from_period, 'MON-YY') - 1)
                               AND TRUNC (conversion_date) =
                                   (SELECT TRUNC (calendar_period_open_date) - 1
                                      FROM fa_deprn_periods
                                     WHERE     period_name = p_from_period
                                           AND book_type_code =
                                               m.book_type_code)
                               AND conversion_type = 'Spot';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to derive spot rate for the perod'
                                || ''
                                || p_from_period);
                            ln_begin_spot_rate   := NULL;
                            retcode              := 2; -- added to complete the program with error if spot rate is not defined.
                            EXIT;
                    END;

                    BEGIN
                        SELECT conversion_rate
                          INTO ln_end_spot_rate
                          FROM gl_daily_rates
                         WHERE     from_currency =
                                   (SELECT currency_code
                                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                                     WHERE     gsob.set_of_books_id =
                                               fbc.set_of_books_id
                                           AND fbc.book_type_code =
                                               m.book_type_code
                                           AND NVL (date_ineffective,
                                                    SYSDATE + 1) >
                                               SYSDATE)
                               AND to_currency = 'USD'
                               --AND TRUNC (conversion_date) = TRUNC (TO_DATE (p_to_period, 'MON-YY') - 1)
                               AND TRUNC (conversion_date) =
                                   (SELECT TRUNC (calendar_period_close_date)
                                      FROM fa_deprn_periods
                                     WHERE     period_name = p_to_period
                                           AND book_type_code =
                                               m.book_type_code)
                               AND conversion_type = 'Spot';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to derive spot rate for the perod'
                                || ''
                                || p_to_period);
                            ln_end_spot_rate   := NULL;
                            retcode            := 2; -- added to complete the program with warning if spot rate is not defined
                            EXIT; -- added to complete the program with warning if spot rate is not defined
                    END;
                ELSE
                    ln_begin_spot_rate   := NULL;
                    ln_end_spot_rate     := NULL;
                END IF;

                print_log_prc ('Begin Spot Rate ' || ln_begin_spot_rate);
                print_log_prc ('End Spot Rate ' || ln_end_spot_rate);
                -- End changes by BT Technology Team v4.1 on 24-Dec-2014

                v_null_count      := 0;

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                FOR crec
                    IN c_header (cp_book      => m.book_type_code,   --p_book,
                                 p_currency   => p_currency)
                LOOP
                    BEGIN
                        v_custodian              := NULL;
                        v_depreciation_account   := NULL;

                        SELECT per.global_name custodian
                          INTO v_custodian
                          FROM apps.fa_distribution_history dh, apps.per_people_f per
                         WHERE     dh.asset_id = crec.asset_id  --asset_number
                               AND dh.book_type_code = m.book_type_code --p_book
                               AND dh.date_ineffective IS NULL
                               AND dh.assigned_to = per.person_id(+)
                               AND TRUNC (SYSDATE) BETWEEN NVL (
                                                               per.effective_start_date,
                                                               TRUNC (
                                                                   SYSDATE))
                                                       AND NVL (
                                                               per.effective_end_date,
                                                               TRUNC (
                                                                   SYSDATE));
                    --fnd_file.put_line (fnd_file.LOG, 'Custodian is: ' || v_custodian);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Exception in Custodian is: '
                                || SUBSTR (SQLERRM, 1, 200));
                            v_custodian              := NULL;
                            v_depreciation_account   := NULL;
                    END;

                    BEGIN
                        v_cost   := 0;

                        SELECT fbbc.cost
                          INTO v_cost
                          FROM fa_books fb, fa_books_book_controls_v fbbc
                         WHERE     fb.asset_id = crec.asset_id
                               --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                               AND fb.book_type_code = m.book_type_code -- p_book
                               AND fb.date_ineffective IS NULL
                               AND fb.transaction_header_id_in =
                                   fbbc.transaction_header_id_in;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            /*fnd_file.put_line (
                               fnd_file.LOG,
                               'Exception in Cost is: ' || SUBSTR (SQLERRM, 1, 200));*/
                            v_cost   := 0;
                    END;

                    BEGIN
                        v_dep_reserve   := 0;

                        SELECT apps.xxd_fa_roll_fwd_pkg.xxd_fa_depreciation_cost (crec.asset_id, --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                                                                                                 m.book_type_code --p_book
                                                                                                                 )
                          INTO v_dep_reserve
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Exception in Accumulated Depri is: '
                                || SUBSTR (SQLERRM, 1, 200));
                            v_dep_reserve   := 0;
                    END;

                    INSERT INTO xxdo.xxd_fa_roll_fwd_rep_t (
                                    book,
                                    period_from,
                                    period_to,
                                    currency,
                                    asset_category,
                                    asset_cost_comb, -- Added as per CCR0009036
                                    asset_cost_account,
                                    brand,
                                    asset_number,
                                    location, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                    description,
                                    custodian,
                                    cost_center,
                                    parent_asset,
                                    begin_year,
                                    begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                    addition,
                                    adjustment,
                                    retirement,
                                    capitalization,
                                    revaluation,
                                    reclass,
                                    transfer,
                                    addition_nonf,
                                    adjustment_nonf,
                                    retirement_nonf,
                                    capitalization_nonf,
                                    revaluation_nonf,
                                    reclass_nonf,
                                    transfer_nonf,
                                    end_year,
                                    end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                    report_type,
                                    asset_id,
                                    impairment,
                                    net_book_value)
                         --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                         VALUES (m.book_type_code,                   --p_book,
                                                   p_from_period, p_to_period, p_currency, crec.asset_category, crec.asset_xla_comb, -- Added as per CCR0009036
                                                                                                                                     crec.asset_cost_account, crec.brand, crec.asset_number, crec.location, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                                                            crec.description, v_custodian, crec.cost_center, crec.parent_asset, crec.begin_year, crec.begin_year, --crec.begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                                                                                                                                                                  crec.addition, crec.adjustment, crec.retirement, crec.capitalization, crec.revaluation, crec.reclass, crec.transfer, crec.addition_nonf, crec.adjustment_nonf, crec.retirement_nonf, crec.capitalization_nonf, crec.revaluation_nonf, crec.reclass_nonf, crec.transfer_nonf, crec.end_year, crec.end_year, --crec.end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             crec.report_type
                                 , crec.asset_id, 0, --retrofit for Impairment V 4.0 on 13 Nov 2014
                                                     0);

                    COMMIT;
                END LOOP;

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                FOR net_book IN c_net_book (m.book_type_code)        --p_book)
                LOOP
                    apps.xxd_fa_roll_fwd_pkg.xxd_fa_update_impairment (
                        net_book.asset_id,
                        --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                        m.book_type_code);                          --p_book);
                    --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                    apps.xxd_fa_roll_fwd_pkg.xxd_fa_net_book_value (
                        net_book.asset_id,
                        m.book_type_code);                          --p_book);
                END LOOP;

                FOR k IN c_dis
                LOOP
                    FOR j IN c_dis1 (k.info)
                    LOOP
                        BEGIN
                            FOR i IN c_output (k.info)
                            LOOP
                                BEGIN
                                    SELECT DISTINCT period_name
                                      INTO v_period_from
                                      FROM fa_deprn_periods
                                     WHERE period_name = i.period_from;
                                END;

                                BEGIN
                                    SELECT DISTINCT period_name
                                      INTO v_period_to
                                      FROM fa_deprn_periods
                                     WHERE period_name = i.period_to;
                                END;

                                BEGIN
                                    SELECT DISTINCT
                                           TO_CHAR (date_placed_in_service, 'DD-MON-YYYY')
                                      INTO v_date_in_service
                                      FROM xxdo.xxd_fa_roll_rsv_ledger_t
                                     WHERE     asset_id = i.asset_id --asset_number
                                           AND (transaction_type IS NULL OR transaction_type NOT IN ('R', 'T'));
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        v_date_in_service   := NULL;
                                END;

                                BEGIN
                                    SELECT DISTINCT method_code
                                      INTO v_method_code
                                      FROM xxdo.xxd_fa_roll_rsv_ledger_t
                                     WHERE     asset_id = i.asset_id --i.asset_number
                                           AND (transaction_type IS NULL OR transaction_type NOT IN ('R', 'T'));
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        v_method_code   := NULL;
                                END;

                                BEGIN
                                    SELECT DISTINCT ROUND (life / 12, 2)
                                      INTO v_life
                                      FROM xxdo.xxd_fa_roll_rsv_ledger_t
                                     WHERE     asset_id = i.asset_id --i.asset_number
                                           AND (transaction_type IS NULL OR transaction_type NOT IN ('R', 'T'));
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        v_life   := NULL;
                                END;

                                BEGIN
                                    SELECT SUM (cost) - SUM (deprn_reserve) - SUM (NVL (xfr.impairment, 0)) -- Retofit for Impairment 4.0 on 13 Nov 2014 by BT Team
                                      INTO v_net_book_value
                                      FROM xxdo.xxd_fa_roll_rsv_ledger_t a, xxdo.xxd_fa_roll_fwd_rep_t xfr
                                     WHERE     a.asset_id = i.asset_id
                                           AND a.asset_id = xfr.asset_id; --i.asset_number
                                END;

                                --START changes by showkath on 12/01/2015 to fix net fx translation requirement
                                BEGIN
                                    SELECT currency_code
                                      INTO l_func_currency
                                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                                     WHERE     gsob.set_of_books_id =
                                               fbc.set_of_books_id
                                           AND fbc.book_type_code =
                                               m.book_type_code
                                           AND NVL (date_ineffective,
                                                    SYSDATE + 1) >
                                               SYSDATE;

                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'book' || m.book_type_code);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'currency' || l_func_currency);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_func_currency   := NULL;
                                END;

                                --END changes by showkath on 12/01/2015 to fix net fx translation requirement
                                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                /*IF (h_reporting_flag = 'P')
                                THEN
                                   ln_begin_spot := NULL;
                                   ln_begin_trans := NULL;
                                   ln_end_spot := NULL;
                                   ln_end_trans := NULL;
                                   ln_net_trans := NULL;
                                ELSE*/
                                --comented by showkath to display below values for h_reporting_flag = P 11/18/2015
                                BEGIN
                                    IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                                    THEN
                                        ln_begin_spot   :=
                                              NVL (i.begin_year_fun, 0)
                                            * NVL (ln_begin_spot_rate, 1);

                                        ln_end_spot   :=
                                              NVL (i.end_year_fun, 0)
                                            * NVL (ln_end_spot_rate, 1);
                                    ELSE
                                        ln_begin_spot   :=
                                              NVL (i.begin_year_fun, 0)
                                            * ln_begin_spot_rate;
                                        ln_begin_trans   :=
                                            ln_begin_spot - i.begin_year;
                                        ln_end_spot   :=
                                              NVL (i.end_year_fun, 0)
                                            * ln_end_spot_rate;
                                        ln_end_trans   :=
                                            ln_end_spot - i.end_year;
                                    END IF;
                                --ln_net_trans := ln_end_trans - ln_begin_trans; -- commented by showkath on 01-DEC-2015 to fix net fx translation
                                END;

                                --END IF;

                                -- End changes by BT Technology Team v4.1 on 24-Dec-2014

                                -- Start changes by Showkath v5.0 on 07-Jul-2015
                                --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                                IF (p_currency <> NVL (l_func_currency, 'X'))
                                THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                                    BEGIN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'book_type_code:' || m.book_type_code);

                                        SELECT DISTINCT conversion_rate
                                          INTO ln_conversion_rate
                                          FROM apps.gl_daily_rates
                                         WHERE     from_currency =
                                                   (SELECT currency_code
                                                      FROM gl_sets_of_books gsob, FA_BOOK_CONTROLS fbc
                                                     WHERE     GSOB.SET_OF_BOOKS_ID =
                                                               fbc.SET_OF_BOOKS_ID
                                                           AND fbc.BOOK_TYPE_CODE =
                                                               m.book_type_code
                                                           AND NVL (
                                                                   DATE_INEFFECTIVE,
                                                                     SYSDATE
                                                                   + 1) >
                                                               SYSDATE)
                                               AND to_currency = 'USD'
                                               AND conversion_type =
                                                   'Corporate'
                                               AND TO_CHAR (conversion_date,
                                                            'MON-YY') =
                                                   (SELECT TO_CHAR (calendar_period_open_date, 'MON-YY')
                                                      FROM fa_deprn_periods fdp
                                                     WHERE     period_name =
                                                               p_from_period
                                                           AND book_type_code =
                                                               m.book_type_code);

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Transactional Date exchange rate:'
                                            || ln_conversion_rate);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_conversion_rate   := 1;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'In exception of Transactional Date exchange rate:'
                                                || SQLERRM);
                                    END;

                                    ln_addition         := i.addition_nonf;
                                    ln_adjustment       := i.adjustment_nonf;
                                    ln_retirement       := i.retirement_nonf;
                                    ln_capitalization   :=
                                        i.capitalization_nonf;
                                    ln_revaluation      := i.revaluation_nonf;
                                    ln_reclass          := i.reclass_nonf;
                                    ln_transfer         := i.transfer_nonf;

                                    ln_net_trans        := NULL;
                                    ln_net_trans        :=
                                          NVL (ln_end_spot, 0)
                                        - ( /*NVL ( (i.begin_year * ln_conversion_rate),
                                                 0)*/
                                            --commented by showkath on 07-DEC-2015 to fix total issue.
                                           NVL (ln_begin_spot, 0) --added by showkath on 07-DEC-2015 to fix total issue.
                                                                  + NVL (ln_addition, 0) + NVL (ln_adjustment, 0) + NVL (ln_retirement, 0) + NVL (ln_capitalization, 0) + NVL (ln_revaluation, 0) + NVL (ln_reclass, 0) + NVL (ln_transfer, 0));
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Program is running with USD Currency-Values with Conversion Rate');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        '------------------------------------------');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'begin balance:' || i.begin_year);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Additions:' || ln_addition);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Adjustments:' || ln_adjustment);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Retirement:' || ln_retirement);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Captalization:' || ln_capitalization);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Revaluation:' || ln_revaluation);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Reclass:' || ln_reclass);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Transfer:' || ln_transfer);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Net FX Transaction:' || ln_net_trans);
                                ELSE
                                    ln_addition         := i.addition;
                                    ln_adjustment       := i.adjustment;
                                    ln_retirement       := i.retirement;
                                    ln_capitalization   := i.capitalization;
                                    ln_revaluation      := i.revaluation;
                                    ln_reclass          := i.reclass;
                                    ln_transfer         := i.transfer;
                                    ln_net_trans        := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Program is running with Non USD Currency-Values without Conversion Rate');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        '------------------------------------------');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Additions:123' || ln_addition);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Adjustments:' || ln_adjustment);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Retirement:' || ln_retirement);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Captalization:' || ln_capitalization);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Revaluation:' || ln_revaluation);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Reclass:' || ln_reclass);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Transfer:' || ln_transfer);
                                END IF;

                                --End Changes by Showkath v5.0 on 07-Jul-2015

                                IF SIGN (ln_reclass) = -1
                                THEN
                                    BEGIN
                                        SELECT segment1 || '-' || segment2 || '-' || segment3
                                          INTO l_category
                                          FROM apps.fa_transaction_headers fth, apps.fa_deprn_periods fdp_to, apps.fa_asset_history fh,
                                               apps.fa_categories fc
                                         WHERE     1 = 1
                                               AND fh.transaction_header_id_out =
                                                   fth.transaction_header_id
                                               AND fth.asset_id = i.asset_id
                                               AND fc.category_id =
                                                   fh.category_id
                                               AND fth.book_type_code =
                                                   fdp_to.book_type_code
                                               AND fth.transaction_date_entered <=
                                                   fdp_to.calendar_period_close_date
                                               AND fth.transaction_type_code IN
                                                       ('ADDITION', 'RECLASS')
                                               AND fdp_to.period_name =
                                                   p_to_period
                                               AND fth.book_type_code =
                                                   m.book_type_code
                                               AND fth.transaction_header_id =
                                                   (SELECT MAX (fth2.transaction_header_id)
                                                      FROM apps.fa_transaction_headers fth2
                                                     WHERE     1 = 1
                                                           AND fth2.book_type_code =
                                                               fth.book_type_code
                                                           AND fth2.asset_id =
                                                               fth.asset_id
                                                           AND fth2.transaction_date_entered <=
                                                               fdp_to.calendar_period_close_date
                                                           AND fth2.transaction_type_code IN
                                                                   ('ADDITION', 'RECLASS'));

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Category in negative Value:'
                                            || l_category
                                            || ' for asset'
                                            || i.asset_id);
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            BEGIN
                                                SELECT fc.segment1 || '-' || fc.segment2 || '-' || fc.segment3
                                                  INTO l_category
                                                  FROM apps.fa_transaction_headers fth, apps.fa_deprn_periods fdp_to, apps.fa_asset_history fh,
                                                       apps.fa_categories fc
                                                 WHERE     1 = 1
                                                       AND fh.transaction_header_id_in =
                                                           fth.transaction_header_id
                                                       AND fth.asset_id =
                                                           i.asset_id
                                                       AND fc.category_id =
                                                           fh.category_id
                                                       AND fth.book_type_code =
                                                           fdp_to.book_type_code
                                                       AND fth.transaction_date_entered <=
                                                           fdp_to.calendar_period_close_date
                                                       AND fth.transaction_type_code IN
                                                               ('ADDITION')
                                                       AND fdp_to.period_name =
                                                           p_to_period
                                                       AND fth.book_type_code =
                                                           m.book_type_code;


                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Category in No Data Found query Value:'
                                                    || l_category
                                                    || ' for asset'
                                                    || i.asset_id);
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    l_category   :=
                                                        i.asset_category;
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           'Category in No Data Found exception query Value:'
                                                        || l_category);
                                            END;
                                        WHEN OTHERS
                                        THEN
                                            l_category   := NULL;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Category in Others exception:'
                                                || l_category);
                                    END;
                                ELSE
                                    --added by showkath on 04-DEC=2015
                                    BEGIN
                                        SELECT segment1 || '-' || segment2 || '-' || segment3
                                          INTO l_category
                                          FROM apps.fa_transaction_headers fth, apps.fa_deprn_periods fdp_to, apps.fa_asset_history fh,
                                               apps.fa_categories fc
                                         WHERE     1 = 1
                                               AND fh.transaction_header_id_in =
                                                   fth.transaction_header_id
                                               AND fth.asset_id = i.asset_id
                                               AND fc.category_id =
                                                   fh.category_id
                                               AND fth.book_type_code =
                                                   fdp_to.book_type_code
                                               AND fth.transaction_date_entered <=
                                                   fdp_to.calendar_period_close_date
                                               AND fth.transaction_type_code IN
                                                       ('ADDITION', 'RECLASS')
                                               AND fdp_to.period_name =
                                                   p_to_period
                                               AND fth.book_type_code =
                                                   m.book_type_code
                                               AND fth.transaction_header_id =
                                                   (SELECT MAX (fth2.transaction_header_id)
                                                      FROM apps.fa_transaction_headers fth2
                                                     WHERE     1 = 1
                                                           AND fth2.book_type_code =
                                                               fth.book_type_code
                                                           AND fth2.asset_id =
                                                               fth.asset_id
                                                           AND fth2.transaction_date_entered <=
                                                               fdp_to.calendar_period_close_date
                                                           AND fth2.transaction_type_code IN
                                                                   ('ADDITION', 'RECLASS'));

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Category for possitive value:'
                                            || l_category
                                            || ' for asset'
                                            || i.asset_id);
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            BEGIN
                                                SELECT fc.segment1 || '-' || fc.segment2 || '-' || fc.segment3
                                                  INTO l_category
                                                  FROM apps.fa_transaction_headers fth, apps.fa_deprn_periods fdp_to, apps.fa_asset_history fh,
                                                       apps.fa_categories fc
                                                 WHERE     1 = 1
                                                       AND fh.transaction_header_id_in =
                                                           fth.transaction_header_id
                                                       AND fth.asset_id =
                                                           i.asset_id
                                                       AND fc.category_id =
                                                           fh.category_id
                                                       AND fth.book_type_code =
                                                           fdp_to.book_type_code
                                                       AND fth.transaction_date_entered <=
                                                           fdp_to.calendar_period_close_date
                                                       AND fth.transaction_type_code IN
                                                               ('ADDITION')
                                                       AND fdp_to.period_name =
                                                           p_to_period
                                                       AND fth.book_type_code =
                                                           m.book_type_code;


                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Category in No Data Found query Value:'
                                                    || l_category
                                                    || ' for asset'
                                                    || i.asset_id);
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    l_category   :=
                                                        i.asset_category;
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           'Category in No Data Found exception query Value:'
                                                        || l_category);
                                            END;
                                        WHEN OTHERS
                                        THEN
                                            l_category   := NULL;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Category in Others exception:'
                                                || l_category);
                                    END;
                                END IF;

                                --End changes
                                -- Begin Changes CCR0009036
                                /*
                                                        apps.fnd_file.put_line (
                                                           apps.fnd_file.output,
                                                              i.book
                                                           || CHR (9)
                                                           || TO_CHAR (TO_DATE (v_period_from, 'MON-RR'),
                                                                       'MON-RRRR')    --TO_CHAR(v_period_from)
                                                           || CHR (9)
                                                           || TO_CHAR (TO_DATE (v_period_to, 'MON-RRRR'),
                                                                       'MON-RRRR')      --TO_CHAR(v_period_to)
                                                           || CHR (9)
                                                           || i.currency
                                                           || CHR (9)
                                                           || NVL (l_category, i.asset_category)
                                                           || CHR (9)
                                                           || i.asset_cost_account
                                                           || CHR (9)
                                                           || i.asset_cost_comb  -- Changes CCR0009036
                                                           || CHR (9)            -- Changes CCR0009036
                                                           || i.cost_center
                                                           || CHR (9)
                                                           || i.brand
                                                           || CHR (9)
                                                           || i.asset_number
                                                           || CHR (9)
                                                           || i.description
                                                           || CHR (9)
                                                           || i.custodian
                                                           -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
                                                           /*|| CHR (9)
                                                           || i.parent_asset*/
                                /*|| CHR (9)
                                || i.location
                                -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                                || CHR (9)
                                || v_date_in_service --NULL--i.date_placed_in_service
                                || CHR (9)
                                || v_method_code             --NULL--i.deprn_method
                                || CHR (9)
                                || v_life                      --NULL--i.life_yr_mo
                                || CHR (9)
                                --|| to_char(i.begin_year, 'FM999G999G999G999D99')  --  commented by Showkath v5.0 on 07-Jul-2015
                                --|| CHR (9)                                        --  commented by Showkath v5.0 on 07-Jul-2015
                                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                || TO_CHAR (i.begin_year_fun,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_begin_spot, 'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_addition, 'FM999G999G999G999D99') --v_addition_total--i.addition
                                || CHR (9)
                                || TO_CHAR ( (NVL (ln_adjustment, 0)),
                                            'FM999G999G999G999D99') --v_adjustment_total--i.adjustment
                                || CHR (9)
                                || TO_CHAR (ln_retirement, 'FM999G999G999G999D99') --v_retirement_total--i.retirement
                                || CHR (9)
                                || TO_CHAR (ln_capitalization,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_revaluation,
                                            'FM999G999G999G999D99') --v_revaluation_total--i.revaluation
                                || CHR (9)
                                || TO_CHAR (ln_reclass, 'FM999G999G999G999D99') --v_reclass_total--i.reclass
                                || CHR (9)
                                || TO_CHAR (ln_transfer, 'FM999G999G999G999D99') --v_transfer_total--i.transfer
                                || CHR (9)
                                --|| to_char(i.end_year, 'FM999G999G999G999D99')
                                --|| CHR (9)
                                -- End changes by Showkath v5.0 on 07-Jul-2015
                                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                || TO_CHAR (i.end_year_fun,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_end_spot, 'FM999G999G999G999D99')
                                || CHR (9)
                                --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                                --|| CHR (9)                                       --changes by Showkath v5.0 on 07-Jul-2015
                                || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')
                                || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                          --|| to_char(i.impairment, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                                          --|| CHR (9)                                             --changes by Showkath v5.0 on 07-Jul-2015
                                          --|| to_char(i.net_book_value, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                                );
     */
                                v_num   := v_num + 1;

                                INSERT INTO XXDO.XXD_FA_ROLL_FWD_REP_XML_T (
                                                rownumber,
                                                book,
                                                period_from,
                                                period_to,
                                                currency,
                                                asset_category,
                                                asset_cost_account,
                                                asset_cost_comb,
                                                cost_center,
                                                brand,
                                                asset_number,
                                                description,
                                                custodian,
                                                location,
                                                date_placed_in_service,
                                                deprn_method,
                                                life_yr_mo,
                                                begin_year_fun,
                                                begin_year_spot,
                                                addition,
                                                adjustment,
                                                retirement,
                                                capitalization,
                                                revaluation,
                                                reclass,
                                                transfer,
                                                end_year_fun,
                                                end_year_spot,
                                                net_trans)
                                     VALUES (v_num, i.book, TO_CHAR (TO_DATE (v_period_from, 'MON-RR'), 'MON-RRRR'), TO_CHAR (TO_DATE (v_period_to, 'MON-RRRR'), 'MON-RRRR'), i.currency, NVL (l_category, i.asset_category), i.asset_cost_account, i.asset_cost_comb, i.cost_center, i.brand, i.asset_number, i.description, i.custodian, i.location, v_date_in_service, v_method_code, v_life, /*                                                                        DECODE (TRIM (TO_CHAR (i.begin_year_fun,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (i.begin_year_fun,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_begin_spot,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_begin_spot,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_addition,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_addition,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (NVL (ln_adjustment,0),'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_adjustment,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_retirement,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_retirement,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_capitalization,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_capitalization,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_revaluation,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_revaluation,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_reclass,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_reclass,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_transfer,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_transfer,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (i.end_year_fun,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (i.end_year_fun,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_end_spot,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_end_spot,'999G999G999G999G999D99'))),
                                                                                                                                                                                                                                                                                                                                                                                                                                                                        DECODE (TRIM (TO_CHAR (ln_net_trans,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_net_trans,'999G999G999G999G999D99'))) */
                                                                                                                                                                                                                                                                                                                                                                                                 i.begin_year_fun, ln_begin_spot, ln_addition, NVL (ln_adjustment, 0), ln_retirement, ln_capitalization, ln_revaluation, ln_reclass, ln_transfer, i.end_year_fun
                                             , ln_end_spot, ln_net_trans);
                            -- End Changes CCR0009036

                            END LOOP;

                            COMMIT;                -- Added Changes CCR0009036

                            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                            /*IF (h_reporting_flag = 'P')
                            THEN
                               ln_begin_spot := NULL;
                               ln_begin_trans := NULL;
                               ln_end_spot := NULL;
                               ln_end_trans := NULL;
                               ln_net_trans := NULL;
                            ELSE*/
                            --comented by showkath to display below values for h_reporting_flag = P 11/18/2015
                            BEGIN
                                IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                                THEN
                                    ln_begin_spot   :=
                                          NVL (j.begin_year_fun, 0)
                                        * NVL (ln_begin_spot_rate, 1);

                                    ln_end_spot   :=
                                          NVL (j.end_year_fun, 0)
                                        * NVL (ln_end_spot_rate, 1);
                                ELSE
                                    ln_begin_spot   :=
                                          NVL (j.begin_year_fun, 0)
                                        * ln_begin_spot_rate;
                                    ln_begin_trans   :=
                                        ln_begin_spot - j.begin_year;
                                    ln_end_spot   :=
                                          NVL (j.end_year_fun, 0)
                                        * ln_end_spot_rate;
                                    ln_end_trans   :=
                                        ln_end_spot - j.end_year;
                                --ln_net_trans := ln_end_trans - ln_begin_trans; -- commented by showkath on 01-DEC-2015 to fix net fx translation
                                END IF;
                            END;

                            --END IF;

                            -- End changes by BT Technology Team v4.1 on 24-Dec-2014

                            --Begin Changes by Showkath v5.0 on 07-Jul-2015
                            --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                            IF (p_currency <> NVL (l_func_currency, 'X'))
                            THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Transactional Date exchange rate:'
                                    || ln_conversion_rate);
                                ln_addition         := NULL;
                                ln_adjustment       := NULL;
                                ln_retirement       := NULL;
                                ln_capitalization   := NULL;
                                ln_revaluation      := NULL;
                                ln_reclass          := NULL;
                                ln_transfer         := NULL;
                                ln_addition         := j.addition_nonf;
                                ln_adjustment       := j.adjustment_nonf;
                                ln_retirement       := j.retirement_nonf;
                                ln_capitalization   := j.capitalization_nonf;
                                ln_revaluation      := j.revaluation_nonf;
                                ln_reclass          := j.reclass_nonf;
                                ln_transfer         := j.transfer_nonf;
                                ln_net_trans        := NULL;
                                ln_net_trans        :=
                                      NVL (ln_end_spot, 0) --added by showkath to fix total issue
                                    - ( /*NVL ( (j.begin_year * ln_conversion_rate), 0)*/
                                       NVL (ln_begin_spot, 0) + NVL (ln_addition, 0) + NVL (ln_adjustment, 0) + NVL (ln_retirement, 0) + NVL (ln_capitalization, 0) + NVL (ln_revaluation, 0) + NVL (ln_reclass, 0) + NVL (ln_transfer, 0));
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Program is running with USD Currency-Values with Conversion Rate');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '------------------------------------------');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Additions:' || ln_addition);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Adjustments:' || ln_adjustment);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Retirement:' || ln_retirement);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Captalization:' || ln_capitalization);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Revaluation:' || ln_revaluation);
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Reclass:' || ln_reclass);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Transfer:' || ln_transfer);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Net FX Transaction:' || ln_net_trans);
                            ELSE
                                ln_addition         := NULL;
                                ln_adjustment       := NULL;
                                ln_retirement       := NULL;
                                ln_capitalization   := NULL;
                                ln_revaluation      := NULL;
                                ln_reclass          := NULL;
                                ln_transfer         := NULL;
                                ln_addition         := j.addition;
                                ln_adjustment       := j.adjustment;
                                ln_retirement       := j.retirement;
                                ln_capitalization   := j.capitalization;
                                ln_revaluation      := j.revaluation;
                                ln_reclass          := j.reclass;
                                ln_transfer         := j.transfer;
                                ln_net_trans        := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Program is running with Non USD Currency-Values without Conversion Rate');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '------------------------------------------');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Additions:' || ln_addition);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Adjustments:' || ln_adjustment);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Retirement:' || ln_retirement);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Captalization:' || ln_capitalization);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Revaluation:' || ln_revaluation);
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Reclass:' || ln_reclass);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Transfer:' || ln_transfer);
                            END IF;

                            --End Changes by Showkath v5.0 on 07-Jul-2015
                            -- Begin Changes CCR0009036
                            /*
                                                 apps.fnd_file.put_line (
                                                    apps.fnd_file.output,
                                                       NULL
                                                    || CHR (9)
                                                    || NULL
                                                    || CHR (9)
                                                    || NULL
                                                    || CHR (9)
                                                    || NULL
                                                    || CHR (9)
                                                    || NULL                             --i.asset_category
                                                    || CHR (9)                          -- Changes CCR0009036
                                                    || NULL                             -- Changes CCR0009036
                                                    || CHR (9)
                                                    || NULL                         --i.asset_cost_account
                                                    || CHR (9)
                                                    || NULL                                --i.cost_center
                                                    || CHR (9)
                                                    || NULL                                      --i.brand
                                                    || CHR (9)
                                                    || NULL
                                                    || CHR (9)
                                                    --                  || NULL
                                                    --                  || CHR (9)
                                                    -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                                                    /*|| 'Subtotal by :'
                                                    || j.info1                                         --NULL
                                                    || CHR (9)
                                                    || j.info                                          --NULL
                                                    || CHR (9)*/
                            /*|| NULL                     --i.date_placed_in_service
                            || CHR (9)
                            || NULL                               --i.deprn_method
                            || CHR (9)
                            || NULL                                 --i.life_yr_mo
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || 'Subtotal by :'
                            || j.info1                                      --NULL
                            || CHR (9)
                            || j.info                                       --NULL
                            || CHR (9)
                            -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                            --|| to_char(j.begin_year, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)
                            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                            || TO_CHAR (j.begin_year_fun, 'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_begin_spot, 'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_addition, 'FM999G999G999G999D99') --v_addition_total--i.addition
                            || CHR (9)
                            || TO_CHAR (ln_adjustment, 'FM999G999G999G999D99') --v_adjustment_total--i.adjustment
                            || CHR (9)
                            || TO_CHAR (ln_retirement, 'FM999G999G999G999D99') --v_retirement_total--i.retirement
                            || CHR (9)
                            || TO_CHAR (ln_capitalization,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_revaluation, 'FM999G999G999G999D99') --v_revaluation_total--i.revaluation
                            || CHR (9)
                            || TO_CHAR (ln_reclass, 'FM999G999G999G999D99') --v_reclass_total--i.reclass
                            || CHR (9)
                            || TO_CHAR (ln_transfer, 'FM999G999G999G999D99') --v_transfer_total--i.transfer
                            || CHR (9)
                            --End Changes by Showkath v5.0 on 07-Jul-2015
                            --|| to_char(j.end_year, 'FM999G999G999G999D99') --Changes by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)
                            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                            || TO_CHAR (j.end_year_fun, 'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_end_spot, 'FM999G999G999G999D99')
                            || CHR (9)
                            --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --Changes by Showkath v5.0 on 15-Jul-2015
                            --|| CHR (9)
                            || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')
                            || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                      --|| to_char(j.impairment, 'FM999G999G999G999D99') --Changes by Showkath v5.0 on 15-Jul-2015
                                      --|| CHR (9)
                                      -- || to_char(j.net_book_value, 'FM999G999G999G999D99') --v_net_book_value --Changes by Showkath v5.0 on 15-Jul-2015
                            );
    */
                            v_num   := v_num + 1;

                            INSERT INTO XXDO.XXD_FA_ROLL_FWD_REP_XML_T (
                                            rownumber,
                                            book,
                                            period_from,
                                            period_to,
                                            currency,
                                            asset_category,
                                            asset_cost_account,
                                            asset_cost_comb,
                                            cost_center,
                                            brand,
                                            asset_number,
                                            description,
                                            custodian,
                                            location,
                                            date_placed_in_service,
                                            deprn_method,
                                            life_yr_mo,
                                            begin_year_fun,
                                            begin_year_spot,
                                            addition,
                                            adjustment,
                                            retirement,
                                            capitalization,
                                            revaluation,
                                            reclass,
                                            transfer,
                                            end_year_fun,
                                            end_year_spot,
                                            net_trans)
                                 VALUES (v_num, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         NULL, NULL, NULL,
                                         'Subtotal by :' || j.info1, j.info, /*                                                                        DECODE (TRIM (TO_CHAR (j.begin_year_fun, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (j.begin_year_fun,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_begin_spot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_begin_spot,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_addition, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_addition,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_adjustment, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_adjustment,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_retirement, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_retirement,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_capitalization,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_capitalization,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_revaluation, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_revaluation,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_reclass, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_reclass,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_transfer, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_transfer,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (j.end_year_fun, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (j.end_year_fun,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_end_spot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_end_spot,'999G999G999G999G999D99'))),
                                                                                                                                                    DECODE (TRIM (TO_CHAR (ln_net_trans, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_net_trans,'999G999G999G999G999D99'))) */
                                                                             j.begin_year_fun, ln_begin_spot, ln_addition, NVL (ln_adjustment, 0), ln_retirement, ln_capitalization, ln_revaluation, ln_reclass, ln_transfer, j.end_year_fun
                                         , ln_end_spot, ln_net_trans);
                        -- End Changes CCR0009036
                        END;
                    END LOOP;
                END LOOP;

                COMMIT;                            -- Added Changes CCR0009036

                FOR l IN c_total
                LOOP
                    BEGIN
                        IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                        THEN
                            ln_begin_spot   :=
                                  NVL (l.begin_year_fun_tot, 0)
                                * NVL (ln_begin_spot_rate, 1);
                            ln_end_spot   :=
                                  NVL (l.end_year_fun_tot, 0)
                                * NVL (ln_end_spot_rate, 1);
                        ELSE
                            ln_begin_spot   :=
                                  NVL (l.begin_year_fun_tot, 0)
                                * ln_begin_spot_rate;
                            ln_begin_trans   :=
                                ln_begin_spot - l.begin_year_tot;
                            ln_end_spot    :=
                                  NVL (l.end_year_fun_tot, 0)
                                * ln_end_spot_rate;
                            ln_end_trans   := ln_end_spot - l.end_year_tot;
                        --ln_net_trans := ln_end_trans - ln_begin_trans;--commented by showkath on 01-DEC-2015 to fix net fx translation
                        END IF;
                    END;


                    --END IF;

                    -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                    -- Begin changes by showkath v5.0 on 14-JUL-2015
                    --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                    IF (p_currency <> NVL (l_func_currency, 'X'))
                    THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Transactional Date exchange rate:'
                            || ln_conversion_rate);
                        ln_addition         := NULL;
                        ln_adjustment       := NULL;
                        ln_retirement       := NULL;
                        ln_capitalization   := NULL;
                        ln_revaluation      := NULL;
                        ln_reclass          := NULL;
                        ln_transfer         := NULL;
                        ln_addition         := l.addition_tot_nonf;
                        ln_adjustment       := l.adjustment_tot_nonf;
                        ln_retirement       := l.retirement_tot_nonf;
                        ln_capitalization   := l.capitalization_tot_nonf;
                        ln_revaluation      := l.revaluation_tot_nonf;
                        ln_reclass          := l.reclass_tot_nonf;
                        ln_transfer         := l.transfer_tot_nonf;
                        ln_net_trans        := NULL;
                        ln_net_trans        :=
                              NVL (ln_end_spot, 0)
                            - ( /*NVL ( (l.begin_year_tot * ln_conversion_rate), 0)*/
                               NVL (ln_begin_spot, 0) --addedby showkath on 07-DEC-2015 to fix total issue.
                                                      + NVL (ln_addition, 0) + NVL (ln_adjustment, 0) + NVL (ln_retirement, 0) + NVL (ln_capitalization, 0) + NVL (ln_revaluation, 0) + NVL (ln_reclass, 0) + NVL (ln_transfer, 0));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Program is running with USD Currency-Values with Conversion Rate');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '------------------------------------------');
                        fnd_file.put_line (fnd_file.LOG,
                                           'Additions:' || ln_addition);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adjustments:' || ln_adjustment);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Retirement:' || ln_retirement);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Captalization:' || ln_capitalization);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Revaluation:' || ln_revaluation);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Reclass:' || ln_reclass);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Transfer:' || ln_transfer);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Net FX Transaction:' || ln_net_trans);
                    ELSE
                        ln_addition         := NULL;
                        ln_adjustment       := NULL;
                        ln_retirement       := NULL;
                        ln_capitalization   := NULL;
                        ln_revaluation      := NULL;
                        ln_reclass          := NULL;
                        ln_transfer         := NULL;
                        ln_addition         := l.addition_tot;
                        ln_adjustment       := l.adjustment_tot;
                        ln_retirement       := l.retirement_tot;
                        ln_capitalization   := l.capitalization_tot;
                        ln_revaluation      := l.revaluation_tot;
                        ln_reclass          := l.reclass_tot;
                        ln_transfer         := l.transfer_tot;
                        ln_net_trans        := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Program is running with Non USD Currency-Values without Conversion Rate');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '------------------------------------------');
                        fnd_file.put_line (fnd_file.LOG,
                                           'Additions:' || ln_addition);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adjustments:' || ln_adjustment);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Retirement:' || ln_retirement);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Captalization:' || ln_capitalization);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Revaluation:' || ln_revaluation);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Reclass:' || ln_reclass);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Transfer:' || ln_transfer);
                    END IF;

                    -- Begin changes by showkath v5.0 on 14-JUL-2015
                    BEGIN
                        -- Begin Changes CCR0009036
                        /*
                                          apps.fnd_file.put_line (
                                             apps.fnd_file.output,
                                                NULL
                                             || CHR (9)
                                             || NULL
                                             || CHR (9)
                                             -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                             --Commented as amount was shifted by one cell
                                             /*|| NULL
                                             || CHR (9)*/
                        -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                        /*|| NULL
                        || CHR (9)
                        || NULL                                --i.asset_category
                        || CHR (9)
                        || NULL                            --i.asset_cost_account
                        || CHR (9)
                        || NULL                            -- Changes CCR0009036
                        || CHR (9)                         -- Changes CCR0009036
                        || NULL                                   --i.cost_center
                        || CHR (9)
                        || NULL                                         --i.brand
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                        || NULL --'TOTAL'                                            --NULL
                        || CHR (9)
                        || NULL
                        -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        || NULL                        --i.date_placed_in_service
                        || CHR (9)
                        || NULL                                  --i.deprn_method
                        || CHR (9)
                        || NULL                                    --i.life_yr_mo
                        -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                        --|| 'TOTAL : '                                 --||j.info1--NULL
                        || 'Total by '
                        || m.book_type_code
                        -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                        || CHR (9)
                        --|| to_char(l.begin_year_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 15-Jul-2015
                        --|| CHR (9)
                        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                        || TO_CHAR (l.begin_year_fun_tot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_begin_spot, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_addition, 'FM999G999G999G999D99') --v_addition_total--i.addition
                        || CHR (9)
                        || TO_CHAR (ln_adjustment, 'FM999G999G999G999D99') --v_adjustment_total--i.adjustment
                        || CHR (9)
                        || TO_CHAR (ln_retirement, 'FM999G999G999G999D99') --v_retirement_total--i.retirement
                        || CHR (9)
                        || TO_CHAR (ln_capitalization, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_revaluation, 'FM999G999G999G999D99') --v_revaluation_total--i.revaluation
                        || CHR (9)
                        || TO_CHAR (ln_reclass, 'FM999G999G999G999D99') --v_reclass_total--i.reclass
                        || CHR (9)
                        || TO_CHAR (ln_transfer, 'FM999G999G999G999D99') --v_transfer_total--i.transfer
                        || CHR (9)
                        --changes by Showkath v5.0 on 07-Jul-2015
                        --|| to_char(l.end_year_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                        --|| CHR (9)
                        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                        || TO_CHAR (l.end_year_fun_tot, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_end_spot, 'FM999G999G999G999D99')
                        || CHR (9)
                        --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                        --|| CHR (9)
                        || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')
                        || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                  --|| to_char(l.impairment_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                                  --|| CHR (9)
                                  --|| to_char(l.net_book_value_tot, 'FM999G999G999G999D99')                 --v_net_book_value
                        );*/
                        v_num   := v_num + 1;

                        INSERT INTO XXDO.XXD_FA_ROLL_FWD_REP_XML_T (
                                        rownumber,
                                        book,
                                        period_from,
                                        period_to,
                                        currency,
                                        asset_category,
                                        asset_cost_account,
                                        asset_cost_comb,
                                        cost_center,
                                        brand,
                                        asset_number,
                                        description,
                                        custodian,
                                        location,
                                        date_placed_in_service,
                                        deprn_method,
                                        life_yr_mo,
                                        begin_year_fun,
                                        begin_year_spot,
                                        addition,
                                        adjustment,
                                        retirement,
                                        capitalization,
                                        revaluation,
                                        reclass,
                                        transfer,
                                        end_year_fun,
                                        end_year_spot,
                                        net_trans)
                             VALUES (v_num, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, NULL, NULL,
                                     NULL, 'Total by ' || m.book_type_code, /*                                                                  DECODE (TRIM (TO_CHAR (l.begin_year_fun_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (l.begin_year_fun_tot,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_begin_spot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_begin_spot,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_addition, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_addition,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_adjustment, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_adjustment,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_retirement, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_retirement,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_capitalization,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_capitalization,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_revaluation, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_revaluation,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_reclass, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_reclass,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_transfer, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_transfer,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (l.end_year_fun_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (l.end_year_fun_tot,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_end_spot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_end_spot,'999G999G999G999G999D99'))),
                                                                                                                                             DECODE (TRIM (TO_CHAR (ln_net_trans, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_net_trans,'999G999G999G999G999D99'))) */
                                                                            l.begin_year_fun_tot, ln_begin_spot, ln_addition, NVL (ln_adjustment, 0), ln_retirement, ln_capitalization, ln_revaluation, ln_reclass, ln_transfer, l.end_year_fun_tot
                                     , ln_end_spot, ln_net_trans);

                        COMMIT;
                    -- End Changes CCR0009036

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Error in Calculating Final Output: '
                                || SUBSTR (SQLERRM, 1, 200));
                    END;

                    -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                    /*IF h_reporting_flag = 'P'
                    THEN
                       --ln_begin_grd_tot := NULL;
                       ln_begin_spot_grd_tot := NULL;
                       ln_begin_trans_grd_tot := NULL;
                       --ln_end_grd_tot := NULL;
                       ln_end_spot_grd_tot := NULL;
                       ln_end_trans_grd_tot := NULL;
                       ln_net_trans_grd_tot := NULL;

                    ELSE*/
                    --comented by showkath to display below values for h_reporting_flag = P 11/18/2015
                    BEGIN
                        ln_begin_spot_grd_tot   :=
                              NVL (ln_begin_spot_grd_tot, 0)
                            + NVL (ln_begin_spot, 0);
                        ln_begin_trans_grd_tot   :=
                              NVL (ln_begin_trans_grd_tot, 0)
                            + NVL (ln_begin_trans, 0);


                        ln_end_spot_grd_tot   :=
                              NVL (ln_end_spot_grd_tot, 0)
                            + NVL (ln_end_spot, 0);
                        ln_end_trans_grd_tot   :=
                              NVL (ln_end_trans_grd_tot, 0)
                            + NVL (ln_end_trans, 0);
                    --ln_net_trans_grd_tot := NVL(ln_net_trans_grd_tot,0) + NVL(ln_net_trans,0);-- commented by showkath on 01-DEC-2015 to fix net fx translation

                    END;

                    --END IF;

                    ln_begin_grd_tot   :=
                        NVL (ln_begin_grd_tot, 0) + NVL (l.begin_year_tot, 0);
                    ln_end_grd_tot   :=
                        NVL (ln_end_grd_tot, 0) + NVL (l.end_year_tot, 0);

                    ln_net_book_val_grd_tot   :=
                          NVL (ln_net_book_val_grd_tot, 0)
                        + NVL (l.net_book_value_tot, 0);
                    ln_impairment_tot   :=
                          NVL (ln_impairment_tot, 0)
                        + NVL (l.impairment_tot, 0);

                    -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                    --START Changes by Showkath v5.0 on 07-Jul-2015
                    --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                    IF (p_currency <> NVL (l_func_currency, 'X'))
                    THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                        ln_addition_grd_tot    :=
                              NVL (ln_addition_grd_tot, 0)
                            + NVL (l.addition_tot_nonf, 0);
                        ln_capitalization_grd_tot   :=
                              NVL (ln_capitalization_grd_tot, 0)
                            + NVL (l.capitalization_tot_nonf, 0);
                        ln_adjustment_grd_tot   :=
                              NVL (ln_adjustment_grd_tot, 0)
                            + NVL (l.adjustment_tot_nonf, 0);
                        ln_retirement_grd_tot   :=
                              NVL (ln_retirement_grd_tot, 0)
                            + NVL (l.retirement_tot_nonf, 0);
                        ln_revaluation_grd_tot   :=
                              NVL (ln_revaluation_grd_tot, 0)
                            + NVL (l.revaluation_tot_nonf, 0);
                        ln_reclass_grd_tot     :=
                              NVL (ln_reclass_grd_tot, 0)
                            + NVL (l.reclass_tot_nonf, 0);
                        ln_transfer_grd_tot    :=
                              NVL (ln_transfer_grd_tot, 0)
                            + NVL (l.transfer_tot_nonf, 0);

                        ln_net_trans_grd_tot   := NULL;
                        ln_net_trans_grd_tot   :=
                              NVL (ln_end_spot_grd_tot, 0)
                            - ( /*NVL (
                                   (ln_begin_grd_tot * NVL (ln_conversion_rate, 1)),
                                   0)*/
                               NVL (ln_begin_spot_grd_tot, 0) -- added by showkath to fix total issue
                                                              + NVL (ln_addition_grd_tot, 0) + NVL (ln_adjustment_grd_tot, 0) + NVL (ln_retirement_grd_tot, 0) + NVL (ln_capitalization_grd_tot, 0) + NVL (ln_revaluation_grd_tot, 0) + NVL (ln_reclass_grd_tot, 0) + NVL (ln_transfer_grd_tot, 0));
                    ELSE
                        ln_addition_grd_tot   :=
                              NVL (ln_addition_grd_tot, 0)
                            + NVL (l.addition_tot, 0);
                        ln_capitalization_grd_tot   :=
                              NVL (ln_capitalization_grd_tot, 0)
                            + NVL (l.capitalization_tot, 0);
                        ln_adjustment_grd_tot   :=
                              NVL (ln_adjustment_grd_tot, 0)
                            + NVL (l.adjustment_tot, 0);
                        ln_retirement_grd_tot   :=
                              NVL (ln_retirement_grd_tot, 0)
                            + NVL (l.retirement_tot, 0);
                        ln_revaluation_grd_tot   :=
                              NVL (ln_revaluation_grd_tot, 0)
                            + NVL (l.revaluation_tot, 0);
                        ln_reclass_grd_tot   :=
                              NVL (ln_reclass_grd_tot, 0)
                            + NVL (l.reclass_tot, 0);
                        ln_transfer_grd_tot   :=
                              NVL (ln_transfer_grd_tot, 0)
                            + NVL (l.transfer_tot, 0);
                        ln_net_trans   := NULL;
                    END IF;
                --End Changes by Showkath v5.0 on 07-Jul-2015
                END LOOP;
            -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
            ELSE
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       'Period not Open for Book: '
                    || m.book_type_code
                    || ' for Period: '
                    || p_from_period
                    || ' '
                    || p_to_period);
            END IF;                                                -- If ended
        END LOOP;

        BEGIN
            -- Begin Changes CCR0009036
            /*
                     apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           NULL
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                        --Commented as amount was shifted by one cell
                        /*|| NULL
                        || CHR (9)*/
            -- End changes by BT Technology Team v4.1 on 24-Dec-2014
            /*|| NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL                            -- Changes CCR0009036
            || CHR (9)                         -- Changes CCR0009036
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL                               --'TOTAL Fixed Asset' --v4.1
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || 'TOTAL Fixed Asset'                                 --NULL v4.1
            || CHR (9)
            --|| to_char(ln_begin_grd_tot, 'FM999G999G999G999D99') -- Changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || NULL
            || CHR (9)
            || TO_CHAR (ln_begin_spot_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            --|| to_char(ln_begin_trans_grd_tot, 'FM999G999G999G999D99') -- Changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || TO_CHAR (ln_addition_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_adjustment_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_retirement_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_capitalization_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_revaluation_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_reclass_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_transfer_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            --|| to_char(ln_end_grd_tot, 'FM999G999G999G999D99') -- Changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || NULL
            || CHR (9)
            || TO_CHAR (ln_end_spot_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            --|| to_char(ln_end_trans_grd_tot, 'FM999G999G999G999D99') -- Changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || TO_CHAR (ln_net_trans_grd_tot, 'FM999G999G999G999D99')
            || CHR (9) --|| to_char(ln_impairment_tot, 'FM999G999G999G999D99') -- Changes by Showkath v5.0 on 07-Jul-2015
                      --|| CHR (9)
                      --|| to_char(ln_net_book_val_grd_tot, 'FM999G999G999G999D99')
            );
*/
            v_num                       := v_num + 1;

            INSERT INTO XXDO.XXD_FA_ROLL_FWD_REP_XML_T (
                            rownumber,
                            book,
                            period_from,
                            period_to,
                            currency,
                            asset_category,
                            asset_cost_account,
                            asset_cost_comb,
                            cost_center,
                            brand,
                            asset_number,
                            description,
                            custodian,
                            location,
                            date_placed_in_service,
                            deprn_method,
                            life_yr_mo,
                            begin_year_fun,
                            begin_year_spot,
                            addition,
                            adjustment,
                            retirement,
                            capitalization,
                            revaluation,
                            reclass,
                            transfer,
                            end_year_fun,
                            end_year_spot,
                            net_trans)
                 VALUES (v_num, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, 'TOTAL Fixed Asset', NULL,
                         /*                                                         DECODE (TRIM (TO_CHAR (ln_begin_spot_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_begin_spot_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_addition_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_addition_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_adjustment_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_adjustment_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_retirement_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_retirement_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_capitalization_grd_tot,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_capitalization_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_revaluation_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_revaluation_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_reclass_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_reclass_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_transfer_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_transfer_grd_tot,'999G999G999G999G999D99'))),
                                                                                 NULL,
                                                                                 DECODE (TRIM (TO_CHAR (ln_end_spot_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_end_spot_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_net_trans_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_net_trans_grd_tot,'999G999G999G999G999D99'))) */
                         ln_begin_spot_grd_tot, ln_addition_grd_tot, ln_adjustment_grd_tot, ln_retirement_grd_tot, ln_capitalization_grd_tot, ln_revaluation_grd_tot, ln_reclass_grd_tot, ln_transfer_grd_tot, NULL
                         , ln_end_spot_grd_tot, ln_net_trans_grd_tot);

            COMMIT;

            -- End Changes CCR0009036

            --START ::Commented the CIP part as part of INC0320339  on 02 -NOV-2016
            /*get_project_cip_prc (
               p_called_from           => 'DETAIL',
               p_book                  => p_book,
               p_currency              => p_currency,
               p_from_period           => p_from_period,
               p_to_period             => p_to_period,
               p_begin_spot_rate       => ln_begin_spot_rate,
               p_end_spot_rate         => ln_end_spot_rate,
               p_begin_bal_tot         => ln_begin_cip_tot,
               p_begin_spot_tot        => ln_begin_spot_cip_tot,
               p_begin_trans_tot       => ln_begin_trans_cip_tot,
               p_additions_tot         => ln_addition_cip_tot,
               p_capitalizations_tot   => ln_capitalization_cip_tot,
               p_end_bal_tot           => ln_end_cip_tot,
               p_end_spot_tot          => ln_end_spot_cip_tot,
               p_end_trans_tot         => ln_end_trans_cip_tot,
               p_net_trans_tot         => ln_net_trans_cip_tot);*/
            --END ::Commented the CIP part as part of INC0320339  on 02 -Nov-2016

            BEGIN
                ln_begin_spot_grd_tot   :=
                    NVL (ln_begin_spot_grd_tot, 0) + ln_begin_spot_cip_tot;
                ln_begin_trans_grd_tot   :=
                    NVL (ln_begin_trans_grd_tot, 0) + ln_begin_trans_cip_tot;


                ln_end_spot_grd_tot   :=
                    NVL (ln_end_spot_grd_tot, 0) + ln_end_spot_cip_tot;
                ln_end_trans_grd_tot   :=
                    NVL (ln_end_trans_grd_tot, 0) + ln_end_trans_cip_tot;

                IF    (p_currency <> NVL (l_func_currency, 'X'))
                   OR (p_book IS NULL)
                THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                    ln_net_trans_grd_tot   :=
                        NVL (ln_net_trans_grd_tot, 0) + ln_net_trans_cip_tot; -- commented by showkath on 01_DEC-2015 to fix net fx traslation issue
                END IF;
            END;

            --END IF;

            ln_end_grd_tot              := ln_end_grd_tot + ln_end_cip_tot;
            ln_begin_grd_tot            := ln_begin_grd_tot + ln_begin_cip_tot;
            ln_addition_grd_tot         :=
                ln_addition_grd_tot + ln_addition_cip_tot;
            ln_capitalization_grd_tot   :=
                ln_capitalization_grd_tot + ln_capitalization_cip_tot;
            ln_net_book_val_grd_tot     := ln_net_book_val_grd_tot;

            -- Begin Changes CCR0009036
            /*         apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           NULL
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                        --Commented as amount was shifted by one cell
                        /*|| NULL
                        || CHR (9)*/
            -- End changes by BT Technology Team v4.1 on 24-Dec-2014
            /*|| NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL                            -- Changes CCR0009036
            || CHR (9)                         -- Changes CCR0009036
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL                                      --'GRAND TOTAL ' v4.1
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || NULL
            || CHR (9)
            || 'GRAND TOTAL '                                      --NULL v4.1
            || CHR (9)
            --|| to_char(ln_begin_grd_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 15-Jul-2015
            --|| CHR (9)
            || NULL
            || CHR (9)
            || TO_CHAR (ln_begin_spot_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            --|| to_char(ln_begin_trans_grd_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || TO_CHAR (ln_addition_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_adjustment_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_retirement_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_capitalization_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_revaluation_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_reclass_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            || TO_CHAR (ln_transfer_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            --|| to_char(ln_end_grd_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || NULL
            || CHR (9)
            || TO_CHAR (ln_end_spot_grd_tot, 'FM999G999G999G999D99')
            || CHR (9)
            --|| to_char(ln_end_trans_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
            --|| CHR (9)
            || TO_CHAR (ln_net_trans_grd_tot, 'FM999G999G999G999D99')
            || CHR (9) --|| to_char(ln_impairment_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                      --|| CHR (9)
                      --|| to_char(ln_net_book_val_grd_tot, 'FM999G999G999G999D99')
            );*/

            v_num                       := v_num + 1;

            INSERT INTO XXDO.XXD_FA_ROLL_FWD_REP_XML_T (
                            rownumber,
                            book,
                            period_from,
                            period_to,
                            currency,
                            asset_category,
                            asset_cost_account,
                            asset_cost_comb,
                            cost_center,
                            brand,
                            asset_number,
                            description,
                            custodian,
                            location,
                            date_placed_in_service,
                            deprn_method,
                            life_yr_mo,
                            begin_year_fun,
                            begin_year_spot,
                            addition,
                            adjustment,
                            retirement,
                            capitalization,
                            revaluation,
                            reclass,
                            transfer,
                            end_year_fun,
                            end_year_spot,
                            net_trans)
                 VALUES (v_num, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, NULL, NULL,
                         NULL, 'GRAND TOTAL ', NULL,
                         /*                                                         DECODE (TRIM (TO_CHAR (ln_begin_spot_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_begin_spot_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_addition_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_addition_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_adjustment_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_adjustment_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_retirement_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_retirement_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_capitalization_grd_tot,'999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_capitalization_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_revaluation_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_revaluation_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_reclass_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_reclass_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_transfer_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_transfer_grd_tot,'999G999G999G999G999D99'))),
                                                                                 NULL,
                                                                                 DECODE (TRIM (TO_CHAR (ln_end_spot_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_end_spot_grd_tot,'999G999G999G999G999D99'))),
                                                                                 DECODE (TRIM (TO_CHAR (ln_net_trans_grd_tot, '999G999G999G999G999D99')),'.00','0',TRIM (TO_CHAR (ln_net_trans_grd_tot,'999G999G999G999G999D99'))) */
                         ln_begin_spot_grd_tot, ln_addition_grd_tot, ln_adjustment_grd_tot, ln_retirement_grd_tot, ln_capitalization_grd_tot, ln_revaluation_grd_tot, ln_reclass_grd_tot, ln_transfer_grd_tot, NULL
                         , ln_end_spot_grd_tot, ln_net_trans_grd_tot);

            COMMIT;
        -- End Changes CCR0009036
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error in Calculating Final Output : '
                    || SUBSTR (SQLERRM, 1, 200));
        END;

        -- End changes by BT Technology Team v4.1 on 26-Dec-2014

        -- Begin Changes CCR0009036

        BEGIN
            BEGIN
                SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                  INTO v_report_date
                  FROM sys.DUAL;
            END;

            apps.fnd_file.put_line (
                fnd_file.output,
                '<?xml version="1.0" encoding="US-ASCII"?>');
            apps.fnd_file.put_line (apps.fnd_file.output, '<MAIN>');
            apps.fnd_file.put_line (apps.fnd_file.output, '<PARAMGRP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<DC>'
                || DBMS_XMLGEN.CONVERT ('DECKERS CORPORATION')
                || '</DC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<RN>'
                || DBMS_XMLGEN.CONVERT (
                       'Report Name :Deckers FA Roll Forward Detail Cost Report')
                || '</RN>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<RD>'
                || DBMS_XMLGEN.CONVERT ('Report Date - :' || v_report_date)
                || '</RD>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<SP>'
                || DBMS_XMLGEN.CONVERT (
                       'Starting Period is :' || p_from_period)
                || '</SP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<EP>'
                || DBMS_XMLGEN.CONVERT ('Ending Period is :' || p_to_period)
                || '</EP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<SUBB>'
                || DBMS_XMLGEN.CONVERT ('Subtotal By :' || p_subtotal)
                || '</SUBB>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<SUBV>'
                || DBMS_XMLGEN.CONVERT (
                       'Subtotal By Value :' || p_subtotal_value)
                || '</SUBV>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<PT>'
                || DBMS_XMLGEN.CONVERT ('Project Type :' || p_project_type)
                || '</PT>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<FAS>'
                || DBMS_XMLGEN.CONVERT ('Fixed Asset Section')
                || '</FAS>');
            apps.fnd_file.put_line (apps.fnd_file.output, '</PARAMGRP>');
            apps.fnd_file.put_line (apps.fnd_file.output, '<HDRGRP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<Book>' || DBMS_XMLGEN.CONVERT ('Book') || '</Book>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<HSP>'
                || DBMS_XMLGEN.CONVERT ('Starting Period')
                || '</HSP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<HEP>' || DBMS_XMLGEN.CONVERT ('Ending Period') || '</HEP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<CURR>' || DBMS_XMLGEN.CONVERT ('Currency') || '</CURR>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<AC>' || DBMS_XMLGEN.CONVERT ('Asset Category') || '</AC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<ACA>'
                || DBMS_XMLGEN.CONVERT ('Asset Cost Account')
                || '</ACA>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<ACC>'
                || DBMS_XMLGEN.CONVERT ('Asset Code Combination')
                || '</ACC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<DCC>'
                || DBMS_XMLGEN.CONVERT ('Depreciation Cost Center')
                || '</DCC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<AB>' || DBMS_XMLGEN.CONVERT ('Asset Brand') || '</AB>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<AN>' || DBMS_XMLGEN.CONVERT ('Asset Number') || '</AN>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<AD>'
                || DBMS_XMLGEN.CONVERT ('Asset Description')
                || '</AD>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<ACU>'
                || DBMS_XMLGEN.CONVERT ('Asset Custodian')
                || '</ACU>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<LOC>' || DBMS_XMLGEN.CONVERT ('Location') || '</LOC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<DPIS>'
                || DBMS_XMLGEN.CONVERT ('Date Placed In Service')
                || '</DPIS>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<DM>'
                || DBMS_XMLGEN.CONVERT ('Depreciation Method')
                || '</DM>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<LIFE>' || DBMS_XMLGEN.CONVERT ('Life Yr.Mo') || '</LIFE>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<BBFC>'
                || DBMS_XMLGEN.CONVERT (
                       'Begin Balance in <Functional Currency>')
                || '</BBFC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<BBSR>'
                || DBMS_XMLGEN.CONVERT (
                       'Begin Balance <' || p_currency || '> at Spot Rate')
                || '</BBSR>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<ADD>' || DBMS_XMLGEN.CONVERT ('Additions') || '</ADD>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<ADJ>' || DBMS_XMLGEN.CONVERT ('Adjustments') || '</ADJ>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<RET>' || DBMS_XMLGEN.CONVERT ('Retirements') || '</RET>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<CAP>' || DBMS_XMLGEN.CONVERT ('Capitalization') || '</CAP>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<REV>' || DBMS_XMLGEN.CONVERT ('Revaluation') || '</REV>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<REC>' || DBMS_XMLGEN.CONVERT ('Reclasses') || '</REC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                '<TRAN>' || DBMS_XMLGEN.CONVERT ('Transfers') || '</TRAN>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<EBFC>'
                || DBMS_XMLGEN.CONVERT (
                       'End Balance in <Functional Currency>')
                || '</EBFC>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<EBSR>'
                || DBMS_XMLGEN.CONVERT (
                       'End Balance <' || p_currency || '> at Spot Rate')
                || '</EBSR>');
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   '<NFT>'
                || DBMS_XMLGEN.CONVERT ('Net FX Translation')
                || '</NFT>');
            apps.fnd_file.put_line (apps.fnd_file.output, '</HDRGRP>');
            apps.fnd_file.put_line (apps.fnd_file.output, '<OUTPUT>');

            OPEN data_cur;

            LOOP
                FETCH data_cur INTO output_row;

                EXIT WHEN data_cur%NOTFOUND;

                fnd_file.put_line (fnd_file.output, '<ROW>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<RN>'
                    || DBMS_XMLGEN.CONVERT (output_row.rownumber)
                    || '</RN>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<BK>'
                    || DBMS_XMLGEN.CONVERT (output_row.book)
                    || '</BK>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<PERIOD_FROM>'
                    || DBMS_XMLGEN.CONVERT (output_row.period_from)
                    || '</PERIOD_FROM>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<PERIOD_TO>'
                    || DBMS_XMLGEN.CONVERT (output_row.period_to)
                    || '</PERIOD_TO>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<CURRENCY>'
                    || DBMS_XMLGEN.CONVERT (output_row.currency)
                    || '</CURRENCY>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<ASSET_CATEGORY>'
                    || DBMS_XMLGEN.CONVERT (output_row.asset_category)
                    || '</ASSET_CATEGORY>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<ASSET_COST_ACCOUNT>'
                    || DBMS_XMLGEN.CONVERT (output_row.asset_cost_account)
                    || '</ASSET_COST_ACCOUNT>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<ASSET_COST_COMB>'
                    || DBMS_XMLGEN.CONVERT (output_row.asset_cost_comb)
                    || '</ASSET_COST_COMB>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<COST_CENTER>'
                    || DBMS_XMLGEN.CONVERT (output_row.cost_center)
                    || '</COST_CENTER>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<BRAND>'
                    || DBMS_XMLGEN.CONVERT (output_row.brand)
                    || '</BRAND>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<ASSET_NUMBER>'
                    || DBMS_XMLGEN.CONVERT (output_row.asset_number)
                    || '</ASSET_NUMBER>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<DESCRIPTION>'
                    || DBMS_XMLGEN.CONVERT (output_row.description)
                    || '</DESCRIPTION>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<CUSTODIAN>'
                    || DBMS_XMLGEN.CONVERT (output_row.custodian)
                    || '</CUSTODIAN>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<LOCATION>'
                    || DBMS_XMLGEN.CONVERT (output_row.location)
                    || '</LOCATION>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<DATE_PLACED_IN_SERVICE>'
                    || DBMS_XMLGEN.CONVERT (
                           output_row.date_placed_in_service)
                    || '</DATE_PLACED_IN_SERVICE>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<DEPRN_METHOD>'
                    || DBMS_XMLGEN.CONVERT (output_row.deprn_method)
                    || '</DEPRN_METHOD>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<LIFE_YR_MO>'
                    || DBMS_XMLGEN.CONVERT (output_row.life_yr_mo)
                    || '</LIFE_YR_MO>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<BEGIN_YEAR_FUN>'
                    || DBMS_XMLGEN.CONVERT (output_row.begin_year_fun)
                    || '</BEGIN_YEAR_FUN>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<BEGIN_YEAR_SPOT>'
                    || DBMS_XMLGEN.CONVERT (output_row.begin_year_spot)
                    || '</BEGIN_YEAR_SPOT>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<ADDITION>'
                    || DBMS_XMLGEN.CONVERT (output_row.addition)
                    || '</ADDITION>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<ADJUSTMENT>'
                    || DBMS_XMLGEN.CONVERT (output_row.adjustment)
                    || '</ADJUSTMENT>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<RETIREMENT>'
                    || DBMS_XMLGEN.CONVERT (output_row.retirement)
                    || '</RETIREMENT>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<CAPITALIZATION>'
                    || DBMS_XMLGEN.CONVERT (output_row.capitalization)
                    || '</CAPITALIZATION>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<REVALUATION>'
                    || DBMS_XMLGEN.CONVERT (output_row.revaluation)
                    || '</REVALUATION>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<RECLASS>'
                    || DBMS_XMLGEN.CONVERT (output_row.reclass)
                    || '</RECLASS>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<TRANSFER>'
                    || DBMS_XMLGEN.CONVERT (output_row.transfer)
                    || '</TRANSFER>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<END_YEAR_FUN>'
                    || DBMS_XMLGEN.CONVERT (output_row.end_year_fun)
                    || '</END_YEAR_FUN>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<END_YEAR_SPOT>'
                    || DBMS_XMLGEN.CONVERT (output_row.end_year_spot)
                    || '</END_YEAR_SPOT>');
                fnd_file.put_line (
                    fnd_file.output,
                       '<NET_TRANS>'
                    || DBMS_XMLGEN.CONVERT (output_row.net_trans)
                    || '</NET_TRANS>');
                fnd_file.put_line (fnd_file.output, '</ROW>');
            END LOOP;

            CLOSE data_cur;

            fnd_file.put_line (fnd_file.output, '</OUTPUT>');
            fnd_file.put_line (fnd_file.output, '</MAIN>');

            EXECUTE IMMEDIATE 'truncate table XXDO.XXD_FA_ROLL_FWD_REP_XML_T';
        END;
    -- End Changes CCR0009036

    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
    END main_detail;

    PROCEDURE xxd_fa_rsvldg_proc_sum (book IN VARCHAR2, period IN VARCHAR2)
    IS
        operation           VARCHAR2 (200);
        dist_book           VARCHAR2 (15);
        ucd                 DATE;
        upc                 NUMBER;
        tod                 DATE;
        tpc                 NUMBER;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        EXECUTE IMMEDIATE 'truncate table XXDO.XXD_FA_ROLL_RSV_LEDGER_SUM_T';

        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;

            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        operation   := 'Selecting Book and Period information';

        IF (h_reporting_flag = 'R')
        THEN
              SELECT bc.distribution_source_book dbk, NVL (dp.period_close_date, SYSDATE) ucd, dp.period_counter upc,
                     MIN (dp_fy.period_open_date) tod, MIN (dp_fy.period_counter) tpc
                INTO dist_book, ucd, upc, tod,
                              tpc
                FROM fa_deprn_periods_mrc_v dp, fa_deprn_periods_mrc_v dp_fy, fa_book_controls_mrc_v bc
               WHERE     dp.book_type_code = book
                     AND dp.period_name = period
                     AND dp_fy.book_type_code = book
                     AND dp_fy.fiscal_year = dp.fiscal_year
                     AND bc.book_type_code = book
            GROUP BY bc.distribution_source_book, dp.period_close_date, dp.period_counter;
        ELSE
              SELECT bc.distribution_source_book dbk, NVL (dp.period_close_date, SYSDATE) ucd, dp.period_counter upc,
                     MIN (dp_fy.period_open_date) tod, MIN (dp_fy.period_counter) tpc
                INTO dist_book, ucd, upc, tod,
                              tpc
                FROM fa_deprn_periods dp, fa_deprn_periods dp_fy, fa_book_controls bc
               WHERE     dp.book_type_code = book
                     AND dp.period_name = period
                     AND dp_fy.book_type_code = book
                     AND dp_fy.fiscal_year = dp.fiscal_year
                     AND bc.book_type_code = book
            GROUP BY bc.distribution_source_book, dp.period_close_date, dp.period_counter;
        END IF;

        operation   := 'Inserting into XXDO.XXD_FA_ROLL_RSV_LEDGER_SUM_T';

        -- run only if CRL not installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective,
                                reserve_acct)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd_bonus.cost cost,
                           DECODE (dd_bonus.period_counter, upc, dd_bonus.deprn_amount - dd_bonus.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd_bonus.period_counter), 1, 0, dd_bonus.ytd_deprn - dd_bonus.bonus_ytd_deprn) ytd_deprn, dd_bonus.deprn_reserve - dd_bonus.bonus_deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd_bonus.period_counter,
                           NVL (th.date_effective, ucd), ''
                      FROM fa_deprn_detail_mrc_v dd_bonus, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books_mrc_v books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CIP', 'CAPITALIZED')
                           AND dd_bonus.book_type_code = book
                           AND dd_bonus.distribution_id = dh.distribution_id
                           AND dd_bonus.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                    UNION ALL
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.bonus_deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, 0 cost,
                           DECODE (dd.period_counter, upc, dd.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.bonus_ytd_deprn) ytd_deprn, dd.bonus_deprn_reserve deprn_reserve,
                           0 percent, 'B' t_type, dd.period_counter,
                           NVL (th.date_effective, ucd), cb.bonus_deprn_expense_acct
                      FROM fa_deprn_detail_mrc_v dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books_mrc_v books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CIP', 'CAPITALIZED')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND books.bonus_rule IS NOT NULL
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective,
                                reserve_acct)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd_bonus.cost cost,
                           DECODE (dd_bonus.period_counter, upc, dd_bonus.deprn_amount - dd_bonus.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd_bonus.period_counter), 1, 0, dd_bonus.ytd_deprn - dd_bonus.bonus_ytd_deprn) ytd_deprn, dd_bonus.deprn_reserve - dd_bonus.bonus_deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd_bonus.period_counter,
                           NVL (th.date_effective, ucd), ''
                      FROM fa_deprn_detail dd_bonus, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                           AND dd_bonus.book_type_code = book
                           AND dd_bonus.distribution_id = dh.distribution_id
                           AND dd_bonus.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                    UNION ALL
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.bonus_deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, 0 cost,
                           DECODE (dd.period_counter, upc, dd.bonus_deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.bonus_ytd_deprn) ytd_deprn, dd.bonus_deprn_reserve deprn_reserve,
                           0 percent, 'B' t_type, dd.period_counter,
                           NVL (th.date_effective, ucd), cb.bonus_deprn_expense_acct
                      FROM fa_deprn_detail dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE     cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CIP', 'CAPITALIZED') --,'CIP')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND books.bonus_rule IS NOT NULL
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod;
            END IF;
        -- run only if CRL installed
        ELSIF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            -- Insert Non-Group Details
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd.cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd.period_counter,
                           NVL (th.date_effective, ucd)
                      FROM fa_deprn_detail_mrc_v dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books_mrc_v books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE             -- start cua - exclude the group Assets
                               books.group_asset_id IS NULL
                           AND                                      -- end cua
                               cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CAPITALIZED', 'CIP') --('CAPITALIZED') --,'CIP')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                           AND         -- start cua - exclude the group Assets
                               books.group_asset_id IS NULL;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective)
                    SELECT dh.asset_id asset_id, dh.code_combination_id dh_ccid, cb.deprn_reserve_acct rsv_account,
                           books.date_placed_in_service start_date, books.deprn_method_code method, books.life_in_months life,
                           books.adjusted_rate rate, books.production_capacity capacity, dd.cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           DECODE (th.transaction_type_code, NULL, dh.units_assigned / ah.units * 100) percent, DECODE (th.transaction_type_code,  NULL, DECODE (th_rt.transaction_type_code, 'FULL RETIREMENT', 'F', DECODE (books.depreciate_flag, 'NO', 'N')),  'TRANSFER', 'T',  'TRANSFER OUT', 'P',  'RECLASS', 'R') t_type, dd.period_counter,
                           NVL (th.date_effective, ucd)
                      FROM fa_deprn_detail dd, fa_asset_history ah, fa_transaction_headers th,
                           fa_transaction_headers th_rt, fa_books books, fa_distribution_history dh,
                           fa_category_books cb
                     WHERE             -- start cua - exclude the group Assets
                               books.group_asset_id IS NULL
                           AND cb.book_type_code = book
                           AND cb.category_id = ah.category_id
                           AND ah.asset_id = dh.asset_id
                           AND ah.date_effective <
                               NVL (th.date_effective, ucd)
                           AND NVL (ah.date_ineffective, SYSDATE) >=
                               NVL (th.date_effective, ucd)
                           AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                           AND dd.book_type_code = book
                           AND dd.distribution_id = dh.distribution_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id = dh.asset_id
                                       AND dd_sub.distribution_id =
                                           dh.distribution_id
                                       AND dd_sub.period_counter <= upc)
                           AND th_rt.book_type_code = book
                           AND th_rt.transaction_header_id =
                               books.transaction_header_id_in
                           AND books.book_type_code = book
                           AND books.asset_id = dh.asset_id
                           AND NVL (books.period_counter_fully_retired, upc) >=
                               tpc
                           AND books.date_effective <=
                               NVL (th.date_effective, ucd)
                           AND NVL (books.date_ineffective, SYSDATE + 1) >
                               NVL (th.date_effective, ucd)
                           AND th.book_type_code(+) = dist_book
                           AND th.transaction_header_id(+) =
                               dh.transaction_header_id_out
                           AND th.date_effective(+) BETWEEN tod AND ucd
                           AND dh.book_type_code = dist_book
                           AND dh.date_effective <= ucd
                           AND NVL (dh.date_ineffective, SYSDATE) > tod
                           AND books.group_asset_id IS NULL;
            -- start cua - exclude the group Assets
            END IF;

            -- end cua

            -- Insert the Group Depreciation Details
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid ch_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, gar.deprn_method_code method, gar.life_in_months life,
                           gar.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary_mrc_v dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_deprn_periods_mrc_v dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gad.super_group_id IS NULL
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           -- mwoodwar
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;      -- mwoodwar
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid ch_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, gar.deprn_method_code method, gar.life_in_months life,
                           gar.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_deprn_periods dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gad.super_group_id IS NULL
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           -- mwoodwar
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;      -- mwoodwar
            END IF;

            -- Insert the SuperGroup Depreciation Details
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid dh_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, sgr.deprn_method_code method, gar.life_in_months life,
                           sgr.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary_mrc_v dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_super_group_rules sgr, fa_deprn_periods_mrc_v dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.super_group_id = sgr.super_group_id
                           AND gad.book_type_code = sgr.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail_mrc_v dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date
                           AND sgr.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (sgr.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_rsv_ledger_sum_t (
                                asset_id,
                                dh_ccid,
                                deprn_reserve_acct,
                                date_placed_in_service,
                                method_code,
                                life,
                                rate,
                                capacity,
                                cost,
                                deprn_amount,
                                ytd_deprn,
                                deprn_reserve,
                                percent,
                                transaction_type,
                                period_counter,
                                date_effective)
                    SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid dh_ccid, gad.deprn_reserve_acct_ccid rsv_account,
                           gar.deprn_start_date start_date, sgr.deprn_method_code method, gar.life_in_months life,
                           sgr.adjusted_rate rate, gar.production_capacity capacity, dd.adjusted_cost cost,
                           DECODE (dd.period_counter, upc, dd.deprn_amount, 0) deprn_amount, DECODE (SIGN (tpc - dd.period_counter), 1, 0, dd.ytd_deprn) ytd_deprn, dd.deprn_reserve deprn_reserve,
                           100 percent, 'G' t_type, dd.period_counter,
                           ucd
                      FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                           fa_super_group_rules sgr, fa_deprn_periods dp
                     WHERE     dd.book_type_code = book
                           AND dd.asset_id = gar.group_asset_id
                           AND gar.book_type_code = dd.book_type_code
                           AND gad.super_group_id = sgr.super_group_id
                           AND gad.book_type_code = sgr.book_type_code
                           AND gad.book_type_code = gar.book_type_code
                           AND gad.group_asset_id = gar.group_asset_id
                           AND dd.period_counter =
                               (SELECT MAX (dd_sub.period_counter)
                                  FROM fa_deprn_detail dd_sub
                                 WHERE     dd_sub.book_type_code = book
                                       AND dd_sub.asset_id =
                                           gar.group_asset_id
                                       AND dd_sub.period_counter <= upc)
                           AND dd.period_counter = dp.period_counter
                           AND dd.book_type_code = dp.book_type_code
                           AND gar.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (gar.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date
                           AND sgr.date_effective <=
                               dp.calendar_period_close_date
                           AND NVL (sgr.date_ineffective,
                                    (dp.calendar_period_close_date + 1)) >
                               dp.calendar_period_close_date;
            END IF;
        END IF;                                             --end of CRL check

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                fnd_file.LOG,
                'Exception Occured1 :' || SUBSTR (SQLERRM, 1, 200));
    END xxd_fa_rsvldg_proc_sum;

    PROCEDURE get_balance_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                               , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2)
    IS
        p_date              DATE := period_date;
        a_date              DATE := additions_date;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        -- Fix for Bug #1892406. Run only if CRL not installed.
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf,                            --
                                    report_type)
                        SELECT /*+ ORDERED */
                               dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve) * conversion_rate, --end  changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                                                                                                                                                                 report_type
                          FROM fa_deprn_detail dd, fa_distribution_history dh, fa_asset_history ah,
                               fa_category_books cb, fa_books bk, fa_deprn_periods fdp, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               gl_daily_rates gdr --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               AND fdp.book_type_code = book
                               AND fdp.period_counter = dd.period_counter
                               -- AND gdr.conversion_date =
                               --fdp.calendar_period_open_date
                               AND gdr.conversion_date =
                                   DECODE (
                                       begin_or_end,
                                       'BEGIN', fdp.calendar_period_open_date,
                                       fdp.calendar_period_close_date)
                               AND gdr.conversion_type = 'Spot'  --'Corporate'
                               AND gdr.from_currency = g_from_currency
                               AND gdr.to_currency = g_to_currency
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                        SELECT /*+ ORDERED */
                               dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               report_type
                          FROM fa_deprn_detail dd, fa_distribution_history dh, fa_asset_history ah,
                               fa_category_books cb, fa_books bk
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                END IF;
            END;
        --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
        -- END IF;
        --END IF;
        -- Run only if CRL installed.
        ELSIF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            --commented changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
            --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                    report_type)
                        SELECT dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               --
                               DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve) * conversion_rate, --
                                                                                                                                                                                 report_type
                          FROM fa_distribution_history dh, fa_deprn_detail dd, fa_asset_history ah,
                               fa_category_books cb, fa_books bk, fa_deprn_periods fdp, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               gl_daily_rates gdr --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               AND fdp.book_type_code = book
                               AND fdp.period_counter = DD.period_counter
                               AND gdr.conversion_date =
                                   fdp.calendar_period_open_date
                               AND gdr.conversion_type = 'Spot'  --'Corporate'
                               AND gdr.from_currency = g_from_currency
                               AND gdr.to_currency = g_to_currency
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND -- (CIP Assets dont appear in CIP Detail Report)
                                   DECODE (
                                       report_type,
                                       'CIP COST', dd.deprn_source_code,
                                       DECODE (begin_or_end,
                                               'BEGIN', dd.deprn_source_code,
                                               'D')) =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL
                               -- start of CUA - This is to exclude the Group Asset Members
                               AND bk.group_asset_id IS NULL;
                --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                        SELECT dh.asset_id, dh.code_combination_id, NULL,
                               DECODE (report_type,  'COST', cb.asset_cost_acct,  'CIP COST', cb.cip_cost_acct,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', dd.cost,  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               report_type
                          FROM fa_distribution_history dh, fa_deprn_detail dd, fa_asset_history ah,
                               fa_category_books cb, fa_books bk
                         WHERE     dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND -- (CIP Assets dont appear in CIP Detail Report)
                                   DECODE (
                                       report_type,
                                       'CIP COST', dd.deprn_source_code,
                                       DECODE (begin_or_end,
                                               'BEGIN', dd.deprn_source_code,
                                               'D')) =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND dh.distribution_id =
                                               dd.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = dd.book_type_code
                               AND bk.book_type_code = cb.book_type_code
                               AND bk.asset_id = dd.asset_id
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN bk.date_effective
                                                       AND NVL (
                                                               bk.date_ineffective,
                                                               SYSDATE)
                               AND NVL (bk.period_counter_fully_retired,
                                        period_pc + 1) >
                                   earliest_pc
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL
                               -- start of CUA - This is to exclude the Group Asset Members
                               AND bk.group_asset_id IS NULL;
                END IF;
            END;
        --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
        -- END IF;
        -- end of cua
        END IF;
    END get_balance_sum;

    PROCEDURE get_balance_group_begin_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                           , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2)
    IS
        p_date              DATE := period_date;
        a_date              DATE := additions_date;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            -- -- commented to display all columns for any reporting_flag by showkath 12/06/2015
            --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    report_type)
                        SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                               NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               ----changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                               DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve) * conversion_rate, --    --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                                                                                                                                                                                    report_type
                          FROM fa_books bk, fa_category_books cb, fa_asset_history ah,
                               fa_deprn_detail dd, fa_distribution_history dh, fa_group_asset_default gad,
                               fa_deprn_periods fdp, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                     gl_daily_rates gdr --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                         WHERE     gad.book_type_code = bk.book_type_code
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                               AND fdp.book_type_code = bk.book_type_code
                               AND fdp.period_counter = DD.period_counter
                               AND gdr.conversion_date =
                                   fdp.calendar_period_open_date
                               AND gdr.conversion_type = 'Spot'  --'Corporate'
                               AND gdr.from_currency = g_from_currency
                               AND gdr.to_currency = g_to_currency
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                               AND gad.group_asset_id = bk.group_asset_id
                               AND bk.group_asset_id IS NOT NULL
                               AND dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = book
                               AND bk.book_type_code = book
                               AND bk.asset_id = dd.asset_id
                               AND (bk.transaction_header_id_in =
                                    (SELECT MIN (fab.transaction_header_id_in)
                                       FROM fa_books_groups bg, fa_books fab
                                      WHERE     bg.group_asset_id =
                                                NVL (bk.group_asset_id, -2)
                                            AND bg.book_type_code =
                                                fab.book_type_code
                                            AND fab.transaction_header_id_in <=
                                                bg.transaction_header_id_in
                                            AND NVL (
                                                    fab.transaction_header_id_out,
                                                    bg.transaction_header_id_in) >=
                                                bg.transaction_header_id_in
                                            AND bg.period_counter =
                                                period_pc + 1
                                            AND fab.asset_id = bk.asset_id
                                            AND fab.book_type_code =
                                                bk.book_type_code
                                            AND bg.beginning_balance_flag
                                                    IS NOT NULL))
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                -- begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                        SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                               NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               report_type
                          FROM fa_books bk, fa_category_books cb, fa_asset_history ah,
                               fa_deprn_detail dd, fa_distribution_history dh, fa_group_asset_default gad
                         WHERE     gad.book_type_code = bk.book_type_code
                               AND gad.group_asset_id = bk.group_asset_id
                               AND bk.group_asset_id IS NOT NULL
                               AND dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = book
                               AND bk.book_type_code = book
                               AND bk.asset_id = dd.asset_id
                               AND (bk.transaction_header_id_in =
                                    (SELECT MIN (fab.transaction_header_id_in)
                                       FROM fa_books_groups bg, fa_books fab
                                      WHERE     bg.group_asset_id =
                                                NVL (bk.group_asset_id, -2)
                                            AND bg.book_type_code =
                                                fab.book_type_code
                                            AND fab.transaction_header_id_in <=
                                                bg.transaction_header_id_in
                                            AND NVL (
                                                    fab.transaction_header_id_out,
                                                    bg.transaction_header_id_in) >=
                                                bg.transaction_header_id_in
                                            AND bg.period_counter =
                                                period_pc + 1
                                            AND fab.asset_id = bk.asset_id
                                            AND fab.book_type_code =
                                                bk.book_type_code
                                            AND bg.beginning_balance_flag
                                                    IS NOT NULL))
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                END IF;
            END;
        -- end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        --END IF;
        ELSE
            -- changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    report_type)
                        SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                               NULL, 'BEGIN', dd.deprn_reserve,
                               dd.deprn_reserve * conversion_rate, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                   report_type
                          FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                               fa_deprn_periods fdp, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                     gl_daily_rates gdr --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                         WHERE     dd.book_type_code = book
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                               AND fdp.book_type_code = dd.book_type_code
                               AND fdp.period_counter = dd.period_counter
                               AND gdr.conversion_date =
                                   fdp.calendar_period_open_date
                               AND gdr.conversion_type = 'Spot'  --'Corporate'
                               AND gdr.from_currency = g_from_currency
                               AND gdr.to_currency = g_to_currency
                               --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                               AND dd.asset_id = gar.group_asset_id
                               AND gar.book_type_code = dd.book_type_code
                               AND gad.book_type_code = gar.book_type_code
                               AND gad.group_asset_id = gar.group_asset_id
                               AND dd.period_counter =
                                   (SELECT MAX (dd_sub.period_counter)
                                      FROM fa_deprn_detail dd_sub
                                     WHERE     dd_sub.book_type_code = book
                                           AND dd_sub.asset_id =
                                               gar.group_asset_id
                                           AND dd_sub.period_counter <=
                                               period_pc);
                --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                        SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                               NULL, 'BEGIN', dd.deprn_reserve,
                               report_type
                          FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad
                         WHERE     dd.book_type_code = book
                               AND dd.asset_id = gar.group_asset_id
                               AND gar.book_type_code = dd.book_type_code
                               AND gad.book_type_code = gar.book_type_code
                               AND gad.group_asset_id = gar.group_asset_id
                               AND dd.period_counter =
                                   (SELECT MAX (dd_sub.period_counter)
                                      FROM fa_deprn_detail dd_sub
                                     WHERE     dd_sub.book_type_code = book
                                           AND dd_sub.asset_id =
                                               gar.group_asset_id
                                           AND dd_sub.period_counter <=
                                               period_pc);
                END IF;
            END;
        --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        -- END IF;
        --NULL;
        END IF;
    --END IF;                                               --end of CRL check
    END get_balance_group_begin_sum;

    PROCEDURE get_balance_group_end_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period_pc IN NUMBER, earliest_pc IN NUMBER, period_date IN DATE, additions_date IN DATE
                                         , report_type IN VARCHAR2, balance_type IN VARCHAR2, begin_or_end IN VARCHAR2)
    IS
        p_date              DATE := period_date;
        a_date              DATE := additions_date;
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF report_type NOT IN ('RESERVE')
            THEN
                IF (h_reporting_flag = 'R')
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_fun, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                        SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                               NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               DECODE (report_type,  'COST', DECODE (NVL (bk_fun.group_asset_id, -2), -2, dd_fun.cost, bk_fun.cost),  'CIP COST', dd_fun.cost,  'RESERVE', dd_fun.deprn_reserve,  'REVAL RESERVE', dd_fun.reval_reserve), -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                                                                                                          report_type
                          FROM fa_books_mrc_v bk, fa_category_books cb, fa_asset_history ah,
                               fa_deprn_detail_mrc_v dd, -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                                                         fa_deprn_detail dd_fun, fa_books bk_fun,
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               fa_distribution_history dh, fa_group_asset_default gad
                         WHERE     gad.book_type_code = bk.book_type_code
                               AND gad.group_asset_id = bk.group_asset_id
                               -- This is to include only the Group Asset Members
                               AND bk.group_asset_id IS NOT NULL
                               AND dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail_mrc_v sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = book
                               AND bk.book_type_code = book
                               AND bk.asset_id = dd.asset_id
                               AND (bk.transaction_header_id_in =
                                    (SELECT MIN (fab.transaction_header_id_in)
                                       FROM fa_books_groups_mrc_v bg, fa_books_mrc_v fab
                                      WHERE     bg.group_asset_id =
                                                NVL (bk.group_asset_id, -2)
                                            AND bg.book_type_code =
                                                fab.book_type_code
                                            AND fab.transaction_header_id_in <=
                                                bg.transaction_header_id_in
                                            AND NVL (
                                                    fab.transaction_header_id_out,
                                                    bg.transaction_header_id_in) >=
                                                bg.transaction_header_id_in
                                            AND bg.period_counter =
                                                period_pc + 1
                                            AND fab.asset_id = bk.asset_id
                                            AND fab.book_type_code =
                                                bk.book_type_code
                                            AND bg.beginning_balance_flag
                                                    IS NOT NULL))
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND gad.book_type_code = bk_fun.book_type_code
                               AND gad.group_asset_id = bk_fun.group_asset_id
                               -- This is to include only the Group Asset Members
                               AND bk_fun.group_asset_id IS NOT NULL
                               AND DECODE (dd_fun.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd_fun.asset_id = dh.asset_id
                               AND dd_fun.book_type_code = book
                               AND dd_fun.distribution_id =
                                   dh.distribution_id
                               AND dd_fun.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd_fun.deprn_source_code,
                                           'D') =
                                   dd_fun.deprn_source_code
                               AND dd_fun.period_counter =
                                   (SELECT MAX (sub_dd_fun.period_counter)
                                      FROM fa_deprn_detail sub_dd_fun
                                     WHERE     sub_dd_fun.book_type_code =
                                               book
                                           AND sub_dd_fun.distribution_id =
                                               dh.distribution_id
                                           AND sub_dd_fun.period_counter <=
                                               period_pc)
                               AND DECODE (dd_fun.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND bk_fun.book_type_code = book
                               AND bk_fun.asset_id = dd_fun.asset_id
                               AND (bk_fun.transaction_header_id_in =
                                    (SELECT MIN (fab.transaction_header_id_in)
                                       FROM fa_books_groups bg, fa_books fab
                                      WHERE     bg.group_asset_id =
                                                NVL (bk_fun.group_asset_id,
                                                     -2)
                                            AND bg.book_type_code =
                                                fab.book_type_code
                                            AND fab.transaction_header_id_in <=
                                                bg.transaction_header_id_in
                                            AND NVL (
                                                    fab.transaction_header_id_out,
                                                    bg.transaction_header_id_in) >=
                                                bg.transaction_header_id_in
                                            AND bg.period_counter =
                                                period_pc + 1
                                            AND fab.asset_id =
                                                bk_fun.asset_id
                                            AND fab.book_type_code =
                                                bk_fun.book_type_code
                                            AND bg.beginning_balance_flag
                                                    IS NOT NULL))
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                        SELECT dh.asset_id, NVL (gad.deprn_expense_acct_ccid, dh.code_combination_id), gad.asset_cost_acct_ccid,
                               NULL, DECODE (report_type,  'RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  'REVAL RESERVE', DECODE (dd.deprn_source_code, 'D', begin_or_end, 'ADDITION'),  begin_or_end), DECODE (report_type,  'COST', DECODE (NVL (bk.group_asset_id, -2), -2, dd.cost, bk.cost),  'CIP COST', dd.cost,  'RESERVE', dd.deprn_reserve,  'REVAL RESERVE', dd.reval_reserve),
                               report_type
                          FROM fa_books bk, fa_category_books cb, fa_asset_history ah,
                               fa_deprn_detail dd, fa_distribution_history dh, fa_group_asset_default gad
                         WHERE     gad.book_type_code = bk.book_type_code
                               AND gad.group_asset_id = bk.group_asset_id
                               -- This is to include only the Group Asset Members
                               AND bk.group_asset_id IS NOT NULL
                               AND dh.book_type_code =
                                   distribution_source_book
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN dh.date_effective
                                                       AND NVL (
                                                               dh.date_ineffective,
                                                               SYSDATE)
                               AND dd.asset_id = dh.asset_id
                               AND dd.book_type_code = book
                               AND dd.distribution_id = dh.distribution_id
                               AND dd.period_counter <= period_pc
                               AND DECODE (begin_or_end,
                                           'BEGIN', dd.deprn_source_code,
                                           'D') =
                                   dd.deprn_source_code
                               AND dd.period_counter =
                                   (SELECT MAX (sub_dd.period_counter)
                                      FROM fa_deprn_detail sub_dd
                                     WHERE     sub_dd.book_type_code = book
                                           AND sub_dd.distribution_id =
                                               dh.distribution_id
                                           AND sub_dd.period_counter <=
                                               period_pc)
                               AND ah.asset_id = dh.asset_id
                               AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                               AND DECODE (dd.deprn_source_code,
                                           'D', p_date,
                                           a_date) BETWEEN ah.date_effective
                                                       AND NVL (
                                                               ah.date_ineffective,
                                                               SYSDATE)
                               AND cb.category_id = ah.category_id
                               AND cb.book_type_code = book
                               AND bk.book_type_code = book
                               AND bk.asset_id = dd.asset_id
                               AND (bk.transaction_header_id_in =
                                    (SELECT MIN (fab.transaction_header_id_in)
                                       FROM fa_books_groups bg, fa_books fab
                                      WHERE     bg.group_asset_id =
                                                NVL (bk.group_asset_id, -2)
                                            AND bg.book_type_code =
                                                fab.book_type_code
                                            AND fab.transaction_header_id_in <=
                                                bg.transaction_header_id_in
                                            AND NVL (
                                                    fab.transaction_header_id_out,
                                                    bg.transaction_header_id_in) >=
                                                bg.transaction_header_id_in
                                            AND bg.period_counter =
                                                period_pc + 1
                                            AND fab.asset_id = bk.asset_id
                                            AND fab.book_type_code =
                                                bk.book_type_code
                                            AND bg.beginning_balance_flag
                                                    IS NOT NULL))
                               AND DECODE (
                                       report_type,
                                       'COST', DECODE (
                                                   ah.asset_type,
                                                   'CAPITALIZED', cb.asset_cost_acct,
                                                   NULL),
                                       'CIP COST', DECODE (
                                                       ah.asset_type,
                                                       'CIP', cb.cip_cost_acct,
                                                       NULL),
                                       'RESERVE', cb.deprn_reserve_acct,
                                       'REVAL RESERVE', cb.reval_reserve_acct)
                                       IS NOT NULL;
                END IF;
            ELSE
                IF (h_reporting_flag = 'R')
                THEN
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_fun, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                    report_type)
                        SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                               NULL, 'END', dd.deprn_reserve,
                               dd_fun.deprn_reserve, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                     report_type
                          FROM fa_deprn_summary_mrc_v dd, fa_deprn_summary dd_fun, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                                                                   fa_group_asset_rules gar,
                               fa_group_asset_default gad
                         WHERE     dd.book_type_code = book
                               AND dd.asset_id = gar.group_asset_id
                               AND gar.book_type_code = dd.book_type_code
                               AND gad.book_type_code = gar.book_type_code
                               AND gad.group_asset_id = gar.group_asset_id
                               -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND dd_fun.book_type_code = book
                               AND dd_fun.asset_id = gar.group_asset_id
                               AND gar.book_type_code = dd_fun.book_type_code
                               AND dd_fun.period_counter =
                                   (SELECT MAX (dd_sub.period_counter)
                                      FROM fa_deprn_detail dd_sub
                                     WHERE     dd_sub.book_type_code = book
                                           AND dd_sub.asset_id =
                                               gar.group_asset_id
                                           AND dd_sub.period_counter <=
                                               period_pc)
                               -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                               AND dd.period_counter =
                                   (SELECT MAX (dd_sub.period_counter)
                                      FROM fa_deprn_detail_mrc_v dd_sub
                                     WHERE     dd_sub.book_type_code = book
                                           AND dd_sub.asset_id =
                                               gar.group_asset_id
                                           AND dd_sub.period_counter <=
                                               period_pc);
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                        SELECT gar.group_asset_id asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                               NULL, 'END', dd.deprn_reserve,
                               report_type
                          FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad
                         WHERE     dd.book_type_code = book
                               AND dd.asset_id = gar.group_asset_id
                               AND gar.book_type_code = dd.book_type_code
                               AND gad.book_type_code = gar.book_type_code
                               AND gad.group_asset_id = gar.group_asset_id
                               AND dd.period_counter =
                                   (SELECT MAX (dd_sub.period_counter)
                                      FROM fa_deprn_detail dd_sub
                                     WHERE     dd_sub.book_type_code = book
                                           AND dd_sub.asset_id =
                                               gar.group_asset_id
                                           AND dd_sub.period_counter <=
                                               period_pc);
                END IF;
            END IF;
        END IF;                                            -- end of CRL check
    END get_balance_group_end_sum;

    PROCEDURE get_adjustments_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                                   , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2)
    IS
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);

            /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'h_set_of_books_id:' || h_set_of_books_id);*/



            IF (h_set_of_books_id = -1)
            THEN
                h_set_of_books_id   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            SELECT set_of_books_id
              INTO h_set_of_books_id
              FROM fa_book_controls
             WHERE book_type_code = book;

            h_reporting_flag   := 'P';
        END IF;

        -- Run only if CRL not installed.
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'N')
        THEN
            -- commented to display all columns for any reporting_flag by showkath
            --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount * conversion_rate) amount_nonf, --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                                                                                                report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_transaction_headers th,
                                 fa_asset_history ah, fa_adjustments aj, /* SLA Changes */
                                                                         xla_ae_headers headers,
                                 xla_ae_lines lines, xla_distribution_links links, --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                                   fa_deprn_periods fdp,
                                 gl_daily_rates gdr
                           --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter =
                                     aj.period_counter_created
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 /* SLA Changes */
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, report_type;
                --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_transaction_headers th,
                                 fa_asset_history ah, fa_adjustments aj, /* SLA Changes */
                                                                         xla_ae_headers headers,
                                 xla_ae_lines lines, xla_distribution_links links
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 /* SLA Changes */
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, report_type;
                END IF;
            END;
        --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        --END IF;
        -- Run only if CRL installed.
        ELSIF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            --commented by showkath to fix conv_rate issue(4) on 06-DEC-2015
            --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount * conversion_rate), --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                                                                                    report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_transaction_headers th,
                                 fa_asset_history ah, fa_adjustments aj, /* SLA Changes */
                                                                         xla_ae_headers headers,
                                 xla_ae_lines lines, xla_distribution_links links, fa_deprn_periods fdp, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 gl_daily_rates gdr --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 -- begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter =
                                     aj.period_counter_created
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 -- start of cua
                                 AND NOT EXISTS
                                         (SELECT 'x'
                                            FROM fa_books bks
                                           WHERE     bks.book_type_code = book
                                                 AND bks.asset_id = aj.asset_id
                                                 AND bks.group_asset_id
                                                         IS NOT NULL
                                                 AND bks.date_ineffective
                                                         IS NOT NULL)
                                 -- end of cua
                                 /* SLA Changes */
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, report_type;
                --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                          SELECT dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                                 report_type
                            FROM fa_lookups rt, fa_distribution_history dh, fa_transaction_headers th,
                                 fa_asset_history ah, fa_adjustments aj, /* SLA Changes */
                                                                         xla_ae_headers headers,
                                 xla_ae_lines lines, xla_distribution_links links
                           WHERE     rt.lookup_type = 'REPORT TYPE'
                                 AND rt.lookup_code = report_type
                                 AND dh.book_type_code =
                                     distribution_source_book
                                 AND aj.asset_id = dh.asset_id
                                 AND aj.book_type_code = book
                                 AND aj.distribution_id = dh.distribution_id
                                 AND aj.adjustment_type IN
                                         (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                                 AND aj.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                                 AND th.transaction_header_id =
                                     aj.transaction_header_id
                                 AND ah.asset_id = dh.asset_id
                                 AND ((ah.asset_type != 'EXPENSED' AND report_type IN ('COST', 'CIP COST')) OR (ah.asset_type IN ('CAPITALIZED', 'CIP') AND report_type IN ('RESERVE', 'REVAL RESERVE')))
                                 AND th.transaction_header_id BETWEEN ah.transaction_header_id_in
                                                                  AND NVL (
                                                                            ah.transaction_header_id_out
                                                                          - 1,
                                                                          th.transaction_header_id)
                                 AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                     0
                                 -- start of cua
                                 AND NOT EXISTS
                                         (SELECT 'x'
                                            FROM fa_books bks
                                           WHERE     bks.book_type_code = book
                                                 AND bks.asset_id = aj.asset_id
                                                 AND bks.group_asset_id
                                                         IS NOT NULL
                                                 AND bks.date_ineffective
                                                         IS NOT NULL)
                                 -- end of cua
                                 /* SLA Changes */
                                 AND links.source_distribution_id_num_1 =
                                     aj.transaction_header_id
                                 AND links.source_distribution_id_num_2 =
                                     aj.adjustment_line_id
                                 AND links.application_id = 140
                                 AND links.source_distribution_type = 'TRX'
                                 AND headers.application_id = 140
                                 AND headers.ae_header_id = links.ae_header_id
                                 AND headers.ledger_id = h_set_of_books_id
                                 AND lines.ae_header_id = links.ae_header_id
                                 AND lines.ae_line_num = links.ae_line_num
                                 AND lines.application_id = 140
                        GROUP BY dh.asset_id, dh.code_combination_id, lines.code_combination_id, --AJ.Code_Combination_ID,
                                 aj.source_type_code, report_type;
                END IF;
            END;
        --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        -- END IF;
        END IF;

        IF report_type = 'RESERVE'
        THEN
            --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    report_type)
                          SELECT dh.asset_id, dh.code_combination_id, NULL,
                                 cb.deprn_reserve_acct, 'ADDITION', SUM (dd.deprn_reserve),
                                 SUM (dd.deprn_reserve * conversion_rate), --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                           report_type
                            FROM fa_distribution_history dh, fa_category_books cb, fa_asset_history ah,
                                 fa_deprn_detail dd, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                     fa_deprn_periods fdp, gl_daily_rates gdr
                           --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                           WHERE     NOT EXISTS
                                         (SELECT asset_id
                                            FROM xxdo.xxd_fa_roll_fwd_sum_t
                                           WHERE     asset_id = dh.asset_id
                                                 AND distribution_ccid =
                                                     dh.code_combination_id
                                                 AND source_type_code =
                                                     'ADDITION')
                                 AND dd.book_type_code = book
                                 --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter = DD.period_counter
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND (dd.period_counter + 1) BETWEEN period1_pc
                                                                 AND period2_pc
                                 AND dd.deprn_source_code = 'B'
                                 AND dd.asset_id = dh.asset_id
                                 AND dd.deprn_reserve != 0
                                 AND dd.distribution_id = dh.distribution_id
                                 AND dh.asset_id = ah.asset_id
                                 AND ah.date_effective <
                                     NVL (dh.date_ineffective, SYSDATE)
                                 AND NVL (dh.date_ineffective, SYSDATE) <=
                                     NVL (ah.date_ineffective, SYSDATE)
                                 AND dd.book_type_code = cb.book_type_code
                                 AND ah.category_id = cb.category_id
                        GROUP BY dh.asset_id, dh.code_combination_id, cb.deprn_reserve_acct,
                                 report_type;
                ----changes by showkath to fix conv_rate issue(4) on 06-DEC-201
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                          SELECT dh.asset_id, dh.code_combination_id, NULL,
                                 cb.deprn_reserve_acct, 'ADDITION', SUM (dd.deprn_reserve),
                                 report_type
                            FROM fa_distribution_history dh, fa_category_books cb, fa_asset_history ah,
                                 fa_deprn_detail dd
                           WHERE     NOT EXISTS
                                         (SELECT asset_id
                                            FROM xxdo.xxd_fa_roll_fwd_sum_t
                                           WHERE     asset_id = dh.asset_id
                                                 AND distribution_ccid =
                                                     dh.code_combination_id
                                                 AND source_type_code =
                                                     'ADDITION')
                                 AND dd.book_type_code = book
                                 AND (dd.period_counter + 1) BETWEEN period1_pc
                                                                 AND period2_pc
                                 AND dd.deprn_source_code = 'B'
                                 AND dd.asset_id = dh.asset_id
                                 AND dd.deprn_reserve != 0
                                 AND dd.distribution_id = dh.distribution_id
                                 AND dh.asset_id = ah.asset_id
                                 AND ah.date_effective <
                                     NVL (dh.date_ineffective, SYSDATE)
                                 AND NVL (dh.date_ineffective, SYSDATE) <=
                                     NVL (ah.date_ineffective, SYSDATE)
                                 AND dd.book_type_code = cb.book_type_code
                                 AND ah.category_id = cb.category_id
                        GROUP BY dh.asset_id, dh.code_combination_id, cb.deprn_reserve_acct,
                                 report_type;
                END IF;
            END;
        --changes by showkath to fix conv_rate issue(4) on 06-DEC-201
        --END IF;
        END IF;
    END get_adjustments_sum;

    PROCEDURE get_adjustments_for_group_sum (book IN VARCHAR2, distribution_source_book IN VARCHAR2, period1_pc IN NUMBER
                                             , period2_pc IN NUMBER, report_type IN VARCHAR2, balance_type IN VARCHAR2)
    IS
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);

            /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                    'h_set_of_books_id:' || h_set_of_books_id);*/


            IF (h_set_of_books_id = -1)
            THEN
                h_set_of_books_id   := NULL;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            SELECT set_of_books_id
              INTO h_set_of_books_id
              FROM fa_book_controls
             WHERE book_type_code = book;

            h_reporting_flag   := 'P';
        END IF;

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            IF (h_reporting_flag = 'R')
            THEN
                INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                asset_id,
                                distribution_ccid,
                                adjustment_ccid,
                                category_books_account,
                                source_type_code,
                                amount,
                                amount_fun, --Added by BT Technology Team v4.1 on 18-Dec-2014
                                report_type)
                      SELECT aj.asset_id, gad.deprn_expense_acct_ccid, DECODE (aj.adjustment_type, 'COST', gad.asset_cost_acct_ccid, lines.code_combination_id /*AJ.Code_Combination_ID*/
                                                                                                                                                              ),
                             NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                             -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                             SUM (DECODE (aj_fun.debit_credit_flag, balance_type, 1, -1) * aj_fun.adjustment_amount), -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                      report_type
                        FROM fa_lookups rt, fa_adjustments_mrc_v aj, fa_books_mrc_v bk,
                             -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                             fa_adjustments aj_fun, fa_books bk_fun, -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                     fa_group_asset_default gad,
                             /* SLA Changes */
                             xla_ae_headers headers, xla_ae_lines lines, xla_distribution_links links
                       WHERE     bk.asset_id = aj.asset_id
                             AND bk.book_type_code = book
                             AND bk.group_asset_id = gad.group_asset_id
                             AND bk.book_type_code = gad.book_type_code
                             AND bk.date_ineffective IS NULL
                             AND aj.asset_id IN
                                     (SELECT asset_id
                                        FROM fa_books_mrc_v
                                       WHERE     group_asset_id IS NOT NULL
                                             AND date_ineffective IS NULL)
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND rt.lookup_code = report_type
                             AND aj.asset_id = bk.asset_id
                             AND aj.book_type_code = book
                             AND aj.adjustment_type IN
                                     (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                             AND aj.period_counter_created BETWEEN period1_pc
                                                               AND period2_pc
                             AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                 0
                             /* SLA Changes */
                             AND links.source_distribution_id_num_1 =
                                 aj.transaction_header_id
                             AND links.source_distribution_id_num_2 =
                                 aj.adjustment_line_id
                             -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                             AND bk_fun.asset_id = aj_fun.asset_id
                             AND bk_fun.book_type_code = book
                             AND bk_fun.group_asset_id = gad.group_asset_id
                             AND bk_fun.book_type_code = gad.book_type_code
                             AND bk_fun.date_ineffective IS NULL
                             AND aj_fun.asset_id IN
                                     (SELECT asset_id
                                        FROM fa_books
                                       WHERE     group_asset_id IS NOT NULL
                                             AND date_ineffective IS NULL)
                             AND aj_fun.asset_id = bk_fun.asset_id
                             AND aj_fun.book_type_code = book
                             AND aj_fun.adjustment_type IN
                                     (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                             AND aj_fun.period_counter_created BETWEEN period1_pc
                                                                   AND period2_pc
                             AND (DECODE (rt.lookup_code, aj_fun.adjustment_type, 1, 0) * aj_fun.adjustment_amount) !=
                                 0
                             /* SLA Changes */
                             AND links.source_distribution_id_num_1 =
                                 aj_fun.transaction_header_id
                             AND links.source_distribution_id_num_2 =
                                 aj_fun.adjustment_line_id
                             -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                             AND links.application_id = 140
                             AND links.source_distribution_type = 'TRX'
                             AND headers.application_id = 140
                             AND headers.ae_header_id = links.ae_header_id
                             AND headers.ledger_id = h_set_of_books_id
                             AND lines.ae_header_id = links.ae_header_id
                             AND lines.ae_line_num = links.ae_line_num
                             AND lines.application_id = 140
                    GROUP BY aj.asset_id, gad.deprn_expense_acct_ccid, DECODE (aj.adjustment_type, 'COST', gad.asset_cost_acct_ccid, lines.code_combination_id /*AJ.Code_Combination_ID*/
                                                                                                                                                              ),
                             aj.source_type_code, report_type;
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                        , report_type)
                      SELECT aj.asset_id, gad.deprn_expense_acct_ccid, DECODE (aj.adjustment_type, 'COST', gad.asset_cost_acct_ccid, lines.code_combination_id /*AJ.Code_Combination_ID*/
                                                                                                                                                              ),
                             NULL, aj.source_type_code, SUM (DECODE (aj.debit_credit_flag, balance_type, 1, -1) * aj.adjustment_amount),
                             report_type
                        FROM fa_lookups rt, fa_adjustments aj, fa_books bk,
                             fa_group_asset_default gad, /* SLA Changes */
                                                         xla_ae_headers headers, xla_ae_lines lines,
                             xla_distribution_links links
                       WHERE     bk.asset_id = aj.asset_id
                             AND bk.book_type_code = book
                             AND bk.group_asset_id = gad.group_asset_id
                             AND bk.book_type_code = gad.book_type_code
                             AND bk.date_ineffective IS NULL
                             AND aj.asset_id IN
                                     (SELECT asset_id
                                        FROM fa_books
                                       WHERE     group_asset_id IS NOT NULL
                                             AND date_ineffective IS NULL)
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND rt.lookup_code = report_type
                             AND aj.asset_id = bk.asset_id
                             AND aj.book_type_code = book
                             AND aj.adjustment_type IN
                                     (report_type, DECODE (report_type, 'REVAL RESERVE', 'REVAL AMORT'))
                             AND aj.period_counter_created BETWEEN period1_pc
                                                               AND period2_pc
                             AND (DECODE (rt.lookup_code, aj.adjustment_type, 1, 0) * aj.adjustment_amount) !=
                                 0
                             /* SLA Changes */
                             AND links.source_distribution_id_num_1 =
                                 aj.transaction_header_id
                             AND links.source_distribution_id_num_2 =
                                 aj.adjustment_line_id
                             AND links.application_id = 140
                             AND links.source_distribution_type = 'TRX'
                             AND headers.application_id = 140
                             AND headers.ae_header_id = links.ae_header_id
                             AND headers.ledger_id = h_set_of_books_id
                             AND lines.ae_header_id = links.ae_header_id
                             AND lines.ae_line_num = links.ae_line_num
                             AND lines.application_id = 140
                    GROUP BY aj.asset_id, gad.deprn_expense_acct_ccid, DECODE (aj.adjustment_type, 'COST', gad.asset_cost_acct_ccid, lines.code_combination_id /* AJ.Code_Combination_ID*/
                                                                                                                                                              ),
                             aj.source_type_code, report_type;
            END IF;
        END IF;
    END get_adjustments_for_group_sum;

    PROCEDURE get_deprn_effects_sum (book                       IN VARCHAR2,
                                     distribution_source_book   IN VARCHAR2,
                                     period1_pc                 IN NUMBER,
                                     period2_pc                 IN NUMBER,
                                     report_type                IN VARCHAR2)
    IS
        h_set_of_books_id   NUMBER;
        h_reporting_flag    VARCHAR2 (1);
        v_sob_id            VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;


            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/
        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        -- begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        BEGIN
            IF g_to_currency <> g_from_currency
            THEN
                ---- end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                asset_id,
                                distribution_ccid,
                                adjustment_ccid,
                                category_books_account,
                                source_type_code,
                                amount,
                                amount_nonf, -- changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                report_type)
                      SELECT dh.asset_id, dh.code_combination_id, NULL,
                             DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (dd.deprn_source_code, 'D', 'DEPRECIATION', 'ADDITION'), SUM (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - DECODE (adj.debit_credit_flag, 'DR', 1, -1) * NVL (adj.adjustment_amount, 0),  'REVAL RESERVE', -dd.reval_amortization)),
                             --start changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                             SUM (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - DECODE (adj.debit_credit_flag, 'DR', 1, -1) * NVL (adj.adjustment_amount, 0),  'REVAL RESERVE', -dd.reval_amortization) * conversion_rate), -- end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                                                                                                                                                                                    report_type
                        FROM fa_lookups_b rt, fa_category_books cb, fa_distribution_history dh,
                             fa_asset_history ah, fa_deprn_detail dd, fa_deprn_periods dp,
                             fa_adjustments adj, --start changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                 fa_deprn_periods fdp, gl_daily_rates gdr
                       --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                       WHERE     dh.book_type_code = distribution_source_book
                             --start changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                             AND fdp.book_type_code = book
                             AND fdp.period_counter = dd.period_counter
                             AND gdr.conversion_date =
                                 fdp.calendar_period_open_date
                             AND gdr.conversion_type = 'Corporate'
                             AND gdr.from_currency = g_from_currency
                             AND gdr.to_currency = g_to_currency
                             --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                             AND ah.asset_id = dh.asset_id
                             AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                             AND ah.date_effective <
                                 NVL (dh.date_ineffective, SYSDATE)
                             AND NVL (dh.date_ineffective, SYSDATE) <=
                                 NVL (ah.date_ineffective, SYSDATE)
                             AND cb.category_id = ah.category_id
                             AND cb.book_type_code = book
                             AND ((dd.deprn_source_code = 'B' AND (dd.period_counter + 1) < period2_pc) OR (dd.deprn_source_code = 'D'))
                             AND dd.book_type_code || '' = book
                             AND dd.asset_id = dh.asset_id
                             AND dd.distribution_id = dh.distribution_id
                             AND dd.period_counter BETWEEN period1_pc
                                                       AND period2_pc
                             AND dp.book_type_code = dd.book_type_code
                             AND dp.period_counter = dd.period_counter
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND DECODE (
                                     rt.lookup_code,
                                     'RESERVE', cb.deprn_reserve_acct,
                                     'REVAL RESERVE', cb.reval_reserve_acct)
                                     IS NOT NULL
                             AND (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount,  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0 OR DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - NVL (dd.deprn_adjustment_amount, 0),  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0)
                             AND adj.asset_id(+) = dd.asset_id
                             AND adj.book_type_code(+) = dd.book_type_code
                             AND adj.period_counter_created(+) =
                                 dd.period_counter
                             AND adj.distribution_id(+) = dd.distribution_id
                             AND adj.source_type_code(+) = 'REVALUATION'
                             AND adj.adjustment_type(+) = 'EXPENSE'
                             AND adj.adjustment_amount(+) <> 0
                    GROUP BY dh.asset_id, dh.code_combination_id, DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct),
                             dd.deprn_source_code, report_type;
            --start changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            ELSE
                INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                        , report_type)
                      SELECT dh.asset_id, dh.code_combination_id, NULL,
                             DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct), DECODE (dd.deprn_source_code, 'D', 'DEPRECIATION', 'ADDITION'), SUM (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - DECODE (adj.debit_credit_flag, 'DR', 1, -1) * NVL (adj.adjustment_amount, 0),  'REVAL RESERVE', -dd.reval_amortization)),
                             report_type
                        FROM fa_lookups_b rt, fa_category_books cb, fa_distribution_history dh,
                             fa_asset_history ah, fa_deprn_detail dd, fa_deprn_periods dp,
                             fa_adjustments adj
                       WHERE     dh.book_type_code = distribution_source_book
                             AND ah.asset_id = dh.asset_id
                             AND ah.asset_type IN ('CAPITALIZED', 'CIP')
                             AND ah.date_effective <
                                 NVL (dh.date_ineffective, SYSDATE)
                             AND NVL (dh.date_ineffective, SYSDATE) <=
                                 NVL (ah.date_ineffective, SYSDATE)
                             AND cb.category_id = ah.category_id
                             AND cb.book_type_code = book
                             AND ((dd.deprn_source_code = 'B' AND (dd.period_counter + 1) < period2_pc) OR (dd.deprn_source_code = 'D'))
                             AND dd.book_type_code || '' = book
                             AND dd.asset_id = dh.asset_id
                             AND dd.distribution_id = dh.distribution_id
                             AND dd.period_counter BETWEEN period1_pc
                                                       AND period2_pc
                             AND dp.book_type_code = dd.book_type_code
                             AND dp.period_counter = dd.period_counter
                             AND rt.lookup_type = 'REPORT TYPE'
                             AND DECODE (
                                     rt.lookup_code,
                                     'RESERVE', cb.deprn_reserve_acct,
                                     'REVAL RESERVE', cb.reval_reserve_acct)
                                     IS NOT NULL
                             AND (DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount,  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0 OR DECODE (rt.lookup_code,  'RESERVE', dd.deprn_amount - NVL (dd.deprn_adjustment_amount, 0),  'REVAL RESERVE', NVL (dd.reval_amortization, 0)) != 0)
                             AND adj.asset_id(+) = dd.asset_id
                             AND adj.book_type_code(+) = dd.book_type_code
                             AND adj.period_counter_created(+) =
                                 dd.period_counter
                             AND adj.distribution_id(+) = dd.distribution_id
                             AND adj.source_type_code(+) = 'REVALUATION'
                             AND adj.adjustment_type(+) = 'EXPENSE'
                             AND adj.adjustment_amount(+) <> 0
                    GROUP BY dh.asset_id, dh.code_combination_id, DECODE (rt.lookup_code,  'RESERVE', cb.deprn_reserve_acct,  'REVAL RESERVE', cb.reval_reserve_acct),
                             dd.deprn_source_code, report_type;
            END IF;
        END;

        --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        --END IF;

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            -- commented  by showkath to fix conv_rate issue(4) on 06-DEC-2015
            --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
            BEGIN
                IF g_from_currency <> g_to_currency
                THEN
                    --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (
                                    asset_id,
                                    distribution_ccid,
                                    adjustment_ccid,
                                    category_books_account,
                                    source_type_code,
                                    amount,
                                    amount_nonf, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    report_type)
                          SELECT dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', SUM (dd.deprn_amount),
                                 SUM (dd.deprn_amount * conversion_rate), --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                                          report_type
                            FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad,
                                 fa_deprn_periods fdp, --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                                       gl_daily_rates gdr --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                           WHERE     dd.book_type_code = book
                                 --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND fdp.book_type_code = book
                                 AND fdp.period_counter = dd.period_counter
                                 AND gdr.conversion_date =
                                     fdp.calendar_period_open_date
                                 AND gdr.conversion_type = 'Corporate'
                                 AND gdr.from_currency = g_from_currency
                                 AND gdr.to_currency = g_to_currency
                                 --changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                 AND dd.asset_id = gar.group_asset_id
                                 AND gar.book_type_code = dd.book_type_code
                                 AND gad.book_type_code = gar.book_type_code
                                 AND gad.group_asset_id = gar.group_asset_id
                                 AND dd.period_counter BETWEEN period1_pc
                                                           AND period2_pc
                        GROUP BY dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', report_type;
                --begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                ELSE
                    INSERT INTO xxdo.xxd_fa_roll_fwd_sum_t (asset_id, distribution_ccid, adjustment_ccid, category_books_account, source_type_code, amount
                                                            , report_type)
                          SELECT dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', SUM (dd.deprn_amount),
                                 report_type
                            FROM fa_deprn_summary dd, fa_group_asset_rules gar, fa_group_asset_default gad
                           WHERE     dd.book_type_code = book
                                 AND dd.asset_id = gar.group_asset_id
                                 AND gar.book_type_code = dd.book_type_code
                                 AND gad.book_type_code = gar.book_type_code
                                 AND gad.group_asset_id = gar.group_asset_id
                                 AND dd.period_counter BETWEEN period1_pc
                                                           AND period2_pc
                        GROUP BY dd.asset_id, gad.deprn_expense_acct_ccid, gad.deprn_reserve_acct_ccid,
                                 NULL, 'DEPRECIATION', report_type;
                END IF;
            END;
        --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
        --END IF;
        END IF;                                            -- end of CRL check
    END get_deprn_effects_sum;

    PROCEDURE insert_info_sum (book                IN VARCHAR2,
                               start_period_name   IN VARCHAR2,
                               end_period_name     IN VARCHAR2,
                               report_type         IN VARCHAR2,
                               adj_mode            IN VARCHAR2)
    IS
        period1_pc                 NUMBER;
        period1_pod                DATE;
        period1_pcd                DATE;
        period2_pc                 NUMBER;
        period2_pcd                DATE;
        distribution_source_book   VARCHAR2 (15);
        balance_type               VARCHAR2 (2);
        h_set_of_books_id          NUMBER;
        h_reporting_flag           VARCHAR2 (1);
        v_sob_id                   VARCHAR2 (100);
    BEGIN
        -- get mrc related info
        BEGIN
            -- h_set_of_books_id := to_number(substrb(userenv('CLIENT_INFO'),45,10));

            --       Commented by B T Technology v 4.0 on 10 Nov 2014
            --         SELECT TO_NUMBER (SUBSTRB (USERENV ('CLIENT_INFO'), 45, 10))
            --           INTO h_set_of_books_id
            --           FROM DUAL;

            v_sob_id            := g_set_of_books_id;


            h_set_of_books_id   := xxd_fa_set_client_info_fnc (v_sob_id);
        /*apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_set_of_books_id:' || h_set_of_books_id);*/

        EXCEPTION
            WHEN OTHERS
            THEN
                h_set_of_books_id   := NULL;
        END;

        IF (h_set_of_books_id IS NOT NULL)
        THEN
            IF NOT fa_cache_pkg.fazcsob (
                       x_set_of_books_id     => h_set_of_books_id,
                       x_mrc_sob_type_code   => h_reporting_flag)
            THEN
                RAISE fnd_api.g_exc_unexpected_error;
            END IF;
        ELSE
            h_reporting_flag   := 'P';
        END IF;

        print_log_prc ('h_reporting_flag3 :' || h_reporting_flag);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'h_reporting_flag:' || h_reporting_flag);

        IF (h_reporting_flag = 'R')
        THEN
            SELECT p1.period_counter, p1.period_open_date, NVL (p1.period_close_date, SYSDATE),
                   p2.period_counter, NVL (p2.period_close_date, SYSDATE), bc.distribution_source_book
              INTO period1_pc, period1_pod, period1_pcd, period2_pc,
                             period2_pcd, distribution_source_book
              FROM fa_deprn_periods_mrc_v p1, fa_deprn_periods_mrc_v p2, fa_book_controls_mrc_v bc
             WHERE     bc.book_type_code = book
                   AND p1.book_type_code = book
                   AND p1.period_name = start_period_name
                   AND p2.book_type_code = book
                   AND p2.period_name = end_period_name;
        ELSE
            SELECT p1.period_counter, p1.period_open_date, NVL (p1.period_close_date, SYSDATE),
                   p2.period_counter, NVL (p2.period_close_date, SYSDATE), bc.distribution_source_book
              INTO period1_pc, period1_pod, period1_pcd, period2_pc,
                             period2_pcd, distribution_source_book
              FROM fa_deprn_periods p1, fa_deprn_periods p2, fa_book_controls bc
             WHERE     bc.book_type_code = book
                   AND p1.book_type_code = book
                   AND p1.period_name = start_period_name
                   AND p2.book_type_code = book
                   AND p2.period_name = end_period_name;
        END IF;

        IF (report_type = 'RESERVE' OR report_type = 'REVAL RESERVE')
        THEN
            balance_type   := 'CR';                                    --'CR';
        ELSE
            balance_type   := 'DR';                                    --'DR';
        END IF;

        DELETE FROM fa_lookups_b
              WHERE lookup_type = 'REPORT TYPE' AND lookup_code = report_type;

        DELETE FROM fa_lookups_tl
              WHERE lookup_type = 'REPORT TYPE' AND lookup_code = report_type;

        INSERT INTO fa_lookups_b (lookup_type, lookup_code, last_updated_by,
                                  last_update_date, enabled_flag)
             VALUES ('REPORT TYPE', report_type, 1,
                     SYSDATE, 'Y');

        INSERT INTO fa_lookups_tl (lookup_type, lookup_code, meaning,
                                   last_update_date, last_updated_by, language
                                   , source_lang)
            SELECT 'REPORT TYPE', report_type, report_type,
                   SYSDATE, 1, l.language_code,
                   USERENV ('LANG')
              FROM fnd_languages l
             WHERE     l.installed_flag IN ('I', 'B')
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM fa_lookups_tl t
                             WHERE     t.lookup_type = 'REPORT TYPE'
                                   AND t.lookup_code = report_type
                                   AND t.language = l.language_code);

        /* Get Beginning Balance */
        /* Use Period1_PC-1, to get balance as of end of period immediately
        preceding Period1_PC */
        get_balance_sum (book, distribution_source_book, period1_pc - 1,
                         period1_pc - 1, period1_pod, period1_pcd,
                         report_type, balance_type, 'BEGIN');

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            get_balance_group_begin_sum (book,
                                         distribution_source_book,
                                         period1_pc - 1,
                                         period1_pc - 1,
                                         period1_pod,
                                         period1_pcd,
                                         report_type,
                                         balance_type,
                                         'BEGIN');
        END IF;

        /* Get Ending Balance */
        get_balance_sum (book, distribution_source_book, period2_pc,
                         period1_pc - 1, period2_pcd, period2_pcd,
                         report_type, balance_type, 'END');

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            get_balance_group_end_sum (book, distribution_source_book, period2_pc, period1_pc - 1, period2_pcd, period2_pcd
                                       , report_type, balance_type, 'END');
        END IF;

        get_adjustments_sum (book, distribution_source_book, period1_pc,
                             period2_pc, report_type, balance_type);

        -- run only if CRL installed
        IF (NVL (fnd_profile.VALUE ('CRL-FA ENABLED'), 'N') = 'Y')
        THEN
            get_adjustments_for_group_sum (book,
                                           distribution_source_book,
                                           period1_pc,
                                           period2_pc,
                                           report_type,
                                           balance_type);
        END IF;

        IF (report_type = 'RESERVE' OR report_type = 'REVAL RESERVE')
        THEN
            get_deprn_effects_sum (book, distribution_source_book, period1_pc
                                   , period2_pc, report_type);
        END IF;
    END insert_info_sum;

    PROCEDURE main_summary (errbuf                OUT VARCHAR2,
                            retcode               OUT NUMBER,
                            p_book             IN     VARCHAR2,
                            p_currency         IN     VARCHAR2,
                            p_from_period      IN     VARCHAR2,
                            p_to_period        IN     VARCHAR2,
                            p_subtotal         IN     VARCHAR2,
                            p_subtotal_value   IN     VARCHAR2)
    AS
        v_num                           NUMBER;
        v_supplier                      VARCHAR2 (100);
        v_cost                          NUMBER;
        v_dep_reserve                   NUMBER;
        v_current_period_depreciation   NUMBER;
        v_ending_dpereciation_reserve   NUMBER;
        v_net_book_value                NUMBER;
        v_report_date                   VARCHAR2 (30);
        v_asset_count                   NUMBER;
        v_prior_year                    NUMBER;
        v_begining_yr_deprn             NUMBER;
        v_ytd_deprn_transfer            NUMBER;
        v_ytd_deprn                     NUMBER;
        v_cost_total                    NUMBER;
        v_current_period_deprn_total    NUMBER;
        v_ytd_deprn_total               NUMBER;
        v_ending_deprn_reserve_total    NUMBER;
        v_net_book_value_total          NUMBER;
        v_begin_yr_deprn_total          NUMBER;
        v_ending_total                  NUMBER;
        v_begin_total                   NUMBER;
        v_addition_total                NUMBER;
        v_adjustment_total              NUMBER;
        v_retirement_total              NUMBER;
        v_reclass_total                 NUMBER;
        v_transfer_total                NUMBER;
        v_revaluation_total             NUMBER;
        v_custodian                     VARCHAR2 (50);
        v_location_id                   NUMBER;
        v_location_flexfield            VARCHAR2 (100);
        v_depreciation_account          VARCHAR2 (100);
        v_null_count                    NUMBER := 0;
        v_asset_num                     NUMBER;
        v_period_from                   VARCHAR2 (20);
        v_date_in_service               DATE;                  --VARCHAR2(20);
        v_method_code                   VARCHAR2 (20);
        v_life                          NUMBER;
        --v_period_from VARCHAR2(20);
        v_period_to                     VARCHAR2 (20);
        --v_net_book_value NUMBER;
        vn_adj_cost                     NUMBER;
        vn_deprn_reserve                NUMBER;
        v_net_book_value1               NUMBER;

        -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
        ln_begin_spot_rate              NUMBER;
        ln_end_spot_rate                NUMBER;
        ln_begin_spot                   NUMBER;
        ln_begin_trans                  NUMBER;
        ln_end_spot                     NUMBER;
        ln_end_trans                    NUMBER;
        ln_net_trans                    NUMBER;

        ln_begin_grd_tot                NUMBER := 0;
        ln_begin_spot_grd_tot           NUMBER := 0;
        ln_begin_trans_grd_tot          NUMBER := 0;
        ln_addition_grd_tot             NUMBER := 0;

        ln_adjustment_grd_tot           NUMBER := 0;
        ln_retirement_grd_tot           NUMBER := 0;
        ln_revaluation_grd_tot          NUMBER := 0;
        ln_reclass_grd_tot              NUMBER := 0;
        ln_transfer_grd_tot             NUMBER := 0;

        ln_capitalization_grd_tot       NUMBER := 0;
        ln_end_grd_tot                  NUMBER := 0;
        ln_end_spot_grd_tot             NUMBER := 0;
        ln_end_trans_grd_tot            NUMBER := 0;
        ln_net_trans_grd_tot            NUMBER := 0;
        ln_net_book_val_grd_tot         NUMBER := 0;
        ln_impairment_tot               NUMBER := 0;

        ln_begin_cip_tot                NUMBER := 0;
        ln_begin_spot_cip_tot           NUMBER := 0;
        ln_begin_trans_cip_tot          NUMBER := 0;
        ln_addition_cip_tot             NUMBER := 0;
        ln_capitalization_cip_tot       NUMBER := 0;
        ln_end_cip_tot                  NUMBER := 0;
        ln_end_spot_cip_tot             NUMBER := 0;
        ln_end_trans_cip_tot            NUMBER := 0;
        ln_net_trans_cip_tot            NUMBER := 0;
        l_period_from                   VARCHAR2 (30);
        l_period_to                     VARCHAR2 (30);
        h_set_of_books_id               NUMBER;
        h_reporting_flag                VARCHAR2 (1);
        -- End changes by BT Technology Team v4.1 on 24-Dec-2014
        -- added by Showkath v5.0 on 07-Jul-2015 begin
        ln_conversion_rate              NUMBER;
        ln_addition                     NUMBER;
        ln_adjustment                   NUMBER;
        ln_retirement                   NUMBER;
        ln_capitalization               NUMBER;
        ln_revaluation                  NUMBER;
        ln_reclass                      NUMBER;
        ln_transfer                     NUMBER;
        l_testing                       VARCHAR2 (10);
        --added by Showkath v5.0 on 07-Jul-2015 end
        l_func_currency                 VARCHAR2 (10); -- added by showkath on 01-DEC-2015 to fix net fx translation issue
        l_category                      VARCHAR2 (30); -- added by showkath on 02-DEC-2015
        l_func_currency_spot            VARCHAR2 (10); -- added by showkath on 01-DEC-2015

        CURSOR c_net_book (p_book IN VARCHAR2)
        IS
            SELECT DISTINCT book, period_from, period_to,
                            asset_id
              FROM xxdo.xxd_fa_roll_fwd_rep_sum_t
             WHERE book = p_book;

        CURSOR c_header (cp_book IN VARCHAR2, p_currency IN VARCHAR2)
        IS
            SELECT asset_category, asset_cost_account, cost_center,
                   asset_category_attrib1 brand, asset_number, begin1 begin_year,
                   begin2 begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                          addition, adjustment,
                   retirement, capitalization, revaluation,
                   reclass, transfer, --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                      addition_nonf,
                   adjustment_nonf, retirement_nonf, capitalization_nonf,
                   revaluation_nonf, reclass_nonf, transfer_nonf,
                   --END changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                   end1 end_year, end2 end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                     report_type,
                   asset_id, impairment, net_book_value
              FROM (  SELECT DISTINCT -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
                                      --fc.segment1 || '-' || fc.segment2 asset_category,
                                      fc.segment1 || '.' || fc.segment2 || '.' || fc.segment3 asset_category, --NVL (rsv1.category_books_account, cc_adjust.segment3) asset_cost_account,
                                                                                                              NVL (rsv1.category_books_account, cc_adjust.segment6) asset_cost_account, --MAX (cc.segment2) cost_center,
                                                                                                                                                                                        cc.segment5 cost_center,
                                      --fc.attribute1 asset_category_attrib1,
                                      fc.segment3 asset_category_attrib1, -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                                                                          ad.asset_number, NVL (SUM (NVL (DECODE (rsv1.source_type_code, 'BEGIN', NVL (rsv1.amount, 0), NULL), 0)), 0) begin1,
                                      -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                      NVL2 (ln_begin_spot_rate, NVL (SUM (NVL (DECODE (rsv1.source_type_code, 'BEGIN', NVL (rsv1.amount_fun, 0), NULL), 0)), 0), NULL) begin2, -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                               SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'ADDITION', 'CIP ADDITION'), NVL (rsv1.amount, 0), NULL)) + DECODE (ad.asset_id, apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (ad.asset_id, cp_book), SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'ADDITION'), -NVL (rsv1.amount, 0), 0)), 0) addition, SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'ADJUSTMENT', 'CIP ADJUSTMENT'), NVL (rsv1.amount, 0), NULL)) adjustment,
                                      SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'RETIREMENT', 'CIP RETIREMENT'), NVL (rsv1.amount, 0), NULL)) retirement, DECODE (ad.asset_id, apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (ad.asset_id, cp_book), SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type,  'CIP COST', 'ADDITION',  'COST', 'ADDITION'), NVL (rsv1.amount, 0), NULL)), NULL) capitalization, SUM (DECODE (rsv1.source_type_code, 'REVALUATION', NVL (rsv1.amount, 0), NULL)) revaluation,
                                      SUM (DECODE (rsv1.source_type_code, 'RECLASS', NVL (rsv1.amount, 0), NULL)) reclass, SUM (DECODE (rsv1.source_type_code, 'TRANSFER', NVL (rsv1.amount, 0), NULL)) transfer, --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                                                                                                                                                                                                  SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'ADDITION', 'CIP ADDITION'), NVL (rsv1.amount_nonf, 0), NULL)) + DECODE (ad.asset_id, apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (ad.asset_id, cp_book), SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'ADDITION'), -NVL (rsv1.amount_nonf, 0), 0)), 0) addition_nonf,
                                      SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'ADJUSTMENT', 'CIP ADJUSTMENT'), NVL (rsv1.amount_nonf, 0), NULL)) adjustment_nonf, SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type, 'COST', 'RETIREMENT', 'CIP RETIREMENT'), NVL (rsv1.amount_nonf, 0), NULL)) retirement_nonf, DECODE (ad.asset_id, apps.xxd_fa_roll_fwd_pkg.xxd_fa_cap_asset (ad.asset_id, cp_book), SUM (DECODE (rsv1.source_type_code, DECODE (rsv1.report_type,  'CIP COST', 'ADDITION',  'COST', 'ADDITION'), NVL (rsv1.amount_nonf, 0), NULL)), NULL) capitalization_nonf,
                                      SUM (DECODE (rsv1.source_type_code, 'REVALUATION', NVL (rsv1.amount_nonf, 0), NULL)) revaluation_nonf, SUM (DECODE (rsv1.source_type_code, 'RECLASS', NVL (rsv1.amount_nonf, 0), NULL)) reclass_nonf, SUM (DECODE (rsv1.source_type_code, 'TRANSFER', NVL (rsv1.amount_nonf, 0), NULL)) transfer_nonf,
                                      --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                      SUM (NVL (DECODE (rsv1.source_type_code, 'END', NVL (rsv1.amount, 0), NULL), 0)) end1, -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                             NVL2 (ln_begin_spot_rate, SUM (NVL (DECODE (rsv1.source_type_code, 'END', NVL (rsv1.amount_fun, 0), NULL), 0)), NULL) end2, -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                                                                                                         rsv1.report_type,
                                      ad.asset_id, ad.parent_asset_id parent_asset, 0 impairment,
                                      0 net_book_value
                        FROM xxdo.xxd_fa_roll_fwd_sum_t rsv1, fa_additions ad, fa_categories fc,
                             fa_category_books fcb, gl_code_combinations_kfv cc, gl_code_combinations_kfv cc_cost,
                             gl_code_combinations cc_adjust
                       WHERE     1 = 1
                             AND rsv1.asset_id = ad.asset_id
                             AND ad.asset_category_id = fc.category_id
                             AND fc.category_id = fcb.category_id
                             AND fcb.book_type_code = cp_book
                             AND fcb.asset_cost_account_ccid =
                                 cc_cost.code_combination_id
                             AND cc_adjust.code_combination_id(+) =
                                 rsv1.adjustment_ccid
                             AND cc.code_combination_id =
                                 rsv1.distribution_ccid
                             AND DECODE (
                                     p_subtotal,
                                     'AC', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   --TO_CHAR (fc.category_id) --Commented by BT Technology Team v3.0
                                                   TO_CHAR (fc.segment1 /*|| '.'
                                                                        || fc.segment2
                                                                        || '.'
                                                                        || fc.segment3*/
                                                                       ) --Added by BT Technology Team v3.0
                                                                        ),
                                     'ACC', DECODE (
                                                p_subtotal_value,
                                                NULL, TO_CHAR (1),
                                                NVL (
                                                    TO_CHAR (
                                                        rsv1.category_books_account),
                                                    --TO_CHAR (cc_adjust.segment3) --Commented by BT Technology Team v3.0
                                                    TO_CHAR (
                                                        cc_adjust.segment6) --Added by BT Technology Team v3.0
                                                                           )),
                                     'CC', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   --TO_CHAR (cc.segment2) --Commented by BT Technology Team v3.0
                                                   TO_CHAR (cc.segment5) --Added by BT Technology Team v3.0
                                                                        ),
                                     -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
                                     /*'PA', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   TO_CHAR (ad.parent_asset_id))) = */
                                     'BD', DECODE (p_subtotal_value,
                                                   NULL, TO_CHAR (1),
                                                   TO_CHAR (fc.segment3))) =
                                 -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                                 DECODE (p_subtotal_value,
                                         NULL, TO_CHAR (1),
                                         p_subtotal_value)
                    GROUP BY -- Start changes by BT Technology Team v3.0 on 21-Oct-2014
 /*fc.segment1 || '-' || fc.segment2,
 NVL (rsv1.category_books_account,
      cc_adjust.segment3),
 fc.attribute1,*/
                    fc.segment1 || '.' || fc.segment2 || '.' || fc.segment3, NVL (rsv1.category_books_account, cc_adjust.segment6), cc.segment5,
                    fc.segment3, -- End changes by BT Technology Team v3.0 on 21-Oct-2014
                                 rsv1.report_type, ad.asset_id,
                    ad.asset_number, ad.parent_asset_id
                    ORDER BY DECODE (p_subtotal,  'AC', asset_category,  'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset        --Commented by BT Technology Team v3.0
                                                                                                                         'BD', asset_category_attrib1 --Added by BT Technology Team v3.0
                                                                                                                                                     ), ad.asset_number);

        CURSOR c_dis_sum IS
            SELECT DISTINCT
                   DECODE (p_subtotal,  -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                        --'AC', asset_category,
                                        'AC', SUBSTR (asset_category, 1, INSTR (asset_category, '.') - 1),  -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                            'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset --Commented by BT Technology Team v3.0
                                                                                                                                                            'BD', brand --Added by BT Technology Team v3.0
                                                                                                                                                                       ) info
              FROM xxdo.xxd_fa_roll_fwd_rep_sum_t;

        CURSOR c_dis1_sum (c_1 VARCHAR2)
        IS
              SELECT DECODE (p_subtotal,  'AC', 'Asset Category',  'ACC', 'Cost Account',  'CC', 'Cost Center',  --'PA', 'Parent Asset' --Commented by BT Technology Team v3.0
                                                                                                                 'BD', 'Brand' --Added by BT Technology Team v3.0
                                                                                                                              ) info1, DECODE (p_subtotal,  -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                            --'AC', asset_category,
                                                                                                                                                            'AC', SUBSTR (asset_category, 1, INSTR (asset_category, '.') - 1),  -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                                                                                                                                                'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset --Commented by BT Technology Team v3.0
                                                                                                                                                                                                                                                                                'BD', brand --Added by BT Technology Team v3.0
                                                                                                                                                                                                                                                                                           ) info, SUM (begin_year) begin_year,
                     SUM (begin_year_fun) begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                          SUM (addition) addition, SUM (adjustment) adjustment,
                     SUM (retirement) retirement, SUM (capitalization) capitalization, SUM (revaluation) revaluation,
                     SUM (reclass) reclass, SUM (transfer) transfer, --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                                                     SUM (addition_nonf) addition_nonf,
                     SUM (adjustment_nonf) adjustment_nonf, SUM (retirement_nonf) retirement_nonf, SUM (capitalization_nonf) capitalization_nonf,
                     SUM (revaluation_nonf) revaluation_nonf, SUM (reclass_nonf) reclass_nonf, SUM (transfer_nonf) transfer_nonf,
                     --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                     SUM (end_year) end_year, SUM (end_year_fun) end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                               SUM (impairment) impairment,
                     SUM (net_book_value) net_book_value
                FROM xxdo.xxd_fa_roll_fwd_rep_sum_t
               WHERE DECODE (
                         p_subtotal,
                         -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                         --'AC', asset_category,
                         'AC', SUBSTR (asset_category,
                                       1,
                                       INSTR (asset_category, '.') - 1),
                         -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                         'ACC', asset_cost_account,
                         'CC', cost_center,
                         --'PA', parent_asset --Commented by BT Technology Team v3.0
                         'BD', brand        --Added by BT Technology Team v3.0
                                    ) =
                     c_1
            GROUP BY DECODE (p_subtotal,  -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                                          --'AC', asset_category,
                                          'AC', SUBSTR (asset_category, 1, INSTR (asset_category, '.') - 1),  -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                                                                                                              'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset --Commented by BT Technology Team v3.0
                                                                                                                                                              'BD', brand --Added by BT Technology Team v3.0
                                                                                                                                                                         );

        CURSOR c_output (c_1 VARCHAR2)
        IS
              SELECT book, period_from, period_to,
                     currency, asset_category, cost_center,
                     asset_cost_account, brand, parent_asset,
                     SUM (begin_year) begin_year, SUM (begin_year_fun) begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                       SUM (addition) addition,
                     SUM (adjustment) adjustment, SUM (retirement) retirement, SUM (capitalization) capitalization,
                     SUM (revaluation) revaluation, SUM (reclass) reclass, SUM (transfer) transfer,
                     --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                     SUM (addition_nonf) addition_nonf, SUM (adjustment_nonf) adjustment_nonf, SUM (retirement_nonf) retirement_nonf,
                     SUM (capitalization_nonf) capitalization_nonf, SUM (revaluation_nonf) revaluation_nonf, SUM (reclass_nonf) reclass_nonf,
                     SUM (transfer_nonf) transfer_nonf, --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                                        SUM (end_year) end_year, SUM (end_year_fun) end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                     SUM (impairment) impairment, SUM (net_book_value) net_book_value
                FROM xxdo.xxd_fa_roll_fwd_rep_sum_t
               WHERE DECODE (
                         p_subtotal,
                         -- Start changes by BT Technology Team v4.1 on 18-Dec-2014
                         --'AC', asset_category,
                         'AC', SUBSTR (asset_category,
                                       1,
                                       INSTR (asset_category, '.') - 1),
                         -- End changes by BT Technology Team v4.1 on 18-Dec-2014
                         'ACC', asset_cost_account,
                         'CC', cost_center,
                         --'PA', parent_asset --Commented by BT Technology Team v3.0
                         'BD', brand        --Added by BT Technology Team v3.0
                                    ) =
                     c_1
            GROUP BY book, period_from, period_to,
                     currency, asset_category, cost_center,
                     asset_cost_account, brand, parent_asset
            ORDER BY DECODE (p_subtotal,  'AC', asset_category,  'ACC', asset_cost_account,  'CC', cost_center,  --'PA', parent_asset --Commented by BT Technology Team v3.0
                                                                                                                 'BD', brand --Added by BT Technology Team v3.0
                                                                                                                            );

        CURSOR c_total IS
            SELECT SUM (begin_year) begin_year_tot, SUM (begin_year_fun) begin_year_fun_tot, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                             SUM (addition) addition_tot,
                   SUM (adjustment) adjustment_tot, SUM (retirement) retirement_tot, SUM (capitalization) capitalization_tot,
                   SUM (revaluation) revaluation_tot, SUM (reclass) reclass_tot, SUM (transfer) transfer_tot,
                   SUM (end_year) end_year_tot, --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                                SUM (addition_nonf) addition_tot_nonf, SUM (adjustment_nonf) adjustment_tot_nonf,
                   SUM (retirement_nonf) retirement_tot_nonf, SUM (capitalization_nonf) capitalization_tot_nonf, SUM (revaluation_nonf) revaluation_tot_nonf,
                   SUM (reclass_nonf) reclass_tot_nonf, SUM (transfer_nonf) transfer_tot_nonf, --end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015-
                                                                                               SUM (end_year_fun) end_year_fun_tot, --Added by BT Technology Team v4.1 on 24-Dec-2014
                   SUM (impairment) impairment_tot, SUM (net_book_value) net_book_value_tot
              FROM xxdo.xxd_fa_roll_fwd_rep_sum_t;
    BEGIN
        --EXECUTE IMMEDIATE 'Truncate table xxdo.XXD_FA_ROLL_FWD_REP_SUM_T';

        print_log_prc ('p_book :' || p_book);
        print_log_prc ('p_currency :' || p_currency);
        print_log_prc ('p_from_period :' || p_from_period);
        print_log_prc ('p_to_period :' || p_to_period);
        print_log_prc ('p_subtotal :' || p_subtotal);
        print_log_prc ('p_subtotal_value :' || p_subtotal_value);


        -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
        --EXECUTE IMMEDIATE 'Truncate table xxdo.XXD_FA_ROLL_FWD_SUM_T';

        --Moved here from below
        BEGIN
            SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
              INTO v_report_date
              FROM sys.DUAL;
        END;

        apps.fnd_file.put_line (apps.fnd_file.output, 'DECKERS CORPORATION');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
            --'Report Name :Fixed Assets RollForward Summary - Deckers');
            'Report Name :Deckers FA Roll Forward Summary Cost Report'); --Commented by showkath on 12/01 as per requirement
        --'Report Name :FA Roll Forward Summary Cost Report');    --Added by showkath on 12/01 as per requirement
        -- End changes by BT Technology Team v4.1 on 26-Dec-2014
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Report Date - :' || v_report_date);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Starting Period is: ' || p_from_period);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Ending Period is: ' || p_to_period);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Subtotal By : ' || p_subtotal);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Subtotal By Value: ' || p_subtotal_value);
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, 'Fixed Asset Section');

        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Book'
            || CHR (9)
            || 'Starting Period'
            || CHR (9)
            || 'Ending Period'
            || CHR (9)
            || 'Currency'
            || CHR (9)
            || 'Asset Category'
            || CHR (9)
            || 'Asset Cost Account'
            || CHR (9)
            || 'Depreciation Cost Center'                --'Asset Cost Center'
            || CHR (9)
            || 'Asset Brand'
            || CHR (9)
            --|| 'Begin Balance' --changes by Showkath v5.0 on 15-Jul-2015
            --|| CHR (9)
            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
            || 'Begin Balance in <Functional Currency>'
            || CHR (9)
            || 'Begin Balance <'
            || p_currency
            || '> at Spot Rate'
            || CHR (9)
            --|| 'Begin FX Translation' --changes by Showkath v5.0 on 15-Jul-2015
            --|| CHR (9)
            -- End changes by BT Technology Team v4.1 on 24-Dec-2014
            || 'Additions'
            || CHR (9)
            || 'Adjustments'
            || CHR (9)
            || 'Retirements'
            || CHR (9)
            || 'Capitalization'
            || CHR (9)
            || 'Revaluation'
            || CHR (9)
            || 'Reclasses'
            || CHR (9)
            || 'Transfers'
            || CHR (9)
            --|| 'Ending Balance' --changes by Showkath v5.0 on 15-Jul-2015
            --|| CHR (9)
            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
            || 'End Balance in <Functional Currency>'
            || CHR (9)
            || 'End Balance <'
            || p_currency
            || '> at Spot Rate'
            || CHR (9)
            --|| 'End FX Translation'--changes by Showkath v5.0 on 15-Jul-2015
            --|| CHR (9)
            || 'Net FX Translation'
            || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                      --|| 'Impairment' --changes by Showkath v5.0 on 15-Jul-2015
                      --|| CHR (9)
                      --|| 'Net Book Value'                                      -- || CHR(9)
                      -- || 'Asset'
                      );

        FOR m
            IN (SELECT book_type_code
                  FROM fa_book_controls
                 WHERE     book_type_code = NVL (p_book, book_type_code)
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE)
        LOOP
            BEGIN
                SELECT period_name
                  INTO l_period_from
                  FROM fa_deprn_periods
                 WHERE     book_type_code = m.book_type_code
                       AND period_name = p_from_period;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_period_from   := NULL;
            END;

            BEGIN
                SELECT period_name
                  INTO l_period_to
                  FROM fa_deprn_periods
                 WHERE     book_type_code = m.book_type_code
                       AND period_name = p_to_period;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_period_to   := NULL;
            END;

            --Begin changes by showkath to fix conv_rate issue(4) on 06-DEC-2015--
            BEGIN
                SELECT currency_code
                  INTO g_from_currency
                  FROM gl_sets_of_books gsob, fa_book_controls fbc
                 WHERE     gsob.set_of_books_id = fbc.set_of_books_id
                       AND fbc.book_type_code = m.book_type_code
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            --End changes by showkath to fix conv_rate issue(4) on 06-DEC-2015--

            IF (l_period_from IS NOT NULL AND l_period_to IS NOT NULL)
            THEN
                -- End changes by BT Technology Team v4.1 on 26-Dec-2014

                -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                EXECUTE IMMEDIATE 'Truncate table xxdo.XXD_FA_ROLL_FWD_REP_SUM_T';

                -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                --g_set_of_books_id := xxd_fa_return_sob_id_fnc (p_book, p_currency);
                g_set_of_books_id   :=
                    xxd_fa_return_sob_id_fnc (m.book_type_code, p_currency);

                -- Start changes by BT Technology Team v4.2 on 26-Dec-2014
                BEGIN
                    h_set_of_books_id   :=
                        xxd_fa_set_client_info_fnc (g_set_of_books_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        h_set_of_books_id   := NULL;
                END;

                IF (h_set_of_books_id IS NOT NULL)
                THEN
                    IF NOT fa_cache_pkg.fazcsob (
                               x_set_of_books_id     => h_set_of_books_id,
                               x_mrc_sob_type_code   => h_reporting_flag)
                    THEN
                        RAISE fnd_api.g_exc_unexpected_error;
                    END IF;
                ELSE
                    h_reporting_flag   := 'P';
                END IF;

                -- End changes by BT Technology Team v4.2 on 26-Dec-2014

                print_log_prc ('g_set_of_books_id :' || g_set_of_books_id);

                /*run FA_RSVLDG_PROC*/
                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                --xxd_fa_roll_fwd_pkg.xxd_fa_rsvldg_proc_sum (p_book, p_to_period);
                xxd_fa_roll_fwd_pkg.xxd_fa_rsvldg_proc_sum (m.book_type_code,
                                                            l_period_to); --p_to_period);

                --Commented and moved above for v4.1 on 26-Dec-2014
                /*BEGIN
                   SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
                     INTO v_report_date
                     FROM sys.DUAL;
                END;*/

                -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                --Moved the code outside m loop
                EXECUTE IMMEDIATE 'Truncate table xxdo.XXD_FA_ROLL_FWD_SUM_T';

                -- End changes by BT Technology Team v4.1 on 26-Dec-2014

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                insert_info_sum (book => m.book_type_code,           --p_book,
                                                           start_period_name => l_period_from, --p_from_period,
                                                                                               end_period_name => l_period_to
                                 ,                              --p_to_period,
                                   report_type => 'CIP COST', adj_mode => NULL);

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                insert_info_sum (book => m.book_type_code,           --p_book,
                                                           start_period_name => l_period_from, --p_from_period,
                                                                                               end_period_name => l_period_to
                                 ,                              --p_to_period,
                                   report_type => 'COST', adj_mode => NULL);

                --START changes by showkath on 12/01/2015 to fix net fx translation requirement
                BEGIN
                    SELECT currency_code
                      INTO l_func_currency_spot
                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                     WHERE     gsob.set_of_books_id = fbc.set_of_books_id
                           AND fbc.book_type_code = m.book_type_code
                           AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_func_currency   := NULL;
                END;

                g_from_currency   := l_func_currency_spot;

                --END changes by showkath on 12/01/2015 to fix net fx translation requirement

                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                --IF (p_currency = 'USD')--changes by showkath on 12/01/2015
                IF (p_currency <> l_func_currency_spot)
                THEN
                    BEGIN
                        SELECT conversion_rate
                          INTO ln_begin_spot_rate
                          FROM gl_daily_rates
                         WHERE     from_currency =
                                   (SELECT currency_code
                                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                                     WHERE     gsob.set_of_books_id =
                                               fbc.set_of_books_id
                                           AND fbc.book_type_code =
                                               m.book_type_code
                                           AND NVL (date_ineffective,
                                                    SYSDATE + 1) >
                                               SYSDATE)
                               AND to_currency = 'USD'
                               --AND TRUNC (conversion_date) = TRUNC (TO_DATE (p_from_period, 'MON-YY') - 1)
                               AND TRUNC (conversion_date) =
                                   (SELECT TRUNC (calendar_period_open_date) - 1
                                      FROM fa_deprn_periods
                                     WHERE     period_name = p_from_period
                                           AND book_type_code =
                                               m.book_type_code)
                               AND conversion_type = 'Spot';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_begin_spot_rate   := NULL;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to derive spot rate for the perod'
                                || ''
                                || p_from_period);
                            retcode              := 2; -- added to complete the program with error if spot rate is not defined
                            EXIT;
                    END;

                    BEGIN
                        SELECT conversion_rate
                          INTO ln_end_spot_rate
                          FROM gl_daily_rates
                         WHERE     from_currency =
                                   (SELECT currency_code
                                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                                     WHERE     gsob.set_of_books_id =
                                               fbc.set_of_books_id
                                           AND fbc.book_type_code =
                                               m.book_type_code
                                           AND NVL (date_ineffective,
                                                    SYSDATE + 1) >
                                               SYSDATE)
                               AND to_currency = 'USD'
                               --AND TRUNC (conversion_date) = TRUNC (TO_DATE (p_to_period, 'MON-YY') - 1)
                               AND TRUNC (conversion_date) =
                                   (SELECT TRUNC (calendar_period_close_date)
                                      FROM fa_deprn_periods
                                     WHERE     period_name = p_to_period
                                           AND book_type_code =
                                               m.book_type_code)
                               AND conversion_type = 'Spot';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            ln_end_spot_rate   := NULL;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Failed to derive spot rate for the perod'
                                || ''
                                || p_to_period);
                            retcode            := 2; -- added to complete the program with warning if spot rate is not defined
                            EXIT;
                    END;
                ELSE
                    ln_begin_spot_rate   := NULL;
                    ln_end_spot_rate     := NULL;
                END IF;

                print_log_prc ('Begin Spot Rate :' || ln_begin_spot_rate);
                print_log_prc ('End Spot Rate :' || ln_end_spot_rate);
                v_null_count      := 0;

                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                --FOR crec IN c_header (cp_book => p_book, p_currency => p_currency)
                FOR crec
                    IN c_header (cp_book      => m.book_type_code,
                                 p_currency   => p_currency)
                LOOP
                    BEGIN
                        v_cost   := 0;

                        SELECT fbbc.cost
                          INTO v_cost
                          FROM fa_books fb, fa_books_book_controls_v fbbc
                         WHERE     fb.asset_id = crec.asset_id
                               --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                               AND fb.book_type_code = m.book_type_code --p_book
                               AND fb.date_ineffective IS NULL
                               AND fb.transaction_header_id_in =
                                   fbbc.transaction_header_id_in;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            /*fnd_file.put_line (
                               fnd_file.LOG,
                                  'Exception in Summary Cost is: for AssetID: '
                               || crec.asset_id
                               || ' is :'
                               || SUBSTR (SQLERRM, 1, 200));*/
                            v_cost   := 0;
                    END;

                    BEGIN
                        v_dep_reserve   := 0;

                        SELECT apps.xxd_fa_roll_fwd_pkg.xxd_fa_depreciation_cost (crec.asset_id, --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                                                                                                 m.book_type_code --p_book
                                                                                                                 )
                          INTO v_dep_reserve
                          FROM DUAL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Exception in Summary Accumulated Depri is: '
                                || SUBSTR (SQLERRM, 1, 200));
                            v_dep_reserve   := 0;
                    END;

                    INSERT INTO xxdo.xxd_fa_roll_fwd_rep_sum_t (
                                    book,
                                    period_from,
                                    period_to,
                                    currency,
                                    asset_category,
                                    asset_cost_account,
                                    brand,
                                    cost_center,
                                    begin_year,
                                    begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                    addition,
                                    adjustment,
                                    retirement,
                                    capitalization,
                                    revaluation,
                                    reclass,
                                    transfer,
                                    -- begin added code to fix conv_rate fix by showkath on 06_DEC
                                    addition_nonf,
                                    adjustment_nonf,
                                    retirement_nonf,
                                    capitalization_nonf,
                                    revaluation_nonf,
                                    reclass_nonf,
                                    transfer_nonf,
                                    ---- end added code to fix conv_rate fix by showkath on 06_DEC
                                    end_year,
                                    end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                    report_type,
                                    asset_id,
                                    impairment,
                                    net_book_value)
                         --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                         VALUES (m.book_type_code,                   --p_book,
                                                   p_from_period, p_to_period, p_currency, crec.asset_category, crec.asset_cost_account, crec.brand, crec.cost_center, crec.begin_year, crec.begin_year, --crec.begin_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                                                         crec.addition, crec.adjustment, crec.retirement, crec.capitalization, crec.revaluation, crec.reclass, crec.transfer, -- begin added code to fix conv_rate fix by showkath on 06_DEC
                                                                                                                                                                                                                                                                                                                              crec.addition_nonf, crec.adjustment_nonf, crec.retirement_nonf, crec.capitalization_nonf, crec.revaluation_nonf, crec.reclass_nonf, crec.transfer_nonf, -- end added code to fix conv_rate fix by showkath on 06_DEC
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      crec.end_year, crec.end_year, --crec.end_year_fun, --Added by BT Technology Team v4.1 on 24-Dec-2014
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    crec.report_type
                                 , crec.asset_id, 0, 0);

                    COMMIT;
                --apps.XXD_FA_ROLL_FWD_PKG.xxd_fa_net_book_value_sum(crec.asset_id,p_book);
                END LOOP;


                --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                FOR net_book IN c_net_book (m.book_type_code)        --p_book)
                LOOP
                    apps.xxd_fa_roll_fwd_pkg.xxd_fa_update_impairment_sum (
                        net_book.asset_id,
                        --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                        m.book_type_code                              --p_book
                                        );
                    apps.xxd_fa_roll_fwd_pkg.xxd_fa_net_book_value_sum (
                        net_book.asset_id,
                        --Replaced p_book with m.book_type_code for v4.1 on 26-Dec-2014
                        m.book_type_code                              --p_book
                                        );
                END LOOP;


                FOR k IN c_dis_sum
                LOOP
                    FOR j IN c_dis1_sum (k.info)
                    LOOP
                        BEGIN
                            FOR i IN c_output (k.info)
                            LOOP
                                vn_adj_cost         := NULL;
                                vn_deprn_reserve    := NULL;
                                v_net_book_value    := NULL;
                                v_net_book_value1   := 0;

                                BEGIN
                                    SELECT DISTINCT period_name
                                      INTO v_period_from
                                      FROM fa_deprn_periods
                                     WHERE period_name = i.period_from;
                                END;

                                BEGIN
                                    SELECT DISTINCT period_name
                                      INTO v_period_to
                                      FROM fa_deprn_periods
                                     WHERE period_name = i.period_to;
                                END;

                                --START changes by showkath on 12/01/2015 to fix net fx translation requirement
                                BEGIN
                                    SELECT currency_code
                                      INTO l_func_currency
                                      FROM gl_sets_of_books gsob, fa_book_controls fbc
                                     WHERE     gsob.set_of_books_id =
                                               fbc.set_of_books_id
                                           AND fbc.book_type_code =
                                               m.book_type_code
                                           AND NVL (date_ineffective,
                                                    SYSDATE + 1) >
                                               SYSDATE;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        l_func_currency   := NULL;
                                END;

                                --END changes by showkath on 12/01/2015 to fix net fx translation requirement

                                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                /*IF (h_reporting_flag = 'P')
                                THEN
                                   ln_begin_spot := NULL;
                                   ln_begin_trans := NULL;
                                   ln_end_spot := NULL;
                                   ln_end_trans := NULL;
                                   ln_net_trans := NULL;
                                ELSE*/
                                --comented by showkath to display below values for h_reporting_flag = P 11/18/2015
                                BEGIN
                                    IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                                    THEN
                                        ln_begin_spot   :=
                                              NVL (i.begin_year_fun, 0)
                                            * NVL (ln_begin_spot_rate, 1);
                                        ln_end_spot   :=
                                              NVL (i.end_year_fun, 0)
                                            * NVL (ln_end_spot_rate, 1);
                                    ELSE
                                        ln_begin_spot   :=
                                              NVL (i.begin_year_fun, 0)
                                            * ln_begin_spot_rate;
                                        ln_begin_trans   :=
                                            ln_begin_spot - i.begin_year;
                                        ln_end_spot   :=
                                              NVL (i.end_year_fun, 0)
                                            * ln_end_spot_rate;
                                        ln_end_trans   :=
                                            ln_end_spot - i.end_year;
                                    --ln_net_trans := ln_end_trans - ln_begin_trans; -- commented by showkath on 12/01/2015 to fix net fx translation requirement
                                    END IF;
                                END;

                                -- END IF;

                                -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                --End Changes by Showkath v5.0 on 07-Jul-2015
                                --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                                IF (p_currency <> NVL (l_func_currency, 'X'))
                                THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                                    BEGIN
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'book_type_code:' || m.book_type_code);

                                        SELECT DISTINCT conversion_rate
                                          INTO ln_conversion_rate
                                          FROM apps.gl_daily_rates
                                         WHERE     from_currency =
                                                   (SELECT currency_code
                                                      FROM gl_sets_of_books gsob, FA_BOOK_CONTROLS fbc
                                                     WHERE     GSOB.SET_OF_BOOKS_ID =
                                                               fbc.SET_OF_BOOKS_ID
                                                           AND fbc.BOOK_TYPE_CODE =
                                                               m.book_type_code
                                                           AND NVL (
                                                                   DATE_INEFFECTIVE,
                                                                     SYSDATE
                                                                   + 1) >
                                                               SYSDATE)
                                               AND to_currency = 'USD'
                                               AND conversion_type =
                                                   'Corporate'
                                               AND TO_CHAR (conversion_date,
                                                            'MON-YY') =
                                                   (SELECT TO_CHAR (calendar_period_open_date, 'MON-YY')
                                                      FROM fa_deprn_periods fdp
                                                     WHERE     period_name =
                                                               p_from_period
                                                           AND book_type_code =
                                                               m.book_type_code);

                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                               'Transactional Date exchange rate:'
                                            || ln_conversion_rate);
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            ln_conversion_rate   := 1;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'In exception of Transactional Date exchange rate:'
                                                || SQLERRM);
                                    END;

                                    ln_addition         := i.addition_nonf;
                                    ln_adjustment       := i.adjustment_nonf;
                                    ln_retirement       := i.retirement_nonf;
                                    ln_capitalization   :=
                                        i.capitalization_nonf;
                                    ln_revaluation      := i.revaluation_nonf;
                                    ln_reclass          := i.reclass_nonf;
                                    ln_transfer         := i.transfer_nonf;
                                    -- end changes by showkath to fix conv_rate issue(4) on 06-DEC-2015
                                    ln_net_trans        := NULL;
                                    ln_net_trans        :=
                                          NVL (ln_end_spot, 0)
                                        - (NVL (ln_begin_spot, 0) -- added by showkath to fix net fx translation issue on 06-DEC-2015
                                                                  /*NVL ( (i.begin_year * ln_conversion_rate),
                                                                         0)*/
                                                                  -- commented by showkath to fix net fx translation issue on 06-DEC-2015
                                                                  + NVL (ln_addition, 0) + NVL (ln_adjustment, 0) + NVL (ln_retirement, 0) + NVL (ln_capitalization, 0) + NVL (ln_revaluation, 0) + NVL (ln_reclass, 0) + NVL (ln_transfer, 0));
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Program is running with USD Currency-Values with Conversion Rate');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        '------------------------------------------');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'begin Balance:' || i.begin_year);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Additions:' || ln_addition);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Adjustments:' || ln_adjustment);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Retirement:' || ln_retirement);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Captalization:' || ln_capitalization);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Revaluation:' || ln_revaluation);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Reclass:' || ln_reclass);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Transfer:' || ln_transfer);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Net FX Transaction:' || ln_net_trans);
                                ELSE
                                    ln_addition         := i.addition;
                                    ln_adjustment       := i.adjustment;
                                    ln_retirement       := i.retirement;
                                    ln_capitalization   := i.capitalization;
                                    ln_revaluation      := i.revaluation;
                                    ln_reclass          := i.reclass;
                                    ln_transfer         := i.transfer;
                                    ln_net_trans        := NULL;
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Program is running with Non USD Currency-Values without Conversion Rate');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        '------------------------------------------');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Additions:' || ln_addition);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Adjustments:' || ln_adjustment);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Retirement:' || ln_retirement);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Captalization:' || ln_capitalization);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Revaluation:' || ln_revaluation);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Reclass:' || ln_reclass);
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Transfer:' || ln_transfer);
                                END IF;

                                --End Changes by Showkath v5.0 on 07-Jul-2015
                                apps.fnd_file.put_line (
                                    apps.fnd_file.output,
                                       i.book
                                    || CHR (9)
                                    || TO_CHAR (
                                           TO_DATE (v_period_from, 'MON-RR'),
                                           'MON-RRRR') --TO_CHAR(v_period_from)
                                    || CHR (9)
                                    || TO_CHAR (
                                           TO_DATE (v_period_to, 'MON-RRRR'),
                                           'MON-RRRR')  --TO_CHAR(v_period_to)
                                    || CHR (9)
                                    || i.currency
                                    || CHR (9)
                                    || i.asset_category
                                    || CHR (9)
                                    || i.asset_cost_account
                                    || CHR (9)
                                    || i.cost_center
                                    || CHR (9)
                                    || i.brand
                                    || CHR (9)
                                    --|| to_char(i.begin_year, 'FM999G999G999G999D99') -  commented by Showkath v5.0 on 07-Jul-2015
                                    --|| CHR (9)
                                    -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                    || TO_CHAR (i.begin_year_fun,
                                                'FM999G999G999G999D99')
                                    || CHR (9)
                                    || TO_CHAR (ln_begin_spot,
                                                'FM999G999G999G999D99')
                                    || CHR (9)
                                    || TO_CHAR (ln_addition,
                                                'FM999G999G999G999D99') --v_addition_total--i.addition
                                    || CHR (9)
                                    || TO_CHAR ((NVL (ln_adjustment, 0)),
                                                'FM999G999G999G999D99') --v_adjustment_total--i.adjustment
                                    || CHR (9)
                                    || TO_CHAR (ln_retirement,
                                                'FM999G999G999G999D99') --v_retirement_total--i.retirement
                                    || CHR (9)
                                    || TO_CHAR (ln_capitalization,
                                                'FM999G999G999G999D99')
                                    || CHR (9)
                                    || TO_CHAR (ln_revaluation,
                                                'FM999G999G999G999D99') --v_revaluation_total--i.revaluation
                                    || CHR (9)
                                    || TO_CHAR (ln_reclass,
                                                'FM999G999G999G999D99') --v_reclass_total--i.reclass
                                    || CHR (9)
                                    || TO_CHAR (ln_transfer,
                                                'FM999G999G999G999D99') --v_transfer_total--i.transfer
                                    || CHR (9)
                                    --|| to_char(i.end_year, 'FM999G999G999G999D99')
                                    --|| CHR (9)
                                    -- End changes by Showkath v5.0 on 07-Jul-2015
                                    -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                    || TO_CHAR (i.end_year_fun,
                                                'FM999G999G999G999D99')
                                    || CHR (9)
                                    || TO_CHAR (ln_end_spot,
                                                'FM999G999G999G999D99')
                                    || CHR (9)
                                    --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --  changes by Showkath v5.0 on 07-Jul-2015
                                    --|| CHR (9)
                                    || TO_CHAR (ln_net_trans,
                                                'FM999G999G999G999D99')
                                    || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                              --|| to_char(i.impairment, 'FM999G999G999G999D99') -- changes by Showkath v5.0 on 07-Jul-2015
                                              --|| CHR (9)
                                              --|| to_char(i.net_book_value, 'FM999G999G999G999D99')                    -- || CHR(9)
                                              -- || i.asset_id
                                              );
                            --v_net_book_value1 := v_net_book_value1+v_net_book_value;
                            END LOOP;

                            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                            /* IF (h_reporting_flag = 'P')
                             THEN
                                ln_begin_spot := NULL;
                                ln_begin_trans := NULL;
                                ln_end_spot := NULL;
                                ln_end_trans := NULL;
                                ln_net_trans := NULL;
                             ELSE*/
                            BEGIN
                                IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                                THEN
                                    ln_begin_spot   :=
                                          NVL (j.begin_year_fun, 0)
                                        * NVL (ln_begin_spot_rate, 1);
                                    ln_end_spot   :=
                                          NVL (j.end_year_fun, 0)
                                        * NVL (ln_end_spot_rate, 1);
                                ELSE
                                    ln_begin_spot   :=
                                          NVL (j.begin_year_fun, 0)
                                        * ln_begin_spot_rate;
                                    ln_begin_trans   :=
                                        ln_begin_spot - j.begin_year;
                                    ln_end_spot   :=
                                          NVL (j.end_year_fun, 0)
                                        * ln_end_spot_rate;
                                    ln_end_trans   :=
                                        ln_end_spot - j.end_year;
                                --ln_net_trans := ln_end_trans - ln_begin_trans; -- commented by showkath on 01-DEC-2015 to fix net fx translation
                                END IF;
                            END;

                            -- END IF;

                            -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                            --Begin Changes by Showkath v5.0 on 07-Jul-2015
                            --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                            IF (p_currency <> NVL (l_func_currency, 'X'))
                            THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Transactional Date exchange rate:'
                                    || ln_conversion_rate);
                                ln_addition         := NULL;
                                ln_adjustment       := NULL;
                                ln_retirement       := NULL;
                                ln_capitalization   := NULL;
                                ln_revaluation      := NULL;
                                ln_reclass          := NULL;
                                ln_transfer         := NULL;
                                ln_addition         := j.addition_nonf;
                                ln_adjustment       := j.adjustment_nonf;
                                ln_retirement       := j.retirement_nonf;
                                ln_capitalization   := j.capitalization_nonf;
                                ln_revaluation      := j.revaluation_nonf;
                                ln_reclass          := j.reclass_nonf;
                                ln_transfer         := j.transfer_nonf;
                                --added by showkath on 01-DEC-2015 to fix net fx translation
                                ln_net_trans        := NULL;
                                ln_net_trans        :=
                                      NVL (ln_end_spot, 0)
                                    - ( -- NVL ( (j.begin_year * ln_conversion_rate), 0) -- commented by showkath on 06-DEC-2015 to fix conv rate issue
                                       NVL (ln_begin_spot, 0) -- added by showkath on 06-DEC-2015 to fix conv rate issue
                                                              + NVL (ln_addition, 0) + NVL (ln_adjustment, 0) + NVL (ln_retirement, 0) + NVL (ln_capitalization, 0) + NVL (ln_revaluation, 0) + NVL (ln_reclass, 0) + NVL (ln_transfer, 0));
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Program is running with USD Currency-Values with Conversion Rate');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '------------------------------------------');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Additions:' || ln_addition);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Adjustments:' || ln_adjustment);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Retirement:' || ln_retirement);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Captalization:' || ln_capitalization);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Revaluation:' || ln_revaluation);
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Reclass:' || ln_reclass);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Transfer:' || ln_transfer);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Net FX Transaction:' || ln_net_trans);
                            ELSE
                                ln_addition         := NULL;
                                ln_adjustment       := NULL;
                                ln_retirement       := NULL;
                                ln_capitalization   := NULL;
                                ln_revaluation      := NULL;
                                ln_reclass          := NULL;
                                ln_transfer         := NULL;
                                ln_addition         := j.addition;
                                ln_adjustment       := j.adjustment;
                                ln_retirement       := j.retirement;
                                ln_capitalization   := j.capitalization;
                                ln_revaluation      := j.revaluation;
                                ln_reclass          := j.reclass;
                                ln_transfer         := j.transfer;
                                ln_net_trans        := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Program is running with Non USD Currency-Values without Conversion Rate');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '------------------------------------------');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Additions:' || ln_addition);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Adjustments:' || ln_adjustment);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Retirement:' || ln_retirement);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Captalization:' || ln_capitalization);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Revaluation:' || ln_revaluation);
                                fnd_file.put_line (fnd_file.LOG,
                                                   'Reclass:' || ln_reclass);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Transfer:' || ln_transfer);
                            END IF;

                            --End Changes by Showkath v5.0 on 07-Jul-2015
                            apps.fnd_file.put_line (
                                apps.fnd_file.output,
                                   NULL
                                || CHR (9)
                                || NULL
                                || CHR (9)
                                || NULL
                                || CHR (9)
                                || NULL
                                || CHR (9)
                                || NULL                     --i.asset_category
                                || CHR (9)
                                || NULL                     --i.asset_category
                                || CHR (9)
                                || 'Subtotal by : '
                                || j.info1                              --NULL
                                || CHR (9)
                                || j.info                               --NULL
                                || CHR (9)
                                --|| to_char(j.begin_year, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                                --|| CHR (9)
                                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                || TO_CHAR (j.begin_year_fun,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_begin_spot,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_addition,
                                            'FM999G999G999G999D99') --v_addition_total--i.addition
                                || CHR (9)
                                || TO_CHAR (ln_adjustment,
                                            'FM999G999G999G999D99') --v_adjustment_total--i.adjustment
                                || CHR (9)
                                || TO_CHAR (ln_retirement,
                                            'FM999G999G999G999D99') --v_retirement_total--i.retirement
                                || CHR (9)
                                || TO_CHAR (ln_capitalization,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_revaluation,
                                            'FM999G999G999G999D99') --v_revaluation_total--i.revaluation
                                || CHR (9)
                                || TO_CHAR (ln_reclass,
                                            'FM999G999G999G999D99') --v_reclass_total--i.reclass
                                || CHR (9)
                                || TO_CHAR (ln_transfer,
                                            'FM999G999G999G999D99') --v_transfer_total--i.transfer
                                || CHR (9)
                                --End Changes by Showkath v5.0 on 07-Jul-2015
                                --|| to_char(j.end_year, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                                --|| CHR (9)
                                -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                                || TO_CHAR (j.end_year_fun,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                || TO_CHAR (ln_end_spot,
                                            'FM999G999G999G999D99')
                                || CHR (9)
                                --|| to_char(ln_end_trans, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                                --|| CHR (9)
                                || TO_CHAR (ln_net_trans,
                                            'FM999G999G999G999D99')
                                || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                          --|| to_char(j.impairment, 'FM999G999G999G999D99')
                                          --|| CHR (9)
                                          --|| to_char(j.net_book_value, 'FM999G999G999G999D99')       --v_net_book_value
                                          );
                        END;
                    END LOOP;
                END LOOP;

                FOR l IN c_total
                LOOP
                    -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                    /*IF (h_reporting_flag = 'P')
                    THEN
                       ln_begin_spot := NULL;
                       ln_begin_trans := NULL;
                       ln_end_spot := NULL;
                       ln_end_trans := NULL;
                       ln_net_trans := NULL;
                    ELSE*/
                    BEGIN
                        IF (g_from_currency = 'USD' AND g_to_currency = 'USD')
                        THEN
                            ln_begin_spot   :=
                                  NVL (l.begin_year_fun_tot, 0)
                                * NVL (ln_begin_spot_rate, 1);
                            ln_end_spot   :=
                                  NVL (l.end_year_fun_tot, 0)
                                * NVL (ln_end_spot_rate, 1);
                        ELSE
                            ln_begin_spot   :=
                                  NVL (l.begin_year_fun_tot, 0)
                                * ln_begin_spot_rate;
                            ln_begin_trans   :=
                                ln_begin_spot - l.begin_year_tot;
                            ln_end_spot    :=
                                  NVL (l.end_year_fun_tot, 0)
                                * ln_end_spot_rate;
                            ln_end_trans   := ln_end_spot - l.end_year_tot;
                        --ln_net_trans := ln_end_trans - ln_begin_trans; -- commented by showkath on 01-DEC-2015 to fix net fx translation
                        END IF;
                    END;

                    -- END IF;

                    -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                    -- START changes by showkath v5.0 on 14-Dec-2014
                    --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                    IF (p_currency <> NVL (l_func_currency, 'X'))
                    THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Transactional Date exchange rate:'
                            || ln_conversion_rate);
                        ln_addition         := NULL;
                        ln_adjustment       := NULL;
                        ln_retirement       := NULL;
                        ln_capitalization   := NULL;
                        ln_revaluation      := NULL;
                        ln_reclass          := NULL;
                        ln_transfer         := NULL;
                        ln_addition         := l.addition_tot_nonf;
                        ln_adjustment       := l.adjustment_tot_nonf;
                        ln_retirement       := l.retirement_tot_nonf;
                        ln_capitalization   := l.capitalization_tot_nonf;
                        ln_revaluation      := l.revaluation_tot_nonf;
                        ln_reclass          := l.reclass_tot_nonf;
                        ln_transfer         := l.transfer_tot_nonf;
                        --added  by showkath on 06-DEC-2015 to fix conv rate issue
                        ln_net_trans        := NULL;
                        ln_net_trans        :=
                              NVL (ln_end_spot, 0)
                            - ( --NVL ( (l.begin_year_tot * ln_conversion_rate), 0)--commented  by showkath on 06-DEC-2015 to fix conv rate issue
                               NVL (ln_begin_spot, 0) --added  by showkath on 06-DEC-2015 to fix conv rate issue
                                                      + NVL (ln_addition, 0) + NVL (ln_adjustment, 0) + NVL (ln_retirement, 0) + NVL (ln_capitalization, 0) + NVL (ln_revaluation, 0) + NVL (ln_reclass, 0) + NVL (ln_transfer, 0));
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Program is running with USD Currency-Values with Conversion Rate');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '------------------------------------------');
                        fnd_file.put_line (fnd_file.LOG,
                                           'Additions:' || ln_addition);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adjustments:' || ln_adjustment);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Retirement:' || ln_retirement);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Captalization:' || ln_capitalization);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Revaluation:' || ln_revaluation);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Reclass:' || ln_reclass);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Transfer:' || ln_transfer);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Net FX Transaction:' || ln_net_trans);
                    ELSE
                        ln_addition         := NULL;
                        ln_adjustment       := NULL;
                        ln_retirement       := NULL;
                        ln_capitalization   := NULL;
                        ln_revaluation      := NULL;
                        ln_reclass          := NULL;
                        ln_transfer         := NULL;
                        ln_addition         := l.addition_tot;
                        ln_adjustment       := l.adjustment_tot;
                        ln_retirement       := l.retirement_tot;
                        ln_capitalization   := l.capitalization_tot;
                        ln_revaluation      := l.revaluation_tot;
                        ln_reclass          := l.reclass_tot;
                        ln_transfer         := l.transfer_tot;
                        ln_net_trans        := NULL;
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Program is running with Non USD Currency-Values without Conversion Rate');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '------------------------------------------');
                        fnd_file.put_line (fnd_file.LOG,
                                           'Additions:' || ln_addition);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Adjustments:' || ln_adjustment);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Retirement:' || ln_retirement);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Captalization:' || ln_capitalization);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Revaluation:' || ln_revaluation);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Reclass:' || ln_reclass);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Transfer:' || ln_transfer);
                    END IF;

                    -- END changes by showkath v5.0 on 14-Dec-2014
                    BEGIN
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || NULL                         --i.asset_category
                            || CHR (9)
                            || NULL                     --i.asset_cost_account
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
                            --|| 'TOTAL : '                                 --||j.info1--NULL
                            || 'Total by '
                            || m.book_type_code
                            -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                            || CHR (9)
                            --|| to_char(l.begin_year_tot, 'FM999G999G999G999D99') -- changes by showkath v5.0 on 14-Dec-2014
                            --|| CHR (9)
                            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                            || TO_CHAR (l.begin_year_fun_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_begin_spot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_addition, 'FM999G999G999G999D99') --v_addition_total--i.addition
                            || CHR (9)
                            || TO_CHAR (ln_adjustment,
                                        'FM999G999G999G999D99') --v_adjustment_total--i.adjustment
                            || CHR (9)
                            || TO_CHAR (ln_retirement,
                                        'FM999G999G999G999D99') --v_retirement_total--i.retirement
                            || CHR (9)
                            || TO_CHAR (ln_capitalization,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_revaluation,
                                        'FM999G999G999G999D99') --v_revaluation_total--i.revaluation
                            || CHR (9)
                            || TO_CHAR (ln_reclass, 'FM999G999G999G999D99') --v_reclass_total--i.reclass
                            || CHR (9)
                            || TO_CHAR (ln_transfer, 'FM999G999G999G999D99') --v_transfer_total--i.transfer
                            || CHR (9)
                            --changes by Showkath v5.0 on 07-Jul-2015
                            --|| to_char(l.end_year_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)
                            -- Start changes by BT Technology Team v4.1 on 24-Dec-2014
                            || TO_CHAR (l.end_year_fun_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_end_spot, 'FM999G999G999G999D99')
                            || CHR (9)
                            --|| to_char(ln_end_trans, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                            --|| CHR (9)
                            || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')
                            || CHR (9) -- End changes by BT Technology Team v4.1 on 24-Dec-2014
                                      --|| to_char(l.impairment_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                                      --|| CHR (9)
                                      --|| to_char(l.net_book_value_tot, 'FM999G999G999G999D99')                --v_net_book_value
                                      );

                        ln_begin_spot_grd_tot   :=
                              NVL (ln_begin_spot_grd_tot, 0)
                            + NVL (ln_begin_spot, 0);
                        ln_begin_trans_grd_tot   :=
                              NVL (ln_begin_trans_grd_tot, 0)
                            + NVL (ln_begin_trans, 0);


                        ln_end_spot_grd_tot   :=
                              NVL (ln_end_spot_grd_tot, 0)
                            + NVL (ln_end_spot, 0);
                        ln_end_trans_grd_tot   :=
                              NVL (ln_end_trans_grd_tot, 0)
                            + NVL (ln_end_trans, 0);
                        --ln_net_trans_grd_tot := NVL(ln_net_trans_grd_tot,0) + NVL(ln_net_trans,0); --commented by showkath on 01-DEC-2015 to fix net fx translation
                        --END IF;

                        ln_begin_grd_tot   :=
                              NVL (ln_begin_grd_tot, 0)
                            + NVL (l.begin_year_tot, 0);
                        ln_end_grd_tot   :=
                            NVL (ln_end_grd_tot, 0) + NVL (l.end_year_tot, 0);

                        ln_net_book_val_grd_tot   :=
                              NVL (ln_net_book_val_grd_tot, 0)
                            + NVL (l.net_book_value_tot, 0);
                        ln_impairment_tot   :=
                              NVL (ln_impairment_tot, 0)
                            + NVL (l.impairment_tot, 0);

                        -- End changes by BT Technology Team v4.1 on 26-Dec-2014
                        --START Changes by Showkath v5.0 on 07-Jul-2015
                        --IF (p_currency = 'USD') THEN -- commented by showkath on 01-DEC-2015 to fix net fx translation
                        IF (p_currency <> NVL (l_func_currency, 'X'))
                        THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                            ln_addition_grd_tot    :=
                                  NVL (ln_addition_grd_tot, 0)
                                + NVL (l.addition_tot_nonf, 0);
                            ln_capitalization_grd_tot   :=
                                  NVL (ln_capitalization_grd_tot, 0)
                                + NVL (l.capitalization_tot_nonf, 0);
                            ln_adjustment_grd_tot   :=
                                  NVL (ln_adjustment_grd_tot, 0)
                                + NVL (l.adjustment_tot_nonf, 0);
                            ln_retirement_grd_tot   :=
                                  NVL (ln_retirement_grd_tot, 0)
                                + NVL (l.retirement_tot_nonf, 0);
                            ln_revaluation_grd_tot   :=
                                  NVL (ln_revaluation_grd_tot, 0)
                                + NVL (l.revaluation_tot_nonf, 0);
                            ln_reclass_grd_tot     :=
                                  NVL (ln_reclass_grd_tot, 0)
                                + NVL (l.reclass_tot_nonf, 0);
                            ln_transfer_grd_tot    :=
                                  NVL (ln_transfer_grd_tot, 0)
                                + NVL (l.transfer_tot_nonf, 0);

                            ln_net_trans_grd_tot   := NULL;
                            ln_net_trans_grd_tot   :=
                                  NVL (ln_end_spot_grd_tot, 0)
                                - ( /*NVL (
                                            (  ln_begin_grd_tot
                                             * NVL (ln_conversion_rate, 1)),
                                            0)*/
                -- commented by showkath on 06-DEC-2015 to fix conv rate issue
                                  NVL (ln_begin_spot_grd_tot, 0) -- added by showkath on 06-DEC-2015 to fix net fx translation issue
                                                                 + NVL (ln_addition_grd_tot, 0) + NVL (ln_adjustment_grd_tot, 0) + NVL (ln_retirement_grd_tot, 0) + NVL (ln_capitalization_grd_tot, 0) + NVL (ln_revaluation_grd_tot, 0) + NVL (ln_reclass_grd_tot, 0) + NVL (ln_transfer_grd_tot, 0));
                        ELSE
                            ln_addition_grd_tot   :=
                                  NVL (ln_addition_grd_tot, 0)
                                + NVL (l.addition_tot, 0);
                            ln_capitalization_grd_tot   :=
                                  NVL (ln_capitalization_grd_tot, 0)
                                + NVL (l.capitalization_tot, 0);
                            ln_adjustment_grd_tot   :=
                                  NVL (ln_adjustment_grd_tot, 0)
                                + NVL (l.adjustment_tot, 0);
                            ln_retirement_grd_tot   :=
                                  NVL (ln_retirement_grd_tot, 0)
                                + NVL (l.retirement_tot, 0);
                            ln_revaluation_grd_tot   :=
                                  NVL (ln_revaluation_grd_tot, 0)
                                + NVL (l.revaluation_tot, 0);
                            ln_reclass_grd_tot   :=
                                  NVL (ln_reclass_grd_tot, 0)
                                + NVL (l.reclass_tot, 0);
                            ln_transfer_grd_tot   :=
                                  NVL (ln_transfer_grd_tot, 0)
                                + NVL (l.transfer_tot, 0);
                            ln_net_trans   := NULL;
                        END IF;
                    --END Changes by Showkath v5.0 on 07-Jul-2015
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            apps.fnd_file.put_line (
                                apps.fnd_file.LOG,
                                   'Error in Calculating Final Output: '
                                || SUBSTR (SQLERRM, 1, 200));
                    END;
                END LOOP;
            -- Start changes by BT Technology Team v4.1 on 26-Dec-2014
            ELSE
                apps.fnd_file.put_line (
                    apps.fnd_file.output,
                       'Period not Open for Book: '
                    || m.book_type_code
                    || ' for Period: '
                    || p_from_period
                    || ' '
                    || p_to_period);
            END IF;                                                -- If ended
        END LOOP;

        BEGIN
            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || 'TOTAL Fixed Asset: '
                || CHR (9)
                --|| to_char(ln_begin_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_begin_spot_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_begin_trans_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || TO_CHAR (ln_addition_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_adjustment_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_retirement_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_capitalization_grd_tot,
                            'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_revaluation_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_reclass_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_transfer_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_end_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_end_spot_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_end_trans_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || TO_CHAR (ln_net_trans_grd_tot, 'FM999G999G999G999D99')
                || CHR (9) --|| to_char(ln_impairment_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                          --|| CHR (9)
                          --|| to_char(ln_net_book_val_grd_tot, 'FM999G999G999G999D99')
                          );
            get_project_cip_prc (p_called_from => 'SUMMARY', p_book => p_book, p_currency => p_currency, p_from_period => p_from_period, p_to_period => p_to_period, p_begin_spot_rate => ln_begin_spot_rate, p_end_spot_rate => ln_end_spot_rate, p_begin_bal_tot => ln_begin_cip_tot, p_begin_spot_tot => ln_begin_spot_cip_tot, p_begin_trans_tot => ln_begin_trans_cip_tot, p_additions_tot => ln_addition_cip_tot, p_capitalizations_tot => ln_capitalization_cip_tot, p_end_bal_tot => ln_end_cip_tot, p_end_spot_tot => ln_end_spot_cip_tot, p_end_trans_tot => ln_end_trans_cip_tot
                                 , p_net_trans_tot => ln_net_trans_cip_tot);

            BEGIN
                ln_begin_spot_grd_tot   :=
                    NVL (ln_begin_spot_grd_tot, 0) + ln_begin_spot_cip_tot;
                ln_begin_trans_grd_tot   :=
                    NVL (ln_begin_trans_grd_tot, 0) + ln_begin_trans_cip_tot;

                ln_end_spot_grd_tot   :=
                    NVL (ln_end_spot_grd_tot, 0) + ln_end_spot_cip_tot;
                ln_end_trans_grd_tot   :=
                    NVL (ln_end_trans_grd_tot, 0) + ln_end_trans_cip_tot;

                IF    (p_currency <> NVL (l_func_currency, 'X'))
                   OR (p_book IS NULL)
                THEN -- added by showkath on 01-DEC-2015 to fix net fx translation
                    ln_net_trans_grd_tot   :=
                        NVL (ln_net_trans_grd_tot, 0) + ln_net_trans_cip_tot;
                END IF;
            END;

            --END IF;

            ln_begin_grd_tot          := ln_begin_grd_tot + ln_begin_cip_tot;
            ln_end_grd_tot            := ln_end_grd_tot + ln_end_cip_tot;
            ln_net_book_val_grd_tot   := ln_net_book_val_grd_tot;
            ln_addition_grd_tot       :=
                ln_addition_grd_tot + ln_addition_cip_tot;
            ln_capitalization_grd_tot   :=
                ln_capitalization_grd_tot + ln_capitalization_cip_tot;

            apps.fnd_file.put_line (
                apps.fnd_file.output,
                   NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || NULL
                || CHR (9)
                || 'GRAND TOTAL :'
                || CHR (9)
                --|| to_char(ln_begin_grd_tot, 'FM999G999G999G999D99') --changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_begin_spot_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_begin_trans_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || TO_CHAR (ln_addition_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_adjustment_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_retirement_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_capitalization_grd_tot,
                            'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_revaluation_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_reclass_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_transfer_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_end_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_end_spot_grd_tot, 'FM999G999G999G999D99')
                || CHR (9)
                --|| to_char(ln_end_trans_grd_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                --|| CHR (9)
                || TO_CHAR (ln_net_trans_grd_tot, 'FM999G999G999G999D99')
                || CHR (9) --|| to_char(ln_impairment_tot, 'FM999G999G999G999D99')--changes by Showkath v5.0 on 07-Jul-2015
                          --|| CHR (9)
                          --|| to_char(ln_net_book_val_grd_tot, 'FM999G999G999G999D99')
                          );
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'Error in Calculating Final Output: '
                    || SUBSTR (SQLERRM, 1, 200));
        END;
    -- End changes by BT Technology Team v4.1 on 26-Dec-2014
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Error in main_summary:' || SQLERRM);
    END main_summary;
END XXD_FA_ROLL_FWD_PKG;
/
