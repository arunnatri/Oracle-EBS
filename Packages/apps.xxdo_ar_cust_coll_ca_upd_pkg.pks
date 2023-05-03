--
-- XXDO_AR_CUST_COLL_CA_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_CUST_COLL_CA_UPD_PKG"
AS
    /******************************************************************************
    -- NAME:       XXDO_AR_CUST_COLL_CA_UPD_PKG
    -- PURPOSE:   To define procedures used for updating collector and Credit Analyst for customers
    -- REVISIONS:
    -- Ver      Date          Author          Description
    -- -----    ----------    -------------   -----------------------------------
    -- 1.0      26-FEB-2017    Infosys         Initial version
    ******************************************************************************/
    --Procedure to update vat number
    PROCEDURE xxdoar_upd_coll_ca;

    --Main procedure
    PROCEDURE main_proc (errbuf       OUT NOCOPY VARCHAR2,
                         retcode      OUT NOCOPY NUMBER);
END XXDO_AR_CUST_COLL_CA_UPD_PKG;
/
