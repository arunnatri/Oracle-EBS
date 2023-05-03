--
-- XXD_SEG_DERIVATION_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_SEG_DERIVATION_PKG
AS
    -- =======================================================================================
    -- NAME: XXD_SEG_DERIVATION_PKG.pks
    --
    -- Design Reference:
    --
    -- PROGRAM TYPE :  Package Spec
    -- PURPOSE:
    -- For the account generator work flows
    -- NOTES
    --
    --
    -- HISTORY
    -- =======================================================================================
    --  Date          Author                                Version             Activity
    -- =======================================================================================
    --
    -- 2-Sep-2014     BTDev team      1.0                  Initial Version
    --
    -- =======================================================================================

    FUNCTION get_company_segment (p_org_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_cost_center_segment (p_expenditure_org_id IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_channel_segment (p_projectid IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_brand_segment (p_projectid IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_geo_segment (p_projectid IN NUMBER)
        RETURN NUMBER;

    FUNCTION get_is_task_capitalized (p_expenditureitemid IN NUMBER DEFAULT NULL, p_projectid IN NUMBER DEFAULT NULL, p_taskid IN NUMBER DEFAULT NULL)
        RETURN VARCHAR2;

    PROCEDURE get_is_task_tran_control (
        p_projectid                 IN     NUMBER DEFAULT NULL,
        p_taskid                    IN     NUMBER DEFAULT NULL,
        p_expendituretype           IN     VARCHAR2 DEFAULT NULL,
        px_task_trans_cntrl            OUT VARCHAR2,
        px_task_trans_capitalflag      OUT VARCHAR2);

    PROCEDURE get_is_project_trans_cntrl (
        p_projectid                IN     NUMBER DEFAULT NULL,
        p_expendituretype          IN     VARCHAR2 DEFAULT NULL,
        px_prj_trans_cntrl            OUT VARCHAR2,
        px_prj_trans_capitalflag      OUT VARCHAR2);

    FUNCTION get_exp_type_natural_acct (p_expenditure_type IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_fixed_cip_natural_acct
        RETURN NUMBER;

    FUNCTION check_expense_or_asset (p_unit_price IN NUMBER, p_category_id IN NUMBER, p_currency_code IN VARCHAR2)
        RETURN VARCHAR2;
END XXD_SEG_DERIVATION_PKG;
/
