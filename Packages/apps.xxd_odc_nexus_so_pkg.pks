--
-- XXD_ODC_NEXUS_SO_PKG  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:07 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_ODC_NEXUS_SO_PKG"
/****************************************************************************************
* Package      :XXD_ODC_NEXUS_SO_PKG
* Design       : This package is used for the ODC SO process
* Notes        :
* Modification :
-- ===============================================================================
-- Date         Version#   Name                    Comments
-- ===============================================================================
-- 01-Jun-2022  1.0      Shivanshu          Initial Version
******************************************************************************************/
IS
    --Sets values for the SO extract filter in the XXD_NIM_SO_V
    --This procedure writes values to the XXD_NIM_LOOKUPS lookup
    PROCEDURE set_so_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);
END XXD_ODC_NEXUS_SO_PKG;
/


GRANT EXECUTE ON APPS.XXD_ODC_NEXUS_SO_PKG TO SOA_INT
/
