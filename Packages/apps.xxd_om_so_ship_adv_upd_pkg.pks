--
-- XXD_OM_SO_SHIP_ADV_UPD_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:24 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_OM_SO_SHIP_ADV_UPD_PKG"
/****************************************************************************************
* Package      :XXD_OM_SO_SHIP_ADV_UPD_PKG
* Design       : This package is used to update the program run date for NFI-TMS Integration
* Notes        :
* Modification :
-- ===============================================================================
-- Date         Version#   Name                    Comments
-- ===============================================================================
--  11-Sep-2021  1.0      Showkath Ali          Initial Version
******************************************************************************************/
IS
    --Sets values for the PO extract filter in the XXD_MFG_PO_V
    --This procedure writes values to the XXD_MFG_LOOKUPS lookup
    PROCEDURE set_so_last_extract_date (p_data IN VARCHAR2, p_status OUT NOCOPY VARCHAR2, p_message OUT NOCOPY VARCHAR2);
END XXD_OM_SO_SHIP_ADV_UPD_PKG;
/


GRANT EXECUTE ON APPS.XXD_OM_SO_SHIP_ADV_UPD_PKG TO SOA_INT
/
