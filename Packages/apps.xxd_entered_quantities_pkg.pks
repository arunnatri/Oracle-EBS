--
-- XXD_ENTERED_QUANTITIES_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXD_ENTERED_QUANTITIES_PKG
AS
    /*
     *********************************************************************************************
      * Package         : XXD_ENTERED_QUANTITIES_PKG
      * Author          : BT Technology Team
      * Created         : 24-APRIL-2015
      * Description     :
      *
      * Modification  :
      *-----------------------------------------------------------------------------------------------
      *     Date         Developer             Version     Description
      *-----------------------------------------------------------------------------------------------
      *   24-APRIL-2015  BT Technology Team     V1.1         Development
      ************************************************************************************************/
    PROCEDURE GET_ENTERED_QUANTITIES (P_ERRBUF          OUT VARCHAR2,
                                      P_RETCODE         OUT VARCHAR2,
                                      P_F_DATE       IN     VARCHAR2,
                                      P_T_DATE       IN     VARCHAR2,
                                      P_DEBUG_MODE   IN     CHAR);

    FUNCTION GET_FIRST_MONDAY (P_DATE IN DATE)
        RETURN DATE;
END XXD_ENTERED_QUANTITIES_PKG;
/
