--
-- XXD_NIM_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_NIM_UTILS"
IS
    /****************************************************************************************
    * Package      :XXD_NIM_UTILS
    * Design       : This package is used for the NIM process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
    -- 29-Jun-2018  1.0      Greg Jensen          Initial Version
    ******************************************************************************************/
    --Set the last SO extract date in the lookup
    PROCEDURE set_so_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_NIM_LOOKUPS'
               AND lookup_code = 'NIM_SO_LAST_EXTRACT';

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_NIM_LOOKUPS'
               AND lookup_code = 'NIM_SO_LAST_EXTRACT';

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_so_last_extract_date;

    --set the IR last extract date to the lookup
    PROCEDURE set_ir_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET description   = tag
         WHERE     lookup_type = 'XXD_NIM_LOOKUPS'
               AND lookup_code = 'NIM_IR_LAST_EXTRACT';

        UPDATE fnd_lookup_values
           SET tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_NIM_LOOKUPS'
               AND lookup_code = 'NIM_IR_LAST_EXTRACT';

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_ir_last_extract_date;
END xxd_nim_utils;
/


--
-- XXD_NIM_UTILS  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_NIM_UTILS FOR APPS.XXD_NIM_UTILS
/


GRANT EXECUTE ON APPS.XXD_NIM_UTILS TO SOA_INT
/
