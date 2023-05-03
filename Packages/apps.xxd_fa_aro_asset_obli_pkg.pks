--
-- XXD_FA_ARO_ASSET_OBLI_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_ARO_ASSET_OBLI_PKG"
AS
         /****************************************************************************************
* Package      : XXD_FA_ARO_ASSET_OBLI_PKG
* Design       : This package will be used to generate the ARO asset obligation report
* Notes        :
* Modification :
-- ======================================================================================
-- Date         Version#   Name                    Comments
-- ======================================================================================
-- 31-Aug-2021  1.0        Showkath Ali            Initial Version
******************************************************************************************/
    pv_program_mode      VARCHAR2 (100);
    pv_region            VARCHAR2 (100);
    pv_asset_book        VARCHAR2 (100);
    pv_balance_type      VARCHAR2 (10);
    PV_BALANCE_CHECK1    VARCHAR2 (10);
    PV_BALANCE_CHECK2    VARCHAR2 (10);
    pv_financial_year    VARCHAR2 (10);
    --PV_MTD_FINANCIAL_YEAR           VARCHAR2(10);
    PV_MTD_PERIOD_NAME   VARCHAR2 (10);
    sent_to_blackline    VARCHAR2 (10);
    PN_ACC_ADD_ACC       VARCHAR2 (10);
    TEAR_DOWN_OFF_ACC    VARCHAR2 (10);
    GAIN_LOSS_ACC        VARCHAR2 (10);
    TEAR_DOWN_EXP_ACC    VARCHAR2 (10);

    FUNCTION MAIN (pv_program_mode IN VARCHAR2, pv_region IN VARCHAR2, pv_asset_book IN VARCHAR2, pv_financial_year IN VARCHAR2, pv_balance_type IN VARCHAR2, sent_to_blackline IN VARCHAR2
                   , PV_MTD_PERIOD_NAME IN VARCHAR2)
        RETURN BOOLEAN;
END XXD_FA_ARO_ASSET_OBLI_PKG;
/
