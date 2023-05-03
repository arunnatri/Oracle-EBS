--
-- XXD_RMSSTORE_LKP_UPD  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:18 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_RMSSTORE_LKP_UPD"
IS
    /****************************************************************************************
    * Package      :XXD_RMSSTORE_LKP_UPD
    * Design       : This package is used for the AR concession process
    * Notes        :
    * Modification :
    -- ===============================================================================
    -- Date         Version#   Name               Comments
    -- ===============================================================================
    -- 15-feb-2020  1.0       Shivanshu          Initial Version
    ******************************************************************************************/
    --Set the last Store extract date in the select * from   fnd_lookup_values_vl where lookup_type =

    v_num_rows   VARCHAR2 (100);

    PROCEDURE set_store_last_extract_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET attribute15   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     lookup_type = 'XXD_RETAIL_STORES'
               AND attribute14 = 'CONCESSION'
               AND enabled_flag = 'Y'
               AND attribute6 = p_data;

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_store_last_extract_date;

    PROCEDURE set_store_previous_date (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values
           SET attribute15 = NVL (attribute15, TO_CHAR (SYSDATE - 1, 'DD-MON-YYYY HH:MI:SS AM'))
         WHERE     lookup_type = 'XXD_RETAIL_STORES'
               AND attribute14 = 'CONCESSION'
               AND enabled_flag = 'Y'
               AND attribute15 IS NULL;

        --      COMMIT;
        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_store_previous_date;


    PROCEDURE update_stores_in_tbl (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        INSERT INTO xxdo.xxd_rms_concession_store_t (RMS_STORE_ID,
                                                     PROCESS_STATUS,
                                                     creation_date)
            (SELECT rms_store_id, NULL, SYSDATE
               FROM apps.xxd_retail_stores_v rs
              WHERE     1 = 1
                    AND NVL (store_channel, 'X') = 'CONCESSION'
                    AND enabled_flag = 'Y'
                    AND NOT EXISTS
                            (SELECT 1
                               FROM xxdo.xxd_rms_concession_store_t cs
                              WHERE cs.rms_store_id = rs.rms_store_id)
                    AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                    AND NVL (end_date_active, SYSDATE + 1));

        --      COMMIT;

        UPDATE xxdo.xxd_rms_concession_store_t
           SET process_status   = NULL
         WHERE rms_store_id = DECODE (p_data, '0', rms_store_id, p_data);

        v_num_rows   := SQL%ROWCOUNT;

        IF v_num_rows > 0
        THEN
            x_status   := 'S';
        ELSE
            x_status    := 'E';
            x_message   := 'No Rows Return';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END update_stores_in_tbl;


    PROCEDURE update_stores_status_tbl (p_data IN VARCHAR2, x_status OUT NOCOPY VARCHAR2, x_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE xxdo.xxd_rms_concession_store_t
           SET PROCESS_STATUS   = 'P'
         WHERE rms_store_id = NVL (p_data, rms_store_id);

        x_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            x_status    := 'E';
            x_message   := SUBSTR (SQLERRM, 1, 2000);
    END update_stores_status_tbl;
END XXD_RMSSTORE_LKP_UPD;
/


GRANT EXECUTE ON APPS.XXD_RMSSTORE_LKP_UPD TO SOA_INT
/

GRANT EXECUTE ON APPS.XXD_RMSSTORE_LKP_UPD TO XXDO
/
