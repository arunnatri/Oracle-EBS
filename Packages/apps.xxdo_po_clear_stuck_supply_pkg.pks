--
-- XXDO_PO_CLEAR_STUCK_SUPPLY_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_PO_CLEAR_STUCK_SUPPLY_PKG"
/*
================================================================
 Created By              : Infosys
 Creation Date           : 27-Jan-2017
 File Name               : XXDOPO_CLEAR_STUCK_SUPPLY.pks
 Incident Num            :
 Description             :
 Latest Version          : 1.0

================================================================
 Date               Version#    Name                    Remarks
================================================================
27-Jan-2017         1.0        Infosys

======================================================================================
*/
AS
    PROCEDURE XXDO_PO_CLR_STCK_SUPPLY_PROC (P_RETCODE     OUT NUMBER,
                                            P_ERROR_BUF   OUT VARCHAR2);
END XXDO_PO_CLEAR_STUCK_SUPPLY_PKG;
/
