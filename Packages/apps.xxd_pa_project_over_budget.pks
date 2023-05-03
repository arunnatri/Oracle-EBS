--
-- XXD_PA_PROJECT_OVER_BUDGET  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:24:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxd_pa_project_over_budget
AS
    /*******************************************************************************************************************
     NAME     :   XXD_PA_PROJECT_OVER_BUDGET
     PURPOSE  :   Package called by program 'Deckers: Project Over Budget Alert'
                  Sends email to project managers and PMO with over budget project details

     REVISIONS:
    --------------------------------------------------------------------------------------------------------------------
     Ver No     Developer                                Date                             Description
    --------------------------------------------------------------------------------------------------------------------
     1.0            BT Technology Team                 11-Sep-2014                        Base Version
    *********************************************************************************************************************/
    PROCEDURE send_email (p_sender          VARCHAR2,
                          p_recipient       VARCHAR2,
                          p_subject         VARCHAR2,
                          p_body            VARCHAR2,
                          x_status      OUT VARCHAR2,
                          x_message     OUT VARCHAR2);

    PROCEDURE main (x_errbuf          OUT VARCHAR2,
                    x_retcode         OUT NUMBER,
                    p_debug_flag   IN     VARCHAR2);
END xxd_pa_project_over_budget;
/
