--
-- XXD_WSH_EDI_DIRECTSHIP_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:23 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WSH_EDI_DIRECTSHIP_PKG"
AS
    /************************************************************************************************
       * Package         : XXD_WSH_EDI_DIRECTSHIP_PKG
       * Description     : This package is used for raising dock.door business event
       * Notes           :
       * Modification    :
       *-----------------------------------------------------------------------------------------------
       * Date         Version#      Name                       Description
       *-----------------------------------------------------------------------------------------------
       * 13-MAY-2019  1.0           Showkath Ali               Initial Version
       ************************************************************************************************/
    PROCEDURE main (errbuf OUT VARCHAR2, retcode OUT NUMBER, p_reprocess IN VARCHAR2
                    , p_shipment_id IN NUMBER);
END xxd_wsh_edi_directship_pkg;
/
