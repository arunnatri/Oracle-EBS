--
-- XXDOGL006_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:13:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOGL006_PKG
AS
    /******************************************************************************
       NAME: XXDOGL006_PKG
       Program NAme : Chart of Accounts Integration - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0        02/27/2011  Shibu            1. Created this package for GL CCID Integration with Retail
    ******************************************************************************/

    FUNCTION SEGMENT_DESC (p_chart_of_accounts_id IN NUMBER, p_segment IN VARCHAR2, p_value IN VARCHAR2)
        RETURN VARCHAR;

    PROCEDURE MAIN (PV_ERRBUF OUT VARCHAR2, PV_RETCODE OUT VARCHAR2, PV_REPROCESS IN VARCHAR2
                    , PV_FROM_DATE IN VARCHAR2, PV_TO_DATE IN VARCHAR2);
END XXDOGL006_PKG;
/
