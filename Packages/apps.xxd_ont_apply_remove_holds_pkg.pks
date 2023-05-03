--
-- XXD_ONT_APPLY_REMOVE_HOLDS_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:28 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ONT_APPLY_REMOVE_HOLDS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_APPLY_REMOVE_HOLDS_PKG
    * Design       : This package will be used TO APPLY /REMOVE holds on the SO.
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
 -- 04-Apr-2022  21.0        Gaurav Joshi
    ******************************************************************************************/
    PROCEDURE main (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_mode IN VARCHAR2);
END XXD_ONT_APPLY_REMOVE_HOLDS_PKG;
/
