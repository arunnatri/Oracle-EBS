--
-- XXDO_WF_PROGRESS_LINES_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_WF_PROGRESS_LINES_PKG"
AS
    PROCEDURE XXDO_WORKFLOW_PROGRESS_MAIN (p_error_code IN OUT NUMBER, p_error_message IN OUT VARCHAR2, P_ORDER_NUMBER IN NUMBER
                                           , P_LINE_STATUS IN VARCHAR2);
END XXDO_WF_PROGRESS_LINES_PKG;
/
