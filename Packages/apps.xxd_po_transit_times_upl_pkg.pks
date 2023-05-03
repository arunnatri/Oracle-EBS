--
-- XXD_PO_TRANSIT_TIMES_UPL_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_PO_TRANSIT_TIMES_UPL_PKG"
AS
    /******************************************************************************************************
    * Package Name  : XXD_PO_TRANSIT_TIMES_UPL_PKG
    * Description   : This Package will be used to insert/update lookup - XXDO_SUPPLIER_INTRANSIT
    *
    * Modification History
    * -------------------
    * Date          Author            Version          Change Description
    * -----------   ------            -------          ---------------------------
    * 17-Nov-2022   Ramesh BR         1.0              Initial Version
    ********************************************************************************************************/

    PROCEDURE lookup_upload_prc (p_ultimate_dest_code   IN VARCHAR2,
                                 p_vendor_name          IN VARCHAR2,
                                 p_vendor_site_code     IN VARCHAR2,
                                 p_tran_days_ocean      IN NUMBER,
                                 p_tran_days_air        IN NUMBER,
                                 p_tran_days_truck      IN NUMBER,
                                 p_pref_ship_method     IN VARCHAR2,
                                 p_batch_id             IN NUMBER,
                                 p_lookup_code          IN NUMBER,
                                 p_sup_site_status      IN VARCHAR2,
                                 p_enabled_flag         IN VARCHAR2);
END XXD_PO_TRANSIT_TIMES_UPL_PKG;
/
