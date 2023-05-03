--
-- XXD_PA_TIME_CARD_INTF_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_PA_TIME_CARD_INTF_PKG
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
    -- 07-NOV-2011        1.0        BT Tech Team     Initial development.
    --
    -------------------------------------------------------------------------------
    FUNCTION GET_PROJECT_NUMBER (p_attask_project_ref IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION GET_TASK_NUMBER (p_attask_project_ref IN VARCHAR2)
        RETURN VARCHAR2;

    FUNCTION GET_ORG_ID (p_attask_project_ref IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_EXP_ENDING_DATE (p_time_entered_date IN DATE)
        RETURN DATE;

    FUNCTION GET_EMPLOYEE_NUM (p_employee_ref IN VARCHAR2)
        RETURN NUMBER;

    FUNCTION GET_ORG_NAME (p_employee_ref IN VARCHAR2)
        RETURN VARCHAR2;
END XXD_PA_TIME_CARD_INTF_PKG;
/
