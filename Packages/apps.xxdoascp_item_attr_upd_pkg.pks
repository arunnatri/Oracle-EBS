--
-- XXDOASCP_ITEM_ATTR_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:12:26 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDOASCP_ITEM_ATTR_UPD_PKG"
AS
    --  ###################################################################################
    --
    --  System          : Oracle Applications
    --  Subsystem       : ASCP
    --  Project         : [ISC-205] 02003: Supply Planning
    --  Description     : Package for Item Attribute Update Interface
    --  Module          : xxdoascp_item_attr_upd_pkg
    --  File            : xxdoascp_item_attr_upd_pkg
    --  Schema          : APPS
    --  Date            : 28-APR-2015
    --  Version         : 1.0
    --  Author(s)       : BT Technology
    --  Purpose         : Package used to validate the data in the staging table data and load into the item interface table.
    --                        Then calls the item import program to update the item attributes.
    --  dependency      : None
    --  Change History
    --  --------------
    --  Date            Name                Ver     Change                  Description
    --  ----------      --------------      -----   --------------------    ------------------
    --  28-APR-2015    BT Technology        1.0                             Initial Version
    --
    --
    --  ###################################################################################

    /* *****************************************************************************************
      Staging table Status codes and definitions
      *******************************************************************************************
      99  -   Initial load status from flat file into landing Table.
      -1  -   Sucessfully Loaded Into the staging Table.
      0   -   Initial Status  after extraction from Landing Table and before staging table validations.
      1   -   Staging table Errored Records while getting the Necessary ID's
      2   -   Successfully validated and populated the necessary id's to staging table
      3   -   Successfully Processed Records into the Item Interface Tables
      4   -   Records Errored out by API/Interface
      6   -   Data Successfully written into the Base tables
      10  -   Updating the Staging table with the Interface Errors
      50  -   Technical Error Status
      ******************************************************************************************/
    PROCEDURE submit_item_import (pv_orgid IN VARCHAR2, pv_allorgsflag IN VARCHAR2, pv_validateitemsflag IN VARCHAR2, pv_processitemsflag IN VARCHAR2, pv_deleteprocessedflag IN VARCHAR2, pv_setprocessid IN VARCHAR2, pv_createupdateflag IN VARCHAR2, pn_req_id OUT NUMBER, pv_retcode OUT VARCHAR2
                                  , pv_reterror OUT VARCHAR2);

    FUNCTION lead_time_cal (              -- Start Added By BT Technology Team
                            pn_organization_id IN NUMBER, pn_inventory_id IN NUMBER, pn_full_lead_time IN NUMBER
                            , p_sample IN VARCHAR2)
        RETURN NUMBER;                      -- End Added By BT Technology Team

    --started adding for CCR0006305
    FUNCTION fetch_transit_lead_time (pv_country_code    IN VARCHAR2,
                                      pv_supplier_code   IN VARCHAR2)
        RETURN NUMBER;

    --ended adding for CCR0006305

    PROCEDURE item_attr_update_proc (pv_errbuf    OUT VARCHAR2,
                                     pv_retcode   OUT VARCHAR2);

    PROCEDURE audit_report (pn_conc_request_id IN NUMBER);

    PROCEDURE identify_master_child_attr ( -- Start Added By BT Technology Team
                                          pv_column_name IN VARCHAR2, pv_actual_column IN VARCHAR2, pn_request_id IN NUMBER); -- End Added By BT Technology Team

    /*FUNCTION identify_master_child_attr (    -- Commented By BT Technology Team
       pv_column_name         IN   VARCHAR2,
       pv_master_child        IN   VARCHAR2,
       pv_interface_staging   IN   VARCHAR2,
       pn_sno                 IN   NUMBER,
       pn_request_id          IN   NUMBER
    )
       RETURN VARCHAR2;   */

    PROCEDURE del_item_int_stuck_rec (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_purge_date IN VARCHAR2
                                      , pn_user_id IN NUMBER);

    PROCEDURE p_item_extract (                  -- Added By BT Technology Team
                              pv_errbuf    OUT VARCHAR2,
                              pv_retcode   OUT VARCHAR2);

    PROCEDURE stg_tbl_upd_proc (pv_errbuff   OUT VARCHAR2,
                                pv_retcode   OUT VARCHAR2);

    PROCEDURE extract_cat_to_stg (              -- Added By BT Technology Team
                                  x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_request_id IN NUMBER);

    --Start CR 117 BT TECH TEAM 8/24/2015

    FUNCTION get_japan_intransit_time (p_category_id   NUMBER,
                                       p_sample        VARCHAR2)
        RETURN NUMBER;
--End CR 117 BT TECH TEAM 8/24/2015
END xxdoascp_item_attr_upd_pkg;
/
