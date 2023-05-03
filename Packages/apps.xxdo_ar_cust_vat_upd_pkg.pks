--
-- XXDO_AR_CUST_VAT_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:15:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AR_CUST_VAT_UPD_PKG"
AS
    /******************************************************************************
    -- NAME:       XXDO_AR_CUST_VAT_UPD_PKG
    -- PURPOSE:   To define procedures used for customer site-use VAT Number update
    -- REVISIONS:
    -- Ver      Date          Author          Description
    -- -----    ----------    -------------   -----------------------------------
    -- 1.0      24-OCT-2016    Infosys         Initial version
    ******************************************************************************/
    --Procedure to update vat number
    PROCEDURE xxdoar_upd_vat_number;

    --Main procedure
    PROCEDURE main_proc (errbuf       OUT NOCOPY VARCHAR2,
                         retcode      OUT NOCOPY NUMBER);
END XXDO_AR_CUST_VAT_UPD_PKG;
/
