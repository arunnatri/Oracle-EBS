--
-- XXDO_GEH_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_GEH_PKG
    AUTHID CURRENT_USER
AS
    -- Purpose :
    -- Public function and procedures
    /***************************************************************************************
      Program    : XXDO_GEH_PKG
      Author     :
      Owner      : APPS
      Modifications:
      -------------------------------------------------------------------------------
      Date           version    Author          Description
      -------------  ------- ----------     -----------------------------------------
      5-Jun-2014     1.0     BT TECH TEAM          Common Utilities
    ***************************************************************************************/

    PROCEDURE record_error (p_module IN VARCHAR2,   --Oracle module short name
                                                  p_cust_account_id IN NUMBER, p_program IN VARCHAR2, --Concurrent program, PLSQL procedure, etc..
                                                                                                      p_error_msg IN VARCHAR2, --SQLERRM
                                                                                                                               p_error_line IN VARCHAR2, --DBMS_UTILITY.FORMAT_ERROR_BACKTRACE
                                                                                                                                                         p_created_by IN NUMBER, --USER_ID
                                                                                                                                                                                 -- p_request_id   IN   NUMBER DEFAULT NULL,     -- concurrent request ID
                                                                                                                                                                                 p_more_info1 IN VARCHAR2 DEFAULT NULL, --additional information for troubleshooting
                                                                                                                                                                                                                        p_more_info2 IN VARCHAR2 DEFAULT NULL, p_more_info3 IN VARCHAR2 DEFAULT NULL
                            , p_more_info4 IN VARCHAR2 DEFAULT NULL);
END XXDO_GEH_PKG;
/
