--
-- XXD_FA_CIP_ROLL_FWD_REPORT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:30:40 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_FA_CIP_ROLL_FWD_REPORT_PKG"
AS
    /***********************************************************************************
    *$header :                                                                        *
    *                                                                                 *
    * AUTHORS : Infosys                                                        *
    *                                                                                 *
    * PURPOSE : CIP Report                                              *
    *                                                                                 *
    * PARAMETERS :                                                                    *
    *                                                                                 *
    * DATE : 16-Sep-2016                                                              *
    *                                                                                 *
    * History      :                                                                  *
    *                                                                                 *
    * =============================================================================== *
    * Who                   Version    Comments                          When         *
    * Infosys               1.1        Change as part of CCR0007020      08-MAY-2018  *
    * Showkath              1.2        Change as part of CCR0008086      20-AUG-2019  *
    * Aravind Kannuri       1.3        Change as part of CCR0007965      19-NOV-2019  *
    * Aravind Kannuri       1.4        Change as part of CCR0009113      18-JAN-2021  *
    * =============================================================================== *
    **********************************************************************************/
    -- Function to get the account for CCA project
    FUNCTION get_cip_cca_account (pn_project_id IN NUMBER DEFAULT NULL, pn_task_id IN NUMBER DEFAULT NULL, pn_expenditure_item_id IN NUMBER DEFAULT NULL)
        RETURN VARCHAR2
    IS
        lv_cip_cca_account   VARCHAR2 (10) := NULL;
        lv_err_msg           VARCHAR2 (2000) := NULL;
    BEGIN
        IF     pn_project_id IS NULL
           AND pn_task_id IS NULL
           AND pn_expenditure_item_id IS NULL
        THEN
            lv_cip_cca_account   := NULL;
        ELSIF     pn_project_id IS NULL
              AND pn_task_id IS NULL
              AND pn_expenditure_item_id IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_expenditure_items_all pei, apps.pa_tasks pt, apps.pa_projects_all pa,
                       apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pei.expenditure_item_id = pn_expenditure_item_id
                       AND pei.task_id = pt.task_id
                       AND pt.billable_flag = 'Y'              --Capitalizable
                       AND pt.project_id = pa.project_id
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        ELSIF     pn_project_id IS NULL
              AND pn_task_id IS NOT NULL
              AND pn_expenditure_item_id IS NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_tasks pt, apps.pa_projects_all pa, apps.fnd_flex_value_sets ffvs,
                       apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pt.task_id = pn_task_id
                       AND pt.billable_flag = 'Y'              --Capitalizable
                       AND pt.project_id = pa.project_id
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        ELSIF     pn_project_id IS NULL
              AND pn_task_id IS NOT NULL
              AND pn_expenditure_item_id IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_tasks pt, apps.pa_projects_all pa, apps.pa_expenditure_items_all pei,
                       apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pt.task_id = pn_task_id
                       AND pt.billable_flag = 'Y'              --Capitalizable
                       AND pt.project_id = pa.project_id
                       AND pt.task_id = pei.task_id
                       AND pei.expenditure_item_id = pn_expenditure_item_id
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        ELSIF     pn_project_id IS NOT NULL
              AND pn_task_id IS NULL
              AND pn_expenditure_item_id IS NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_projects_all pa, apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pa.project_id = pn_project_id
                       AND EXISTS
                               (SELECT 1
                                  FROM apps.pa_tasks pt
                                 WHERE     1 = 1
                                       AND pt.project_id = pa.project_id
                                       AND pt.billable_flag = 'Y' --Capitalizable
                                                                 )
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        ELSIF     pn_project_id IS NOT NULL
              AND pn_task_id IS NULL
              AND pn_expenditure_item_id IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_projects_all pa, apps.pa_expenditure_items_all pei, apps.pa_tasks pt,
                       apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pa.project_id = pn_project_id
                       AND pa.project_id = pei.project_id
                       AND pei.expenditure_item_id = pn_expenditure_item_id
                       AND pei.project_id = pt.project_id
                       AND pei.task_id = pt.task_id
                       AND pt.billable_flag = 'Y'              --Capitalizable
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        ELSIF     pn_project_id IS NOT NULL
              AND pn_task_id IS NOT NULL
              AND pn_expenditure_item_id IS NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_projects_all pa, apps.pa_tasks pt, apps.fnd_flex_value_sets ffvs,
                       apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pa.project_id = pn_project_id
                       AND pa.project_id = pt.project_id
                       AND pt.task_id = pn_task_id
                       AND pt.billable_flag = 'Y'              --Capitalizable
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        ELSIF     pn_project_id IS NOT NULL
              AND pn_task_id IS NOT NULL
              AND pn_expenditure_item_id IS NOT NULL
        THEN
            BEGIN
                SELECT ffvl.attribute1 account_value
                  INTO lv_cip_cca_account
                  FROM apps.pa_projects_all pa, apps.pa_tasks pt, apps.pa_expenditure_items_all pei,
                       apps.fnd_flex_value_sets ffvs, apps.fnd_flex_values_vl ffvl
                 WHERE     1 = 1
                       AND pa.project_id = pn_project_id
                       AND pa.project_id = pt.project_id
                       AND pt.task_id = pn_task_id
                       AND pt.billable_flag = 'Y'              --Capitalizable
                       AND pt.project_id = pei.project_id
                       AND pt.task_id = pei.task_id
                       AND pei.expenditure_item_id = pn_expenditure_item_id
                       AND ffvs.flex_value_set_name =
                           'XXD_FA_PA_PROJECT_TYPE'
                       AND ffvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND pa.attribute1 = ffvl.flex_value;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_cip_cca_account   := NULL;
                WHEN OTHERS
                THEN
                    lv_cip_cca_account   := NULL;
            END;
        END IF;

        RETURN lv_cip_cca_account;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_err_msg           :=
                SUBSTR (
                       'Main Exception in GET_CIP_CCA_ACCOUNT function. Error is:'
                    || SQLERRM,
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            lv_cip_cca_account   := NULL;
            RETURN lv_cip_cca_account;
    END get_cip_cca_account;

    --START Added as per version 1.3
    --Added New procedure 'get_project_cip_dtls_prc' by replacing of existing procedure 'get_project_cip_prc'
    PROCEDURE get_project_cip_dtls_prc (p_book           IN VARCHAR2,
                                        p_currency       IN VARCHAR2,
                                        p_from_period    IN VARCHAR2,
                                        p_to_period      IN VARCHAR2,
                                        p_project_type   IN VARCHAR2)
    IS
        ln_project_id              NUMBER;
        ln_task_id                 NUMBER;
        l_task_num                 VARCHAR2 (25);
        ln_project_account         VARCHAR2 (100);
        lv_cip_account             VARCHAR2 (100);
        ln_from_period_ctr         NUMBER;
        ln_to_period_ctr           NUMBER;
        ln_end_period_ctr          NUMBER;
        l_func_currency            VARCHAR2 (10);
        ld_begin_date              DATE;
        ld_end_date                DATE;

        --Corp Rate
        ln_begin_corp_rate         NUMBER := 0;
        ln_end_corp_rate           NUMBER := 0;

        --Spot Rate
        ln_Opening_Balance         NUMBER := 0;
        ln_Opening_Bal_Spot        NUMBER := 0;
        ln_Additions               NUMBER := 0;
        ln_Capitalizations         NUMBER := 0;
        ln_transfers               NUMBER := 0;
        ln_begin_Additions         NUMBER := 0;
        ln_begin_Capitalizations   NUMBER := 0;
        ln_begin_transfers         NUMBER := 0;
        ln_end_Additions           NUMBER := 0;
        ln_end_Capitalizations     NUMBER := 0;
        ln_end_transfers           NUMBER := 0;
        ln_Ending_Balance          NUMBER := 0;
        ln_Ending_Bal_Spot         NUMBER := 0;
        ln_begin_spot_rate         NUMBER := 0;
        ln_end_spot_rate           NUMBER := 0;
        ln_begin_bal_spot          NUMBER := 0;
        ln_end_bal_spot            NUMBER := 0;
        ln_common_end_spot_rate    NUMBER := 0;
        ln_net_trans               NUMBER := 0;

        --Totals
        ln_additions_tot           NUMBER := 0;
        ln_capitalizations_tot     NUMBER := 0;
        ln_transfers_tot           NUMBER := 0;
        ln_begin_bal_fun_tot       NUMBER := 0;
        ln_begin_bal_spot_tot      NUMBER := 0;
        ln_end_bal_fun_tot         NUMBER := 0;
        ln_end_bal_spot_tot        NUMBER := 0;
        ln_net_trans_tot           NUMBER := 0;
        l_total_flag               VARCHAR2 (1) := 'N';

        CURSOR cur_cip_dtls (p_book_type_code    VARCHAR2,
                             p_currency          VARCHAR2,
                             p_begin_date        DATE,
                             p_end_date          DATE,
                             p_func_currency     VARCHAR2,
                             p_cip_account       VARCHAR2,
                             p_from_period_ctr   NUMBER,
                             p_end_period_ctr    NUMBER)
        IS
              SELECT project_number, project_name, NVL (task_number, '') task_number,
                     org_id, SUM (NVL (acct_burdened_cost, 0)) acct_burdened_cost, SUM (NVL (denom_burdened_cost, 0)) denom_burdened_cost,
                     SUM (NVL (Additions, 0) + NVL (Capitalization, 0) + NVL (transfer, 0)) Opening_Balance, SUM (Curr_Additions) Additions, SUM (Curr_Cap) Capitalizations,
                     SUM (Curr_Transfers) Transfers, SUM (NVL (Additions, 0) + NVL (Capitalization, 0) + NVL (transfer, 0)) + SUM (NVL (Curr_Additions, 0)) + SUM (NVL (Curr_Cap, 0)) + SUM (NVL (Curr_Transfers, 0)) Ending_Balance
                FROM (                                       --Opening Balance
                      (  SELECT p.segment1 project_number, p.name project_name, NVL (t.task_number, '') task_number,
                                p.org_id org_id, SUM (pcdl.acct_burdened_cost) acct_burdened_cost, SUM (pcdl.burdened_cost) denom_burdened_cost,
                                ROUND (SUM (pcdl.burdened_cost), 2) Additions, NULL Capitalization, NULL Transfer,
                                NULL Curr_Additions, NULL Curr_Cap, NULL Curr_Transfers
                           FROM apps.pa_projects_all p, apps.pa_tasks t, apps.pa_expenditure_items_all ei,
                                apps.pa_expenditures_all x, apps.pa_project_types_all pt, apps.pa_implementations_all pia,
                                apps.pa_cost_distribution_lines_all pcdl, apps.gl_code_combinations_kfv gcck
                          WHERE     t.project_id = p.project_id
                                AND ei.project_id = p.project_id
                                AND p.project_type = pt.project_type
                                AND p.org_id = pt.org_id
                                AND ei.task_id = t.task_id
                                AND ei.expenditure_id = x.expenditure_id
                                AND ei.org_id = pia.org_id
                                AND gcck.code_combination_id =
                                    pcdl.dr_code_combination_id
                                AND gcck.segment6 = p_cip_account
                                AND pia.book_type_code(+) = p_book_type_code
                                AND pcdl.project_id = ei.project_id
                                AND pcdl.task_id = ei.task_id
                                AND ei.transaction_source NOT IN
                                        ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                AND pcdl.expenditure_item_id =
                                    ei.expenditure_item_id
                                AND pcdl.billable_flag = 'Y'
                                AND pcdl.gl_date < p_begin_date
                       GROUP BY p.segment1, p.name, t.task_number,
                                p.org_id
                       UNION ALL
                       (  SELECT ppa.segment1, ppa.name, NVL (t.task_number, '') task_number,
                                 ppa.org_id, NULL, NULL,
                                 NULL, ROUND (-1 * SUM (DECODE (pal.task_id, 0, -1 * current_asset_cost, current_asset_cost)), 2) Capitalization, NULL,
                                 NULL, NULL, NULL
                            FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                                 pa_project_types_all pta, pa_tasks t, gl_code_combinations_kfv gcck --Added as per v1.4
                           WHERE     1 = 1
                                 AND pal.transfer_status_code = 'T'
                                 AND t.project_id = ppa.project_id
                                 AND pal.org_id = pia.org_id
                                 AND pia.book_type_code = p_book_type_code
                                 AND pal.project_id = ppa.project_id
                                 AND pal.org_id = ppa.org_id
                                 AND gcck.code_combination_id = pal.cip_ccid --Added as per v1.4
                                 AND gcck.segment6 = p_cip_account --Added as per v1.4
                                 AND pal.org_id = t.carrying_out_organization_id
                                 AND ppa.project_type = pta.project_type
                                 AND ppa.org_id = pta.org_id
                                 AND pal.task_id = t.task_id
                                 AND fa_period_name IN
                                         (SELECT period_name
                                            FROM fa_deprn_periods
                                           WHERE     book_type_code =
                                                     p_book_type_code
                                                 AND period_counter <
                                                     p_from_period_ctr)
                        GROUP BY ppa.segment1, ppa.name, t.task_number,
                                 ppa.org_id
                        UNION ALL
                          SELECT ppa.segment1, ppa.name, '',
                                 ppa.org_id org_id, NULL, NULL,
                                 NULL, ROUND (-1 * SUM (current_asset_cost), 2) Capitalization, NULL,
                                 NULL, NULL, NULL
                            FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                                 pa_project_types_all pta, gl_code_combinations_kfv gcck --Added as per v1.4
                           WHERE     1 = 1
                                 AND pal.transfer_status_code = 'T'
                                 AND pal.org_id = pia.org_id
                                 AND pia.book_type_code = p_book_type_code
                                 AND pal.project_id = ppa.project_id
                                 AND pal.org_id = ppa.org_id
                                 AND gcck.code_combination_id = pal.cip_ccid --Added as per v1.4
                                 AND gcck.segment6 = p_cip_account --Added as per v1.4
                                 AND ppa.project_type = pta.project_type
                                 AND ppa.org_id = pta.org_id
                                 AND pal.task_id = 0
                                 AND fa_period_name IN
                                         (SELECT period_name
                                            FROM fa_deprn_periods
                                           WHERE     book_type_code =
                                                     p_book_type_code
                                                 AND period_counter <
                                                     p_from_period_ctr)
                        GROUP BY ppa.segment1, ppa.name, ppa.org_id)
                       UNION ALL
                         SELECT p.segment1 project_number, p.name, NVL (t.task_number, '') task_number,
                                p.org_id org_id, SUM (pcdl.acct_burdened_cost) acct_burdened_cost, SUM (pcdl.burdened_cost) denom_burdened_cost,
                                NULL, NULL, ROUND (SUM (pcdl.burdened_cost), 2) Transfer,
                                NULL, NULL, NULL
                           FROM apps.pa_projects_all p, pa_tasks t, apps.pa_expenditure_items_all ei,
                                apps.pa_expenditures_all x, apps.pa_project_types_all pt, apps.pa_implementations_all pia,
                                apps.pa_cost_distribution_lines_all pcdl, apps.gl_code_combinations_kfv gcck
                          WHERE     1 = 1
                                AND t.project_id = p.project_id
                                AND ei.project_id = p.project_id
                                AND p.project_type = pt.project_type
                                AND p.org_id = pt.org_id
                                AND ei.task_id = t.task_id
                                AND ei.expenditure_id = x.expenditure_id
                                AND ei.org_id = pia.org_id
                                AND pia.book_type_code(+) = p_book_type_code
                                AND pcdl.project_id = ei.project_id
                                AND pcdl.task_id = ei.task_id
                                AND gcck.code_combination_id =
                                    pcdl.dr_code_combination_id
                                AND gcck.segment6 = p_cip_account
                                AND ei.transaction_source IN
                                        ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                AND pcdl.expenditure_item_id =
                                    ei.expenditure_item_id
                                AND pcdl.billable_flag = 'Y'
                                AND pcdl.gl_date < p_begin_date
                       GROUP BY p.segment1, p.name, t.task_number,
                                p.org_id)
                      UNION ALL
                      --Additions, Capitalization and Transfers
                      (  SELECT p.segment1 project_number, p.name, NVL (t.task_number, '') task_number,
                                p.org_id org_id, SUM (pcdl.acct_burdened_cost) acct_burdened_cost, SUM (pcdl.burdened_cost) denom_burdened_cost,
                                NULL, NULL, NULL,
                                ROUND (SUM (pcdl.burdened_cost), 2) Curr_Additions, NULL Curr_Cap, NULL Curr_Transfers
                           FROM apps.pa_projects_all p, apps.pa_tasks t, apps.pa_expenditure_items_all ei,
                                apps.pa_expenditures_all x, apps.pa_project_types_all pt, apps.pa_implementations_all pia,
                                apps.pa_cost_distribution_lines_all pcdl, apps.gl_code_combinations_kfv gcck
                          WHERE     t.project_id = p.project_id
                                AND ei.project_id = p.project_id
                                AND p.project_type = pt.project_type
                                AND p.org_id = pt.org_id
                                AND ei.task_id = t.task_id
                                AND ei.expenditure_id = x.expenditure_id
                                AND ei.org_id = pia.org_id
                                AND pia.book_type_code(+) = p_book_type_code
                                AND pcdl.project_id = ei.project_id
                                AND pcdl.task_id = ei.task_id
                                AND gcck.code_combination_id =
                                    pcdl.dr_code_combination_id
                                AND gcck.segment6 = p_cip_account
                                AND ei.transaction_source NOT IN
                                        ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                AND pcdl.expenditure_item_id =
                                    ei.expenditure_item_id
                                AND pcdl.billable_flag = 'Y'
                                AND pcdl.gl_date BETWEEN p_begin_date
                                                     AND p_end_date
                       GROUP BY p.segment1, p.name, t.task_number,
                                p.org_id
                       UNION ALL
                       (  SELECT ppa.segment1, ppa.name, NVL (t.task_number, '') task_number,
                                 ppa.org_id org_id, NULL, NULL,
                                 NULL, NULL, NULL,
                                 NULL, ROUND (-1 * SUM (DECODE (pal.task_id, 0, -1 * current_asset_cost, current_asset_cost)), 2) Curr_Cap, NULL
                            FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                                 pa_project_types_all pta, pa_tasks t, gl_code_combinations_kfv gcck --Added as per v1.4
                           WHERE     1 = 1
                                 AND pal.transfer_status_code = 'T'
                                 AND t.project_id = ppa.project_id
                                 AND pal.org_id = pia.org_id
                                 AND pia.book_type_code = p_book_type_code
                                 AND pal.project_id = ppa.project_id
                                 AND gcck.code_combination_id = pal.cip_ccid --Added as per v1.4
                                 AND gcck.segment6 = p_cip_account --Added as per v1.4
                                 AND pal.org_id = ppa.org_id
                                 AND pal.org_id = t.carrying_out_organization_id
                                 AND ppa.project_type = pta.project_type
                                 AND ppa.org_id = pta.org_id
                                 AND pal.task_id = t.task_id
                                 AND fa_period_name IN
                                         (SELECT period_name
                                            FROM fa_deprn_periods
                                           WHERE     book_type_code =
                                                     p_book_type_code
                                                 AND period_counter BETWEEN p_from_period_ctr
                                                                        AND p_end_period_ctr)
                        GROUP BY ppa.segment1, ppa.name, t.task_number,
                                 ppa.org_id
                        UNION ALL
                          SELECT ppa.segment1, ppa.name, '',
                                 ppa.org_id, NULL, NULL,
                                 NULL, NULL, NULL,
                                 NULL, ROUND (-1 * SUM (current_asset_cost), 2) Curr_Cap, NULL
                            FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                                 pa_project_types_all pta, gl_code_combinations_kfv gcck --Added as per v1.4
                           WHERE     1 = 1
                                 AND pal.transfer_status_code = 'T'
                                 AND pal.org_id = pia.org_id
                                 AND pia.book_type_code = p_book_type_code
                                 AND pal.project_id = ppa.project_id
                                 AND pal.org_id = ppa.org_id
                                 AND gcck.code_combination_id = pal.cip_ccid --Added as per v1.4
                                 AND gcck.segment6 = p_cip_account --Added as per v1.4
                                 AND ppa.project_type = pta.project_type
                                 AND ppa.org_id = pta.org_id
                                 AND pal.task_id = 0
                                 AND fa_period_name IN
                                         (SELECT period_name
                                            FROM fa_deprn_periods
                                           WHERE     book_type_code =
                                                     p_book_type_code
                                                 AND period_counter BETWEEN p_from_period_ctr
                                                                        AND p_end_period_ctr)
                        GROUP BY ppa.segment1, ppa.name, ppa.org_id)
                       UNION ALL
                         SELECT p.segment1 project_number, p.name, NVL (t.task_number, '') task_number,
                                p.org_id, SUM (pcdl.acct_burdened_cost) acct_burdened_cost, SUM (pcdl.burdened_cost) denom_burdened_cost,
                                NULL, NULL, NULL,
                                NULL, NULL, ROUND (SUM (pcdl.burdened_cost), 2) Curr_Transfers
                           FROM apps.pa_projects_all p, pa_tasks t, apps.pa_expenditure_items_all ei,
                                apps.pa_expenditures_all x, apps.pa_project_types_all pt, apps.pa_implementations_all pia,
                                apps.pa_cost_distribution_lines_all pcdl, apps.gl_code_combinations_kfv gcck
                          WHERE     1 = 1
                                AND t.project_id = p.project_id
                                AND ei.project_id = p.project_id
                                AND p.project_type = pt.project_type
                                AND p.org_id = pt.org_id
                                AND ei.task_id = t.task_id
                                AND ei.expenditure_id = x.expenditure_id
                                AND ei.org_id = pia.org_id
                                AND pia.book_type_code(+) = p_book_type_code
                                AND pcdl.project_id = ei.project_id
                                AND pcdl.task_id = ei.task_id
                                AND gcck.code_combination_id =
                                    pcdl.dr_code_combination_id
                                AND gcck.segment6 = p_cip_account
                                AND ei.transaction_source IN
                                        ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                AND pcdl.expenditure_item_id =
                                    ei.expenditure_item_id
                                AND pcdl.billable_flag = 'Y'
                                AND pcdl.gl_date BETWEEN p_begin_date
                                                     AND p_end_date
                       GROUP BY p.segment1, p.name, t.task_number,
                                p.org_id))
            GROUP BY project_number, project_name, task_number,
                     org_id
            ORDER BY 1, 3;
    BEGIN
        print_log_prc ('Print CIP details');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, 'Project CIP Section');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Project Number'
            || CHR (9)
            || 'Project Name'
            || CHR (9)
            || 'Task Number'
            || CHR (9)
            || 'Asset Book Name '
            || CHR (9)
            || 'GL Account '
            || CHR (9)
            || 'From Date'
            || CHR (9)
            || 'To Date'
            || CHR (9)
            || 'Begin Balance in <Functional Currency>'
            || CHR (9)
            || 'Begin Balance <USD> at Spot Rate'
            || CHR (9)
            || 'Additions'
            || CHR (9)
            || 'Transfers'
            || CHR (9)
            || 'Capitalizations'
            || CHR (9)
            || 'End Balance in <Functional Currency>'
            || CHR (9)
            || 'End Balance <USD> at Spot Rate'
            || CHR (9)
            || 'Currency'
            || CHR (9)
            || 'Net FX Translation');

        FOR rec
            IN (SELECT book_type_code
                  FROM fa_book_controls_sec
                 WHERE     book_type_code = NVL (p_book, book_type_code)
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE)
        LOOP
            ld_begin_date            := NULL;
            ld_end_date              := NULL;
            l_func_currency          := NULL;
            l_total_flag             := 'N';

            --Initialization by Book
            ln_begin_bal_fun_tot     := 0;
            ln_begin_bal_spot_tot    := 0;
            ln_additions_tot         := 0;
            ln_transfers_tot         := 0;
            ln_capitalizations_tot   := 0;
            ln_end_bal_fun_tot       := 0;
            ln_end_bal_spot_tot      := 0;
            ln_net_trans_tot         := 0;

            --To fetch Begin Date based on period
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

            --To fetch End Date based on period
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

            --To fetch functional currency
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

            g_from_currency          := l_func_currency;

            print_log_prc ('Book_Type	::' || rec.book_type_code);
            print_log_prc (
                   'Begin_date and End_date	::'
                || ld_begin_date
                || ' and '
                || ld_end_date);
            print_log_prc (
                   'From_period and To_period  ::'
                || p_from_period
                || ' and '
                || p_to_period);
            print_log_prc (
                   'p_currency and Func_Currency ::'
                || p_currency
                || ' and '
                || l_func_currency);


            --To fetch period counter from
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

            --To fetch period counter to
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

            --To fetch cip account
            BEGIN
                lv_cip_account   := NULL;

                SELECT ffvl.flex_value
                  INTO lv_cip_account
                  FROM apps.fnd_flex_value_sets flvs, apps.fnd_flex_values_vl ffvl
                 WHERE     flvs.flex_value_set_name = 'XXD_FA_PA_CIP_ACCT_VS'
                       AND flvs.flex_value_set_id = ffvl.flex_value_set_id
                       AND ffvl.enabled_flag = 'Y'
                       AND ffvl.summary_flag = 'N'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           ffvl.start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (
                                                           ffvl.end_date_active,
                                                           SYSDATE))
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log_prc (
                        'Error fetching cip account: ' || lv_cip_account);
            END;


            BEGIN
                FOR m
                    IN cur_cip_dtls (rec.book_type_code, p_currency, ld_begin_date, ld_end_date, l_func_currency, lv_cip_account
                                     , ln_from_period_ctr, ln_to_period_ctr)
                LOOP
                    ln_project_id              := 0;
                    ln_task_id                 := 0;
                    l_task_num                 := NULL;
                    ln_Opening_Balance         := 0;
                    ln_Opening_Bal_Spot        := 0;
                    ln_Additions               := 0;
                    ln_Capitalizations         := 0;
                    ln_transfers               := 0;
                    ln_begin_Additions         := 0;
                    ln_begin_Capitalizations   := 0;
                    ln_begin_transfers         := 0;
                    ln_end_Additions           := 0;
                    ln_end_Capitalizations     := 0;
                    ln_end_transfers           := 0;
                    ln_Ending_Balance          := 0;
                    ln_Ending_Bal_Spot         := 0;
                    ln_begin_spot_rate         := 0;
                    ln_begin_corp_rate         := 0;
                    ln_end_corp_rate           := 0;
                    ln_end_spot_rate           := 0;
                    ln_begin_bal_spot          := 0;
                    ln_end_bal_spot            := 0;
                    ln_project_account         := NULL;
                    ln_net_trans               := NULL;
                    l_total_flag               := 'Y';

                    --To validate Task
                    IF m.task_number = '0'
                    THEN
                        l_task_num   := NULL;
                    ELSE
                        l_task_num   := m.task_number;
                    END IF;

                    --To fetch project_id
                    BEGIN
                        SELECT project_id
                          INTO ln_project_id
                          FROM pa_projects_all
                         WHERE name = m.project_name;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_project_id   := 0;
                    END;

                    --To fetch Task_id
                    BEGIN
                        SELECT task_id
                          INTO ln_task_id
                          FROM pa_tasks
                         WHERE     task_number = m.task_number
                               AND project_id = ln_project_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_task_id   := 0;
                    END;

                    --Function to fetch project account
                    ln_project_account         :=
                        get_cip_cca_account (ln_project_id, ln_task_id, NULL); --CCR0008086

                    --To fetch begin conversion corporate rate
                    IF l_func_currency <> g_to_currency
                    THEN
                        BEGIN
                            SELECT conversion_rate
                              INTO ln_begin_corp_rate
                              FROM gl_daily_rates
                             WHERE     from_currency = l_func_currency
                                   AND to_currency = 'USD'
                                   AND TRUNC (conversion_date) =
                                       (SELECT TRUNC (calendar_period_open_date) - 1
                                          FROM fa_deprn_periods
                                         WHERE     period_name =
                                                   p_from_period
                                               AND book_type_code =
                                                   rec.book_type_code)
                                   AND conversion_type = 'Corporate';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_begin_corp_rate   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Corporate is not defined');
                        END;

                        --To fetch end conversion corporate rate
                        BEGIN
                            SELECT conversion_rate
                              INTO ln_end_corp_rate
                              FROM gl_daily_rates
                             WHERE     from_currency = l_func_currency
                                   AND to_currency = 'USD'
                                   AND TRUNC (conversion_date) =
                                       (SELECT TRUNC (calendar_period_close_date)
                                          FROM fa_deprn_periods
                                         WHERE     period_name = p_to_period
                                               AND book_type_code =
                                                   rec.book_type_code)
                                   AND conversion_type = 'Corporate';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_end_corp_rate   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Corporate rate is not defined');
                        END;

                        --To fetch begin conversion spot rate
                        BEGIN
                            SELECT conversion_rate
                              INTO ln_begin_spot_rate
                              FROM gl_daily_rates
                             WHERE     from_currency = l_func_currency
                                   AND to_currency = 'USD'
                                   AND TRUNC (conversion_date) =
                                       (SELECT TRUNC (calendar_period_open_date) - 1
                                          FROM fa_deprn_periods
                                         WHERE     period_name =
                                                   p_from_period
                                               AND book_type_code =
                                                   rec.book_type_code)
                                   AND conversion_type = 'Spot';
                        EXCEPTION
                            WHEN NO_DATA_FOUND
                            THEN
                                ln_begin_spot_rate   := NULL;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Spot rate is not defined');
                        END;

                        --To fetch end conversion sport rate
                        BEGIN
                            SELECT conversion_rate
                              INTO ln_end_spot_rate
                              FROM gl_daily_rates
                             WHERE     from_currency = l_func_currency
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
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Spot rate is not defined');
                        END;
                    ELSE
                        ln_begin_corp_rate   := NULL;
                        ln_end_corp_rate     := NULL;
                        ln_begin_spot_rate   := NULL;
                        ln_end_spot_rate     := NULL;
                    END IF;

                    --IF ((g_to_currency = l_func_currency) OR (p_currency = l_func_currency)) THEN
                    IF g_to_currency = l_func_currency
                    THEN
                        ln_Opening_Balance   :=
                              NVL (ln_Opening_Balance, 0)
                            + NVL (m.Opening_Balance, 0);
                        ln_Additions   :=
                            NVL (ln_Additions, 0) + NVL (m.Additions, 0);
                        ln_Capitalizations   :=
                              NVL (ln_Capitalizations, 0)
                            + NVL (m.Capitalizations, 0);
                        ln_transfers   :=
                            NVL (ln_transfers, 0) + NVL (m.transfers, 0);
                        ln_Ending_Balance   :=
                              NVL (ln_Ending_Balance, 0)
                            + NVL (m.Ending_Balance, 0);

                        ln_begin_bal_spot   :=
                              NVL (ln_begin_bal_spot, 0)
                            + NVL (m.Opening_Balance, 0);
                        ln_end_bal_spot   :=
                              NVL (ln_end_bal_spot, 0)
                            + NVL (m.Ending_Balance, 0);
                        ln_net_trans   := NULL;
                    ELSE
                        --Functional Currency Calculations
                        ln_Opening_Balance   :=
                              NVL (ln_Opening_Balance, 0)
                            + NVL (m.Opening_Balance, 0);
                        ln_Additions   :=
                            NVL (ln_Additions, 0) + NVL (m.Additions, 0);
                        ln_Capitalizations   :=
                              NVL (ln_Capitalizations, 0)
                            + NVL (m.Capitalizations, 0);
                        ln_transfers   :=
                            NVL (ln_transfers, 0) + NVL (m.transfers, 0);
                        ln_Ending_Balance   :=
                              NVL (ln_Ending_Balance, 0)
                            + NVL (m.Ending_Balance, 0);

                        --Spot Rates Calculations
                        ln_begin_bal_spot   :=
                              NVL (ln_begin_bal_spot, 0)
                            + (NVL (ln_Opening_Balance, 0) * NVL (ln_begin_spot_rate, 1));
                        ln_end_bal_spot   :=
                              NVL (ln_end_bal_spot, 0)
                            + (NVL (ln_Ending_Balance, 0) * NVL (ln_end_spot_rate, 1));
                        ln_net_trans   :=
                              NVL (ln_Ending_Balance, 0)
                            - (NVL (ln_Opening_Balance, 0) + +NVL (ln_Additions, 0) + NVL (ln_Capitalizations, 0) + NVL (ln_transfers, 0));

                        IF NVL (ln_net_trans, 0) = 0
                        THEN
                            ln_net_trans   := NULL;
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        '----------------------------------------------------------------------------------------------------------');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Project Number 	::' || m.project_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Project Name   	::' || m.project_name);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Task Number    	::' || l_task_num);

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Begin Balance  	::'
                        || TO_CHAR (ln_Opening_Balance,
                                    'FM999G999G999G999D99'));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Additions    	::'
                        || TO_CHAR (ln_Additions, 'FM999G999G999G999D99'));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Capitalizations ::'
                        || TO_CHAR (ln_Capitalizations,
                                    'FM999G999G999G999D99'));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Transfers    	::'
                        || TO_CHAR (ln_transfers, 'FM999G999G999G999D99'));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Ending Balance  ::'
                        || TO_CHAR (ln_Ending_Balance,
                                    'FM999G999G999G999D99'));

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Begin_bal_spotrate ::'
                        || TO_CHAR (ln_begin_bal_spot,
                                    'FM999G999G999G999D99'));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'End_bal_spotrate   ::'
                        || TO_CHAR (ln_end_bal_spot, 'FM999G999G999G999D99'));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Net FX Translation ::'
                        || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99'));

                    /*End change as part of ENHC0012843 on 01-Nov-2016 */
                    apps.fnd_file.put_line (
                        apps.fnd_file.output,
                           m.project_number
                        || CHR (9)
                        || m.project_name
                        || CHR (9)
                        || l_task_num
                        || CHR (9)
                        || rec.book_type_code
                        || CHR (9)
                        || NVL (ln_project_account, 12160)        --CCR0008086
                        || CHR (9)
                        || TO_CHAR (TO_DATE (p_from_period, 'MON-RR'),
                                    'MON-RRRR')
                        || CHR (9)
                        || TO_CHAR (TO_DATE (p_to_period, 'MON-RRRR'),
                                    'MON-RRRR')
                        || CHR (9)
                        || TO_CHAR (ln_Opening_Balance,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_begin_bal_spot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_Additions, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_transfers, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_Capitalizations,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_Ending_Balance,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_end_bal_spot, 'FM999G999G999G999D99')
                        || CHR (9)
                        || NVL (l_func_currency, p_currency)
                        || CHR (9)
                        || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99'));

                    --Totals
                    ln_additions_tot           :=
                        NVL (ln_additions_tot, 0) + NVL (m.Additions, 0);
                    ln_capitalizations_tot     :=
                          NVL (ln_capitalizations_tot, 0)
                        + NVL (m.Capitalizations, 0);
                    ln_transfers_tot           :=
                        NVL (ln_transfers_tot, 0) + NVL (m.transfers, 0);
                    ln_begin_bal_fun_tot       :=
                          NVL (ln_begin_bal_fun_tot, 0)
                        + NVL (ln_Opening_Balance, 0);
                    ln_begin_bal_spot_tot      :=
                          NVL (ln_begin_bal_spot_tot, 0)
                        + NVL (ln_begin_bal_spot, 0);
                    ln_end_bal_fun_tot         :=
                          NVL (ln_end_bal_fun_tot, 0)
                        + NVL (ln_Ending_Balance, 0);
                    ln_end_bal_spot_tot        :=
                          NVL (ln_end_bal_spot_tot, 0)
                        + NVL (ln_end_bal_spot, 0);
                    ln_net_trans_tot           :=
                        NVL (ln_net_trans_tot, '') + NVL (ln_net_trans, '');
                END LOOP;

                IF l_total_flag = 'Y'
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
                        || 'Total'
                        || CHR (9)
                        || TO_CHAR (ln_begin_bal_fun_tot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_begin_bal_spot_tot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_additions_tot, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_transfers_tot, 'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_capitalizations_tot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_end_bal_fun_tot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || TO_CHAR (ln_end_bal_spot_tot,
                                    'FM999G999G999G999D99')
                        || CHR (9)
                        || NULL
                        || CHR (9)
                        || TO_CHAR (ln_net_trans_tot, 'FM999G999G999G999D99'));
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log_prc ('Error in main cursor-loop:' || SQLERRM);
            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc ('Error in get_project_cip_dtls_prc:' || SQLERRM);
    END;

    --END Added as per version 1.3

    /* Below Procedure 'get_project_cip_prc' is 'NOT IN USE', its
       replaced with above procedure 'get_project_cip_dtls_prc' as per version 1.3*/
    PROCEDURE get_project_cip_prc (p_book           IN VARCHAR2,
                                   p_currency       IN VARCHAR2,
                                   p_from_period    IN VARCHAR2,
                                   p_to_period      IN VARCHAR2,
                                   p_project_type   IN VARCHAR2  -- CCR0008086
                                                               )
    IS
        ln_begin_bal                 NUMBER;
        ln_begin_bal_fun             NUMBER;
        ln_begin_bal_spot            NUMBER;
        ln_begin_trans               NUMBER;
        ln_additions                 NUMBER;
        ln_additions_fun             NUMBER;
        ln_capital_fun               NUMBER;
        ln_capitalizations           NUMBER;
        ln_end_bal                   NUMBER;
        ln_end_bal_fun               NUMBER;
        ln_end_bal_spot              NUMBER;
        ln_end_trans                 NUMBER;
        ln_net_trans                 NUMBER;
        ln_begin_bal_tot             NUMBER := 0;
        ln_begin_bal_fun_tot         NUMBER := 0;
        ln_begin_bal_spot_tot        NUMBER := 0;
        ln_begin_trans_tot           NUMBER := 0;
        ln_additions_tot             NUMBER := 0;
        ln_capitalizations_tot       NUMBER := 0;
        ln_end_bal_tot               NUMBER := 0;
        ln_end_bal_fun_tot           NUMBER := 0;
        ln_end_bal_spot_tot          NUMBER := 0;
        ln_end_trans_tot             NUMBER := 0;
        ld_begin_date                DATE;
        ld_end_date                  DATE;
        ln_begin_spot_rate           NUMBER;
        ln_end_spot_rate             NUMBER;
        l_func_currency              VARCHAR2 (10);
        ln_begin_bal_fun_add         NUMBER;
        ln_begin_bal_fun_cap         NUMBER;
        ln_end_bal_fun_add           NUMBER;
        ln_end_bal_fun_cap           NUMBER;
        ln_from_period_ctr           NUMBER;
        ln_to_period_ctr             NUMBER;
        l_total_flag                 VARCHAR2 (1);
        ln_begin_bal_fun_sub_tot     NUMBER := 0;
        ln_begin_bal_spot_sub_tot    NUMBER := 0;
        ln_additions_sub_tot         NUMBER := 0;
        ln_capitalizations_sub_tot   NUMBER := 0;
        ln_end_bal_sub_tot           NUMBER := 0;
        ln_end_bal_fun_sub_tot       NUMBER := 0;
        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
        ln_net_trans_tot             NUMBER := 0;
        ln_net_trans_sub_tot         NUMBER := 0;
        ln_transfers_fun             NUMBER := 0;
        ln_transfers                 NUMBER := 0;
        ln_transfers_sub_tot         NUMBER := 0;
        ln_transfers_tot             NUMBER := 0;
        l_task_num                   VARCHAR2 (25);
        ln_end_bal_Net_fx            NUMBER := 0;
        /*End change as part of ENHC0012843 on 01-Nov-2016 */
        /*Start change as part of ENHC0013056 on 25-Jan-2017 */
        ln_common_end_spot_rate      NUMBER;
        /*End change as part of ENHC0013056 on 25-Jan-2017 */
        /*Start change as part of ENHC0013056 on 05-Apr-2017 */
        ln_additions_spot            NUMBER := 0;
        ln_transfers_spot            NUMBER := 0;
        ln_capitalization_spot       NUMBER := 0;
        /*End change as part of ENHC0013056 on 05-Apr-2017 */
        ln_project_account           VARCHAR2 (100);              --CCR0008086
        ln_project_id                NUMBER;                      --CCR0008086
        ln_task_id                   NUMBER;                      --CCR0008086

        CURSOR cur_ending_bal (p_book_type_code VARCHAR2, p_end_date VARCHAR2, p_ln_from_period_ctr NUMBER
                               , p_ln_to_period_ctr NUMBER)
        IS
              SELECT project_num, project_name, task_num
                FROM (SELECT DISTINCT NVL (p.segment1, '') AS Project_num, NVL (p.name, '') AS project_name, NVL (t.task_number, '') AS task_num
                        FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei
                       WHERE     t.project_id = p.project_id
                             AND ei.project_id = p.project_id
                             AND ei.task_id = t.task_id
                             AND ei.org_id =
                                 (SELECT org_id
                                    FROM pa_implementations_all
                                   WHERE book_type_code = p_book_type_code)
                             AND ei.expenditure_item_date <= p_end_date
                             AND ((p.attribute1 = p_project_type) OR (p.attribute1 IS NULL AND p_project_type = 'Non Special') OR (1 = 1 AND NVL (p_project_type, 'All') = 'All')) --CCR0008086
                      UNION
                      SELECT DISTINCT NVL (p.segment1, '') AS Project_num, NVL (p.name, '') AS project_name, NVL (t.task_number, '') AS task_num
                        FROM pa_projects_all p, pa_tasks t, pa_project_asset_lines_all pal
                       WHERE     t.project_id = p.project_id
                             AND pal.project_id = p.project_id
                             AND pal.task_id = t.task_id
                             AND pal.transfer_status_code = 'T'
                             AND pal.org_id =
                                 (SELECT org_id
                                    FROM pa_implementations_all
                                   WHERE book_type_code = p_book_type_code)
                             AND fa_period_name IN
                                     (SELECT period_name
                                        FROM fa_deprn_periods
                                       WHERE     book_type_code =
                                                 p_book_type_code
                                             AND period_counter BETWEEN p_ln_from_period_ctr
                                                                    AND p_ln_to_period_ctr)
                             AND ((p.attribute1 = p_project_type) OR (p.attribute1 IS NULL AND p_project_type = 'Non Special') OR (1 = 1 AND p_project_type = 'All')) --CCR0008086
                      /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                      UNION
                      SELECT DISTINCT NVL (p.segment1, '') AS Project_num, NVL (p.name, '') AS project_name, '0' AS task_num
                        FROM pa_projects_all p, pa_project_asset_lines_all pal
                       WHERE     pal.project_id = p.project_id
                             AND pal.task_id = 0
                             AND pal.transfer_status_code = 'T'
                             AND pal.org_id =
                                 (SELECT org_id
                                    FROM pa_implementations_all
                                   WHERE book_type_code = p_book_type_code)
                             AND fa_period_name IN
                                     (SELECT period_name
                                        FROM fa_deprn_periods
                                       WHERE     book_type_code =
                                                 p_book_type_code
                                             AND period_counter BETWEEN p_ln_from_period_ctr
                                                                    AND p_ln_to_period_ctr)
                             AND ((p.attribute1 = p_project_type) OR (p.attribute1 IS NULL AND p_project_type = 'Non Special') OR (1 = 1 AND p_project_type = 'All')) --CCR0008086
                                                                                                                                                                     )
            ORDER BY project_num, task_num;
    /*End change as part of ENHC0012843 on 01-Nov-2016 */
    BEGIN
        print_log_prc ('Print CIP details');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (apps.fnd_file.output, 'Project CIP Section');
        apps.fnd_file.put_line (apps.fnd_file.output, ' ');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
               'Project Number'
            || CHR (9)
            || 'Project Name'
            || CHR (9)
            || 'Task Number'
            || CHR (9)
            || 'Asset Book Name '
            || CHR (9)
            || 'GL Account '
            || CHR (9)
            || 'From Date'
            || CHR (9)
            || 'To Date'
            || CHR (9)
            || 'Begin Balance in <Functional Currency>'
            || CHR (9)
            || 'Begin Balance <USD> at Spot Rate'
            || CHR (9)
            || 'Additions'
            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
            || CHR (9)
            || 'Transfers'
            /*End change as part of ENHC0012843 on 01-Nov-2016 */
            || CHR (9)
            || 'Capitalizations'
            || CHR (9)
            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
            || 'End Balance in <Functional Currency>'
            || CHR (9)
            || 'End Balance <USD> at Spot Rate'
            || CHR (9)
            || 'Currency'
            || CHR (9)
            || 'Net FX Translation'/*End change as part of ENHC0012843 on 01-Nov-2016 */
                                   );

        FOR rec
            IN (SELECT book_type_code
                  FROM FA_BOOK_CONTROLS_SEC
                 WHERE     book_type_code = NVL (p_book, book_type_code)
                       AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE)
        LOOP
            l_total_flag      := 'N';

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

            print_log_prc ('ld_begin_date:: ' || ld_begin_date);
            print_log_prc ('ld_end_date  :: ' || ld_end_date);

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

            g_from_currency   := l_func_currency;

            fnd_file.put_line (fnd_file.LOG,
                               'l_func_currency ::' || l_func_currency);
            fnd_file.put_line (fnd_file.LOG,
                               'g_from_currency ::' || g_from_currency);
            fnd_file.put_line (fnd_file.LOG,
                               'g_to_currency ::' || g_to_currency);
            fnd_file.put_line (fnd_file.LOG, 'p_currency ::' || p_currency);

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

            /*Start change as part of ENHC0013056 on 25-Jan-2017 */
            --Moved the complete logic inside begin balance loop
            /*
            IF (p_currency <> l_func_currency) THEN
              BEGIN
                SELECT conversion_rate
                INTO ln_begin_spot_rate
                FROM gl_daily_rates
                WHERE from_currency =
                  (SELECT currency_code
                  FROM gl_sets_of_books gsob,
                    fa_book_controls fbc
                  WHERE gsob.set_of_books_id              = fbc.set_of_books_id
                  AND fbc.book_type_code                  = rec.book_type_code
                  AND NVL (date_ineffective, SYSDATE + 1) > SYSDATE
                  )
                AND to_currency             = 'USD'
                AND TRUNC (conversion_date) =
                  (SELECT TRUNC (calendar_period_open_date) - 1
                  FROM fa_deprn_periods
                  WHERE period_name  = p_from_period
                  AND book_type_code = rec.book_type_code
                  )
                AND conversion_type = 'Spot';
              EXCEPTION
              WHEN NO_DATA_FOUND THEN
                ln_begin_spot_rate := NULL;
                fnd_file.put_line(fnd_file.log,'Spot rate is not defined');
              END;
            */
            /*End change as part of ENHC0013056 on 25-Jan-2017 */
            IF (p_currency <> l_func_currency)
            THEN
                BEGIN
                    SELECT conversion_rate
                      /*Start change as part of ENHC0013056 on 25-Jan-2017 */
                      --INTO ln_end_spot_rate
                      INTO ln_common_end_spot_rate
                      /*End change as part of ENHC0013056 on 25-Jan-2017 */
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
                        ln_common_end_spot_rate   := NULL;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Spot rate is not defined');
                END;
            ELSE
                ln_common_end_spot_rate   := NULL;
            END IF;

            --  fnd_file.put_line(fnd_file.log,'ln_begin_spot_rate ::'||ln_begin_spot_rate);
            fnd_file.put_line (
                fnd_file.LOG,
                'ln_common_end_spot_rate ::' || ln_common_end_spot_rate);

            IF (ld_begin_date IS NOT NULL AND ld_end_date IS NOT NULL)
            THEN
                ln_begin_bal_fun_sub_tot     := 0;
                ln_begin_bal_spot_sub_tot    := 0;
                ln_additions_sub_tot         := 0;
                ln_capitalizations_sub_tot   := 0;
                ln_end_bal_sub_tot           := 0;
                ln_end_bal_fun_sub_tot       := 0;
                ln_transfers_sub_tot         := 0;
                ln_net_trans_sub_tot         := 0; -- Added as part of ENHC0012883 on 15-Dec-2016

                BEGIN
                    FOR m IN cur_ending_bal (rec.book_type_code, ld_end_date, ln_from_period_ctr
                                             , ln_to_period_ctr)
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                            '----------------------------------------------------------------------------------------------------------');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Project Number ::' || m.project_num);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Project Name   ::' || m.project_name);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Task Number    ::' || m.task_num);

                        l_total_flag        := 'Y';

                        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                        IF m.task_num = '0'
                        THEN
                            l_task_num   := NULL;
                        ELSE
                            l_task_num   := m.task_num;
                        END IF;

                        /*End change as part of ENHC0012843 on 01-Nov-2016 */
                        --Calculating end Calculation,
                        ln_end_bal          := 0;
                        ln_end_bal_fun      := 0;

                        /*Start change as part of ENHC0013056 on 25-Jan-2017 */
                        --Commented below section as end balance will be calculated using below formula
                        --End_Balance= Begin_Balance+Additions+Transfers-Capitalization
                        /*
                         BEGIN
                              SELECT SUM (NVL (project_burdened_cost, 0)),
                                     SUM (NVL (acct_burdened_cost, 0))
                                INTO ln_end_bal, ln_end_bal_fun
                                FROM pa_projects_all p,
                                     pa_tasks t,
                                     pa_expenditure_items_all ei,
                                     pa_expenditures_all x,
                                     pa_project_types_all pt
                               WHERE     t.project_id = p.project_id
                                     AND ei.project_id = p.project_id
                                     AND p.project_type = pt.project_type
                                     AND p.org_id = pt.org_id
                                AND p.segment1 = m.project_num
                                AND p.name = m.project_name
                                AND t.task_number =m.task_num
                                     AND ei.task_id = t.task_id
                                     AND ei.expenditure_id = x.expenditure_id
                                     AND ei.org_id =
                                            (SELECT org_id
                                               FROM pa_implementations_all
                                              WHERE book_type_code = rec.book_type_code)
                                     AND ei.expenditure_item_date <= ld_end_date
                                     AND DECODE (pt.project_type_class_code,
                                                 'CAPITAL', ei.billable_flag,
                                                 NULL) = 'Y'
                                     AND NOT EXISTS
                                                (SELECT 1
                                                   FROM pa_project_asset_line_details pald,
                                                        pa_project_asset_lines_all pal
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
                           print_log_prc ('ln_end_bal                       ::' || ln_end_bal);
                           print_log_prc ('ln_end_bal_fun                   ::' || ln_end_bal_fun);

                           EXCEPTION
                              WHEN OTHERS
                              THEN
                                 print_log_prc ('Error fetching End Balance:' || SQLERRM);
                           END;
                           */
                        /*End change as part of ENHC0013056 on 25-Jan-2017 */
                        ---*START*Calculating BEGIN Balance
                        BEGIN
                            /*Start change as part of ENHC0013056 on 25-Jan-2017 */
                            ln_begin_bal         := 0;
                            ln_begin_bal_fun     := 0;
                            ln_begin_spot_rate   := NULL;
                            ln_end_spot_rate     := NULL;
                            ln_begin_bal_spot    := 0;
                            ln_end_bal_spot      := 0;

                            --
                            --
                            /* Start of Change as part of CCR0007020 */
                            /*
                            FOR begin_bal_rec IN
                                  (SELECT pcdl.expenditure_item_id,NVL (pcdl.project_burdened_cost, 0) proj_burdened_cost,NVL (pcdl.acct_burdened_cost, 0)acct_burdened_cost,pcdl.DENOM_CURRENCY_CODE,NVL (pcdl.denom_burdened_cost, 0) denom_burdened_cost
                             FROM pa_projects_all p,
                               pa_tasks t,
                               pa_expenditure_items_all ei,
                               pa_expenditures_all x,
                               pa_project_types_all pt,
                               pa_cost_distribution_lines_all pcdl
                             WHERE t.project_id    = p.project_id
                             AND ei.project_id     = p.project_id
                             AND p.project_type    = pt.project_type
                             AND p.org_id          = pt.org_id
                             AND ei.task_id        = t.task_id
                             AND ei.expenditure_id = x.expenditure_id
                             AND pcdl.project_id = ei.project_id
                             AND pcdl.task_id = ei.task_id
                             AND pcdl.expenditure_item_id = ei.expenditure_item_id
                             AND pcdl.billable_flag = 'Y'
                             AND pcdl.gl_date < ld_begin_date
                           AND p.segment1             =m.project_num
                             AND p.name                 =m.project_name
                             AND t.task_number          =m.task_num
                             AND ei.org_id         =
                               (SELECT org_id
                               FROM pa_implementations_all
                               WHERE book_type_code = rec.book_type_code
                               )
                             AND NOT EXISTS
                               (SELECT 1
                               FROM pa_project_asset_line_details pald,
                                 pa_project_asset_lines_all pal
                               WHERE 1                               = 1
                               AND ei.expenditure_item_id            = pald.expenditure_item_id
                               AND pald.project_asset_line_detail_id = pal.project_asset_line_detail_id
                               AND pal.project_id                    = ei.project_id
                               AND pal.fa_period_name      IS NOT NULL
                               AND pald.reversed_flag ='N'
                               AND pal.org_id               = ei.org_id
                               AND pal.transfer_status_code = 'T'
                               AND ((SELECT calendar_period_open_date
                                 FROM fa_deprn_periods
                                 WHERE period_name  = pal.fa_period_name
                                 AND book_type_code = rec.book_type_code) < ld_begin_date)))
                             */
                            /* End of Change as part of CCR0007020 */
                            FOR begin_bal_rec
                                IN (SELECT pcdl.expenditure_item_id, NVL (pcdl.project_burdened_cost, 0) proj_burdened_cost, NVL (pcdl.acct_burdened_cost, 0) acct_burdened_cost,
                                           pcdl.DENOM_CURRENCY_CODE, NVL (pcdl.denom_burdened_cost, 0) denom_burdened_cost
                                      FROM pa_projects_all p, pa_expenditure_items_all pei, apps.pa_tasks t,
                                           apps.pa_cost_distribution_lines_all pcdl
                                     WHERE     pei.EXPENDITURE_ITEM_ID =
                                               pcdl.expenditure_item_id
                                           AND pei.org_id =
                                               (SELECT org_id
                                                  FROM pa_implementations_all
                                                 WHERE book_type_code =
                                                       rec.book_type_code)
                                           AND pei.task_id = t.task_id
                                           AND p.project_id = pei.project_id
                                           AND p.segment1 = m.project_num
                                           AND p.name = m.project_name
                                           AND t.task_number = m.task_num
                                           AND pcdl.billable_flag = 'Y'
                                           AND pcdl.gl_date < ld_begin_date
                                           AND NOT EXISTS
                                                   (-- Query to get  capitalized but not reversed expenditure and pa_project_asset_line_details_id
                                                    SELECT pei1.project_id, t1.task_number, pei1.expenditure_item_id,
                                                           pald1.project_asset_line_detail_id
                                                      FROM pa_projects_all p1, apps.pa_project_asset_line_details pald1, pa_expenditure_items_all pei1,
                                                           apps.pa_tasks t1
                                                     WHERE     pald1.expenditure_item_id =
                                                               pei1.expenditure_item_id
                                                           AND pei1.task_id =
                                                               t1.task_id
                                                           AND pei1.expenditure_item_id =
                                                               pei.expenditure_item_id -- Join from First query used to get expenditure details
                                                           AND p1.project_id =
                                                               pei1.project_id
                                                           AND p1.segment1 =
                                                               m.project_num
                                                           AND p1.name =
                                                               m.project_name
                                                           AND t1.task_number =
                                                               m.task_num
                                                           AND pald1.project_asset_line_detail_id IN
                                                                   (SELECT project_asset_line_detail_id
                                                                      FROM pa_project_asset_lines_all pa, fa_deprn_periods pb
                                                                     WHERE     pa.project_id =
                                                                               p1.project_id
                                                                           AND pa.transfer_status_code =
                                                                               'T'
                                                                           AND pa.REV_PROJ_ASSET_LINE_ID
                                                                                   IS NULL
                                                                           AND pb.book_type_code =
                                                                               rec.book_type_code
                                                                           AND pa.fa_period_name =
                                                                               pb.period_name
                                                                           AND pb.period_counter <
                                                                               ln_from_period_ctr)
                                                           AND NOT EXISTS
                                                                   (SELECT pei2.project_id, t2.task_number, pei2.expenditure_item_id,
                                                                           pald2.project_asset_line_detail_id
                                                                      FROM pa_projects_all p2, apps.pa_project_asset_line_details pald2, pa_expenditure_items_all pei2,
                                                                           apps.pa_tasks t2
                                                                     WHERE     pald2.expenditure_item_id =
                                                                               pei2.expenditure_item_id
                                                                           AND pald2.reversed_flag =
                                                                               'Y'
                                                                           AND pei2.task_id =
                                                                               t2.task_id
                                                                           AND pei2.project_id =
                                                                               p2.project_id
                                                                           AND p2.segment1 =
                                                                               m.project_num
                                                                           AND p2.name =
                                                                               m.project_name
                                                                           AND t2.task_number =
                                                                               m.task_num
                                                                           AND pald2.project_asset_line_detail_id IN
                                                                                   (SELECT project_asset_line_detail_id
                                                                                      FROM pa_project_asset_lines_all pa, fa_deprn_periods pb
                                                                                     WHERE     pa.project_id =
                                                                                               p2.project_id
                                                                                           AND pa.transfer_status_code =
                                                                                               'T'
                                                                                           AND pa.REV_PROJ_ASSET_LINE_ID
                                                                                                   IS NOT NULL
                                                                                           AND pb.book_type_code =
                                                                                               rec.book_type_code
                                                                                           AND pa.fa_period_name =
                                                                                               pb.period_name
                                                                                           AND pb.period_counter <
                                                                                               ln_from_period_ctr
                                                                                           AND pei1.expenditure_item_id =
                                                                                               pei2.expenditure_item_id -- Join to get capitalized but not reversed entries
                                                                                           AND pald1.project_asset_line_detail_id =
                                                                                               pald2.project_asset_line_detail_id -- Join to get capitalized but not reversed entries
                                                                                                                                 ))
                                                           AND EXISTS
                                                                   (SELECT pei3.project_id, t3.task_number, pei3.expenditure_item_id,
                                                                           pald3.project_asset_line_detail_id
                                                                      FROM pa_projects_all p3, apps.pa_project_asset_line_details pald3, pa_expenditure_items_all pei3,
                                                                           apps.pa_tasks t3
                                                                     WHERE     pald3.expenditure_item_id =
                                                                               pei3.expenditure_item_id
                                                                           AND pei3.task_id =
                                                                               t3.task_id
                                                                           AND pei3.project_id =
                                                                               p3.project_id
                                                                           AND p3.segment1 =
                                                                               m.project_num
                                                                           AND p3.name =
                                                                               m.project_name
                                                                           AND t3.task_number =
                                                                               m.task_num
                                                                           AND pald3.project_asset_line_detail_id IN
                                                                                   (SELECT project_asset_line_detail_id
                                                                                      FROM pa_project_asset_lines_all pa, fa_deprn_periods pb
                                                                                     WHERE     pa.project_id =
                                                                                               p3.project_id
                                                                                           AND pa.transfer_status_code =
                                                                                               'T'
                                                                                           AND pa.REV_PROJ_ASSET_LINE_ID
                                                                                                   IS NULL
                                                                                           AND pb.book_type_code =
                                                                                               rec.book_type_code
                                                                                           AND pa.fa_period_name =
                                                                                               pb.period_name
                                                                                           AND pb.period_counter <
                                                                                               ln_from_period_ctr)
                                                                           AND NOT EXISTS
                                                                                   (SELECT pei4.project_id, t4.task_number, pei4.expenditure_item_id,
                                                                                           pald4.project_asset_line_detail_id
                                                                                      FROM pa_projects_all p4, apps.pa_project_asset_line_details pald4, pa_expenditure_items_all pei4,
                                                                                           apps.pa_tasks t4
                                                                                     WHERE     pald4.expenditure_item_id =
                                                                                               pei4.expenditure_item_id
                                                                                           AND pald4.reversed_flag =
                                                                                               'Y'
                                                                                           AND pei4.task_id =
                                                                                               t4.task_id
                                                                                           AND pei4.project_id =
                                                                                               p4.project_id
                                                                                           AND p4.segment1 =
                                                                                               m.project_num
                                                                                           AND p4.name =
                                                                                               m.project_name
                                                                                           AND t4.task_number =
                                                                                               m.task_num
                                                                                           AND pald4.project_asset_line_detail_id IN
                                                                                                   (SELECT project_asset_line_detail_id
                                                                                                      FROM pa_project_asset_lines_all pa, fa_deprn_periods pb
                                                                                                     WHERE     pa.project_id =
                                                                                                               p4.project_id
                                                                                                           AND pa.transfer_status_code =
                                                                                                               'T'
                                                                                                           AND pa.REV_PROJ_ASSET_LINE_ID
                                                                                                                   IS NOT NULL
                                                                                                           AND pb.book_type_code =
                                                                                                               rec.book_type_code
                                                                                                           AND pa.fa_period_name =
                                                                                                               pb.period_name
                                                                                                           AND pei3.EXPENDITURE_ITEM_ID =
                                                                                                               pei4.EXPENDITURE_ITEM_ID --Join to get capitalized but not reversed entries
                                                                                                           AND pald3.project_asset_line_detail_id =
                                                                                                               pald4.project_asset_line_detail_id --Join to get capitalized but not reversed entries
                                                                                                           AND pb.period_counter <
                                                                                                               ln_from_period_ctr)))))
                            LOOP
                                --
                                --
                                ln_begin_bal   :=
                                      ln_begin_bal
                                    + begin_bal_rec.proj_burdened_cost;
                                ln_begin_bal_fun   :=
                                      ln_begin_bal_fun
                                    + begin_bal_rec.acct_burdened_cost;

                                --
                                --
                                IF (begin_bal_rec.denom_currency_code <> g_to_currency)
                                THEN
                                    BEGIN
                                        SELECT conversion_rate
                                          INTO ln_begin_spot_rate
                                          FROM gl_daily_rates
                                         WHERE     from_currency =
                                                   begin_bal_rec.denom_currency_code
                                               AND to_currency = 'USD'
                                               AND TRUNC (conversion_date) =
                                                   (SELECT TRUNC (calendar_period_open_date) - 1
                                                      FROM fa_deprn_periods
                                                     WHERE     period_name =
                                                               p_from_period
                                                           AND book_type_code =
                                                               rec.book_type_code)
                                               AND conversion_type = 'Spot';
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_begin_spot_rate   := NULL;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                'Spot rate is not defined');
                                    END;
                                ELSE
                                    ln_begin_spot_rate   := NULL;
                                END IF;

                                --
                                --
                                IF (begin_bal_rec.denom_currency_code <> g_to_currency)
                                THEN
                                    BEGIN
                                        SELECT conversion_rate
                                          INTO ln_end_spot_rate
                                          FROM gl_daily_rates
                                         WHERE     from_currency =
                                                   begin_bal_rec.denom_currency_code
                                               AND to_currency = 'USD'
                                               AND TRUNC (conversion_date) =
                                                   (SELECT TRUNC (calendar_period_close_date)
                                                      FROM fa_deprn_periods
                                                     WHERE     period_name =
                                                               p_to_period
                                                           AND book_type_code =
                                                               rec.book_type_code)
                                               AND conversion_type = 'Spot';
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_end_spot_rate   := NULL;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                'Spot rate is not defined');
                                    END;
                                ELSE
                                    ln_end_spot_rate   := NULL;
                                END IF;

                                --
                                --
                                IF    begin_bal_rec.denom_currency_code =
                                      'USD'
                                   OR (p_currency = l_func_currency)
                                THEN
                                    /* Start of Change as part of CCR0007020 */
                                    --ln_begin_bal_spot := NVL(ln_begin_bal_spot,0)+NVL(begin_bal_rec.denom_burdened_cost,0) *1;
                                    --ln_end_bal_spot   := NVL(ln_end_bal_spot,0)+NVL(begin_bal_rec.denom_burdened_cost,0) *1;
                                    ln_begin_bal_spot   :=
                                          NVL (ln_begin_bal_spot, 0)
                                        + NVL (
                                              begin_bal_rec.acct_burdened_cost,
                                              0);
                                    ln_end_bal_spot   :=
                                          NVL (ln_end_bal_spot, 0)
                                        + NVL (
                                              begin_bal_rec.acct_burdened_cost,
                                              0);
                                /* End of Change as part of CCR0007020 */
                                ELSE
                                    /* Start of Change as part of CCR0007020 */
                                    --ln_begin_bal_spot := NVL(ln_begin_bal_spot,0) + (begin_bal_rec.acct_burdened_cost*NVL(ln_begin_spot_rate,1));
                                    --ln_end_bal_spot   := NVL(ln_end_bal_spot,0) + (begin_bal_rec.acct_burdened_cost*NVL(ln_end_spot_rate,1));
                                    ln_begin_bal_spot   :=
                                          NVL (ln_begin_bal_spot, 0)
                                        + (begin_bal_rec.denom_burdened_cost * NVL (ln_begin_spot_rate, 1));
                                    ln_end_bal_spot   :=
                                          NVL (ln_end_bal_spot, 0)
                                        + (begin_bal_rec.denom_burdened_cost * NVL (ln_end_spot_rate, 1));
                                /* End of Change as part of CCR0007020 */
                                END IF;

                                --
                                --
                                print_log_prc (
                                    '*******************************************************************');
                                print_log_prc (
                                       'expenditure_item_id                     ::'
                                    || begin_bal_rec.expenditure_item_id);
                                print_log_prc (
                                       'proj_burdened_cost                      ::'
                                    || begin_bal_rec.proj_burdened_cost);
                                print_log_prc (
                                       'acct_burdened_cost                      ::'
                                    || begin_bal_rec.acct_burdened_cost);
                                print_log_prc (
                                       'Entered_currency                        ::'
                                    || begin_bal_rec.denom_currency_code);

                                IF (begin_bal_rec.denom_currency_code <> g_to_currency)
                                THEN
                                    print_log_prc (
                                           'Begin Balance spot rate for '
                                        || begin_bal_rec.denom_currency_code
                                        || ' to'
                                        || ' USD :: '
                                        || ln_begin_spot_rate);
                                    print_log_prc (
                                           'End   Balance spot rate for '
                                        || begin_bal_rec.denom_currency_code
                                        || ' to'
                                        || ' USD :: '
                                        || ln_end_spot_rate);
                                END IF;

                                print_log_prc (
                                    '*******************************************************************');
                            END LOOP;
                        --
                        --
                        /* SELECT SUM (NVL (pcdl.project_burdened_cost, 0)),
                           SUM (NVL (pcdl.acct_burdened_cost, 0))
                         INTO ln_begin_bal,
                           ln_begin_bal_fun
                         FROM pa_projects_all p,
                           pa_tasks t,
                           pa_expenditure_items_all ei,
                           pa_expenditures_all x,
                           pa_project_types_all pt,
                           pa_cost_distribution_lines_all pcdl -- Added on 03-OCT
                         WHERE t.project_id    = p.project_id
                         AND ei.project_id     = p.project_id
                         AND p.project_type    = pt.project_type
                         AND p.org_id          = pt.org_id
                         AND ei.task_id        = t.task_id
                         AND ei.expenditure_id = x.expenditure_id
                         -- Start: Added on 03-OCT
                         --
                         AND pcdl.project_id = ei.project_id
                         AND pcdl.task_id = ei.task_id
                         AND pcdl.expenditure_item_id = ei.expenditure_item_id
                         AND pcdl.billable_flag = 'Y'
                         AND pcdl.gl_date < ld_begin_date
                         --
                         -- End: Added on 03-OCT
                       AND p.segment1             =m.project_num
                         AND p.name                 =m.project_name
                         AND t.task_number          =m.task_num
                         AND ei.org_id         =
                           (SELECT org_id
                           FROM pa_implementations_all
                           WHERE book_type_code = rec.book_type_code
                           )
                         -- AND ei.expenditure_item_date  < ld_begin_date -- Commented on 03-OCT
                         -- AND DECODE (pt.project_type_class_code, 'CAPITAL', ei.billable_flag, NULL) = 'Y' -- Commented on 03-OCT
                         AND NOT EXISTS
                           (SELECT 1
                           FROM pa_project_asset_line_details pald,
                             pa_project_asset_lines_all pal
                           WHERE 1                               = 1
                           AND ei.expenditure_item_id            = pald.expenditure_item_id
                           AND pald.project_asset_line_detail_id = pal.project_asset_line_detail_id
                           AND pal.project_id                    = ei.project_id
                           AND pal.fa_period_name      IS NOT NULL
                          --Start change as part of ENHC0012883 on 15-Dec-2016
                           AND pald.reversed_flag ='N'
                         --End change as part of ENHC0012883 on 15-Dec-2016
                           AND pal.org_id               = ei.org_id
                           AND pal.transfer_status_code = 'T'
                           AND ((SELECT calendar_period_open_date
                             FROM fa_deprn_periods
                             WHERE period_name  = pal.fa_period_name
                             AND book_type_code = rec.book_type_code) < ld_begin_date)
                           );
                           */
                        /*End change as part of ENHC0013056 on 25-Jan-2017 */
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                print_log_prc (
                                       'Error fetching Begin Balance:'
                                    || SQLERRM);
                        END;

                        --Calculating Capitalizations
                        BEGIN
                            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                            IF m.task_num = '0'
                            THEN
                                SELECT SUM (pal.current_asset_cost) * -1 amt, SUM (pal.current_asset_cost * gdr.conversion_rate) * -1 conv_amt
                                  INTO ln_capitalizations, ln_capital_fun
                                  FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                                       pa_project_types_all pta, gl_daily_rates gdr
                                 WHERE     1 = 1
                                       AND pal.transfer_status_code = 'T'
                                       AND pal.org_id = pia.org_id
                                       AND pia.book_type_code =
                                           rec.book_type_code
                                       AND pal.project_id = ppa.project_id
                                       AND pal.org_id = ppa.org_id
                                       AND ppa.project_type =
                                           pta.project_type
                                       AND ppa.org_id = pta.org_id
                                       AND gdr.conversion_date(+) =
                                           TRUNC (pal.gl_date)
                                       AND gdr.conversion_type(+) =
                                           'Corporate'
                                       AND gdr.from_currency(+) =
                                           l_func_currency
                                       AND gdr.to_currency(+) = p_currency
                                       AND ppa.segment1 = m.project_num
                                       AND ppa.name = m.project_name
                                       AND pal.task_id = '0'
                                       AND fa_period_name IN
                                               (SELECT period_name
                                                  FROM fa_deprn_periods
                                                 WHERE     book_type_code =
                                                           rec.book_type_code
                                                       AND period_counter BETWEEN ln_from_period_ctr
                                                                              AND ln_to_period_ctr);

                                /*Start change as part of ENHC0013056 on 05-Apr-2017 */
                                ln_capitalization_spot   := 0;

                                IF     (p_currency <> NVL (l_func_currency, 'X'))
                                   AND ln_capitalizations IS NOT NULL
                                THEN
                                    BEGIN
                                        --
                                        --
                                        FOR rec_cap
                                            IN (SELECT NVL (
                                                           pcdl.denom_burdened_cost,
                                                           0)
                                                           denom_burdened_cost,
                                                       DECODE (
                                                           pcdl.denom_currency_code,
                                                           'USD', 1,
                                                           (SELECT conversion_rate
                                                              FROM gl_daily_rates
                                                             WHERE     from_currency =
                                                                       pcdl.denom_currency_code
                                                                   AND to_currency =
                                                                       'USD'
                                                                   AND TRUNC (
                                                                           conversion_date) =
                                                                       ld_end_date
                                                                   AND conversion_type =
                                                                       'Spot'))
                                                           spot_rate
                                                  FROM pa_projects_all p, pa_expenditure_items_all ei, pa_expenditures_all x,
                                                       pa_project_types_all pt, pa_cost_distribution_lines_all pcdl
                                                 WHERE     ei.project_id =
                                                           p.project_id
                                                       AND p.project_type =
                                                           pt.project_type
                                                       AND p.org_id =
                                                           pt.org_id
                                                       AND ei.expenditure_id =
                                                           x.expenditure_id
                                                       AND pcdl.project_id =
                                                           ei.project_id
                                                       AND pcdl.task_id =
                                                           ei.task_id
                                                       AND pcdl.expenditure_item_id =
                                                           ei.expenditure_item_id
                                                       AND pcdl.billable_flag =
                                                           'Y'
                                                       AND pcdl.gl_date BETWEEN ld_begin_date
                                                                            AND ld_end_date
                                                       AND p.segment1 =
                                                           m.project_num
                                                       AND p.name =
                                                           m.project_name
                                                       AND ei.org_id =
                                                           (SELECT org_id
                                                              FROM pa_implementations_all
                                                             WHERE book_type_code =
                                                                   rec.book_type_code)
                                                       AND EXISTS
                                                               (SELECT 1
                                                                  FROM pa_project_asset_line_details pald, pa_project_asset_lines_all pal
                                                                 WHERE     1 =
                                                                           1
                                                                       AND ei.expenditure_item_id =
                                                                           pald.expenditure_item_id
                                                                       AND pald.project_asset_line_detail_id =
                                                                           pal.project_asset_line_detail_id
                                                                       AND pal.project_id =
                                                                           ei.project_id
                                                                       AND pal.fa_period_name
                                                                               IS NOT NULL
                                                                       AND pald.reversed_flag =
                                                                           'N'
                                                                       AND pal.org_id =
                                                                           ei.org_id
                                                                       AND pal.transfer_status_code =
                                                                           'T'))
                                        LOOP
                                            ln_capitalization_spot   :=
                                                  ln_capitalization_spot
                                                + (rec_cap.denom_burdened_cost * rec_cap.spot_rate);
                                        END LOOP;

                                        ln_capitalization_spot   :=
                                            ln_capitalization_spot * -1;
                                        --
                                        --
                                        print_log_prc (
                                               'ln_capitalization_spot ::'
                                            || ln_capitalization_spot);
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_capitalization_spot   := 0;
                                        WHEN OTHERS
                                        THEN
                                            ln_capitalization_spot   := 0;
                                            print_log_prc (
                                                   'Error in fetching spot rate for capitalizations ::'
                                                || SQLERRM);
                                    END;
                                END IF;
                            /*End change as part of ENHC0013056 on 05-Apr-2017 */
                            ELSE
                                /*End change as part of ENHC0012843 on 01-Nov-2016 */
                                ln_capitalization_spot   := 0;

                                SELECT SUM (pal.current_asset_cost) * -1 amt, SUM (pal.current_asset_cost * gdr.conversion_rate) * -1 conv_amt
                                  INTO ln_capitalizations, ln_capital_fun
                                  FROM pa_project_asset_lines_all pal, pa_implementations_all pia, pa_projects_all ppa,
                                       pa_project_types_all pta, gl_daily_rates gdr, pa_tasks t
                                 WHERE     1 = 1
                                       AND pal.transfer_status_code = 'T'
                                       AND t.project_id = ppa.project_id
                                       AND pal.org_id = pia.org_id
                                       AND pia.book_type_code =
                                           rec.book_type_code
                                       AND pal.project_id = ppa.project_id
                                       AND pal.org_id = ppa.org_id
                                       AND ppa.project_type =
                                           pta.project_type
                                       AND ppa.org_id = pta.org_id
                                       AND gdr.conversion_date(+) =
                                           TRUNC (pal.gl_date)
                                       AND gdr.conversion_type(+) =
                                           'Corporate'
                                       AND gdr.from_currency(+) =
                                           l_func_currency
                                       AND gdr.to_currency(+) = p_currency
                                       AND ppa.segment1 = m.project_num
                                       AND ppa.name = m.project_name
                                       AND t.task_number = m.task_num
                                       AND pal.task_id = t.TASK_ID
                                       AND fa_period_name IN
                                               (SELECT period_name
                                                  FROM fa_deprn_periods
                                                 WHERE     book_type_code =
                                                           rec.book_type_code
                                                       AND period_counter BETWEEN ln_from_period_ctr
                                                                              AND ln_to_period_ctr);

                                /*Start change as part of ENHC0013056 on 05-Apr-2017 */
                                --
                                --
                                IF     (p_currency <> NVL (l_func_currency, 'X'))
                                   AND ln_capitalizations IS NOT NULL
                                THEN
                                    BEGIN
                                        --
                                        --
                                        FOR rec_cap
                                            IN (SELECT NVL (
                                                           pcdl.denom_burdened_cost,
                                                           0)
                                                           denom_burdened_cost,
                                                       DECODE (
                                                           pcdl.denom_currency_code,
                                                           'USD', 1,
                                                           (SELECT conversion_rate
                                                              FROM gl_daily_rates
                                                             WHERE     from_currency =
                                                                       pcdl.denom_currency_code
                                                                   AND to_currency =
                                                                       'USD'
                                                                   AND TRUNC (
                                                                           conversion_date) =
                                                                       ld_end_date
                                                                   AND conversion_type =
                                                                       'Spot'))
                                                           spot_rate
                                                  FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                                                       pa_expenditures_all x, pa_project_types_all pt, pa_cost_distribution_lines_all pcdl
                                                 WHERE     ei.project_id =
                                                           p.project_id
                                                       AND p.project_type =
                                                           pt.project_type
                                                       AND p.org_id =
                                                           pt.org_id
                                                       AND ei.expenditure_id =
                                                           x.expenditure_id
                                                       AND pcdl.project_id =
                                                           ei.project_id
                                                       AND pcdl.task_id =
                                                           ei.task_id
                                                       AND pcdl.expenditure_item_id =
                                                           ei.expenditure_item_id
                                                       AND pcdl.billable_flag =
                                                           'Y'
                                                       AND pcdl.gl_date BETWEEN ld_begin_date
                                                                            AND ld_end_date
                                                       AND p.segment1 =
                                                           m.project_num
                                                       AND p.name =
                                                           m.project_name
                                                       AND t.project_id =
                                                           p.project_id
                                                       AND ei.task_id =
                                                           t.task_id
                                                       AND t.task_number =
                                                           m.task_num
                                                       AND ei.org_id =
                                                           (SELECT org_id
                                                              FROM pa_implementations_all
                                                             WHERE book_type_code =
                                                                   rec.book_type_code)
                                                       AND EXISTS
                                                               (SELECT 1
                                                                  FROM pa_project_asset_line_details pald, pa_project_asset_lines_all pal
                                                                 WHERE     1 =
                                                                           1
                                                                       AND ei.expenditure_item_id =
                                                                           pald.expenditure_item_id
                                                                       AND pald.project_asset_line_detail_id =
                                                                           pal.project_asset_line_detail_id
                                                                       AND pal.project_id =
                                                                           ei.project_id
                                                                       AND pal.fa_period_name
                                                                               IS NOT NULL
                                                                       AND pald.reversed_flag =
                                                                           'N'
                                                                       AND pal.org_id =
                                                                           ei.org_id
                                                                       AND pal.transfer_status_code =
                                                                           'T'))
                                        LOOP
                                            ln_capitalization_spot   :=
                                                  ln_capitalization_spot
                                                + (rec_cap.denom_burdened_cost * rec_cap.spot_rate);
                                        END LOOP;

                                        ln_capitalization_spot   :=
                                            ln_capitalization_spot * -1;
                                        --
                                        --
                                        print_log_prc (
                                               'ln_capitalization_spot ::'
                                            || ln_capitalization_spot);
                                    EXCEPTION
                                        WHEN NO_DATA_FOUND
                                        THEN
                                            ln_capitalization_spot   := 0;
                                        WHEN OTHERS
                                        THEN
                                            ln_capitalization_spot   := 0;
                                            print_log_prc (
                                                   'Error in fetching spot rate for capitalizations ::'
                                                || SQLERRM);
                                    END;
                                END IF;
                            /*End change as part of ENHC0013056 on 05-Apr-2017 */
                            --
                            --
                            END IF; /*Added as part of ENHC0012843 on 01-Nov-2016 */

                            /*Start change as part of ENHC0012883 on 15-Dec-2016 */
                            --        IF ln_capitalizations IS NOT NULL AND ln_capital_fun IS NULL
                            IF     ln_capitalizations IS NOT NULL
                               AND ln_capital_fun IS NULL
                            /*End change as part of ENHC0012883 on 15-Dec-2016 */
                            THEN
                                print_log_prc (
                                       'Corporate rate not defined between '
                                    || l_func_currency
                                    || ' and '
                                    || p_currency);
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                print_log_prc (
                                       'Error fetching Capitalization:'
                                    || SQLERRM);
                        END;

                        /*Start change as part of ENHC0012883 on 15-Dec-2016 */
                        /*
                        IF (p_currency <> NVL (l_func_currency, 'X'))
                          THEN
                             ln_additions := ln_additions_fun;
                             ln_capitalizations := ln_capital_fun;
                          END IF;
                        */
                        /*End change as part of ENHC0012883 on 15-Dec-2016 */
                        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                        BEGIN
                            /*              SELECT SUM (NVL (pcdl.burdened_cost, 0) * gdr.conversion_rate),
                                  SUM (NVL (pcdl.burdened_cost, 0))
                                INTO ln_transfers_fun,
                                  ln_transfers
                                FROM pa_projects_all p,
                                  pa_tasks t,
                                  pa_expenditure_items_all ei,
                                  pa_expenditures_all x,
                                  pa_project_types_all pt,
                                  pa_implementations_all pia,
                                  gl_daily_rates gdr,
                                  pa_cost_distribution_lines_all pcdl
                                WHERE t.project_id         = p.project_id
                                AND ei.project_id          = p.project_id
                                AND p.project_type         = pt.project_type
                                AND p.org_id               = pt.org_id
                                AND ei.task_id             = t.task_id
                                AND ei.expenditure_id      = x.expenditure_id
                                AND ei.org_id              = pia.org_id
                                AND gdr.conversion_type(+) = 'Corporate'
                                AND gdr.from_currency(+)   = l_func_currency
                                AND gdr.to_currency(+)     = p_currency
                                AND gdr.conversion_date(+) = TRUNC(ei.expenditure_item_date)
                                AND pia.book_type_code(+)  = rec.book_type_code
                                AND p.segment1             =m.project_num
                                AND p.name                 =m.project_name
                                AND t.task_number          =m.task_num
                                AND pcdl.project_id = ei.project_id
                                AND pcdl.task_id = ei.task_id
                                AND ei.transaction_source IN ('XXDO_PROJECT_TRANSFER_OUT','XXDO_PROJECT_TRANSFER_IN')
                                AND pcdl.expenditure_item_id = ei.expenditure_item_id
                                AND pcdl.billable_flag = 'Y'
                                AND pcdl.gl_date BETWEEN ld_begin_date AND ld_end_date;
                            */
                            /*Start change as part of ENHC0013056 on 05-Apr-2017 */
                            ln_transfers_fun   := 0;
                            ln_transfers       := 0;

                            FOR rec_transfers
                                IN (SELECT pcdl.burdened_cost, gdr.conversion_rate, pcdl.denom_currency_code,
                                           pcdl.denom_burdened_cost
                                      FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                                           pa_expenditures_all x, pa_project_types_all pt, pa_implementations_all pia,
                                           gl_daily_rates gdr, pa_cost_distribution_lines_all pcdl
                                     WHERE     t.project_id = p.project_id
                                           AND ei.project_id = p.project_id
                                           AND p.project_type =
                                               pt.project_type
                                           AND p.org_id = pt.org_id
                                           AND ei.task_id = t.task_id
                                           AND ei.expenditure_id =
                                               x.expenditure_id
                                           AND ei.org_id = pia.org_id
                                           AND gdr.conversion_type(+) =
                                               'Corporate'
                                           AND gdr.from_currency(+) =
                                               l_func_currency
                                           AND gdr.to_currency(+) =
                                               p_currency
                                           AND gdr.conversion_date(+) =
                                               TRUNC (
                                                   ei.expenditure_item_date)
                                           AND pia.book_type_code(+) =
                                               rec.book_type_code
                                           AND p.segment1 = m.project_num
                                           AND p.name = m.project_name
                                           AND t.task_number = m.task_num
                                           AND pcdl.project_id =
                                               ei.project_id
                                           AND pcdl.task_id = ei.task_id
                                           AND ei.transaction_source IN
                                                   ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                           AND pcdl.expenditure_item_id =
                                               ei.expenditure_item_id
                                           AND pcdl.billable_flag = 'Y'
                                           AND pcdl.gl_date BETWEEN ld_begin_date
                                                                AND ld_end_date)
                            LOOP
                                --
                                --
                                ln_transfers_fun   :=
                                      ln_transfers_fun
                                    + (NVL (rec_transfers.burdened_cost, 0) * rec_transfers.conversion_rate);
                                ln_transfers   :=
                                      ln_transfers
                                    + NVL (rec_transfers.burdened_cost, 0);

                                --
                                IF     rec_transfers.denom_currency_code =
                                       'USD'
                                   AND (p_currency <> NVL (l_func_currency, 'X'))
                                THEN
                                    ln_transfers_spot   :=
                                          ln_transfers_spot
                                        + rec_transfers.denom_burdened_cost;
                                END IF;
                            --
                            END LOOP;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                print_log_prc (
                                       'Error fetching Transfers Balance:'
                                    || SQLERRM);
                        END;

                        ln_transfers_spot   := 0;

                        IF p_currency <> NVL (l_func_currency, 'X')
                        THEN
                            --
                            --
                            BEGIN
                                --
                                --
                                FOR rec_transfers_spot
                                    IN (SELECT pcdl.denom_currency_code,
                                               pcdl.denom_burdened_cost,
                                               DECODE (
                                                   pcdl.denom_currency_code,
                                                   'USD', 1,
                                                   (SELECT conversion_rate
                                                      FROM gl_daily_rates
                                                     WHERE     from_currency =
                                                               pcdl.denom_currency_code
                                                           AND to_currency =
                                                               'USD'
                                                           AND TRUNC (
                                                                   conversion_date) =
                                                               ld_end_date
                                                           AND conversion_type =
                                                               'Spot')) spot_rate_denom
                                          FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                                               pa_expenditures_all x, pa_project_types_all pt, pa_implementations_all pia,
                                               pa_cost_distribution_lines_all pcdl
                                         WHERE     t.project_id =
                                                   p.project_id
                                               AND ei.project_id =
                                                   p.project_id
                                               AND p.project_type =
                                                   pt.project_type
                                               AND p.org_id = pt.org_id
                                               AND ei.task_id = t.task_id
                                               AND ei.expenditure_id =
                                                   x.expenditure_id
                                               AND ei.org_id = pia.org_id
                                               AND pia.book_type_code(+) =
                                                   rec.book_type_code
                                               AND p.segment1 = m.project_num
                                               AND p.name = m.project_name
                                               AND t.task_number = m.task_num
                                               AND pcdl.project_id =
                                                   ei.project_id
                                               AND pcdl.task_id = ei.task_id
                                               AND ei.transaction_source IN
                                                       ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                               AND pcdl.expenditure_item_id =
                                                   ei.expenditure_item_id
                                               AND pcdl.billable_flag = 'Y'
                                               AND pcdl.gl_date BETWEEN ld_begin_date
                                                                    AND ld_end_date)
                                LOOP
                                    ln_transfers_spot   :=
                                          ln_transfers_spot
                                        + (rec_transfers_spot.denom_burdened_cost * rec_transfers_spot.spot_rate_denom);
                                END LOOP;
                            --
                            --
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    print_log_prc (
                                           'Error in  fetching Transfers(USD spot balance):: '
                                        || SQLERRM);
                            END;
                        --
                        --
                        END IF;

                        --
                        --
                        /*End change as part of ENHC0013056 on 05-Apr-2017 */
                        /*End change as part of ENHC0012843 on 01-Nov-2016 */


                        ---*END*  Calculating BEGIN Balance
                        /* Commented and modified on 03-OCT
                        SELECT SUM (NVL (burden_cost, 0)*gdr.conversion_rate),
                          SUM (NVL (burden_cost, 0)) */
                        /*Start change as part of ENHC0013056 on 05-Apr-2017 */
                        /*   SELECT SUM (NVL (pcdl.burdened_cost, 0) * gdr.conversion_rate),
                             SUM (NVL (pcdl.burdened_cost, 0))
                           INTO ln_additions_fun,
                             ln_additions
                           FROM pa_projects_all p,
                             pa_tasks t,
                             pa_expenditure_items_all ei,
                             pa_expenditures_all x,
                             pa_project_types_all pt,
                             pa_implementations_all pia,
                             gl_daily_rates gdr,
                             pa_cost_distribution_lines_all pcdl -- Added on 03-OCT
                           WHERE t.project_id         = p.project_id
                           AND ei.project_id          = p.project_id
                           AND p.project_type         = pt.project_type
                           AND p.org_id               = pt.org_id
                           AND ei.task_id             = t.task_id
                           AND ei.expenditure_id      = x.expenditure_id
                           AND ei.org_id              = pia.org_id
                           AND gdr.conversion_type(+) = 'Corporate'
                           AND gdr.from_currency(+)   = l_func_currency
                           AND gdr.to_currency(+)     = p_currency
                           AND gdr.conversion_date(+) = TRUNC(ei.expenditure_item_date)
                           AND pia.book_type_code(+)  = rec.book_type_code
                           AND p.segment1             =m.project_num
                           AND p.name                 =m.project_name
                           AND t.task_number          =m.task_num
                           -- Start: Added on 03-OCT
                           --
                           AND pcdl.project_id = ei.project_id
                           AND pcdl.task_id = ei.task_id
                            --Start change as part of ENHC0012843 on 01-Nov-2016
                           AND ei.transaction_source NOT IN ('XXDO_PROJECT_TRANSFER_OUT','XXDO_PROJECT_TRANSFER_IN')
                            --End change as part of ENHC0012843 on 01-Nov-2016
                           AND pcdl.expenditure_item_id = ei.expenditure_item_id
                           AND pcdl.billable_flag = 'Y'
                           AND pcdl.gl_date BETWEEN ld_begin_date AND ld_end_date;
                          */
                        BEGIN
                            --
                            --
                            ln_additions_fun   := 0;
                            ln_additions       := 0;

                            FOR rec_additions
                                IN (SELECT pcdl.burdened_cost, gdr.conversion_rate, pcdl.denom_currency_code,
                                           pcdl.denom_burdened_cost
                                      FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                                           pa_expenditures_all x, pa_project_types_all pt, pa_implementations_all pia,
                                           gl_daily_rates gdr, pa_cost_distribution_lines_all pcdl
                                     WHERE     t.project_id = p.project_id
                                           AND ei.project_id = p.project_id
                                           AND p.project_type =
                                               pt.project_type
                                           AND p.org_id = pt.org_id
                                           AND ei.task_id = t.task_id
                                           AND ei.expenditure_id =
                                               x.expenditure_id
                                           AND ei.org_id = pia.org_id
                                           AND gdr.conversion_type(+) =
                                               'Corporate'
                                           AND gdr.from_currency(+) =
                                               l_func_currency
                                           AND gdr.to_currency(+) =
                                               p_currency
                                           AND gdr.conversion_date(+) =
                                               TRUNC (
                                                   ei.expenditure_item_date)
                                           AND pia.book_type_code(+) =
                                               rec.book_type_code
                                           AND p.segment1 = m.project_num
                                           AND p.name = m.project_name
                                           AND t.task_number = m.task_num
                                           AND pcdl.project_id =
                                               ei.project_id
                                           AND pcdl.task_id = ei.task_id
                                           AND ei.transaction_source NOT IN
                                                   ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                           AND pcdl.expenditure_item_id =
                                               ei.expenditure_item_id
                                           AND pcdl.billable_flag = 'Y'
                                           AND pcdl.gl_date BETWEEN ld_begin_date
                                                                AND ld_end_date)
                            LOOP
                                --
                                --
                                ln_additions_fun   :=
                                      ln_additions_fun
                                    + (NVL (rec_additions.burdened_cost, 0) * rec_additions.conversion_rate);
                                ln_additions   :=
                                      ln_additions
                                    + NVL (rec_additions.burdened_cost, 0);
                            --
                            --
                            END LOOP;
                        --
                        --
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                print_log_prc (
                                       'Error in calculating additions:'
                                    || SQLERRM);
                        END;

                        ln_additions_spot   := 0;

                        IF p_currency <> NVL (l_func_currency, 'X')
                        THEN
                            --
                            --
                            BEGIN
                                --
                                --
                                FOR rec_additions_spot
                                    IN (SELECT pcdl.denom_currency_code,
                                               pcdl.denom_burdened_cost,
                                               DECODE (
                                                   pcdl.denom_currency_code,
                                                   'USD', 1,
                                                   (SELECT conversion_rate
                                                      FROM gl_daily_rates
                                                     WHERE     from_currency =
                                                               pcdl.denom_currency_code
                                                           AND to_currency =
                                                               'USD'
                                                           AND TRUNC (
                                                                   conversion_date) =
                                                               ld_end_date
                                                           AND conversion_type =
                                                               'Spot')) spot_rate_denom
                                          FROM pa_projects_all p, pa_tasks t, pa_expenditure_items_all ei,
                                               pa_expenditures_all x, pa_project_types_all pt, pa_implementations_all pia,
                                               pa_cost_distribution_lines_all pcdl
                                         WHERE     t.project_id =
                                                   p.project_id
                                               AND ei.project_id =
                                                   p.project_id
                                               AND p.project_type =
                                                   pt.project_type
                                               AND p.org_id = pt.org_id
                                               AND ei.task_id = t.task_id
                                               AND ei.expenditure_id =
                                                   x.expenditure_id
                                               AND ei.org_id = pia.org_id
                                               AND pia.book_type_code(+) =
                                                   rec.book_type_code
                                               AND p.segment1 = m.project_num
                                               AND p.name = m.project_name
                                               AND t.task_number = m.task_num
                                               AND pcdl.project_id =
                                                   ei.project_id
                                               AND pcdl.task_id = ei.task_id
                                               AND ei.transaction_source NOT IN
                                                       ('XXDO_PROJECT_TRANSFER_OUT', 'XXDO_PROJECT_TRANSFER_IN')
                                               AND pcdl.expenditure_item_id =
                                                   ei.expenditure_item_id
                                               AND pcdl.billable_flag = 'Y'
                                               AND pcdl.gl_date BETWEEN ld_begin_date
                                                                    AND ld_end_date)
                                LOOP
                                    ln_additions_spot   :=
                                          ln_additions_spot
                                        + (rec_additions_spot.denom_burdened_cost * rec_additions_spot.spot_rate_denom);
                                END LOOP;
                            --
                            --
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    print_log_prc (
                                           'Error in  fetching Additions (USD spot balance):: '
                                        || SQLERRM);
                            END;
                        --
                        --
                        END IF;

                        --
                        --
                        /*Start change as part of ENHC0013056 on 05-Apr-2017 */
                        --
                        -- End: Added on 03-OCT
                        -- AND ei.expenditure_item_date BETWEEN ld_begin_date AND ld_end_date -- Commented on 03-OCT
                        -- AND DECODE (pt.project_type_class_code, 'CAPITAL', ei.billable_flag, NULL) = 'Y'; -- Commented on 03-OCT
                        /*Start change as part of ENHC0012883 on 15-Dec-2016 */
                        print_log_prc (
                               'ln_begin_bal                     ::'
                            || ln_begin_bal);
                        print_log_prc (
                               'ln_begin_bal_fun                 ::'
                            || ln_begin_bal_fun);
                        print_log_prc (
                               'ln_begin_bal_spot                ::'
                            || ln_begin_bal_spot);
                        print_log_prc (
                               'ln_additions                     ::'
                            || ln_additions);
                        print_log_prc (
                               'ln_additions_fun(Corporate Rate) ::'
                            || ln_additions_fun);
                        print_log_prc (
                               'ln_additions_spot                ::'
                            || ln_additions_spot);
                        print_log_prc (
                               'ln_capitalizations               ::'
                            || ln_capitalizations);
                        print_log_prc (
                               'ln_capital_fun(Corporate Rate)   ::'
                            || ln_capital_fun);
                        print_log_prc (
                               'ln_transfers                     ::'
                            || ln_transfers);
                        print_log_prc (
                               'ln_transfers_fun(Corporate Rate) ::'
                            || ln_transfers_fun);
                        print_log_prc (
                               'ln_transfers_spot                ::'
                            || ln_transfers_spot);

                        /*End change as part of ENHC0012883 on 15-Dec-2016 */
                        /*Start change as part of ENHC0013056 on 25-Jan-2017 */
                        /*
                          IF (g_from_currency  = 'USD' AND g_to_currency = 'USD') THEN
                            ln_begin_bal_spot := NVL(ln_begin_bal_fun,0) * NVL(ln_begin_spot_rate,1);
                            ln_end_bal_spot   := NVL(ln_end_bal_fun,0)   * NVL(ln_common_end_spot_rate,1);
                          ELSE
                            ln_begin_bal_spot := NVL(ln_begin_bal_fun,0)  * NVL(ln_begin_spot_rate,1);
                            ln_end_bal_spot   := NVL(ln_end_bal_fun ,0)   * NVL(ln_common_end_spot_rate,1);
                          END IF;
                          print_log_prc ('ln_begin_bal_spot                ::' || ln_begin_bal_spot);
                       */
                        /*End change as part of ENHC0013056 on 25-Jan-2017 */
                        IF (p_currency <> NVL (l_func_currency, 'X'))
                        THEN
                            ln_end_bal_fun       :=
                                  NVL (ln_begin_bal_fun, 0)
                                + NVL (ln_additions, 0)
                                + NVL (ln_transfers, 0)
                                + NVL (ln_capitalizations, 0);

                            /*Start change as part of ENHC0013056 on 25-Jan-2017 */
                            --     ln_end_bal_spot   := NVL(ln_end_bal_fun,0)   * NVL(ln_common_end_spot_rate,1);
                            --   print_log_prc ('ln_end_bal_spot (Temp) ::' || ln_end_bal_spot);
                            --   ln_end_bal_spot    :=NVL(ln_end_bal_spot,0) + ((NVL(ln_additions,0) +NVL(ln_transfers,0)+ NVL(ln_capitalizations,0))*NVL(ln_common_end_spot_rate,1));
                            IF   NVL (ln_begin_bal_fun, 0)
                               + NVL (ln_additions, 0)
                               + NVL (ln_transfers, 0)
                               + NVL (ln_capitalizations, 0) =
                               0
                            THEN
                                ln_end_bal_spot   := 0;
                            ELSE
                                /*Start  change as part of ENHC0013056 on 05-Apr-2017*/
                                --ln_end_bal_spot:=ln_end_bal_spot +((NVL(ln_additions,0) +NVL(ln_transfers,0)+ NVL(ln_capitalizations,0))*NVL(ln_common_end_spot_rate,1));
                                ln_end_bal_spot   :=
                                      ln_end_bal_spot
                                    + ln_additions_spot
                                    + ln_transfers_spot
                                    + ln_capitalization_spot;
                            /*End  change as part of ENHC0013056 on 05-Apr-2017 */
                            END IF;

                            /*End change as part of ENHC0013056 on 25-Jan-2017 */
                            ln_additions         := ln_additions_fun;
                            ln_capitalizations   := ln_capital_fun;
                            ln_transfers         := ln_transfers_fun;
                            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                            ln_net_trans         := NULL;
                            ln_net_trans         :=
                                  NVL (ln_end_bal_spot, 0)
                                - (NVL ((ln_begin_bal_spot), 0) + NVL (ln_additions, 0) + NVL (ln_transfers, 0) + NVL (ln_capitalizations, 0));
                        ELSE
                            /*Start change as part of ENHC0012883 on 15-Dec-2016 */
                            ln_end_bal_fun   :=
                                  NVL (ln_begin_bal_fun, 0)
                                + NVL (ln_additions, 0)
                                + NVL (ln_transfers, 0)
                                + NVL (ln_capitalizations, 0);

                            /*Start change as part of ENHC0013056 on 25-Jan-2017 */
                            --ln_end_bal_spot   := NVL(ln_end_bal_fun,0)   * NVL(ln_common_end_spot_rate,1);
                            -- ln_end_bal_spot   :=NVL(ln_end_bal_spot,0) + ((NVL(ln_additions,0) +NVL(ln_transfers,0)+ NVL(ln_capitalizations,0))*NVL(ln_common_end_spot_rate,1));
                            IF   NVL (ln_begin_bal_fun, 0)
                               + NVL (ln_additions, 0)
                               + NVL (ln_transfers, 0)
                               + NVL (ln_capitalizations, 0) =
                               0
                            THEN
                                ln_end_bal_spot   := 0;
                            ELSE
                                --ln_end_bal_spot:=ln_end_bal_spot+ln_additions_spot+ln_transfers_spot +((NVL(ln_capitalizations,0))*NVL(ln_common_end_spot_rate,1));
                                ln_end_bal_spot   :=
                                      ln_end_bal_spot
                                    + ((NVL (ln_additions, 0) + NVL (ln_transfers, 0) + NVL (ln_capitalizations, 0)) * NVL (ln_common_end_spot_rate, 1));
                            END IF;

                            /*End change as part of ENHC0013056 on 25-Jan-2017 */
                            /*End change as part of ENHC0012883 on 15-Dec-2016 */
                            ln_net_trans   := NULL;
                        /*End change as part of ENHC0012843 on 01-Nov-2016 */
                        END IF;

                        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                        --    ln_end_bal_spot:= NVL(ln_begin_bal_spot,0) + NVL(ln_additions,0) + NVL(ln_capitalizations,0)+NVL(ln_transfers,0);
                        --    ln_end_bal_fun:= NVL(ln_begin_bal_fun,0) + NVL(ln_additions,0) + NVL(ln_capitalizations,0)+NVL(ln_transfers,0);
                        print_log_prc (
                               'ln_end_bal_fun                   ::'
                            || ln_end_bal_fun);
                        print_log_prc (
                               'ln_end_bal_spot                  ::'
                            || ln_end_bal_spot);
                        print_log_prc (
                               'ln_net_trans                     ::'
                            || ln_net_trans);
                        print_log_prc (CHR (13));

                        --CCR0008086
                        BEGIN
                            SELECT project_id
                              INTO ln_project_id
                              FROM pa_projects_all
                             WHERE name = m.project_name;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_project_id   := 0;
                        END;

                        BEGIN
                            SELECT task_id
                              INTO ln_task_id
                              FROM pa_tasks
                             WHERE     task_number = m.task_num
                                   AND project_id = ln_project_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                ln_task_id   := 0;
                        END;

                        --CCR0008086



                        ln_project_account   :=
                            get_cip_cca_account (ln_project_id,
                                                 ln_task_id,
                                                 NULL);           --CCR0008086
                        /*End change as part of ENHC0012843 on 01-Nov-2016 */
                        apps.fnd_file.put_line (
                            apps.fnd_file.output,
                               m.project_num
                            || CHR (9)
                            || m.project_name
                            || CHR (9)
                            || l_task_num
                            || CHR (9)
                            || rec.book_type_code
                            || CHR (9)
                            --||12160  --CCR0008086
                            || NVL (ln_project_account, 12160)    --CCR0008086
                            || CHR (9)
                            || TO_CHAR (TO_DATE (p_from_period, 'MON-RR'),
                                        'MON-RRRR')
                            || CHR (9)
                            || TO_CHAR (TO_DATE (p_to_period, 'MON-RRRR'),
                                        'MON-RRRR')     --TO_CHAR(v_period_to)
                            || CHR (9)
                            || TO_CHAR (ln_begin_bal_fun,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_begin_bal_spot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_additions, 'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_transfers, 'FM999G999G999G999D99') -- Added as part of ENHC0012843 on 01-Nov-2016
                            || CHR (9)
                            || TO_CHAR (ln_capitalizations,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                            || TO_CHAR (ln_end_bal_fun,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_end_bal_spot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || p_currency
                            || CHR (9)
                            || TO_CHAR (ln_net_trans, 'FM999G999G999G999D99')/*End change as part of ENHC0012843 on 01-Nov-2016 */
                                                                             );
                        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                        --   ln_end_bal_tot     := nvl(ln_end_bal_tot,0)            +(NVL(ln_begin_bal_spot,0)+nvl(ln_additions,0)+NVL(ln_transfers,0)+NVL(ln_capitalizations,0));
                        --   ln_end_bal_fun_tot :=nvl(ln_end_bal_fun_tot,0)         +(NVL(ln_begin_bal_fun,0)+NVL(ln_additions,0)+NVL(ln_transfers,0)+NVL(ln_capitalizations,0));
                        ln_end_bal_tot      :=
                              NVL (ln_end_bal_tot, 0)
                            + NVL (ln_end_bal_spot, 0);
                        ln_end_bal_fun_tot   :=
                              NVL (ln_end_bal_fun_tot, 0)
                            + NVL (ln_end_bal_fun, 0);
                        /*End change as part of ENHC0012843 on 01-Nov-2016 */
                        ln_additions_tot    :=
                            NVL (ln_additions_tot, 0) + NVL (ln_additions, 0);
                        ln_begin_bal_fun_tot   :=
                              NVL (ln_begin_bal_fun_tot, 0)
                            + NVL (ln_begin_bal_fun, 0);
                        ln_begin_bal_spot_tot   :=
                              NVL (ln_begin_bal_spot_tot, 0)
                            + NVL (ln_begin_bal_spot, 0);
                        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                        ln_net_trans_tot    :=
                            NVL (ln_net_trans_tot, 0) + NVL (ln_net_trans, 0);
                        ln_transfers_tot    :=
                            NVL (ln_transfers_tot, 0) + NVL (ln_transfers, 0);
                        --  ln_end_bal_sub_tot     := nvl(ln_end_bal_sub_tot,0)            +(NVL(ln_begin_bal_spot,0)+NVL(ln_additions,0)+NVL(ln_transfers,0)+NVL(ln_capitalizations,0));
                        --  ln_end_bal_fun_sub_tot :=nvl(ln_end_bal_fun_sub_tot,0)         +(NVL(ln_begin_bal_fun,0)+NVL(ln_additions,0)+NVL(ln_transfers,0)+NVL(ln_capitalizations,0));
                        ln_end_bal_sub_tot   :=
                              NVL (ln_end_bal_sub_tot, 0)
                            + NVL (ln_end_bal_spot, 0);
                        ln_end_bal_fun_sub_tot   :=
                              NVL (ln_end_bal_fun_sub_tot, 0)
                            + NVL (ln_end_bal_fun, 0);
                        /*End change as part of ENHC0012843 on 01-Nov-2016 */
                        ln_additions_sub_tot   :=
                              NVL (ln_additions_sub_tot, 0)
                            + NVL (ln_additions, 0);
                        ln_begin_bal_fun_sub_tot   :=
                              NVL (ln_begin_bal_fun_sub_tot, 0)
                            + NVL (ln_begin_bal_fun, 0);
                        ln_begin_bal_spot_sub_tot   :=
                              NVL (ln_begin_bal_spot_sub_tot, 0)
                            + NVL (ln_begin_bal_spot, 0);
                        ln_capitalizations_tot   :=
                              NVL (ln_capitalizations_tot, 0)
                            + NVL (ln_capitalizations, 0);
                        ln_capitalizations_sub_tot   :=
                              NVL (ln_capitalizations_sub_tot, 0)
                            + NVL (ln_capitalizations, 0);
                        /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                        ln_net_trans_sub_tot   :=
                              NVL (ln_net_trans_sub_tot, 0)
                            + NVL (ln_net_trans, 0);

                        ln_transfers_sub_tot   :=
                              NVL (ln_transfers_sub_tot, 0)
                            + NVL (ln_transfers, 0);
                    /*End change as part of ENHC0012843 on 01-Nov-2016 */

                    END LOOP;

                    IF l_total_flag = 'Y'
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
                            || 'Total'
                            || CHR (9)
                            || TO_CHAR (ln_begin_bal_fun_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_begin_bal_spot_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_additions_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                            || TO_CHAR (ln_transfers_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            /*End change as part of ENHC0012843 on 01-Nov-2016 */
                            || TO_CHAR (ln_capitalizations_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                            || TO_CHAR (ln_end_bal_fun_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || TO_CHAR (ln_end_bal_sub_tot,
                                        'FM999G999G999G999D99')
                            || CHR (9)
                            || NULL
                            || CHR (9)
                            || TO_CHAR (ln_net_trans_sub_tot,
                                        'FM999G999G999G999D99')/*End change as part of ENHC0012843 on 01-Nov-2016 */
                                                               );
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        print_log_prc (
                            'Error fetching End Balance:' || SQLERRM);
                END;
            END IF;
        END LOOP;

        IF p_book IS NULL
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
                || 'Grand Total'
                || CHR (9)
                || TO_CHAR (ln_begin_bal_fun_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_begin_bal_spot_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_additions_tot, 'FM999G999G999G999D99')
                || CHR (9)
                /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                || TO_CHAR (ln_transfers_tot, 'FM999G999G999G999D99')
                || CHR (9)
                /*End change as part of ENHC0012843 on 01-Nov-2016 */
                || TO_CHAR (ln_capitalizations_tot, 'FM999G999G999G999D99')
                || CHR (9)
                /*Start change as part of ENHC0012843 on 01-Nov-2016 */
                || TO_CHAR (ln_end_bal_fun_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || TO_CHAR (ln_end_bal_tot, 'FM999G999G999G999D99')
                || CHR (9)
                || NULL
                || CHR (9)
                || TO_CHAR (ln_net_trans_tot, 'FM999G999G999G999D99')/*End change as part of ENHC0012843 on 01-Nov-2016 */
                                                                     );
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            print_log_prc ('Error in get_project_cip_prc:' || SQLERRM);
    END;

    PROCEDURE main_detail (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_book IN VARCHAR2, p_currency IN VARCHAR2, p_from_period IN VARCHAR2, p_to_period IN VARCHAR2
                           , p_project_type IN VARCHAR2          -- CCR0008086
                                                       )
    AS
        v_report_date   VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT TO_CHAR (SYSDATE, 'DD-MON-YYYY')
              INTO v_report_date
              FROM sys.DUAL;
        END;

        apps.fnd_file.put_line (apps.fnd_file.output, 'DECKERS CORPORATION');
        apps.fnd_file.put_line (
            apps.fnd_file.output,
            'Report Name :Deckers CIP Roll Forward Detail Report');

        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Report Date - :' || v_report_date);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Starting Period is: ' || p_from_period);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Ending Period is: ' || p_to_period);
        apps.fnd_file.put_line (apps.fnd_file.output,
                                'Project Type is: ' || p_project_type); --CCR0008086

        -- START Changes as per version 1.3
        /*--Commented old one and using new procedure
        get_project_cip_prc ( p_book => p_book, p_currency => p_currency, p_from_period => p_from_period, p_to_period => p_to_period, p_project_type => p_project_type );-- CCR0008086
        */
        get_project_cip_dtls_prc (p_book           => p_book,
                                  p_currency       => p_currency,
                                  p_from_period    => p_from_period,
                                  p_to_period      => p_to_period,
                                  p_project_type   => p_project_type);
    -- END Changes as per version 1.3

    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'sqlerrm:' || SQLERRM);
    END main_detail;

    PROCEDURE print_log_prc (p_msg IN VARCHAR2)
    IS
    BEGIN
        IF p_msg IS NOT NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
        END IF;

        RETURN;
    END print_log_prc;
END XXD_FA_CIP_ROLL_FWD_REPORT_PKG;
/
