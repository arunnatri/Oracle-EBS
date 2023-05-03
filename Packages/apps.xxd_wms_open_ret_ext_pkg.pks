--
-- XXD_WMS_OPEN_RET_EXT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:17 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_OPEN_RET_EXT_PKG"
AS
    --  #########################################################################################
    --  Package      : XXD_WMS_OPEN_RET_EXT_PKG
    --  Design       : This package provides Text extract for Open Retail Returns Extract to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  09-JUN-2021     1.0        Aravind Kannuri               CCR0009315
    --  #########################################################################################

    -- To be used in query as bind variable
    gn_error   CONSTANT NUMBER := 2;


    PROCEDURE main (errbuf                 OUT NOCOPY VARCHAR2,
                    retcode                OUT NOCOPY NUMBER,
                    p_period_end_date   IN            VARCHAR2,
                    p_org_id            IN            NUMBER,
                    p_addl_report       IN            VARCHAR2,
                    p_file_path         IN            VARCHAR2);
END XXD_WMS_OPEN_RET_EXT_PKG;
/
