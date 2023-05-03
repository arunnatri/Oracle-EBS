--
-- XXD_MFG_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:25 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_MFG_UTILS"
IS
    /****************************************************************************************
    * Package      :XXD_MFG_UTILS
    * Design       : This package is used for the MFG process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
    -- 29-Jun-2020  1.0      Shivanshu Talwar          Initial Version
    ******************************************************************************************/
    --Set the last PO extract date in the lookup
    PROCEDURE set_po_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_MFG_INT_LOOKUPS'
               AND lookup_code = 'MFG_PO_LAST_EXTRACT';

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_MFG_INT_LOOKUPS'
               AND lookup_code = 'MFG_PO_LAST_EXTRACT';

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_po_last_extract_date;

    --set the Vend last extract date to the lookup
    PROCEDURE set_vend_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_MFG_INT_LOOKUPS'
               AND lookup_code = 'MFG_VEND_LAST_EXTRACT';

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_MFG_INT_LOOKUPS'
               AND lookup_code = 'MFG_VEND_LAST_EXTRACT';

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_vend_last_extract_date;
END XXD_MFG_UTILS;
/


GRANT EXECUTE ON APPS.XXD_MFG_UTILS TO SOA_INT
/

GRANT EXECUTE ON APPS.XXD_MFG_UTILS TO XXDO
/
