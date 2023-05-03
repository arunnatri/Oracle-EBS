--
-- XXDO_SINGLE_ATP_RESULT_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:17:47 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXDO_SINGLE_ATP_RESULT_PKG"
IS
    /**********************************************************************************************
        * PACKAGE         : APPS.XXDO_SINGLE_ATP_RESULT_PKG
        * Author          : BT Technology Team
        * Created         : 30-MAR-2015
        * Program Name    :
        * Description     :
        *
        * Modification    :
        *-----------------------------------------------------------------------------------------------
        *     Date         Developer             Version     Description
        *-----------------------------------------------------------------------------------------------
        *     30-Mar-2015 BT Technology Team     V1.1         Development
        *     29-Oct-2015 BT Technology Team     V1.2         Code change on adding application
        *     06-Jan-2021 Jayarajan A. K.        v1.3         Added functions get_appl_atp, get_no_free_atp and get_bulk_atp
        ************************************************************************************************/

    FUNCTION given_dclass (p_demand_class VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                           -- Start modification by BT Technology Team 29-Oct-15 v1.2
                           , p_application VARCHAR2:= 'EDI'-- End modification by BT Technology Team 29-Oct-15 v1.2
                                                           )
        RETURN NUMBER;

    FUNCTION given_dclass_1 (p_demand_class VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                             -- Start modification by BT Technology Team 29-Oct-15 v1.2
                             , p_application VARCHAR2:= 'RMS'-- End modification by BT Technology Team 29-Oct-15 v1.2
                                                             )
        RETURN NUMBER;

    FUNCTION given_cust_number (p_cust_number VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                                , p_application VARCHAR2)
        RETURN NUMBER;

    -- Start v1.3 changes

    FUNCTION get_appl_atp (p_store_type VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                           , p_application VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_no_free_atp (p_store_type          VARCHAR2,
                              p_inventory_item_id   NUMBER,
                              p_inv_org_id          NUMBER,
                              p_application1        VARCHAR2,
                              p_application2        VARCHAR2)
        RETURN NUMBER;

    FUNCTION get_bulk_atp (p_cust_number VARCHAR2, p_inventory_item_id NUMBER, p_inv_org_id NUMBER
                           , p_application VARCHAR2)
        RETURN NUMBER;
-- End v1.3 changes

END XXDO_SINGLE_ATP_RESULT_PKG;
/
