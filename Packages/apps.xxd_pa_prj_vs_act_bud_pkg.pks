--
-- XXD_PA_PRJ_VS_ACT_BUD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_PA_PRJ_VS_ACT_BUD_PKG
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
    P_OU               VARCHAR2 (100);
    P_PROJECT_TYPE     VARCHAR2 (100);
    P_PROJECT          VARCHAR2 (100);
    P_PROJECT_STATUS   VARCHAR2 (100);
    P_CHANNEL          VARCHAR2 (100);
    P_BRAND            VARCHAR2 (100);
    P_GEO              VARCHAR2 (100);
    P_CURRENCY_TYPE    VARCHAR2 (100);
    P_RUN_TYPE         VARCHAR2 (100);
    P_RUN_BY           VARCHAR2 (100);
    P_RUN_DATE         VARCHAR2 (100);
    gc_where_clause    VARCHAR2 (32767);



    FUNCTION GET_EXP_AMT (p_project_id         IN VARCHAR2,
                          p_task_id            IN NUMBER,
                          p_expenditure_type   IN VARCHAR2,
                          p_currency           IN VARCHAR2,
                          p_capital_flag       IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_CLASS_CODE (p_project_id   IN VARCHAR2,
                             p_category     IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION GET_BUDGET (p_project_id         IN VARCHAR2,
                         p_task_id            IN NUMBER,
                         p_expenditure_type   IN VARCHAR2,
                         p_initial_latest     IN VARCHAR2,
                         p_currency           IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_CMT_COST (p_project_id         IN VARCHAR2,
                           p_task_id            IN NUMBER,
                           p_expenditure_type   IN VARCHAR2,
                           p_currency           IN VARCHAR2,
                           p_calling_level      IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION BEFOREREPORTTRIGGER (p_status IN VARCHAR2)
        RETURN BOOLEAN;

    FUNCTION GET_KEY_MEMBER (p_project_id    IN NUMBER,
                             p_member_type   IN VARCHAR2)
        RETURN VARCHAR2;
END XXD_PA_PRJ_VS_ACT_BUD_PKG;
/
