--
-- XXDO_AP_INVOICE_HOLD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:54 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_AP_INVOICE_HOLD_PKG"
AS
    /****************************************************************************
    **
    NAME:       XXDO_AP_INVOICE_HOLD_PKG
    PURPOSE:    This package contains procedures for Invoice Hold Extract
    REVISIONS:
    Ver        Date        Author                   Description
    ---------  ----------  ---------------  ------------------------------------
    1.0        10/11/2016   Infosys                 1. Created this package.
    1.1        04-Feb-2021  Srinath Siricilla/      Updated for CCR0009257
                            Viswanathan Pandian
    ******************************************************************************/
    PROCEDURE main (p_out_var_errbuf       OUT VARCHAR2,
                    p_out_var_retcode      OUT NUMBER,
                    -- Start of Change for CCR0009257
                    p_region            IN     VARCHAR2,
                    p_org_id            IN     NUMBER,
                    p_hold_name         IN     VARCHAR2,
                    p_tax_holds_only    IN     VARCHAR2);
-- End of Change for CCR0009257
END xxdo_ap_invoice_hold_pkg;
/
