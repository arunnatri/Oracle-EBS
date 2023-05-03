--
-- XXD_PA_PRJ_VS_ACT_BUD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_PA_PRJ_VS_ACT_BUD_PKG
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Technology Team
    -- Creation Date           : 17-NOV-2014
    -- File Name               : XXD_PA_PRJ_VS_ACT_BUD_PKG.pks
    -- Work Order Num          : Report to show capital project budget VS actual
    -- Description             : Report to show capital project budget VS actual
    -- Latest Version          : 1.0
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name                Remarks
    -- =============================================================================
    -- 17-NOV-2014        1.0       BT Technology Team    Initial development.
    --
    -------------------------------------------------------------------------------

    FUNCTION GET_EXP_AMT (p_project_id         IN VARCHAR2,
                          p_task_id            IN NUMBER,
                          p_expenditure_type   IN VARCHAR2,
                          p_currency           IN VARCHAR2,
                          p_capital_flag       IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_expenditure_amt   NUMBER;
    BEGIN
        SELECT SUM (DECODE (p_currency,  'REPORTING', PROJECT_BURDENED_COST,  'FUNCTIONAL', ACCT_BURDENED_COST))
          INTO ln_expenditure_amt
          FROM pa_expenditure_items_all peia, pa_tasks pt
         WHERE     peia.task_id = pt.task_id(+)
               AND peia.project_id = p_project_id
               AND peia.expenditure_type =
                   NVL (p_expenditure_type, peia.expenditure_type)
               AND peia.task_id IN
                       (    SELECT task_id
                              FROM pa_tasks
                        START WITH task_id = NVL (p_task_id, peia.task_id)
                        CONNECT BY NOCYCLE PRIOR task_id = top_task_id)
               AND peia.billable_flag =
                   DECODE (p_capital_flag,
                           'CAPEX', 'Y',
                           'OPEX', 'N',
                           'ALL', peia.billable_flag);

        RETURN NVL (ln_expenditure_amt, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NVL (ln_expenditure_amt, 0);
    END GET_EXP_AMT;

    FUNCTION GET_CLASS_CODE (p_project_id   IN VARCHAR2,
                             p_category     IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_class_code_c IS
            SELECT class_code
              FROM pa_project_classes_v
             WHERE project_id = p_project_id AND class_category = p_category;

        lv_class_code   VARCHAR2 (100);
    BEGIN
        OPEN get_class_code_c;

        FETCH get_class_code_c INTO lv_class_code;

        IF get_class_code_c%NOTFOUND
        THEN
            RETURN 'NA';
        END IF;

        CLOSE get_class_code_c;

        RETURN NVL (lv_class_code, 'NA');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_class_code_c%ISOPEN
            THEN
                CLOSE get_class_code_c;
            END IF;

            FND_FILE.put_line (FND_FILE.LOG,
                               'Exception at GET_CLASS_CODE' || SQLERRM);
            RETURN 'NA';
    END GET_CLASS_CODE;

    FUNCTION GET_BUDGET (p_project_id         IN VARCHAR2,
                         p_task_id            IN NUMBER,
                         p_expenditure_type   IN VARCHAR2,
                         p_initial_latest     IN VARCHAR2,
                         p_currency           IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_budget_c IS
            SELECT ppa.project_currency_code, ppa.projfunc_currency_code, pbv.burdened_cost,
                   TRUNC (pbv.baselined_date) baselined_date
              FROM pa_budget_versions_baselined_v pbv, pa_projects_all ppa
             WHERE     ppa.project_id = pbv.project_id
                   AND ppa.project_id = p_project_id
                   AND pbv.current_flag =
                       DECODE (p_initial_latest,
                               'FINAL', 'Y',
                               pbv.current_flag)
                   AND pbv.version_number =
                       DECODE (p_initial_latest,
                               'INITIAL', 1,
                               pbv.version_number);

        CURSOR get_task_budget IS
              SELECT ppa.project_currency_code, ppa.projfunc_currency_code, SUM (pbl.burdened_cost) burdened_cost,
                     TRUNC (pbv.baselined_date) baselined_date
                FROM pa_budget_lines_v pbl, pa_budget_versions_baselined_v pbv, pa_projects_all ppa
               WHERE     ppa.project_id = pbv.project_id
                     AND pbl.budget_version_id = pbv.budget_version_id
                     AND pbl.project_id = p_project_id
                     AND pbl.task_id = p_task_id
                     AND pbv.current_flag =
                         DECODE (p_initial_latest,
                                 'FINAL', 'Y',
                                 pbv.current_flag)
                     AND pbv.version_number =
                         DECODE (p_initial_latest,
                                 'INITIAL', 1,
                                 pbv.version_number)
            GROUP BY pbv.baselined_date, ppa.project_currency_code, ppa.projfunc_currency_code;

        CURSOR get_exp_budget IS
              SELECT ppa.project_currency_code, ppa.projfunc_currency_code, SUM (pbl.burdened_cost) burdened_cost,
                     TRUNC (pbv.baselined_date) baselined_date
                FROM pa_budget_lines_v pbl, pa_budget_versions_baselined_v pbv, pa_projects_all ppa,
                     pa_resource_list_members prl
               WHERE     ppa.project_id = pbv.project_id
                     AND pbl.budget_version_id = pbv.budget_version_id
                     AND pbl.resource_list_member_id =
                         prl.resource_list_member_id
                     AND pbl.project_id = p_project_id
                     AND prl.expenditure_type = p_expenditure_type
                     AND pbl.task_id = NVL (p_task_id, pbl.task_id)
                     AND pbv.current_flag =
                         DECODE (p_initial_latest,
                                 'FINAL', 'Y',
                                 pbv.current_flag)
                     AND pbv.version_number =
                         DECODE (p_initial_latest,
                                 'INITIAL', 1,
                                 pbv.version_number)
            GROUP BY pbv.baselined_date, ppa.project_currency_code, ppa.projfunc_currency_code,
                     prl.expenditure_type;

        ln_budget            VARCHAR2 (100);
        ln_conv_rate         NUMBER;
        lcu_get_budget_rec   get_budget_c%ROWTYPE;
    BEGIN
        IF p_task_id IS NULL AND p_expenditure_type IS NULL
        THEN
            OPEN get_budget_c;

            FETCH get_budget_c INTO lcu_get_budget_rec;

            CLOSE get_budget_c;
        ELSIF p_task_id IS NOT NULL AND p_expenditure_type IS NULL
        THEN
            OPEN get_task_budget;

            FETCH get_task_budget INTO lcu_get_budget_rec;

            CLOSE get_task_budget;
        ELSIF p_task_id IS NULL AND p_expenditure_type IS NOT NULL
        THEN
            OPEN get_exp_budget;

            FETCH get_exp_budget INTO lcu_get_budget_rec;

            CLOSE get_exp_budget;
        ELSIF p_task_id IS NOT NULL AND p_expenditure_type IS NOT NULL
        THEN
            OPEN get_exp_budget;

            FETCH get_exp_budget INTO lcu_get_budget_rec;

            CLOSE get_exp_budget;
        END IF;

        IF p_currency = 'FUNCTIONAL'
        THEN
            RETURN NVL (lcu_get_budget_rec.burdened_cost, 0);
        ELSIF lcu_get_budget_rec.project_currency_code =
              lcu_get_budget_rec.projfunc_currency_code
        THEN
            RETURN NVL (lcu_get_budget_rec.burdened_cost, 0);
        ELSE
            BEGIN
                SELECT conversion_rate
                  INTO ln_conv_rate
                  FROM gl_daily_rates
                 WHERE     conversion_date =
                           lcu_get_budget_rec.baselined_date
                       AND conversion_type = 'Corporate'
                       AND from_currency =
                           lcu_get_budget_rec.projfunc_currency_code
                       AND to_currency =
                           lcu_get_budget_rec.project_currency_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_conv_rate   := 0;
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Exception in fetching conversion rate from '
                        || lcu_get_budget_rec.projfunc_currency_code
                        || ' to '
                        || lcu_get_budget_rec.project_currency_code
                        || ' on '
                        || lcu_get_budget_rec.baselined_date);
            END;

            RETURN NVL (
                       ROUND (
                           lcu_get_budget_rec.burdened_cost * ln_conv_rate,
                           2),
                       0);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_budget_c%ISOPEN
            THEN
                CLOSE get_budget_c;
            END IF;

            IF get_exp_budget%ISOPEN
            THEN
                CLOSE get_exp_budget;
            END IF;

            IF get_task_budget%ISOPEN
            THEN
                CLOSE get_task_budget;
            END IF;

            FND_FILE.put_line (FND_FILE.LOG,
                               'Exception at GET_BUDGET' || SQLERRM);
            RETURN 0;
    END GET_BUDGET;

    FUNCTION GET_CMT_COST (p_project_id         IN VARCHAR2,
                           p_task_id            IN NUMBER,
                           p_expenditure_type   IN VARCHAR2,
                           p_currency           IN VARCHAR2,
                           p_calling_level      IN VARCHAR2)
        RETURN NUMBER
    IS
        ln_cmt_cost   NUMBER;
    BEGIN
        IF p_calling_level = 'PROJECT'
        THEN
            IF p_currency = 'REPORTING'
            THEN
                BEGIN
                    SELECT SUM (pct.tot_cmt_burdened_cost)
                      INTO ln_cmt_cost
                      FROM pa_commitment_txns pct, pa_txn_accum_details ptad, pa_lookups pl,
                           pa_lookups pl2
                     WHERE     ptad.line_type = 'M'
                           AND ptad.cmt_line_id = pct.cmt_line_id
                           AND pl.lookup_code = pct.line_type
                           AND pl.lookup_type = 'COMMITMENT LINE TYPE'
                           AND pl2.lookup_code = pct.transaction_source
                           AND pl2.lookup_type = 'COMMITMENT TXN SOURCE'
                           AND pct.project_id = p_project_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cmt_cost   := 0;
                END;
            ELSIF p_currency = 'FUNCTIONAL'
            THEN
                BEGIN
                    SELECT SUM (ppac.cmt_burdened_cost_ptd)
                      INTO ln_cmt_cost
                      FROM pa_project_accum_headers pah, pa_project_accum_commitments ppac
                     WHERE     pah.project_accum_id =
                               ppac.project_accum_id(+)
                           AND pah.project_id = p_project_id
                           AND pah.task_id = 0
                           AND pah.resource_list_id = 0;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cmt_cost   := 0;
                END;
            END IF;
        ELSIF p_calling_level = 'TASK'
        THEN
            IF p_currency = 'REPORTING'
            THEN
                BEGIN
                    SELECT SUM (ct.tot_cmt_burdened_cost)
                      INTO ln_cmt_cost
                      FROM pa_commitment_txns ct, pa_txn_accum_details tad, pa_lookups l,
                           pa_lookups l2, pa_tasks t, hr_organization_units o
                     WHERE     tad.line_type = 'M'
                           AND tad.cmt_line_id = ct.cmt_line_id
                           AND l.lookup_code = ct.line_type
                           AND l.lookup_type = 'COMMITMENT LINE TYPE'
                           AND l2.lookup_code = ct.transaction_source
                           AND l2.lookup_type = 'COMMITMENT TXN SOURCE'
                           AND ct.task_id = t.task_id
                           AND ct.organization_id = o.organization_id
                           AND ct.project_id = p_project_id
                           AND ct.task_id IN
                                   (    SELECT task_id
                                          FROM pa_tasks
                                    START WITH task_id =
                                               NVL (p_task_id, ct.task_id)
                                    CONNECT BY NOCYCLE PRIOR task_id =
                                                       top_task_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cmt_cost   := 0;
                END;
            ELSIF p_currency = 'FUNCTIONAL'
            THEN
                BEGIN
                    SELECT SUM (pac.cmt_burdened_cost_ptd)
                      INTO ln_cmt_cost
                      FROM pa_project_accum_headers pah, pa_project_accum_commitments pac
                     -- WHERE pah.task_id          IN (SELECT task_id FROM pa_tasks start with task_id = NVL(p_task_id,pah.task_id) connect by nocycle prior task_id =top_task_id) ---- Commented to fix CRP3 issue on 19-Feb-2015
                     WHERE     pah.task_id = p_task_id -- Added to fix CRP3 issue on 19-Feb-2015
                           AND pah.project_id = p_project_id
                           AND pah.resource_list_id = 0
                           AND pah.project_accum_id = pac.project_accum_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_cmt_cost   := 0;
                END;
            END IF;
        ELSIF p_calling_level IN ('EXPENDITURE', 'TASK-EXPENDITURE')
        THEN
            SELECT SUM (DECODE (p_currency, 'FUNCTIONAL', ct.acct_burdened_cost, ct.tot_cmt_burdened_cost))
              INTO ln_cmt_cost
              FROM pa_commitment_txns ct, pa_txn_accum_details tad, pa_lookups l,
                   pa_lookups l2, pa_tasks t, hr_organization_units o
             WHERE     tad.line_type = 'M'
                   AND tad.cmt_line_id = ct.cmt_line_id
                   AND l.lookup_code = ct.line_type
                   AND l.lookup_type = 'COMMITMENT LINE TYPE'
                   AND l2.lookup_code = ct.transaction_source
                   AND l2.lookup_type = 'COMMITMENT TXN SOURCE'
                   AND ct.task_id = t.task_id
                   AND ct.organization_id = o.organization_id
                   AND ct.project_id = p_project_id
                   AND ct.expenditure_type =
                       NVL (p_expenditure_type, ct.expenditure_type)
                   AND ct.task_id IN
                           (    SELECT task_id
                                  FROM pa_tasks
                            START WITH task_id = NVL (p_task_id, ct.task_id)
                            CONNECT BY NOCYCLE PRIOR task_id = top_task_id);
        END IF;

        RETURN NVL (ln_cmt_cost, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NVL (ln_cmt_cost, 0);
    END GET_CMT_COST;

    FUNCTION BEFOREREPORTTRIGGER (p_status IN VARCHAR2)
        RETURN BOOLEAN
    IS
        lc_profile_value   VARCHAR2 (2);

        CURSOR get_profile_value_c IS
            SELECT fpov1.PROFILE_OPTION_VALUE
              FROM fnd_profile_options_vl fpov, fnd_profile_option_values fpov1
             WHERE     fpov1.profile_option_id = fpov.profile_option_id
                   AND fpov.user_profile_option_name =
                       'PA: Cross Project User -- Update'
                   AND fpov1.level_id = 10003
                   AND level_value = FND_GLOBAL.RESP_ID;
    BEGIN
        gc_where_clause    := NULL;
        lc_profile_value   := NULL;

        OPEN get_profile_value_c;

        FETCH get_profile_value_c INTO lc_profile_value;

        CLOSE get_profile_value_c;

        FND_FILE.PUT_LINE (
            FND_FILE.LOG,
            'Profile Value:' || lc_profile_value || 'Resp id' || FND_GLOBAL.RESP_ID);

        IF lc_profile_value = 'N'
        THEN
            gc_where_clause   :=
                   ' AND EXISTS (SELECT 1 FROM PA_PROJECT_PLAYERS PPP, FND_USER FU'
                || ' WHERE FU.EMPLOYEE_ID = PPP.PERSON_ID AND FU.USER_ID ='
                || FND_GLOBAL.USER_ID
                || ' AND PPP.project_id = ppa.project_id) ';
        ELSE
            gc_where_clause   := 'AND 1 = 1';
        END IF;

        IF p_status = 'Close'
        THEN
            gc_where_clause   :=
                   gc_where_clause
                || ' AND pps.project_status_name = ''Closed''';
        ELSIF p_status = 'Exclude Close'
        THEN
            gc_where_clause   :=
                   gc_where_clause
                || ' AND pps.project_status_name <> ''Closed''';
        END IF;

        FND_FILE.PUT_LINE (FND_FILE.LOG, 'Where Caluse' || gc_where_clause);
        RETURN (TRUE);
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_profile_value_c%ISOPEN
            THEN
                CLOSE get_profile_value_c;
            END IF;

            FND_FILE.put_line (FND_FILE.LOG,
                               'Exception at BEFOREREPORTTRIGGER' || SQLERRM);
            RETURN (FALSE);
    END BEFOREREPORTTRIGGER;

    FUNCTION GET_KEY_MEMBER (p_project_id    IN NUMBER,
                             p_member_type   IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_key_member_c IS
            SELECT PPF.full_name
              FROM pa_project_players ppp, per_all_people_f ppf
             WHERE     ppp.project_id = p_project_id
                   AND ppp.project_role_type =
                       DECODE (p_member_type,
                               'PROJECT MANAGER', 'PROJECT MANAGER',
                               'PROJECT ACCOUNTANT', '1000')
                   AND ppp.person_id = ppf.person_id
                   AND SYSDATE BETWEEN (ppf.effective_start_date)
                                   AND NVL (
                                           ppf.effective_end_date,
                                           TO_DATE ('31-DEC-4712',
                                                    'DD-MON-YYYY'));

        lc_key_member   VARCHAR2 (240);
    BEGIN
        lc_key_member   := NULL;

        OPEN get_key_member_c;

        FETCH get_key_member_c INTO lc_key_member;

        CLOSE get_key_member_c;

        RETURN NVL (lc_key_member, 'NA');
    EXCEPTION
        WHEN OTHERS
        THEN
            IF get_key_member_c%ISOPEN
            THEN
                CLOSE get_key_member_c;
            END IF;

            RETURN 'NA';
    END GET_KEY_MEMBER;
END XXD_PA_PRJ_VS_ACT_BUD_PKG;
/
