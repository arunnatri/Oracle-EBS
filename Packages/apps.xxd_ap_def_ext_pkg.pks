--
-- XXD_AP_DEF_EXT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_DEF_EXT_PKG"
AS
    --  ####################################################################################################
    --  Package      : XXD_AP_DEF_EXT_PKG
    --  Design       : This package provides Text extract for Deckers Deferred Prepaid Account Extract to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  14-MAY-2021     1.0       Srinath Siricilla              CCR0009308
    --  ####################################################################################################

    --
    -- To be used in query as bind variable
    --
    gn_error   CONSTANT NUMBER := 2;



    PROCEDURE MAIN (errbuf OUT NOCOPY VARCHAR2, retcode OUT NOCOPY NUMBER, p_acctng_date IN VARCHAR2
                    , p_file_path IN VARCHAR2);
END XXD_AP_DEF_EXT_PKG;
/
