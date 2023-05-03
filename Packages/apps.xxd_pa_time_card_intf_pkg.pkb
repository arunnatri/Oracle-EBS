--
-- XXD_PA_TIME_CARD_INTF_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS.XXD_PA_TIME_CARD_INTF_PKG
AS
    --------------------------------------------------------------------------------
    -- Created By              : BT Tech Team
    -- Creation Date           : 07-NOV-2014
    -- Program Name            : XXD_PA_TIME_CARD_INTF_PKG.pkb
    -- Description             : Providing Functions to AtTask to get Oracle values for Employee Time Card Interface from AtTask
    -- Language                : PL/SQL
    --
    -- Revision History:
    -- =============================================================================
    -- Date               Version#    Name            Remarks
    -- =============================================================================
    -- 07-NOV-2011        1.0         BT Tech Team    Initial development.

    --
    -------------------------------------------------------------------------------
    FUNCTION GET_PROJECT_NUMBER (p_attask_project_ref IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_project_c IS
            SELECT segment_value_lookup
              FROM pa_segment_value_lookup_sets pss, pa_segment_value_lookups psv
             WHERE     psv.segment_value_lookup_set_id =
                       pss.segment_value_lookup_set_id
                   AND segment_value_lookup_set_name =
                       'DO_ORACLE_ATTASK_PROJECT_MAP'
                   AND segment_value = p_attask_project_ref;

        lc_project_number   VARCHAR2 (25);
    BEGIN
        lc_project_number   := 0;

        OPEN get_project_c;

        FETCH get_project_c INTO lc_project_number;

        CLOSE get_project_c;

        RETURN NVL (lc_project_number, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_PROJECT_NUMBER;

    FUNCTION GET_TASK_NUMBER (p_attask_project_ref IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_task_c IS
            SELECT task_number
              FROM pa_segment_value_lookup_sets pss, pa_segment_value_lookups psv, pa_projects_all ppa,
                   pa_tasks pt
             WHERE     psv.segment_value_lookup_set_id =
                       pss.segment_value_lookup_set_id
                   AND pt.project_id = ppa.project_id
                   AND segment_value_lookup_set_name =
                       'DO_ORACLE_ATTASK_PROJECT_MAP'
                   AND pt.task_name LIKE '%EMP%TIME%CAPEX%'
                   AND ppa.segment1 = segment_value_lookup
                   AND segment_value = p_attask_project_ref;

        lc_task_number   VARCHAR2 (25);
    BEGIN
        lc_task_number   := 0;

        OPEN get_task_c;

        FETCH get_task_c INTO lc_task_number;

        CLOSE get_task_c;

        RETURN NVL (lc_task_number, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_TASK_NUMBER;

    FUNCTION GET_ORG_ID (p_attask_project_ref IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_org_id_c IS
            SELECT ppa.org_id
              FROM pa_segment_value_lookup_sets pss, pa_segment_value_lookups psv, pa_projects_all ppa
             WHERE     psv.segment_value_lookup_set_id =
                       pss.segment_value_lookup_set_id
                   AND segment_value_lookup_set_name =
                       'DO_ORACLE_ATTASK_PROJECT_MAP'
                   AND ppa.segment1 = segment_value_lookup
                   AND segment_value = p_attask_project_ref;

        ln_org_id   NUMBER;
    BEGIN
        ln_org_id   := 0;

        OPEN get_org_id_c;

        FETCH get_org_id_c INTO ln_org_id;

        CLOSE get_org_id_c;

        RETURN NVL (ln_org_id, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_ORG_ID;

    FUNCTION GET_EXP_ENDING_DATE (p_time_entered_date IN DATE)
        RETURN DATE
    IS
        CURSOR get_exp_ending_c IS
            SELECT TRUNC (DECODE (TO_CHAR (p_time_entered_date, 'd'), 1, p_time_entered_date, NEXT_DAY (p_time_entered_date, 'SUNDAY'))) exp_ending_date
              FROM DUAL;

        ld_exp_end_date   DATE;
    BEGIN
        ld_exp_end_date   := NULL;

        OPEN get_exp_ending_c;

        FETCH get_exp_ending_c INTO ld_exp_end_date;

        CLOSE get_exp_ending_c;

        RETURN ld_exp_end_date;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END GET_EXP_ENDING_DATE;

    FUNCTION GET_EMPLOYEE_NUM (p_employee_ref IN VARCHAR2)
        RETURN NUMBER
    IS
        CURSOR get_emp_number_c IS
            SELECT employee_number
              FROM per_all_people_f
             WHERE     SYSDATE BETWEEN effective_start_date
                                   AND effective_end_date
                   AND attribute3 = p_employee_ref;

        ln_emp_number   NUMBER;
    BEGIN
        ln_emp_number   := 0;

        OPEN get_emp_number_c;

        FETCH get_emp_number_c INTO ln_emp_number;

        CLOSE get_emp_number_c;

        RETURN NVL (ln_emp_number, 0);
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END GET_EMPLOYEE_NUM;

    FUNCTION GET_ORG_NAME (p_employee_ref IN VARCHAR2)
        RETURN VARCHAR2
    IS
        CURSOR get_org_name_c IS
            SELECT segment_value_lookup
              FROM pa_segment_value_lookup_sets pss, pa_segment_value_lookups psv, gl_code_combinations gcc,
                   per_all_people_f ppf, per_all_assignments_f paaf
             WHERE     psv.segment_value_lookup_set_id =
                       pss.segment_value_lookup_set_id
                   AND ppf.person_id = paaf.person_id
                   AND segment_value_lookup_set_name =
                       'DO_EXP_ORG_COST_CENTER'
                   AND segment_value = gcc.segment5
                   AND paaf.default_code_comb_id = gcc.code_combination_id
                   AND ppf.attribute3 = p_employee_ref
                   AND SYSDATE BETWEEN ppf.effective_start_date
                                   AND ppf.effective_end_date
                   AND SYSDATE BETWEEN paaf.effective_start_date
                                   AND paaf.effective_end_date;

        lc_org_name   VARCHAR2 (100);
    BEGIN
        lc_org_name   := 0;

        OPEN get_org_name_c;

        FETCH get_org_name_c INTO lc_org_name;

        CLOSE get_org_name_c;

        RETURN lc_org_name;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END GET_ORG_NAME;
END XXD_PA_TIME_CARD_INTF_PKG;
/
