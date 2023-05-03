--
-- XXD_RMSSTORE_LKP_UPD  (Package) 
--
--  Dependencies: 
--   STANDARD (Package)
--
/* Formatted on 4/26/2023 4:25:27 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE APPS."XXD_RMSSTORE_LKP_UPD"
AS
    /****************************************************************************************
    * Package      : XXD_RMSSTORE_LKP_UPD
    * Design       : This package will be used for AR concession integration/customization
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 24-Jun-2019  1.0        Shivanshu Talwar     Initial Version
    ******************************************************************************************/
    PROCEDURE set_store_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);

    PROCEDURE set_store_previous_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);

    PROCEDURE update_stores_in_tbl (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);

    PROCEDURE update_stores_status_tbl (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2);
END XXD_RMSSTORE_LKP_UPD;
/


GRANT EXECUTE ON APPS.XXD_RMSSTORE_LKP_UPD TO SOA_INT
/

GRANT EXECUTE ON APPS.XXD_RMSSTORE_LKP_UPD TO XXDO
/
