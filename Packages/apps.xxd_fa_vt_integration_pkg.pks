--
-- XXD_FA_VT_INTEGRATION_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_VT_INTEGRATION_PKG"
AS
    /****************************************************************************************
     * Package      : XXD_FA_VT_INTEGRATION_PKG
     * Design       : This package will be used for FA and VT integration
     * Notes        :
     * Modification :
     -- ======================================================================================
     -- Date         Version#   Name                    Comments
     -- ======================================================================================
     -- 27-DEC-2020  1.0        Tejaswi Gangumalla      Initial Version
     ******************************************************************************************/
    PROCEDURE main (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER);
END;
/
