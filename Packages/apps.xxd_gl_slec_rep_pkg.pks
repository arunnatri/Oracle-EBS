--
-- XXD_GL_SLEC_REP_PKG  (Package) 
--
--  Dependencies: 
--   GL_PERIOD_STATUSES (Synonym)
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_SLEC_REP_PKG"
AS
    /******************************************************************************
     NAME: APPS.XXD_GL_SLEC_REP_PKG
     REP NAME: GL Secondary Ledger Entered Currency Report - Deckers

     REVISIONS:
     Ver       Date       Author          Description
     --------- ---------- --------------- ------------------------------------
     1.0       01/22/19   Madhav Dhurjaty Initial Version - CCR0007749
    ******************************************************************************/
    P_COMPANY             VARCHAR2 (10);
    P_PERIOD_FROM         gl_period_statuses.period_name%TYPE;
    P_PERIOD_TO           gl_period_statuses.period_name%TYPE;
    P_INTERCOMPANY_ONLY   VARCHAR2 (1);
    P_PERIOD_TYPE         VARCHAR2 (10);
    G_PERIOD_SET_NAME     VARCHAR2 (30) DEFAULT 'DO_FY_CALENDAR';

    --
    --
    FUNCTION before_report
        RETURN BOOLEAN;

    --
    --
    FUNCTION after_report
        RETURN BOOLEAN;
END XXD_GL_SLEC_REP_PKG;
/
