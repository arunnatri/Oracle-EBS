--
-- XXDO_SALESREP_PKG1  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDO_SALESREP_PKG1
    AUTHID CURRENT_USER
IS
    /*
  *********************************************************************************************
    * Package         : XXDO_SALESREP_PKG
    * Author          : BT Technology Team
    * Created         : 20-MAR-2015
    * Description     :THIS PACKAGE IS USED  TO INSERT THE SALESREP DATA INTO
    *                  CUSTOM TABLE
    *
    * Modification    :
    *-----------------------------------------------------------------------------------------------
    *     Date         Developer             Version     Description
    *-----------------------------------------------------------------------------------------------
    *     20-MAR-2015 BT Technology Team     V1.1         Development
    ************************************************************************************************/

    PROCEDURE MAIN (X_ERRBUF OUT VARCHAR2, X_RETCODE OUT NUMBER);
END XXDO_SALESREP_PKG1;
/
