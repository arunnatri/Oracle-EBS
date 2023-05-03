--
-- XXD_PPM_TIMESHEET_INT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:13 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PPM_TIMESHEET_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_PPM_TIMESHEET_INT_PKG
    * Design       : This package is used for timesheet interface
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name                    Comments
    -- ===============================================================================
    -- 04-Jan-2022  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    FUNCTION open_gl_date (p_exp_item_date IN DATE, p_org_id IN NUMBER)
        RETURN DATE;

    PROCEDURE main (retcode OUT VARCHAR2, errbuff OUT VARCHAR2, p_recipients IN VARCHAR2
                    , p_reprocess IN VARCHAR2);
END xxd_ppm_timesheet_int_pkg;
/
