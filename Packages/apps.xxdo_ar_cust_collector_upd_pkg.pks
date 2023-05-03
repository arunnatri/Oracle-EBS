--
-- XXDO_AR_CUST_COLLECTOR_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_CUST_COLLECTOR_UPD_PKG"
AS
    /******************************************************************************
    -- NAME:       XXDO_AR_CUST_COLLECTOR_UPD_PKG
    -- PURPOSE:   To define procedures used for updating collector name for EMEA customers
    -- REVISIONS:
    -- Ver      Date          Author             Description
    -- -----    ----------    -------------      -----------------------------------
    -- 1.0      12-DEC-2016    Infosys            Initial version
    -- 1.1      23-JAN-2017    Srinath Siricilla  ENHC0013047
    ******************************************************************************/
    --Procedure to update vat number
    PROCEDURE xxdoar_upd_collector;

    --Main procedure
    PROCEDURE main_proc (errbuf       OUT NOCOPY VARCHAR2,
                         retcode      OUT NOCOPY NUMBER);
END XXDO_AR_CUST_COLLECTOR_UPD_PKG;
/
