--
-- XXDO_NEGATIVE_ATP_REPORT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:37 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_NEGATIVE_ATP_REPORT_PKG"
IS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_NEGATIVE_ATP_REPORT_PKG.pks
    * Language     : PL/SQL
    * Description  :
    * History      :
    *
    * WHO            WHAT                                    WHEN
    * -------------- --------------------------------------- ---------------
    * BT_TECHNOLOGY        Original version.                       01-Dec-2015
    *
    *
    *******************************************************************************/
    P_ORGANIZATION_NAME   VARCHAR2 (10);
    P_BRAND               VARCHAR2 (10);
    P_STYLE               VARCHAR2 (10);
    P_COLOR               VARCHAR2 (10);
    P_ITEM_SIZE           VARCHAR2 (10);
    P_PLAN_ID             NUMBER;
    P_PLAN_DATE           VARCHAR2 (100);
    P_FROM_DATE           VARCHAR2 (100);
    P_TO_DATE             VARCHAR2 (100);

    FUNCTION beforeReport (P_ORGANIZATION_NAME IN VARCHAR2, P_PLAN_ID IN NUMBER, P_PLAN_DATE IN VARCHAR2
                           , P_FROM_DATE IN VARCHAR2, P_TO_DATE IN VARCHAR2)
        RETURN BOOLEAN;
END XXDO_NEGATIVE_ATP_REPORT_PKG;
/
