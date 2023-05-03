--
-- XXD_FA_ASSET_EXTRACT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_FA_ASSET_EXTRACT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_FA_ASSET_EXTRACT_PKG
    * Design       : This package will be used to fetch the asset details and send to blackline
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 18-May-2021  1.0        Showkath Ali            Initial Version
    ******************************************************************************************/


    PROCEDURE asset_main (p_ERRBUF                OUT VARCHAR2,
                          p_RETCODE               OUT NUMBER,
                          P_BOOK               IN     VARCHAR2,
                          P_PERIOD             IN     VARCHAR2,
                          P_COST_CENTER        IN     VARCHAR2,
                          P_MAJOR_CATEGORY     IN     VARCHAR2,
                          P_MINOR_CATEGORY     IN     VARCHAR2,
                          P_ASSET_COST_GROUP   IN     VARCHAR2,
                          P_GRAND_TOTAL_BY     IN     VARCHAR2,
                          P_CURRENCY           IN     NUMBER,
                          P_PROJECT_TYPE       IN     VARCHAR2,  -- CCR0008086
                          p_file_path          IN     VARCHAR2);

    PROCEDURE MAIN (ERRBUF                  OUT VARCHAR2,
                    RETCODE                 OUT NUMBER,
                    P_BOOK               IN     VARCHAR2,
                    P_PERIOD             IN     VARCHAR2,
                    P_CURRENCY           IN     VARCHAR2,
                    P_ASSET_COST_GROUP   IN     VARCHAR2);

    PROCEDURE FA_RSVLDG_PROC (BOOK IN VARCHAR2, PERIOD IN VARCHAR2);

    --   ERRBUF          OUT VARCHAR2,
    --  RETCODE         OUT NUMBER)
    PROCEDURE ASSET_RSV_REP (P_BOOK       IN VARCHAR2,
                             P_PERIOD     IN VARCHAR2,
                             P_CURRENCY   IN NUMBER);

    PROCEDURE INSERT_INFO (BOOK IN VARCHAR2, START_PERIOD_NAME IN VARCHAR2, END_PERIOD_NAME IN VARCHAR2
                           , REPORT_TYPE IN VARCHAR2);

    PROCEDURE GET_BALANCE (BOOK IN VARCHAR2, DISTRIBUTION_SOURCE_BOOK IN VARCHAR2, PERIOD_PC IN NUMBER, EARLIEST_PC IN NUMBER, PERIOD_DATE IN DATE, ADDITIONS_DATE IN DATE
                           , REPORT_TYPE IN VARCHAR2, BALANCE_TYPE IN VARCHAR2, BEGIN_OR_END IN VARCHAR2);

    PROCEDURE GET_BALANCE_GROUP_BEGIN (BOOK IN VARCHAR2, DISTRIBUTION_SOURCE_BOOK IN VARCHAR2, PERIOD_PC IN NUMBER, EARLIEST_PC IN NUMBER, PERIOD_DATE IN DATE, ADDITIONS_DATE IN DATE
                                       , REPORT_TYPE IN VARCHAR2, BALANCE_TYPE IN VARCHAR2, BEGIN_OR_END IN VARCHAR2);

    PROCEDURE GET_BALANCE_GROUP_END (BOOK IN VARCHAR2, DISTRIBUTION_SOURCE_BOOK IN VARCHAR2, PERIOD_PC IN NUMBER, EARLIEST_PC IN NUMBER, PERIOD_DATE IN DATE, ADDITIONS_DATE IN DATE
                                     , REPORT_TYPE IN VARCHAR2, BALANCE_TYPE IN VARCHAR2, BEGIN_OR_END IN VARCHAR2);

    FUNCTION ASSET_ACCOUNT_FN (P_BOOK IN VARCHAR2, P_ASSET_NUMBER IN VARCHAR2, --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                                                               -- P_CURRENCY       IN   NUMBER
                                                                               P_SOB_ID IN NUMBER
                               , P_PERIOD IN VARCHAR2)
        --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
        RETURN VARCHAR2;

    FUNCTION ASSET_RESERVE_ACCOUNT_FN (P_BOOK IN VARCHAR2, P_PERIOD IN VARCHAR2, P_ASSET_NUMBER IN VARCHAR2
                                       , --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
                                         --P_CURRENCY       IN   NUMBER
                                         P_SOB_ID IN NUMBER)
        --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
        RETURN VARCHAR2;

    --Start modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.1
    FUNCTION ASSET_CATEGORY_FN (P_BOOK           IN VARCHAR2,
                                P_PERIOD         IN VARCHAR2,
                                P_ASSET_NUMBER   IN VARCHAR2)
        RETURN VARCHAR2;

    --End modificaion for Defect 701,Dt 23-Nov-15,By BT Technology Team,V1.2
    --Start modificaion for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.2
    FUNCTION ASSET_RSV_ACCOUNT_NULL_FN (P_BOOK IN VARCHAR2, P_ASSET_NUMBER IN VARCHAR2, P_SOB_ID IN NUMBER
                                        , P_PERIOD IN VARCHAR2)
        RETURN VARCHAR2;
--End modificaion for Defect 701,Dt 04-Dec-15,By BT Technology Team,V1.2
END XXD_FA_ASSET_EXTRACT_PKG;
/
