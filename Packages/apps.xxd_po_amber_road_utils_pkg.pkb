--
-- XXD_PO_AMBER_ROAD_UTILS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_AMBER_ROAD_UTILS_PKG"
IS
    /****************************************************************************************
    * Package      : xxd_po_amber_road_utils_pkg
    * Design       : This is a utility package used for Amber Road Project
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 11-Sep-2018  1.0         Kranthi Bollam          Initial Version
    --
    -- ===========  ========    ======================= =======================================
    ******************************************************************************************/
    --Global Variables
    gv_package_name      CONSTANT VARCHAR2 (30) := 'XXD_PO_AMBER_ROAD_UTILS_PKG';
    gn_user_id           CONSTANT NUMBER := fnd_global.user_id;
    gn_conc_request_id   CONSTANT NUMBER := fnd_global.conc_request_id;

    --Procedure to print messages into either log or output files
    --Parameters
    --PV_MSG        Message to be printed
    --PV_TIME       Print time or not. Default is no.
    --PV_FILE       Print to LOG or OUTPUT file. Default write it to LOG file
    PROCEDURE msg (pv_msg    IN VARCHAR2,
                   pv_time   IN VARCHAR2 DEFAULT 'N',
                   pv_file   IN VARCHAR2 DEFAULT 'LOG')
    IS
        --Local Variables
        lv_proc_name    VARCHAR2 (30) := 'MSG';
        lv_msg          VARCHAR2 (4000);
        lv_time_stamp   VARCHAR2 (20)
                            := TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS');
    BEGIN
        IF pv_time = 'Y'
        THEN
            lv_msg   := pv_msg || '. Timestamp: ' || lv_time_stamp;
        ELSE
            lv_msg   := pv_msg;
        END IF;

        IF UPPER (pv_file) = 'OUT'
        THEN
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.output, lv_msg);
            END IF;
        ELSE
            IF gn_user_id = -1
            THEN
                DBMS_OUTPUT.put_line (lv_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, lv_msg);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In When Others exception in '
                || gv_package_name
                || '.'
                || lv_proc_name
                || ' procedure. Error is: '
                || SQLERRM);
    END msg;

    --Set the Purchase Order last extract date to the lookup
    PROCEDURE set_po_last_extract_date (pv_dummy IN VARCHAR2 --To make SOA code work
                                                            , xv_status OUT NOCOPY VARCHAR2, xv_message OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        UPDATE fnd_lookup_values flv
           SET flv.description   = flv.tag
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_PO_AMBER_ROAD_UTILS_LKP'
               AND flv.lookup_code = 'AMBER_ROAD_PO_LAST_EXTRACT';

        UPDATE fnd_lookup_values flv_1
           SET flv_1.tag   = TO_CHAR (SYSDATE, 'DD-MON-YYYY HH:MI:SS AM')
         WHERE     1 = 1
               AND flv_1.lookup_type = 'XXD_PO_AMBER_ROAD_UTILS_LKP'
               AND flv_1.lookup_code = 'AMBER_ROAD_PO_LAST_EXTRACT';

        xv_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            xv_status    := 'E';
            xv_message   := SUBSTR (SQLERRM, 1, 2000);
    END set_po_last_extract_date;
END xxd_po_amber_road_utils_pkg;
/


--
-- XXD_PO_AMBER_ROAD_UTILS_PKG  (Synonym) 
--
CREATE OR REPLACE SYNONYM SOA_INT.XXD_PO_AMBER_ROAD_UTILS_PKG FOR APPS.XXD_PO_AMBER_ROAD_UTILS_PKG
/


GRANT EXECUTE, DEBUG ON APPS.XXD_PO_AMBER_ROAD_UTILS_PKG TO SOA_INT
/
