--
-- XXD_PA_PROJ_EXP_INQ_PKG  (Package) 
--
--  Dependencies: 
--   FND_ATTACHED_DOCUMENTS (Synonym)
--   HR_ALL_ORGANIZATION_UNITS_TL (Synonym)
--   HR_OPERATING_UNITS (View)
--   PA_COST_DISTRIBUTION_LINES_ALL (Synonym)
--   PA_EXPENDITURE_ITEMS_ALL (Synonym)
--   PA_PROJECTS_ALL (Synonym)
--   PA_TASKS (Synonym)
--   PER_ALL_PEOPLE_F (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:15 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PA_PROJ_EXP_INQ_PKG"
AS
    /************************************************************************************************
       * Package         : XXD_PA_PROJ_EXP_INQ_PKG
       * Description     : This package is used to get Project Invoice Documents
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date         Version#      Name                       Description
       *-----------------------------------------------------------------------------------------------
       * 18-JUL-2018  1.0           Aravind Kannuri           Initial Version for CCR0007350
       ************************************************************************************************/

    p_entity_name         fnd_attached_documents.entity_name%TYPE := 'AP_INVOICES';
    p_org_id              hr_operating_units.organization_id%TYPE;
    p_proj_id             pa_projects_all.project_id%TYPE;
    p_proj_name           pa_projects_all.name%TYPE;
    p_task_id             pa_tasks.task_id%TYPE;
    p_task_name           pa_tasks.task_name%TYPE;
    p_trans_id            pa_expenditure_items_all.expenditure_item_id%TYPE;
    p_expend_org_id       hr_all_organization_units_tl.organization_id%TYPE;
    p_expend_type         pa_expenditure_items_all.expenditure_type%TYPE;
    p_expend_type_class   pa_expenditure_items_all.expenditure_type%TYPE;
    p_gl_period           pa_cost_distribution_lines_all.gl_period_name%TYPE;
    p_item_from_date      VARCHAR2 (50);
    p_item_to_date        VARCHAR2 (50);
    p_emp_num             per_all_people_f.employee_number%TYPE;
    p_emp_name            per_all_people_f.full_name%TYPE;
    p_trans_source        pa_expenditure_items_all.transaction_source%TYPE;
    p_exp_end_from_date   VARCHAR2 (50);
    p_exp_end_to_date     VARCHAR2 (50);
    p_user_file_path      VARCHAR2 (1000);

    --To fetch Invoices to upload
    FUNCTION upload_inv_docs
        RETURN BOOLEAN;

    --To fetch Invoice documents file path
    FUNCTION get_doc_file_path (p_pk1_value_id IN NUMBER, p_entity_name IN fnd_attached_documents.entity_name%TYPE, p_user_file_path IN VARCHAR2)
        RETURN VARCHAR2;
END xxd_pa_proj_exp_inq_pkg;
/
