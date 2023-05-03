--
-- XXDOAP009_REP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:11:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoap009_rep_pkg
AS
    /******************************************************************************
       NAME: XXDOAP009_REP_PKG
       REP NAME:AP Parked Invoices - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       1.0       03/07/2011     Shibu        1. Created this package for XXDOAP009_REP_PKG Report
    ******************************************************************************/
    PROCEDURE parked_invoices (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id NUMBER
                               , pn_vendor_id NUMBER, pv_pgrp_id VARCHAR2);
END xxdoap009_rep_pkg;
/
