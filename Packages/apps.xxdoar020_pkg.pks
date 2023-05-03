--
-- XXDOAR020_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:01 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS.xxdoar020_pkg
AS
    /******************************************************************************
       NAME: XXDOAR020_PKG
      Program NAME:Create Factored Remittance Batch - Deckers

       REVISIONS:
       Ver        Date        Author           Description
       ---------  ----------  ---------------  ------------------------------------
       -- MODIFICATION HISTORY
    -- Person                          Date                                Comments
    --Shibu Alex                      11-17-2011                           Initial Version
    -- BT Technology Team             11-25-2014                           NO Modifications
    ******************************************************************************/
    PROCEDURE create_receipt_batch (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pd_from_date IN VARCHAR2, pd_to_date IN VARCHAR2, pn_batch_source_id IN NUMBER, pn_org_d IN NUMBER
                                    , pd_receipt_date IN VARCHAR2, pd_gl_date IN VARCHAR2, pn_brand IN VARCHAR2);
END xxdoar020_pkg;
/
