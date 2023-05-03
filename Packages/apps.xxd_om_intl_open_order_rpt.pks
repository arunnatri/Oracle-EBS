--
-- XXD_OM_INTL_OPEN_ORDER_RPT  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:16 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_INTL_OPEN_ORDER_RPT"
AS
    /****************************************************************************************
    * Package      : XXD_OM_INTL_OPEN_ORDER_RPT
    * Design       : This package will be used for Deckers Intl Open Orders Report
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name             Comments
    -- ======================================================================================
    -- 29-Aug-2022  1.0        Ramesh BR        Initial Version
    ******************************************************************************************/

    P_FROM_SHIP_DATE    VARCHAR2 (20);
    P_TO_SHIP_DATE      VARCHAR2 (20);
    P_FROM_ORDER_DATE   VARCHAR2 (20);
    P_TO_ORDER_DATE     VARCHAR2 (20);
    P_REGION            VARCHAR2 (240);

    where_clause        VARCHAR2 (1000);

    FUNCTION MAIN_LOAD
        RETURN BOOLEAN;
END XXD_OM_INTL_OPEN_ORDER_RPT;
/
