--
-- XXD_MFG_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:21:50 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_MFG_UTILS"
/****************************************************************************************
* Package      :XXD_MFG_UTILS
* Design       : This package is used for the MFG Integration
* Notes        :
* Modification :
-- ===============================================================================
-- Date         Version#   Name                    Comments
-- ===============================================================================
--  29-Jun-2020  1.0      Shivanshu Talwar          Initial Version
******************************************************************************************/
IS
    --Sets values for the PO extract filter in the XXD_MFG_PO_V
    --This procedure writes values to the XXD_MFG_LOOKUPS lookup
    PROCEDURE set_po_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);

    --Sets the last extract date for the XXD_MFG_VEND views
    PROCEDURE set_vend_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);
END XXD_MFG_UTILS;
/


GRANT EXECUTE ON APPS.XXD_MFG_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXD_MFG_UTILS TO XXDO
/
