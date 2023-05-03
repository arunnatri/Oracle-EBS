--
-- XXD_ODC_NEXUS_SO_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ODC_NEXUS_SO_PKG"
IS
    /****************************************************************************************
    * Package      :XXD_ODC_NEXUS_SO_PKG
    * Design       : This package is used for the NIM process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
      -- 01-Jun-2022  1.0      Shivanshu          Initial Version
    ******************************************************************************************/
    --Set the last SO extract date in the lookup
    PROCEDURE set_so_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_ODC_NEXUS_SO_NC_EXCT_LKP'
               AND lookup_code = 'ODC_NEXUS_SO_LAST_EXTRACT';

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_ODC_NEXUS_SO_NC_EXCT_LKP'
               AND lookup_code = 'ODC_NEXUS_SO_LAST_EXTRACT';

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_so_last_extract_date;
END XXD_ODC_NEXUS_SO_PKG;
/


GRANT EXECUTE ON APPS.XXD_ODC_NEXUS_SO_PKG TO SOA_INT
/
