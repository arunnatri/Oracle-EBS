--
-- XXD_OM_SO_SHIP_ADV_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:10 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_OM_SO_SHIP_ADV_UPD_PKG"
IS
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
    --Set the last SO extract date in the lookup
    PROCEDURE set_so_last_extract_date (p_data IN VARCHAR2, p_status OUT NOCOPY VARCHAR2, p_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_PO_NFI_RUN_DATE_LOOKUP'
               AND lookup_code = 'XXD_PO_LAST_EXTRACT';

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_PO_NFI_RUN_DATE_LOOKUP'
               AND lookup_code = 'XXD_PO_LAST_EXTRACT';

        --      COMMIT;
        p_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status    := 'E';
            p_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_so_last_extract_date;
END XXD_OM_SO_SHIP_ADV_UPD_PKG;
/


GRANT EXECUTE ON APPS.XXD_OM_SO_SHIP_ADV_UPD_PKG TO SOA_INT
/
