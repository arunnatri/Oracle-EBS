--
-- XXDOAR032_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.XXDOAR032_REP_PKG
AS
    /******************************************************************************
       NAME: XXDOAR032_REP_PKG
       REP NAME:AR Collector Re-Assigning - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       05/31/2013     Shibu        1. Created this package for XXDOAR032_REP_PKG Report
       V1.1     28-APR-2015  BT Technology Team   Retrofit for BT project
    ******************************************************************************/

    PROCEDURE collector_upd (PV_ERRBUF OUT VARCHAR2, PV_RETCODE OUT VARCHAR2, PN_FRM_COLL_ID NUMBER
                             , PN_TO_COLL_ID NUMBER);
END XXDOAR032_REP_PKG;
/
