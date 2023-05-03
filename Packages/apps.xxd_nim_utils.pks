--
-- XXD_NIM_UTILS  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:22:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_NIM_UTILS"
/****************************************************************************************
* Package      :XXD_NIM_UTILS
* Design       : This package is used for the NIM process
* Notes        :
* Modification :
-- ===============================================================================
-- Date         Version#   Name                    Comments
-- ===============================================================================
-- 29-Jun-2018  1.0      Greg Jensen          Initial Version
******************************************************************************************/
IS
    --Sets values for the SO extract filter in the XXD_NIM_SO_V
    --This procedure writes values to the XXD_NIM_LOOKUPS lookup
    PROCEDURE set_so_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);

    --Sets the last extract date for the XXD_NIM_IR views
    PROCEDURE set_ir_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);
END xxd_nim_utils;
/


--
-- XXD_NIM_UTILS  (Synonym) 
--
--  Dependencies: 
--   XXD_NIM_UTILS (Package)
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_NIM_UTILS FOR APPS.XXD_NIM_UTILS
/


GRANT EXECUTE ON APPS.XXD_NIM_UTILS TO SOA_INT
/
