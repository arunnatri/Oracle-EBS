--
-- XXD_GL_CURR_RATES_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_GL_CURR_RATES_EXTRACT_PKG"
AS
         /****************************************************************************************
* Package      : XXD_GL_CURR_RATES_EXTRACT_PKG
* Design       : This package will be used to fetch the daily rates from base table and send to blackline
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 30-Mar-2021  1.0        Showkath Ali            Initial Version
******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    PROCEDURE main (p_errbuf                 OUT VARCHAR2,
                    p_retcode                OUT NUMBER,
                    p_currency            IN     VARCHAR2,
                    p_rate_type           IN     VARCHAR2,
                    p_rate_date           IN     VARCHAR2,
                    p_period_end_date     IN     VARCHAR2,
                    p_conversion_method   IN     VARCHAR2,
                    p_file_path           IN     VARCHAR2);
END XXD_GL_CURR_RATES_EXTRACT_PKG;
/
