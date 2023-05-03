--
-- XXD_AP_PREPAY_BAL_EXT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:18:39 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_AP_PREPAY_BAL_EXT_PKG"
AS
    --  #########################################################################################
    --  Package      : XXD_AP_PREPAY_BAL_EXT_PKG
    --  Design       : This package provides Text extract for AP Prepayment Balances to BL
    --  Notes        :
    --  Modification :
    --  ======================================================================================
    --  Date            Version#   Name                          Comments
    --  ======================================================================================
    --  22-JUN-2021     1.0        Aravind Kannuri               CCR0009318
    --  #########################################################################################

    -- To be used in query as bind variable
    gn_error   CONSTANT NUMBER := 2;


    PROCEDURE main (errbuf                 OUT NOCOPY VARCHAR2,
                    retcode                OUT NOCOPY NUMBER,
                    p_period_end_date   IN            VARCHAR2,
                    p_region            IN            VARCHAR2,
                    p_org_id            IN            NUMBER,
                    p_file_path         IN            VARCHAR2);
END XXD_AP_PREPAY_BAL_EXT_PKG;
/
