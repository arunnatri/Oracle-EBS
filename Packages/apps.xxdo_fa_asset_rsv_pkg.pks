--
-- XXDO_FA_ASSET_RSV_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_FA_ASSET_RSV_PKG"
AS
    /*******************************************************************************
    * PROGRAM NAME : XXDO_FA_ASSET_RSV_PKG
    * LANGUAGE     : PL/SQL
    * DESCRIPTION  : THIS PACKAGE WILL GENERATE ASSET RESERVE DETAIL EXTENDED LOCATION
    *                REPORT
    * HISTORY      :
    *
    * WHO                   WHAT              DESC                             WHEN
    * -------------- ---------------------------------------------- ---------------
    * BT TECHNOLOGY TEAM          1.0 - INITIAL VERSION               AUG/6/2014
    * BT TECHNOLOGY TEAM          1.1 - Defect 701                    NOV/23/2014
    * BT TECHNOLOGY TEAM          1.2 - Defect 701                    DEC/4/2014
    * Showkath Ali                1.3 - CCR0008086                    AUG/14/2019
    * --------------------------------------------------------------------------- */
    P_BOOK               VARCHAR2 (100);
    P_PERIOD             VARCHAR2 (100);
    P_CURRENCY           NUMBER;
    P_ASSET_COST_GROUP   VARCHAR2 (100);
    P_COST_CENTER        VARCHAR2 (100);
    P_MAJOR_CATEGORY     VARCHAR2 (100);
    P_MINOR_CATEGORY     VARCHAR2 (100);
    P_GRAND_TOTAL_BY     VARCHAR2 (100);
    P_OUTPUT_TYPE        VARCHAR2 (100);
    P_PROJECT_TYPE       VARCHAR2 (100);                         -- CCR0008086

    --P_SQL_STATEMENT             VARCHAR2(32000);
    FUNCTION XML_MAIN (P_BOOK IN VARCHAR2, P_PERIOD IN VARCHAR2, P_COST_CENTER IN VARCHAR2, P_MAJOR_CATEGORY IN VARCHAR2, P_MINOR_CATEGORY IN VARCHAR2, P_GRAND_TOTAL_BY IN VARCHAR2
                       , P_CURRENCY IN NUMBER, P_ASSET_COST_GROUP IN VARCHAR2, P_PROJECT_TYPE IN VARCHAR2 -- CCR0008086
                                                                                                         )
        RETURN BOOLEAN;

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
END XXDO_FA_ASSET_RSV_PKG;
/
