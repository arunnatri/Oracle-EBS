--
-- XXDO_LPN_PUB  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:16:34 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_LPN_PUB"
AS
    /******************************************************************************/
    /* Name       : Package XXDO_LPN_PUB
    /* Created by : Infosys Ltd.(Karthik Kumar K S)
    /* Created On : 6/9/2016
    /* Description: Package to bundle all custom built functionality related to LPN
    /*              in WMS Org.
    /******************************************************************************/
    /**/
    /******************************************************************************/
    /* Name         : MASS_LPN_UNLOAD_PRC
    /* Description  : Procedure to Mass break down  LPN's from parent LPN
    /******************************************************************************/
    PROCEDURE MASS_LPN_UNLOAD_PRC (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, p_org_id IN NUMBER
                                   , p_lpn_id IN NUMBER);

    /******************************************************************************/
    /* Name         : UNLOAD_LPNS_FROM_DOCK
    /* Description  : Procedure to unload LPN's from Dock Door
    /******************************************************************************/
    PROCEDURE UNLOAD_LPNS_FROM_DOCK (p_out_error_buff OUT VARCHAR2, p_out_error_code OUT NUMBER, p_org_id IN NUMBER
                                     , p_delv_id IN NUMBER);
END XXDO_LPN_PUB;
/
