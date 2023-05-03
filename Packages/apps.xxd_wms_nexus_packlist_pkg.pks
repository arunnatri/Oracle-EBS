--
-- XXD_WMS_NEXUS_PACKLIST_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:26:14 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_WMS_NEXUS_PACKLIST_PKG"
IS
    /****************************************************************************************
    * Package      :XXD_WMS_NEXUS_PACKLIST_PKG
    * Design       : This package is used for the NIM process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
      -- 01-Jun-2022  1.0      Shivanshu          Initial Version
    ******************************************************************************************/
    --Set the last SO extract date in the lookup
    PROCEDURE set_asn_last_extract_date (p_code IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);

    PROCEDURE packlist_extract_event (x_status       OUT NOCOPY VARCHAR2,
                                      x_message      OUT NOCOPY VARCHAR2);
END XXD_WMS_NEXUS_PACKLIST_PKG;
/
