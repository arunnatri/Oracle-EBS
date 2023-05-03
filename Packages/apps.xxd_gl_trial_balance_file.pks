--
-- XXD_GL_TRIAL_BALANCE_FILE  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_TRIAL_BALANCE_FILE"
AS
    /****************************************************************************************
    * Package      : XXD_GL_TRAIL_BALANCE_FILE
    * Design       : This package will be used to purge integration/customization tables
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 24-Jun-2019  1.0        Shivanshu Talwar     Initial Version
    ******************************************************************************************/
    PROCEDURE fetch_gl_balances (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, pv_send_to_bl IN VARCHAR2
                                 , pv_file_path IN VARCHAR2);
END XXD_GL_TRIAL_BALANCE_FILE;
/
