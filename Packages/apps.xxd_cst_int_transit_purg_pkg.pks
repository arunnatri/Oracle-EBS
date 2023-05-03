--
-- XXD_CST_INT_TRANSIT_PURG_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:19:45 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_CST_INT_TRANSIT_PURG_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_CST_INT_TRANSIT_PURG_PKG
    * Design       : This package Purg The tables
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 23-Sep-2021   1.0        Balavenu Rao        Initial Version (CCR0009519)
    ******************************************************************************************/
    PROCEDURE main_prc (x_errbuf       OUT NOCOPY VARCHAR2,
                        x_retcode      OUT NOCOPY VARCHAR2);
END XXD_CST_INT_TRANSIT_PURG_PKG;
/
