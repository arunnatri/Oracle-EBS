--
-- XXD_GL_AC_SETTING_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_AC_SETTING_EXTRACT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_GL_AC_SETTING_EXTRACT_PKG
    * Design       : This package will be used to fetch the Account settings from value set and send to blackline
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 29-Mar-2021  1.0        Showkath Ali            Initial Version
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    PROCEDURE main (p_errbuf                 OUT VARCHAR2,
                    p_retcode                OUT NUMBER,
                    p_enabled_flag        IN     VARCHAR2,
                    p_override_last_run   IN     VARCHAR2,
                    p_file_path           IN     VARCHAR2);

    PROCEDURE grouping_main (p_errbuf OUT VARCHAR2, p_retcode OUT NUMBER, p_grouped IN VARCHAR2, p_enabled IN VARCHAR2, p_group_name IN VARCHAR2, p_override_last_run IN VARCHAR2
                             , p_file_path IN VARCHAR2);
END XXD_GL_AC_SETTING_EXTRACT_PKG;
/
