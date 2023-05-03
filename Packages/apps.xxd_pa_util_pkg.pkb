--
-- XXD_PA_UTIL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PA_UTIL_PKG"
AS
    /****************************************************************************************
    * Change#      : CCR0008074
    * Package      : XXD_PA_UTIL_PKG
    * Description  : Projects Utility Package (Created for CCR0008074)
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 25-Jul-2019  1.0         Kranthi Bollam          Initial Version
    --
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/

    --Function to return CCA Account value if configured for the project
    --Parameters
    --pn_project_id          IN  NUMBER  Optional
    --pn_task_id             IN  NUMBER  Optional
    --pn_expenditure_item_id IN  NUMBER  Optional
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
END xxd_pa_util_pkg;
/
