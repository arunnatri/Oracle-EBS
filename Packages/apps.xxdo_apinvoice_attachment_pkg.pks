--
-- XXDO_APINVOICE_ATTACHMENT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:14:52 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_APINVOICE_ATTACHMENT_PKG"
AS
    /****************************************************************************
    **
    NAME:       XXDO_AP_INVOICE_ATTACHMENT_PKG
    PURPOSE:    This package contains procedure for Invoice Attachment which
                generates an extract for any specific period
    REVISIONS:
    Ver        Date        Author           Description
    ---------  ----------  ---------------  ------------------------------------
    1.0        10/11/2016   Infosys           1. Created this package.
    ******************************************************************************/
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2, P_Inv_Frm IN VARCHAR2
                    , P_Inv_To IN VARCHAR2);
END XXDO_APINVOICE_ATTACHMENT_PKG;
/
