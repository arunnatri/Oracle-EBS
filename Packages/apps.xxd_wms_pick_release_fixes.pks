--
-- XXD_WMS_PICK_RELEASE_FIXES  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_PICK_RELEASE_FIXES"
    AUTHID CURRENT_USER
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Project         :
    --  Description     :
    --  Module          : xxd_wms_pick_release_fixes
    --  File            : xxd_wms_pick_release_fixes.pks
    --  Schema          : APPS
    --  Date            : 16-JUL-2015
    --  Version         : 1.0
    --  Author(s)       : Rakesh Dudani [ Suneratech Consulting]
    --  Purpose         : Package used to update the shipment priority code.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  01-SEPT-2015     Rakesh Dudani       1.0                             Initial Version
    --
    --
    --  ###################################################################################

    PROCEDURE update_ship_priority (errbuff OUT VARCHAR2, retcode OUT VARCHAR2, p_org_id IN NUMBER);
END xxd_wms_pick_release_fixes;
/
