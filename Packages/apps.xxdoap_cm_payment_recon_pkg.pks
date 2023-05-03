--
-- XXDOAP_CM_PAYMENT_RECON_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:11:53 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOAP_CM_PAYMENT_RECON_PKG"
AS
    /*******************************************************************************
    * Program Name : XXDOAP_CM_PAYMENT_RECON_PKG
    * Language     : PL/SQL
    * Description  : This package will update bank statement data in interface table from payments
    *
    * History      :
    *
    * WHO                  DESCRIPTION                         WHEN
    * ------------------------------------------------------------------------------------
    * Infosys Team   1.0                                 15-SEP-2016
    * --------------------------------------------------------------------------- */
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT VARCHAR2);
END;
/
