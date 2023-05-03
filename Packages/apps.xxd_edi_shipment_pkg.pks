--
-- XXD_EDI_SHIPMENT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:20:00 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_EDI_SHIPMENT_PKG"
    AUTHID CURRENT_USER
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Project         :
    --  Description     :
    --  Module          : xxd_edi_shipment_pkg
    --  File            : xxd_edi_shipment_pkg.pks
    --  Schema          : APPS
    --  Date            : 16-JUL-2015
    --  Version         : 1.0
    --  Author(s)       : Rakesh Dudani [ Suneratech Consulting]
    --  Purpose         : Package used to update the shipment's load id.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  16-JUL-2015     Rakesh Dudani       1.0                             Initial Version
    --
    --
    --  ###################################################################################

    PROCEDURE update_shipment_load_id (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, pv_ship_delivery IN VARCHAR2, pv_dummy_input IN VARCHAR2, pn_ship_del_id IN NUMBER, pv_load_id IN VARCHAR2, pv_tracking_num IN VARCHAR2, pv_waybill IN VARCHAR2, pv_pro_number IN VARCHAR2
                                       , pv_scac IN VARCHAR2);
END xxd_edi_shipment_pkg;
/
