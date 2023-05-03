--
-- XXD_ONT_SHIP_CONFIRM_INT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:19 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_SHIP_CONFIRM_INT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_SHIP_CONFIRM_INT_PKG
    * Description  : This is package for WMS(Highjump) to OM Ship Confirm Interface
    * Notes        :
    * Modification :
    -- ===========  ========    ======================= =====================================
    -- Date         Version#    Name                    Comments
    -- ===========  ========    ======================= =======================================
    -- 15-Apr-2019  1.0         Kranthi Bollam          Initial Version
    -- 01-Nov-2019  1.1         Viswanathan Pandian     Updated for CCR0008298
    -- 11-Nov-2019  1.2         Tejaswi Gangumalla      Updated for CCR0008227
    -- 15-Jun-2020  1.3         Aravind Kannuri         Updated for CCR0008698
    -- 03-Sep-2020  1.4         Viswanathan Pandian     Updated for CCR0008881
    -- 23-Apr-2021  1.5         Greg Jensen             Updated for CCR0009256
    -- 24-Jan-2022  1.6         Laltu K Sah             Updated for CCR0009784
    -- 05-Aug-2022  1.7         Gaurav Joshi            Updated for CCR0010086
    ******************************************************************************************/

    ----------------------
    -- Global Variables --
    ----------------------
    -- Return code (0 for success, 1 for failure)
    gv_package_name                 VARCHAR2 (30) := 'XXD_ONT_SHIP_CONFIRM_INT_PKG';
    gv_status_code                  VARCHAR2 (1) := '0';
    gv_status_msg                   VARCHAR2 (4000);
    gv_ret_sts_warning              VARCHAR2 (1) := 'W';
    gv_ar_release_reason   CONSTANT VARCHAR2 (10) := 'CRED-REL';
    gv_om_release_reason   CONSTANT VARCHAR2 (10) := 'CS-REL';
    g_ship_request_ids_tab          tabtype_id;
    gn_parent_req_id                NUMBER;
    g_smtp_connection               UTL_SMTP.connection := NULL;
    gn_connection_flag              NUMBER := 0;
    g_all_hold_source_tbl           g_hold_source_tbl_type;
    gn_from_stop_id                 NUMBER := 0;
    gn_inv_org_id                   NUMBER := 0;
    g_new_delv_ids_tab              tabtype_id;
    g_carton_qty_tab                tabtype_id;

    -- ***************************************************************************
    -- Procedure Name      : purge
    -- Description         : This procedure is to purge the old records
    -- Parameters          : pv_errbuf           OUT : Error message
    --                       pv_retcode          OUT : Execution status
    --                       pv_purge_option     IN  : Purge Option
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author              Version Description
    -- ------------  -----------------   ------- --------------------------------
    -- 2019/04/15   Kranthi Bollam       1.0     Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE PURGE (pv_errbuf            OUT VARCHAR2,
                     pv_retcode           OUT VARCHAR2,
                     pv_purge_option   IN     VARCHAR2)
    IS
        ld_sysdate          DATE := SYSDATE;
        ln_purge_days_stg   NUMBER := 30;
        ln_purge_days_log   NUMBER := 30;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'In Purge Program - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG,
                           'PV_PURGE_OPTION: ' || pv_purge_option);
        fnd_file.put_line (
            fnd_file.LOG,
            'PV_PURGE_OPTION = STAGING_TABLES - Delete only Staging tables');
        fnd_file.put_line (
            fnd_file.LOG,
            'PV_PURGE_OPTION = LOG_TABLES - Delete only Log tables');
        fnd_file.put_line (
            fnd_file.LOG,
            'PV_PURGE_OPTION = BOTH - Delete both Staging and Log tables');
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        BEGIN
            SELECT TO_NUMBER (description)
              INTO ln_purge_days_stg
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'XXD_WMS_SHIP_CONFIRM_UTIL_LKP'
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND lookup_code = 'PURGE_DAYS_STG';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_purge_days_stg   := 30;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error getting purge days staging from XXD_WMS_SHIP_CONFIRM_UTIL_LKP lookup. Defaulting purge days staging to 30 days');
                fnd_file.put_line (fnd_file.LOG, 'Error is: ' || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Staging tables Purge Days: ' || ln_purge_days_stg);

        BEGIN
            SELECT TO_NUMBER (description)
              INTO ln_purge_days_log
              FROM fnd_lookup_values
             WHERE     1 = 1
                   AND lookup_type = 'XXD_WMS_SHIP_CONFIRM_UTIL_LKP'
                   AND LANGUAGE = 'US'
                   AND enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND lookup_code = 'PURGE_DAYS_LOG';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_purge_days_log   := 30;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error getting LOG purge days from XXD_WMS_SHIP_CONFIRM_UTIL_LKP lookup. Defaulting purge days log to 30 days');
                fnd_file.put_line (fnd_file.LOG, 'Error is: ' || SQLERRM);
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Log tables Purge Days: ' || ln_purge_days_log);

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_head_log (wh_id,
                                                     shipment_number,
                                                     master_load_ref,
                                                     customer_load_id,
                                                     carrier,
                                                     service_level,
                                                     pro_number,
                                                     comments,
                                                     ship_date,
                                                     seal_number,
                                                     trailer_number,
                                                     employee_id,
                                                     employee_name,
                                                     archive_date,
                                                     archive_request_id,
                                                     process_status,
                                                     error_message,
                                                     request_id,
                                                     creation_date,
                                                     created_by,
                                                     last_update_date,
                                                     last_updated_by,
                                                     source_type,
                                                     attribute1,
                                                     attribute2,
                                                     attribute3,
                                                     attribute4,
                                                     attribute5,
                                                     attribute6,
                                                     attribute7,
                                                     attribute8,
                                                     attribute9,
                                                     attribute10,
                                                     attribute11,
                                                     attribute12,
                                                     attribute13,
                                                     attribute14,
                                                     attribute15,
                                                     attribute16,
                                                     attribute17,
                                                     attribute18,
                                                     attribute19,
                                                     attribute20,
                                                     SOURCE,
                                                     destination,
                                                     record_type,
                                                     shipment_type,
                                                     sales_channel --Added for 1.2
                                                                  )
                SELECT wh_id, shipment_number, master_load_ref,
                       customer_load_id, carrier, service_level,
                       pro_number, comments, ship_date,
                       seal_number, trailer_number, employee_id,
                       employee_name, ld_sysdate, gn_request_id,
                       process_status, error_message, request_id,
                       creation_date, created_by, last_update_date,
                       last_updated_by, source_type, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, SOURCE, destination,
                       record_type, shipment_type, sales_channel --Added for 1.2
                  FROM xxdo_ont_ship_conf_head_stg
                 WHERE creation_date < ld_sysdate - ln_purge_days_stg;

            IF pv_purge_option = 'STAGING_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_head_stg
                      WHERE creation_date < ld_sysdate - ln_purge_days_stg;
            END IF;

            IF pv_purge_option = 'LOG_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_head_log
                      WHERE creation_date < ld_sysdate - ln_purge_days_log;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error happened while archiving shipment headers data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment headers data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_order_log (wh_id, shipment_number, order_number, ship_to_name, ship_to_attention, ship_to_addr1, ship_to_addr2, ship_to_addr3, ship_to_city, ship_to_state, ship_to_zip, ship_to_country_code, archive_date, archive_request_id, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, SOURCE, destination, record_type, address_verified, order_header_id, delivery_id, ship_to_org_id, ship_to_location_id, edi_eligible
                                                      , edi_creation_status --Added for 1.2
                                                                           )
                SELECT wh_id, shipment_number, order_number,
                       ship_to_name, ship_to_attention, ship_to_addr1,
                       ship_to_addr2, ship_to_addr3, ship_to_city,
                       ship_to_state, ship_to_zip, ship_to_country_code,
                       ld_sysdate, gn_request_id, process_status,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       source_type, attribute1, attribute2,
                       attribute3, attribute4, attribute5,
                       attribute6, attribute7, attribute8,
                       attribute9, attribute10, attribute11,
                       attribute12, attribute13, attribute14,
                       attribute15, attribute16, attribute17,
                       attribute18, attribute19, attribute20,
                       SOURCE, destination, record_type,
                       address_verified, order_header_id, delivery_id,
                       ship_to_org_id, ship_to_location_id, edi_eligible,
                       edi_creation_status                     --Added for 1.2
                  FROM xxdo_ont_ship_conf_order_stg
                 WHERE creation_date < ld_sysdate - ln_purge_days_stg;

            IF pv_purge_option = 'STAGING_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_order_stg
                      WHERE creation_date < ld_sysdate - ln_purge_days_stg;
            END IF;

            IF pv_purge_option = 'LOG_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_order_log
                      WHERE creation_date < ld_sysdate - ln_purge_days_log;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error happened while archiving shipment deliveries data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment deliveries data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_carton_log (wh_id,
                                                       shipment_number,
                                                       order_number,
                                                       carton_number,
                                                       tracking_number,
                                                       freight_list,
                                                       freight_actual,
                                                       weight,
                                                       LENGTH,
                                                       width,
                                                       height,
                                                       archive_date,
                                                       archive_request_id,
                                                       process_status,
                                                       error_message,
                                                       request_id,
                                                       creation_date,
                                                       created_by,
                                                       last_update_date,
                                                       last_updated_by,
                                                       source_type,
                                                       attribute1,
                                                       attribute2,
                                                       attribute3,
                                                       attribute4,
                                                       attribute5,
                                                       attribute6,
                                                       attribute7,
                                                       attribute8,
                                                       attribute9,
                                                       attribute10,
                                                       attribute11,
                                                       attribute12,
                                                       attribute13,
                                                       attribute14,
                                                       attribute15,
                                                       attribute16,
                                                       attribute17,
                                                       attribute18,
                                                       attribute19,
                                                       attribute20,
                                                       SOURCE,
                                                       destination,
                                                       record_type,
                                                       freight_charged)
                SELECT wh_id, shipment_number, order_number,
                       carton_number, tracking_number, freight_list,
                       freight_actual, weight, LENGTH,
                       width, height, ld_sysdate,
                       gn_request_id, process_status, error_message,
                       request_id, creation_date, created_by,
                       last_update_date, last_updated_by, source_type,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, SOURCE,
                       destination, record_type, freight_charged
                  FROM xxdo_ont_ship_conf_carton_stg
                 WHERE creation_date < ld_sysdate - ln_purge_days_stg;

            IF pv_purge_option = 'STAGING_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_carton_stg
                      WHERE creation_date < ld_sysdate - ln_purge_days_stg;
            END IF;

            IF pv_purge_option = 'LOG_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_carton_log
                      WHERE creation_date < ld_sysdate - ln_purge_days_log;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error happened while archiving shipment cartons data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment cartons data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_cardtl_log (wh_id,
                                                       shipment_number,
                                                       order_number,
                                                       carton_number,
                                                       line_number,
                                                       item_number,
                                                       qty,
                                                       uom,
                                                       host_subinventory,
                                                       archive_date,
                                                       archive_request_id,
                                                       process_status,
                                                       error_message,
                                                       request_id,
                                                       creation_date,
                                                       created_by,
                                                       last_update_date,
                                                       last_updated_by,
                                                       source_type,
                                                       attribute1,
                                                       attribute2,
                                                       attribute3,
                                                       attribute4,
                                                       attribute5,
                                                       attribute6,
                                                       attribute7,
                                                       attribute8,
                                                       attribute9,
                                                       attribute10,
                                                       attribute11,
                                                       attribute12,
                                                       attribute13,
                                                       attribute14,
                                                       attribute15,
                                                       attribute16,
                                                       attribute17,
                                                       attribute18,
                                                       attribute19,
                                                       attribute20,
                                                       SOURCE,
                                                       destination,
                                                       record_type)
                SELECT wh_id, shipment_number, order_number,
                       carton_number, line_number, item_number,
                       qty, uom, host_subinventory,
                       ld_sysdate, gn_request_id, process_status,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       source_type, attribute1, attribute2,
                       attribute3, attribute4, attribute5,
                       attribute6, attribute7, attribute8,
                       attribute9, attribute10, attribute11,
                       attribute12, attribute13, attribute14,
                       attribute15, attribute16, attribute17,
                       attribute18, attribute19, attribute20,
                       SOURCE, destination, record_type
                  FROM xxdo_ont_ship_conf_cardtl_stg
                 WHERE creation_date < ld_sysdate - ln_purge_days_stg;

            IF pv_purge_option = 'STAGING_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_cardtl_stg
                      WHERE creation_date < ld_sysdate - ln_purge_days_stg;
            END IF;

            IF pv_purge_option = 'LOG_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM xxdo_ont_ship_conf_cardtl_log
                      WHERE creation_date < ld_sysdate - ln_purge_days_log;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error happened while archiving shipment carton details data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment carton details data: '
                    || SQLERRM);
        END;

        COMMIT;

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_xml_log (process_status,
                                                    xml_document,
                                                    file_name,
                                                    error_message,
                                                    request_id,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    archive_request_id,
                                                    archive_date,
                                                    message_id,
                                                    shipment_num,
                                                    attribute1,
                                                    attribute2,
                                                    attribute3,
                                                    attribute4,
                                                    attribute5)
                SELECT process_status, xml_document, file_name,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       gn_request_id, ld_sysdate, message_id,
                       shipment_num, attribute1, attribute2,
                       attribute3, attribute4, attribute5
                  FROM xxdo_ont_ship_conf_xml_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (ld_sysdate) - ln_purge_days_stg;

            IF pv_purge_option = 'STAGING_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM
                    xxdo_ont_ship_conf_xml_stg
                      WHERE TRUNC (creation_date) <
                            TRUNC (ld_sysdate) - ln_purge_days_stg;
            END IF;

            IF pv_purge_option = 'LOG_TABLES' OR pv_purge_option = 'BOTH'
            THEN
                DELETE FROM
                    xxdo_ont_ship_conf_xml_log
                      WHERE TRUNC (creation_date) <
                            TRUNC (ld_sysdate) - ln_purge_days_log;
            END IF;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Error happened while archiving Ship Confirm XML  data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving Ship Confirm XML data: '
                    || SQLERRM);
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'In Purge Program - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            pv_retcode   := '1';
            pv_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END PURGE;

    /** ****************************************************************************
   -- Procedure Name      : get_resp_details
   --
   -- Description         : This procedure is to archive and purge the old records
   -- Parameters          : p_resp_id        OUT : Responsibility ID
   --                       p_resp_appl_id   OUT : Application ID
   --
   -- Return/Exit         :  none
   --
   -- DEVELOPMENT and MAINTENANCE HISTORY
   --
   -- date           author              Version Description
   -- ------------   -----------------   ------- --------------------------------
   -- 2019/05/01     Kranthi Bollam      1.0     Initial Version.
   --
   --
   ***************************************************************************/
    PROCEDURE get_resp_details (p_org_id IN NUMBER, p_module_name IN VARCHAR2, p_resp_id OUT NUMBER
                                , p_resp_appl_id OUT NUMBER)
    IS
        lv_mo_resp_id           NUMBER;
        lv_mo_resp_appl_id      NUMBER;
        lv_const_om_resp_name   VARCHAR2 (200)
                                    := 'Order Management Super User - ';
        lv_const_po_resp_name   VARCHAR2 (200) := 'Purchasing Super User - ';
        lv_const_ou_name        VARCHAR2 (200);
        lv_var_ou_name          VARCHAR2 (200);
    BEGIN
        IF p_module_name = 'ONT'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.NAME)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND LANGUAGE = 'US'
                       AND hou.organization_id = p_org_id
                       AND flv.description = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;
            END;
        ELSIF p_module_name = 'PO'
        THEN
            BEGIN
                SELECT resp.responsibility_id, resp.application_id
                  INTO lv_mo_resp_id, lv_mo_resp_appl_id
                  FROM fnd_lookup_values flv, hr_operating_units hou, fnd_responsibility_vl resp
                 WHERE     flv.lookup_code = UPPER (hou.NAME)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND LANGUAGE = 'US'
                       AND hou.organization_id = p_org_id
                       AND meaning = resp.responsibility_name
                       AND end_date_active IS NULL
                       AND end_date IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_resp_id        := NULL;
                    p_resp_appl_id   := NULL;
            END;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Responsbility Application Id '
            || lv_mo_resp_appl_id
            || '-'
            || lv_mo_resp_id);
        p_resp_id        := lv_mo_resp_id;
        p_resp_appl_id   := lv_mo_resp_appl_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_resp_id        := NULL;
            p_resp_appl_id   := NULL;
    END get_resp_details;

    -- ***************************************************************************
    -- Procedure Name      : lock_records
    -- Description         : This procedure is to lock the records for processing
    --
    -- Parameters          : pv_errbuf       OUT : Error message
    --                       pv_retcode      OUT : Execution status
    --                       pv_shipment_no  IN  : Shipment Number
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author                  Version Description
    -- ------------  -----------------       ------- --------------------------------
    -- 2019/05/02    Kranthi Bollam          1.0     Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE lock_records (pv_errbuf           OUT VARCHAR2,
                            pv_retcode          OUT VARCHAR2,
                            pv_shipment_no   IN     VARCHAR2)
    IS
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        UPDATE xxdo_ont_ship_conf_head_stg
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND shipment_number = pv_shipment_no;

        UPDATE xxdo_ont_ship_conf_order_stg
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND shipment_number = pv_shipment_no;

        UPDATE xxdo_ont_ship_conf_carton_stg
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND shipment_number = pv_shipment_no;

        UPDATE xxdo_ont_ship_conf_cardtl_stg
           SET process_status = 'INPROCESS', request_id = gn_request_id, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND shipment_number = pv_shipment_no;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR in LOCK_RECORDS procedure : ' || pv_errbuf);
    END lock_records;

    -- ***************************************************************************
    -- Procedure Name      : reset_error_records
    -- Description         : This procedure is to reset the error records for the given shipment number
    --
    -- Parameters          : pv_errbuf       OUT : Error message
    --                       pv_retcode      OUT : Execution status
    --                       pv_shipment_no  IN  : Shipment Number
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author              Version Description
    -- ------------  -----------------   ------- --------------------------------
    -- 2019/05/01   Kranthi Bollam       1.0     Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE reset_error_records (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2)
    IS
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        UPDATE xxdo_ont_ship_conf_head_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no;

        UPDATE xxdo_ont_ship_conf_order_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no;

        UPDATE xxdo_ont_ship_conf_carton_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no;

        UPDATE xxdo_ont_ship_conf_cardtl_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = gn_user_id,
               last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    := SUBSTR (SQLERRM, 1, 2000);
            fnd_file.put_line (
                fnd_file.LOG,
                   'ERROR in RESET_ERROR_RECORDS procedure for shipment number: '
                || pv_shipment_no
                || ' Error is: '
                || pv_errbuf);
    END reset_error_records;

    -- ***************************************************************************
    -- Procedure Name      : update_error_records
    -- Description         : This procedure is to update the process status and error message of the processed
    --                       and errored records
    --
    -- Parameters          : pv_errbuf           OUT : Error message
    --                       pv_retcode          OUT : Execution status
    --                       pv_shipment_no      IN  : Shipment Number
    --                       pv_delivery_no      IN  : Delivery Number
    --                       pv_carton_no        IN  : Carton Number
    --                       pv_line_no          IN  : Line Number
    --                       pv_item_number      IN  : Item Number
    --                       pv_error_level      IN  : Error Level
    --                       pv_error_message    IN  : Error message
    --                       pv_status           IN  : To Status
    --                       pv_source           IN  : Program where the error occurred
    --
    -- Return/Exit         : none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date         author             Version  Description
    -- ------------ -----------------  -------  --------------------------------
    -- 2019/04/15   Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    -- To update a shipment, shipment number will be passed. delivery number will be blank, all deliveries will be updated as error
    ---To update a delivery alone, shipment number and delivery number need to be passed, all cartons will be updated as error
    -- To update a carton alone, shipment number, delivery number and carton number to be passed, all order lines will be updated as error
    -- Shipment will be updated always
    PROCEDURE update_error_records (pv_errbuf             OUT VARCHAR2,
                                    pv_retcode            OUT VARCHAR2,
                                    pv_shipment_no     IN     VARCHAR2,
                                    pv_delivery_no     IN     VARCHAR2,
                                    pv_carton_no       IN     VARCHAR2,
                                    pv_line_no         IN     VARCHAR2,
                                    pv_item_number     IN     VARCHAR2,
                                    pv_error_level     IN     VARCHAR2,
                                    pv_error_message   IN     VARCHAR2,
                                    pv_status          IN     VARCHAR2,
                                    pv_source          IN     VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_num_errored_locked_count   NUMBER := 0;
        l_num_pending_proc_count     NUMBER := -1;
        l_chr_savepoint_name         VARCHAR2 (30);
        lv_errbuf                    VARCHAR2 (2000);
        lv_retcode                   VARCHAR2 (30);
        ln_trip_id                   NUMBER := 0;
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        --      fnd_file.put_line (fnd_file.LOG, 'pv_shipment_no : ' || pv_shipment_no);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_delivery_no : ' || pv_delivery_no);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_carton_no : ' || pv_carton_no);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_line_no : ' || pv_line_no);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_item_number : ' || pv_item_number);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_error_level : ' || pv_error_level);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_error_message : ' || pv_error_message);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_status : ' || pv_status);
        --      fnd_file.put_line (fnd_file.LOG, 'pv_source : ' || pv_source);
        IF pv_status = 'ERROR'
        THEN
            IF pv_source IN ('DELIVERY_THREAD', 'PICK_CONFIRM')
            THEN
                -- Update the error message at the correct delivery level and mark all other deliveries as ERROR
                UPDATE xxdo_ont_ship_conf_order_stg
                   SET process_status = pv_status, error_message = DECODE (pv_error_level, 'DELIVERY', pv_error_message, error_message), --NULL),
                                                                                                                                         last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no
                       AND order_number = NVL (pv_delivery_no, order_number);

                UPDATE xxdo_ont_ship_conf_carton_stg
                   SET process_status = pv_status, error_message = DECODE (pv_error_level, 'CARTON', pv_error_message, error_message), --NULL),
                                                                                                                                       last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no
                       AND order_number = NVL (pv_delivery_no, order_number)
                       AND carton_number = NVL (pv_carton_no, carton_number);

                UPDATE xxdo_ont_ship_conf_cardtl_stg
                   SET process_status = pv_status, error_message = DECODE (pv_error_level, 'ORDER LINE', pv_error_message, error_message), --NULL),
                                                                                                                                           last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no
                       AND order_number = NVL (pv_delivery_no, order_number)
                       AND carton_number = NVL (pv_carton_no, carton_number)
                       AND line_number = NVL (pv_line_no, line_number)
                       AND item_number = NVL (pv_item_number, item_number);

                --Update all deliveries within the shipment if the delivery number is passed as null
                IF pv_delivery_no IS NULL
                THEN
                    UPDATE xxdo_ont_ship_conf_order_stg
                       SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND process_status = 'INPROCESS'
                           AND shipment_number = pv_shipment_no;

                    UPDATE xxdo_ont_ship_conf_carton_stg
                       SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND process_status = 'INPROCESS'
                           AND shipment_number = pv_shipment_no;

                    UPDATE xxdo_ont_ship_conf_cardtl_stg
                       SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND process_status = 'INPROCESS'
                           AND shipment_number = pv_shipment_no;
                END IF;
            ELSE                 -- If the error source is not delivery thread
                UPDATE xxdo_ont_ship_conf_order_stg
                   SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no;

                UPDATE xxdo_ont_ship_conf_carton_stg
                   SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no;

                UPDATE xxdo_ont_ship_conf_cardtl_stg
                   SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no;
            END IF;                               -- End of error source check

            --KK - Update shipment header table status only if the pv_error_level is SHIPMENT
            IF pv_error_level = 'SHIPMENT' AND pv_status <> 'PROCESSED'
            THEN
                UPDATE xxdo_ont_ship_conf_head_stg
                   SET process_status = pv_status, error_message = DECODE (pv_error_level, 'SHIPMENT', pv_error_message, error_message), --NULL),
                                                                                                                                         last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 WHERE     1 = 1
                       AND process_status = 'INPROCESS'
                       AND shipment_number = pv_shipment_no;
            END IF;                               --End if pv_error_level - KK
        ELSE                                     -- If the status is not error
            UPDATE xxdo_ont_ship_conf_head_stg
               SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND shipment_number = pv_shipment_no;

            UPDATE xxdo_ont_ship_conf_order_stg
               SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND shipment_number = pv_shipment_no;

            UPDATE xxdo_ont_ship_conf_carton_stg
               SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND shipment_number = pv_shipment_no;

            UPDATE xxdo_ont_ship_conf_cardtl_stg
               SET process_status = pv_status, last_updated_by = gn_user_id, last_update_date = SYSDATE
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND shipment_number = pv_shipment_no;
        END IF;                                         -- End of Status check

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            COMMIT;
            pv_retcode   := '2';
            pv_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'ERROR in update error records procedure for '
                || pv_error_message
                || ' Error is: '
                || pv_errbuf);
    END update_error_records;

    -- ***************************************************************************
    -- Procedure Name      : pick_line
    -- Description         : This procedure will allocate and transact specified
    --                       move order line.
    --
    -- Parameters          : pv_errbuf       OUT : Error message
    --                       pv_retcode      OUT : Execution Status
    --                       pn_mo_line_id   IN  : Move Order Line
    --                       pn_txn_hdr_id   IN  : Transaction Header Id
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE pick_line (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_mo_line_id IN NUMBER
                         , pn_txn_hdr_id IN NUMBER)
    IS
        ln_number_of_rows         NUMBER;
        ln_detailed_qty           NUMBER;
        lv_return_status          VARCHAR2 (1);
        ln_msg_count              NUMBER;
        lv_msg_data               VARCHAR2 (32767);
        ln_revision               NUMBER;
        ln_locator_id             NUMBER;
        ln_transfer_to_location   NUMBER;
        ln_lot_number             NUMBER;
        ld_expiration_date        DATE;
        ln_transaction_temp_id    NUMBER;
        ln_msg_cntr               NUMBER;
        ln_msg_index_out          NUMBER;
        l_trolin_tbl              inv_move_order_pub.trolin_tbl_type;
        l_mold_tbl                inv_mo_line_detail_util.g_mmtt_tbl_type;
        l_mmtt_tbl                inv_mo_line_detail_util.g_mmtt_tbl_type;
        o_trolin_tbl              inv_move_order_pub.trolin_tbl_type;
    BEGIN
        --Reset status variables
        pv_retcode   := '0';
        pv_errbuf    := NULL;
        fnd_file.put_line (
            fnd_file.LOG,
            'Processing the move order line id :' || pn_mo_line_id);
        -- Call standard oracle API to perform the allocation and transaction
        inv_replenish_detail_pub.line_details_pub (p_line_id => pn_mo_line_id, x_number_of_rows => ln_number_of_rows, x_detailed_qty => ln_detailed_qty, x_return_status => lv_return_status, x_msg_count => ln_msg_count, x_msg_data => lv_msg_data, x_revision => ln_revision, x_locator_id => ln_locator_id, x_transfer_to_location => ln_transfer_to_location, x_lot_number => ln_lot_number, x_expiration_date => ld_expiration_date, x_transaction_temp_id => ln_transaction_temp_id, p_transaction_header_id => pn_txn_hdr_id, p_transaction_mode => 1, p_move_order_type => inv_globals.g_move_order_pick_wave, p_serial_flag => NULL, p_plan_tasks => FALSE, p_auto_pick_confirm => FALSE
                                                   , p_commit => FALSE);
        fnd_file.put_line (fnd_file.LOG,
                           'Number of rows :' || ln_number_of_rows);

        IF ln_number_of_rows > 0
        THEN
            l_trolin_tbl   :=
                inv_trolin_util.query_rows (p_line_id => pn_mo_line_id);
            inv_pick_wave_pick_confirm_pub.pick_confirm (
                p_api_version_number   => 1.0,
                p_init_msg_list        => fnd_api.g_true,
                p_commit               => fnd_api.g_true,
                x_return_status        => lv_return_status,
                x_msg_count            => ln_msg_count,
                x_msg_data             => lv_msg_data,
                p_move_order_type      => 3,
                p_transaction_mode     => 1,
                p_trolin_tbl           => l_trolin_tbl,
                p_mold_tbl             => l_mold_tbl,
                x_mmtt_tbl             => l_mmtt_tbl,
                x_trolin_tbl           => o_trolin_tbl,
                p_transaction_date     => SYSDATE);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                pv_retcode    := '1';
                pv_errbuf     :=
                       'API to confirm picking failed with status: '
                    || lv_return_status
                    || ' Move Line ID : '
                    || pn_mo_line_id
                    || 'Error: '
                    || lv_msg_data;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || lv_msg_data);
                END LOOP;
            ELSE
                pv_errbuf   :=
                       'API to confirm picking was successful with status: '
                    || lv_return_status;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);

                UPDATE wsh_delivery_details
                   SET attribute15   = 'Pick Confirmed'
                 WHERE move_order_line_id = pn_mo_line_id;
            END IF;
        ELSE
            pv_retcode    := '1';
            pv_errbuf     :=
                   'API to allocate and transact line completed with status: '
                || lv_return_status
                || '. Since number of rows is: 0'
                || pn_mo_line_id
                || ' line cannot be picked.';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            ln_msg_cntr   := 1;
            fnd_file.put_line (fnd_file.LOG, 'lv_msg_data : ' || lv_msg_data);

            WHILE ln_msg_cntr <= ln_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                 , p_msg_index_out => ln_msg_index_out);
                ln_msg_cntr   := ln_msg_cntr + 1;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message: ' || lv_msg_data);
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '1';
            pv_errbuf    :=
                   'Error while picking move order line id '
                || pn_mo_line_id
                || ': '
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END pick_line;

    -- ***************************************************************************
    -- Procedure Name      : create_trip
    -- Description         : This procedure creates a trip with given information.
    --
    -- Parameters          : pv_errbuf               OUT : Error Message
    --                       pv_retcode              OUT : Execution Status
    --                       pv_trip                 IN  : Trip name / Shipment Number
    --                       pv_carrier              IN  : Carrier Name
    --                       pn_carrier_id           IN  : Carrier Id
    --                       pv_ship_method_code     IN  : Ship Method Code
    --                       pv_vehicle_number       IN  : Vehicle Number
    --                       pv_mode_of_transport    IN  : Mode of Transport
    --                       pv_master_bol_number    IN  : Master BOL
    --                       xn_trip_id              OUT : New Trip Id
    --
    -- Return/Exit         : none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE create_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_trip IN VARCHAR2, pv_carrier IN VARCHAR2, pn_carrier_id IN NUMBER, pv_ship_method_code IN VARCHAR2, pv_vehicle_number IN VARCHAR2, pv_mode_of_transport IN VARCHAR2, pv_master_bol_number IN VARCHAR2
                           , xn_trip_id OUT NUMBER)
    IS
        lv_return_status    VARCHAR2 (30) := NULL;
        ln_msg_count        NUMBER;
        ln_msg_cntr         NUMBER;
        ln_msg_index_out    NUMBER;
        lv_msg_data         VARCHAR2 (2000);
        ln_trip_id          NUMBER;
        lv_trip_name        VARCHAR2 (240);
        ln_carrier_id       NUMBER := NULL;
        l_rec_trip_info     wsh_trips_pub.trip_pub_rec_type;
        lv_transport_code   VARCHAR2 (50);
        l_ex_set_error      EXCEPTION;
    BEGIN
        --Reset status variables
        pv_errbuf                           := NULL;
        pv_retcode                          := '0';

        -- Resolve Carrier_ID
        IF pn_carrier_id IS NOT NULL
        THEN
            l_rec_trip_info.carrier_id   := pn_carrier_id;
        ELSE
            BEGIN
                SELECT wcv.carrier_id
                  INTO ln_carrier_id
                  FROM wsh_carriers_v wcv
                 WHERE wcv.carrier_name = pv_carrier;

                l_rec_trip_info.carrier_id   := ln_carrier_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_carrier_id   := NULL;
                    pv_errbuf       :=
                           'No Carrier found by the Name: '
                        || pv_carrier
                        || ' : Error is: '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'No Carrier found by the Name: '
                        || pv_carrier
                        || ' : Error is: '
                        || SQLERRM);
                    RAISE l_ex_set_error;
            END;
        END IF;

        IF pv_mode_of_transport IS NOT NULL
        THEN
            BEGIN
                SELECT lookup_code
                  INTO lv_transport_code
                  FROM fnd_lookup_values_vl flvv
                 WHERE     flvv.lookup_type = 'WSH_MODE_OF_TRANSPORT'
                       AND flvv.meaning = pv_mode_of_transport
                       AND flvv.enabled_flag = 'Y'
                       AND (TRUNC (SYSDATE) BETWEEN NVL (TRUNC (flvv.start_date_active), TRUNC (SYSDATE) - 1) AND NVL (TRUNC (flvv.end_date_active), TRUNC (SYSDATE) + 1));
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_transport_code   := NULL;
                    pv_errbuf           :=
                           'Error while resolving mode of transport from lookup '
                        || 'WSH_MODE_OF_TRANSPORT for the transport code '
                        || pv_mode_of_transport
                        || '. '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while resolving mode of transport from lookup '
                        || 'WSH_MODE_OF_TRANSPORT for the transport code '
                        || pv_mode_of_transport
                        || '. '
                        || SQLERRM);
                    RAISE l_ex_set_error;
            END;
        END IF;

        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling CREATE_UPDATE_TRIP API...');
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG, 'Trip Name      : ' || pv_trip);
        fnd_file.put_line (fnd_file.LOG,
                           'Carrier ID      : ' || ln_carrier_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Ship Method Code  :' || pv_ship_method_code);
        fnd_file.put_line (fnd_file.LOG,
                           'Vehicle Number    :' || pv_vehicle_number);
        fnd_file.put_line (fnd_file.LOG,
                           'Mode Of Transport : ' || lv_transport_code);
        fnd_file.put_line (fnd_file.LOG, ' ');
        l_rec_trip_info.NAME                := pv_trip;
        l_rec_trip_info.carrier_id          := ln_carrier_id;
        l_rec_trip_info.vehicle_number      := pv_vehicle_number;
        l_rec_trip_info.ship_method_code    := pv_ship_method_code;
        l_rec_trip_info.mode_of_transport   := lv_transport_code;
        wsh_trips_pub.create_update_trip (
            p_api_version_number   => gn_api_version_number,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => lv_return_status,
            x_msg_count            => ln_msg_count,
            x_msg_data             => lv_msg_data,
            p_action_code          => 'CREATE',
            p_trip_info            => l_rec_trip_info,
            x_trip_id              => ln_trip_id,
            x_trip_name            => lv_trip_name);

        IF    lv_return_status <> fnd_api.g_ret_sts_success
           OR ln_trip_id IS NULL
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                'API to create trip failed with status: ' || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);

            IF ln_msg_count > 0
            THEN
                xn_trip_id    := 0;
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || lv_msg_data);
                END LOOP;

                pv_errbuf     := lv_msg_data;
            END IF;
        ELSE
            xn_trip_id   := ln_trip_id;
            pv_retcode   := '0';
            pv_errbuf    :=
                   'API to create trip was successful with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Trip ID > '
                || TO_CHAR (ln_trip_id)
                || ': Trip Name > '
                || lv_trip_name);
        END IF;

        -- Reset stop seq number
        fnd_file.put_line (fnd_file.LOG,
                           'End Calling CREATE_UPDATE_TRIP API...');
    EXCEPTION
        WHEN l_ex_set_error
        THEN
            pv_retcode   := '2';
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error occurred in the Creation of Trip while creating trip for Shipment Number: '
                || pv_trip
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error occurred in the Creation of Trip while creating trip for Shipment Number: '
                || pv_trip
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END create_trip;

    -- ***************************************************************************
    -- Procedure Name      : create_stop
    -- Description         : This procedure creates stops for a trip
    --
    -- Parameters          : pv_errbuf               OUT : Error Message
    --                       pv_retcode              OUT : Execution Status
    --                       pv_ship_type            IN  : Shipment Type
    --                       pn_trip_id              IN  : Trip Id
    --                       pn_stop_seq             IN  : Stop Sequence Number
    --                       pn_stop_location_id     IN  : Stop Location Id
    --                       pv_dep_seal_code        IN  : Departure Seal Code
    --                       xn_stop_id              OUT : New Stop Id
    --
    -- Return/Exit         : none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/25    Kranthi Bollam     1.0      Initial Version.
    -- ***************************************************************************
    PROCEDURE create_stop (pv_errbuf                OUT VARCHAR2,
                           pv_retcode               OUT VARCHAR2,
                           pv_ship_type          IN     VARCHAR2,
                           pn_trip_id            IN     VARCHAR2,
                           pn_stop_seq           IN     NUMBER,
                           pn_stop_location_id   IN     VARCHAR2,
                           pv_dep_seal_code      IN     VARCHAR2,
                           xn_stop_id               OUT NUMBER)
    IS
        ln_msg_count       NUMBER;
        ln_msg_cntr        NUMBER;
        ln_msg_index_out   NUMBER;
        lv_msg_data        VARCHAR2 (2000);
        lv_return_status   VARCHAR2 (30) := NULL;
        l_rec_stop_nfo     wsh_trip_stops_pub.trip_stop_pub_rec_type;
        ln_stop_id         NUMBER := 0;
        ln_seq             NUMBER := 0;
    BEGIN
        --Reset status variables
        pv_errbuf                         := NULL;
        pv_retcode                        := '0';

        IF pv_ship_type = 'SHIP_TO'
        THEN
            l_rec_stop_nfo.departure_seal_code   := pv_dep_seal_code;
        END IF;

        l_rec_stop_nfo.trip_id            := pn_trip_id;
        l_rec_stop_nfo.stop_location_id   := pn_stop_location_id;

        IF pn_stop_seq IS NULL
        THEN
            -- Resolve stop sequence number
            BEGIN
                SELECT MAX (stop_sequence_number)
                  INTO ln_seq
                  FROM wsh_trip_stops
                 WHERE trip_id = pn_trip_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_seq   := 0;
            END;

            l_rec_stop_nfo.stop_sequence_number   := NVL (ln_seq, 0) + 10;
        ELSE
            l_rec_stop_nfo.stop_sequence_number   := pn_stop_seq;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Start Calling create update stop API for Stop Number: '
            || l_rec_stop_nfo.stop_sequence_number);
        wsh_trip_stops_pub.create_update_stop (
            p_api_version_number   => gn_api_version_number,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => lv_return_status,
            x_msg_count            => ln_msg_count,
            x_msg_data             => lv_msg_data,
            p_action_code          => 'CREATE',
            p_stop_info            => l_rec_stop_nfo,
            x_stop_id              => ln_stop_id);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'API to create update stop failed with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);

            IF ln_msg_count > 0
            THEN
                xn_stop_id    := 0;
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || lv_msg_data);
                END LOOP;

                pv_errbuf     := lv_msg_data;
            END IF;
        ELSE
            xn_stop_id   := ln_stop_id;
            pv_retcode   := '0';
            pv_errbuf    :=
                   'API to create update stop was successful with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            fnd_file.put_line (fnd_file.LOG,
                               pv_ship_type || ' Stop ID : ' || ln_stop_id);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'End Calling create update stop API...');
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'An unexpected error occurred in the Creation of Stop. Trip ID > '
                || pn_trip_id
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE;
            fnd_file.put_line (
                fnd_file.LOG,
                   'An unexpected error occurred in the Creation of Stop. Trip ID > '
                || pn_trip_id
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END create_stop;

    -- ***************************************************************************
    -- Procedure Name      : split_order_line
    -- Description         : This procedure splits the delivery details by no.of cartons for the order line
    -- Parameters          : pv_shipment_no       IN  : Shipment Number
    --                       pv_delivery_no       IN  : Delivery Number
    --                       pn_order_line        IN :  Order Line Number
    --                       pv_errbuf            OUT : Error Message
    --                       pv_retcode           OUT : Execution Status
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/09    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE split_order_line (pv_errbuf           OUT VARCHAR2,
                                pv_retcode          OUT VARCHAR2,
                                pv_shipment_no   IN     VARCHAR2,
                                pv_delivery_no   IN     VARCHAR2,
                                pn_order_line    IN     NUMBER)
    IS
        CURSOR c_delivery_details IS
              SELECT wdd.delivery_detail_id, wdd.requested_quantity quantity
                FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
               WHERE     wnd.delivery_id = TO_NUMBER (pv_delivery_no)
                     AND wnd.delivery_id = wda.delivery_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     AND wdd.source_code = 'OE'
                     AND wdd.source_line_id = pn_order_line
                     AND wdd.released_status = 'Y'
            ORDER BY wdd.requested_quantity;

        CURSOR c_carton_details IS
              SELECT qty
                FROM xxdo.xxdo_ont_ship_conf_cardtl_stg
               WHERE     1 = 1
                     AND process_status = 'INPROCESS'
                     AND shipment_number = pv_shipment_no
                     AND order_number = pv_delivery_no
                     AND line_number = pn_order_line
            ORDER BY qty DESC;                        --CCR0009256. added sort

        ln_delivery_qty        NUMBER := 0;
        ln_diff_qty            NUMBER := 0;
        ln_remaining_qty       NUMBER := 0;
        lv_errbuf              VARCHAR2 (4000);
        lv_retcode             VARCHAR2 (1);
        ln_new_del_detail_id   NUMBER := 0;
        l_carton_qty_tab       tabtype_id;
        ln_idx                 NUMBER := 1;
        ln_index               NUMBER := 1;
        ln_carry_forward_qty   NUMBER := 0;
        ln_carton_count        NUMBER := 0;
    BEGIN
        ln_remaining_qty   := 0;
        fnd_file.put_line (
            fnd_file.LOG,
               'Inside Split Order Line procedure for Line ID: '
            || pn_order_line);

        IF l_carton_qty_tab.EXISTS (1)
        THEN
            l_carton_qty_tab.DELETE;
        END IF;

        BEGIN
            OPEN c_carton_details;

            FETCH c_carton_details BULK COLLECT INTO l_carton_qty_tab;

            CLOSE c_carton_details;

            ln_carton_count   := l_carton_qty_tab.COUNT;
        EXCEPTION
            WHEN OTHERS
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                       'When Others exception in c_carton_details cursor. Error is:'
                    || SQLERRM);
        END;

        FOR delivery_det_rec IN c_delivery_details
        LOOP
            ln_remaining_qty   := delivery_det_rec.quantity;



            IF     ln_carry_forward_qty > 0
               AND ln_carry_forward_qty < delivery_det_rec.quantity
            THEN
                --SPLIT the delivery detail for ln_carry_forward_qty
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Splitting Delivery Detail ID: '
                        || delivery_det_rec.delivery_detail_id
                        || ' for Qty :'
                        || ln_carry_forward_qty);
                    split_delivery_detail (
                        pv_errbuf               => lv_errbuf,
                        pv_retcode              => lv_retcode,
                        pn_delivery_detail_id   =>
                            delivery_det_rec.delivery_detail_id,
                        pn_split_quantity       => ln_carry_forward_qty,
                        pv_delivery_name        => pv_delivery_no,
                        xn_delivery_detail_id   => ln_new_del_detail_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'New Delivery Detail ID Created: '
                        || ln_new_del_detail_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while invoking split_delivery_detail procedure :'
                            || SQLERRM;
                        --DBMS_OUTPUT.put_line (pv_errbuf);
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        lv_errbuf    := NULL;
                        lv_retcode   := NULL;
                        ROLLBACK;                                      --Added
                --RETURN; --Exit the delivery --Commented on 10Jul2019
                END;

                IF lv_retcode <> '0'
                THEN
                    BEGIN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Error thrown by split_delivery_detail for Carry forward qty Split in Split_order_line procedure. Error is: '
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        --Added below update_error_records on 10Jul2019
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => pv_delivery_no,
                            pv_carton_no       => NULL,
                            pv_line_no         => pn_order_line,
                            pv_item_number     => NULL,
                            pv_error_level     => 'ORDER LINE',
                            pv_error_message   => pv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || lv_errbuf;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;

                    ROLLBACK;                                          --Added
                    RETURN;                                --Exit the delivery
                END IF;

                ln_remaining_qty       := ln_remaining_qty - ln_carry_forward_qty;
                ln_carry_forward_qty   := 0;
                ln_index               := ln_index + 1;
            END IF;

            WHILE ln_remaining_qty > 0 AND ln_carton_count >= ln_index
            LOOP
                IF ln_remaining_qty >= l_carton_qty_tab (ln_index)
                THEN
                    ln_diff_qty        :=
                        ln_remaining_qty - l_carton_qty_tab (ln_index);

                    IF ln_diff_qty > 0
                    THEN
                        --split for ln_diff_qty)
                        BEGIN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Splitting Delivery Detail ID: '
                                || delivery_det_rec.delivery_detail_id
                                || ' for Qty :'
                                || ln_diff_qty);
                            split_delivery_detail (
                                pv_errbuf           => lv_errbuf,
                                pv_retcode          => lv_retcode,
                                pn_delivery_detail_id   =>
                                    delivery_det_rec.delivery_detail_id,
                                pn_split_quantity   => ln_diff_qty,
                                pv_delivery_name    => pv_delivery_no,
                                xn_delivery_detail_id   =>
                                    ln_new_del_detail_id);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'New Delivery Detail ID Created: '
                                || ln_new_del_detail_id);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '2';
                                pv_errbuf    :=
                                       'Unexpected Error while invoking split_delivery_detail procedure :'
                                    || SQLERRM;
                                --DBMS_OUTPUT.put_line (pv_errbuf);
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                                lv_errbuf    := NULL;
                                lv_retcode   := NULL;
                                ROLLBACK;                              --Added
                        --RETURN; --Exit the delivery --Commented on 10Jul2019
                        END;

                        IF lv_retcode <> '0'
                        THEN
                            BEGIN
                                pv_retcode   := '2';
                                pv_errbuf    :=
                                       'Error thrown by split_delivery_detail for Diff Qty Split in Split_order_line procedure. Error is: '
                                    || lv_errbuf;
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                                --Added below update_error_records on 10Jul2019
                                update_error_records (
                                    pv_errbuf          => lv_errbuf,
                                    pv_retcode         => lv_retcode,
                                    pv_shipment_no     => pv_shipment_no,
                                    pv_delivery_no     => pv_delivery_no,
                                    pv_carton_no       => NULL,
                                    pv_line_no         => pn_order_line,
                                    pv_item_number     => NULL,
                                    pv_error_level     => 'ORDER LINE',
                                    pv_error_message   => pv_errbuf,
                                    pv_status          => 'ERROR',
                                    pv_source          => 'DELIVERY_THREAD');
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                           'Unexpected Error while updating error status :'
                                        || lv_errbuf;
                                    --DBMS_OUTPUT.put_line (pv_errbuf);
                                    fnd_file.put_line (fnd_file.LOG,
                                                       pv_errbuf);
                            END;

                            ROLLBACK;                                  --Added
                            RETURN;                        --Exit the delivery
                        END IF;
                    ELSE
                        EXIT;
                    END IF;

                    ln_index           := ln_index + 1;
                    ln_remaining_qty   := ln_diff_qty;
                ELSE
                    ln_carry_forward_qty   :=
                        l_carton_qty_tab (ln_index) - ln_remaining_qty;
                    EXIT;
                END IF;
            END LOOP;                                                 -- while
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error in split_order_line procedure. Error is: '
                || SQLERRM;
            --DBMS_OUTPUT.put_line (pv_errbuf);
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END split_order_line;

    -- ***************************************************************************
    -- Procedure Name      : create_delivery
    -- Description         : This procedure creates Delivery for partial and multiple shipment case
    -- Parameters          : pv_delivery_no       IN  : Delivery Number
    --                       xn_delivery_id       OUT : New Delivery ID
    --                       pv_errbuf            OUT : Error Message
    --                       pv_retcode           OUT : Execution Status
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/09    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE create_delivery (pv_delivery_no IN VARCHAR2, xn_delivery_id OUT NUMBER, pv_errbuf OUT VARCHAR2
                               , pv_retcode OUT VARCHAR2)
    IS
        lv_return_status      VARCHAR2 (30) := NULL;
        ln_msg_count          NUMBER;
        ln_msg_cntr           NUMBER;
        ln_msg_index_out      NUMBER;
        lv_msg_data           VARCHAR2 (2000);
        ln_delivery_id        NUMBER;
        lv_delivery_name      VARCHAR2 (240);
        l_rec_delivery_info   wsh_deliveries_pub.delivery_pub_rec_type;
        ln_trip_id            NUMBER;
        lv_trip_name          VARCHAR2 (240);
        ln_to_stop            NUMBER;

        CURSOR delv_cur IS
            SELECT wnd.*
              FROM wsh_new_deliveries wnd
             WHERE     1 = 1
                   AND wnd.NAME = pv_delivery_no
                   AND wnd.organization_id = gn_inv_org_id
                   AND wnd.status_code = 'OP';
    BEGIN
        --Reset status variables
        pv_retcode   := '0';
        pv_errbuf    := NULL;

        FOR delv_rec IN delv_cur
        LOOP
            -- Set record info variables
            l_rec_delivery_info.organization_id   := delv_rec.organization_id;
            l_rec_delivery_info.customer_id       := delv_rec.customer_id;
            l_rec_delivery_info.ship_method_code   :=
                delv_rec.ship_method_code;
            l_rec_delivery_info.initial_pickup_location_id   :=
                delv_rec.initial_pickup_location_id;
            l_rec_delivery_info.ultimate_dropoff_location_id   :=
                delv_rec.ultimate_dropoff_location_id;
            --l_rec_delivery_info.waybill := delv_rec.waybill;--waybill;
            l_rec_delivery_info.attribute11       :=
                pv_delivery_no;
            --l_rec_delivery_info.attribute2 := delv_rec.attribute2;--carrier;
            --l_rec_delivery_info.attribute1 := delv_rec.attribute1;--tracking_number;

            -- Call create_update_delivery api
            fnd_file.put_line (fnd_file.LOG, ' ');
            fnd_file.put_line (fnd_file.LOG,
                               'Start Calling create update delivery API..');
            wsh_deliveries_pub.create_update_delivery (
                p_api_version_number   => gn_api_version_number,
                p_init_msg_list        => fnd_api.g_true,
                x_return_status        => lv_return_status,
                x_msg_count            => ln_msg_count,
                x_msg_data             => lv_msg_data,
                p_action_code          => 'CREATE',
                p_delivery_info        => l_rec_delivery_info,
                x_delivery_id          => ln_delivery_id,
                x_name                 => lv_delivery_name);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                pv_retcode   := '2';
                pv_errbuf    :=
                       'API to create delivery failed with status: '
                    || lv_return_status;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);

                IF ln_msg_count > 0
                THEN
                    xn_delivery_id   := 0;
                    -- Retrieve messages
                    ln_msg_cntr      := 1;

                    WHILE ln_msg_cntr <= ln_msg_count
                    LOOP
                        fnd_msg_pub.get (
                            p_msg_index       => ln_msg_cntr,
                            p_encoded         => 'F',
                            p_data            => lv_msg_data,
                            p_msg_index_out   => ln_msg_index_out);
                        ln_msg_cntr   := ln_msg_cntr + 1;
                        fnd_file.put_line (fnd_file.LOG,
                                           'Error Message:' || lv_msg_data);
                    END LOOP;
                END IF;
            ELSE
                pv_errbuf        :=
                       'API to create delivery was successful with status: '
                    || lv_return_status;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                xn_delivery_id   := ln_delivery_id;

                BEGIN
                    --Assigning the delivery detail to new delivery was failing since Source header id is blank on the new delivery created in 12.2.3.
                    --So, Source header id is updated on new delivery */
                    UPDATE wsh_new_deliveries
                       SET source_header_id   = delv_rec.source_header_id
                     WHERE delivery_id = ln_delivery_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error updating new Delivery ID > '
                            || TO_CHAR (ln_delivery_id)
                            || ' with source header id. Error is: '
                            || SQLERRM);
                        pv_errbuf    :=
                               'Error updating new Delivery ID > '
                            || TO_CHAR (ln_delivery_id)
                            || ' with source header id. Error is: '
                            || SQLERRM;
                        pv_retcode   := '2';
                END;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Delivery ID > '
                    || TO_CHAR (ln_delivery_id)
                    || ' : Delivery Name > '
                    || lv_delivery_name);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'End Calling create update delivery.api..');
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    := 'Error while creating delivery.' || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'An unexpected error occurred in the Creation of Delivery.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END create_delivery;

    -- ***************************************************************************
    -- Procedure Name      : ship_confirm_trip
    -- Description         : This procedure creates Delivery for partial and multiple shipment case
    -- Parameters          : pv_errbuf           OUT : Error Message
    --                       pv_retcode          OUT : Execution Status
    --                       pn_org_id           IN  : Operating Unit ID
    --                       pn_trip_id          IN  : Trip ID
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/09    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    --Ship Confirm trip
    PROCEDURE ship_confirm_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_org_id IN NUMBER
                                 , pn_trip_id IN NUMBER)
    IS
        p_api_version_number   NUMBER := 1.0;
        p_init_msg_list        VARCHAR2 (1) := fnd_api.g_true;
        --FND_API.G_TRUE = 'T'
        r_action_rec           wsh_trips_pub.action_param_rectype;
        ln_org_id              NUMBER;
        lv_commit              VARCHAR2 (1) := fnd_api.g_false;
        --FND_API.G_FALSE = 'F'
        lv_return_status       VARCHAR2 (200) := NULL;
        ln_msg_count           NUMBER;
        lv_msg_data            VARCHAR2 (2000) := NULL;
        ln_msg_index_out       NUMBER;
        lv_message_data        VARCHAR2 (2000) := NULL;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'Inside Ship Confirm for Trip - START: ' || pn_trip_id);
        r_action_rec.action_code       := 'TRIP-CONFIRM';
        r_action_rec.organization_id   := pn_org_id;
        wsh_trips_pub.trip_action (
            p_api_version_number   => p_api_version_number,
            p_init_msg_list        => p_init_msg_list,
            p_commit               => lv_commit,
            x_return_status        => lv_return_status,
            x_msg_count            => ln_msg_count,
            x_msg_data             => lv_msg_data,
            p_action_param_rec     => r_action_rec,
            p_trip_id              => pn_trip_id,
            p_trip_name            => NULL);
        fnd_file.put_line (
            fnd_file.LOG,
            'Ship Confirm Return Status :   ' || lv_return_status);

        IF ln_msg_count > 0 AND lv_return_status <> 'S'
        THEN
            FOR ln_index IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => ln_index, p_encoded => 'F', p_data => lv_msg_data
                                 , p_msg_index_out => ln_msg_index_out);
                lv_message_data   :=
                    SUBSTR (lv_message_data || lv_msg_data || '. ', 1, 2000);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error message data is:   ' || lv_msg_data);
            END LOOP;

            pv_retcode   := '2';
            pv_errbuf    := lv_message_data;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Inside Ship Confirm for Trip - END: ' || pn_trip_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                'Exception in the Ship Confirm Trip Procedure :' || SQLERRM);
    END ship_confirm_trip;

    -- ***********************************************************************************
    -- Procedure/Function Name  : wait_for_request
    -- Description              : The purpose of this procedure is to make the
    --                            parent request to wait untill unless child
    --                            request completes
    --
    -- parameters               : in_num_parent_req_id  in : Parent Request Id
    --
    -- Return/Exit              : N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version
    -- ***************************************************************************
    PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
    AS
        --Local Variables Declaration
        ln_count                NUMBER := 0;
        ln_num_intvl            NUMBER := 5;
        ln_data_set_id          NUMBER := NULL;
        ln_num_max_wait         NUMBER := 120000;
        lv_chr_phase            VARCHAR2 (250) := NULL;
        lv_chr_status           VARCHAR2 (250) := NULL;
        lv_chr_dev_phase        VARCHAR2 (250) := NULL;
        lv_chr_dev_status       VARCHAR2 (250) := NULL;
        lv_chr_msg              VARCHAR2 (250) := NULL;
        lb_bol_request_status   BOOLEAN;

        --Cursor to fetch the child request id's--
        CURSOR cur_child_req_id IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = in_num_parent_req_id;
    BEGIN
        --Loop for each child request to wait for completion--
        FOR rec_child_req_id IN cur_child_req_id
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (rec_child_req_id.request_id,
                                                 ln_num_intvl,
                                                 ln_num_max_wait,
                                                 lv_chr_phase, -- out parameter
                                                 lv_chr_status, -- out parameter
                                                 lv_chr_dev_phase, -- out parameter
                                                 lv_chr_dev_status, -- out parameter
                                                 lv_chr_msg   -- out parameter
                                                           );

            IF    UPPER (lv_chr_dev_status) = 'WARNING'
               OR UPPER (lv_chr_dev_status) = 'ERROR'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in submitting the request, request_id = '
                    || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_phase =' || lv_chr_phase);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_status =' || lv_chr_status);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error,lv_chr_dev_status =' || lv_chr_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_msg =' || lv_chr_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Request completed');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'request_id = ' || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_chr_msg =' || lv_chr_msg);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error:' || SQLERRM);
    END wait_for_request;

    -- ***************************************************************************
    -- Function Name      : get_email_ids
    -- Description        : This function is used to get list of email recipents for the lookup provided in the parameter
    -- Parameters         : pv_errbuf       OUT : Error Message
    --                      pv_retcode      OUT : Execution Status
    --                      pv_lookup_type  IN  : Lookup Type name
    --
    -- Return/Exit         :  List of email id's in a table type
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 2019/05/21   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION get_email_ids (pv_lookup_type VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        lv_def_mail_recips   do_mail_utils.tbl_recips;

        CURSOR recips_cur IS
            SELECT flv.description email_id
              FROM fnd_lookup_values flv
             WHERE     1 = 1
                   AND flv.lookup_type = pv_lookup_type
                   AND flv.lookup_code LIKE 'EMAIL_ID%'
                   AND flv.enabled_flag = 'Y'
                   AND flv.LANGUAGE = USERENV ('LANG')
                   AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                                   AND NVL (flv.end_date_active, SYSDATE + 1);
    BEGIN
        lv_def_mail_recips.DELETE;

        FOR recips_rec IN recips_cur
        LOOP
            lv_def_mail_recips (lv_def_mail_recips.COUNT + 1)   :=
                recips_rec.email_id;
        END LOOP;

        IF lv_def_mail_recips.COUNT < 1
        THEN
            lv_def_mail_recips (1)   := 'MVDCApplicationSupport@deckers.com';
            lv_def_mail_recips (2)   := 'gcc-ebs-scm@deckers.com';
        END IF;

        RETURN lv_def_mail_recips;
    EXCEPTION
        WHEN OTHERS
        THEN
            lv_def_mail_recips (1)   := 'MVDCApplicationSupport@deckers.com';
            lv_def_mail_recips (2)   := 'gcc-ebs-scm@deckers.com';
            RETURN lv_def_mail_recips;
    END get_email_ids;

    -- ***************************************************************************
    -- Procedure Name      : send_notification
    -- Description         : This procedure is used to send notification based on the notification type
    -- Parameters          : pv_errbuf               OUT : Error Message
    --                       pv_retcode              OUT : Execution Status
    --                       pv_notification_type    IN  : Notification Type
    --                       pn_request_id           IN  : Request ID
    --                       pv_shipment_no          IN  : Shipment Number
    --                       pn_delivery_id          IN  : Delivery ID
    --
    -- Return/Exit         :  None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 2019/05/21   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE send_notification (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_notification_type IN VARCHAR2
                                 , pn_request_id IN NUMBER, pv_shipment_no IN VARCHAR2, pn_delivery_id IN NUMBER)
    IS
        --Error files Cursor
        CURSOR file_error_cur IS
            SELECT process_status, message_id, shipment_num,
                   file_name, error_message, request_id,
                   creation_date
              FROM xxdo_ont_ship_conf_xml_stg
             WHERE     1 = 1
                   AND request_id = pn_request_id
                   AND process_status = 'ERROR';

        CURSOR cur_errored_shipments IS
              SELECT DISTINCT shipment.wh_id, shipment.shipment_number, shipment.master_load_ref,
                              shipment.customer_load_id, shipment.ship_date, shipment.employee_name,
                              delivery.order_number, DECODE (shipment.error_message, NULL, NULL, shipment.error_message || '.') || DECODE (delivery.error_message, NULL, NULL, delivery.error_message || '.') error_message
                FROM xxdo_ont_ship_conf_head_stg shipment, xxdo_ont_ship_conf_order_stg delivery
               WHERE     1 = 1
                     AND shipment.shipment_number = pv_shipment_no
                     AND shipment.request_id = pn_request_id
                     AND shipment.wh_id = delivery.wh_id
                     AND shipment.shipment_number = delivery.shipment_number
                     AND delivery.request_id = pn_request_id
                     AND (shipment.process_status = 'ERROR' OR delivery.process_status = 'ERROR')
            ORDER BY delivery.order_number;

        --Local Variables
        lv_proc_name              VARCHAR2 (30) := 'SEND_NOTIFICATION';
        lv_inst_name              VARCHAR2 (20) := NULL;
        lv_def_mail_recips        do_mail_utils.tbl_recips;
        ln_ret_val                NUMBER := 0;
        lv_err_msg                VARCHAR2 (4000) := NULL;
        ln_file_err_cnt           NUMBER := 0;
        lv_email_body             VARCHAR2 (4000) := NULL;
        lv_out_line               VARCHAR2 (4000) := NULL;
        l_ex_instance_not_known   EXCEPTION;
        l_ex_no_recips            EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'In Send Notification Procedure - START');

        -- Get the instance name - it will be shown in the report
        BEGIN
            SELECT DECODE (applications_system_name, 'EBSPROD', 'PRODUCTION', 'TEST(' || applications_system_name || ')') instance_name
              INTO lv_inst_name
              FROM fnd_product_groups;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_ex_instance_not_known;
        END;

        IF pv_notification_type = 'FILE_ERROR'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In Send Mail Notification Procedure and Notification Type is: '
                || pv_notification_type);

            SELECT COUNT (1)
              INTO ln_file_err_cnt
              FROM xxdo_ont_ship_conf_xml_stg
             WHERE     1 = 1
                   AND request_id = pn_request_id
                   AND process_status = 'ERROR';

            --Now get the email recipients list
            lv_def_mail_recips   :=
                get_email_ids ('XXD_WMS_SHIP_CONFIRM_UTIL_LKP');

            IF lv_def_mail_recips.COUNT < 1
            THEN
                RAISE l_ex_no_recips;
            END IF;

            --Email statements start
            do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Ship Confirm Interface Duplicate Files Notification.' || ' Email generated from ' || lv_inst_name || ' instance'
                                            , ln_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            lv_email_body   :=
                   'Hi All,'
                || CHR (10)
                || CHR (10)
                || 'Please find attached the Ship Confirm Interface duplicate files.'
                || CHR (10)
                || CHR (10)
                || 'Number of files in error   :'
                || ln_file_err_cnt
                || CHR (10)
                || CHR (10)
                || 'Regards'
                || CHR (10)
                || 'Warehouse Support Team';
            do_mail_utils.send_mail_line (lv_email_body, ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_Ship_Confirm_Duplicate_Files_'
                || TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS')
                || '.xls"',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                   'File Name'
                || CHR (9)
                || 'Message ID'
                || CHR (9)
                || 'Shipment Number'
                || CHR (9)
                || 'Status'
                || CHR (9)
                || 'Error Message'
                || CHR (9)
                || 'Process Date'
                || CHR (9),
                ln_ret_val);

            FOR file_error_rec IN file_error_cur
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       file_error_rec.file_name
                    || CHR (9)
                    || file_error_rec.message_id
                    || CHR (9)
                    || file_error_rec.shipment_num
                    || CHR (9)
                    || file_error_rec.process_status
                    || CHR (9)
                    || file_error_rec.error_message
                    || CHR (9)
                    || file_error_rec.creation_date
                    || CHR (9);
                do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
            END LOOP;

            do_mail_utils.send_mail_close (ln_ret_val);
        ELSIF pv_notification_type = 'GENERATE_ERROR_REPORT'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'In Send Mail Notification Procedure and Notification Type is: '
                || pv_notification_type);
            --Now get the email recipients list
            lv_def_mail_recips   :=
                get_email_ids ('XXD_WMS_SHIP_CONFIRM_UTIL_LKP');

            IF lv_def_mail_recips.COUNT < 1
            THEN
                RAISE l_ex_no_recips;
            END IF;

            --Email statements start
            do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Ship Confirm Interface Error Report for Shipment#' || pv_shipment_no || '. Email generated from ' || lv_inst_name || ' instance'
                                            , ln_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            lv_email_body   :=
                   'Hi All,'
                || CHR (10)
                || CHR (10)
                || 'Please find attached the Ship Confirm Interface Error Report for Shipment#'
                || pv_shipment_no
                || '.'
                || CHR (10)
                || CHR (10)
                || '***This is a System generated Email***';
            do_mail_utils.send_mail_line (lv_email_body, ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('Content-Type: text/xls',
                                          ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Content-Disposition: attachment; filename="Deckers_Ship_Confirm_Error_Report_'
                || pv_shipment_no
                || '_'
                || TO_CHAR (SYSDATE, 'RRRRMMDDHH24MISS')
                || '.xls"',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line (
                   'Warehouse'
                || CHR (9)
                || 'shipment_number'
                || CHR (9)
                || 'Master Load Ref'
                || CHR (9)
                || 'Customer Load ID'
                || CHR (9)
                || 'Ship Date'
                || CHR (9)
                || 'Delivery#'
                || CHR (9)
                || 'Error Message'
                || CHR (9),
                ln_ret_val);

            FOR errored_shipments_rec IN cur_errored_shipments
            LOOP
                lv_out_line   := NULL;
                lv_out_line   :=
                       errored_shipments_rec.wh_id
                    || CHR (9)
                    || errored_shipments_rec.shipment_number
                    || CHR (9)
                    || errored_shipments_rec.master_load_ref
                    || CHR (9)
                    || errored_shipments_rec.customer_load_id
                    || CHR (9)
                    || errored_shipments_rec.ship_date
                    || CHR (9)
                    || errored_shipments_rec.order_number
                    || CHR (9)
                    || errored_shipments_rec.error_message;
                do_mail_utils.send_mail_line (lv_out_line, ln_ret_val);
            END LOOP;

            do_mail_utils.send_mail_close (ln_ret_val);
        ELSIF pv_notification_type = 'BACKORDER_FAIL'
        THEN
            --Now get the email recipients list
            lv_def_mail_recips   :=
                get_email_ids ('XXD_WMS_SHIP_CONFIRM_UTIL_LKP');

            IF lv_def_mail_recips.COUNT < 1
            THEN
                RAISE l_ex_no_recips;
            END IF;

            --Email statements start
            do_mail_utils.send_mail_header (fnd_profile.VALUE ('DO_DEF_ALERT_SENDER'), lv_def_mail_recips, 'Ship Confirm Interface Back Order Failed for Delivery#' || pn_delivery_id || '. Email generated from ' || lv_inst_name || ' instance'
                                            , ln_ret_val);
            do_mail_utils.send_mail_line (
                'Content-Type: multipart/mixed; boundary=boundarystring',
                ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_line ('--boundarystring', ln_ret_val);
            do_mail_utils.send_mail_line ('', ln_ret_val);
            do_mail_utils.send_mail_close (ln_ret_val);
        END IF;                                  --pv_notification_type end if

        fnd_file.put_line (fnd_file.LOG,
                           'In Send Notification Procedure - END');
    EXCEPTION
        WHEN l_ex_no_recips
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            lv_err_msg   :=
                SUBSTR (
                       'In When ex_no_recips exception in Package '
                    || gv_package_name
                    || '.'
                    || lv_proc_name
                    || ' . No Recipient email IDs',
                    1,
                    2000);
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
            pv_errbuf    := lv_err_msg;
            pv_retcode   := '2';
        WHEN l_ex_instance_not_known
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            pv_errbuf    := 'Unable to derive the instance';
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        WHEN OTHERS
        THEN
            do_mail_utils.send_mail_close (ln_ret_val);
            pv_errbuf    :=
                   'When Others Exception in SEND_NOTIFICATION procedure. Error is: '
                || SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'When Others Exception in SEND_NOTIFICATION procedure for notification type: '
                || pv_notification_type);
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END send_notification;

    -- ***************************************************************************
    -- Procedure Name      : update_lpn
    -- Description         : This procedure is used to updated old LPN with NEW LPN
    -- Parameters          : p_in_chr_old_lpn        IN  : Old License Plate Number
    --                       p_in_chr_new_lpn        IN  : New License Plate Number
    --                       pv_ret_sts              OUT : Execution Status
    --                       pv_ret_msg              OUT : Error Message
    --
    -- Return/Exit         :  None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 2019/04/15   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE update_lpn (p_in_chr_old_lpn IN VARCHAR2, p_in_chr_new_lpn IN VARCHAR2, pv_ret_sts OUT VARCHAR2
                          , pv_ret_msg OUT VARCHAR2)
    IS
        l_lpn_rec         wms_license_plate_numbers%ROWTYPE;
        l_return_status   VARCHAR2 (1);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (4000);
    BEGIN
        BEGIN
            SELECT lpn_id, organization_id
              INTO l_lpn_rec.lpn_id, l_lpn_rec.organization_id
              FROM wms_license_plate_numbers
             WHERE 1 = 1 AND license_plate_number = p_in_chr_old_lpn;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_lpn_rec.lpn_id            := NULL;
                l_lpn_rec.organization_id   := NULL;
        END;

        --Assign new LPN number
        l_lpn_rec.license_plate_number   := p_in_chr_new_lpn;
        -- To update who columns
        l_lpn_rec.last_updated_by        := gn_user_id;
        l_lpn_rec.last_update_date       := SYSDATE;
        l_lpn_rec.last_update_login      := gn_login_id;
        --Call API to update LPN
        wms_container_pub.modify_lpn (p_api_version => 1, p_init_msg_list => fnd_api.g_false, p_commit => fnd_api.g_false, p_validation_level => fnd_api.g_valid_level_full, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_lpn => l_lpn_rec, p_source_type_id => NULL, p_source_header_id => NULL, p_source_name => NULL, p_source_line_id => NULL
                                      , p_source_line_detail_id => NULL);

        IF l_return_status = fnd_api.g_ret_sts_success
        THEN
            pv_ret_sts   := l_return_status;
            pv_ret_msg   := NULL;
        ELSE
            FOR i IN 1 .. l_msg_count
            LOOP
                l_msg_data   :=
                    apps.fnd_msg_pub.get (p_msg_index => i, p_encoded => 'F');
            END LOOP;

            pv_ret_sts   := l_return_status;
            pv_ret_msg   := l_msg_data;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   '***EXCEPTION in Updating from LPN#'
                || p_in_chr_old_lpn
                || ' to LPN#'
                || p_in_chr_new_lpn
                || ' Error is :'
                || SQLERRM);
            pv_ret_sts   := fnd_api.g_ret_sts_error;
            pv_ret_msg   :=
                   '***EXCEPTION in Updating from LPN#'
                || p_in_chr_old_lpn
                || ' to LPN#'
                || p_in_chr_new_lpn
                || ' Error is :'
                || SQLERRM;
    END update_lpn;

    -- ***************************************************************************
    -- Procedure Name      : remove_ship_set
    -- Description         : This procedure is used to update ship sets
    -- Parameters          : pv_shipment_no      IN  : Shipment Number
    --                       pv_delivery_no      IN  : Delivery Number
    --                       pn_parent_req_id    IN  : Request Id
    --                       pv_ret_sts          OUT : Execution Status
    --                       pv_ret_msg          OUT : Error Message
    --
    -- Return/Exit         :  None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 2019/04/15   Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE remove_ship_set (pv_shipment_no     IN     VARCHAR2,
                               pv_delivery_no     IN     VARCHAR2,
                               pn_parent_req_id   IN     VARCHAR2,
                               pv_ret_sts            OUT VARCHAR2,
                               pv_ret_msg            OUT VARCHAR2)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        --To identify the sales orders for which ship set has to be removed
        CURSOR cur_ship_set_orders IS
            SELECT DISTINCT wnd.source_header_id header_id, ooha.org_id
              FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd, apps.oe_order_headers_all ooha
             WHERE     1 = 1
                   AND s.shipment_number = pv_shipment_no
                   AND s.order_number = pv_delivery_no
                   AND s.request_id = pn_parent_req_id
                   AND s.order_number = wnd.delivery_id
                   AND wnd.organization_id = gn_inv_org_id
                   AND wnd.status_code = 'OP'
                   AND wnd.source_header_id = ooha.header_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all ool
                             WHERE     1 = 1
                                   AND ool.header_id = wnd.source_header_id
                                   AND ool.ship_set_id IS NOT NULL);

        CURSOR line_cur (pn_header_id IN NUMBER)
        IS
            SELECT oel.line_id
              FROM apps.oe_order_lines_all oel
             WHERE     1 = 1
                   AND oel.header_id = pn_header_id
                   AND oel.open_flag = 'Y'
                   AND oel.ship_set_id IS NOT NULL;

        l_api_version_number           NUMBER := 1;
        -- IN Variables --
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_rec                     oe_order_pub.line_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;
        -- OUT Variables --
        l_header_rec_out               oe_order_pub.header_rec_type;
        l_header_val_rec_out           oe_order_pub.header_val_rec_type;
        l_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        l_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        l_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        l_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        l_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        l_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        l_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        l_line_tbl_out                 oe_order_pub.line_tbl_type;
        l_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        l_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        l_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        l_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        l_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        l_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        l_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        l_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        l_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        l_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        i                              NUMBER := 0;
        j                              NUMBER := 0;
        l_return_status                VARCHAR2 (1);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (4000);
        ln_ship_set_same_cnt           NUMBER := 0;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'In Ship Set removal procedure - START');
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_resp_id,
                                    resp_appl_id   => gn_resp_appl_id);
        --Initializing return status to success before start of the loop
        --Even if one order is failed in ship set removal, rollback all the changes and exit delivery
        pv_ret_sts   := '0';

        FOR ship_set_orders_rec IN cur_ship_set_orders
        LOOP
            i                          := i + 1;
            j                          := 0;
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            mo_global.init ('ONT');
            mo_global.set_org_context (ship_set_orders_rec.org_id,
                                       NULL,
                                       'ONT');
            l_header_rec               := oe_order_pub.g_miss_header_rec;
            l_header_rec.operation     := oe_globals.g_opr_update;
            l_header_rec.header_id     := ship_set_orders_rec.header_id;
            l_action_request_tbl (i)   := oe_order_pub.g_miss_request_rec;
            l_line_tbl.DELETE ();

            FOR line_rec IN line_cur (ship_set_orders_rec.header_id)
            LOOP
                j                            := j + 1;
                l_line_tbl (j)               := oe_order_pub.g_miss_line_rec;
                l_line_tbl (j).header_id     := ship_set_orders_rec.header_id;
                l_line_tbl (j).line_id       := line_rec.line_id;
                l_line_tbl (j).operation     := oe_globals.g_opr_update;
                l_line_tbl (j).ship_set_id   := NULL;        --Remove ship set
            END LOOP;                                      --line_cur end loop

            --Calling Process order API
            oe_order_pub.process_order (
                p_api_version_number       => l_api_version_number,
                p_header_rec               => l_header_rec,
                p_line_tbl                 => l_line_tbl,
                p_action_request_tbl       => l_action_request_tbl,
                p_line_adj_tbl             => l_line_adj_tbl,
                x_header_rec               => l_header_rec_out,
                x_header_val_rec           => l_header_val_rec_out,
                x_header_adj_tbl           => l_header_adj_tbl_out,
                x_header_adj_val_tbl       => l_header_adj_val_tbl_out,
                x_header_price_att_tbl     => l_header_price_att_tbl_out,
                x_header_adj_att_tbl       => l_header_adj_att_tbl_out,
                x_header_adj_assoc_tbl     => l_header_adj_assoc_tbl_out,
                x_header_scredit_tbl       => l_header_scredit_tbl_out,
                x_header_scredit_val_tbl   => l_header_scredit_val_tbl_out,
                x_line_tbl                 => l_line_tbl_out,
                x_line_val_tbl             => l_line_val_tbl_out,
                x_line_adj_tbl             => l_line_adj_tbl_out,
                x_line_adj_val_tbl         => l_line_adj_val_tbl_out,
                x_line_price_att_tbl       => l_line_price_att_tbl_out,
                x_line_adj_att_tbl         => l_line_adj_att_tbl_out,
                x_line_adj_assoc_tbl       => l_line_adj_assoc_tbl_out,
                x_line_scredit_tbl         => l_line_scredit_tbl_out,
                x_line_scredit_val_tbl     => l_line_scredit_val_tbl_out,
                x_lot_serial_tbl           => l_lot_serial_tbl_out,
                x_lot_serial_val_tbl       => l_lot_serial_val_tbl_out,
                x_action_request_tbl       => l_action_request_tbl_out,
                x_return_status            => l_return_status,
                x_msg_count                => l_msg_count,
                x_msg_data                 => l_msg_data);

            IF l_return_status <> fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Ship set removal failed for sales order header id : '
                    || l_header_rec_out.header_id);
                ROLLBACK;

                FOR i IN 1 .. l_msg_count
                LOOP
                    l_msg_data   :=
                        oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                END LOOP;

                fnd_file.put_line (fnd_file.LOG,
                                   'Reason for failure  : ' || l_msg_data);
                pv_ret_sts   := '2';
                pv_ret_msg   := l_msg_data;
            END IF;
        END LOOP;                               --cur_ship_set_orders end loop

        IF pv_ret_sts = '0'
        THEN
            COMMIT;
        ELSE
            ROLLBACK;              --Roll back all updates of ship set removal

            --Check if all the lines of the delivery has the same ship set number.. If Yes then return the Success else Return Fail
            SELECT COUNT (DISTINCT oola.ship_set_id)
              INTO ln_ship_set_same_cnt
              FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda,
                   apps.wsh_delivery_details wdd, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
             WHERE     1 = 1
                   AND s.shipment_number = pv_shipment_no
                   AND s.order_number = pv_delivery_no
                   AND s.request_id = pn_parent_req_id
                   AND s.order_number = wnd.delivery_id
                   AND wnd.organization_id = gn_inv_org_id
                   AND wnd.status_code = 'OP'
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.organization_id = gn_inv_org_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status = 'Y'
                   AND wnd.source_header_id = ooha.header_id
                   AND ooha.header_id = oola.line_id
                   AND wdd.source_line_id = oola.line_id;

            IF ln_ship_set_same_cnt = 1
            THEN
                pv_ret_sts   := '0';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'In Ship Set removal Failed. But All the lines in the delivery have same ship set. So proceed with next steps.');
            ELSE
                pv_ret_sts   := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'In Ship Set removal Failed and also the lines in the delivery does not have same ship set. So Complete the program in Error.');
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Ship Set removal procedure - END');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   '***EXCEPTION in removing ship set for delivery#'
                || pv_delivery_no
                || '. Error is :'
                || SQLERRM);
            pv_ret_sts   := '2';
            pv_ret_msg   :=
                   '***EXCEPTION in removing ship set for delivery#'
                || pv_delivery_no
                || '. Error is :'
                || SQLERRM;

            --Check if all the lines of the delivery has the same ship set number.. If Yes the return the Success else Return Fail
            SELECT COUNT (DISTINCT oola.ship_set_id)
              INTO ln_ship_set_same_cnt
              FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda,
                   apps.wsh_delivery_details wdd, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
             WHERE     1 = 1
                   AND s.shipment_number = pv_shipment_no
                   AND s.order_number = pv_delivery_no
                   AND s.request_id = pn_parent_req_id
                   AND s.order_number = wnd.delivery_id
                   AND wnd.organization_id = gn_inv_org_id
                   AND wnd.status_code = 'OP'
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.organization_id = gn_inv_org_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status = 'Y'
                   AND wnd.source_header_id = ooha.header_id
                   AND ooha.header_id = oola.line_id
                   AND wdd.source_line_id = oola.line_id;

            IF ln_ship_set_same_cnt = 1
            THEN
                pv_ret_sts   := '0';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Ship Set removal Failed. But All the lines in the delivery have same ship set. So proceed with next steps.');
            ELSE
                pv_ret_sts   := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'In Ship Set removal Failed and also the lines in the delivery does not have same ship set. So Complete the program in Error.');
            END IF;
    END remove_ship_set;

    -- ***************************************************************************
    -- Procedure Name      : create_shipment_in_stg_tab
    -- Description         : This procedure is used to create a new shipment record in the staging tables for the shipment for which has 'ERROR' deliveries
    -- Parameters          : pv_errbuf       OUT : Error Message
    --                       pv_retcode      OUT : Execution Status
    --                       pv_shipment_no  IN  : Shipment Number
    --                       pn_request_id   IN  : Request ID
    -- Return/Exit         : None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 2019/05/22    Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE create_shipment_in_stg_tab (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2
                                          , pn_request_id IN NUMBER)
    IS
        l_ship_rec            xxdo_ont_ship_conf_head_stg%ROWTYPE;
        ln_err_cnt            NUMBER := 0;
        lv_suffix_num         NUMBER := 0;
        lv_shipment_number    VARCHAR2 (50) := NULL;
        ln_delivery_count     NUMBER := 0;
        ln_delv_error_count   NUMBER := 0;
        --Added on 11Jul2019
        ln_new_shipment_cnt   NUMBER := 0;
    --Added on 11Jul2019
    BEGIN
        SELECT COUNT (1)
          INTO ln_err_cnt
          FROM xxdo_ont_ship_conf_order_stg delv, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
         WHERE     1 = 1
               AND delv.shipment_number = pv_shipment_no
               AND delv.request_id = pn_request_id
               AND delv.shipment_number = carton.shipment_number
               AND delv.order_number = carton.order_number
               AND carton.request_id = pn_request_id
               AND carton.shipment_number = cardtl.shipment_number
               AND carton.order_number = cardtl.order_number
               AND carton.carton_number = cardtl.carton_number
               AND cardtl.request_id = pn_request_id
               AND (delv.process_status = 'ERROR' OR carton.process_status = 'ERROR' OR cardtl.process_status = 'ERROR');

        --Count of deliveries
        SELECT COUNT (DISTINCT delv.order_number)
          INTO ln_delivery_count
          FROM xxdo_ont_ship_conf_order_stg delv
         WHERE     1 = 1
               AND delv.shipment_number = pv_shipment_no
               AND delv.request_id = pn_request_id;

        --Count of Deliveries in Error
        SELECT COUNT (DISTINCT delv.order_number)
          INTO ln_delv_error_count
          FROM xxdo_ont_ship_conf_order_stg delv
         WHERE     1 = 1
               AND delv.shipment_number = pv_shipment_no
               AND delv.request_id = pn_request_id
               AND delv.process_status = 'ERROR';

        --If errors exists and shipment has multiple deliveries then only create a new shipment
        IF     ln_err_cnt > 0
           AND ln_delivery_count > 1
           AND ln_delv_error_count < ln_delivery_count
        THEN
            BEGIN
                SELECT ship.*
                  INTO l_ship_rec
                  FROM xxdo_ont_ship_conf_head_stg ship
                 WHERE     1 = 1
                       AND ship.shipment_number = pv_shipment_no
                       AND ship.request_id = pn_request_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            IF INSTR (l_ship_rec.shipment_number, '_') > 0
            THEN
                lv_suffix_num   :=
                    TO_NUMBER (
                        SUBSTR (l_ship_rec.shipment_number,
                                INSTR (l_ship_rec.shipment_number, '_') + 1));
                lv_suffix_num   := lv_suffix_num + 1;
                lv_shipment_number   :=
                       SUBSTR (l_ship_rec.shipment_number,
                               1,
                               INSTR (l_ship_rec.shipment_number, '_'))
                    || lv_suffix_num;
            ELSE
                lv_suffix_num   := 1;
                lv_shipment_number   :=
                    l_ship_rec.shipment_number || '_' || lv_suffix_num;
            END IF;

            BEGIN
                INSERT INTO xxdo_ont_ship_conf_head_stg (wh_id,
                                                         shipment_number,
                                                         master_load_ref,
                                                         customer_load_id,
                                                         carrier,
                                                         service_level,
                                                         pro_number,
                                                         comments,
                                                         ship_date,
                                                         seal_number,
                                                         trailer_number,
                                                         employee_id,
                                                         employee_name,
                                                         process_status,
                                                         error_message,
                                                         request_id,
                                                         creation_date,
                                                         created_by,
                                                         last_update_date,
                                                         last_updated_by,
                                                         source_type,
                                                         attribute1,
                                                         attribute2,
                                                         attribute3,
                                                         attribute4,
                                                         attribute5,
                                                         attribute6,
                                                         attribute7,
                                                         attribute8,
                                                         attribute9,
                                                         attribute10,
                                                         attribute11,
                                                         attribute12,
                                                         attribute13,
                                                         attribute14,
                                                         attribute15,
                                                         attribute16,
                                                         attribute17,
                                                         attribute18,
                                                         attribute19,
                                                         attribute20,
                                                         SOURCE,
                                                         destination,
                                                         record_type,
                                                         bol_number,
                                                         shipment_type, -- Added for CCR0008881
                                                         sales_channel -- Added for CCR0008881
                                                                      )
                         VALUES (l_ship_rec.wh_id,
                                 lv_shipment_number,
                                 l_ship_rec.master_load_ref,
                                 l_ship_rec.customer_load_id,
                                 l_ship_rec.carrier,
                                 l_ship_rec.service_level,
                                 l_ship_rec.pro_number,
                                 l_ship_rec.comments,
                                 l_ship_rec.ship_date,
                                 l_ship_rec.seal_number,
                                 l_ship_rec.trailer_number,
                                 l_ship_rec.employee_id,
                                 l_ship_rec.employee_name,
                                 'ERROR',                     --process_status
                                 NULL,                         --Error Message
                                 pn_request_id,               --gn_request_id,
                                 SYSDATE,                      --creation_date
                                 gn_user_id,                      --created_by
                                 SYSDATE,                   --last_update_date
                                 gn_user_id,                 --last_updated_by
                                 l_ship_rec.source_type,
                                 l_ship_rec.attribute1,
                                 l_ship_rec.attribute2,
                                 l_ship_rec.attribute3,
                                 l_ship_rec.attribute4,
                                 l_ship_rec.attribute5,
                                 l_ship_rec.attribute6,
                                 l_ship_rec.attribute7,
                                 l_ship_rec.attribute8,
                                 l_ship_rec.attribute9,
                                 l_ship_rec.attribute10,
                                 l_ship_rec.attribute11,
                                 l_ship_rec.attribute12,
                                 l_ship_rec.attribute13,
                                 l_ship_rec.attribute14,
                                 l_ship_rec.attribute15,
                                 l_ship_rec.attribute16,
                                 l_ship_rec.attribute17,
                                 l_ship_rec.attribute18,
                                 l_ship_rec.attribute19,
                                 l_ship_rec.attribute20,
                                 l_ship_rec.SOURCE,
                                 l_ship_rec.destination,
                                 l_ship_rec.record_type,
                                 l_ship_rec.bol_number,
                                 l_ship_rec.shipment_type, -- Added for CCR0008881
                                 l_ship_rec.sales_channel -- Added for CCR0008881
                                                         );

                SELECT COUNT (1)
                  INTO ln_new_shipment_cnt
                  FROM xxdo_ont_ship_conf_head_stg
                 WHERE     shipment_number = lv_shipment_number
                       AND request_id = pn_request_id;

                IF ln_new_shipment_cnt > 0
                THEN
                    UPDATE xxdo_ont_ship_conf_order_stg
                       SET shipment_number = lv_shipment_number, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND process_status = 'ERROR'
                           AND shipment_number = pv_shipment_no
                           AND request_id = pn_request_id;

                    UPDATE xxdo_ont_ship_conf_carton_stg
                       SET shipment_number = lv_shipment_number, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND process_status = 'ERROR'
                           AND shipment_number = pv_shipment_no
                           AND request_id = pn_request_id;

                    UPDATE xxdo_ont_ship_conf_cardtl_stg
                       SET shipment_number = lv_shipment_number, last_updated_by = gn_user_id, last_update_date = SYSDATE
                     WHERE     1 = 1
                           AND process_status = 'ERROR'
                           AND shipment_number = pv_shipment_no
                           AND request_id = pn_request_id;

                    COMMIT;                               --Added on 11Jul2019
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Unable to create New Shipment in Shipment Staging table.');
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;                             --Added on 11Jul2019
                    fnd_file.put_line (
                        fnd_file.LOG,
                           '***EXCEPTION in Inserting a new shipment record in shipment header staging table'
                        || pv_shipment_no
                        || '. Error is :'
                        || SQLERRM);
            END;
        END IF;                                            --ln_err_cnt end if
    --      COMMIT; --Added on 10Jul2019
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                   '***EXCEPTION while creating a new shipment record in shipment header staging table'
                || pv_shipment_no
                || '. Error is :'
                || SQLERRM);
            pv_retcode   := '2';
            pv_errbuf    :=
                   '***EXCEPTION in creating a new shipment record in shipment header staging table'
                || pv_shipment_no
                || '. Error is :'
                || SQLERRM;
    END create_shipment_in_stg_tab;

    -- ***************************************************************************
    -- Procedure Name      : ship_confirm_main
    -- Description         : This is the driver procedure for ship confirm interface
    -- Parameters          : pv_errbuf       OUT : Error Message
    --                       pv_retcode      OUT : Execution Status
    --                       pv_shipment_no   IN  : Shipment Number
    --
    -- Return/Exit         :  None
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    -- Date          Author                Version  Description
    -- ------------  -----------------     -------  --------------------------------
    -- 2019/04/15    Kranthi Bollam        1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE ship_confirm_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2)
    IS
        --Cursor to get shipments in error
        CURSOR ship_err_cur IS
            SELECT xsch.*
              FROM xxdo.xxdo_ont_ship_conf_head_stg xsch
             WHERE     1 = 1
                   AND xsch.process_status = 'ERROR'
                   AND xsch.shipment_number =
                       NVL (pv_shipment_no, shipment_number);

        --Cursor to get shipments to be processed
        CURSOR ship_cur IS
              SELECT xsch.*
                FROM xxdo.xxdo_ont_ship_conf_head_stg xsch
               WHERE     1 = 1
                     AND xsch.process_status = 'NEW'
                     AND xsch.shipment_number =
                         NVL (pv_shipment_no, shipment_number)
            --Pick only the shipment which are in PROCESSED status in XML staging table
            --         AND EXISTS (
            --                     SELECT 1
            --                       FROM xxdo.xxdo_ont_ship_conf_xml_stg xml_stg
            --                      WHERE 1=1
            --                        AND xml_stg.shipment_num = xsch.shipment_number
            --                        AND xml_stg.process_status = 'PROCESSED'
            --                    )
            ORDER BY xsch.bol_number NULLS FIRST --Process the PARCEL shipments first and then the other one's
                                                , xsch.shipment_number;

        lv_errbuf        VARCHAR2 (4000);
        lv_retcode       VARCHAR2 (30);
        lb_req_status    BOOLEAN;
        lv_req_failure   VARCHAR2 (1) := 'N';
        lv_phase         VARCHAR2 (100) := NULL;
        lv_status        VARCHAR2 (100) := NULL;
        lv_dev_phase     VARCHAR2 (100) := NULL;
        lv_dev_status    VARCHAR2 (100) := NULL;
        lv_message       VARCHAR2 (1000) := NULL;
        ln_request_id    NUMBER := 0;
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
               'HJ to EBS Ship Confirm Interface Program Started - '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (fnd_file.LOG, 'Parameters');
        fnd_file.put_line (fnd_file.LOG,
                           '------------------------------------');
        fnd_file.put_line (fnd_file.LOG,
                           'Shipment Number: ' || pv_shipment_no);
        fnd_file.put_line (fnd_file.LOG,
                           '------------------------------------');
        /* below reset is not required. Commented by Kranthi on 24Jun2019
          fnd_file.put_line (
           fnd_file.LOG,
              'Calling RESET_ERROR_RECORDS Procedure - START '
           || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --Reset Shipments in 'ERROR' to 'NEW' status
        FOR ship_err_rec IN ship_err_cur
        LOOP
           lv_errbuf := NULL;
           lv_retcode := NULL;
           reset_error_records (
              pv_errbuf        => lv_errbuf,
              pv_retcode       => lv_retcode,
              pv_shipment_no   => ship_err_rec.shipment_number);
        END LOOP;
        COMMIT;           -- Commit after the 'ERROR' records are reset to 'NEW'
        fnd_file.put_line (
           fnd_file.LOG,
              'Calling RESET_ERROR_RECORDS Procedure - END '
           || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        */
        fnd_file.put_line (
            fnd_file.LOG,
               'Submitting Child program for each shipment - START '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        --Now process Shipments in 'NEW' status
        --Spawn a Ship Confirm Child concurrent request for each shipment
        FOR ship_rec IN ship_cur
        LOOP
            ln_request_id   := NULL;

            BEGIN
                ln_request_id   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXD_HJ_EBS_SHIP_CONFIRM_CHILD',
                        description   => NULL,
                        start_time    => NULL,
                        sub_request   => FALSE,
                        argument1     => ship_rec.shipment_number --Parameter1
                                                                 );
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error in submitting Shipment Processor program for Shipment Number:'
                        || ship_rec.shipment_number);
                    fnd_file.put_line (fnd_file.LOG, 'Error is:' || SQLERRM);
            END;

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Ship Confirm Processor Program submitted for Shipment Number:'
                || ship_rec.shipment_number
                || ' with request id:'
                || ln_request_id);
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Submitting Child program for each shipment - END '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'HJ to EBS Ship Confirm Interface Program END - '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    :=
                SUBSTR ('Main Exception:  Error is : ' || SQLERRM, 1, 2000);
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END ship_confirm_main;

    -- ***************************************************************************
    -- Procedure Name      : MAIN
    --
    -- Description         : This procedure created for "Deckers HJ to EBS Ship Confirm Child Program"(XXD_HJ_EBS_SHIP_CONFIRM_CHILD)
    --                       which is submitted for each shipment "Deckers HJ to EBS Ship Confirm Program" (XXD_HJ_EBS_SHIP_CONFIRM)
    -- Parameters          : pv_errbuf           OUT : Error Message
    --                       pv_retcode          OUT : Execution Status
    --                       pv_shipment_no      IN  : Shipment Number
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author                  Version  Description
    -- ------------  ---------------------   -------  ---------------------------
    -- 2019/05/02    Kranthi Bollam          1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE main (pv_errbuf           OUT VARCHAR2,
                    pv_retcode          OUT VARCHAR2,
                    pv_shipment_no   IN     VARCHAR2)
    IS
        lv_errbuf                    VARCHAR2 (4000);
        lv_retcode                   VARCHAR2 (30);
        lb_req_status                BOOLEAN;
        lv_req_failure               VARCHAR2 (1) := 'N';
        lv_phase                     VARCHAR2 (100) := NULL;
        lv_status                    VARCHAR2 (100) := NULL;
        lv_dev_phase                 VARCHAR2 (100) := NULL;
        lv_dev_status                VARCHAR2 (100) := NULL;
        lv_message                   VARCHAR2 (1000) := NULL;
        ln_request_id                NUMBER := 0;
        ln_carton_upd_err_cnt        NUMBER := 0;
        lv_suffix_num                NUMBER := 0;
        lv_new_carton_number         VARCHAR2 (22) := NULL;
        l_ex_bulk_fetch_failed       EXCEPTION;
        ln_inv_org_id                NUMBER;           -- Added for CCR0009784
        ln_check                     NUMBER;           -- Added for CCR0009784

        CURSOR cur_shipment_data IS
            SELECT shipment_number
              FROM xxdo_ont_ship_conf_head_stg shipment
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND request_id = gn_request_id
                   AND shipment_number = pv_shipment_no;

        TYPE l_ship_headers_obj_tab_type
            IS TABLE OF cur_shipment_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_shipconf_headers_obj_tab   l_ship_headers_obj_tab_type;

        --Check if carton already exists or not for the shipment
        CURSOR cur_existing_cartons IS
            SELECT carton.order_number, carton.carton_number
              FROM xxdo_ont_ship_conf_carton_stg carton, wms_license_plate_numbers lpn
             WHERE     carton.process_status = 'INPROCESS'
                   AND shipment_number = pv_shipment_no
                   AND carton.carton_number = lpn.license_plate_number
                   AND carton.request_id = gn_request_id;
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        IF g_all_hold_source_tbl.EXISTS (1)
        THEN
            g_all_hold_source_tbl.DELETE;
        END IF;

        -- Start for CCR0009784
        BEGIN
            SELECT mp.organization_id
              INTO ln_inv_org_id
              FROM mtl_parameters mp, xxdo_ont_ship_conf_head_stg head
             WHERE     1 = 1
                   AND mp.organization_code = head.wh_id
                   AND head.shipment_number = pv_shipment_no;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_inv_org_id   := NULL;
        END;

        BEGIN
            SELECT COUNT (1)
              INTO ln_check
              FROM wsh_new_deliveries wnd1, wsh_delivery_details wdd1, wsh_delivery_assignments wda1,
                   xxdo_ont_ship_conf_cardtl_stg stg1, xxdo.xxdo_ont_ship_conf_head_stg head1
             WHERE     1 = 1
                   AND wnd1.NAME = stg1.order_number
                   AND stg1.shipment_number = head1.shipment_number
                   AND wnd1.organization_id = ln_inv_org_id
                   AND wnd1.delivery_id = wda1.delivery_id
                   AND wda1.delivery_detail_id = wdd1.delivery_detail_id
                   AND head1.process_status = 'INPROCESS'
                   --AND head1.request_id = gn_request_id
                   AND wdd1.organization_id = ln_inv_org_id
                   AND wdd1.source_code = 'OE'
                   AND EXISTS
                           (SELECT 1
                              FROM wsh_new_deliveries wnd, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                                   xxdo_ont_ship_conf_cardtl_stg stg, xxdo.xxdo_ont_ship_conf_head_stg head
                             WHERE     1 = 1
                                   AND wnd.NAME = stg.order_number
                                   AND stg.shipment_number =
                                       head.shipment_number
                                   AND head.shipment_number = pv_shipment_no
                                   AND wdd1.source_header_id =
                                       wdd.source_header_id
                                   AND wnd.organization_id = ln_inv_org_id
                                   AND wnd.delivery_id = wda.delivery_id
                                   AND wda.delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND wdd.organization_id = ln_inv_org_id
                                   AND wdd.source_code = 'OE');
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_check   := 0;
        END;

        IF ln_check = 0
        THEN
            -- End for CCR0009784

            lv_errbuf               := NULL;
            lv_retcode              := '0';
            -- Lock the records by updating the status to INPROCESS and request id to current request id
            lock_records (pv_errbuf        => lv_errbuf,
                          pv_retcode       => lv_retcode,
                          pv_shipment_no   => pv_shipment_no);

            IF lv_retcode <> '0'
            THEN
                apps.fnd_file.put_line (
                    apps.fnd_file.LOG,
                    'Unable to Lock Records. Exiting the program.');
                pv_errbuf    := lv_errbuf;
                pv_retcode   := '2';
                RETURN;
            END IF;

            BEGIN
                SELECT mp.organization_id
                  INTO gn_inv_org_id
                  FROM mtl_parameters mp, xxdo_ont_ship_conf_head_stg head
                 WHERE     1 = 1
                       AND mp.organization_code = head.wh_id
                       AND head.shipment_number = pv_shipment_no
                       AND head.request_id = gn_request_id
                       AND head.process_status = 'INPROCESS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                        SUBSTR (
                               'Error in Getting Inventory Org ID For warehouse. Error is: '
                            || SQLERRM,
                            1,
                            2000);
                    pv_retcode   := '2';
                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                        'Exiting the program as there is ' || pv_errbuf);

                    ---Added code to update staging tables on 10Jul2019 before exiting the program
                    BEGIN
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => NULL,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'SHIPMENT',
                            pv_error_message   => pv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                'Unexpected Error while updating error in Getting Inventory Org ID for wareshouse.';
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;

                    RETURN;                              --Exiting the program
            END;

            --Apps initialization for API call to update LPN's
            fnd_global.apps_initialize (gn_user_id,
                                        gn_resp_id,
                                        gn_resp_appl_id);

            FOR existing_cartons_rec IN cur_existing_cartons
            LOOP
                lv_retcode   := NULL;
                lv_errbuf    := NULL;

                IF INSTR (existing_cartons_rec.carton_number, '_') > 0
                THEN
                    lv_suffix_num   :=
                        TO_NUMBER (
                            SUBSTR (
                                existing_cartons_rec.carton_number,
                                  INSTR (existing_cartons_rec.carton_number,
                                         '_')
                                + 1));
                    lv_suffix_num   := lv_suffix_num + 1;
                    lv_new_carton_number   :=
                           SUBSTR (
                               existing_cartons_rec.carton_number,
                                 INSTR (existing_cartons_rec.carton_number,
                                        '_')
                               - 1)
                        || '_'
                        || lv_suffix_num;
                ELSE
                    lv_suffix_num   := 1;
                    lv_new_carton_number   :=
                           existing_cartons_rec.carton_number
                        || '_'
                        || lv_suffix_num;
                END IF;

                update_lpn (p_in_chr_old_lpn => existing_cartons_rec.carton_number, p_in_chr_new_lpn => lv_new_carton_number, --existing_cartons_rec.carton_number || '_1',
                                                                                                                              pv_ret_sts => lv_retcode
                            , pv_ret_msg => lv_errbuf);

                IF lv_retcode = fnd_api.g_ret_sts_success
                THEN
                    UPDATE xxdo_ont_ship_conf_carton_stg carton
                       SET carton.attribute1 = 'WMS Carton Number Suffixed with _' || lv_suffix_num, last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     1 = 1
                           AND carton.process_status = 'INPROCESS'
                           AND carton.shipment_number = pv_shipment_no
                           AND carton.carton_number =
                               existing_cartons_rec.carton_number
                           AND carton.request_id = gn_request_id;

                    UPDATE xxdo_ont_ship_conf_cardtl_stg cardtl
                       SET cardtl.attribute1 = 'WMS Carton Number Suffixed with _' || lv_suffix_num, last_update_date = SYSDATE, last_updated_by = gn_user_id
                     WHERE     1 = 1
                           AND cardtl.process_status = 'INPROCESS'
                           AND cardtl.shipment_number = pv_shipment_no
                           AND cardtl.carton_number =
                               existing_cartons_rec.carton_number
                           AND cardtl.request_id = gn_request_id;

                    COMMIT;        --Commit if the LPN is successfully updated
                ELSE
                    pv_errbuf    :=
                        SUBSTR (
                               'Error in updating LPN#'
                            || existing_cartons_rec.carton_number
                            || ' to LPN#'
                            || lv_new_carton_number
                            || '. Error is:'
                            || lv_errbuf,
                            1,
                            2000);
                    pv_retcode   := '2';

                    BEGIN
                        update_error_records (
                            pv_errbuf        => lv_errbuf,
                            pv_retcode       => lv_retcode,
                            pv_shipment_no   => pv_shipment_no,
                            pv_delivery_no   =>
                                existing_cartons_rec.order_number,
                            pv_carton_no     =>
                                existing_cartons_rec.carton_number,
                            pv_line_no       => NULL,
                            pv_item_number   => NULL,
                            pv_error_level   => 'CARTON',
                            pv_error_message   =>
                                'Carton already Exists and LPN update failed',
                            pv_status        => 'ERROR',
                            pv_source        => 'DELIVERY_THREAD');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Carton already Exists and LPN update failed');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                'Unexpected Error while updating error for Carton already Exists and LPN update failed.';
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;

                    EXIT;                                      --Exit the loop
                END IF;
            END LOOP;

            ln_carton_upd_err_cnt   := 0;

            SELECT COUNT (1)
              INTO ln_carton_upd_err_cnt
              FROM xxdo_ont_ship_conf_carton_stg carton
             WHERE     1 = 1
                   AND carton.process_status = 'ERROR'
                   AND carton.request_id = gn_request_id
                   AND shipment_number = pv_shipment_no;

            --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
            IF ln_carton_upd_err_cnt > 0
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf        => lv_errbuf,
                        pv_retcode       => lv_retcode,
                        pv_shipment_no   => pv_shipment_no,
                        pv_delivery_no   => NULL,
                        pv_carton_no     => NULL,
                        pv_line_no       => NULL,
                        pv_item_number   => NULL,
                        pv_error_level   => 'SHIPMENT',
                        pv_error_message   =>
                            'One or more Cartons already exists in EBS and LPN update failed',
                        pv_status        => 'ERROR',
                        pv_source        => 'SHIPMENT_THREAD_BEFORE_DT');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'One or more Cartons already exists in EBS and LPN update failed');
                    pv_retcode   := '2';
                    pv_errbuf    :=
                        'One or more Cartons already exists in EBS and LPN update failed';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                            'Unexpected Error while updating error for One or more Cartons already exists in EBS and LPN update failed';
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;

                ROLLBACK;
                RETURN;                                    --Exit the Shipment
            END IF;

            -- Process the shipments which share the same deliveries
            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling SHIPMENT_THREAD procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            lv_errbuf               := NULL;
            lv_retcode              := '0';

            BEGIN
                shipment_thread (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pv_shipment_no => pv_shipment_no
                                 , pn_parent_req_id => gn_request_id);
                pv_retcode   := lv_retcode;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while calling SHIPMENT_THREAD procedure : '
                        || SQLERRM;
                    pv_retcode   := '2';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);

                    --Update the process status in all staging tables for this shipment from 'INPROCESS' to 'ERROR'
                    BEGIN
                        update_error_records (
                            pv_errbuf        => lv_errbuf,
                            pv_retcode       => lv_retcode,
                            pv_shipment_no   => pv_shipment_no,
                            pv_delivery_no   => NULL,
                            pv_carton_no     => NULL,
                            pv_line_no       => NULL,
                            pv_item_number   => NULL,
                            pv_error_level   => 'SHIPMENT',
                            pv_error_message   =>
                                'Unexpected error while calling SHIPMENT_THREAD procedure',
                            pv_status        => 'ERROR',
                            pv_source        => 'SHIPMENT_THREAD_BEFORE_DT');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'One or more Cartons already exists in EBS and LPN update failed');
                        pv_retcode   := '2';
                        pv_errbuf    :=
                            'One or more Cartons already exists in EBS and LPN update failed';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                'Unexpected Error while updating error for One or more Cartons already exists in EBS and LPN update failed';
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;

                    RETURN;                                --Exit the Shipment
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling SHIPMENT_THREAD procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

            --Reapply holds that are released
            IF g_all_hold_source_tbl.EXISTS (1)
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Calling reapply_holds procedure if holds are released - START. Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

                BEGIN
                    reapply_holds (
                        pv_errbuf           => lv_errbuf,
                        pv_retcode          => lv_retcode,
                        p_hold_source_tbl   => g_all_hold_source_tbl);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_errbuf    := SQLERRM;
                        pv_retcode   := '1';
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unexpected error while invoking reapply holds procedure : '
                            || pv_errbuf);
                END;

                IF lv_retcode <> '0'
                THEN
                    pv_errbuf    :=
                        'Hold application has failed. Please refer the log file fore more details';
                    pv_retcode   := '1';
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Calling reapply_holds procedure if holds are released - END. Timestamp: '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling Generate error report procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            --Generate the error report for this shipment
            lv_errbuf               := NULL;
            lv_retcode              := '0';

            BEGIN
                generate_error_report (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pv_shipment_no => pv_shipment_no
                                       , pn_request_id => gn_request_id);

                IF lv_retcode <> '0'
                THEN
                    pv_errbuf    :=
                           'Error in Generate Error Report procedure : '
                        || lv_errbuf;
                    pv_retcode   := '1';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while Generate Error Report procedure : '
                        || SQLERRM;
                    pv_retcode   := '1';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling Generate error report procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            --Create a new shipment record in the header staging table if there are
            --any deliveries in ERROR for this shipment with shipment number as shipment_number_1 or _2 or increment the number
            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling CREATE_SHIPMENT_IN_STG_TAB procedure - START. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
            lv_errbuf               := NULL;
            lv_retcode              := '0';

            BEGIN
                create_shipment_in_stg_tab (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pv_shipment_no => pv_shipment_no
                                            , pn_request_id => gn_request_id);

                IF lv_retcode <> '0'
                THEN
                    pv_errbuf    :=
                           'Error in CREATE_SHIPMENT_IN_STG_TAB procedure : '
                        || lv_errbuf;
                    pv_retcode   := '1';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while CREATE_SHIPMENT_IN_STG_TAB procedure : '
                        || SQLERRM;
                    pv_retcode   := '1';
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Calling CREATE_SHIPMENT_IN_STG_TAB procedure - END. Timestamp: '
                || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        END IF;                                        -- Added for CCR0009784
    EXCEPTION
        WHEN l_ex_bulk_fetch_failed
        THEN
            pv_retcode   := '2';
        WHEN OTHERS
        THEN
            pv_errbuf    := 'Unexpected error at MAIN procedure : ' || SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END main;

    -- ***************************************************************************
    -- Procedure Name      : generate_error_report
    -- Description         : This procedure is to generate the error report for the current run
    --
    -- Parameters          : pv_errbuf       OUT : Error message
    --                       pv_retcode      OUT : Execution status
    --                       pv_shipment_no  IN  : Shipment Number
    --                       pn_request_id   IN  : Request ID
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE generate_error_report (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2
                                     , pn_request_id IN NUMBER)
    IS
        lv_errbuf      VARCHAR2 (4000) := NULL;
        lv_retcode     VARCHAR2 (1) := '0';
        ln_error_cnt   NUMBER := 0;

        CURSOR cur_errored_shipments IS
            SELECT DISTINCT shipment.wh_id, shipment.shipment_number, shipment.master_load_ref,
                            shipment.customer_load_id, shipment.ship_date, shipment.employee_name,
                            delivery.order_number, shipment.error_message || ' ' || delivery.error_message error_message
              FROM xxdo_ont_ship_conf_head_stg shipment, xxdo_ont_ship_conf_order_stg delivery, xxdo_ont_ship_conf_carton_stg carton,
                   xxdo_ont_ship_conf_cardtl_stg cardtl
             WHERE     1 = 1
                   AND shipment.shipment_number = pv_shipment_no
                   AND shipment.request_id = pn_request_id
                   AND shipment.wh_id = delivery.wh_id
                   AND shipment.shipment_number = delivery.shipment_number
                   AND delivery.request_id = pn_request_id
                   AND delivery.wh_id = carton.wh_id
                   AND delivery.shipment_number = carton.shipment_number
                   AND delivery.order_number = carton.order_number
                   AND carton.request_id = pn_request_id
                   AND carton.wh_id = cardtl.wh_id
                   AND carton.shipment_number = cardtl.shipment_number
                   AND carton.order_number = cardtl.order_number
                   AND carton.carton_number = cardtl.carton_number
                   AND cardtl.request_id = pn_request_id
                   AND (shipment.process_status = 'ERROR' OR delivery.process_status = 'ERROR' OR carton.process_status = 'ERROR' OR cardtl.process_status = 'ERROR');
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        SELECT COUNT (1)
          INTO ln_error_cnt
          FROM xxdo_ont_ship_conf_head_stg shipment, xxdo_ont_ship_conf_order_stg delivery, xxdo_ont_ship_conf_carton_stg carton,
               xxdo_ont_ship_conf_cardtl_stg cardtl
         WHERE     1 = 1
               AND shipment.shipment_number = pv_shipment_no
               AND shipment.request_id = pn_request_id
               AND shipment.wh_id = delivery.wh_id
               AND shipment.shipment_number = delivery.shipment_number
               AND delivery.request_id = pn_request_id
               AND delivery.wh_id = carton.wh_id
               AND delivery.shipment_number = carton.shipment_number
               AND delivery.order_number = carton.order_number
               AND carton.request_id = pn_request_id
               AND carton.shipment_number = cardtl.shipment_number
               AND carton.order_number = cardtl.order_number
               AND carton.carton_number = cardtl.carton_number
               AND carton.wh_id = cardtl.wh_id
               AND cardtl.request_id = pn_request_id
               AND (shipment.process_status = 'ERROR' OR delivery.process_status = 'ERROR' OR carton.process_status = 'ERROR' OR cardtl.process_status = 'ERROR');

        fnd_file.put_line (fnd_file.LOG,
                           'Error Records Count : ' || ln_error_cnt);

        IF ln_error_cnt > 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Generating Error Report.');
            fnd_file.put_line (
                fnd_file.output,
                'Warehouse Code|Shipment Number|Master Load Ref|Customer Load Id|Ship Date|Employee Name|Order Number|Error Message');

            FOR errored_shipments_rec IN cur_errored_shipments
            LOOP
                fnd_file.put_line (
                    fnd_file.output,
                       errored_shipments_rec.wh_id
                    || '|'
                    || errored_shipments_rec.shipment_number
                    || '|'
                    || errored_shipments_rec.master_load_ref
                    || '|'
                    || errored_shipments_rec.customer_load_id
                    || '|'
                    || errored_shipments_rec.ship_date
                    || '|'
                    || errored_shipments_rec.employee_name
                    || '|'
                    || errored_shipments_rec.order_number
                    || '|'
                    || errored_shipments_rec.error_message);
            END LOOP;

            send_notification (
                pv_errbuf              => lv_errbuf,
                pv_retcode             => lv_retcode,
                pv_notification_type   => 'GENERATE_ERROR_REPORT',
                pn_request_id          => gn_request_id,
                pv_shipment_no         => pv_shipment_no,
                pn_delivery_id         => NULL);
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'No records in ERROR, So not printing Error Report in Output file and also not sending email notification.');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at GENERATE_ERROR_REPORT procedure : '
                || pv_errbuf);
    END generate_error_report;

    -- ***************************************************************************
    -- Procedure Name      : get_subinv_xfer_qty
    -- Description         : This procedure is to back order the delivery
    -- Parameters          : pn_delivery_id    IN  : Delivery Number
    --                       pv_errbuf         OUT : Return Message
    --                       pv_retcode        OUT : Return Status
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE get_subinv_xfer_qty (
        pn_new_delivery_id   IN     NUMBER,
        p_subinv_xfer_tab       OUT g_subinv_xfer_tbl_type)
    IS
        CURSOR new_delv_cur IS
              SELECT wnd.delivery_id, wdd.organization_id, wdd.inventory_item_id,
                     wdd.subinventory, SUM (NVL (wdd.requested_quantity, 0)) quantity
                FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
               WHERE     1 = 1
                     AND wnd.NAME = pn_new_delivery_id           --'468676512'
                     AND wnd.status_code = 'OP'      --Delivery Should be Open
                     AND wnd.organization_id = gn_inv_org_id
                     AND wnd.delivery_id = wda.delivery_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     AND wdd.organization_id = gn_inv_org_id
                     AND wdd.source_code = 'OE'
                     AND wdd.released_status = 'Y'     --Staged/Pick Confirmed
            --   AND wdd.delivery_detail_id = 55766505
            GROUP BY wnd.delivery_id, wdd.organization_id, wdd.inventory_item_id,
                     wdd.subinventory;

        l_subinv_xfer_tab        g_subinv_xfer_tbl_type;
        l_ex_bulk_fetch_failed   EXCEPTION;
        lv_err_msg               VARCHAR2 (4000) := NULL;
        lv_retcode               VARCHAR (1) := '0';
    BEGIN
        fnd_file.put_line (
            fnd_file.LOG,
            'In GET_SUBINV_XFER_QTY for delivery Id ' || pn_new_delivery_id);

        IF l_subinv_xfer_tab.COUNT > 0
        THEN
            l_subinv_xfer_tab.DELETE;
        END IF;

        OPEN new_delv_cur;

        BEGIN
            FETCH new_delv_cur BULK COLLECT INTO l_subinv_xfer_tab;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_err_msg   :=
                       'Error in BULK Fetch in GET_SUBINV_XFER_QTY procedure: '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, lv_err_msg);
                RAISE l_ex_bulk_fetch_failed;
        END;

        CLOSE new_delv_cur;

        p_subinv_xfer_tab   := l_subinv_xfer_tab;
    EXCEPTION
        WHEN l_ex_bulk_fetch_failed
        THEN
            lv_err_msg   :=
                'Bulk fetch failed in GET_SUBINV_XFER_QTY procedure';
            lv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
        WHEN OTHERS
        THEN
            p_subinv_xfer_tab   := l_subinv_xfer_tab;

            IF new_delv_cur%FOUND
            THEN
                CLOSE new_delv_cur;
            END IF;

            lv_retcode          := '2';
            lv_err_msg          :=
                   'Exception in GET_SUBINV_XFER_QTY procedure for delivery: '
                || pn_new_delivery_id
                || '. Error is:'
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, lv_err_msg);
    END get_subinv_xfer_qty;

    -- ***************************************************************************
    -- Procedure Name      : back_order_delivery
    -- Description        : This procedure is to back order the delivery
    -- Parameters         : pn_delivery_id     IN  : Delivery Number
    --                      pv_errbuf         OUT : Return Message
    --                      pv_retcode        OUT : Return Status
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE back_order_delivery (pn_delivery_id IN VARCHAR2, pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2)
    IS
        --Standard Parameters.
        p_api_version               NUMBER;
        p_init_msg_list             VARCHAR2 (30);
        p_commit                    VARCHAR2 (30);
        --Parameters for WSH_DELIVERIES_PUB.Delivery_Action.
        p_action_code               VARCHAR2 (15);
        p_delivery_id               NUMBER;
        p_delivery_name             VARCHAR2 (30);
        p_asg_trip_id               NUMBER;
        p_asg_trip_name             VARCHAR2 (30);
        p_asg_pickup_stop_id        NUMBER;
        p_asg_pickup_loc_id         NUMBER;
        p_asg_pickup_loc_code       VARCHAR2 (30);
        p_asg_pickup_arr_date       DATE;
        p_asg_pickup_dep_date       DATE;
        p_asg_dropoff_stop_id       NUMBER;
        p_asg_dropoff_loc_id        NUMBER;
        p_asg_dropoff_loc_code      VARCHAR2 (30);
        p_asg_dropoff_arr_date      DATE;
        p_asg_dropoff_dep_date      DATE;
        p_sc_action_flag            VARCHAR2 (10);
        p_sc_close_trip_flag        VARCHAR2 (10);
        p_sc_create_bol_flag        VARCHAR2 (10);
        p_sc_stage_del_flag         VARCHAR2 (10);
        p_sc_trip_ship_method       VARCHAR2 (30);
        p_sc_actual_dep_date        VARCHAR2 (30);
        p_sc_report_set_id          NUMBER;
        p_sc_report_set_name        VARCHAR2 (60);
        p_wv_override_flag          VARCHAR2 (10);
        p_sc_defer_interface_flag   VARCHAR2 (1);
        x_trip_id                   VARCHAR2 (30);
        x_trip_name                 VARCHAR2 (30);
        --out parameters
        x_return_status             VARCHAR2 (10);
        x_msg_count                 NUMBER;
        x_msg_data                  VARCHAR2 (2000);
        x_msg_details               VARCHAR2 (3000);
        x_msg_summary               VARCHAR2 (3000);
        lv_errbuf                   VARCHAR2 (4000);
        lv_retcode                  VARCHAR2 (1) := '0';
        -- Handle exceptions
        l_api_error_exception       EXCEPTION;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Backorder Delivery : ' || pn_delivery_id);
        -- Initialize return status
        x_return_status       := wsh_util_core.g_ret_sts_success;
        -- Call this procedure to initialize applications parameters
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_resp_id,
                                    resp_appl_id   => gn_resp_appl_id);
        -- Values for back order the delivery
        p_action_code         := 'CONFIRM'; -- The action code for ship confirm
        p_delivery_id         := pn_delivery_id;
        -- The delivery that needs to be confirmed
        --p_sc_action_flag              := 'B';       -- Backorder quantity.
        p_sc_action_flag      := 'C';                         -- Backorder all
        p_sc_stage_del_flag   := 'N';
        -- Call to WSH_DELIVERIES_PUB.Delivery_Action.
        wsh_deliveries_pub.delivery_action (
            p_api_version_number        => 1.0,
            p_init_msg_list             => p_init_msg_list,
            x_return_status             => x_return_status,
            x_msg_count                 => x_msg_count,
            x_msg_data                  => x_msg_data,
            p_action_code               => p_action_code,
            p_delivery_id               => p_delivery_id,
            p_delivery_name             => p_delivery_name,
            p_asg_trip_id               => p_asg_trip_id,
            p_asg_trip_name             => p_asg_trip_name,
            p_asg_pickup_stop_id        => p_asg_pickup_stop_id,
            p_asg_pickup_loc_id         => p_asg_pickup_loc_id,
            p_asg_pickup_loc_code       => p_asg_pickup_loc_code,
            p_asg_pickup_arr_date       => p_asg_pickup_arr_date,
            p_asg_pickup_dep_date       => p_asg_pickup_dep_date,
            p_asg_dropoff_stop_id       => p_asg_dropoff_stop_id,
            p_asg_dropoff_loc_id        => p_asg_dropoff_loc_id,
            p_asg_dropoff_loc_code      => p_asg_dropoff_loc_code,
            p_asg_dropoff_arr_date      => p_asg_dropoff_arr_date,
            p_asg_dropoff_dep_date      => p_asg_dropoff_dep_date,
            p_sc_action_flag            => p_sc_action_flag,
            p_sc_close_trip_flag        => p_sc_close_trip_flag,
            p_sc_create_bol_flag        => p_sc_create_bol_flag,
            p_sc_stage_del_flag         => p_sc_stage_del_flag,
            p_sc_trip_ship_method       => p_sc_trip_ship_method,
            p_sc_actual_dep_date        => p_sc_actual_dep_date,
            p_sc_report_set_id          => p_sc_report_set_id,
            p_sc_report_set_name        => p_sc_report_set_name,
            p_wv_override_flag          => p_wv_override_flag,
            p_sc_defer_interface_flag   => p_sc_defer_interface_flag,
            x_trip_id                   => x_trip_id,
            x_trip_name                 => x_trip_name);

        IF (x_return_status <> wsh_util_core.g_ret_sts_success)
        THEN
            RAISE l_api_error_exception;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'Back order of the delivery '
                || p_delivery_id
                || ' is successful');
        END IF;
    EXCEPTION
        WHEN l_api_error_exception
        THEN
            wsh_util_core.get_messages (p_init_msg_list => 'Y', x_summary => x_msg_summary, x_details => x_msg_details
                                        , x_count => x_msg_count);

            IF x_msg_count > 1
            THEN
                x_msg_data   := x_msg_summary || x_msg_details;
                fnd_file.put_line (fnd_file.LOG,
                                   'Message Data : ' || x_msg_data);
            ELSE
                x_msg_data   := x_msg_summary;
                fnd_file.put_line (fnd_file.LOG,
                                   'Message Data : ' || x_msg_data);
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'API Exception in BACK_ORDER_DELIVERY procedure for delivery: '
                || pn_delivery_id
                || '. Error is:'
                || SQLERRM);
            pv_retcode   := '2';
            pv_errbuf    := 'API Exception: ' || x_msg_data;
            send_notification (pv_errbuf              => lv_errbuf,
                               pv_retcode             => lv_retcode,
                               pv_notification_type   => 'BACKORDER_FAIL',
                               pn_request_id          => gn_request_id,
                               pv_shipment_no         => NULL,
                               pn_delivery_id         => pn_delivery_id);
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in BACK_ORDER_DELIVERY procedure for delivery: '
                || pn_delivery_id
                || '. Error is:'
                || SQLERRM);
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Exception in BACK_ORDER_DELIVERY procedure for delivery: '
                || pn_delivery_id
                || '. Error is:'
                || SQLERRM;
            send_notification (pv_errbuf              => lv_errbuf,
                               pv_retcode             => lv_retcode,
                               pv_notification_type   => 'BACKORDER_FAIL',
                               pn_request_id          => gn_request_id,
                               pv_shipment_no         => NULL,
                               pn_delivery_id         => pn_delivery_id);
    END back_order_delivery;

    -- ***************************************************************************
    -- Procedure Name      : subinventory_transfer
    -- Description        : This procedure is to move the back ordered qty from STAGE to PICK subinventory
    -- Parameters         : p_subinv_xfer_tab    IN  Table type record
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE subinventory_transfer (
        p_subinv_xfer_tab IN g_subinv_xfer_tbl_type)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        ln_api_version                NUMBER := 1.0;
        lv_init_msg_list              VARCHAR2 (1) := fnd_api.g_true;
        lv_ret_val                    NUMBER;
        lv_return_status              VARCHAR2 (1);
        lv_commit                     VARCHAR2 (1) := fnd_api.g_true;
        ln_validation_level           NUMBER := 1;
        ln_msg_cnt                    NUMBER := 0;
        lv_msg_data                   VARCHAR2 (4000) := NULL;
        ln_trans_count                NUMBER;
        ln_table                      NUMBER := 1;
        ln_transaction_header_id      NUMBER;
        ln_transaction_interface_id   NUMBER;
        lv_primary_uom_code           VARCHAR2 (30) := NULL;
        ln_idx                        NUMBER := 0;
        l_subinv_xfer_tab             g_subinv_xfer_tbl_type;
    BEGIN
        l_subinv_xfer_tab   := p_subinv_xfer_tab;
        fnd_file.put_line (
            fnd_file.LOG,
            'START - Subinventory transfer - Inserting records into MTL_TRANSACTIONS_INTERFACE.');

        FOR ln_idx IN l_subinv_xfer_tab.FIRST .. l_subinv_xfer_tab.LAST
        LOOP
            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_transaction_interface_id
              FROM DUAL;

            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_transaction_header_id
              FROM DUAL;

            BEGIN
                SELECT primary_uom_code
                  INTO lv_primary_uom_code
                  FROM mtl_system_items_b
                 WHERE     organization_id =
                           l_subinv_xfer_tab (ln_idx).organization_id
                       --gn_inv_org_id
                       AND inventory_item_id =
                           l_subinv_xfer_tab (ln_idx).inventory_item_id --900094976
                                                                       ;
            EXCEPTION
                WHEN OTHERS
                THEN
                    lv_primary_uom_code   := NULL;
            END;

            INSERT INTO mtl_transactions_interface (transaction_uom,
                                                    transaction_date,
                                                    source_code,
                                                    source_line_id,
                                                    source_header_id,
                                                    process_flag,
                                                    transaction_mode,
                                                    lock_flag,
                                                    last_update_date,
                                                    last_updated_by,
                                                    creation_date,
                                                    created_by,
                                                    last_update_login,
                                                    request_id,
                                                    inventory_item_id,
                                                    subinventory_code,
                                                    organization_id,
                                                    transaction_quantity,
                                                    primary_quantity,
                                                    transaction_type_id,
                                                    transfer_subinventory,
                                                    transaction_header_id,
                                                    transaction_interface_id)
                     VALUES (lv_primary_uom_code,    --'PR', --transaction uom
                             SYSDATE,                       --transaction date
                             'Subinventory Transfer',
                             --source code (Transaction source identifier; Used for auditing and process control)
                             99,
                             --source line id (Transaction source line identifier; Used for auditing only)
                             99,
                             --source header id (Transaction source group identifier; Used for process control by user-submitted Transaction Workers)
                             1,
                             --process flag  ('1' for ready, '2' for not ready, '3' if the transaction fails for some reason)
                             3,
                             --transaction mode ( immediate concurrent processing mode (2) or background processing mode (3))
                             2,
                             --lock flag (Flag indicating whether the transaction is locked by the Transaction Manager or Workers ('1' for locked, '2' or NULL for not locked); this prevents two different Workers from processing the same transaction; You should always specify '2')
                             SYSDATE,                       --last update date
                             gn_user_id,                     --last updated by
                             SYSDATE,                           --created date
                             gn_user_id,                          --created by
                             gn_login_id,                  --last update login
                             gn_request_id,                       --request id
                             l_subinv_xfer_tab (ln_idx).inventory_item_id,
                             --900094976 , --inventory item id
                             'STAGE',
                             --subinventory code
                             l_subinv_xfer_tab (ln_idx).organization_id,
                             --107, --organization id
                             l_subinv_xfer_tab (ln_idx).quantity,
                             --1, --transaction quantity
                             l_subinv_xfer_tab (ln_idx).quantity,
                             --1, --primary quantity
                             2,
                             --transaction type id --Subinventory Transfer
                             'PICK',                        -- To subinventory
                             ln_transaction_header_id, --transaction header id
                             ln_transaction_interface_id --mtl_material_transactions_s.nextval --transaction interface id
                                                        );
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'END - Subinventory transfer - Inserting records into MTL_TRANSACTIONS_INTERFACE.');
        fnd_file.put_line (fnd_file.LOG,
                           'START - Calling Transaction Processor');
        lv_ret_val          :=
            inv_txn_manager_pub.process_transactions (
                p_api_version        => ln_api_version,
                p_init_msg_list      => lv_init_msg_list,
                p_commit             => lv_commit,
                p_validation_level   => ln_validation_level,
                x_return_status      => lv_return_status,
                x_msg_count          => ln_msg_cnt,
                x_msg_data           => lv_msg_data,
                x_trans_count        => ln_trans_count,
                p_table              => ln_table,
                p_header_id          => ln_transaction_header_id);

        IF (lv_return_status <> fnd_api.g_ret_sts_success)
        THEN
            ln_msg_cnt   := NVL (ln_msg_cnt, 0) + 1;

            FOR i IN 1 .. ln_msg_cnt
            LOOP
                IF i = 1
                THEN
                    lv_msg_data   :=
                        'Error is: ' || CHR (10) || fnd_msg_pub.get (i, 'F');
                ELSE
                    lv_msg_data   := fnd_msg_pub.get (i, 'F');
                END IF;

                --fnd_message.set_string(SUBSTRB(lv_msg_data , 1, 2000));
                --fnd_message.show;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'SI Transfer Failed. Error is:' || lv_msg_data);
            END LOOP;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'END - Calling Transaction Processor');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in SUBINVENTORY_TRANSFER procedure. Error is:'
                || SQLERRM);
    END subinventory_transfer;

    -- ***************************************************************************
    -- Procedure Name      : UPDATE_DELIVERY_ATTRIBUTES
    -- Description         : This procedure is to update atributes values in wsh_new_deliveries and wsh_delivery_details table
    --
    -- Parameters          : pv_errbuf           OUT : Error message
    --                       pv_retcode          OUT : Execution status
    --                       pv_shipment_no      IN  : Shipment number
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author               Version  Description
    -- ------------  -----------------    -------  --------------------------------
    -- 2020/03/11    Tejaswi Gangumalla    1.0     Initial Version created for change 1.2
    --
    -- ***************************************************************************
    PROCEDURE update_delivery_attributes (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2)
    IS
        lv_tracking_num     VARCHAR2 (50);
        lv_trailer_number   VARCHAR2 (50);
        lv_seal_number      VARCHAR2 (50);
        lv_bol_number       VARCHAR2 (50);
        lv_shipment_type    VARCHAR2 (50);
        lv_sales_channel    VARCHAR2 (100);
        ln_cust_count       NUMBER;
    BEGIN
        /* update carrier code in attribute2 of WND - WND_ATTRIBUTE2 */
        BEGIN
            UPDATE wsh_new_deliveries
               SET attribute2   =
                       (SELECT h.carrier
                          FROM apps.xxdo_ont_ship_conf_head_stg h
                         WHERE     process_status = 'PROCESSED'
                               AND h.shipment_number = pv_shipment_no)
             --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
             WHERE     name IN
                           (SELECT order_number        -- Added as per ver 1.3
                              FROM apps.xxdo_ont_ship_conf_order_stg
                             WHERE     process_status = 'PROCESSED'
                                   AND shipment_number = pv_shipment_no)
                   AND attribute2 IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_errbuf    :=
                       'Unexpected error while updating carrier_code : '
                    || SQLERRM;
                pv_retcode   := '2';
        END;

        /* update CUST_LOAD_ID in attribute2 of WND - WND_ATTRIBUTE2 */
        BEGIN
            UPDATE wsh_new_deliveries
               SET attribute15   =
                       (SELECT h.customer_load_id
                          FROM apps.xxdo_ont_ship_conf_head_stg h
                         WHERE     h.process_status = 'PROCESSED'
                               AND h.shipment_number = pv_shipment_no)
             --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
             WHERE     name IN
                           (SELECT order_number        -- Added as per ver 1.3
                              FROM apps.xxdo_ont_ship_conf_order_stg
                             WHERE     process_status = 'PROCESSED'
                                   AND shipment_number = pv_shipment_no)
                   AND attribute15 IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_errbuf    :=
                       'Unexpected error while updating customer_load_id : '
                    || SQLERRM;
                pv_retcode   := '2';
        END;

        BEGIN
            lv_bol_number       := NULL;
            lv_seal_number      := NULL;
            lv_trailer_number   := NULL;

            SELECT seal_number, bol_number, trailer_number,
                   shipment_type, sales_channel
              INTO lv_seal_number, lv_bol_number, lv_trailer_number, lv_shipment_type,
                                 lv_sales_channel
              FROM apps.xxdo_ont_ship_conf_head_stg
             WHERE     process_status = 'PROCESSED'
                   AND shipment_number = pv_shipment_no;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_seal_number      := NULL;
                lv_bol_number       := NULL;
                lv_trailer_number   := NULL;
        END;

        /* update waybill in waybill of WND */
        IF lv_bol_number IS NOT NULL
        THEN
            BEGIN
                UPDATE wsh_new_deliveries
                   SET waybill   = lv_bol_number
                 --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
                 WHERE     name IN
                               (SELECT order_number    -- Added as per ver 1.3
                                  FROM apps.xxdo_ont_ship_conf_order_stg
                                 WHERE     process_status = 'PROCESSED'
                                       AND shipment_number = pv_shipment_no)
                       AND waybill IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while updating way_bill : '
                        || SQLERRM;
                    pv_retcode   := '2';
            END;
        END IF;

        /* update trailer number  in attribute16 of WND */
        IF lv_trailer_number IS NOT NULL
        THEN
            BEGIN
                UPDATE wsh_new_deliveries
                   SET attribute6   = lv_trailer_number
                 --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
                 WHERE     name IN
                               (SELECT order_number    -- Added as per ver 1.3
                                  FROM apps.xxdo_ont_ship_conf_order_stg
                                 WHERE     process_status = 'PROCESSED'
                                       AND shipment_number = pv_shipment_no)
                       AND attribute6 IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while updating trailer_number : '
                        || SQLERRM;
                    pv_retcode   := '2';
            END;
        END IF;

        /* update seal code in seal_code of WDD */
        IF lv_seal_number IS NOT NULL
        THEN
            BEGIN
                UPDATE wsh_delivery_details
                   SET seal_code   = lv_seal_number
                 WHERE     delivery_detail_id IN
                               (SELECT wda.delivery_detail_id
                                  FROM wsh_delivery_assignments wda, wsh_new_deliveries wnd -- Added as per ver 1.3
                                 --WHERE wda.delivery_id IN (                -- Commented as per ver 1.3
                                 WHERE     wnd.delivery_id = wda.delivery_id -- Added as per ver 1.3
                                       AND wnd.name IN
                                               (       -- Added as per ver 1.3
                                                --SELECT NVL (delivery_id, order_number)     -- Commented as per ver 1.3
                                                SELECT order_number -- Added as per ver 1.3
                                                  FROM apps.xxdo_ont_ship_conf_order_stg
                                                 WHERE     process_status =
                                                           'PROCESSED'
                                                       AND shipment_number =
                                                           pv_shipment_no))
                       AND seal_code IS NULL;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while updating seal_code : '
                        || SQLERRM;
                    pv_retcode   := '2';
            END;
        END IF;

        IF UPPER (lv_shipment_type) = 'NON-PARCEL'
        THEN
            /* update waybill in tracking_number of WDD */
            BEGIN
                UPDATE wsh_delivery_details
                   SET tracking_number   = lv_bol_number
                 WHERE     tracking_number IS NULL
                       AND delivery_detail_id IN
                               (SELECT wda.delivery_detail_id
                                  FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda
                                 WHERE     wnd.delivery_id = wda.delivery_id
                                       --AND wnd.delivery_id IN (                                   -- Commented as per ver 1.3
                                       --SELECT NVL (delivery_id, order_number)      -- Commented as per ver 1.3
                                       AND name IN
                                               (SELECT order_number -- Added as per ver 1.3
                                                  FROM apps.xxdo_ont_ship_conf_order_stg
                                                 WHERE     process_status =
                                                           'PROCESSED'
                                                       AND shipment_number =
                                                           pv_shipment_no));
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while updating tracking number : '
                        || SQLERRM;
                    pv_retcode   := '2';
            END;
        END IF;

        /* update edi_eligible in table XXDO_ONT_SHIP_CONF_ORDER_STG  */
        IF     UPPER (lv_shipment_type) = 'PARCEL'
           AND UPPER (lv_sales_channel) = 'DROPSHIP'
        THEN
            BEGIN
                UPDATE xxdo_ont_ship_conf_order_stg
                   SET edi_eligible   = 'Y'
                 WHERE     process_status = 'PROCESSED'
                       AND shipment_number = pv_shipment_no;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    :=
                           'Unexpected error while updating edi_eligible : '
                        || SQLERRM;
                    pv_retcode   := '2';
            END;
        END IF;

        IF     UPPER (lv_shipment_type) = 'PARCEL'
           AND UPPER (lv_sales_channel) NOT IN ('ECOM', 'DROPSHIP')
        THEN
            FOR order_rec
                IN (SELECT DISTINCT ord.order_header_id
                      FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca
                     WHERE     ord.process_status = 'PROCESSED'
                           AND ord.shipment_number = pv_shipment_no
                           AND ord.order_header_id = ooh.header_id
                           AND ooh.sold_to_org_id = hca.cust_account_id)
            LOOP
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_cust_count
                      FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca
                     WHERE     ord.process_status = 'PROCESSED'
                           AND ord.shipment_number = pv_shipment_no
                           AND ord.order_header_id =
                               order_rec.order_header_id
                           AND ord.order_header_id = ooh.header_id
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM fnd_lookup_values flv
                                     WHERE     lookup_type =
                                               'XXDO_EDI_CUSTOMERS'
                                           AND flv.LANGUAGE = 'US'
                                           AND flv.enabled_flag = 'Y'
                                           AND flv.lookup_code =
                                               hca.account_number);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_errbuf    :=
                               'Unexpected error while validating customer : '
                            || SQLERRM;
                        pv_retcode   := '2';
                END;

                IF ln_cust_count > 0
                THEN
                    BEGIN
                        UPDATE xxdo_ont_ship_conf_order_stg
                           SET edi_eligible   = 'Y'
                         WHERE     process_status = 'PROCESSED'
                               AND shipment_number = pv_shipment_no
                               AND order_header_id =
                                   order_rec.order_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_errbuf    :=
                                   'Unexpected error while updating edi_eligible : '
                                || SQLERRM;
                            pv_retcode   := '2';
                    END;
                END IF;
            END LOOP;
        END IF;

        IF UPPER (lv_shipment_type) = 'NON-PARCEL'
        THEN
            FOR order_rec
                IN (SELECT DISTINCT ord.order_header_id
                      FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca
                     WHERE     ord.process_status = 'PROCESSED'
                           AND ord.shipment_number = pv_shipment_no
                           AND ord.order_header_id = ooh.header_id
                           AND ooh.sold_to_org_id = hca.cust_account_id)
            LOOP
                BEGIN
                    SELECT COUNT (*)
                      INTO ln_cust_count
                      FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca
                     WHERE     ord.process_status = 'PROCESSED'
                           AND ord.shipment_number = pv_shipment_no
                           AND ord.order_header_id =
                               order_rec.order_header_id
                           AND ord.order_header_id = ooh.header_id
                           AND ooh.sold_to_org_id = hca.cust_account_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM fnd_lookup_values flv
                                     WHERE     lookup_type =
                                               'XXDO_EDI_CUSTOMERS'
                                           AND flv.LANGUAGE = 'US'
                                           AND flv.enabled_flag = 'Y'
                                           AND flv.lookup_code =
                                               hca.account_number);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_errbuf    :=
                               'Unexpected error while validating customer : '
                            || SQLERRM;
                        pv_retcode   := '2';
                END;

                IF ln_cust_count > 0
                THEN
                    BEGIN
                        UPDATE xxdo_ont_ship_conf_order_stg
                           SET edi_eligible   = 'Y'
                         WHERE     process_status = 'PROCESSED'
                               AND shipment_number = pv_shipment_no
                               AND order_header_id =
                                   order_rec.order_header_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_errbuf    :=
                                   'Unexpected error while updating edi_eligible : '
                                || SQLERRM;
                            pv_retcode   := '2';
                    END;
                END IF;
            END LOOP;
        END IF;

        /* update edi_creation_status in table XXDO_ONT_SHIP_CONF_ORDER_STG  */
        BEGIN
            UPDATE xxdo_ont_ship_conf_order_stg
               SET edi_creation_status   = 'NEW'
             WHERE     process_status = 'PROCESSED'
                   AND shipment_number = pv_shipment_no
                   AND edi_eligible = 'Y'
                   AND edi_creation_status IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_errbuf    :=
                       'Unexpected error while updating edi_creation_status: '
                    || SQLERRM;
                pv_retcode   := '2';
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    :=
                   'Unexpected error in procedure update_delivery_attributes: '
                || SQLERRM;
            pv_retcode   := '2';
    END update_delivery_attributes;

    -- ***************************************************************************
    -- Procedure Name      : shipment_thread
    -- Description         : This procedure is to process the shipment - create trip, stops, launch delivery threads and ship confirm
    --
    -- Parameters          : pv_errbuf           OUT : Error message
    --                       pv_retcode          OUT : Execution status
    --                       pv_shipment_no      IN  : Shipment number
    --                       pn_parent_req_id    IN  : Parent - Main Thread - Request Id
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0       Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE shipment_thread (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2
                               , pn_parent_req_id IN NUMBER)
    IS
        lb_req_status                BOOLEAN;
        lv_req_failure               VARCHAR2 (1) := 'N';
        lv_phase                     VARCHAR2 (100) := NULL;
        lv_status                    VARCHAR2 (100) := NULL;
        lv_dev_phase                 VARCHAR2 (100) := NULL;
        lv_dev_status                VARCHAR2 (100) := NULL;
        lv_message                   VARCHAR2 (1000) := NULL;
        lv_errbuf                    VARCHAR2 (2000);
        lv_retcode                   VARCHAR2 (30);
        ln_ship_from_loc_id          NUMBER := 0;
        ln_stop_id                   NUMBER := 0;
        ln_trip_id                   NUMBER := 0;
        ln_existing_trip_id          NUMBER := 0;
        ln_shipment_index            NUMBER := 1;
        ln_inventory_org_id          NUMBER := -1;
        lv_period_open_flag          VARCHAR2 (1) := 'N';
        ln_carrier_id                NUMBER := -1;
        ln_del_index                 NUMBER := 1;
        ln_shipment_id               NUMBER := 0;
        lv_packed_proc_status        VARCHAR2 (30);
        lv_pick_conf_failure         VARCHAR2 (1);
        l_delivery_request_ids_tab   tabtype_id;
        l_shipconfirm_del_ids_tab    tabtype_id;
        l_shipconf_headers_obj_tab   shipconf_headers_obj_tab_type;
        l_hold_source_tbl            g_hold_source_tbl_type;
        l_all_hold_source_tbl        g_hold_source_tbl_type;
        l_ex_bulk_fetch_failed       EXCEPTION;
        ln_from_stop_id              NUMBER;
        ln_process_cnt               NUMBER := 0;
        l_subinv_xfer_tab            g_subinv_xfer_tbl_type;
        lv_err_flag                  VARCHAR2 (1) := 'N';
        lv_savepoint                 VARCHAR2 (100) := NULL;
        ld_date                      DATE;
        ln_carrier_service_id        NUMBER := 0;

        --Added on 16Jul2019
        CURSOR cur_shipment_data IS
            SELECT shipconf_headers_obj_type (
                       wh_id,
                       shipment_number,
                       master_load_ref,
                       customer_load_id,
                       carrier,
                       service_level,
                       pro_number,
                       comments,
                       ship_date,
                       seal_number,
                       trailer_number,
                       employee_id,
                       employee_name,
                       process_status,
                       error_message,
                       request_id,
                       creation_date,
                       created_by,
                       last_update_date,
                       last_updated_by,
                       source_type,
                       attribute1,
                       attribute2,
                       attribute3,
                       attribute4,
                       attribute5,
                       attribute6,
                       attribute7,
                       attribute8,
                       attribute9,
                       attribute10,
                       attribute11,
                       attribute12,
                       attribute13,
                       attribute14,
                       attribute15,
                       attribute16,
                       attribute17,
                       attribute18,
                       attribute19,
                       attribute20,
                       SOURCE,
                       destination,
                       record_type,
                       CAST (
                           MULTISET (
                               SELECT wh_id, shipment_number, order_number,
                                      ship_to_name, ship_to_attention, ship_to_addr1,
                                      ship_to_addr2, ship_to_addr3, ship_to_city,
                                      ship_to_state, ship_to_zip, ship_to_country_code,
                                      process_status, error_message, request_id,
                                      creation_date, created_by, last_update_date,
                                      last_updated_by, source_type, attribute1,
                                      attribute2, attribute3, attribute4,
                                      attribute5, attribute6, attribute7,
                                      attribute8, attribute9, attribute10,
                                      attribute11, attribute12, attribute13,
                                      attribute14, attribute15, attribute16,
                                      attribute17, attribute18, attribute19,
                                      attribute20, SOURCE, destination,
                                      record_type, address_verified, order_header_id,
                                      delivery_id, ship_to_org_id, ship_to_location_id,
                                      NULL
                                 FROM xxdo_ont_ship_conf_order_stg delivery
                                WHERE     delivery.shipment_number =
                                          shipment.shipment_number
                                      AND delivery.wh_id = shipment.wh_id
                                      AND delivery.process_status =
                                          'INPROCESS'
                                      AND delivery.request_id =
                                          pn_parent_req_id)
                               AS shipconf_orders_obj_tab_type))
              FROM xxdo_ont_ship_conf_head_stg shipment
             WHERE     process_status = 'INPROCESS'
                   AND request_id = pn_parent_req_id
                   AND shipment_number = pv_shipment_no;

        CURSOR cur_ship_to_stops IS
            SELECT DISTINCT ship_to_location_id
              FROM xxdo_ont_ship_conf_order_stg
             WHERE     1 = 1
                   AND shipment_number = pv_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = pn_parent_req_id;

        CURSOR cur_same_stop_del_nums (p_num_ship_to_loc_id IN NUMBER)
        IS
            SELECT order_number
              FROM xxdo_ont_ship_conf_order_stg
             WHERE     1 = 1
                   AND shipment_number = pv_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = pn_parent_req_id
                   AND ship_to_location_id = p_num_ship_to_loc_id;

        /* To update ship method for deliveries */
        CURSOR cur_delivery_ids IS
            SELECT delivery_id
              FROM xxdo_ont_ship_conf_order_stg
             WHERE     1 = 1
                   AND shipment_number = pv_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = pn_parent_req_id;

        CURSOR cur_order_header_id (pv_delivery_number IN VARCHAR2)
        IS
            SELECT wdd.source_header_id
              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda
             WHERE     1 = 1
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.NAME = pv_delivery_number
                   AND ROWNUM < 2;

        CURSOR cur_pick_conf_deliveries IS
            SELECT order_number, wh_id
              FROM xxdo_ont_ship_conf_order_stg delivery
             WHERE     1 = 1
                   AND shipment_number = pv_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = pn_parent_req_id
                   AND EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda
                             WHERE     1 = 1
                                   AND wnd.delivery_id = wda.delivery_id
                                   AND wda.delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND wnd.NAME = delivery.order_number
                                   AND wdd.released_status = 'S');

        CURSOR cur_mo_lines (pv_delivery_number IN VARCHAR2)
        IS
            SELECT DISTINCT mtrl.transaction_header_id, mtrl.line_id mo_line_id
              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda,
                   mtl_txn_request_lines mtrl
             WHERE     1 = 1
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.NAME = pv_delivery_number
                   AND wdd.source_line_id = mtrl.txn_source_line_id
                   AND wdd.move_order_line_id = mtrl.line_id
                   AND wdd.released_status = 'S';

        CURSOR cur_ship_set_orders IS
            SELECT DISTINCT wnd.source_header_id header_id
              FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd
             WHERE     1 = 1
                   AND s.shipment_number = pv_shipment_no
                   AND s.order_number = wnd.delivery_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all ool
                             WHERE     1 = 1
                                   AND ool.header_id = wnd.source_header_id
                                   AND ool.ship_set_id IS NOT NULL);
    BEGIN
        pv_errbuf             := NULL;
        pv_retcode            := '0';
        gn_parent_req_id      := pn_parent_req_id;
        fnd_file.put_line (fnd_file.LOG,
                           'Parent Request ID: ' || pn_parent_req_id);
        fnd_file.put_line (
            fnd_file.LOG,
            'Processing started for Shipment Number : ' || pv_shipment_no);

        FOR pick_conf_deliveries_rec IN cur_pick_conf_deliveries
        LOOP
            lv_packed_proc_status   := NULL;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Pick confirm started for the delivery : '
                || pick_conf_deliveries_rec.order_number);

            --Get the process status from the status table for the shipment and delivery
            BEGIN
                SELECT process_status
                  INTO lv_packed_proc_status
                  FROM xxdo_ont_pick_status_order
                 WHERE     1 = 1
                       AND order_number =
                           pick_conf_deliveries_rec.order_number
                       AND shipment_number = pv_shipment_no
                       AND wh_id = pick_conf_deliveries_rec.wh_id
                       AND status = 'PACKED';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    lv_packed_proc_status   := NULL;
                WHEN OTHERS
                THEN
                    lv_packed_proc_status   := NULL;
            END;

            IF    lv_packed_proc_status IS NULL
               OR lv_packed_proc_status IN ('ERROR', 'NEW')
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Pick confirm the entire delivery');
                lv_pick_conf_failure   := 'N';

                -- Pick confirm the entire delivery
                FOR mo_lines_rec
                    IN cur_mo_lines (pick_conf_deliveries_rec.order_number)
                LOOP
                    pick_line (
                        pv_errbuf       => lv_errbuf,
                        pv_retcode      => lv_retcode,
                        pn_mo_line_id   => mo_lines_rec.mo_line_id,
                        pn_txn_hdr_id   => mo_lines_rec.transaction_header_id);

                    IF lv_retcode <> '0'
                    THEN
                        lv_pick_conf_failure   := 'Y';
                        EXIT;                                  --Exit the loop
                    END IF;
                END LOOP;

                -- If API failed for any of the move order lines, update the delivery as failed
                IF lv_pick_conf_failure = 'Y'
                THEN
                    BEGIN
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     =>
                                pick_conf_deliveries_rec.order_number,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   =>
                                'Pick confirm failed : ' || lv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'PICK_CONFIRM');
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Pick confirm failed for delivery : '
                            || pick_conf_deliveries_rec.order_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || lv_errbuf;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;
                ELSE
                    -- Pick confirmation is fully successful. Insert the packed message into order status table.
                    COMMIT;

                    IF lv_packed_proc_status IS NULL
                    THEN                        -- No message insert or update
                        BEGIN
                            INSERT INTO xxdo.xxdo_ont_pick_status_order (
                                            wh_id,
                                            order_number,
                                            tran_date,
                                            status,
                                            shipment_number,
                                            shipment_status,
                                            comments,
                                            error_msg,
                                            created_by,
                                            creation_date,
                                            last_updated_by,
                                            last_update_date,
                                            last_update_login,
                                            process_status,
                                            record_type,
                                            SOURCE,
                                            destination)
                                 VALUES (pick_conf_deliveries_rec.wh_id, pick_conf_deliveries_rec.order_number, SYSDATE, --pd_ship_date,
                                                                                                                         'PACKED', pv_shipment_no, 'NEW', 'SHIP-AUTOINSERT', NULL, gn_user_id, SYSDATE, gn_user_id, SYSDATE, gn_login_id, 'PROCESSED', 'INSERT'
                                         ,                       --record type
                                           'WMS',                     --source
                                                  'EBS'          --destination
                                                       );
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '1';
                                pv_errbuf    :=
                                       'PACKED message is not inserted into order status table due to : '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        END;
                    ELSE                 -- update the existing PACKED message
                        UPDATE xxdo.xxdo_ont_pick_status_order
                           SET process_status = 'PROCESSED', request_id = gn_request_id, last_update_date = SYSDATE,
                               last_updated_by = gn_user_id
                         WHERE     order_number =
                                   pick_conf_deliveries_rec.order_number
                               AND shipment_number = pv_shipment_no
                               AND wh_id = pick_conf_deliveries_rec.wh_id
                               AND status = 'PACKED';
                    END IF;    -- End of PACKED Message -update / insert check
                END IF;                       -- Pick confirm successful check
            END IF;                            -- End of lv_packed_proc_status
        END LOOP;                          --cur_pick_conf_deliveries end loop

        COMMIT;
        fnd_file.put_line (
            fnd_file.LOG,
            'Establishing Save point : SP_' || gn_request_id || '_BEFORE_DT');
        lv_savepoint          :=
            'SAVEPOINT SP_' || gn_request_id || '_BEFORE_DT';

        EXECUTE IMMEDIATE lv_savepoint;

        --Get the shipment data into a table type for processing --START
        OPEN cur_shipment_data;

        BEGIN
            FETCH cur_shipment_data
                BULK COLLECT INTO l_shipconf_headers_obj_tab;
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_errbuf   := 'Error in BULK Fetch : ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error in BULK Fetch : ' || pv_errbuf);
                RAISE l_ex_bulk_fetch_failed;
        END;

        CLOSE cur_shipment_data;

        --Get the shipment data into a table type for processing --END
        fnd_file.put_line (fnd_file.LOG, 'Validating the Shipment data...');
        --Ship Confirm Date Validation --START
        fnd_file.put_line (
            fnd_file.LOG,
               'Validating if Ship Confirm Date is NULL or NOT for Shipment#'
            || l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number);

        IF l_shipconf_headers_obj_tab (ln_shipment_index).ship_date IS NULL
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   => 'Ship Confirm Date is NULL',
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Ship Confirm Date is NULL for Shipment#'
                    || l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                   'Ship Confirm Date is NULL for Shipment#'
                || l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number;
            RETURN;                                         --Exit the program
        END IF;

        --Ship Confirm Date Validation --END

        --Inventory Org Validation --START
        fnd_file.put_line (fnd_file.LOG, 'Validating the Shipment data...');
        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether the warehouse '
            || l_shipconf_headers_obj_tab (ln_shipment_index).wh_id
            || ' is WMS enabled');

        BEGIN
            SELECT mp.organization_id
              INTO ln_inventory_org_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code =
                       l_shipconf_headers_obj_tab (ln_shipment_index).wh_id
                   AND mp.organization_code = flv.lookup_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_inventory_org_id   := -1;
        END;

        IF ln_inventory_org_id = -1
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                           l_shipconf_headers_obj_tab (ln_shipment_index).wh_id
                        || ' - Warehouse is not WMS Enabled',
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (ln_shipment_index).wh_id
                    || ' - Warehouse is not WMS Enabled');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                   l_shipconf_headers_obj_tab (ln_shipment_index).wh_id
                || ' - Warehouse is not WMS Enabled';
            RETURN;                                         --Exit the program
        END IF;

        --Inventory Org Validation --END

        --Validation - If ship date falls in Open Inventory Accounting Period or Not - START
        fnd_file.put_line (
            fnd_file.LOG,
            'Validating whether the ship date falls in open inventory accounting period');
        lv_period_open_flag   := 'N';

        BEGIN
            SELECT ocp.open_flag
              INTO lv_period_open_flag
              FROM org_acct_periods ocp
             WHERE     1 = 1
                   AND ocp.organization_id = ln_inventory_org_id
                   AND l_shipconf_headers_obj_tab (ln_shipment_index).ship_date BETWEEN ocp.period_start_date
                                                                                    AND ocp.schedule_close_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_period_open_flag   := 'N';
        END;

        fnd_file.put_line (
            fnd_file.LOG,
               'Ship Date: '
            || l_shipconf_headers_obj_tab (ln_shipment_index).ship_date);
        fnd_file.put_line (fnd_file.LOG,
                           'lv_period_open_flag: ' || lv_period_open_flag);

        IF lv_period_open_flag = 'N'
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf        => lv_errbuf,
                    pv_retcode       => lv_retcode,
                    pv_shipment_no   =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no   => NULL,
                    pv_carton_no     => NULL,
                    pv_line_no       => NULL,
                    pv_item_number   => NULL,
                    pv_error_level   => 'SHIPMENT',
                    pv_error_message   =>
                        'Inventory accounting period is not open for Shipment Date',
                    pv_status        => 'ERROR',
                    pv_source        => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Inventory accounting period is not open for Shipment Date');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                'Inventory accounting period is not open for Shipment Date';
            RETURN;                                        --Exit the shipment
        END IF;

        --Validation - If ship date falls in Open Inventory Accounting Period or Not - START

        --Carrier Validation --START
        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether the carrier '
            || l_shipconf_headers_obj_tab (ln_shipment_index).carrier
            || '  is valid');

        BEGIN
            SELECT carrier_id
              INTO ln_carrier_id
              FROM wsh_carriers_v
             WHERE freight_code =
                   l_shipconf_headers_obj_tab (ln_shipment_index).carrier;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_carrier_id   := -1;
        END;

        IF ln_carrier_id = -1
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                           l_shipconf_headers_obj_tab (ln_shipment_index).carrier
                        || ' - carrier is not valid',
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (ln_shipment_index).carrier
                    || ' - carrier is not valid');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                   l_shipconf_headers_obj_tab (ln_shipment_index).carrier
                || ' - carrier is not valid';
            RETURN;
        END IF;

        --Carrier Validation --END

        --Carrier Ship Method Validation --START (Added on 16Jul2019)
        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether the carrier Ship Method'
            || l_shipconf_headers_obj_tab (ln_shipment_index).service_level
            || '  is valid');

        BEGIN
            SELECT carrier_service_id
              INTO ln_carrier_service_id
              FROM wsh_carrier_services
             WHERE     ship_method_code =
                       l_shipconf_headers_obj_tab (ln_shipment_index).service_level
                   AND enabled_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_carrier_service_id   := -1;
        END;

        IF ln_carrier_service_id = -1
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                           l_shipconf_headers_obj_tab (ln_shipment_index).service_level
                        || ' - carrier Ship Method is not valid',
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (ln_shipment_index).service_level
                    || ' - carrier Ship Method is not valid');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                   l_shipconf_headers_obj_tab (ln_shipment_index).service_level
                || ' - carrier Ship Method is not valid';
            RETURN;
        END IF;

        --Carrier Ship Method Validation --END

        --Deliveries exists for shipment or not Validation -START
        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether deliveries are sent for the shipment : '
            || l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number);

        IF l_shipconf_headers_obj_tab (ln_shipment_index).shipconf_orders_obj_tab.COUNT =
           0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf        => lv_errbuf,
                    pv_retcode       => lv_retcode,
                    pv_shipment_no   =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no   => NULL,
                    pv_carton_no     => NULL,
                    pv_line_no       => NULL,
                    pv_item_number   => NULL,
                    pv_error_level   => 'SHIPMENT',
                    pv_error_message   =>
                        'Delivery Information is not sent from WMS for this shipment',
                    pv_status        => 'ERROR',
                    pv_source        => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Delivery Information is not sent from WMS for the shipment : '
                    || l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                   'Delivery Information is not sent from WMS for the shipment : '
                || l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number;
            RETURN;
        END IF;

        --Deliveries exists for shipment or not Validation -END

        --Validation - Check if Trip already exists or Not for the shipment - START
        fnd_file.put_line (fnd_file.LOG,
                           'Validating whether the trip already exists');

        BEGIN
            SELECT COUNT (1)
              INTO ln_existing_trip_id
              FROM wsh_trips
             WHERE NAME =
                   l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_existing_trip_id   := 0;
        END;

        IF ln_existing_trip_id <> 0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                           l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number
                        || ' - Trip already exists',
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number
                    || ' - Trip already exists');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RETURN;
            END;

            pv_retcode   := '2';
            pv_errbuf    :=
                   l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number
                || ' - Trip already exists';
            RETURN;
        END IF;

        --Validation - Check if Trip already exists or Not - END

        --Trip Creation - START
        fnd_file.put_line (fnd_file.LOG, 'Creating the trip');
        lv_retcode            := '0';
        lv_errbuf             := NULL;

        -- Create a trip before invoking the delivery threads
        BEGIN
            create_trip (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pv_trip => l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number, pv_carrier => l_shipconf_headers_obj_tab (ln_shipment_index).carrier, pn_carrier_id => ln_carrier_id, pv_ship_method_code => l_shipconf_headers_obj_tab (ln_shipment_index).service_level, pv_vehicle_number => NULL, pv_mode_of_transport => NULL, pv_master_bol_number => NULL
                         , xn_trip_id => ln_trip_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_errbuf    := SQLERRM;
                pv_retcode   := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexpected error while invoking create trip procedure : '
                    || pv_errbuf);
        --RETURN; --Commented on 10Jul2019
        END;

        IF lv_retcode <> '0'
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                        'Trip creation failed - ' || lv_errbuf,
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (fnd_file.LOG,
                                   'Trip Creation failed - ' || lv_errbuf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Trip Creation is successful. Trip Id : ' || ln_trip_id);
        END IF;

        --Trip Creation - END

        --Ship From Stop Creation - START
        fnd_file.put_line (
            fnd_file.LOG,
               'Creating the SHIP FROM stop - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        -- Create SHIP FROM stop before invoking the delivery threads
        BEGIN
            SELECT location_id
              INTO ln_ship_from_loc_id
              FROM hr_organization_units hou
             WHERE organization_id = ln_inventory_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_ship_from_loc_id   := 0;
                pv_errbuf             := SQLERRM;
                pv_retcode            := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexpected error while getting ship from location : '
                    || pv_errbuf);
                --ROLLBACK TO lv_savepoint; --Not Required
                ROLLBACK;
        END;

        IF ln_ship_from_loc_id <> 0
        THEN
            BEGIN
                create_stop (
                    pv_errbuf             => lv_errbuf,
                    pv_retcode            => lv_retcode,
                    pv_ship_type          => 'SHIP_FROM',
                    pn_trip_id            => ln_trip_id,
                    pn_stop_seq           => 10,
                    pn_stop_location_id   => ln_ship_from_loc_id,
                    pv_dep_seal_code      =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).seal_number,
                    xn_stop_id            => ln_stop_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    := SQLERRM;
                    pv_retcode   := '2';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while invoking create stop procedure : '
                        || pv_errbuf);
                    --ROLLBACK TO lv_savepoint;
                    ROLLBACK;
            END;

            IF lv_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     =>
                            l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                        pv_delivery_no     => NULL,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'SHIPMENT',
                        pv_error_message   =>
                            'Ship From Stop creation failed - ' || lv_errbuf,
                        pv_status          => 'ERROR',
                        pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Ship From Stop Creation failed - ' || lv_errbuf);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;

                --ROLLBACK TO lv_savepoint;
                ROLLBACK;
                RETURN;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Ship From Stop Creation was successful. Stop Id : '
                    || ln_stop_id);
                -- Storing the trip id at the shipment header level
                l_shipconf_headers_obj_tab (ln_shipment_index).attribute3   :=
                    ln_stop_id;
                ln_from_stop_id   := ln_stop_id;
                gn_from_stop_id   := ln_stop_id; --Assigning to global variable
            END IF;
        ELSE
            --if ship from location is not fetched. Update the stg tables to error and Rollback Trip creation
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error while getting ship from location. So exiting the Program '
                || pv_errbuf);

            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                        'Ship From Location Fetch failed - ' || lv_errbuf,
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Ship From Location Fetch failed - ' || lv_errbuf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            --ROLLBACK TO lv_savepoint;
            ROLLBACK;
            RETURN;                                        --Exit the shipment
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Creating the SHIP FROM stop - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --Ship From Stop Creation - END

        --Launching Delivery Thread - START
        fnd_file.put_line (
            fnd_file.LOG,
               'Launching the delivery threads - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        lv_err_flag           := 'N';

        FOR ln_index IN l_shipconf_headers_obj_tab (ln_shipment_index).shipconf_orders_obj_tab.FIRST ..
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipconf_orders_obj_tab.LAST
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'Invoking the Delivery procedure');
            lv_retcode   := '0';
            lv_errbuf    := NULL;
            --calling delivery_thread procedure
            delivery_thread (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pv_shipment_no => l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number, pv_delivery_no => l_shipconf_headers_obj_tab (ln_shipment_index).shipconf_orders_obj_tab (ln_index).order_number, pn_trip_id => ln_trip_id, pv_carrier => l_shipconf_headers_obj_tab (ln_shipment_index).carrier
                             , pn_parent_req_id => pn_parent_req_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Control Back to the Shipment procedure');

            IF lv_retcode <> '0'
            THEN
                lv_err_flag   := 'Y';
            END IF;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'Launching the delivery threads - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        --Launching Delivery Thread - END
        IF lv_err_flag = 'Y'
        THEN
            pv_retcode   := '2';               --Complete the program in error
        END IF;

        SELECT COUNT (1)
          INTO ln_process_cnt
          FROM xxdo_ont_ship_conf_order_stg
         WHERE     1 = 1
               AND shipment_number = pv_shipment_no
               AND process_status = 'INPROCESS'
               AND request_id = pn_parent_req_id;

        IF ln_process_cnt = 0
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'All deliveries in Shipment are in ERROR. Exiting the shipment.');

            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     =>
                        l_shipconf_headers_obj_tab (ln_shipment_index).shipment_number,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   => 'All Deliveries are in ERROR',
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (fnd_file.LOG,
                                   'All Deliveries are in ERROR');
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error to All Deliveries are in ERROR :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN;                                        --Exit the shipment
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'updating Ship method - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        FOR delivery_rec IN cur_delivery_ids
        LOOP
            update_ship_method (
                delivery_rec.delivery_id,
                l_shipconf_headers_obj_tab (ln_shipment_index).service_level);
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
               'updating Ship method - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'Creating Ship to Stop - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        -- Logic to create SHIP TO Stops
        FOR ship_to_stops_rec IN cur_ship_to_stops
        LOOP
            BEGIN
                create_stop (
                    pv_errbuf             => lv_errbuf,
                    pv_retcode            => lv_retcode,
                    pv_ship_type          => 'SHIP_TO',
                    pn_trip_id            => ln_trip_id,
                    pn_stop_seq           => NULL,
                    -- create stop will derive the next sequence no
                    pn_stop_location_id   =>
                        ship_to_stops_rec.ship_to_location_id,
                    pv_dep_seal_code      => NULL,
                    xn_stop_id            => ln_stop_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_errbuf    := SQLERRM;
                    pv_retcode   := '2';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while invoking create stop procedure for ship to location : '
                        || pv_errbuf);
                    ROLLBACK;
            --RETURN; --Commented on 10Jul2019. Do not exit immediately, stamp the error in the staging tables and then exit
            END;

            IF lv_retcode <> '0'
            THEN
                -- Update all the deliveries of the current ship to location
                FOR same_stop_del_nums_rec
                    IN cur_same_stop_del_nums (
                           ship_to_stops_rec.ship_to_location_id)
                LOOP
                    BEGIN
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     =>
                                same_stop_del_nums_rec.order_number,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   =>
                                   'Ship To Stop creation failed - '
                                || lv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Ship To Stop Creation failed - ' || lv_errbuf);
                        pv_retcode   := '2';
                        pv_errbuf    := lv_errbuf;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while updating error status to Ship To Stop creation failed - '
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                            ROLLBACK;
                            RETURN;
                    END;
                END LOOP;

                ROLLBACK;
                RETURN;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Ship To Stop Creation is successful for ship to location: '
                    || ship_to_stops_rec.ship_to_location_id
                    || ' Ship to Id : '
                    || ln_stop_id);

                FOR same_stop_del_nums_rec
                    IN cur_same_stop_del_nums (
                           ship_to_stops_rec.ship_to_location_id)
                LOOP
                    --Assign delivery to Stop
                    assign_del_to_trip (
                        pv_errbuf         => lv_errbuf,
                        pv_retcode        => lv_retcode,
                        pn_trip_id        => ln_trip_id,
                        pn_delivery_id    =>
                            TO_NUMBER (same_stop_del_nums_rec.order_number),
                        pn_from_stop_id   => ln_from_stop_id,
                        pn_to_stop_id     => ln_stop_id);

                    IF lv_retcode <> '0'
                    THEN
                        BEGIN
                            update_error_records (
                                pv_errbuf          => lv_errbuf,
                                pv_retcode         => lv_retcode,
                                pv_shipment_no     => pv_shipment_no,
                                pv_delivery_no     =>
                                    same_stop_del_nums_rec.order_number,
                                pv_carton_no       => NULL,
                                pv_line_no         => NULL,
                                pv_item_number     => NULL,
                                pv_error_level     => 'DELIVERY',
                                pv_error_message   =>
                                       'Assigning Delivery to Trip-Stop failed - '
                                    || lv_errbuf,
                                pv_status          => 'ERROR',
                                pv_source          => 'DELIVERY_THREAD');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Assigning Delivery to Trip-Stop failed - '
                                || lv_errbuf);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '2';
                                pv_errbuf    :=
                                       'Unexpected Error while updating error to Assigning Delivery to Trip-Stop failed - '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                                ROLLBACK;
                                RETURN;
                        END;

                        ROLLBACK;
                        RETURN;
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Assigning Delivery to Trip-Stop is successful. Delivery Id: '
                            || TO_NUMBER (
                                   same_stop_del_nums_rec.order_number));
                    END IF;
                END LOOP;                             --cur_same_stop_del_nums
            END IF;
        END LOOP;                                 --cur_ship_to_stops end loop

        fnd_file.put_line (
            fnd_file.LOG,
               'Creating Ship to Stop - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        -- Ship confirm the Trip
        lv_errbuf             := NULL;
        lv_retcode            := '0';
        fnd_file.put_line (
            fnd_file.LOG,
               'Ship confirm the Trip - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        BEGIN
            ship_confirm_trip (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pn_org_id => gn_inv_org_id
                               , pn_trip_id => ln_trip_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => NULL,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'SHIPMENT',
                        pv_error_message   =>
                               'Calling Ship Confirm Trip Procedure Failed:  '
                            || lv_errbuf,
                        pv_status          => 'ERROR',
                        pv_source          => 'SHIPMENT_THREAD_AFTER_DT');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Calling Ship Confirm Trip Procedure Failed:  '
                        || lv_errbuf);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error to Calling Ship Confirm Trip Procedure Failed:  '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        ROLLBACK;
                        RETURN;
                END;

                ROLLBACK;                           --Rollback entire shipment
                RETURN;
        END;

        IF lv_retcode <> '0'
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => NULL,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'SHIPMENT',
                    pv_error_message   =>
                        'Ship Confirm Trip Failed:  ' || lv_errbuf,
                    pv_status          => 'ERROR',
                    pv_source          => 'SHIPMENT_THREAD_AFTER_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Ship Confirm Trip Failed:  ' || lv_errbuf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error to Ship Confirm Trip Failed :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    ROLLBACK;
                    RETURN;
            END;

            ROLLBACK;
            RETURN;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'Ship confirm Trip is successful');
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Ship confirm the Trip - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'Updating the Successfully processed records status to PROCESSED - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        --- Update the successfully processed records status as "PROCESSED"
        BEGIN
            update_error_records (
                pv_errbuf          => lv_errbuf,
                pv_retcode         => lv_retcode,
                pv_shipment_no     => pv_shipment_no,
                pv_delivery_no     => NULL,
                pv_carton_no       => NULL,
                pv_line_no         => NULL,
                pv_item_number     => NULL,
                pv_error_level     => 'SHIPMENT',
                pv_error_message   => NULL,
                pv_status          => 'PROCESSED',
                pv_source          => 'SHIPMENT_THREAD_AFTER_DT');
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '2';
                pv_errbuf    :=
                       'Unexpected Error while updating status to PROCESSED from INPROCESS:'
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                RETURN;
        END;

        COMMIT;
        fnd_file.put_line (
            fnd_file.LOG,
               'Updating the Successfully processed records status to PROCESSED - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        fnd_file.put_line (
            fnd_file.LOG,
               'Backorder the new Delivery if created - START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        --Back Order the new delivery --START
        IF g_new_delv_ids_tab.EXISTS (1)
        THEN
            FOR l_num_hold_index IN 1 .. g_new_delv_ids_tab.COUNT
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Backorder Delivery : '
                    || g_new_delv_ids_tab (l_num_hold_index));

                --Transfer the items that are in STAGE subinventory to PICK subinventory after back ordering the delivery
                --So get the items and quantity which needs to be moved from STAGE to PICK subinventory
                IF l_subinv_xfer_tab.EXISTS (1)
                THEN
                    l_subinv_xfer_tab.DELETE;
                END IF;

                get_subinv_xfer_qty (
                    pn_new_delivery_id   =>
                        g_new_delv_ids_tab (l_num_hold_index),
                    p_subinv_xfer_tab   => l_subinv_xfer_tab);
                lv_errbuf    := NULL;
                lv_retcode   := '0';

                BEGIN
                    back_order_delivery (
                        pn_delivery_id   =>
                            g_new_delv_ids_tab (l_num_hold_index),
                        pv_errbuf    => lv_errbuf,
                        pv_retcode   => lv_retcode);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Exception while calling back_order_delivery procedure. Error is: '
                            || SQLERRM);
                        lv_retcode   := '2';
                END;

                IF lv_retcode <> '0'
                THEN
                    lv_err_flag   := 'Y';
                ELSE
                    COMMIT;                 --Commit the back ordered delivery
                END IF;

                --If back order is successful then move the inventory which is in STAGE Subinventory to PICK Subinventory
                --Move the back ordered qty from STAGE to PICK subinventory
                IF lv_retcode = '0' AND l_subinv_xfer_tab.COUNT > 0
                THEN
                    subinventory_transfer (
                        p_subinv_xfer_tab => l_subinv_xfer_tab);
                END IF;
            END LOOP;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Backorder the new Delivery if created - END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));
        --Back Order the new delivery - END
        --Start of changes for 1.2
        /*  Updating delivery table attribute values - Start*/
        fnd_file.put_line (
            fnd_file.LOG,
               'Calling update_delivery_attributes- START. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        BEGIN
            update_delivery_attributes (pv_errbuf        => lv_errbuf,
                                        pv_retcode       => lv_retcode,
                                        pv_shipment_no   => pv_shipment_no);
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_retcode   := '1';
                pv_errbuf    :=
                       'Unexpected Error while updating delivery attributes :'
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                RETURN;
        END;

        IF lv_retcode <> '0'
        THEN
            pv_retcode   := '1';
            pv_errbuf    :=
                'Error while updating delivery atrributes:' || lv_errbuf;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Calling update_delivery_attributes- END. Timestamp: '
            || TO_CHAR (SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        /*  Updating delivery table attribute values - End*/
        --End of changes for 1.2
        --Commented interfacing to EDI tables logic for change 1.2
        /*  Logic for interfacing to EDI tables - Start*/
        /*fnd_file.put_line (fnd_file.LOG,
                           'Calling INTERFACE_EDI_ASNS procedure - START. Timestamp: '||TO_CHAR(SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));

        BEGIN
           interface_edi_asns (pv_errbuf        => lv_errbuf,
                               pv_retcode       => lv_retcode,
                               pv_shipment_no   => pv_shipment_no);
        EXCEPTION
           WHEN OTHERS
           THEN
              pv_retcode := '1';
              pv_errbuf :=
                 'Unexpected Error while interfacing EDI ASNs :' || SQLERRM;
              fnd_file.put_line (fnd_file.LOG, pv_errbuf);
              RETURN;
        END;

        IF lv_retcode <> '0'
        THEN
           pv_retcode := '1';
           pv_errbuf := 'Error while interfacing EDI ASNs :' || lv_errbuf;
           fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Calling INTERFACE_EDI_ASNS procedure - END. Timestamp: '||TO_CHAR(SYSDATE, 'DD-MON-RRRR HH24:MI:SS'));*/
        IF lv_err_flag = 'Y'
        THEN
            pv_retcode   := '2';
        END IF;
    EXCEPTION
        WHEN l_ex_bulk_fetch_failed
        THEN
            pv_retcode   := '2';
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at Shipment thread procedure : '
                || pv_errbuf);
            update_error_records (
                pv_errbuf          => lv_errbuf,
                pv_retcode         => lv_retcode,
                pv_shipment_no     => pv_shipment_no,
                pv_delivery_no     => NULL,
                pv_carton_no       => NULL,
                pv_line_no         => NULL,
                pv_item_number     => NULL,
                pv_error_level     => 'SHIPMENT',
                pv_error_message   =>
                       'Unexpected error at Shipment thread procedure : '
                    || pv_errbuf,
                pv_status          => 'ERROR',
                pv_source          => 'SHIPMENT_THREAD_AFTER_DT');
    END shipment_thread;

    -- ***************************************************************************
    -- Procedure Name      : update_ship_method
    -- Description         : This procedure is to update the ship method
    --
    -- Parameters          : pn_delivery_id           IN : Delivery ID
    --                       pv_ship_method_code      IN : Ship Method
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0       Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE update_ship_method (pn_delivery_id        IN NUMBER,
                                  pv_ship_method_code   IN VARCHAR2)
    IS
        lv_ship_method_code    VARCHAR2 (100);
        lv_service_level       VARCHAR2 (100);
        lv_mode_of_transport   VARCHAR2 (100);
        ln_carrier_id          NUMBER;
        ln_organization_id     NUMBER;
        -----
        lt_delivery_info       wsh_deliveries_pub.delivery_pub_rec_type;
        lv_return_status       VARCHAR2 (200);
        ln_msg_count           NUMBER;
        lv_msg_data            VARCHAR2 (2000);
        ln_delivery_id         NUMBER;
        lv_name                VARCHAR2 (100);
        lv_msg_details         VARCHAR2 (3000);
        lv_msg_summary         VARCHAR2 (3000);
        ------
        lv_init_msg_list       VARCHAR2 (30);
        lv_commit              VARCHAR2 (30);
        lv_source_code         VARCHAR2 (15);
        ln_index               NUMBER;
        changed_attributes     wsh_delivery_details_pub.changedattributetabtype;

        CURSOR c_get_delivery_details IS
            SELECT DISTINCT wdd.delivery_detail_id, source_code
              FROM apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
             WHERE     wda.delivery_id = pn_delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id;

        TYPE source_code_type IS TABLE OF VARCHAR2 (10000);

        lt_source_code         source_code_type;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Delivery : ' || pn_delivery_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Ship Method Meaning : ' || pv_ship_method_code);

        /* Get the carrier details*/
        BEGIN
            SELECT ship_method_code, carrier_id, service_level,
                   mode_of_transport
              INTO lv_ship_method_code, ln_carrier_id, lv_service_level, lv_mode_of_transport
              FROM apps.wsh_carrier_services
             WHERE     enabled_flag = 'Y'
                   AND ship_method_code = pv_ship_method_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_ship_method_code   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to fetch Ship method code for: '
                    || pv_ship_method_code);
        END;

        /* Get the carrier details*/
        BEGIN
            SELECT organization_id
              INTO ln_organization_id
              FROM apps.wsh_new_deliveries
             WHERE delivery_id = pn_delivery_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_organization_id   := NULL;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to fetch Organization for delivery: '
                    || pn_delivery_id);
        END;

        IF lv_ship_method_code IS NOT NULL
        THEN
            /* Update Delivery Attributes */
            lt_delivery_info.delivery_id         := pn_delivery_id;
            lt_delivery_info.NAME                := TO_CHAR (pn_delivery_id);
            lt_delivery_info.ship_method_code    := lv_ship_method_code;
            lt_delivery_info.carrier_id          := ln_carrier_id;
            lt_delivery_info.organization_id     := ln_organization_id;
            lt_delivery_info.service_level       := lv_service_level;
            lt_delivery_info.mode_of_transport   := lv_mode_of_transport;
            wsh_deliveries_pub.create_update_delivery (p_api_version_number => 1.0, p_init_msg_list => fnd_api.g_true, x_return_status => lv_return_status, x_msg_count => ln_msg_count, x_msg_data => lv_msg_data, p_action_code => 'UPDATE', p_delivery_info => lt_delivery_info, p_delivery_name => TO_CHAR (pn_delivery_id), x_delivery_id => ln_delivery_id
                                                       , x_name => lv_name);

            IF lv_return_status <> 'S'
            THEN
                wsh_util_core.get_messages ('Y', lv_msg_summary, lv_msg_details
                                            , ln_msg_count);
                lv_msg_summary   := lv_msg_summary || ' ' || lv_msg_details;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'API Error while updating the Delivery: '
                    || lv_msg_summary);
            ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Delivery Updated Successful');
            END IF;

            lt_source_code                       :=
                source_code_type ('OE', 'WSH');
            /* Update Delivery Detail Attributes */
            lv_return_status                     :=
                wsh_util_core.g_ret_sts_success;

            /*FOR detail_rec IN c_get_delivery_details
            LOOP
               --- Delivery Details --

               fnd_file.put_line (
                  fnd_file.LOG,
                  'Delivery Detail:' || detail_rec.delivery_detail_id);

               changed_attributes (1).delivery_detail_id :=
                  detail_rec.delivery_detail_id;
               changed_attributes (1).shipping_method_code := lv_ship_method_code;
               changed_attributes (1).carrier_id := ln_carrier_id;

               wsh_delivery_details_pub.update_shipping_attributes (
                  p_api_version_number   => 1.0,
                  p_init_msg_list        => fnd_api.g_true,
                  p_commit               => fnd_api.g_true,
                  x_return_status        => lv_return_status,
                  x_msg_count            => ln_msg_count,
                  x_msg_data             => lv_msg_data,
                  p_changed_attributes   => changed_attributes,
                  p_source_code          => detail_rec.source_code);

               IF (lv_return_status <> wsh_util_core.g_ret_sts_success)
               THEN
                  wsh_util_core.get_messages ('Y',
                                              lv_msg_summary,
                                              lv_msg_details,
                                              ln_msg_count);
                  lv_msg_summary := lv_msg_summary || ' ' || lv_msg_details;
                  fnd_file.put_line (
                     fnd_file.LOG,
                        'API Error while updating Delivery Details '
                     || lv_msg_summary);
               ELSE
                  fnd_file.put_line (fnd_file.LOG, 'Update Succesful');
               END IF;
            END LOOP;*/
            UPDATE wsh_delivery_details
               SET ship_method_code = lv_ship_method_code, carrier_id = ln_carrier_id, service_level = lv_service_level,
                   mode_of_transport = lv_mode_of_transport
             WHERE delivery_detail_id IN
                       (SELECT delivery_detail_id
                          FROM wsh_delivery_assignments
                         WHERE delivery_id = pn_delivery_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'In Main Exception updating ship method code, ' || SQLERRM);
    END update_ship_method;

    -- ***************************************************************************
    -- Function Name      : check_valid_ship_to
    -- Description        : This function is to check if ship to location of delivery is Valid or not and based on that send TRUE or FALSE
    -- Parameters         : pv_shipment_no       IN  : Shipment Number
    --                      pv_delivery_no       IN  : Delivery Number
    --                      pv_errbuf            OUT : Error Message
    --                      pv_retcode           OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION check_valid_ship_to (pv_shipment_no IN VARCHAR2, pv_delivery_no IN VARCHAR2, pv_errbuf OUT VARCHAR2
                                  , pv_retcode OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_ship_to_loc_id   NUMBER := NULL;
        ln_ship_to_exists   NUMBER := NULL;
        lv_errbuf           VARCHAR2 (4000) := NULL;
        lv_retcode          VARCHAR2 (1) := '0';
    BEGIN
        SELECT DISTINCT wdd.ship_to_location_id
          INTO ln_ship_to_loc_id
          FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd,
               hz_locations hl
         WHERE     1 = 1
               AND wnd.NAME = pv_delivery_no
               AND wnd.organization_id = gn_inv_org_id
               AND wnd.delivery_id = wda.delivery_id
               AND wda.delivery_detail_id = wdd.delivery_detail_id
               AND wdd.organization_id = gn_inv_org_id
               AND wdd.source_code = 'OE'
               AND wdd.ship_to_location_id = hl.location_id;

        IF ln_ship_to_loc_id IS NULL
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'DELIVERY',
                    pv_error_message   =>
                        'Ship To location is either NULL or INVALID',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Ship To location is either NULL or INVALID');
                pv_retcode   := '2';
                pv_errbuf    := 'Ship To location is either NULL or INVALID';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CHECK_VALID_SHIP_TO function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END check_valid_ship_to;

    -- ***************************************************************************
    -- Function Name      : validate_delivery
    -- Description        : This function is to check if delivery details exists in EBS or not and based on that send TRUE or FALSE
    -- Parameters         : pv_shipment_no       IN  : Shipment Number
    --                      pv_delivery_no       IN  : Delivery Number
    --                      pv_errbuf            OUT : Error Message
    --                      pv_retcode           OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION validate_delivery (pv_shipment_no IN VARCHAR2, pv_delivery_no IN VARCHAR2, pv_errbuf OUT VARCHAR2
                                , pv_retcode OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        ln_del_det_exists_cnt   NUMBER := 0;
        lv_errbuf               VARCHAR2 (4000) := NULL;
        lv_retcode              VARCHAR2 (1) := '0';
        ln_del_det_status_cnt   NUMBER := 0;
        lv_error_msg            VARCHAR2 (2000) := NULL;
    BEGIN
        SELECT COUNT (1)
          INTO ln_del_det_exists_cnt
          FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
         WHERE     1 = 1
               AND wnd.NAME = pv_delivery_no
               AND wnd.status_code = 'OP'            --Delivery Should be Open
               AND wnd.organization_id = gn_inv_org_id
               AND wnd.delivery_id = wda.delivery_id
               AND wda.delivery_detail_id = wdd.delivery_detail_id
               AND wdd.organization_id = gn_inv_org_id
               AND wdd.source_code = 'OE';

        IF ln_del_det_exists_cnt <> 0
        THEN
            SELECT COUNT (1)
              INTO ln_del_det_status_cnt
              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
             WHERE     1 = 1
                   AND wnd.NAME = pv_delivery_no
                   AND wnd.status_code = 'OP'        --Delivery Should be Open
                   AND wnd.organization_id = gn_inv_org_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.organization_id = gn_inv_org_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status <> 'Y';     --Staged/Pick Confirmed

            IF ln_del_det_status_cnt > 0
            THEN
                lv_error_msg   :=
                    'One or more Delivery Details are not Staged/Pick Confirmed';
            END IF;
        ELSE
            lv_error_msg   :=
                'Delivery Details Not Found or Delivery is not OPEN';
        END IF;

        IF lv_error_msg IS NOT NULL
        THEN
            BEGIN
                update_error_records (pv_errbuf          => lv_errbuf,
                                      pv_retcode         => lv_retcode,
                                      pv_shipment_no     => pv_shipment_no,
                                      pv_delivery_no     => pv_delivery_no,
                                      pv_carton_no       => NULL,
                                      pv_line_no         => NULL,
                                      pv_item_number     => NULL,
                                      pv_error_level     => 'DELIVERY',
                                      pv_error_message   => lv_error_msg,
                                      pv_status          => 'ERROR',
                                      pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (fnd_file.LOG, lv_error_msg);
                pv_retcode   := '2';
                pv_errbuf    := lv_error_msg;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in VALIDATE_DELIVERY function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END validate_delivery;

    -- ***************************************************************************
    -- Function Name      : check_item_exists
    -- Description        : This function is to check if Item exists in EBS or not and based on that send TRUE or FALSE
    -- Parameters         : pv_shipment_no       IN  : Shipment Number
    --                      pv_delivery_no       IN  : Delivery Number
    --                      pn_parent_req_id     IN  : Request ID
    --                      pv_errbuf            OUT : Error Message
    --                      pv_retcode           OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION check_item_exists (pv_shipment_no     IN     VARCHAR2,
                                pv_delivery_no     IN     VARCHAR2,
                                pn_parent_req_id   IN     NUMBER,
                                pv_errbuf             OUT VARCHAR2,
                                pv_retcode            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR validate_item_cur IS
              SELECT carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.item_number
                FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
               WHERE     1 = 1
                     AND carton_dtl.process_status = 'INPROCESS'
                     AND carton_dtl.shipment_number = pv_shipment_no
                     AND carton_dtl.order_number = pv_delivery_no
                     AND carton_dtl.request_id = pn_parent_req_id
            GROUP BY carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.item_number;

        ln_item_exists    NUMBER := 0;
        ln_item_err_cnt   NUMBER := 0;
        lv_errbuf         VARCHAR2 (4000) := NULL;
        lv_retcode        VARCHAR2 (1) := '0';
    BEGIN
        SELECT COUNT (1)
          INTO ln_item_exists
          FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
         WHERE     1 = 1
               AND carton_dtl.process_status = 'INPROCESS'
               AND carton_dtl.shipment_number = pv_shipment_no
               AND carton_dtl.order_number = pv_delivery_no
               AND carton_dtl.request_id = pn_parent_req_id
               AND NOT EXISTS
                       (SELECT 1
                          FROM apps.mtl_system_items_b msi
                         WHERE     msi.organization_id = gn_inv_org_id
                               AND msi.segment1 <> carton_dtl.item_number);

        IF ln_item_exists > 0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'DELIVERY',
                    pv_error_message   => 'One or more Items are Invalid',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (fnd_file.LOG,
                                   'One or more Items are Invalid');
                pv_retcode   := '2';
                pv_errbuf    := 'One or more Items are Invalid';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;                                        --ln_item_exists end if
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CHECK_ITEM_EXISTS function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END check_item_exists;

    -- ***************************************************************************
    -- Function Name      : check_ord_line_exists
    -- Description        : This function is to check if Order line exists in EBS or not and based on that send TRUE or FALSE
    -- Parameters         : pv_shipment_no     IN  : Shipment Number
    --                      pv_delivery_no     IN  : Delivery Number
    --                      pn_parent_req_id   IN  : Request ID
    --                      pv_errbuf          OUT : Error Message
    --                      pv_retcode         OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION check_ord_line_exists (pv_shipment_no     IN     VARCHAR2,
                                    pv_delivery_no     IN     VARCHAR2,
                                    pn_parent_req_id   IN     NUMBER,
                                    pv_errbuf             OUT VARCHAR2,
                                    pv_retcode            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR validate_ord_line_cur IS
            SELECT DISTINCT carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                            carton_dtl.line_number, TO_NUMBER (carton_dtl.line_number) line_number_converted
              FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
             WHERE     1 = 1
                   AND carton_dtl.process_status = 'INPROCESS'
                   AND carton_dtl.shipment_number = pv_shipment_no
                   AND carton_dtl.order_number = pv_delivery_no
                   AND carton_dtl.request_id = pn_parent_req_id
                   AND NOT EXISTS
                           (SELECT wdd.source_line_id
                              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
                             WHERE     wnd.NAME = carton_dtl.order_number
                                   AND wnd.status_code = 'OP'
                                   --Delivery Should be Open
                                   AND wnd.organization_id = gn_inv_org_id
                                   AND wnd.delivery_id = wda.delivery_id
                                   AND wda.delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND wdd.organization_id = gn_inv_org_id
                                   AND wdd.source_code = 'OE'
                                   AND wdd.source_line_id =
                                       TO_NUMBER (carton_dtl.line_number));

        ln_ord_line_err_cnt   NUMBER := 0;
        lv_errbuf             VARCHAR2 (4000) := NULL;
        lv_retcode            VARCHAR2 (1) := '0';
    BEGIN
        FOR validate_ord_line_rec IN validate_ord_line_cur
        LOOP
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => validate_ord_line_rec.line_number,
                    pv_item_number     => NULL,
                    pv_error_level     => 'ORDER LINE',
                    pv_error_message   => 'Line Number not found',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Line Number : '
                    || validate_ord_line_rec.line_number
                    || ' does not exist in EBS');
                pv_retcode   := '2';
                pv_errbuf    :=
                       'Line Number : '
                    || validate_ord_line_rec.line_number
                    || ' does not exist in EBS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;
        END LOOP;

        --Check if there are any Errors in Carton Details table for this shipment and delivery
        SELECT COUNT (1)
          INTO ln_ord_line_err_cnt
          FROM xxdo_ont_ship_conf_cardtl_stg
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no
               AND order_number = pv_delivery_no
               AND request_id = pn_parent_req_id;

        --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
        IF ln_ord_line_err_cnt > 0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'DELIVERY',
                    pv_error_message   =>
                        'One or more Line Numbers not found in EBS',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'One or more Line Numbers not found in EBS');
                pv_retcode   := '2';
                pv_errbuf    := 'One or more Line Numbers not found in EBS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CHECK_ORD_LINE_EXISTS function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END check_ord_line_exists;

    -- ***************************************************************************
    -- Function Name      : check_over_ship_delv
    -- Description        : This function is to check for over shipment for delivery and based on that send TRUE or FALSE
    -- Parameters         : pv_shipment_no     IN  : Shipment Number
    --                      pv_delivery_no     IN  : Delivery Number
    --                      pn_parent_req_id   IN  : Request ID
    --                      pv_errbuf          OUT : Error Message
    --                      pv_retcode         OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION check_over_ship_delv (pv_shipment_no     IN     VARCHAR2,
                                   pv_delivery_no     IN     VARCHAR2,
                                   pn_parent_req_id   IN     NUMBER,
                                   pv_errbuf             OUT VARCHAR2,
                                   pv_retcode            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR validate_ord_line_cur IS
              SELECT carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.line_number, TO_NUMBER (carton_dtl.line_number) line_number_converted, SUM (qty) stg_qty
                FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
               WHERE     1 = 1
                     AND carton_dtl.process_status = 'INPROCESS'
                     AND carton_dtl.shipment_number = pv_shipment_no
                     AND carton_dtl.order_number = pv_delivery_no
                     AND carton_dtl.request_id = pn_parent_req_id
            GROUP BY carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.line_number;

        ln_line_delv_qty      NUMBER := 0;
        ln_line_split_qty     NUMBER := 0;
        ln_line_total_qty     NUMBER := 0;
        ln_ship_qty_err_cnt   NUMBER := 0;
        lv_errbuf             VARCHAR2 (4000) := NULL;
        lv_retcode            VARCHAR2 (1) := '0';
    BEGIN
        FOR validate_ord_line_rec IN validate_ord_line_cur
        LOOP
            ln_line_delv_qty    := 0;

            BEGIN
                SELECT SUM (wdd.requested_quantity) delv_qty
                  INTO ln_line_delv_qty
                  FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
                 WHERE     1 = 1
                       AND wnd.NAME = pv_delivery_no
                       AND wnd.status_code = 'OP'
                       AND wnd.organization_id = gn_inv_org_id
                       AND wnd.delivery_id = wda.delivery_id
                       AND wda.delivery_detail_id = wdd.delivery_detail_id
                       AND wdd.source_code = 'OE'
                       AND wdd.released_status = 'Y'
                       AND wdd.organization_id = gn_inv_org_id
                       AND wdd.source_line_id =
                           validate_ord_line_rec.line_number_converted;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_line_delv_qty   := 0;
            END;

            --Get Split line qty
            ln_line_split_qty   := 0;
            --Split line qty is not required. Commented on 10Jul2019
            --         BEGIN
            --            SELECT SUM (wdd.requested_quantity) delv_qty
            --              INTO ln_line_split_qty
            --              FROM wsh_new_deliveries wnd,
            --                   wsh_delivery_assignments wda,
            --                   wsh_delivery_details wdd
            --             WHERE     1 = 1
            --                   AND wnd.name = pv_delivery_no
            --                   AND wnd.status_code = 'OP'
            --                   AND wnd.organization_id = gn_inv_org_id
            --                   AND wnd.delivery_id = wda.delivery_id
            --                   AND wda.delivery_detail_id = wdd.delivery_detail_id
            --                   AND wdd.organization_id = gn_inv_org_id
            --                   AND wdd.source_code = 'OE'
            --                   AND wdd.released_status = 'Y'
            --                   AND wdd.source_line_id =
            --                          (SELECT line_id
            --                             FROM oe_order_lines_all
            --                            WHERE     split_from_line_id =
            --                                         validate_ord_line_rec.line_number_converted
            --                                  AND header_id = wdd.source_header_id);
            --         EXCEPTION
            --            WHEN OTHERS
            --            THEN
            --               ln_line_split_qty := 0;
            --         END;
            ln_line_total_qty   :=
                NVL (ln_line_delv_qty, 0) + NVL (ln_line_split_qty, 0);

            IF validate_ord_line_rec.stg_qty > ln_line_total_qty
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => validate_ord_line_rec.line_number,
                        pv_item_number     => NULL,
                        pv_error_level     => 'ORDER LINE',
                        pv_error_message   =>
                            'Shipped Qty is greater than Requested Qty',
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Line Number : '
                        || validate_ord_line_rec.line_number
                        || ' Shipped Qty: '
                        || validate_ord_line_rec.stg_qty
                        || ' is greater than Requested Qty: '
                        || ln_line_total_qty);
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Line Number : '
                        || validate_ord_line_rec.line_number
                        || ' Shipped Qty: '
                        || validate_ord_line_rec.stg_qty
                        || ' is greater than Requested Qty: '
                        || ln_line_total_qty;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;
            END IF;                     --validate_ord_line_rec.stg_qty end if
        END LOOP;

        --Check if there are any Errors in Carton Details table for this shipment and delivery
        ln_ship_qty_err_cnt   := 0;

        SELECT COUNT (1)
          INTO ln_ship_qty_err_cnt
          FROM xxdo_ont_ship_conf_cardtl_stg
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no
               AND order_number = pv_delivery_no
               AND request_id = pn_parent_req_id;

        --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
        IF ln_ship_qty_err_cnt > 0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf        => lv_errbuf,
                    pv_retcode       => lv_retcode,
                    pv_shipment_no   => pv_shipment_no,
                    pv_delivery_no   => pv_delivery_no,
                    pv_carton_no     => NULL,
                    pv_line_no       => NULL,
                    pv_item_number   => NULL,
                    pv_error_level   => 'DELIVERY',
                    pv_error_message   =>
                        'One or more lines has Shipped Qty greater than Requested Qty',
                    pv_status        => 'ERROR',
                    pv_source        => 'DELIVERY_THREAD');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'One or more lines has Shipped Qty greater than Requested Qty');
                pv_retcode   := '2';
                pv_errbuf    :=
                    'One or more lines has Shipped Qty greater than Requested Qty';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CHECK_OVER_SHIP_DELV function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END check_over_ship_delv;

    -- ***************************************************************************
    -- Function Name      : check_ship_qty_zero
    -- Description        : This function is to check if shipment qty is zero for any carton detail line for delivery and based on that send TRUE or FALSE
    -- Parameters         : pv_shipment_no     IN  : Shipment Number
    --                      pv_delivery_no     IN  : Delivery Number
    --                      pn_parent_req_id   IN  : Request ID
    --                      pv_errbuf         OUT : Error Message
    --                      pv_retcode        OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION check_ship_qty_zero (pv_shipment_no     IN     VARCHAR2,
                                  pv_delivery_no     IN     VARCHAR2,
                                  pn_parent_req_id   IN     NUMBER,
                                  pv_errbuf             OUT VARCHAR2,
                                  pv_retcode            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR validate_ship_qty_cur IS
            SELECT carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                   carton_dtl.line_number
              FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
             WHERE     1 = 1
                   AND carton_dtl.process_status = 'INPROCESS'
                   AND carton_dtl.shipment_number = pv_shipment_no
                   AND carton_dtl.order_number = pv_delivery_no
                   AND carton_dtl.request_id = pn_parent_req_id
                   AND carton_dtl.qty = 0;

        ln_line_delv_qty      NUMBER := 0;
        ln_line_split_qty     NUMBER := 0;
        ln_line_total_qty     NUMBER := 0;
        ln_ship_qty_err_cnt   NUMBER := 0;
        lv_errbuf             VARCHAR2 (4000) := NULL;
        lv_retcode            VARCHAR2 (1) := '0';
    BEGIN
        FOR validate_ship_qty_rec IN validate_ship_qty_cur
        LOOP
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => validate_ship_qty_rec.line_number,
                    pv_item_number     => NULL,
                    pv_error_level     => 'ORDER LINE',
                    pv_error_message   => 'Shipped Qty cannot be 0',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Line Number : '
                    || validate_ship_qty_rec.line_number
                    || ' Shipped Qty is Zero');
                pv_retcode   := '2';
                pv_errbuf    :=
                       'Line Number : '
                    || validate_ship_qty_rec.line_number
                    || ' Shipped Qty is Zero';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;
        END LOOP;

        --Check if there are any Errors in Carton Details table for this shipment and delivery
        ln_ship_qty_err_cnt   := 0;

        SELECT COUNT (1)
          INTO ln_ship_qty_err_cnt
          FROM xxdo_ont_ship_conf_cardtl_stg
         WHERE     1 = 1
               AND process_status = 'ERROR'
               AND shipment_number = pv_shipment_no
               AND order_number = pv_delivery_no
               AND request_id = pn_parent_req_id;

        --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
        IF ln_ship_qty_err_cnt > 0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'DELIVERY',
                    pv_error_message   =>
                        'One or more lines has Shipped Qty as 0',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (fnd_file.LOG,
                                   'One or more lines has Shipped Qty as 0');
                pv_retcode   := '2';
                pv_errbuf    := 'One or more lines has Shipped Qty as 0';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;
        ELSE
            RETURN TRUE;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CHECK_SHIP_QTY_ZERO function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END check_ship_qty_zero;

    -- ***************************************************************************
    -- Function Name      : check_carton_exists
    -- Description        : This function is to check if carton exists for the delivery in staging tabled and also check if it exists in WMS_LICENSE_PLATE_NUMBERS table
    -- Parameters         : pv_shipment_no     IN  : Shipment Number
    --                      pv_delivery_no     IN  : Delivery Number
    --                      pn_parent_req_id   IN  : Request ID
    --                      pv_errbuf         OUT : Error Message
    --                      pv_retcode        OUT : Error Code
    -- Return             : BOOLEAN(TRUE/FALSE)
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION check_carton_exists (pv_shipment_no     IN     VARCHAR2,
                                  pv_delivery_no     IN     VARCHAR2,
                                  pn_parent_req_id   IN     NUMBER,
                                  pv_errbuf             OUT VARCHAR2,
                                  pv_retcode            OUT VARCHAR2)
        RETURN BOOLEAN
    IS
        CURSOR carton_exists_cur IS
            SELECT carton.shipment_number, carton.order_number, carton.wh_id,
                   carton.carton_number
              FROM xxdo_ont_ship_conf_carton_stg carton
             WHERE     1 = 1
                   AND carton.process_status = 'INPROCESS'
                   AND carton.shipment_number = pv_shipment_no
                   AND carton.order_number = pv_delivery_no
                   AND carton.request_id = pn_parent_req_id;

        ln_carton_cnt       NUMBER := 0;
        ln_carton_exists    NUMBER := 0;
        ln_carton_err_cnt   NUMBER := 0;
        lv_errbuf           VARCHAR2 (4000) := NULL;
        lv_retcode          VARCHAR2 (1) := '0';
    BEGIN
        SELECT COUNT (1)
          INTO ln_carton_cnt
          FROM xxdo_ont_ship_conf_carton_stg carton
         WHERE     1 = 1
               AND carton.shipment_number = pv_shipment_no
               AND carton.order_number = pv_delivery_no
               AND carton.process_status = 'INPROCESS'
               AND carton.request_id = pn_parent_req_id;

        IF ln_carton_cnt = 0
        THEN
            BEGIN
                update_error_records (
                    pv_errbuf          => lv_errbuf,
                    pv_retcode         => lv_retcode,
                    pv_shipment_no     => pv_shipment_no,
                    pv_delivery_no     => pv_delivery_no,
                    pv_carton_no       => NULL,
                    pv_line_no         => NULL,
                    pv_item_number     => NULL,
                    pv_error_level     => 'DELIVERY',
                    pv_error_message   => 'No Cartons are sent from WMS',
                    pv_status          => 'ERROR',
                    pv_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (fnd_file.LOG,
                                   'No Cartons are sent from WMS');
                pv_retcode   := '2';
                pv_errbuf    := 'No Cartons are sent from WMS';
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            RETURN FALSE;                                  --Exit the delivery
        ELSE
            SELECT COUNT (1)
              INTO ln_carton_exists
              FROM xxdo_ont_ship_conf_carton_stg carton, wms_license_plate_numbers wlpn
             WHERE     1 = 1
                   AND carton.shipment_number = pv_shipment_no
                   AND carton.order_number = pv_delivery_no
                   AND carton.process_status = 'INPROCESS'
                   AND carton.request_id = pn_parent_req_id
                   AND wlpn.license_plate_number = carton.carton_number
                   AND wlpn.organization_id = gn_inv_org_id;

            IF ln_carton_exists > 0
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'DELIVERY',
                        pv_error_message   =>
                            'Carton Number already exists in EBS',
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    fnd_file.put_line (fnd_file.LOG,
                                       'Carton Number already exists in EBS');
                    pv_retcode   := '2';
                    pv_errbuf    := 'Carton Number already exists in EBS';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;

                RETURN FALSE;
            ELSE
                RETURN TRUE;
            END IF;
        END IF;                                         --ln_carton_cnt end if
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in CHECK_CARTON_EXISTS function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            RETURN FALSE;
    END check_carton_exists;

    -- ***************************************************************************
    -- Function Name      : get_ebs_line_qty
    -- Description        : This function is to calculate the line qty and return it
    -- Parameters         : pv_shipment_no     IN  : Shipment Number
    --                      pv_delivery_no     IN  : Delivery Number
    --                      pv_line_number     IN  : Line Number
    --                      pn_parent_req_id   IN  : Request ID
    --                      pv_errbuf         OUT : Return Message
    --                      pv_retcode        OUT : Return Status
    -- Return             : NUMBER
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/06    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION get_ebs_line_qty (pv_shipment_no IN VARCHAR2, pv_delivery_no IN VARCHAR2, pv_line_number IN VARCHAR2
                               , pn_parent_req_id IN NUMBER, pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2)
        RETURN NUMBER
    IS
        ln_line_delv_qty      NUMBER := 0;
        ln_line_split_qty     NUMBER := 0;
        ln_line_total_qty     NUMBER := 0;
        ln_ship_qty_err_cnt   NUMBER := 0;
        lv_errbuf             VARCHAR2 (4000) := NULL;
        lv_retcode            VARCHAR2 (1) := '0';
    BEGIN
        ln_line_delv_qty    := 0;

        BEGIN
            SELECT SUM (wdd.requested_quantity) delv_qty
              INTO ln_line_delv_qty
              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
             WHERE     1 = 1
                   AND wnd.NAME = pv_delivery_no
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.released_status IN ('S', 'Y')
                   AND wdd.source_line_id = TO_NUMBER (pv_line_number);
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_line_delv_qty   := 0;
        END;

        --Get Split line qty
        ln_line_split_qty   := 0;
        --Line Split Qty is not required. Commented on 10Jul2019
        --      BEGIN
        --         SELECT NVL (SUM (wdd.requested_quantity), 0) delv_qty
        --           INTO ln_line_split_qty
        --           FROM wsh_new_deliveries wnd,
        --                wsh_delivery_assignments wda,
        --                wsh_delivery_details wdd
        --          WHERE     1 = 1
        --                AND wnd.name = pv_delivery_no
        --                AND wnd.delivery_id = wda.delivery_id
        --                AND wda.delivery_detail_id = wdd.delivery_detail_id
        --                AND wdd.source_code = 'OE'
        --                AND wdd.released_status IN ('S', 'Y')
        --                AND wdd.source_line_id =
        --                       (SELECT line_id
        --                          FROM oe_order_lines_all
        --                         WHERE     split_from_line_id =
        --                                      TO_NUMBER (pv_line_number)
        --                               AND header_id = wdd.source_header_id);
        --      EXCEPTION
        --         WHEN OTHERS
        --         THEN
        --            ln_line_split_qty := 0;
        --      END;
        ln_line_total_qty   := ln_line_delv_qty + ln_line_split_qty;
        RETURN ln_line_total_qty;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Exception in GET_EBS_LINE_QTY function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM);
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Exception in GET_EBS_LINE_QTY function for delivery: '
                || pv_delivery_no
                || '. Error is:'
                || SQLERRM;
            RETURN 0;
    END get_ebs_line_qty;

    PROCEDURE update_ids (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2, pv_delivery_no IN VARCHAR2, pn_parent_req_id IN NUMBER, pn_header_id IN NUMBER
                          , pn_delivery_id IN NUMBER, pn_ship_to_org_id IN NUMBER, pn_ship_to_location_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
    BEGIN
        BEGIN
            UPDATE xxdo_ont_ship_conf_order_stg
               SET order_header_id = pn_header_id, delivery_id = pn_delivery_id, ship_to_org_id = pn_ship_to_org_id,
                   ship_to_location_id = pn_ship_to_location_id, last_update_date = SYSDATE, last_updated_by = gn_user_id
             WHERE     shipment_number = pv_shipment_no
                   AND order_number = pv_delivery_no
                   AND process_status = 'INPROCESS'
                   AND request_id = pn_parent_req_id;

            pv_errbuf    := NULL;
            pv_retcode   := '0';
        EXCEPTION
            WHEN OTHERS
            THEN
                pv_errbuf    :=
                       'Unexpected error while updating delivery details on the staging table:'
                    || SQLERRM;
                pv_retcode   := '2';
        END;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            COMMIT;
            pv_errbuf    :=
                   'Unexpected error while updating delivery details on the staging table:'
                || SQLERRM;
            pv_retcode   := '2';
    END update_ids;

    -- ***************************************************************************
    -- Procedure Name      :  delivery_thread
    --
    -- Description         :  This procedure is to process the delivery - create delivery, assign/unassign delivery details, split delivery detail
    --                              create cartons and update freight charges
    --
    -- Parameters          :  pv_errbuf           OUT : Error message
    --                        pv_retcode          OUT : Execution status
    --                        pv_shipment_no       IN  : Shipment Number
    --                        pv_delivery_no       IN  : Delivery Number
    --                        pn_trip_id           IN  : Trip id
    --                        pv_carrier           IN  : Carrier
    --                        pn_parent_req_id     IN  : Parent - Main Thread - Request Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/02    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE delivery_thread (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2, pv_delivery_no IN VARCHAR2, pn_trip_id IN NUMBER, pv_carrier IN VARCHAR2
                               , pn_parent_req_id IN NUMBER)
    IS
        CURSOR cur_order_holds (pn_header_id IN NUMBER)
        IS
            SELECT header_id, hold_id
              FROM oe_order_holds_all ooha, oe_hold_sources_all ohsa
             WHERE     ooha.released_flag = 'N'
                   AND ooha.hold_source_id = ohsa.hold_source_id
                   AND ooha.header_id = pn_header_id;

        CURSOR cur_unassign_dels (p_num_api_delivery_id IN NUMBER)
        IS
            SELECT wdd.delivery_detail_id
              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda
             WHERE     wdd.released_status = 'Y'
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.delivery_id = p_num_api_delivery_id
                   AND wdd.shipped_quantity = 0;

        --Get the distinct item
        CURSOR validate_item_cur IS
              SELECT carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.item_number
                FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
               WHERE     1 = 1
                     AND carton_dtl.process_status = 'INPROCESS'
                     AND carton_dtl.shipment_number = pv_shipment_no
                     AND carton_dtl.order_number = pv_delivery_no
                     AND carton_dtl.request_id = pn_parent_req_id
            GROUP BY carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.item_number;

        --Get the distinct order line
        CURSOR validate_ord_line_cur IS
              SELECT carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.line_number
                FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
               WHERE     1 = 1
                     AND carton_dtl.process_status = 'INPROCESS'
                     AND carton_dtl.shipment_number = pv_shipment_no
                     AND carton_dtl.order_number = pv_delivery_no
                     AND carton_dtl.request_id = pn_parent_req_id
            GROUP BY carton_dtl.shipment_number, carton_dtl.order_number, carton_dtl.wh_id,
                     carton_dtl.line_number;

        --To identify the sales orders for which ship set has to be removed
        CURSOR cur_ship_set_orders IS
            SELECT DISTINCT wnd.source_header_id header_id
              FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd
             WHERE     1 = 1
                   AND s.shipment_number = pv_shipment_no
                   AND s.order_number = pv_delivery_no
                   AND s.request_id = pn_parent_req_id
                   AND s.order_number = wnd.delivery_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all ool
                             WHERE     1 = 1
                                   AND ool.header_id = wnd.source_header_id
                                   AND ool.ship_set_id IS NOT NULL);

        --Get the sales order header id for which the holds are to be released for this delivery
        CURSOR cur_order_header_id (pv_delivery_number IN VARCHAR2)
        IS
            SELECT DISTINCT wdd.source_header_id
              FROM wsh_new_deliveries wnd, wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     1 = 1
                   AND wnd.NAME = pv_delivery_number
                   AND wnd.status_code = 'OP'
                   AND wnd.organization_id = gn_inv_org_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.organization_id = gn_inv_org_id
                   AND wdd.source_code = 'OE';

        lv_errbuf                      VARCHAR2 (2000) := NULL;
        lv_retcode                     VARCHAR2 (30) := '0';
        ln_index                       NUMBER := 0;
        ln_new_delivery_id             NUMBER;
        ln_new_del_detail_id           NUMBER := 0;
        ln_container_id                NUMBER;
        l_undership_del_dtl_ids_tab    tabtype_id;
        l_partial_del_dtl_ids_tab      tabtype_id;
        l_cur_shipments_tab            g_shipments_tab_type;
        l_ex_bulk_fetch_failed         EXCEPTION;
        lb_delv_exists                 BOOLEAN := TRUE;
        lb_delv_is_open                BOOLEAN := TRUE;
        lb_valid_ship_to               BOOLEAN := TRUE;
        lb_delv_det_exists             BOOLEAN := TRUE;
        lb_item_validation             BOOLEAN := TRUE;
        lb_ord_line_validation         BOOLEAN := TRUE;
        lb_line_assigned_to_delv       BOOLEAN := TRUE;
        lb_over_ship_delv              BOOLEAN := TRUE;
        lb_ship_qty_zero               BOOLEAN := TRUE;
        lb_carton_validation           BOOLEAN := TRUE;
        ln_carton_err_cnt              NUMBER := 0;
        ln_ord_line_exists             NUMBER := 0;
        ln_ord_line_err_cnt            NUMBER := 0;
        ln_ord_line_assigned_err_cnt   NUMBER := 0;
        ln_ship_set_exists_cnt         NUMBER := 0;
        ln_ebs_line_qty                NUMBER := 0;
        ln_ebs_line_qty_err_cnt        NUMBER := 0;
        ln_cumu_delv_det_qty           NUMBER := 0;
        ln_diff_qty                    NUMBER := 0;
        lv_ebs_qty_met_ship_qty        VARCHAR2 (1);
        lv_new_delivery_created        VARCHAR2 (1);
        ln_order_header_id             NUMBER := 0;
        ln_del_det_split_err_cnt       NUMBER := 0;
        ln_delivery_id                 NUMBER := 0;
        ln_header_id                   NUMBER := 0;
        ln_ship_to_location_id         NUMBER := 0;
        ln_ship_to_org_id              NUMBER := 0;
        ln_organization_id             NUMBER := 0;
        l_hold_source_tbl              g_hold_source_tbl_type;
        l_all_hold_source_tbl          g_hold_source_tbl_type;
        l_subinv_xfer_tab              g_subinv_xfer_tbl_type;
    BEGIN
        pv_errbuf                 := NULL;
        pv_retcode                := '0';
        fnd_file.put_line (
            fnd_file.LOG,
               'Processing started for Shipment Number : '
            || pv_shipment_no
            || ' Delivery Number: '
            || pv_delivery_no);
        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Validate delivery details - START
        lb_delv_det_exists        :=
            validate_delivery (pv_shipment_no => pv_shipment_no, pv_delivery_no => pv_delivery_no, pv_errbuf => lv_errbuf
                               , pv_retcode => lv_retcode);

        IF NOT lb_delv_det_exists
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Validate delivery details - END

        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Validate whether ship to location is NULL/INVALID - START
        lb_valid_ship_to          :=
            check_valid_ship_to (pv_shipment_no => pv_shipment_no, pv_delivery_no => pv_delivery_no, pv_errbuf => lv_errbuf
                                 , pv_retcode => lv_retcode);

        IF NOT lb_valid_ship_to
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Validate whether ship to location is NULL/INVALID - END

        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Carton validation(Cartons exists or not for the delivery and if exists does the carton already exists in wms_license_plate_numbers)- START
        lb_carton_validation      :=
            check_carton_exists (pv_shipment_no     => pv_shipment_no,
                                 pv_delivery_no     => pv_delivery_no,
                                 pn_parent_req_id   => pn_parent_req_id,
                                 pv_errbuf          => lv_errbuf,
                                 pv_retcode         => lv_retcode);

        IF NOT lb_carton_validation
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Carton validation(Cartons exists or not for the delivery and if exists does the carton already exists in wms_license_plate_numbers)- END

        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Validate Items - START
        lb_item_validation        :=
            check_item_exists (pv_shipment_no     => pv_shipment_no,
                               pv_delivery_no     => pv_delivery_no,
                               pn_parent_req_id   => pn_parent_req_id,
                               pv_errbuf          => lv_errbuf,
                               pv_retcode         => lv_retcode);

        IF NOT lb_item_validation
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Validate Items - END

        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Validate Order Line ID - START
        lb_ord_line_validation    :=
            check_ord_line_exists (pv_shipment_no     => pv_shipment_no,
                                   pv_delivery_no     => pv_delivery_no,
                                   pn_parent_req_id   => pn_parent_req_id,
                                   pv_errbuf          => lv_errbuf,
                                   pv_retcode         => lv_retcode);

        IF NOT lb_ord_line_validation
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Validate Order Line ID - END

        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Validate Shipment Qty = 0 Scenario - START
        lb_ship_qty_zero          :=
            check_ship_qty_zero (pv_shipment_no     => pv_shipment_no,
                                 pv_delivery_no     => pv_delivery_no,
                                 pn_parent_req_id   => pn_parent_req_id,
                                 pv_errbuf          => lv_errbuf,
                                 pv_retcode         => lv_retcode);

        IF NOT lb_ship_qty_zero
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Validate Shipment Qty = 0 Scenario - END

        --Reset Variables
        lv_errbuf                 := NULL;
        lv_retcode                := '0';
        --Validate Over Shipment Scenario - START
        lb_over_ship_delv         :=
            check_over_ship_delv (pv_shipment_no     => pv_shipment_no,
                                  pv_delivery_no     => pv_delivery_no,
                                  pn_parent_req_id   => pn_parent_req_id,
                                  pv_errbuf          => lv_errbuf,
                                  pv_retcode         => lv_retcode);

        IF NOT lb_over_ship_delv
        THEN
            pv_retcode   := lv_retcode;
            pv_errbuf    := lv_errbuf;
            RETURN;                                        --Exit the delivery
        END IF;

        --Validate Over Shipment Scenario - END

        --Post Validation Steps --START

        --Remove Ship Sets on Order lines and delivery --START
        --Check if ship sets exists for the delivery
        SELECT COUNT (1)
          INTO ln_ship_set_exists_cnt
          FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd
         WHERE     1 = 1
               AND s.process_status = 'INPROCESS'
               AND s.shipment_number = pv_shipment_no
               AND s.order_number = pv_delivery_no
               AND s.request_id = pn_parent_req_id
               AND s.order_number = wnd.NAME
               AND wnd.organization_id = gn_inv_org_id
               AND wnd.status_code = 'OP'
               AND EXISTS
                       (SELECT 1
                          FROM apps.oe_order_lines_all ool
                         WHERE     1 = 1
                               AND ool.header_id = wnd.source_header_id
                               AND ool.ship_set_id IS NOT NULL);

        lv_errbuf                 := NULL;
        lv_retcode                := '0';

        IF ln_ship_set_exists_cnt > 0
        THEN
            remove_ship_set (pv_shipment_no     => pv_shipment_no,
                             pv_delivery_no     => pv_delivery_no,
                             pn_parent_req_id   => pn_parent_req_id,
                             pv_ret_sts         => lv_retcode,
                             pv_ret_msg         => lv_errbuf);

            --If ship set removal is successful then only commit else rollback and exit the delivery
            IF lv_retcode <> '0'
            THEN
                --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'DELIVERY',
                        pv_error_message   => 'Ship Set Removal failed',
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    fnd_file.put_line (fnd_file.LOG,
                                       'Ship Set Removal failed in EBS');
                    pv_retcode   := '2';
                    pv_errbuf    := 'Ship Set Removal failed in EBS';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;

                ROLLBACK;                                -- Roll back ship set
                pv_errbuf    :=
                    SUBSTR (
                        'Error in removing Ship set. Error is:' || lv_errbuf,
                        1,
                        2000);
                pv_retcode   := '2';
                RETURN;                                    --Exit the delivery
            END IF;
        END IF;

        --Remove Ship Sets on Order lines and delivery --END
        lv_errbuf                 := NULL;
        lv_retcode                := '0';

        --Release the holds for the delivery --START
        FOR order_header_id_rec IN cur_order_header_id (pv_delivery_no)
        LOOP
            IF l_hold_source_tbl.EXISTS (1)
            THEN
                l_hold_source_tbl.DELETE;
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Invoking the release hold procedure for the delivery : '
                || pv_delivery_no);

            BEGIN
                release_holds (
                    pv_errbuf              => lv_errbuf,
                    pv_retcode             => lv_retcode,
                    p_io_hold_source_tbl   => l_hold_source_tbl,
                    pn_header_id           =>
                        order_header_id_rec.source_header_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error invoking the hold release procedure : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            END;

            -- If hold release is not successful, update the delivery record with error, don't launch the delivery thread
            IF lv_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'DELIVERY',
                        pv_error_message   =>
                            'Hold release failed :  ' || lv_errbuf,
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Hold release failed. Erroring the delivery : '
                        || pv_delivery_no);
                    pv_retcode   := '2';
                    pv_errbuf    :=
                        'Hold release failed. Please refer the log file for more details';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;

                ROLLBACK;
                --if any issues in releasing atleast one hold for the order, then ROLLBACK the holds which are released and exit the delivery
                RETURN;                                    --Exit the delivery
            ELSE
                -- hold release is successful - copy the hold sources into Global hold sources table to reapply the hold later at Shipment level
                IF l_hold_source_tbl.EXISTS (1)
                THEN
                    FOR l_num_hold_index IN 1 .. l_hold_source_tbl.COUNT
                    LOOP
                        --l_all_hold_source_tbl (l_all_hold_source_tbl.COUNT + 1) := l_hold_source_tbl (l_num_hold_index);
                        g_all_hold_source_tbl (
                            g_all_hold_source_tbl.COUNT + 1)   :=
                            l_hold_source_tbl (l_num_hold_index);
                    END LOOP;
                END IF;
            END IF;
        END LOOP;

        --Release the holds for the delivery --END

        -- Splitting the Delivery Details based on container packing - START
        --Get the lines for which multiple cartons exists and split the lines accordingly
        FOR line_rec
            IN (  SELECT line_number
                    FROM xxdo.xxdo_ont_ship_conf_cardtl_stg
                   WHERE     1 = 1
                         AND process_status = 'INPROCESS'
                         AND shipment_number = pv_shipment_no
                         AND order_number = pv_delivery_no
                         AND request_id = pn_parent_req_id
                GROUP BY line_number
                  HAVING COUNT (line_number) > 1)
        LOOP
            BEGIN
                split_order_line (pv_errbuf        => lv_errbuf,
                                  pv_retcode       => lv_retcode,
                                  pv_shipment_no   => pv_shipment_no,
                                  pv_delivery_no   => pv_delivery_no,
                                  pn_order_line    => line_rec.line_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while invoking Split Order Line :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => line_rec.line_number,
                        pv_item_number     => NULL,
                        pv_error_level     => 'ORDER LINE',
                        pv_error_message   => pv_errbuf,
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    ROLLBACK;
                    RETURN;
            END;

            IF lv_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => line_rec.line_number,
                        pv_item_number     => NULL,
                        pv_error_level     => 'ORDER LINE',
                        pv_error_message   =>
                            'Unable to split the order line per containers',
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unable to split the order line per containers '
                        || line_rec.line_number;

                    IF lv_retcode <> '0'
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error while updating Error Records for Unable to split the order line per containers');
                        pv_retcode   := '2';
                        pv_errbuf    := lv_errbuf;
                    END IF;

                    ROLLBACK;
                    RETURN;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status for Unable to split the order line per containers:'
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        ROLLBACK;
                        RETURN;
                END;
            END IF;

            --Check if there are any Errors in Carton Details table for this shipment and delivery
            ln_ord_line_err_cnt   := 0;

            SELECT COUNT (1)
              INTO ln_ord_line_err_cnt
              FROM xxdo_ont_ship_conf_cardtl_stg
             WHERE     1 = 1
                   AND process_status = 'ERROR'
                   AND shipment_number = pv_shipment_no
                   AND order_number = pv_delivery_no
                   AND request_id = pn_parent_req_id;

            --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
            IF ln_ord_line_err_cnt > 0
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf        => lv_errbuf,
                        pv_retcode       => lv_retcode,
                        pv_shipment_no   => pv_shipment_no,
                        pv_delivery_no   => pv_delivery_no,
                        pv_carton_no     => NULL,
                        pv_line_no       => NULL,
                        pv_item_number   => NULL,
                        pv_error_level   => 'DELIVERY',
                        pv_error_message   =>
                            'Unable to split one or more order lines per container',
                        pv_status        => 'ERROR',
                        pv_source        => 'DELIVERY_THREAD');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Unable to split one or more order lines per container');
                    pv_retcode   := '2';
                    pv_errbuf    :=
                        'Unable to split one or more order lines per container';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;
            END IF;
        END LOOP;

        -- Splitting the Delivery Details based on container packing - END

        --Reset variables
        lv_retcode                := NULL;
        lv_errbuf                 := NULL;
        --Partial Pick(Line Quantity Partially Picked) - START
        lv_new_delivery_created   := 'N';

        --Getting shipment qty by line
        FOR line_rec
            IN (  SELECT shipment_number, order_number, line_number,
                         SUM (qty) ship_line_qty
                    FROM xxdo_ont_ship_conf_cardtl_stg
                   WHERE     1 = 1
                         AND process_status = 'INPROCESS'
                         AND shipment_number = pv_shipment_no
                         AND order_number = pv_delivery_no
                         AND request_id = pn_parent_req_id
                GROUP BY shipment_number, order_number, line_number)
        LOOP
            BEGIN
                  SELECT header_id
                    INTO ln_order_header_id
                    FROM oe_order_lines_all
                   WHERE 1 = 1 AND line_id = TO_NUMBER (line_rec.line_number)
                GROUP BY header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_order_header_id   := 0;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unable to derive Order header ID for line ID : '
                        || line_rec.line_number);
            END;

            lv_ebs_qty_met_ship_qty   := 'N';
            ln_ebs_line_qty           :=
                get_ebs_line_qty (pv_shipment_no     => pv_shipment_no,
                                  pv_delivery_no     => pv_delivery_no,
                                  pv_line_number     => line_rec.line_number,
                                  pn_parent_req_id   => pn_parent_req_id,
                                  pv_errbuf          => lv_errbuf,
                                  pv_retcode         => lv_retcode);
            fnd_file.put_line (
                fnd_file.LOG,
                   'EBS Line ID: '
                || line_rec.line_number
                || ' and Qty: '
                || ln_ebs_line_qty);

            IF ln_ebs_line_qty <= 0
            THEN
                --Update the staging tables with qty error
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => line_rec.line_number,
                        pv_item_number     => NULL,
                        pv_error_level     => 'ORDER LINE',
                        pv_error_message   =>
                            'EBS line has zero Qty :  ' || lv_errbuf,
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'EBS line ID:'
                        || line_rec.line_number
                        || ' has zero Qty');
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'EBS line ID:'
                        || line_rec.line_number
                        || ' has zero Qty or Error:'
                        || lv_errbuf;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                END;

                RETURN;                                    --Exit the delivery
            END IF;

            --Under shipment scenario
            IF line_rec.ship_line_qty < ln_ebs_line_qty
            THEN
                ln_cumu_delv_det_qty   := 0;
                ln_index               := 1;

                --Get the delivery detail qty
                FOR delv_det_rec
                    IN (  SELECT wdd.delivery_detail_id, wdd.requested_quantity delv_det_qty, DECODE (wdd.split_from_delivery_detail_id, NULL, 9999999999, wdd.requested_quantity) order_seq --Added for CCR0009784
                            FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
                           WHERE     1 = 1
                                 AND wnd.NAME = pv_delivery_no
                                 AND wnd.delivery_id = wda.delivery_id
                                 AND wda.delivery_detail_id =
                                     wdd.delivery_detail_id
                                 AND wdd.source_code = 'OE'
                                 AND wdd.released_status IN ('S', 'Y')
                                 AND wdd.source_line_id =
                                     TO_NUMBER (line_rec.line_number)
                        -- Not required to consider split line qty. Commented on 10Jul2019
                        --                   UNION
                        --                   SELECT wdd.delivery_detail_id,
                        --                          wdd.requested_quantity delv_det_qty
                        --                     FROM wsh_new_deliveries wnd,
                        --                          wsh_delivery_assignments wda,
                        --                          wsh_delivery_details wdd
                        --                    WHERE     1 = 1
                        --                          AND wnd.name = pv_delivery_no
                        --                          AND wnd.delivery_id = wda.delivery_id
                        --                          AND wda.delivery_detail_id = wdd.delivery_detail_id
                        --                          AND wdd.source_code = 'OE'
                        --                          AND wdd.released_status IN ('S', 'Y') --S=Released to Warehouse, Y=Staged/Pick Confirmed
                        --                          AND wdd.source_line_id =
                        --                                 (SELECT line_id
                        --                                    FROM oe_order_lines_all
                        --                                   WHERE     1 = 1
                        --                                         AND split_from_line_id =
                        --                                                TO_NUMBER (
                        --                                                   line_rec.line_number)
                        --                                         AND header_id =
                        --                                                NVL (ln_order_header_id,
                        --                                                     wdd.source_header_id))
                        ORDER BY order_seq, delv_det_qty)
                LOOP
                    ln_cumu_delv_det_qty   :=
                        ln_cumu_delv_det_qty + delv_det_rec.delv_det_qty;

                    --               Check if the cumulative delivery detail qty meets the line shipment quantity
                    IF line_rec.ship_line_qty = ln_cumu_delv_det_qty
                    THEN
                        --set qty met variable to Yes
                        lv_ebs_qty_met_ship_qty   := 'Y';
                    ELSIF line_rec.ship_line_qty < ln_cumu_delv_det_qty
                    THEN
                        IF lv_new_delivery_created = 'N'
                        THEN
                            --create delivery
                            BEGIN
                                lv_errbuf    := NULL;
                                lv_retcode   := NULL;
                                --create a new delivery
                                create_delivery (pv_delivery_no => pv_delivery_no, xn_delivery_id => ln_new_delivery_id, pv_errbuf => lv_errbuf
                                                 , pv_retcode => lv_retcode);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'New Delivery created: '
                                    || ln_new_delivery_id);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                           'Unexpected Error while invoking creating delivery procedure :'
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       pv_errbuf);
                                    lv_errbuf    := NULL;
                                    lv_retcode   := NULL;
                                    update_error_records (
                                        pv_errbuf          => lv_errbuf,
                                        pv_retcode         => lv_retcode,
                                        pv_shipment_no     => pv_shipment_no,
                                        pv_delivery_no     => pv_delivery_no,
                                        pv_carton_no       => NULL,
                                        pv_line_no         => NULL,
                                        pv_item_number     => NULL,
                                        pv_error_level     => 'DELIVERY',
                                        pv_error_message   => pv_errbuf,
                                        pv_status          => 'ERROR',
                                        pv_source          =>
                                            'DELIVERY_THREAD');
                                    ROLLBACK;                          --Added
                                    RETURN;                --Exit the delivery
                            END;

                            IF lv_retcode <> '0'
                            THEN
                                BEGIN
                                    update_error_records (
                                        pv_errbuf        => lv_errbuf,
                                        pv_retcode       => lv_retcode,
                                        pv_shipment_no   => pv_shipment_no,
                                        pv_delivery_no   => pv_delivery_no,
                                        pv_carton_no     => NULL,
                                        pv_line_no       => NULL,
                                        pv_item_number   => NULL,
                                        pv_error_level   => 'DELIVERY',
                                        pv_error_message   =>
                                            'Unable to create new delivery',
                                        pv_status        => 'ERROR',
                                        pv_source        => 'DELIVERY_THREAD');
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                        'Unable to create new delivery';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        pv_retcode   := '2';
                                        pv_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || lv_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           pv_errbuf);
                                END;

                                ROLLBACK;                              --Added
                                RETURN;                    --Exit the delivery
                            ELSE
                                --if successful, set lv_new_delivery_created to Yes
                                lv_new_delivery_created   := 'Y';
                            END IF; --lv_retcode--create delivery status end if
                        END IF;               --lv_new_delivery_created end if

                        IF lv_ebs_qty_met_ship_qty = 'N'
                        THEN
                            --Get the difference Quantity
                            ln_diff_qty                       :=
                                ln_cumu_delv_det_qty - line_rec.ship_line_qty;
                            --Split the delivery detail
                            --split_delivery_detail(del_det_id, split_qty, return_new_del_det_id)
                            lv_errbuf                         := NULL;
                            lv_retcode                        := NULL;

                            IF delv_det_rec.delv_det_qty > ln_diff_qty
                            THEN
                                BEGIN
                                    split_delivery_detail (
                                        pv_errbuf          => lv_errbuf,
                                        pv_retcode         => lv_retcode,
                                        pn_delivery_detail_id   =>
                                            delv_det_rec.delivery_detail_id,
                                        --ln_split_from_del_id,
                                        pn_split_quantity   =>
                                              delv_det_rec.delv_det_qty
                                            - ln_diff_qty,
                                        --ln_split_qty,
                                        pv_delivery_name   => pv_delivery_no,
                                        xn_delivery_detail_id   =>
                                            ln_new_del_detail_id);
                                    --If delivery split failed, then update the staging table --START
                                    --Update the carton detail stg table with error and error message
                                    --Also mark the delivery as 'Error' with error message as "Line Split failed"
                                    --Rollback and exit the delivery
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'New Delivery Detail ID created: '
                                        || ln_new_del_detail_id);
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        pv_retcode   := '2';
                                        pv_errbuf    :=
                                               'Unexpected Error while invoking split_delivery_detail procedure :'
                                            || SQLERRM;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           pv_errbuf);
                                        lv_errbuf    := NULL;
                                        lv_retcode   := NULL;
                                        update_error_records (
                                            pv_errbuf          => lv_errbuf,
                                            pv_retcode         => lv_retcode,
                                            pv_shipment_no     => pv_shipment_no,
                                            pv_delivery_no     => pv_delivery_no,
                                            pv_carton_no       => NULL,
                                            pv_line_no         => NULL,
                                            pv_item_number     => NULL,
                                            pv_error_level     => 'DELIVERY',
                                            pv_error_message   => pv_errbuf,
                                            pv_status          => 'ERROR',
                                            pv_source          =>
                                                'DELIVERY_THREAD');
                                        ROLLBACK;                      --Added
                                        RETURN;            --Exit the delivery
                                END;

                                IF lv_retcode <> '0'
                                THEN
                                    BEGIN
                                        update_error_records (
                                            pv_errbuf        => lv_errbuf,
                                            pv_retcode       => lv_retcode,
                                            pv_shipment_no   => pv_shipment_no,
                                            pv_delivery_no   => pv_delivery_no,
                                            pv_carton_no     =>
                                                line_rec.line_number,
                                            pv_line_no       => NULL,
                                            pv_item_number   => NULL,
                                            pv_error_level   => 'CARTON',
                                            pv_error_message   =>
                                                'Unable to split delivery detail',
                                            pv_status        => 'ERROR',
                                            pv_source        =>
                                                'DELIVERY_THREAD');
                                        pv_retcode   := '2';
                                        pv_errbuf    :=
                                            'Unable to create new delivery';
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            pv_retcode   := '2';
                                            pv_errbuf    :=
                                                   'Unexpected Error while updating error status :'
                                                || lv_errbuf;
                                            fnd_file.put_line (fnd_file.LOG,
                                                               pv_errbuf);
                                    END;

                                    ROLLBACK;                          --Added
                                    RETURN;                --Exit the delivery
                                END IF;
                            END IF;

                            --Check if there are any Errors in Carton Details table for this shipment and delivery
                            ln_del_det_split_err_cnt          := 0;

                            SELECT COUNT (1)
                              INTO ln_del_det_split_err_cnt
                              FROM xxdo_ont_ship_conf_cardtl_stg
                             WHERE     1 = 1
                                   AND process_status = 'ERROR'
                                   AND shipment_number = pv_shipment_no
                                   AND order_number = pv_delivery_no
                                   AND request_id = pn_parent_req_id;

                            --If Errors exists then update all the staging tables for this delivery to error and update delivery staging table error message
                            IF ln_del_det_split_err_cnt > 0
                            THEN
                                BEGIN
                                    update_error_records (
                                        pv_errbuf        => lv_errbuf,
                                        pv_retcode       => lv_retcode,
                                        pv_shipment_no   => pv_shipment_no,
                                        pv_delivery_no   => pv_delivery_no,
                                        pv_carton_no     => NULL,
                                        pv_line_no       => NULL,
                                        pv_item_number   => NULL,
                                        pv_error_level   => 'DELIVERY',
                                        pv_error_message   =>
                                            'One or more lines delivery detail split failed',
                                        pv_status        => 'ERROR',
                                        pv_source        => 'DELIVERY_THREAD');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'One or more lines in the delivery are not assigned in EBS');
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                        'One or more lines in the delivery are not assigned in EBS';
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        pv_retcode   := '2';
                                        pv_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || lv_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           pv_errbuf);
                                END;

                                ROLLBACK;                              --Added
                                RETURN;
                            END IF;

                            --If delivery split failed, then update the staging table --END

                            --Assign newly split delivery detail id that is created, to new delivery
                            l_undership_del_dtl_ids_tab (1)   :=
                                ln_new_del_detail_id;

                            --delv_det_rec.delivery_detail_id;

                            -- Un assigning the new delivery detail from the existing delivery
                            BEGIN
                                assign_detail_to_delivery (
                                    pv_errbuf               => lv_errbuf,
                                    pv_retcode              => lv_retcode,
                                    pn_delivery_id          => pv_delivery_no,
                                    pv_delivery_name        => NULL,
                                    p_delivery_detail_ids   =>
                                        l_undership_del_dtl_ids_tab,
                                    pv_action               => 'UNASSIGN');
                            --                        fnd_file.put_line (
                            --                           fnd_file.LOG,
                            --                              'Delivery Detail UnAssignment status: '
                            --                           || lv_retcode);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                           'Unexpected Error while invoking assign_detail_to_delivery procedure :'
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       pv_errbuf);
                                    update_error_records (
                                        pv_errbuf          => lv_errbuf,
                                        pv_retcode         => lv_retcode,
                                        pv_shipment_no     => pv_shipment_no,
                                        pv_delivery_no     => pv_delivery_no,
                                        pv_carton_no       => NULL,
                                        pv_line_no         => NULL,
                                        pv_item_number     => NULL,
                                        pv_error_level     => 'DELIVERY',
                                        pv_error_message   => pv_errbuf,
                                        pv_status          => 'ERROR',
                                        pv_source          =>
                                            'DELIVERY_THREAD');
                                    ROLLBACK;                          --Added
                                    RETURN;                --Exit the delivery
                            END;

                            IF lv_retcode <> '0'
                            THEN
                                BEGIN
                                    update_error_records (
                                        pv_errbuf        => lv_errbuf,
                                        pv_retcode       => lv_retcode,
                                        pv_shipment_no   => pv_shipment_no,
                                        pv_delivery_no   => pv_delivery_no,
                                        pv_carton_no     => NULL,
                                        pv_line_no       => NULL,
                                        pv_item_number   => NULL,
                                        pv_error_level   => 'DELIVERY',
                                        pv_error_message   =>
                                            'Unable to assign the split delivery detail to new delivery',
                                        pv_status        => 'ERROR',
                                        pv_source        => 'DELIVERY_THREAD');
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                        'Unable to assign the split delivery detail to new delivery';
                                    ROLLBACK;                          --Added
                                    RETURN;                --Exit the delivery
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        pv_retcode   := '2';
                                        pv_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || lv_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           pv_errbuf);
                                        ROLLBACK;                      --Added
                                        RETURN;            --Exit the delivery
                                END;
                            END IF;

                            BEGIN
                                assign_detail_to_delivery (
                                    pv_errbuf               => lv_errbuf,
                                    pv_retcode              => lv_retcode,
                                    pn_delivery_id          => ln_new_delivery_id,
                                    pv_delivery_name        => NULL,
                                    p_delivery_detail_ids   =>
                                        l_undership_del_dtl_ids_tab,
                                    pv_action               => 'ASSIGN');
                            --                        fnd_file.put_line (
                            --                           fnd_file.LOG,
                            --                              'Delivery Detail Assignment status: '
                            --                           || lv_retcode);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                           'Unexpected Error while invoking assign_detail_to_delivery procedure :'
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       pv_errbuf);
                                    update_error_records (
                                        pv_errbuf          => lv_errbuf,
                                        pv_retcode         => lv_retcode,
                                        pv_shipment_no     => pv_shipment_no,
                                        pv_delivery_no     => pv_delivery_no,
                                        pv_carton_no       => NULL,
                                        pv_line_no         => NULL,
                                        pv_item_number     => NULL,
                                        pv_error_level     => 'DELIVERY',
                                        pv_error_message   => pv_errbuf,
                                        pv_status          => 'ERROR',
                                        pv_source          =>
                                            'DELIVERY_THREAD');
                                    ROLLBACK;                          --Added
                                    RETURN;                --Exit the delivery
                            END;

                            IF lv_retcode <> '0'
                            THEN
                                BEGIN
                                    update_error_records (
                                        pv_errbuf        => lv_errbuf,
                                        pv_retcode       => lv_retcode,
                                        pv_shipment_no   => pv_shipment_no,
                                        pv_delivery_no   => pv_delivery_no,
                                        pv_carton_no     => NULL,
                                        pv_line_no       => NULL,
                                        pv_item_number   => NULL,
                                        pv_error_level   => 'DELIVERY',
                                        pv_error_message   =>
                                            'Unable to assign the split delivery detail to new delivery',
                                        pv_status        => 'ERROR',
                                        pv_source        => 'DELIVERY_THREAD');
                                    pv_retcode   := '2';
                                    pv_errbuf    :=
                                        'Unable to assign the split delivery detail to new delivery';
                                    ROLLBACK;                          --Added
                                    RETURN;                --Exit the delivery
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        pv_retcode   := '2';
                                        pv_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || lv_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           pv_errbuf);
                                        ROLLBACK;                      --Added
                                        RETURN;            --Exit the delivery
                                END;
                            END IF;

                            --Removing the split delivery detail id from the table type after assigning it to new delivery
                            IF l_undership_del_dtl_ids_tab.EXISTS (1)
                            THEN
                                l_undership_del_dtl_ids_tab.DELETE;
                            END IF;

                            --Also set the lv_ebs_qty_met_ship_qty to yes
                            lv_ebs_qty_met_ship_qty           := 'Y';
                        ELSE
                            --UnAssign delivery detail and assign to new delivery
                            --Assign the delivery detail ID's that needs to be UNASSIGNED from existing delivery and then ASSIGNED to thet NEW Delivery to the table type
                            l_undership_del_dtl_ids_tab (ln_index)   :=
                                delv_det_rec.delivery_detail_id;
                            ln_index   := ln_index + 1;
                        END IF;
                    END IF; --line_ship qty and cumulative del det qty comparisons
                END LOOP;                              --delv_det_rec end loop

                --Now unassign and assign the delivery detail id's that are assigned to l_undership_del_dtl_ids_tab table type
                IF l_undership_del_dtl_ids_tab.EXISTS (1)
                THEN
                    BEGIN
                        lv_errbuf    := NULL;
                        lv_retcode   := NULL;
                        assign_detail_to_delivery (
                            pv_errbuf               => lv_errbuf,
                            pv_retcode              => lv_retcode,
                            pn_delivery_id          => TO_NUMBER (pv_delivery_no),
                            pv_delivery_name        => pv_delivery_no,
                            p_delivery_detail_ids   =>
                                l_undership_del_dtl_ids_tab,
                            pv_action               => 'UNASSIGN');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while invoking assign_detail_to_delivery procedure :'
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                            update_error_records (
                                pv_errbuf          => lv_errbuf,
                                pv_retcode         => lv_retcode,
                                pv_shipment_no     => pv_shipment_no,
                                pv_delivery_no     => pv_delivery_no,
                                pv_carton_no       => NULL,
                                pv_line_no         => NULL,
                                pv_item_number     => NULL,
                                pv_error_level     => 'DELIVERY',
                                pv_error_message   => pv_errbuf,
                                pv_status          => 'ERROR',
                                pv_source          => 'DELIVERY_THREAD');
                            ROLLBACK;                                  --Added
                            RETURN;                        --Exit the delivery
                    END;

                    IF lv_retcode <> '0'
                    THEN
                        BEGIN
                            update_error_records (
                                pv_errbuf        => lv_errbuf,
                                pv_retcode       => lv_retcode,
                                pv_shipment_no   => pv_shipment_no,
                                pv_delivery_no   => pv_delivery_no,
                                pv_carton_no     => NULL,
                                pv_line_no       => NULL,
                                pv_item_number   => NULL,
                                pv_error_level   => 'DELIVERY',
                                pv_error_message   =>
                                    'Unable to unassign the delivery detail to new delivery',
                                pv_status        => 'ERROR',
                                pv_source        => 'DELIVERY_THREAD');
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                'Unable to unassign the deliveries';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '2';
                                pv_errbuf    :=
                                       'Unexpected Error while updating error status :'
                                    || lv_errbuf;
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        END;

                        ROLLBACK;                                      --Added
                        RETURN;                            --Exit the delivery
                    END IF;

                    --Now assign the unassigned deliveries to the new delivery
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Assigning all the unshipped delivery details to the new delivery');
                    lv_errbuf    := NULL;
                    lv_retcode   := NULL;

                    BEGIN
                        assign_detail_to_delivery (
                            pv_errbuf               => lv_errbuf,
                            pv_retcode              => lv_retcode,
                            pn_delivery_id          => ln_new_delivery_id,
                            pv_delivery_name        => NULL,
                            p_delivery_detail_ids   =>
                                l_undership_del_dtl_ids_tab,
                            pv_action               => 'ASSIGN');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while invoking unassign delivery detail procedure :'
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                            update_error_records (
                                pv_errbuf          => lv_errbuf,
                                pv_retcode         => lv_retcode,
                                pv_shipment_no     => pv_shipment_no,
                                pv_delivery_no     => pv_delivery_no,
                                pv_carton_no       => NULL,
                                pv_line_no         => NULL,
                                pv_item_number     => NULL,
                                pv_error_level     => 'DELIVERY',
                                pv_error_message   => pv_errbuf,
                                pv_status          => 'ERROR',
                                pv_source          => 'DELIVERY_THREAD');
                            ROLLBACK;                                  --Added
                            RETURN;                        --Exit the delivery
                    END;

                    IF lv_retcode <> '0'
                    THEN
                        BEGIN
                            update_error_records (
                                pv_errbuf          => lv_errbuf,
                                pv_retcode         => lv_retcode,
                                pv_shipment_no     => pv_shipment_no,
                                pv_delivery_no     => pv_delivery_no,
                                pv_carton_no       => NULL,
                                pv_line_no         => NULL,
                                pv_item_number     => NULL,
                                pv_error_level     => 'DELIVERY',
                                pv_error_message   =>
                                    'Unable to assign the deliveries',
                                pv_status          => 'ERROR',
                                pv_source          => 'DELIVERY_THREAD');
                            pv_retcode   := '2';
                            pv_errbuf    := 'Unable to assign the deliveries';
                            ROLLBACK;                                  --Added
                            RETURN;                        --Exit the delivery
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '2';
                                pv_errbuf    :=
                                       'Unexpected Error while updating error status :'
                                    || lv_errbuf;
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                                ROLLBACK;                              --Added
                                RETURN;                    --exit the delivery
                        END;
                    END IF;
                END IF;        --l_undership_del_dtl_ids_tab.EXISTS (1) end if
            END IF;                  --Ship qty and EBS qty comparision end if
        END LOOP;                                          --line_rec loop end

        --Partial Pick(Line Quantity Partially Picked) - END

        --Partial Pick(Few Lines being Picked) - START

        --If EBS line count and Shipment staging table line count is not equal
        --then identify the line which is not in shipment staging table and unassign that line from the delivery in EBS
        --And then assign the unassigned line to a new delivery
        FOR partial_lines_rec
            IN (SELECT DISTINCT wdd.source_line_id, wdd.source_header_id
                  FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
                 WHERE     1 = 1
                       AND wnd.NAME = pv_delivery_no
                       AND wnd.status_code = 'OP'
                       AND wnd.organization_id = gn_inv_org_id
                       AND wnd.delivery_id = wda.delivery_id
                       AND wda.delivery_detail_id = wdd.delivery_detail_id
                       AND wdd.organization_id = gn_inv_org_id
                       AND wdd.source_code = 'OE'
                       AND wdd.released_status IN ('S', 'Y') --'Y' -Staged/Pick Confirmed
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxdo_ont_ship_conf_cardtl_stg
                                 WHERE     1 = 1
                                       AND process_status = 'INPROCESS'
                                       AND order_number = pv_delivery_no
                                       AND line_number =
                                           TO_CHAR (wdd.source_line_id)
                                       AND request_id = pn_parent_req_id))
        LOOP
            --Unassign the line from the delivery(Steps below).
            --Create a new delivery if not already created and unassign all the delivery details of the line from the existing delivery
            IF lv_new_delivery_created = 'N'
            THEN
                --create_new_delivery
                BEGIN
                    lv_errbuf    := NULL;
                    lv_retcode   := NULL;
                    --create a new delivery
                    create_delivery (pv_delivery_no => pv_delivery_no, xn_delivery_id => ln_new_delivery_id, pv_errbuf => lv_errbuf
                                     , pv_retcode => lv_retcode);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while invoking creating delivery procedure :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        lv_errbuf    := NULL;
                        lv_retcode   := NULL;
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => pv_delivery_no,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   => pv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                        ROLLBACK;                                      --Added
                        RETURN;                            --Exit the delivery
                END;

                IF lv_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => pv_delivery_no,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   =>
                                'Unable to create new delivery',
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                        pv_retcode   := '2';
                        pv_errbuf    := 'Unable to create new delivery';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || lv_errbuf;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;

                    ROLLBACK;                                          --Added
                    RETURN;                                --Exit the delivery
                ELSE
                    --if successful, set lv_new_delivery_created to Yes
                    lv_new_delivery_created   := 'Y';
                END IF;            --lv_retcode--create delivery status end if
            END IF;

            --Removing the split delivery detail id from the table type after assigning it to new delivery
            IF l_partial_del_dtl_ids_tab.EXISTS (1)
            THEN
                l_partial_del_dtl_ids_tab.DELETE;
            END IF;

            ln_index   := 1;

            --Get the delivery details for the line and delivery
            --unassign all the delivery details of the line from the existing delivery
            --And assign the unassigned delivery details to the newly created delivery
            FOR miss_det_rec
                IN (SELECT wdd.delivery_detail_id, wdd.requested_quantity delv_det_qty
                      FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
                     WHERE     1 = 1
                           AND wnd.NAME = pv_delivery_no
                           AND wnd.delivery_id = wda.delivery_id
                           AND wda.delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wdd.source_code = 'OE'
                           AND wdd.released_status IN ('S', 'Y')
                           AND wdd.source_line_id =
                               partial_lines_rec.source_line_id --Not required to consider split line qty. Commented on 10Jul2019
                                                               --                UNION
                                                               --                SELECT wdd.delivery_detail_id,
                                                               --                       wdd.requested_quantity delv_det_qty
                                                               --                  FROM wsh_new_deliveries wnd,
                                                               --                       wsh_delivery_assignments wda,
                                                               --                       wsh_delivery_details wdd
                                                               --                 WHERE     1 = 1
                                                               --                       AND wnd.name = pv_delivery_no
                                                               --                       AND wnd.delivery_id = wda.delivery_id
                                                               --                       AND wda.delivery_detail_id = wdd.delivery_detail_id
                                                               --                       AND wdd.source_code = 'OE'
                                                               --                       AND wdd.released_status IN ('S', 'Y')
                                                               --                       AND wdd.source_line_id =
                                                               --                              (SELECT line_id
                                                               --                                 FROM oe_order_lines_all
                                                               --                                WHERE     1 = 1
                                                               --                                      AND split_from_line_id =
                                                               --                                             partial_lines_rec.source_line_id
                                                               --                                      AND header_id = wdd.source_header_id)
                                                               )
            LOOP
                --Ussign the delivery details and then to the newly created delivery
                --Assign the delivery detail ID's that needs to be UNASSIGNED from existing delivery and then ASSIGNED to thet NEW Delivery to the table type
                l_partial_del_dtl_ids_tab (ln_index)   :=
                    miss_det_rec.delivery_detail_id;
                ln_index   := ln_index + 1;
            END LOOP;                                  --miss_det_rec end loop

            --Now unassign and assign the delivery detail id's that are assigned to l_partial_del_dtl_ids_tab table type
            IF l_partial_del_dtl_ids_tab.EXISTS (1)
            THEN
                BEGIN
                    lv_errbuf    := NULL;
                    lv_retcode   := NULL;
                    assign_detail_to_delivery (
                        pv_errbuf               => lv_errbuf,
                        pv_retcode              => lv_retcode,
                        pn_delivery_id          => TO_NUMBER (pv_delivery_no),
                        pv_delivery_name        => pv_delivery_no,
                        p_delivery_detail_ids   => l_partial_del_dtl_ids_tab,
                        pv_action               => 'UNASSIGN');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while invoking assign_detail_to_delivery procedure :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => pv_delivery_no,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   => pv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                        ROLLBACK;                                      --Added
                        RETURN;                            --Exit the delivery
                END;

                IF lv_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            pv_errbuf        => lv_errbuf,
                            pv_retcode       => lv_retcode,
                            pv_shipment_no   => pv_shipment_no,
                            pv_delivery_no   => pv_delivery_no,
                            pv_carton_no     => NULL,
                            pv_line_no       => NULL,
                            pv_item_number   => NULL,
                            pv_error_level   => 'DELIVERY',
                            pv_error_message   =>
                                'Unable to unassign the delivery detail to new delivery',
                            pv_status        => 'ERROR',
                            pv_source        => 'DELIVERY_THREAD');
                        pv_retcode   := '2';
                        pv_errbuf    := 'Unable to unassign the deliveries';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || lv_errbuf;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    END;

                    ROLLBACK;                                          --Added
                    RETURN;                                --Exit the delivery
                END IF;

                --Now assign the unassigned deliveries to the new delivery
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Assigning all the Partial shipped delivery detail Splits to the new delivery');
                lv_errbuf    := NULL;
                lv_retcode   := NULL;

                BEGIN
                    assign_detail_to_delivery (
                        pv_errbuf               => lv_errbuf,
                        pv_retcode              => lv_retcode,
                        pn_delivery_id          => ln_new_delivery_id,
                        pv_delivery_name        => NULL,
                        p_delivery_detail_ids   => l_partial_del_dtl_ids_tab,
                        pv_action               => 'ASSIGN');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while invoking unassign delivery detail procedure :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => pv_delivery_no,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   => pv_errbuf,
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                        ROLLBACK;                                      --Added
                        RETURN;                            --Exit the delivery
                END;

                IF lv_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            pv_errbuf          => lv_errbuf,
                            pv_retcode         => lv_retcode,
                            pv_shipment_no     => pv_shipment_no,
                            pv_delivery_no     => pv_delivery_no,
                            pv_carton_no       => NULL,
                            pv_line_no         => NULL,
                            pv_item_number     => NULL,
                            pv_error_level     => 'DELIVERY',
                            pv_error_message   =>
                                'Unable to assign the deliveries',
                            pv_status          => 'ERROR',
                            pv_source          => 'DELIVERY_THREAD');
                        pv_retcode   := '2';
                        pv_errbuf    := 'Unable to assign the deliveries';
                        ROLLBACK;                                      --Added
                        RETURN;                            --Exit the delivery
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || lv_errbuf;
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                            ROLLBACK;                                  --Added
                            RETURN;                        --exit the delivery
                    END;
                END IF;
            END IF;              --l_partial_del_dtl_ids_tab.EXISTS (1) end if
        END LOOP;

        --Partial Pick(Few Lines being Picked) - END

        --Post Validation Steps --END

        --Update Id's on delivery staging table - START
        BEGIN
            SELECT wnd.delivery_id, wnd.source_header_id, wdd.ship_to_location_id,
                   wdd.ship_to_site_use_id, wdd.organization_id
              INTO ln_delivery_id, ln_header_id, ln_ship_to_location_id, ln_ship_to_org_id,
                                 ln_organization_id
              FROM apps.wsh_new_deliveries wnd, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd
             WHERE     1 = 1
                   AND wnd.NAME = pv_delivery_no
                   AND wnd.status_code = 'OP'
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   --AND wdd.delivery_detail_id in (70632536, 70600217)
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_delivery_id           := 0;
                ln_header_id             := 0;
                ln_ship_to_location_id   := 0;
                ln_ship_to_org_id        := 0;
        END;

        IF (ln_delivery_id = 0 OR ln_header_id = 0 OR ln_ship_to_location_id = 0 OR ln_ship_to_org_id = 0 OR ln_organization_id = 0)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to fetch order header id, ship to location id and ship to org id for delivery number:'
                || pv_delivery_no);

            BEGIN
                update_error_records (
                    pv_errbuf        => lv_errbuf,
                    pv_retcode       => lv_retcode,
                    pv_shipment_no   => pv_shipment_no,
                    pv_delivery_no   => pv_delivery_no,
                    pv_carton_no     => NULL,
                    pv_line_no       => NULL,
                    pv_item_number   => NULL,
                    pv_error_level   => 'DELIVERY',
                    pv_error_message   =>
                        'Unable to fetch order header id or ship to location id or ship to org id ',
                    pv_status        => 'ERROR',
                    pv_source        => 'DELIVERY_THREAD');
                pv_retcode   := '2';
                pv_errbuf    :=
                       'Unable to fetch order header id or ship to location id or ship to org id '
                    || pv_delivery_no;
                RETURN;
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || lv_errbuf;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    ROLLBACK;
                    RETURN;
            END;

            ROLLBACK;                                               --Rollback
            RETURN;                                        --Exit the delivery
        END IF;

        update_ids (pv_errbuf                => lv_errbuf,
                    pv_retcode               => lv_retcode,
                    pv_shipment_no           => pv_shipment_no,
                    pv_delivery_no           => pv_delivery_no,
                    pn_parent_req_id         => pn_parent_req_id,
                    pn_header_id             => ln_header_id,
                    pn_delivery_id           => ln_delivery_id,
                    pn_ship_to_org_id        => ln_ship_to_org_id,
                    pn_ship_to_location_id   => ln_ship_to_location_id);

        IF lv_retcode <> '0'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unable to update IDS is order stg table. Error is'
                || lv_errbuf);
            fnd_file.put_line (fnd_file.LOG, 'Exiting the program');
            pv_retcode   := '2';
            RETURN;
        END IF;

        --Update Id's on delivery staging table - END

        --Creating Container for each carton --START
        fnd_file.put_line (fnd_file.LOG,
                           'Creating container for each carton');

        --Get the cartons and create containers
        FOR carton_rec
            IN (SELECT carton.*
                  FROM xxdo_ont_ship_conf_carton_stg carton
                 WHERE     1 = 1
                       AND carton.shipment_number = pv_shipment_no
                       AND carton.order_number = pv_delivery_no
                       AND carton.request_id = pn_parent_req_id
                       AND carton.process_status = 'INPROCESS')
        LOOP
            --Call package Container Package
            BEGIN
                pack_container (
                    pv_errbuf             => lv_errbuf,
                    pv_retcode            => lv_retcode,
                    pn_header_id          => ln_header_id,
                    --l_delivery_dtl_tab (1).header_id,
                    pn_delivery_id        => ln_delivery_id,
                    pv_container_name     => carton_rec.carton_number,
                    --l_cartons_obj_tab (l_num_carton_ind).carton_number,
                    p_shipments_tab       => l_cur_shipments_tab,
                    pn_freight_cost       =>
                        CASE
                            WHEN NVL (carton_rec.freight_charged, 0) > 0
                            THEN
                                carton_rec.freight_charged
                            ELSE
                                carton_rec.freight_actual
                        END,
                    pn_container_weight   => carton_rec.weight,
                    pv_tracking_number    => carton_rec.tracking_number,
                    pv_carrier            => pv_carrier,
                    --pd_shipment_date      => ld_ship_date,
                    pn_org_id             => ln_organization_id,
                    pv_warehouse          => carton_rec.wh_id,
                    xn_container_id       => ln_container_id);
            --            fnd_file.put_line (
            --               fnd_file.LOG,
            --                  'Carton Number : '
            --               || carton_rec.carton_number
            --               || ' Container ID : '
            --               || ln_container_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unexpected Error while invoking pack container procedure :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'DELIVERY',
                        pv_error_message   => pv_errbuf,
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    RETURN;
            END;

            IF lv_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        pv_errbuf          => lv_errbuf,
                        pv_retcode         => lv_retcode,
                        pv_shipment_no     => pv_shipment_no,
                        pv_delivery_no     => pv_delivery_no,
                        pv_carton_no       => NULL,
                        pv_line_no         => NULL,
                        pv_item_number     => NULL,
                        pv_error_level     => 'DELIVERY',
                        pv_error_message   =>
                               'Unable create container for carton number '
                            || carton_rec.carton_number,
                        pv_status          => 'ERROR',
                        pv_source          => 'DELIVERY_THREAD');
                    pv_retcode   := '2';
                    pv_errbuf    :=
                           'Unable to create container for carton number '
                        || carton_rec.carton_number;
                    RETURN;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        pv_retcode   := '2';
                        pv_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || lv_errbuf;
                        fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        RETURN;
                END;
            END IF;
        END LOOP;                                        --carton_rec end loop

        --Creating Container for each carton --END

        --Assign the newly created deliveries to a table type to back order them after ship confirm --START
        IF ln_new_delivery_id > 0
        THEN
            g_new_delv_ids_tab (g_new_delv_ids_tab.COUNT + 1)   :=
                ln_new_delivery_id;
        END IF;

        --Assign the newly created deliveries to a table type to back order them after ship confirm --END
        fnd_file.put_line (
            fnd_file.LOG,
               'Delivery thread procedure completed for Delivery#: '
            || pv_delivery_no);
    EXCEPTION
        WHEN l_ex_bulk_fetch_failed
        THEN
            pv_retcode   := '2';
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at delivery thread procedure : '
                || pv_errbuf);
            update_error_records (
                pv_errbuf          => lv_errbuf,
                pv_retcode         => lv_retcode,
                pv_shipment_no     => pv_shipment_no,
                pv_delivery_no     => pv_delivery_no,
                pv_carton_no       => NULL,
                pv_line_no         => NULL,
                pv_item_number     => NULL,
                pv_error_level     => 'DELIVERY',
                pv_error_message   =>
                       'Unexpected error at delivery thread procedure : '
                    || pv_errbuf,
                pv_status          => 'ERROR',
                pv_source          => 'DELIVERY_THREAD');
    END delivery_thread;

    -- ***************************************************************************
    -- Procedure Name      :  assign_detail_to_delivery
    --
    -- Description         :  This procedure assigns a Delivery detail to a
    --                        Delivery
    --
    -- Parameters          :
    --                                pv_errbuf         OUT : Error Message
    --                                pv_retcode        OUT : Execution status
    --                                pn_delivery_id       IN   : Delivery Id
    --                                pv_delivery_name     IN   :    Delivery Name
    --                                p_delivery_detail_ids   IN   :    Delivery Detail Ids
    --                                pv_action            IN   :    Action - ASSIGN / UNASSIGN
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE assign_detail_to_delivery (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_id IN NUMBER
                                         , pv_delivery_name IN VARCHAR2, p_delivery_detail_ids IN tabtype_id, pv_action IN VARCHAR2 DEFAULT 'ASSIGN')
    IS
        lv_return_status        VARCHAR2 (30) := NULL;
        ln_msg_count            NUMBER;
        ln_msg_cntr             NUMBER;
        ln_msg_index_out        NUMBER;
        lv_msg_data             VARCHAR2 (2000);
        l_del_details_ids_tab   wsh_delivery_details_pub.id_tab_type;
        l_ex_set_error          EXCEPTION;
    BEGIN
        --Reset status variables
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        --Set delivery detail id
        FOR l_num_ind IN 1 .. p_delivery_detail_ids.COUNT
        LOOP
            l_del_details_ids_tab (l_num_ind)   :=
                p_delivery_detail_ids (l_num_ind);
        END LOOP;

        wsh_delivery_details_pub.detail_to_delivery (
            p_api_version        => gn_api_version_number,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => NULL,
            x_return_status      => lv_return_status,
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data,
            p_tabofdeldets       => l_del_details_ids_tab,
            p_action             => pv_action,
            p_delivery_id        => pn_delivery_id);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF ln_msg_count > 0
            THEN
                pv_retcode    := '2';
                pv_errbuf     :=
                       'API to '
                    || LOWER (pv_action)
                    || ' delivery detail id failed with status: '
                    || lv_return_status;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || lv_msg_data);
                END LOOP;
            END IF;
        ELSE
            pv_errbuf   :=
                   'API to '
                || LOWER (pv_action)
                || ' delivery detail was successful with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);

            --- Logic to update the delivery name on the unassigned delivery details
            IF pv_action = 'UNASSIGN'
            THEN
                FOR l_num_ind IN 1 .. p_delivery_detail_ids.COUNT
                LOOP
                    UPDATE wsh_delivery_details wdd
                       SET attribute11   = pv_delivery_name /* VVAP attribute11*/
                     WHERE delivery_detail_id =
                           p_delivery_detail_ids (l_num_ind);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error while '
                || LOWER (pv_action)
                || 'ing delivery detail.'
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END assign_detail_to_delivery;

    -- ***************************************************************************
    -- Procedure Name      :  pack_into_container
    --
    -- Description         :  This procedure is to link the container, delivery and delivery details
    --
    -- Parameters          : pv_errbuf      OUT : Error message
    --                              pv_retcode     OUT : Execution status
    --                            pn_delivery_id       IN   : Delivery Id
    --                            pn_container_id   IN  : Container Id
    --                            p_delivery_ids_tab   IN  : Delivery detail ids
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE pack_into_container (
        pv_errbuf               OUT VARCHAR2,
        pv_retcode              OUT VARCHAR2,
        pn_delivery_id       IN     NUMBER,
        pn_container_id      IN     NUMBER,
        p_delivery_ids_tab   IN     wsh_util_core.id_tab_type)
    IS
        ln_msg_count   NUMBER;
        lv_msg_data    VARCHAR2 (4000);
        lv_retcode     VARCHAR2 (1);
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';
        fnd_msg_pub.initialize;
        fnd_file.put_line (
            fnd_file.LOG,
            'Trying to pack into container id: ' || pn_container_id);
        fnd_file.put_line (fnd_file.LOG, 'delivery_id: ' || pn_delivery_id);
        fnd_file.put_line (fnd_file.LOG, 'container_id: ' || pn_container_id);

        FOR i IN 1 .. p_delivery_ids_tab.COUNT
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'delivery_detail_id ('
                || i
                || '): '
                || p_delivery_ids_tab (i));
        END LOOP;

        wsh_container_pub.container_actions (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            x_return_status      => lv_retcode,
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data,
            p_detail_tab         => p_delivery_ids_tab,
            p_container_name     => NULL,
            p_cont_instance_id   => pn_container_id,
            p_container_flag     => 'N',
            p_delivery_flag      => 'N',
            p_delivery_id        => pn_delivery_id,
            p_delivery_name      => NULL,
            p_action_code        => 'PACK');

        IF lv_retcode <> 'S'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'ln_msg_count: ' || ln_msg_count);

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                lv_msg_data   := fnd_msg_pub.get (j, 'F');
                lv_msg_data   := REPLACE (lv_msg_data, CHR (0), ' ');
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_msg_data : ' || lv_msg_data);
            END LOOP;

            pv_errbuf    := lv_msg_data;
            pv_retcode   := '2';
        ELSE
            pv_errbuf    := lv_msg_data;
            pv_retcode   := '0';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Packing into Container was successful with status : '
                || lv_retcode);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at pack into container procedure : '
                || pv_errbuf);
    END pack_into_container;

    -- ***************************************************************************
    -- Procedure Name      :  process_delivery_freight
    --
    -- Description         :  This procedure is add the freight charges
    --
    -- Parameters          :
    --                                pv_errbuf         OUT : Error Message
    --                                pv_retcode        OUT : Execution status
    --                                pn_header_id            IN : Order Header Id
    --                                pn_delivery_id          IN : Delivery Id
    --                                pn_freight_charge       IN : Freight Charge
    --                                pn_delivery_detail_id   IN : Delivery Detail id
    --                                pv_carrier              IN : Carrier
    --                                pv_warehouse        IN     : Warehouse code
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE process_delivery_freight (
        pv_errbuf                  OUT VARCHAR2,
        pv_retcode                 OUT VARCHAR2,
        pn_header_id            IN     NUMBER,
        pn_delivery_id          IN     NUMBER,
        pn_freight_charge       IN     NUMBER,
        pn_delivery_detail_id   IN     NUMBER,
        pv_carrier              IN     VARCHAR2,
        pv_warehouse            IN     VARCHAR2)
    IS
        lv_cust_flag             VARCHAR2 (1);
        lv_order_type_flag       VARCHAR2 (1);
        lv_carrier               VARCHAR2 (1) := 'Y';
        l_freight_rec            wsh_freight_costs_pub.pubfreightcostrectype;
        lv_currency_code         VARCHAR2 (10);
        lv_retstat               VARCHAR2 (1);
        ln_msgcount              NUMBER;
        lv_msgdata               VARCHAR2 (2000);
        lv_message               VARCHAR2 (2000);
        lv_message1              VARCHAR2 (2000);
        ln_freight_overide_cnt   NUMBER;
    BEGIN
        pv_errbuf                         := NULL;
        pv_retcode                        := '0';

        BEGIN
            SELECT wcs.attribute3
              INTO lv_carrier
              FROM apps.wsh_carrier_services wcs, wsh_carriers wc, wsh_delivery_details wdd,
                   oe_order_lines_all ool
             WHERE     wc.carrier_id = wcs.carrier_id
                   AND wc.freight_code = pv_carrier
                   AND wcs.ship_method_code = ool.shipping_method_code
                   AND wdd.delivery_detail_id = pn_delivery_detail_id
                   AND ool.line_id = wdd.source_line_id
                   AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_carrier   := 'Y';
        END;

        BEGIN
            SELECT NVL (SUBSTR (rc.attribute6, 1, 1), 'N')
              INTO lv_cust_flag
              FROM ra_customers rc, oe_order_headers_all oh
             WHERE     rc.customer_id = oh.sold_to_org_id
                   AND oh.header_id = pn_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_cust_flag   := 'N';
        END;

        BEGIN
            SELECT NVL (ott.attribute4, 'N')
              INTO lv_order_type_flag
              FROM oe_transaction_types_all ott, oe_order_headers_all oh
             WHERE     ott.transaction_type_id = oh.order_type_id
                   AND oh.header_id = pn_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lv_order_type_flag   := 'N';
        END;

        SELECT COUNT (opa.header_id)
          INTO ln_freight_overide_cnt
          FROM apps.fnd_lookup_values flv, apps.oe_price_adjustments_v opa
         WHERE     flv.lookup_type = 'XXD_ONT_FREIGHT_MOD_EXCLUSION'
               AND flv.LANGUAGE = 'US'
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = opa.list_header_id
               AND opa.header_id = pn_header_id
               AND opa.operand <> 0
               AND opa.adjustment_type_code = 'FREIGHT_CHARGE'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE));

        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Zero Freight - Customer Flag : ' || lv_cust_flag);
        --      fnd_file.put_line (
        --         fnd_file.LOG,
        --         'Zero Freight - Order Type Flag : ' || lv_order_type_flag);
        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Zero Freight - Carrier Flag : ' || lv_carrier);
        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Freight Charge from WMS : ' || pn_freight_charge);
        IF    lv_cust_flag = 'Y'
           OR lv_order_type_flag = 'Y'
           OR lv_carrier = 'N'
           OR pn_freight_charge = 0
           OR ln_freight_overide_cnt <> 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Freight cost is not applied since the delivery is exempted');
            pv_retcode   := '0';
            RETURN;
        END IF;

        BEGIN
            SELECT currency_code
              INTO lv_currency_code
              FROM oe_order_headers_all ooha, qp_list_headers_all qlh
             WHERE     ooha.price_list_id = qlh.list_header_id
                   AND ooha.header_id = pn_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_currency_code   := 'USD';
        END;

        l_freight_rec.currency_code       := lv_currency_code;
        l_freight_rec.action_code         := 'CREATE';
        l_freight_rec.delivery_id         := pn_delivery_id;
        l_freight_rec.unit_amount         := pn_freight_charge;
        l_freight_rec.attribute1          := TO_CHAR (pn_delivery_detail_id);
        --    l_freight_rec.delivery_detail_id := pn_delivery_detail_id;
        --l_freight_rec.freight_cost_type_id := 1;
        l_freight_rec.freight_cost_type   := 'Shipping';

        UPDATE oe_order_lines_all
           SET calculate_price_flag   = 'Y'
         WHERE line_id IN
                   (SELECT source_line_id
                      FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                     WHERE     wda.delivery_id = pn_delivery_id
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.container_flag = 'N');

        apps.wsh_freight_costs_pub.create_update_freight_costs (
            p_api_version_number   => 1.0,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => fnd_api.g_false,
            x_return_status        => lv_retstat,
            x_msg_count            => ln_msgcount,
            x_msg_data             => lv_msgdata,
            p_pub_freight_costs    => l_freight_rec,
            p_action_code          => 'CREATE',
            x_freight_cost_id      => l_freight_rec.freight_cost_type_id);

        IF lv_retstat <> 'S'
        THEN
            FOR i IN 1 .. ln_msgcount
            LOOP
                lv_message   := fnd_msg_pub.get (i, 'F');
                lv_message   := REPLACE (lv_message, CHR (0), ' ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error during freight addition:  ' || lv_message);
            END LOOP;

            fnd_msg_pub.delete_msg ();
            pv_errbuf    := lv_message;
            pv_retcode   := '2';
        ELSE
            pv_retcode   := '0';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Charging freight: '
                || l_freight_rec.unit_amount
                || ' for delivery_id: '
                || l_freight_rec.delivery_id
                || ' on delivery_detail_id: '
                || l_freight_rec.delivery_detail_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at process delivery freight procedure : '
                || pv_errbuf);
    END process_delivery_freight;

    -- ***************************************************************************
    -- Procedure Name      :  process_container_tracking
    --
    -- Description         :  This procedure is to update the tracking number and weight on the delivery detail
    --
    -- Parameters          :
    --                            pv_errbuf         OUT : Error Message
    --                            pv_retcode        OUT : Execution status
    --                            pn_delivery_detail_id   IN : Delivery Detail Id
    --                            pv_tracking_number      IN : Tracking Number
    --                            pn_container_weight     IN : Container Weight
    --                            pv_carrier              IN : Carrier
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE process_container_tracking (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_detail_id IN NUMBER
                                          , pv_tracking_number IN VARCHAR2, pn_container_weight IN NUMBER, pv_carrier IN VARCHAR2)
    IS
    BEGIN
        pv_retcode   := '0';
        pv_errbuf    := NULL;
        fnd_file.put_line (
            fnd_file.LOG,
               'delivery_detail_id at process container tracking procedure = '
            || TO_CHAR (pn_delivery_detail_id));

        UPDATE wsh_delivery_details
           SET tracking_number = TRIM (pv_tracking_number), net_weight = pn_container_weight
         WHERE delivery_detail_id = pn_delivery_detail_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at process container tracking procedure : '
                || pv_errbuf);
    END process_container_tracking;

    -- ***************************************************************************
    -- Procedure Name      :  create_container
    --
    -- Description         :  This procedure is to create the container for each carton
    --
    -- Parameters          :
    --                            pv_errbuf         OUT : Error Message
    --                            pv_retcode        OUT : Execution status
    --                            pn_delivery_id          IN  : Delivery Id
    --                            pn_container_item_id    IN  : Container Item Id
    --                            pv_container_name       IN  :,Container name - LPN
    --                            pn_organization_id      IN  : Inventory Org Id
    --                            xn_container_inst_id   OUT : Container Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE create_container (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_id IN NUMBER, pn_container_item_id IN NUMBER, pv_container_name IN VARCHAR2, pn_organization_id IN NUMBER
                                , xn_container_inst_id OUT NUMBER)
    IS
        l_containers_tab   wsh_util_core.id_tab_type;
        ln_msg_count       NUMBER;
        lv_msg_data        VARCHAR2 (2000);
        ln_api_version     NUMBER := 1.0;
        l_segs_array       fnd_flex_ext.segmentarray;
        lv_return_status   VARCHAR2 (1);
    BEGIN
        pv_retcode   := '0';
        pv_errbuf    := NULL;
        fnd_msg_pub.initialize;
        wsh_container_pub.create_containers (
            p_api_version           => ln_api_version,
            p_init_msg_list         => fnd_api.g_true,
            p_commit                => fnd_api.g_false,
            p_validation_level      => fnd_api.g_valid_level_full,
            x_return_status         => lv_return_status,
            x_msg_count             => ln_msg_count,
            x_msg_data              => lv_msg_data,
            p_container_item_id     => gn_container_item_id,
            p_container_item_name   => NULL,
            p_container_item_seg    => l_segs_array,
            p_organization_id       => pn_organization_id,
            p_organization_code     => NULL,
            p_name_prefix           => NULL,
            p_name_suffix           => NULL,
            p_base_number           => NULL,
            p_num_digits            => NULL,
            p_quantity              => 1,
            p_container_name        => pv_container_name,
            x_container_ids         => l_containers_tab);
        fnd_file.put_line (fnd_file.LOG,
                           'Return Status: ' || lv_return_status);
        fnd_file.put_line (fnd_file.LOG, 'Message Count: ' || ln_msg_count);
        fnd_file.put_line (fnd_file.LOG,
                           'Error Message Data: ' || lv_msg_data);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                lv_msg_data   := fnd_msg_pub.get (j, 'F');
                lv_msg_data   := REPLACE (lv_msg_data, CHR (0), ' ');
                fnd_file.put_line (fnd_file.LOG, lv_msg_data);
            END LOOP;

            pv_retcode   := '2';
            pv_errbuf    := 'Error while creating container: ' || lv_msg_data;
            RETURN;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Container count:' || l_containers_tab.COUNT);

        -- Updating the attributes of each container
        FOR i IN 1 .. l_containers_tab.COUNT
        LOOP
            xn_container_inst_id   := l_containers_tab (i);
            fnd_file.put_line (fnd_file.LOG,
                               'Container id:' || l_containers_tab (i));
            fnd_msg_pub.initialize;
            wsh_container_actions.update_cont_attributes (NULL, pn_delivery_id, l_containers_tab (i)
                                                          , lv_return_status);
            fnd_file.put_line (
                fnd_file.LOG,
                'update attributes ret_stat: ' || lv_return_status);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR j IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    lv_msg_data   := fnd_msg_pub.get (j, 'F');
                    lv_msg_data   := REPLACE (lv_msg_data, CHR (0), ' ');
                    fnd_file.put_line (fnd_file.LOG, lv_msg_data);
                END LOOP;

                pv_retcode   := '2';
                pv_errbuf    :=
                       'Error while updating the attributes of container: '
                    || lv_msg_data;
                RETURN;
            END IF;

            fnd_msg_pub.initialize;
            wsh_container_actions.assign_to_delivery (l_containers_tab (i),
                                                      pn_delivery_id,
                                                      lv_return_status);
            fnd_file.put_line (
                fnd_file.LOG,
                'assign to delivery ret_stat: ' || lv_return_status);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR j IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    lv_msg_data   := fnd_msg_pub.get (j, 'F');
                    lv_msg_data   := REPLACE (lv_msg_data, CHR (0), ' ');
                    fnd_file.put_line (fnd_file.LOG, lv_msg_data);
                END LOOP;

                pv_retcode   := '2';
                pv_errbuf    :=
                       'Error while assigning container to delivery: '
                    || lv_msg_data;
                RETURN;
            ELSE
                /* CONTAINER_BUG Start */
                UPDATE wsh_delivery_details
                   SET source_header_id   =
                           (SELECT source_header_id
                              FROM wsh_new_deliveries
                             WHERE delivery_id = pn_delivery_id)
                 WHERE delivery_detail_id = xn_container_inst_id;
            /* CONTAINER_BUG End */
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at create container procedure : '
                || pv_errbuf);
    END create_container;

    -- ***************************************************************************
    -- Function Name      :  get_requested_quantity
    --
    -- Description         :  This function is to get the requested quantity of the given delivery detail
    --
    -- Parameters          : pn_delivery_detail_id  IN : Delivery Detail id
    --
    -- Return/Exit         :  Requested Quantity
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    FUNCTION get_requested_quantity (pn_delivery_detail_id IN NUMBER)
        RETURN NUMBER
    IS
        ln_requested_qty   NUMBER;
    BEGIN
        SELECT requested_quantity
          INTO ln_requested_qty
          FROM wsh_delivery_details
         WHERE delivery_detail_id = pn_delivery_detail_id;

        RETURN ln_requested_qty;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN 0;
        WHEN OTHERS
        THEN
            RETURN -1;
    END get_requested_quantity;

    -- ***************************************************************************
    -- Procedure Name      :  purge
    --
    -- Description         :  This procedure is to create container, link to delivery / delivery details and add freight costs
    --
    -- Parameters          : pv_errbuf      OUT : Error message
    --                              pv_retcode     OUT : Execution status
    --                            pv_errbuf         OUT : Error Message
    --                            pv_retcode        OUT : Execution status
    --                            pn_header_id          IN : Order Header Id
    --                            pn_delivery_id        IN : Delivery Id
    --                            pv_container_name     IN : Container name - LPN
    --                            p_shipments_tab          IN : Delivery details to be linked to Container
    --                            pn_freight_cost       IN : Freight cost
    --                            pn_container_weight   IN : Container Weight
    --                            pv_tracking_number    IN : Tracking Number
    --                            pv_carrier            IN : Carrier
    --                            pd_shipment_date      IN : Ship Date
    --                            pn_org_id             IN : Inventory Org Id
    --                            pv_warehouse          IN  : Warehouse Code
    --                            xn_container_id      OUT : Container Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/16    Kranthi Bollam     1.0       Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE pack_container (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_header_id IN NUMBER, pn_delivery_id IN NUMBER, pv_container_name IN VARCHAR2, p_shipments_tab IN g_shipments_tab_type, pn_freight_cost IN NUMBER, pn_container_weight IN NUMBER, pv_tracking_number IN VARCHAR2, pv_carrier IN VARCHAR2, --pd_shipment_date      IN     DATE,
                                                                                                                                                                                                                                                                                                                           pn_org_id IN NUMBER, pv_warehouse IN VARCHAR2
                              , xn_container_id OUT NUMBER)
    IS
        lv_errbuf                       VARCHAR2 (2000);
        lv_retcode                      VARCHAR2 (30);
        lv_return_status                VARCHAR2 (1);
        ln_container_id                 NUMBER;
        l_delivery_ids_tab              wsh_util_core.id_tab_type;
        l_row_ids_tab                   wsh_util_core.id_tab_type;
        l_ex_create_container_failure   EXCEPTION;
        l_ex_split_shipments_failure    EXCEPTION;
        l_ex_pack_into_container_fail   EXCEPTION;
        l_ex_process_freight_failure    EXCEPTION;
        l_ex_process_tracking_failure   EXCEPTION;
        ln_del_dtl_ind                  NUMBER := 0;
        ln_container_line_qty           NUMBER := 0;
        ln_remaining_line_qty           NUMBER := 0;
        ln_diff_qty                     NUMBER := 0;
        xn_delivery_detail_id           NUMBER;

        CURSOR c_container_details IS
            SELECT line_number, qty
              FROM xxdo.xxdo_ont_ship_conf_cardtl_stg
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND carton_number = pv_container_name
                   AND order_number = pn_delivery_id;
    BEGIN
        pv_retcode       := '0';
        pv_errbuf        := NULL;
        wsh_delivery_autocreate.autocreate_deliveries (
            p_line_rows           => l_row_ids_tab,
            p_init_flag           => 'N',
            p_pick_release_flag   => 'N',                                   --
            p_container_flag      => 'Y',
            --'Y' means call Autopack routine
            p_check_flag          => 'Y',
            --'Y' means delivery details will be grouped without creating deliveries
            p_max_detail_commit   => 1000,
            x_del_rows            => l_row_ids_tab,
            x_grouping_rows       => l_row_ids_tab,
            x_return_status       => lv_return_status);
        create_container (pv_errbuf => lv_errbuf, pv_retcode => lv_retcode, pn_delivery_id => pn_delivery_id, pn_container_item_id => gn_container_item_id, pv_container_name => pv_container_name, pn_organization_id => pn_org_id
                          , xn_container_inst_id => ln_container_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Create Container Ret Stat: ' || lv_retcode);


        IF lv_retcode <> '0'
        THEN
            pv_errbuf   := lv_errbuf;
            RAISE l_ex_create_container_failure;
        END IF;

        --      FOR ln_del_dtl_ind IN 1 .. p_shipments_tab.COUNT
        --      LOOP
        --         l_delivery_ids_tab (ln_del_dtl_ind) := p_shipments_tab (ln_del_dtl_ind).delivery_detail_id;
        --      END LOOP;
        ln_del_dtl_ind   := 1;

        FOR container_rec IN c_container_details
        LOOP
            ln_remaining_line_qty   := container_rec.qty;
            ln_diff_qty             := 1;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Line: '
                || container_rec.line_number
                || ' Qty: '
                || container_rec.qty);

            FOR del_det_id_rec
                IN (  SELECT wdd.delivery_detail_id,
                             wdd.requested_quantity quantity,
                             --begin CCR0009256 --Rank by delivery details matching qty with container qty
                             CASE
                                 WHEN wdd.requested_quantity =
                                      container_rec.qty
                                 THEN
                                     1
                                 ELSE
                                     0
                             END ctn_match
                        --end CCR0009256
                        FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda, wsh_delivery_details wdd
                       WHERE     1 = 1
                             AND wnd.delivery_id = pn_delivery_id
                             AND wnd.organization_id = gn_inv_org_id
                             AND wnd.status_code = 'OP'
                             AND wnd.delivery_id = wda.delivery_id
                             AND wda.delivery_detail_id =
                                 wdd.delivery_detail_id
                             AND wdd.source_code = 'OE'
                             AND wdd.released_status IN ('S', 'Y')
                             AND wdd.organization_id = gn_inv_org_id
                             AND wdd.source_line_id =
                                 TO_NUMBER (container_rec.line_number)
                             AND wda.parent_delivery_detail_id IS NULL
                    ORDER BY ctn_match DESC, wdd.requested_quantity DESC) --CCR0009256 Change to desc sort to getmatching quantities and  larger carton quantities first.
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Delivery Detail: '
                    || del_det_id_rec.delivery_detail_id
                    || ' Requested Qty: '
                    || del_det_id_rec.quantity
                    || ' Remaining Qty: '
                    || ln_remaining_line_qty);

                IF     ln_remaining_line_qty >= del_det_id_rec.quantity
                   AND ln_diff_qty <> 0
                THEN
                    l_delivery_ids_tab (ln_del_dtl_ind)   :=
                        del_det_id_rec.delivery_detail_id;
                    ln_del_dtl_ind          := ln_del_dtl_ind + 1;
                    ln_diff_qty             :=
                        ln_remaining_line_qty - del_det_id_rec.quantity;
                    ln_remaining_line_qty   := ln_diff_qty;
                ELSIF     ln_remaining_line_qty < del_det_id_rec.quantity
                      AND ln_remaining_line_qty <> 0
                THEN
                    BEGIN
                        split_delivery_detail (
                            lv_errbuf,
                            lv_retcode,
                            del_det_id_rec.delivery_detail_id,
                            ln_remaining_line_qty,
                            pn_delivery_id,
                            xn_delivery_detail_id);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            pv_retcode   := '2';
                            pv_errbuf    :=
                                   'Unexpected Error while invoking split_delivery_detail procedure :'
                                || SQLERRM;
                            --DBMS_OUTPUT.put_line (pv_errbuf);
                            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                            lv_errbuf    := NULL;
                            lv_retcode   := NULL;
                            ROLLBACK;                                  --Added
                            RETURN;                        --Exit the delivery
                    END;

                    IF lv_retcode <> '0'
                    THEN
                        BEGIN
                            pv_retcode   := '2';
                            pv_errbuf    := 'Unable to create new delivery';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                pv_retcode   := '2';
                                pv_errbuf    :=
                                       'Unexpected Error while updating error status :'
                                    || lv_errbuf;
                                --DBMS_OUTPUT.put_line (pv_errbuf);
                                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                        END;

                        ROLLBACK;                                      --Added
                        RETURN;                            --Exit the delivery
                    ELSE
                        l_delivery_ids_tab (ln_del_dtl_ind)   :=
                            del_det_id_rec.delivery_detail_id;
                        ln_del_dtl_ind          := ln_del_dtl_ind + 1;
                        ln_remaining_line_qty   := 0;     --Added on 10Jul2019
                        ln_diff_qty             := 0;     --Added on 10Jul2019
                        EXIT;                             --Added on 10Jul2019
                    END IF;
                END IF;
            END LOOP;
        END LOOP;

        pack_into_container (pv_errbuf            => lv_errbuf,
                             pv_retcode           => lv_retcode,
                             pn_delivery_id       => pn_delivery_id,
                             pn_container_id      => ln_container_id,
                             p_delivery_ids_tab   => l_delivery_ids_tab);
        fnd_file.put_line (fnd_file.LOG,
                           'Pack into container Ret Stat: ' || lv_retcode);

        IF lv_retcode <> '0'
        THEN
            pv_errbuf   := lv_errbuf;
            RAISE l_ex_pack_into_container_fail;
        END IF;

        -- Start changes for CCR0008298
        -- FOR l_num_ind IN 1 .. l_delivery_ids_tab.COUNT
        -- LOOP
        -- End changes for CCR0008298
        process_delivery_freight (
            pv_errbuf               => lv_errbuf,
            pv_retcode              => lv_retcode,
            pn_header_id            => pn_header_id,
            pn_delivery_id          => pn_delivery_id,
            pn_freight_charge       => pn_freight_cost,
            -- Start changes for CCR0008298
            -- pn_delivery_detail_id   => l_delivery_ids_tab (l_num_ind),
            pn_delivery_detail_id   => l_delivery_ids_tab (1),
            -- End changes for CCR0008298
            pv_carrier              => pv_carrier,
            pv_warehouse            => pv_warehouse);
        fnd_file.put_line (
            fnd_file.LOG,
            'process_delivery_freight Ret Stat: ' || lv_retcode);

        -- END LOOP; -- Commented for CCR0008298
        IF lv_retcode <> '0'
        THEN
            pv_errbuf   := lv_errbuf;
            RAISE l_ex_process_freight_failure;
        END IF;

        FOR l_num_ind IN 1 .. l_delivery_ids_tab.COUNT
        LOOP
            process_container_tracking (
                pv_errbuf               => lv_errbuf,
                pv_retcode              => lv_retcode,
                pn_delivery_detail_id   => l_delivery_ids_tab (l_num_ind),
                pv_tracking_number      => pv_tracking_number,
                pn_container_weight     => pn_container_weight,
                pv_carrier              => pv_carrier);
            fnd_file.put_line (
                fnd_file.LOG,
                'process_container_tracking Ret Stat: ' || lv_retcode);
        END LOOP;

        /* Start Update tracking number for carton  TRACKING_NUMBER*/
        BEGIN
            UPDATE wsh_delivery_details
               SET tracking_number   = TRIM (pv_tracking_number)
             WHERE     delivery_detail_id = ln_container_id
                   AND source_code = 'WSH';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while updating tracking number to carton');
        END;

        /* ENDs Update tracking number for carton TRACKING_NUMBER*/
        IF lv_retcode <> '0'
        THEN
            pv_errbuf   := lv_errbuf;
            RAISE l_ex_process_tracking_failure;
        END IF;

        pv_retcode       := '0';
    EXCEPTION
        WHEN l_ex_create_container_failure
        THEN
            pv_retcode   := '2';
        WHEN l_ex_split_shipments_failure
        THEN
            pv_retcode   := '2';
        WHEN l_ex_pack_into_container_fail
        THEN
            pv_retcode   := '2';
        WHEN l_ex_process_freight_failure
        THEN
            pv_retcode   := '2';
        WHEN l_ex_process_tracking_failure
        THEN
            pv_retcode   := '2';
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at package container procedure : '
                || pv_errbuf);
    END pack_container;

    -- ***************************************************************************
    -- Procedure Name      :  assign_del_to_trip
    --
    -- Description         :  This procedure is to assign the delivery to the trip
    --
    -- Parameters          : pv_errbuf      OUT : Error message
    --                              pv_retcode     OUT : Execution status
    --                             pn_trip_id       IN  : Trip id
    --                             pn_delivery_id   IN  : Delivery Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE assign_del_to_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_trip_id IN NUMBER
                                  , pn_delivery_id IN NUMBER, pn_from_stop_id IN NUMBER, pn_to_stop_id IN NUMBER)
    IS
        lv_return_status   VARCHAR2 (30) := NULL;
        ln_msg_count       NUMBER;
        ln_msg_cntr        NUMBER;
        ln_msg_index_out   NUMBER;
        lv_msg_data        VARCHAR2 (2000);
        ln_trip_id         NUMBER;
        lv_trip_name       VARCHAR2 (240);
    BEGIN
        --Reset status variables
        pv_retcode   := '0';
        pv_errbuf    := NULL;
        -- Assign new delivery created to the specified trip id
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Calling delivery action api to assign delivery '
            || pn_delivery_id
            || ' to trip '
            || pn_trip_id);
        --      BEGIN
        --         select wdd.ship_to_location_id
        --               ,
        --            from wsh_new_deliveries wnd,
        --                 wsh_delivery_assignments
        --                 wsh_delivery_details
        --           where 1=1
        --             and wnd.delivery_id = pn_delivery_id;
        --
        --      EXCEPTION
        --        WHEN OTHERS THEN
        --           NULL;
        --      END;

        -- Call delivery_action api
        wsh_deliveries_pub.delivery_action (
            p_api_version_number    => gn_api_version_number,
            p_init_msg_list         => fnd_api.g_true,
            x_return_status         => lv_return_status,
            x_msg_count             => ln_msg_count,
            x_msg_data              => lv_msg_data,
            p_action_code           => 'ASSIGN-TRIP',
            p_delivery_id           => pn_delivery_id,
            p_asg_trip_id           => pn_trip_id,
            p_asg_pickup_stop_id    => pn_from_stop_id,
            p_asg_dropoff_stop_id   => pn_to_stop_id,
            x_trip_id               => ln_trip_id,
            x_trip_name             => lv_trip_name);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'API to assign delivery to trip failed with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);

            IF ln_msg_count > 0
            THEN
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message:' || lv_msg_data);
                END LOOP;
            END IF;

            pv_errbuf    := lv_msg_data;
        ELSE
            pv_retcode   := '0';
            pv_errbuf    :=
                   'API to assign delivery to trip was successful with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            fnd_file.put_line (fnd_file.LOG,
                               'Trip Id from API : ' || ln_trip_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Trip Name from API : ' || lv_trip_name);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    := 'Error while creating delivery.' || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'An unexpected error occurred in the Creation of Delivery.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END assign_del_to_trip;

    -- ***************************************************************************
    -- Procedure Name      :  split_delivery_detail
    --
    -- Description         :  This procedure splits a delivery detail when the
    --                        shipped quantity is less than the ordered quantity
    --
    -- Parameters          :
    --                            pv_errbuf         OUT : Error Message
    --                            pv_retcode        OUT : Execution status
    --                            pn_delivery_detail_id    IN : Delivery Detail Id
    --                            pn_split_quantity        IN : Split Quantity - Requested Qty in the new delivery detail
    --                            pv_delivery_name         IN : Delivery name
    --                            xn_delivery_detail_id   OUT : New Delivery detail id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE split_delivery_detail (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_detail_id IN NUMBER
                                     , pn_split_quantity IN NUMBER, pv_delivery_name IN VARCHAR2, xn_delivery_detail_id OUT NUMBER)
    IS
        lv_return_status           VARCHAR2 (30) := NULL;
        ln_msg_count               NUMBER;
        ln_msg_cntr                NUMBER;
        ln_msg_index_out           NUMBER;
        lv_msg_data                VARCHAR2 (2000);
        l_num_delivery_detail_id   NUMBER := 0;
        l_num_split_quantity       NUMBER;
        --l_num_split_quantity2      NUMBER := pn_split_quantity; --Commented on 10Jul2019
        l_num_split_quantity2      NUMBER := NULL;
        --Added on 10Jul2019 (No need to pass l_num_split_quantity2 for Discrete Inventory Organizations)
        ln_orig_qty                NUMBER := 0;
    BEGIN
        --Reset status variables
        pv_retcode             := '0';
        pv_errbuf              := NULL;

        BEGIN
            SELECT NVL (wdd.requested_quantity, 0)
              INTO ln_orig_qty
              FROM wsh_delivery_details wdd
             WHERE     1 = 1
                   AND wdd.delivery_detail_id = pn_delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wdd.organization_id = gn_inv_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_orig_qty   := 0;
        END;

        --l_num_split_quantity := ln_orig_qty - l_num_split_quantity2; --Commented on 10Jul2019
        l_num_split_quantity   := ln_orig_qty - pn_split_quantity;
        --Added on 10Jul2019
        -- Start calling api
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Calling split line api for Delivery Detail Id: '
            || pn_delivery_detail_id);
        --      fnd_file.put_line (fnd_file.LOG,
        --                         'Delivery Detail Id: ' || pn_delivery_detail_id);
        wsh_delivery_details_pub.split_line (
            p_api_version        => gn_api_version_number,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => NULL,
            x_return_status      => lv_return_status,
            x_msg_count          => ln_msg_count,
            x_msg_data           => lv_msg_data,
            p_from_detail_id     => pn_delivery_detail_id,
            x_new_detail_id      => l_num_delivery_detail_id,
            x_split_quantity     => l_num_split_quantity,
            x_split_quantity2    => l_num_split_quantity2);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF ln_msg_count > 0
            THEN
                xn_delivery_detail_id   := 0;
                pv_retcode              := '2';
                pv_errbuf               :=
                       'API to split the delivery detail failed with status: '
                    || lv_return_status;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                -- Retrieve messages
                ln_msg_cntr             := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || lv_msg_data);
                END LOOP;

                pv_errbuf               := lv_msg_data;
            END IF;
        ELSE
            xn_delivery_detail_id   := l_num_delivery_detail_id;
            pv_errbuf               :=
                   'API to split delivery detail is successful with status: '
                || lv_return_status
                || 'Delivery Detail ID '
                || TO_CHAR (pn_delivery_detail_id)
                || ' is Split. New Delivery Detail ID > '
                || TO_CHAR (l_num_delivery_detail_id);
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            --         fnd_file.put_line (
            --            fnd_file.LOG,
            --               'Delivery Detail > '
            --            || TO_CHAR (pn_delivery_detail_id)
            --            || ' : Split. New Delivery Detail > '
            --            || TO_CHAR (l_num_delivery_detail_id));
            fnd_file.put_line (
                fnd_file.LOG,
                'Updating new delivery detail id in wsh_delivery_details table attribute11 with original delivery number');

            UPDATE wsh_delivery_details
               SET attribute11   = pv_delivery_name
             WHERE     delivery_detail_id = l_num_delivery_detail_id
                   AND organization_id = gn_inv_org_id
                   AND source_code = 'OE';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf   := '2';
            pv_errbuf   :=
                   'Unexpected error while splitting delivery details.'
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'An unexpected error occurred while Splitting Delivery Detail.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END split_delivery_detail;

    -- ***************************************************************************
    -- Procedure Name      :  update_shipping_attributes
    --
    -- Description         :  This procedure updates the shipping attributes for
    --                        a delivery detail
    --
    -- Parameters          :
    --                            pv_errbuf         OUT : Error Message
    --                            pv_retcode        OUT : Execution status
    --                            pn_delivery_detail_id   IN : Delivery Detail Id
    --                            pn_split_quantity       IN : Split Quantity - Requested Qty in the new delivery detail
    --                            pn_order_line_id        IN : Order Line id
    --                            pd_ship_date            IN : Ship Date
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01    Kranthi Bollam     1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE update_shipping_attributes (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_delivery_detail_id IN NUMBER
                                          , pn_shipped_quantity IN NUMBER, pn_order_line_id IN NUMBER, pd_ship_date IN DATE)
    IS
        lv_return_status           VARCHAR2 (30) := NULL;
        ln_msg_count               NUMBER;
        ln_msg_cntr                NUMBER;
        ln_msg_index_out           NUMBER;
        lv_msg_data                VARCHAR2 (2000);
        l_chr_source_code          VARCHAR2 (15) := 'OE';
        l_changed_attributes_tab   wsh_delivery_details_pub.changedattributetabtype;
    BEGIN
        --Reset status variables
        pv_retcode   := '0';
        pv_errbuf    := NULL;
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling update shipping attributes API...');
        l_changed_attributes_tab (1).delivery_detail_id   :=
            pn_delivery_detail_id;
        l_changed_attributes_tab (1).shipped_quantity   :=
            pn_shipped_quantity;
        wsh_delivery_details_pub.update_shipping_attributes (
            p_api_version_number   => gn_api_version_number,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => fnd_api.g_false,
            x_return_status        => lv_return_status,
            x_msg_count            => ln_msg_count,
            x_msg_data             => lv_msg_data,
            p_changed_attributes   => l_changed_attributes_tab,
            p_source_code          => l_chr_source_code);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF ln_msg_count > 0
            THEN
                pv_retcode    := '2';
                pv_errbuf     :=
                       'API to update shipping attributes failed with status: '
                    || lv_return_status;
                fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || lv_msg_data);
                END LOOP;

                pv_errbuf     := lv_msg_data;
            END IF;
        ELSE
            pv_errbuf   :=
                   'API to update shipping attributes was successful with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery Detail > '
                || TO_CHAR (pn_delivery_detail_id)
                || ' : Updated Ship Quantity > '
                || TO_CHAR (pn_shipped_quantity));
            fnd_file.put_line (fnd_file.LOG,
                               'Updating the ship date at order line level');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                'Error while updating shipping attribute.' || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'An unexpected error occurred while Updating Shipping Attributes.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END update_shipping_attributes;

    -- ***************************************************************************
    -- Procedure Name      :  reapply_holds
    --
    -- Description         :  This procedure is to reapply the order holds which were released by the ship confirm interface
    --
    -- Parameters          : pv_errbuf      OUT : Error message
    --                              pv_retcode     OUT : Execution status
    --                              p_hold_source_tbl   IN   : Hold Ids
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE reapply_holds (
        pv_errbuf              OUT VARCHAR2,
        pv_retcode             OUT VARCHAR2,
        p_hold_source_tbl   IN     g_hold_source_tbl_type)
    IS
        l_num_rec_cnt        NUMBER;
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1);
        ln_msg_index_out     NUMBER;
        l_num_org_id         NUMBER;
        l_num_resp_id        NUMBER;
        l_num_resp_appl_id   NUMBER;
        l_hold_source_rec    oe_holds_pvt.hold_source_rec_type;
        l_result             VARCHAR2 (240);

        CURSOR c_lines (p_order_header_id IN NUMBER)
        IS
            SELECT oola.line_id
              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     oola.header_id = ooha.header_id
                   AND oola.flow_status_code = 'SHIPPED'
                   AND ooha.header_id = p_order_header_id;
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        FOR ln_index IN 1 .. p_hold_source_tbl.COUNT
        LOOP
            FOR r_lines IN c_lines (p_hold_source_tbl (ln_index).header_id)
            LOOP
                apps.oe_standard_wf.oeol_selector (
                    p_itemtype   => 'OEOL',
                    p_itemkey    => TO_CHAR (r_lines.line_id),
                    p_actid      => 12345,
                    p_funcmode   => 'SET_CTX',
                    p_result     => l_result);
                apps.wf_engine.handleerror ('OEOL', TO_CHAR (r_lines.line_id), 'INVOICE_INTERFACE'
                                            , 'RETRY', '');
            END LOOP;

            COMMIT;

            SELECT org_id
              INTO l_num_org_id
              FROM oe_order_headers_all
             WHERE     header_id = p_hold_source_tbl (ln_index).header_id
                   AND open_flag = 'Y';

            SELECT COUNT (1)
              INTO l_num_rec_cnt
              FROM oe_order_lines_all
             WHERE     header_id = p_hold_source_tbl (ln_index).header_id
                   AND open_flag = 'Y';

            IF l_num_rec_cnt > 0
            THEN
                l_hold_source_rec   := oe_holds_pvt.g_miss_hold_source_rec;
                l_hold_source_rec.hold_id   :=
                    p_hold_source_tbl (ln_index).hold_id;
                l_hold_source_rec.hold_entity_code   :=
                    p_hold_source_tbl (ln_index).hold_entity_code;
                l_hold_source_rec.hold_entity_id   :=
                    p_hold_source_tbl (ln_index).hold_entity_id;
                l_hold_source_rec.header_id   :=
                    p_hold_source_tbl (ln_index).header_id;
                l_hold_source_rec.line_id   :=
                    p_hold_source_tbl (ln_index).line_id;
                get_resp_details (l_num_org_id, 'ONT', l_num_resp_id,
                                  l_num_resp_appl_id);
                apps.fnd_global.apps_initialize (
                    user_id        => gn_user_id,
                    resp_id        => l_num_resp_id,
                    resp_appl_id   => l_num_resp_appl_id);
                mo_global.init ('ONT');
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_init_msg_list      => fnd_api.g_true,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_none,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => ln_msg_count,
                    x_msg_data           => lv_msg_data,
                    x_return_status      => lv_return_status);

                IF lv_return_status <> fnd_api.g_ret_sts_success
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           p_hold_source_tbl (ln_index).hold_name
                        || ' is not reapplied on the order - header Id: '
                        || p_hold_source_tbl (ln_index).header_id);

                    FOR ln_msg_cntr IN 1 .. ln_msg_count
                    LOOP
                        fnd_msg_pub.get (
                            p_msg_index       => ln_msg_cntr,
                            p_encoded         => 'F',
                            p_data            => lv_msg_data,
                            p_msg_index_out   => ln_msg_index_out);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Error Message: ' || lv_msg_data);
                    END LOOP;

                    pv_retcode   := '2';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           p_hold_source_tbl (ln_index).hold_name
                        || ' is reapplied successfully on the order - header Id: '
                        || p_hold_source_tbl (ln_index).header_id);
                END IF;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       p_hold_source_tbl (ln_index).hold_name
                    || ' is not reapplied since no open lines in the order - header Id: '
                    || p_hold_source_tbl (ln_index).header_id);
            END IF;
        END LOOP;

        COMMIT;                                           --Added on 10Jul2019
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at reapply hold procedure : ' || pv_errbuf);
    END reapply_holds;

    -- ***************************************************************************
    -- Procedure Name      :  release_holds
    --
    -- Description         :  This procedure is to release the order holds before ship confirm
    --
    -- Parameters          : pv_errbuf      OUT : Error message
    --                              pv_retcode     OUT : Execution status
    --                             p_io_hold_source_tbl   IN OUT :  Hold Ids
    --                             pn_header_id     IN  : Order header Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01   Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE release_holds (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, p_io_hold_source_tbl IN OUT g_hold_source_tbl_type
                             , pn_header_id IN NUMBER)
    IS
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (300);
        lv_return_status     VARCHAR2 (1);
        lv_message           VARCHAR2 (2000);
        lv_message1          VARCHAR2 (2000);
        ln_msg_index_out     NUMBER;
        l_num_org_id         NUMBER;
        l_num_resp_id        NUMBER;
        l_num_resp_appl_id   NUMBER;
        l_hold_release_rec   oe_holds_pvt.hold_release_rec_type;
        l_hold_source_rec    oe_holds_pvt.hold_source_rec_type;

        CURSOR cur_holds (p_num_header_id IN NUMBER)
        IS
            SELECT DECODE (hold_srcs.hold_entity_code,  'S', 'Ship-To',  'B', 'Bill-To',  'I', 'Item',  'W', 'Warehouse',  'O', 'Order',  'C', 'Customer',  hold_srcs.hold_entity_code) AS hold_type, hold_defs.NAME AS hold_name, hold_defs.type_code,
                   holds.header_id, holds.org_id hold_org_id, holds.line_id,
                   hold_srcs.*
              FROM oe_hold_definitions hold_defs, oe_hold_sources_all hold_srcs, oe_order_holds_all holds
             WHERE     hold_srcs.hold_source_id = holds.hold_source_id
                   AND hold_defs.hold_id = hold_srcs.hold_id
                   AND holds.header_id = p_num_header_id
                   AND holds.released_flag = 'N';
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';

        FOR holds_rec IN cur_holds (pn_header_id)
        LOOP
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT + 1).hold_id   :=
                holds_rec.hold_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_entity_code   :=
                holds_rec.hold_entity_code;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_entity_id   :=
                holds_rec.hold_entity_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).header_id   :=
                holds_rec.header_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).line_id   :=
                holds_rec.line_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_type   :=
                holds_rec.hold_type;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_name   :=
                holds_rec.hold_name;
            l_hold_source_rec.hold_id            := holds_rec.hold_id;
            l_hold_source_rec.hold_entity_code   :=
                holds_rec.hold_entity_code;
            l_hold_source_rec.hold_entity_id     := holds_rec.hold_entity_id;
            l_hold_release_rec.hold_source_id    := holds_rec.hold_source_id;

            IF holds_rec.type_code = 'CREDIT'
            THEN
                l_hold_release_rec.release_reason_code   :=
                    gv_ar_release_reason;
            ELSE
                l_hold_release_rec.release_reason_code   :=
                    gv_om_release_reason;
            END IF;

            l_hold_release_rec.release_comment   :=
                'Auto-release for ship-confirm.';
            l_hold_release_rec.request_id        :=
                NVL (fnd_global.conc_request_id, -100);
            get_resp_details (holds_rec.hold_org_id, 'ONT', l_num_resp_id,
                              l_num_resp_appl_id);
            apps.fnd_global.apps_initialize (
                user_id        => gn_user_id,
                resp_id        => l_num_resp_id,
                resp_appl_id   => l_num_resp_appl_id);
            mo_global.init ('ONT');
            oe_holds_pub.release_holds (
                p_api_version        => 1.0,
                p_init_msg_list      => fnd_api.g_true,
                p_commit             => fnd_api.g_false,
                p_validation_level   => fnd_api.g_valid_level_none,
                p_hold_source_rec    => l_hold_source_rec,
                p_hold_release_rec   => l_hold_release_rec,
                x_msg_count          => ln_msg_count,
                x_msg_data           => lv_msg_data,
                x_return_status      => lv_return_status);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       holds_rec.hold_name
                    || ' is not released from the order - header Id: '
                    || holds_rec.header_id);

                FOR ln_msg_cntr IN 1 .. ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || lv_msg_data);
                END LOOP;

                pv_retcode   := '2';
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       holds_rec.hold_name
                    || ' is released successfully from the order - header Id: '
                    || holds_rec.header_id);
            END IF;

            fnd_msg_pub.delete_msg ();
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_errbuf    := SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at release hold procedure : ' || pv_errbuf);
    END release_holds;

    -- ***************************************************************************
    -- Procedure Name      :  update_trip
    --
    -- Description         :  This procedure is to update the trip name when there is any error
    --
    -- Parameters          : pv_errbuf      OUT : Error message
    --                              pv_retcode     OUT : Execution status
    --                              pn_trip_id            IN  : Trip Id
    --                              pv_trip_name         IN  :  Trip Name
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2019/05/01    Kranthi Bollam      1.0      Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE update_trip (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pn_trip_id IN VARCHAR2
                           , pv_trip_name IN VARCHAR2)
    IS
        lv_return_status   VARCHAR2 (30) := NULL;
        ln_msg_count       NUMBER;
        ln_msg_cntr        NUMBER;
        ln_msg_index_out   NUMBER;
        lv_msg_data        VARCHAR2 (2000);
        ln_trip_id         NUMBER;
        lv_trip_name       VARCHAR2 (240);
        ln_carrier_id      NUMBER := NULL;
        l_rec_trip_info    wsh_trips_pub.trip_pub_rec_type;
    BEGIN
        --Reset status variables
        pv_errbuf                 := NULL;
        pv_retcode                := '0';
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling CREATE_UPDATE_TRIP API...');
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG, 'Trip Name      : ' || pv_trip_name);
        fnd_file.put_line (fnd_file.LOG, ' ');
        l_rec_trip_info.NAME      := pv_trip_name;
        l_rec_trip_info.trip_id   := pn_trip_id;
        wsh_trips_pub.create_update_trip (
            p_api_version_number   => gn_api_version_number,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => lv_return_status,
            x_msg_count            => ln_msg_count,
            x_msg_data             => lv_msg_data,
            p_action_code          => 'UPDATE',
            p_trip_info            => l_rec_trip_info,
            x_trip_id              => ln_trip_id,
            x_trip_name            => lv_trip_name);

        IF lv_return_status <> fnd_api.g_ret_sts_success
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                'API to update trip failed with status: ' || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);

            IF ln_msg_count > 0
            THEN
                -- Retrieve messages
                ln_msg_cntr   := 1;

                WHILE ln_msg_cntr <= ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    ln_msg_cntr   := ln_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || lv_msg_data);
                END LOOP;

                pv_errbuf     := lv_msg_data;
            END IF;
        ELSE
            pv_retcode   := '0';
            pv_errbuf    :=
                   'API to update trip was successful with status: '
                || lv_return_status;
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Trip ID > '
                || TO_CHAR (ln_trip_id)
                || ': Trip Name > '
                || pv_trip_name);
        END IF;

        -- Reset stop seq number
        fnd_file.put_line (fnd_file.LOG,
                           'End Calling CREATE_UPDATE_TRIP API...');
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '2';
            pv_errbuf    :=
                   'Unexpected error occurred in the Updation of Trip while updating trip for Shipment Number: '
                || pv_trip_name
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error occurred in the Updation of Trip while updating trip for Shipment Number: '
                || pv_trip_name
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END update_trip;

    /*

    Procedure Interface_EDI_ASNs
    This procedure is used to insert ASN entries. Various scenarios are listed below:

    Scenario 1:Wholesale shipment ? everything goes to DC
        a.In this case HJ will group them based on DC, so we will be getting one BOL for the consolidate shipment
        b.One ASN will be created for each BOL
        c.In this case SHIP_TO_ORG_ID could be any store that points to the same DC.

    Scenario 2:Wholesale shipments that are going to individual stores via DC
        a.This will be same as scenario 1 in HJ system (for now this is the understanding)

    Scenario 3:Wholesale shipments that are going to individual stores directly
        a.Each shipment will have its own BOL
        b.Individual ASN will be created for each BOL at (Customer, Ship-To) level

    Scenario 4:Parcel shipments
        a.Create ASN for each (Customer, Ship-to) combination, with Parcel Tracking number
        b.If there are multiple parcels are there in the shipment for same (customer, ship-to), lowest one will be populated as ASN tracking number

    In all these cases ASN needs to be brand specific. If there are Pick Tickets for different brands, ASNs need to be further break down based on brand.

    Change 2.14 - CCR0007332 - For a given shipment file received through HJ, currently the interface creates the EDI records based on the ship to grouping logic.
         DTC orders gets shipped based on deliver to address. This causes improper grouping and creation of EDI.
         The interface needs to create EDI based on the Deliver to location.
    Change 2.15 - CCR0007775 - Fixed a defect caused by CCR0007332 where in Deliver to Org condition was missing while getting tracking number.
                 So added deliver to org condition while getting tracking number for EDI orders

    */
    PROCEDURE interface_edi_asns (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_shipment_no IN VARCHAR2)
    IS
        l_num_shipment_id      NUMBER;
        l_chr_bol_number       VARCHAR2 (50);    /* Modified for CCR0006947 */
        l_chr_record_exists    VARCHAR2 (1);
        l_num_derived_del_id   NUMBER;
        l_num_of_picktickets   NUMBER;
        l_num_ship_to_org_id   NUMBER;
        l_chr_tracking_num     VARCHAR2 (50);
        l_chr_trailer_number   VARCHAR2 (50);       /* Added for CCR0006947 */
        l_chr_seal_number      VARCHAR2 (50);       /* Added for CCR0006947 */

        CURSOR cur_customer_picktickets IS
              SELECT ooh.sold_to_org_id, ooh.attribute5 brand, hca.account_number,
                     NVL (ool.deliver_to_org_id, 1) deliver_to_org_id
                --Added for change v2.14
                FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                     oe_order_lines_all ool           --Added for change v2.14
               WHERE     ord.shipment_number = pv_shipment_no
                     AND ord.order_header_id = ooh.header_id
                     AND ooh.sold_to_org_id = hca.cust_account_id
                     AND EXISTS
                             (SELECT 1
                                FROM fnd_lookup_values flv
                               WHERE     lookup_type = 'XXDO_EDI_CUSTOMERS'
                                     AND flv.LANGUAGE = 'US'
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.lookup_code = hca.account_number)
                     AND ooh.header_id = ool.header_id --Added for change v2.14
            GROUP BY ooh.sold_to_org_id, ooh.attribute5, hca.account_number,
                     NVL (ool.deliver_to_org_id, 1)   --Added for change v2.14
                                                   ;

        CURSOR cur_picktickets (p_num_sold_to_org_id IN NUMBER, p_chr_brand IN VARCHAR2, p_deliver_to_org_id IN NUMBER --Added for change v2.14
                                                                                                                      )
        IS
            SELECT DISTINCT                  --Added DISTINCT for change v2.14
                            ord.*
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, oe_order_lines_all ool --Added for change v2.14
                                                                                                     ,
                   wsh_delivery_assignments wda       --Added for change v2.14
                                               , wsh_delivery_details wdd --Added for change v2.14
             WHERE     ord.shipment_number = pv_shipment_no
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = p_num_sold_to_org_id
                   AND ooh.attribute5 = p_chr_brand
                   AND ooh.header_id = ool.header_id
                   AND NVL (ool.deliver_to_org_id, 1) =
                       NVL (p_deliver_to_org_id, 1)
                   --Added for change v2.14
                   AND NVL (ord.delivery_id, ord.order_number) =
                       wda.delivery_id
                   --Added for change v2.14
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   --Added for change v2.14
                   AND wdd.source_code = 'OE'         --Added for change v2.14
                   AND wdd.source_line_id = ool.line_id --Added for change v2.14
                                                       ;

        CURSOR cur_customer_picktickets_track IS
            SELECT DISTINCT ooh.sold_to_org_id --ooh.ship_to_org_id,  -- Commented EDI856_SHIP_TO_ORG
                                              ,
                            (SELECT ool.ship_to_org_id
                               FROM apps.oe_order_lines_all ool, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                              WHERE     ooh.header_id = ool.header_id
                                    AND ool.line_id = wdd.source_line_id
                                    AND wdd.source_code = 'OE'
                                    AND wdd.delivery_detail_id =
                                        wda.delivery_detail_id
                                    AND wda.delivery_id = ord.order_number
                                    AND ROWNUM = 1) ship_to_org_id -- Added EDI856_SHIP_TO_ORG
                                                                  ,
                            hca.account_number,
                            ooh.attribute5 brand,
                            NVL (ool.deliver_to_org_id, 1) deliver_to_org_id
              --Added for change v2.14
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts hca,
                   oe_order_lines_all ool             --Added for change v2.14
             WHERE     ord.shipment_number = pv_shipment_no
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = hca.cust_account_id
                   AND EXISTS
                           (SELECT 1
                              FROM fnd_lookup_values flv
                             WHERE     lookup_type = 'XXDO_EDI_CUSTOMERS'
                                   AND flv.LANGUAGE = 'US'
                                   AND flv.enabled_flag = 'Y'
                                   AND flv.lookup_code = hca.account_number)
                   AND ooh.header_id = ool.header_id  --Added for change v2.14
                                                    ;

        -- Commented EDI856_SHIP_TO_ORG
        --GROUP BY ooh.sold_to_org_id,
        --        ooh.ship_to_org_id,
        --        hca.account_number,
        --      ooh.attribute5;
        -- Commented EDI856_SHIP_TO_ORG
        CURSOR cur_picktickets_track (p_num_sold_to_org_id IN NUMBER, p_num_ship_to_org_id IN NUMBER, p_chr_brand IN VARCHAR2
                                      , p_deliver_to_org_id IN NUMBER --Added for change v2.14
                                                                     )
        IS
            SELECT ooh.sold_to_org_id, ord.*
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh
             WHERE     ord.shipment_number = pv_shipment_no
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = p_num_sold_to_org_id
                   AND ooh.attribute5 = p_chr_brand
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all ool, apps.wsh_delivery_details wdd, apps.wsh_delivery_assignments wda
                             WHERE     ooh.header_id = ool.header_id
                                   AND ool.line_id = wdd.source_line_id
                                   AND wdd.source_code = 'OE'
                                   AND wdd.delivery_detail_id =
                                       wda.delivery_detail_id
                                   AND wda.delivery_id = ord.order_number
                                   AND ool.ship_to_org_id =
                                       p_num_ship_to_org_id
                                   AND NVL (ool.deliver_to_org_id, 1) =
                                       NVL (p_deliver_to_org_id, 1) --Added for change v2.14
                                                                   );
    BEGIN
        pv_errbuf    := NULL;
        pv_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG,
                           'Interfacing the shipments to EDI tables');

        /* update carrier code in attribute2 of WND - WND_ATTRIBUTE2 */
        UPDATE wsh_new_deliveries
           SET attribute2   =
                   (SELECT h.carrier
                      FROM apps.xxdo_ont_ship_conf_head_stg h
                     WHERE h.shipment_number = pv_shipment_no)
         --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
         WHERE     name IN (SELECT order_number        -- Added as per ver 1.3
                              FROM apps.xxdo_ont_ship_conf_order_stg
                             WHERE shipment_number = pv_shipment_no)
               AND attribute2 IS NULL;

        /* CUST_LOAD_ID - Start */
        UPDATE wsh_new_deliveries
           SET attribute15   =
                   (SELECT h.customer_load_id
                      FROM apps.xxdo_ont_ship_conf_head_stg h
                     WHERE h.shipment_number = pv_shipment_no)
         --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
         WHERE     name IN (SELECT order_number        -- Added as per ver 1.3
                              FROM apps.xxdo_ont_ship_conf_order_stg
                             WHERE shipment_number = pv_shipment_no)
               AND attribute15 IS NULL;

        /* CUST_LOAD_ID - End */
        /* Modified for CCR0006947 */
        BEGIN
            l_chr_bol_number       := NULL;
            l_chr_seal_number      := NULL;
            l_chr_trailer_number   := NULL;

            SELECT seal_number, bol_number, trailer_number
              INTO l_chr_seal_number, l_chr_bol_number, l_chr_trailer_number
              FROM apps.xxdo_ont_ship_conf_head_stg
             WHERE shipment_number = pv_shipment_no;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                pv_errbuf    := 'Shipment Number does not exists';
                pv_retcode   := '2';
            WHEN TOO_MANY_ROWS
            THEN
                pv_errbuf    := 'Duplicate Shipment records found';
                pv_retcode   := '2';
            WHEN OTHERS
            THEN
                pv_errbuf    :=
                    'Unexpected error while deriving BOL no : ' || SQLERRM;
                pv_retcode   := '2';
        END;

        IF    l_chr_bol_number IS NOT NULL
           OR l_chr_seal_number IS NOT NULL
           OR l_chr_tracking_num IS NOT NULL
        THEN
            /*
            If BOL number is available at shipment level, it will be LTL shipment. All pick tickets for a particular customer
            will be going to same address. This will cover Scenario 1, Scenario 2 and Scenario 3:

            In this case single ASN will be generated for all pick tickets for a particular customer. If Brand is different then
            ASN need to be split by brand.
            */
            fnd_file.put_line (fnd_file.LOG,
                               'BOL Exists : ' || l_chr_bol_number);

            /*WAYBILL_NUM*/
            /* Modified for CCR0006947 */
            UPDATE wsh_new_deliveries
               SET waybill = l_chr_bol_number, attribute6 = l_chr_trailer_number
             --WHERE delivery_id IN (SELECT NVL (delivery_id, order_number)   -- Commented as per ver 1.3
             WHERE     name IN (SELECT order_number    -- Added as per ver 1.3
                                  FROM apps.xxdo_ont_ship_conf_order_stg
                                 WHERE shipment_number = pv_shipment_no)
                   AND waybill IS NULL;

            /* Added for CCR0006947 */
            UPDATE wsh_delivery_details
               SET seal_code   = l_chr_seal_number
             WHERE delivery_detail_id IN
                       (SELECT wda.delivery_detail_id
                          FROM wsh_delivery_assignments wda, wsh_new_deliveries wnd -- Added as per ver 1.3
                         -- WHERE wda.delivery_id IN (                -- Commented as per ver 1.3
                         WHERE     wnd.delivery_id = wda.delivery_id -- Added as per ver 1.3
                               AND wnd.name IN
                                       (               -- Added as per ver 1.3
                                        --SELECT NVL (delivery_id, order_number)    -- Commented as per ver 1.3
                                        SELECT order_number -- Added as per ver 1.3
                                          FROM apps.xxdo_ont_ship_conf_order_stg
                                         WHERE shipment_number =
                                               pv_shipment_no));

            /* BOL_TRACK_NO - Start */
            UPDATE wsh_delivery_details
               SET tracking_number   = l_chr_bol_number
             WHERE     tracking_number IS NULL
                   AND delivery_detail_id IN
                           (SELECT wda.delivery_detail_id
                              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda
                             WHERE     wnd.delivery_id = wda.delivery_id
                                   --AND wnd.delivery_id IN (                                      -- Commented as per ver 1.3
                                   --SELECT NVL (delivery_id, order_number)      -- Commented as per ver 1.3
                                   AND name IN
                                           (SELECT order_number -- Added as per ver 1.3
                                              FROM apps.xxdo_ont_ship_conf_order_stg
                                             WHERE shipment_number =
                                                   pv_shipment_no));

            /* BOL_TRACK_NO - End */
            COMMIT;

            FOR customer_picktickets_rec IN cur_customer_picktickets
            LOOP
                l_num_shipment_id      := NULL;
                --- Get next shipment id
                do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                        1,
                                        l_num_shipment_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Shipment id for EDI tables: ' || l_num_shipment_id);

                INSERT INTO do_edi.do_edi856_shipments (shipment_id,
                                                        asn_status,
                                                        asn_date,
                                                        invoice_date,
                                                        customer_id,
                                                        ship_to_org_id,
                                                        waybill,
                                                        seal_code,
                                                        /* Modified for CCR0006947 */
                                                        trailer_number, /* Modified for CCR0006947 */
                                                        tracking_number,
                                                        pro_number,
                                                        est_delivery_date,
                                                        creation_date,
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        archive_flag,
                                                        organization_id,
                                                        location_id,
                                                        request_sent_date,
                                                        reply_rcv_date,
                                                        scheduled_pu_date,
                                                        bill_of_lading,
                                                        carrier,
                                                        carrier_scac,
                                                        comments,
                                                        confirm_sent_date,
                                                        contact_name,
                                                        cust_shipment_id,
                                                        earliest_pu_date,
                                                        latest_pu_date,
                                                        load_id,
                                                        routing_status,
                                                        ship_confirm_date,
                                                        shipment_weight,
                                                        shipment_weight_uom)
                    SELECT l_num_shipment_id,
                           'R',                                  -- ASN Status
                           NULL,                                    --ASN Date
                           NULL,                                --Invoice date
                           customer_picktickets_rec.sold_to_org_id,
                           -1,
                           /* ship to org id is inserted -1 first and updated later */
                           l_chr_bol_number
                               waybill,          /* Modified for CCR0006947 */
                           l_chr_seal_number,
                           /* Modified for CCR0006947 */
                           l_chr_trailer_number, /* Modified for CCR0006947 */
                           NULL
                               tracking_number,
                           head.pro_number,
                           head.ship_date + 3
                               est_delivery_date,
                           SYSDATE
                               creation_date,
                           gn_user_id
                               created_by,
                           SYSDATE
                               last_update_date,
                           gn_user_id
                               last_updated_by,
                           'N'
                               archive_flag,
                           (SELECT organization_id
                              FROM mtl_parameters mp
                             WHERE mp.organization_code = head.wh_id)
                               ship_from_org_id,
                           -1
                               location_id,
                           NULL
                               request_sent_date,
                           NULL
                               reply_rcv_date,
                           NULL
                               scheduled_pu_date,
                           NULL
                               bill_of_lading,
                           head.carrier,
                           (SELECT scac_code
                              FROM wsh_carriers_v
                             WHERE freight_code = head.carrier)
                               carrier_scac,
                           head.comments,
                           NULL
                               confirm_sent_date,
                           NULL
                               contact_name,
                           NULL
                               cust_shipment_id,
                           NULL
                               earliest_pu_date,
                           NULL
                               latest_pu_date,
                           SUBSTR (head.customer_load_id, 1, 10)
                               load_id,
                           NULL
                               routing_status,
                           head.ship_date
                               ship_confirm_date,
                           NULL
                               shipment_weight,
                           'LB'
                               shipment_weight_uom
                      FROM xxdo_ont_ship_conf_head_stg head
                     WHERE     head.shipment_number = pv_shipment_no
                           AND head.process_status = 'PROCESSED';

                l_num_of_picktickets   := 0;
                l_num_ship_to_org_id   := NULL;

                FOR picktickets_rec
                    IN cur_picktickets (
                           customer_picktickets_rec.sold_to_org_id,
                           customer_picktickets_rec.brand,
                           customer_picktickets_rec.deliver_to_org_id --Added for change v2.14
                                                                     )
                LOOP
                    IF l_num_ship_to_org_id IS NULL
                    THEN
                        l_num_ship_to_org_id   :=
                            picktickets_rec.ship_to_org_id;

                        /* update ship to org ID on ASN header only once. Any ship-to in this shipment is fine*/
                        UPDATE do_edi.do_edi856_shipments
                           SET ship_to_org_id   = l_num_ship_to_org_id
                         WHERE     shipment_id = l_num_shipment_id
                               AND ship_to_org_id = -1;
                    END IF;

                    l_num_derived_del_id   :=
                        NVL (picktickets_rec.delivery_id,
                             picktickets_rec.order_number);
                    --- To check whether the delivery is already interfaced
                    l_chr_record_exists   := 'N';

                    BEGIN
                        SELECT 'Y'
                          INTO l_chr_record_exists
                          FROM do_edi.do_edi856_pick_tickets
                         WHERE delivery_id = l_num_derived_del_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_record_exists   := 'N';
                    END;

                    IF l_chr_record_exists = 'N'
                    THEN
                        INSERT INTO do_edi.do_edi856_pick_tickets (
                                        shipment_id,
                                        delivery_id,
                                        weight,
                                        weight_uom,
                                        number_cartons,
                                        cartons_uom,
                                        volume,
                                        volume_uom,
                                        ordered_qty,
                                        shipped_qty,
                                        shipped_qty_uom,
                                        source_header_id,
                                        intmed_ship_to_org_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        archive_flag,
                                        shipment_key)
                              SELECT l_num_shipment_id,
                                     l_num_derived_del_id,
                                     --SUM(NVL(carton.weight, 0))
                                     (SELECT SUM (NVL (cartoni.weight, 0))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 pv_shipment_no
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         weight,
                                     'LB'
                                         weight_uom,
                                     COUNT (DISTINCT carton.carton_number)
                                         number_cartons,
                                     'EA'
                                         cartons_uom,
                                     (SELECT SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 pv_shipment_no
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         volume,
                                     'CI'
                                         volume_uom,
                                     SUM (qty)
                                         ordered_qty,
                                     SUM (qty)
                                         shipped_qty,
                                     'EA'
                                         shipped_qty_uom,
                                     ord.order_header_id
                                         source_header_id,
                                     NULL
                                         intmed_ship_to_org_id,
                                     SYSDATE
                                         creation_date,
                                     gn_user_id
                                         created_by,
                                     SYSDATE
                                         last_update_date,
                                     gn_user_id
                                         last_updated_by,
                                     'N'
                                         archive_flag,
                                     (SELECT l_num_shipment_id || brand_code
                                        FROM do_custom.do_brands db, mtl_parameters mp, mtl_system_items_kfv msi,
                                             mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets mcs,
                                             xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni, xxdo_ont_ship_conf_cardtl_stg cardtli
                                       WHERE     msi.concatenated_segments =
                                                 cardtli.item_number
                                             AND msi.organization_id =
                                                 mic.organization_id
                                             AND msi.inventory_item_id =
                                                 mic.inventory_item_id
                                             AND mcs.category_set_id =
                                                 mic.category_set_id
                                             AND mcs.category_set_id = 1
                                             AND mc.category_id =
                                                 mic.category_id
                                             AND UPPER (mc.segment1) =
                                                 db.brand_name
                                             AND mp.organization_code =
                                                 ord.wh_id
                                             AND mp.organization_id =
                                                 msi.organization_id
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 pv_shipment_no
                                             AND cartoni.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cardtli.process_status =
                                                 'PROCESSED'
                                             AND cardtli.shipment_number =
                                                 ordi.shipment_number
                                             AND cardtli.order_number =
                                                 ordi.order_number
                                             AND cardtli.carton_number =
                                                 cartoni.carton_number
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ROWNUM < 2)
                                         shipment_key
                                FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
                               WHERE     ord.shipment_number = pv_shipment_no
                                     AND ord.process_status = 'PROCESSED'
                                     AND ord.shipment_number =
                                         carton.shipment_number
                                     AND ord.order_number = carton.order_number
                                     AND carton.process_status = 'PROCESSED'
                                     AND cardtl.shipment_number =
                                         ord.shipment_number
                                     AND cardtl.order_number = ord.order_number
                                     AND cardtl.carton_number =
                                         carton.carton_number
                                     AND cardtl.process_status = 'PROCESSED'
                                     AND ord.order_number =
                                         picktickets_rec.order_number
                            GROUP BY ord.order_number, ord.order_header_id, ord.wh_id;

                        UPDATE xxdo_ont_ship_conf_order_stg
                           SET attribute1   = l_num_shipment_id
                         WHERE     order_number =
                                   picktickets_rec.order_number
                               AND shipment_number = pv_shipment_no;

                        l_num_of_picktickets   := l_num_of_picktickets + 1;
                    END IF;
                END LOOP;

                IF l_num_of_picktickets > 0
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;
        ELSE
            /* Bol number does not exists, parcel shipments.
               Create individual ASNs for each (customer, ship-to, brand) combination. populate minimum tracking number at ASN level
             */
            FOR customer_track_rec IN cur_customer_picktickets_track
            LOOP
                l_num_shipment_id      := NULL;
                --- Get next shipment id
                do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                        1,
                                        l_num_shipment_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Shipment id for EDI tables: ' || l_num_shipment_id);
                l_chr_tracking_num     := NULL;

                BEGIN
                    SELECT MIN (tracking_number)
                      INTO l_chr_tracking_num
                      FROM xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh,
                           oe_order_lines_all ool     --Added for change v2.15
                     WHERE     ord.shipment_number = pv_shipment_no
                           AND carton.shipment_number = pv_shipment_no
                           AND carton.order_number = ord.order_number
                           AND ord.order_header_id = ooh.header_id
                           AND ooh.attribute5 = customer_track_rec.brand
                           AND ooh.sold_to_org_id =
                               customer_track_rec.sold_to_org_id
                           --AND ooh.ship_to_org_id = customer_track_rec.ship_to_org_id --Commented code on 29Jun2019 as this should refer line ship to org
                           AND ool.ship_to_org_id =
                               customer_track_rec.ship_to_org_id
                           --Added code on 29Jun2019 as this should refer line ship to org
                           AND carton.tracking_number IS NOT NULL
                           AND ooh.header_id = ool.header_id --Added for change v2.15
                           AND NVL (ool.deliver_to_org_id, 1) =
                               NVL (customer_track_rec.deliver_to_org_id, 1) --Added for change v2.15
                                                                            ;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_chr_tracking_num   := NULL;
                END;

                IF l_chr_tracking_num IS NULL
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Tracking number is not available for shipment :'
                        || pv_shipment_no
                        || ' and account number: '
                        || customer_track_rec.account_number);
                END IF;

                INSERT INTO do_edi.do_edi856_shipments (shipment_id,
                                                        asn_status,
                                                        asn_date,
                                                        invoice_date,
                                                        customer_id,
                                                        ship_to_org_id,
                                                        waybill,
                                                        seal_code,
                                                        /* Added for CCR0006947 */
                                                        trailer_number, /* Added for CCR0006947 */
                                                        tracking_number,
                                                        pro_number,
                                                        est_delivery_date,
                                                        creation_date,
                                                        created_by,
                                                        last_update_date,
                                                        last_updated_by,
                                                        archive_flag,
                                                        organization_id,
                                                        location_id,
                                                        request_sent_date,
                                                        reply_rcv_date,
                                                        scheduled_pu_date,
                                                        bill_of_lading,
                                                        carrier,
                                                        carrier_scac,
                                                        comments,
                                                        confirm_sent_date,
                                                        contact_name,
                                                        cust_shipment_id,
                                                        earliest_pu_date,
                                                        latest_pu_date,
                                                        load_id,
                                                        routing_status,
                                                        ship_confirm_date,
                                                        shipment_weight,
                                                        shipment_weight_uom)
                    SELECT l_num_shipment_id,
                           'R',                                  -- ASN Status
                           NULL,                                    --ASN Date
                           NULL,                                --Invoice date
                           customer_track_rec.sold_to_org_id,
                           customer_track_rec.ship_to_org_id,
                           NULL
                               waybill,
                           NULL,
                           NULL,
                           l_chr_tracking_num,
                           head.pro_number,
                           head.ship_date + 3
                               est_delivery_date,
                           SYSDATE
                               creation_date,
                           gn_user_id
                               created_by,
                           SYSDATE
                               last_update_date,
                           gn_user_id
                               last_updated_by,
                           'N'
                               archive_flag,
                           (SELECT organization_id
                              FROM mtl_parameters mp
                             WHERE mp.organization_code = head.wh_id)
                               ship_from_org_id,
                           -1
                               location_id,
                           NULL
                               request_sent_date,
                           NULL
                               reply_rcv_date,
                           NULL
                               scheduled_pu_date,
                           NULL
                               bill_of_lading,
                           head.carrier,
                           (SELECT scac_code
                              FROM wsh_carriers_v
                             WHERE freight_code = head.carrier)
                               carrier_scac,
                           head.comments,
                           NULL
                               confirm_sent_date,
                           NULL
                               contact_name,
                           NULL
                               cust_shipment_id,
                           NULL
                               earliest_pu_date,
                           NULL
                               latest_pu_date,
                           SUBSTR (head.customer_load_id, 1, 10)
                               load_id,
                           NULL
                               routing_status,
                           head.ship_date
                               ship_confirm_date,
                           NULL
                               shipment_weight,
                           'LB'
                               shipment_weight_uom
                      FROM xxdo_ont_ship_conf_head_stg head
                     WHERE     head.shipment_number = pv_shipment_no
                           AND head.process_status = 'PROCESSED';

                l_num_of_picktickets   := 0;

                FOR picktickets_track_rec
                    IN cur_picktickets_track (
                           customer_track_rec.sold_to_org_id,
                           customer_track_rec.ship_to_org_id,
                           customer_track_rec.brand,
                           customer_track_rec.deliver_to_org_id --Added for change v2.14
                                                               )
                LOOP
                    l_num_derived_del_id   :=
                        NVL (picktickets_track_rec.delivery_id,
                             picktickets_track_rec.order_number);

                    --- To check whether the delivery is already interfaced
                    BEGIN
                        SELECT 'Y'
                          INTO l_chr_record_exists
                          FROM do_edi.do_edi856_pick_tickets
                         WHERE delivery_id = l_num_derived_del_id;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_record_exists   := 'N';
                    END;

                    IF l_chr_record_exists = 'N'
                    THEN
                        INSERT INTO do_edi.do_edi856_pick_tickets (
                                        shipment_id,
                                        delivery_id,
                                        weight,
                                        weight_uom,
                                        number_cartons,
                                        cartons_uom,
                                        volume,
                                        volume_uom,
                                        ordered_qty,
                                        shipped_qty,
                                        shipped_qty_uom,
                                        source_header_id,
                                        intmed_ship_to_org_id,
                                        creation_date,
                                        created_by,
                                        last_update_date,
                                        last_updated_by,
                                        archive_flag,
                                        shipment_key)
                              SELECT l_num_shipment_id,
                                     l_num_derived_del_id,
                                     --SUM(NVL(carton.weight, 0))
                                     (SELECT SUM (NVL (cartoni.weight, 0))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 pv_shipment_no
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         weight,
                                     'LB'
                                         weight_uom,
                                     COUNT (DISTINCT carton.carton_number)
                                         number_cartons,
                                     'EA'
                                         cartons_uom,
                                     (SELECT SUM (NVL (cartoni.LENGTH, 1) * NVL (cartoni.width, 1) * NVL (cartoni.height, 1))
                                        FROM xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni
                                       WHERE     1 = 1
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ordi.shipment_number =
                                                 pv_shipment_no
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED')
                                         volume,
                                     'CI'
                                         volume_uom,
                                     SUM (qty)
                                         ordered_qty,
                                     SUM (qty)
                                         shipped_qty,
                                     'EA'
                                         shipped_qty_uom,
                                     ord.order_header_id
                                         source_header_id,
                                     NULL
                                         intmed_ship_to_org_id,
                                     SYSDATE
                                         creation_date,
                                     gn_user_id
                                         created_by,
                                     SYSDATE
                                         last_update_date,
                                     gn_user_id
                                         last_updated_by,
                                     'N'
                                         archive_flag,
                                     (SELECT l_num_shipment_id || brand_code
                                        FROM do_custom.do_brands db, mtl_parameters mp, mtl_system_items_kfv msi,
                                             mtl_item_categories mic, mtl_categories_b mc, mtl_category_sets mcs,
                                             xxdo_ont_ship_conf_order_stg ordi, xxdo_ont_ship_conf_carton_stg cartoni, xxdo_ont_ship_conf_cardtl_stg cardtli
                                       WHERE     msi.concatenated_segments =
                                                 cardtli.item_number
                                             AND msi.organization_id =
                                                 mic.organization_id
                                             AND msi.inventory_item_id =
                                                 mic.inventory_item_id
                                             AND mcs.category_set_id =
                                                 mic.category_set_id
                                             AND mcs.category_set_id = 1
                                             AND mc.category_id =
                                                 mic.category_id
                                             AND UPPER (mc.segment1) =
                                                 db.brand_name
                                             AND mp.organization_code =
                                                 ord.wh_id
                                             AND mp.organization_id =
                                                 msi.organization_id
                                             AND ordi.shipment_number =
                                                 pv_shipment_no
                                             AND ordi.process_status =
                                                 'PROCESSED'
                                             AND ordi.shipment_number =
                                                 cartoni.shipment_number
                                             AND ordi.order_number =
                                                 cartoni.order_number
                                             AND cartoni.process_status =
                                                 'PROCESSED'
                                             AND cardtli.shipment_number =
                                                 ordi.shipment_number
                                             AND cardtli.order_number =
                                                 ordi.order_number
                                             AND cardtli.carton_number =
                                                 cartoni.carton_number
                                             AND cardtli.process_status =
                                                 'PROCESSED'
                                             AND ordi.order_number =
                                                 ord.order_number
                                             AND ordi.order_header_id =
                                                 ord.order_header_id
                                             AND ROWNUM < 2)
                                         shipment_key
                                FROM xxdo_ont_ship_conf_order_stg ord, xxdo_ont_ship_conf_carton_stg carton, xxdo_ont_ship_conf_cardtl_stg cardtl
                               WHERE     1 = 1
                                     AND ord.process_status = 'PROCESSED'
                                     AND ord.shipment_number = pv_shipment_no
                                     AND carton.process_status = 'PROCESSED'
                                     AND ord.shipment_number =
                                         carton.shipment_number
                                     AND ord.order_number = carton.order_number
                                     AND cardtl.process_status = 'PROCESSED'
                                     AND cardtl.shipment_number =
                                         ord.shipment_number
                                     AND cardtl.order_number = ord.order_number
                                     AND cardtl.carton_number =
                                         carton.carton_number
                                     AND ord.order_number =
                                         picktickets_track_rec.order_number
                            GROUP BY ord.order_number, ord.order_header_id, ord.wh_id;

                        l_num_of_picktickets   := l_num_of_picktickets + 1;

                        UPDATE xxdo_ont_ship_conf_order_stg
                           SET attribute1   = l_num_shipment_id
                         WHERE     order_number =
                                   picktickets_track_rec.order_number
                               AND shipment_number =
                                   picktickets_track_rec.shipment_number;
                    END IF;
                END LOOP;

                IF l_num_of_picktickets > 0
                THEN
                    COMMIT;
                ELSE
                    ROLLBACK;
                END IF;
            END LOOP;
        END IF;                             -- End of Bol number present check

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_retcode   := '1';
            pv_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at while EDI interfacing : ' || pv_errbuf);
    END interface_edi_asns;

    -- begin 1.7

    PROCEDURE release_holds (p_io_hold_source_tbl IN OUT g_hold_source_tbl_type, p_header_id IN NUMBER, p_status OUT VARCHAR2)
    IS
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (300);
        lv_return_status     VARCHAR2 (1);
        lv_message           VARCHAR2 (2000);
        lv_message1          VARCHAR2 (2000);
        ln_msg_index_out     NUMBER;
        l_num_org_id         NUMBER;
        l_num_resp_id        NUMBER;
        l_num_resp_appl_id   NUMBER;
        l_hold_release_rec   oe_holds_pvt.hold_release_rec_type;
        l_hold_source_rec    oe_holds_pvt.hold_source_rec_type;

        CURSOR cur_holds (p_num_header_id IN NUMBER)
        IS
            SELECT DECODE (hold_srcs.hold_entity_code,  'S', 'Ship-To',  'B', 'Bill-To',  'I', 'Item',  'W', 'Warehouse',  'O', 'Order',  'C', 'Customer',  hold_srcs.hold_entity_code) AS hold_type, hold_defs.NAME AS hold_name, hold_defs.type_code,
                   holds.header_id, holds.org_id hold_org_id, holds.line_id,
                   hold_srcs.*
              FROM oe_hold_definitions hold_defs, oe_hold_sources_all hold_srcs, oe_order_holds_all holds
             WHERE     hold_srcs.hold_source_id = holds.hold_source_id
                   AND hold_defs.hold_id = hold_srcs.hold_id
                   AND holds.header_id = p_num_header_id
                   AND holds.released_flag = 'N';
    BEGIN
        FOR holds_rec IN cur_holds (p_header_id)
        LOOP
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT + 1).hold_id   :=
                holds_rec.hold_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_entity_code   :=
                holds_rec.hold_entity_code;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_entity_id   :=
                holds_rec.hold_entity_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).header_id   :=
                holds_rec.header_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).line_id   :=
                holds_rec.line_id;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_type   :=
                holds_rec.hold_type;
            p_io_hold_source_tbl (p_io_hold_source_tbl.COUNT).hold_name   :=
                holds_rec.hold_name;
            l_hold_source_rec.hold_id            := holds_rec.hold_id;
            l_hold_source_rec.hold_entity_code   :=
                holds_rec.hold_entity_code;
            l_hold_source_rec.hold_entity_id     := holds_rec.hold_entity_id;
            l_hold_release_rec.hold_source_id    := holds_rec.hold_source_id;

            IF holds_rec.type_code = 'CREDIT'
            THEN
                l_hold_release_rec.release_reason_code   :=
                    gv_ar_release_reason;
            ELSE
                l_hold_release_rec.release_reason_code   :=
                    gv_om_release_reason;
            END IF;

            fnd_file.put_line (fnd_file.LOG,
                               'hold released request_id ' || gn_request_id);
            l_hold_release_rec.release_comment   :=
                   'Hold released by system for auto invoicing - '
                || gn_request_id;
            l_hold_release_rec.request_id        := NVL (gn_request_id, -100);
            get_resp_details (holds_rec.hold_org_id, 'ONT', l_num_resp_id,
                              l_num_resp_appl_id);
            apps.fnd_global.apps_initialize (
                user_id        => gn_user_id,
                resp_id        => l_num_resp_id,
                resp_appl_id   => l_num_resp_appl_id);
            mo_global.init ('ONT');
            oe_holds_pub.release_holds (
                p_api_version        => 1.0,
                p_init_msg_list      => fnd_api.g_true,
                p_commit             => fnd_api.g_false,
                p_validation_level   => fnd_api.g_valid_level_none,
                p_hold_source_rec    => l_hold_source_rec,
                p_hold_release_rec   => l_hold_release_rec,
                x_msg_count          => ln_msg_count,
                x_msg_data           => lv_msg_data,
                x_return_status      => lv_return_status);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       holds_rec.hold_name
                    || ' is not released from the order - header Id: '
                    || holds_rec.header_id);

                FOR ln_msg_cntr IN 1 .. ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || lv_msg_data);
                END LOOP;

                p_status   := 'E';
                RETURN; -- if there any issue releasing any single hold out of many, return back to the calling procedure.
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       holds_rec.hold_name
                    || ' is released successfully from the order - header Id: '
                    || holds_rec.header_id);
            END IF;

            fnd_msg_pub.delete_msg ();
            p_status                             := 'S';
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at release hold procedure : ' || SQLERRM);
    END release_holds;

    PROCEDURE retry_inv_interface_activity (p_line_id IN NUMBER)
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;
        l_result   VARCHAR2 (100);
    BEGIN
        apps.oe_standard_wf.oeol_selector (
            p_itemtype   => 'OEOL',
            p_itemkey    => TO_CHAR (p_line_id),
            p_actid      => 12345,
            p_funcmode   => 'SET_CTX',
            p_result     => l_result);
        apps.wf_engine.handleerror ('OEOL', TO_CHAR (p_line_id), 'INVOICE_INTERFACE'
                                    , 'RETRY', '');
        COMMIT;
        l_result   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at rretry_inv_interface_activity : '
                || SQLERRM);
    END retry_inv_interface_activity;

    PROCEDURE aplpy_hold_again (
        p_hold_source_tbl     IN     g_hold_source_tbl_type,
        p_apply_hold_status      OUT VARCHAR2)
    IS
        l_num_rec_cnt        NUMBER;
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1);
        ln_msg_index_out     NUMBER;
        l_num_org_id         NUMBER;
        l_num_resp_id        NUMBER;
        l_num_resp_appl_id   NUMBER;
        l_hold_source_rec    oe_holds_pvt.hold_source_rec_type;
        l_result             VARCHAR2 (240);
    BEGIN
        FOR ln_index IN 1 .. p_hold_source_tbl.COUNT
        LOOP
            SELECT org_id
              INTO l_num_org_id
              FROM oe_order_headers_all
             WHERE     header_id = p_hold_source_tbl (ln_index).header_id
                   AND open_flag = 'Y';

            l_hold_source_rec   := oe_holds_pvt.g_miss_hold_source_rec;
            l_hold_source_rec.hold_id   :=
                p_hold_source_tbl (ln_index).hold_id;
            l_hold_source_rec.hold_entity_code   :=
                p_hold_source_tbl (ln_index).hold_entity_code;
            l_hold_source_rec.hold_entity_id   :=
                p_hold_source_tbl (ln_index).hold_entity_id;
            l_hold_source_rec.header_id   :=
                p_hold_source_tbl (ln_index).header_id;
            l_hold_source_rec.line_id   :=
                p_hold_source_tbl (ln_index).line_id;
            l_hold_source_rec.hold_comment   :=
                   'Hold reapplied by system after auto invoicing - '
                || gn_request_id;
            get_resp_details (l_num_org_id, 'ONT', l_num_resp_id,
                              l_num_resp_appl_id);
            apps.fnd_global.apps_initialize (
                user_id        => gn_user_id,
                resp_id        => l_num_resp_id,
                resp_appl_id   => l_num_resp_appl_id);
            mo_global.init ('ONT');
            fnd_file.put_line (
                fnd_file.LOG,
                'inside  reapply hold fnd request id is ' || gn_request_id);
            oe_holds_pub.apply_holds (
                p_api_version        => 1.0,
                p_init_msg_list      => fnd_api.g_true,
                p_commit             => fnd_api.g_false,
                p_validation_level   => fnd_api.g_valid_level_none,
                p_hold_source_rec    => l_hold_source_rec,
                x_msg_count          => ln_msg_count,
                x_msg_data           => lv_msg_data,
                x_return_status      => lv_return_status);

            IF lv_return_status <> fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       p_hold_source_tbl (ln_index).hold_name
                    || ' is not reapplied on the order - header Id: '
                    || p_hold_source_tbl (ln_index).header_id);

                FOR ln_msg_cntr IN 1 .. ln_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => ln_msg_cntr, p_encoded => 'F', p_data => lv_msg_data
                                     , p_msg_index_out => ln_msg_index_out);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || lv_msg_data);
                END LOOP;

                p_apply_hold_status   := 'E';
                RETURN;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       p_hold_source_tbl (ln_index).hold_name
                    || ' is reapplied successfully on the order - header Id: '
                    || p_hold_source_tbl (ln_index).header_id);
            END IF;
        END LOOP;

        p_apply_hold_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            p_apply_hold_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at reapply hold procedure : ' || SQLERRM);
    END aplpy_hold_again;

    FUNCTION order_has_hold (p_header_id NUMBER)
        RETURN VARCHAR2
    IS
        L_COUNT   NUMBER;
    BEGIN
        -- JUST NEED TO SEE IF ATLEAST ONE HOLD EXISTS
        SELECT COUNT (*)
          INTO L_COUNT
          FROM oe_order_holds_all ooha, oe_hold_sources_all ohsa
         WHERE     1 = 1
               AND ooha.released_flag = 'N'
               AND ooha.hold_source_id = ohsa.hold_source_id
               AND ooha.header_id = p_header_id
               AND ROWNUM = 1;

        IF L_COUNT = 0
        THEN
            RETURN 'N';
        ELSE
            RETURN 'Y';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 'E';
    END order_has_hold;

    -- ***************************************************************************

    PROCEDURE progress_stuck_wf (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, p_org_id IN NUMBER
                                 , p_date_from IN VARCHAR2, p_date_to IN VARCHAR2, p_order_number IN NUMBER)
    IS
        l_hold_source_tbl    g_hold_source_tbl_type;
        l_status             VARCHAR2 (1);
        l_wf_status          VARCHAR2 (1);
        p_reapply_status     VARCHAR2 (1);
        l_hold_excl_count    NUMBER;
        l_flow_status_code   VARCHAR2 (100);

        CURSOR c_get_stuck_order_lines (l_header_id IN NUMBER)
        IS
            (SELECT a.line_id, a.header_id, b.order_number
               FROM oe_order_lines_all A, oe_order_headers_all b
              WHERE     1 = 1
                    AND a.flow_status_code = 'INVOICE_HOLD'
                    AND a.open_flag = 'Y'
                    AND INVOICE_INTERFACE_STATUS_CODE IS NULL
                    AND b.header_id = l_header_id
                    AND a.header_id = b.header_id);

        -- get all hdrs having hold withatleast one line stuck with invoice hold status
        -- this will be used to realease the hold at once for all and then retry the line wf for the lines that are failed to interface
        CURSOR c_get_stuck_headers IS
            SELECT header_id, order_number, order_has_hold (b.header_id) hold_exists,
                   flow_status_code
              FROM oe_order_headers_all b
             WHERE     1 = 1
                   AND b.ORG_ID = p_org_id
                   AND OPEN_FLAG = 'Y'
                   AND order_number = NVL (p_order_number, order_number)
                   AND (   (    p_date_from IS NOT NULL
                            AND p_date_TO IS NOT NULL
                            AND EXISTS
                                    (SELECT 1
                                       FROM wsh_new_deliveries wnd
                                      WHERE     wnd.source_header_id =
                                                b.header_id
                                            AND wnd.creation_date BETWEEN FND_DATE.CANONICAL_TO_DATE (
                                                                              p_date_from)
                                                                      AND FND_DATE.CANONICAL_TO_DATE (
                                                                              p_date_to)))
                        OR (p_date_from IS NULL AND p_date_TO IS NULL))
                   /*  AND EXISTS(
         SELECT 1 from wsh_new_deliveries wnd
         where wnd.source_header_id=b.header_id
         AND ( (p_date_from IS NOT NULL AND p_date_TO IS NOT NULL
               and wnd.creation_date between FND_DATE.CANONICAL_TO_DATE(p_date_from) and FND_DATE.CANONICAL_TO_DATE(p_date_to)
         )
         )
         ) */
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all a
                             WHERE     1 = 1
                                   AND flow_status_code = 'INVOICE_HOLD'
                                   AND open_flag = 'Y'
                                   AND INVOICE_INTERFACE_STATUS_CODE IS NULL
                                   AND a.ORG_ID = p_org_id
                                   AND a.header_id = b.header_id);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'p_order_number: ' || p_order_number);

        fnd_file.put_line (fnd_file.LOG, 'p_org_id: ' || p_org_id);
        fnd_file.put_line (
            fnd_file.LOG,
            'p_date_from: ' || FND_DATE.CANONICAL_TO_DATE (p_date_from));

        fnd_file.put_line (
            fnd_file.LOG,
            'p_date_to: ' || FND_DATE.CANONICAL_TO_DATE (p_date_to));

        FOR header IN c_get_stuck_headers
        LOOP
            IF header.hold_exists = 'Y'
            THEN
                IF l_hold_source_tbl.EXISTS (1)
                THEN
                    l_hold_source_tbl.DELETE;
                END IF;

                -- step1; hold(s) exsits in the order. if more than one hold exists then none of them shuld be present in the exculsion list.
                -- for the wf to reprocess none of the hold should be present in the lookup_code

                SELECT COUNT (*)
                  INTO l_hold_excl_count
                  FROM oe_order_holds_all ooha, oe_hold_sources_all ohsa
                 WHERE     1 = 1
                       AND ooha.released_flag = 'N'
                       AND ooha.hold_source_id = ohsa.hold_source_id
                       AND ooha.header_id = header.header_id
                       AND EXISTS
                               (SELECT *
                                  FROM fnd_lookup_values
                                 WHERE     1 = 1
                                       AND lookup_type =
                                           'XXD_ONT_INV_HOLD_EXCL_CRITERIA'
                                       AND LANGUAGE = 'US'
                                       AND enabled_flag = 'Y'
                                       AND SYSDATE BETWEEN NVL (
                                                               start_date_active,
                                                               SYSDATE)
                                                       AND NVL (
                                                               end_date_active,
                                                               SYSDATE + 1)
                                       AND TO_NUMBER (LOOKUP_CODE) =
                                           ohsa.hold_id);

                IF l_hold_excl_count > 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'order Number : '
                        || header.order_number
                        || ' has hold(s) that exists in the hold exclusion criteria and hence cannot be removed.');
                    CONTINUE;
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Invoking the release hold procedure for the order Number : '
                    || header.order_number);
                -- step1 remove holds(s)
                -- this procedure will return S if and only if all the holds for the given hdr removed successfully
                SAVEPOINT header;
                release_holds (p_io_hold_source_tbl   => l_hold_source_tbl,
                               p_header_id            => header.header_id,
                               p_status               => l_status);

                IF l_status = 'E'
                THEN
                    ROLLBACK TO header;
                    CONTINUE;
                ELSE
                    COMMIT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Completed the release hold procedure for the order Number : '
                        || header.order_number);

                    -- hold release is successful - copy the hold sources into Global hold sources table to reapply the hold later at Shipment level
                    IF l_hold_source_tbl.EXISTS (1)
                    THEN
                        FOR l_num_hold_index IN 1 .. l_hold_source_tbl.COUNT
                        LOOP
                            g_all_hold_source_tbl (
                                g_all_hold_source_tbl.COUNT + 1)   :=
                                l_hold_source_tbl (l_num_hold_index);
                        END LOOP;
                    END IF;                 -- end if l_hold_source_tbl.EXISTS
                END IF;                                      --end if l_status
            END IF;                                      -- end if hold exists

            -- step2  retry wf
            FOR line IN c_get_stuck_order_lines (header.header_id)
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Invoking wf retry for line id : ' || line.line_id);
                retry_inv_interface_activity (line.line_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Completed wf retry for line id : ' || line.line_id);
            END LOOP;                                     -- end loop for line

            -- step3 apply the hold(s) back only when the So iis not closed
            BEGIN
                SELECT flow_status_code
                  INTO l_flow_status_code
                  FROM oe_order_headers_all
                 WHERE order_number = header.order_number;
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;

            IF header.hold_exists = 'Y'
            THEN
                IF l_flow_status_code = 'CLOSED'
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Order Number '
                        || header.order_number
                        || ' is closed and hold cannot be reapplied.');
                    CONTINUE;
                END IF;

                IF g_all_hold_source_tbl.EXISTS (1)
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Invoking reapply_holds procedure for order Number: '
                        || header.order_number);

                    aplpy_hold_again (
                        p_hold_source_tbl     => g_all_hold_source_tbl,
                        p_apply_hold_status   => p_reapply_status);

                    p_reapply_status   := 'S';

                    IF p_reapply_status = 'S'
                    THEN
                        COMMIT;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Completed reapply_holds procedure for order Number: '
                            || header.order_number);
                    ELSE
                        ROLLBACK TO header;
                    END IF;
                END IF;
            END IF;                                             -- hold exists
        END LOOP;                                           -- end loop header
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR in progress_stuck_wf procedure : ' || SQLERRM);
    END progress_stuck_wf;
-- end 1.2

END xxd_ont_ship_confirm_int_pkg;
/
