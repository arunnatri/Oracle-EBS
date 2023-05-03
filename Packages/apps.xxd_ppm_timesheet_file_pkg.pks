--
-- XXD_PPM_TIMESHEET_FILE_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PPM_TIMESHEET_FILE_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PPM_TIMESHEET_FILE_PKG
    * Design       : This package is used for timesheet interface
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 04-Jan-2022  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    PROCEDURE process_file (p_recipients   IN     VARCHAR2,
                            x_status          OUT VARCHAR2,
                            x_err_msg         OUT VARCHAR2);
END xxd_ppm_timesheet_file_pkg;
/
