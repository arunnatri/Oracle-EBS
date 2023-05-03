--
-- XXDO_ONT_SHIP_CONFIRM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:22 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_ONT_SHIP_CONFIRM_PKG"
AS
    /*
    **********************************************************************************************
    $Header:  xxdo_ont_ship_confirm_pkg.sql   1.0    2014/07/15    10:00:00   Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_ont_ship_confirm_pkg
    --
    -- Description  :  This is package Body for WMS to OMS Ship Confirm Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 15-Jul-14    Infosys            1.0       Created
    -- 21-Jan-15   Infosys            2.0       Added the logic for EDI interfacing
    --                                                          Identified by EDI_INTERFACE
    -- 22-Jan-15   Infosys            3.0       Fixed the bug in Ship Qty validation
    --                                                          Identified by SHIP_QTY_BUG
    -- 27-Jan-15   Infosys            4.0        Modified for BT Remediation
    -- 09-Feb-15   Infosys            5.0       Updated source header id on
    --                                          delivery detail id of container;identified by CONTAINER_BUG
    --09-Feb-15   Infosys             6.0      Ship confirm warning was ignored; Identified by SHIP_CONFIRM_WARNING
    --18-Feb-15   Infosys             7.0      Source header id is updated on new delivery ; Identified by DEL_SOURCE_HDR_ID
    --10-Apr-15   Infosys             8.0      Fixed the bug for Apply and Release Hold
    --                                                         !! Identified by OU_BUG
    --10-Apr-15  Infosys              9.0      Fixed the bug for Customer Name and Lastupdate date
    --                                                         !! Identified by CUST_NAME,LAST_UPDATE_DATE
    --13-May-15 Infosys             1.5      Changed the logic to roll back the transaction if any step fails
    --                                                         Identified by ROLLBACK_ALL
    -- 13-May-15 Infosys             1.6     If the carton is already existing, create a new carton with suffix ;
    --                                                         Identified by CHANGE_CARTON_NO
    -- 13-May-15 Infosys             1.7     Timestamp is added for creation date of PACKED message;
    --                                                         Identified by PACKED_MSG_DATE_BUG
    -- 29-May-15 Infosys             1.8     EDI ASN Interfacing Logic is modified;
    --                                                         Identified by EDI_ASN_INTERFACE
    -- 29-May-15 Infosys             1.9     If the carton is already existing in WMS, suffix it with _1 ;
    --                                                         Identified by UPDATE_CARTON_NO
    --01-Jun-15  Infosys              2.0     Freight_Charged field is used to get the actual freight;
    --                                                        Identified by FREIGHT_CHARGED
    --02-Jun-15 Infosys            2.1   SYSDATE is passed as transaction date to Transact Move order API
    --                                              Identified by MOVE_ORDER_DATE
    --12-Jun-15 Infosys            2.2    Updating the WAYBILL number; Identified by WAYBILL_NUM
    --15-Jun-15 Infosys           2.3     Update tracking number for carton;Identified by TRACKING_NUMBER
    --16-Jun-15 Infosys           2.4     Update carrier code in WND attribute2;Identified by WND_ATTRIBUTE2
    --20-Aug-15 Infosys           2.5    Logic to handle the split order line ; Identified by SPLIT_LINE
    --24-Aug-15 Infosys           2.4    Logic to remove the ship sets ; Identified by REMOVE_SHIPSET
    --03-Sep-15 Infosys           2.5    Logic to update the tracking number to BOL number for Truck shipments;
    --                                             Identified by BOL_TRACK_NO
    --3-Sep-15  Infosys           2.6    Logic to populate customer load id in WND DFF attribute15;
    --                                             Identified by CUST_LOAD_ID
    --24-Sep-15 Infosys           2.7       Added Logic to Fetch Order Header to Remove ship set for all Orders;
    --                                      Identified by REMOVE_SHIPSET_ALL
    --                                      Added Logic to Purge XML Staging table; Identified by PURGE_XML
    --06-Oct-15 Infosys           2.8    Added Logic to Fetch Order Lines from Pick Interface Log Stg Table
    --                                   Fix for the issue - Unable create container for carton number
    --                                   Identified by PICK_INTERFACE_LOG
    --07-Apr-16 Infosys           2.9    Fetching Ship to Org Id from order line level. Identified by EDI856_SHIP_TO_ORG
    --18-Apr-16 Infosys           2.10   populate line level ship-to for parcels
    --06-May-16 Infosys           2.11   changed carrier flag derivation to shipmethod level
    --18-Jan-18 Krishna L         2.12   CCR0006947 - Seal, Trailer and BOL changes. Invoice Work flow progress for order holds
    --22-Mar-18 Krishna L         2.13   CCR0007100 - Freight Application Override
    --13-Sep-18 Kranthi Bollam    2.14   CCR0007332 - Group EDI Shipments based on the Deliver to location.
    --04-Feb-19 Kranthi Bollam    2.15   CCR0007775 - Fixed a defect in getting tracking number.Added Deliver to Org condition.
    --24-May-19 Kranthi Bollam    2.16   CCR0007832 - Ship Confirm Interface Enhancement. Name Space is added to the XML file and
    --                                   existing code needs to be modified to handle it.
    -- ***************************************************************************

    ----------------------
    -- Global Variables --
    ----------------------
    -- Return code (0 for success, 1 for failure)
    g_chr_status_code                  VARCHAR2 (1) := '0';
    g_chr_status_msg                   VARCHAR2 (4000);
    g_ret_sts_warning                  VARCHAR2 (1) := 'W';
    g_chr_ar_release_reason   CONSTANT VARCHAR2 (10) := 'CRED-REL';
    g_chr_om_release_reason   CONSTANT VARCHAR2 (10) := 'CS-REL';
    g_ship_request_ids_tab             tabtype_id;
    g_num_parent_req_id                NUMBER;
    g_chr_addr_corr_report_name        VARCHAR2 (30)
                                           := 'XXDO_ADDR_CORR_REPORT';
    g_smtp_connection                  UTL_SMTP.connection := NULL;
    g_num_connection_flag              NUMBER := 0;


    -- ***************************************************************************
    -- Procedure Name      :  purge
    --
    -- Description         :  This procedure is to purge the old records
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_num_purge_days   IN  : Purge Days
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys            1.0  Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE PURGE (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_purge_days IN NUMBER)
    IS
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (
            fnd_file.LOG,
            'Purging ' || p_in_num_purge_days || ' days old records...');

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_head_log (wh_id, shipment_number, master_load_ref, customer_load_id, carrier, service_level, pro_number, comments, ship_date, seal_number, trailer_number, employee_id, employee_name, archive_date, archive_request_id, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, SOURCE, destination
                                                     , record_type)
                SELECT wh_id, shipment_number, master_load_ref,
                       customer_load_id, carrier, service_level,
                       pro_number, comments, ship_date,
                       seal_number, trailer_number, employee_id,
                       employee_name, l_dte_sysdate, g_num_request_id,
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
                       record_type
                  FROM xxdo_ont_ship_conf_head_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_ont_ship_conf_head_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving shipment headers data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment headers data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_order_log (wh_id,
                                                      shipment_number,
                                                      order_number,
                                                      ship_to_name,
                                                      ship_to_attention,
                                                      ship_to_addr1,
                                                      ship_to_addr2,
                                                      ship_to_addr3,
                                                      ship_to_city,
                                                      ship_to_state,
                                                      ship_to_zip,
                                                      ship_to_country_code,
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
                                                      address_verified,
                                                      order_header_id,
                                                      delivery_id,
                                                      ship_to_org_id,
                                                      ship_to_location_id)
                SELECT wh_id, shipment_number, order_number,
                       ship_to_name, ship_to_attention, ship_to_addr1,
                       ship_to_addr2, ship_to_addr3, ship_to_city,
                       ship_to_state, ship_to_zip, ship_to_country_code,
                       l_dte_sysdate, g_num_request_id, process_status,
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
                       ship_to_org_id, ship_to_location_id
                  FROM xxdo_ont_ship_conf_order_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_ont_ship_conf_order_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
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
                                                       freight_charged) /* FREIGHT_CHARGED */
                SELECT wh_id, shipment_number, order_number,
                       carton_number, tracking_number, freight_list,
                       freight_actual, weight, LENGTH,
                       width, height, l_dte_sysdate,
                       g_num_request_id, process_status, error_message,
                       request_id, creation_date, created_by,
                       last_update_date, last_updated_by, source_type,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, SOURCE,
                       destination, record_type, freight_charged /* FREIGHT_CHARGED */
                  FROM xxdo_ont_ship_conf_carton_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_ont_ship_conf_carton_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
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
                       l_dte_sysdate, g_num_request_id, process_status,
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
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_ont_ship_conf_cardtl_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving shipment carton details data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment carton details data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_ont_ship_conf_carser_log (wh_id, shipment_number, order_number, carton_number, line_number, serial_number, item_number, archive_date, archive_request_id, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, SOURCE, destination
                                                       , record_type)
                SELECT wh_id, shipment_number, order_number,
                       carton_number, line_number, serial_number,
                       item_number, l_dte_sysdate, g_num_request_id,
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
                       record_type
                  FROM xxdo_ont_ship_conf_carser_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_ont_ship_conf_carser_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving shipment carton serials data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving shipment carton serials data: '
                    || SQLERRM);
        END;

        COMMIT;

        --Start PURGE_XML
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
                                                    archive_date)
                SELECT process_status, xml_document, file_name,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       g_num_request_id, l_dte_sysdate
                  FROM xxdo_ont_ship_conf_xml_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_in_num_purge_days;

            DELETE FROM
                xxdo_ont_ship_conf_xml_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving Ship Confirm XML  data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving Ship Confirm XML data: '
                    || SQLERRM);
        END;
    --END PURGE_XML
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexepected error while purging the records' || SQLERRM);
    END PURGE;

    /*OU_BUG*/
    /** ****************************************************************************
   -- Procedure Name      :  get_resp_details
   --
   -- Description         :  This procedure is to archive and purge the old records


   -- Parameters          : p_resp_id      OUT : Responsibility ID
   --                              p_resp_appl_id     OUT : Application ID
   -
   -- Return/Exit         :  none
   --
   --
   -- DEVELOPMENT and MAINTENANCE HISTORY
   --
   -- date          author             Version  Description
   -- ------------  -----------------  -------

   --------------------------------
   -- 2015/04/01 Infosys            1.0  Initial Version.
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
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
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
                 WHERE     flv.lookup_code = UPPER (hou.name)
                       AND flv.lookup_type = 'XXDO_APPL_RESP_SETUP'
                       AND flv.enabled_flag = 'Y'
                       AND language = 'US'
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

    /*OU_BUG*/
    PROCEDURE send_mail_header (p_in_chr_msg_from IN VARCHAR2, p_in_chr_msg_to IN VARCHAR2, p_in_chr_msg_subject IN VARCHAR2
                                , p_out_num_status OUT NUMBER)
    IS
        l_num_status              NUMBER := 0;
        l_chr_msg_to              VARCHAR2 (2000) := NULL;
        l_chr_mail_temp           VARCHAR2 (2000) := NULL;
        l_chr_mail_id             VARCHAR2 (255);
        l_num_counter             NUMBER := 0;
        l_exe_conn_already_open   EXCEPTION;
    BEGIN
        IF g_num_connection_flag <> 0
        THEN
            RAISE l_exe_conn_already_open;
        END IF;

        g_smtp_connection       := UTL_SMTP.open_connection ('127.0.0.1');
        g_num_connection_flag   := 1;
        l_num_status            := 1;
        UTL_SMTP.helo (g_smtp_connection, 'localhost');
        UTL_SMTP.mail (g_smtp_connection, p_in_chr_msg_from);


        l_chr_mail_temp         := TRIM (p_in_chr_msg_to);

        IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
        THEN
            l_chr_mail_id   := l_chr_mail_temp;
            fnd_file.put_line (fnd_file.LOG,
                               CHR (10) || 'Email ID: ' || l_chr_mail_id);
            UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
        ELSE
            WHILE (LENGTH (l_chr_mail_temp) > 0)
            LOOP
                IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
                THEN
                    -- Last Mail ID
                    l_chr_mail_id   := l_chr_mail_temp;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                    EXIT;
                ELSE
                    -- Next Mail ID
                    l_chr_mail_id   :=
                        TRIM (
                            SUBSTR (l_chr_mail_temp,
                                    1,
                                    INSTR (l_chr_mail_temp, ';', 1) - 1));
                    fnd_file.put_line (
                        fnd_file.LOG,
                        CHR (10) || 'Email ID: ' || l_chr_mail_id);
                    UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
                END IF;

                l_chr_mail_temp   :=
                    TRIM (
                        SUBSTR (l_chr_mail_temp,
                                INSTR (l_chr_mail_temp, ';', 1) + 1,
                                LENGTH (l_chr_mail_temp)));
            END LOOP;
        END IF;


        l_chr_msg_to            :=
            '  ' || TRANSLATE (TRIM (p_in_chr_msg_to), ';', ' ');


        UTL_SMTP.open_data (g_smtp_connection);
        l_num_status            := 2;
        UTL_SMTP.write_data (g_smtp_connection,
                             'To: ' || l_chr_msg_to || UTL_TCP.CRLF);
        UTL_SMTP.write_data (g_smtp_connection,
                             'From: ' || p_in_chr_msg_from || UTL_TCP.CRLF);
        UTL_SMTP.write_data (
            g_smtp_connection,
            'Subject: ' || p_in_chr_msg_subject || UTL_TCP.CRLF);

        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_conn_already_open
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            IF l_num_status = 2
            THEN
                UTL_SMTP.close_data (g_smtp_connection);
            END IF;

            IF l_num_status > 0
            THEN
                UTL_SMTP.quit (g_smtp_connection);
            END IF;

            g_num_connection_flag   := 0;
            p_out_num_status        := -255;
    END send_mail_header;


    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.write_data (g_smtp_connection,
                             p_in_chr_msg_text || UTL_TCP.CRLF);

        p_out_num_status   := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := -2;
        WHEN OTHERS
        THEN
            p_out_num_status   := -255;
    END send_mail_line;

    PROCEDURE send_mail_close (p_out_num_status OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF g_num_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.close_data (g_smtp_connection);
        UTL_SMTP.quit (g_smtp_connection);

        g_num_connection_flag   := 0;
        p_out_num_status        := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := 0;
        WHEN OTHERS
        THEN
            p_out_num_status        := -255;
            g_num_connection_flag   := 0;
    END send_mail_close;


    -- ***************************************************************************
    -- Procedure Name      :  address_correction
    --
    -- Description         :  Procedure creates report if any disccrpeancies are found in the
    --              order address details
    --
    -- Parameters          :  p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_chr_customer_code   IN  : Customer Number
    --
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0   Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE address_correction (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_customer_code IN VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_chr_instance               VARCHAR2 (100);


        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;
        l_exe_instance_not_known     EXCEPTION;

        CURSOR cur_error_records IS
              SELECT DISTINCT ph.customer_code cust_num, ph.customer_name cust_name, /*CUST_NAME*/
                                                                                     ph.warehouse_code wh_code,
                              ph.order_number ord_num, sco.shipment_number shipment_num, ph.ship_to_code ship_to,
                              ph.ship_to_addr1 pick_addr1, ph.ship_to_addr2 pick_addr2, ph.ship_to_addr3 pick_addr3,
                              ph.ship_to_city pick_city, ph.ship_to_state pick_state, ph.ship_to_zip pick_zip,
                              ph.ship_to_country_code pick_country, sco.ship_to_addr1 ship_addr1, sco.ship_to_addr2 ship_addr2,
                              sco.ship_to_addr3 ship_addr3, sco.ship_to_city ship_city, sco.ship_to_state ship_state,
                              sco.ship_to_zip ship_zip, sco.ship_to_country_code ship_country
                FROM xxdo_ont_ship_conf_order_stg sco, xxont_pick_intf_hdr_stg ph
               WHERE     sco.address_verified IN ('NOT VERIFIED', 'N')
                     AND ph.warehouse_code = sco.wh_id
                     AND ph.order_number = sco.order_number
                     AND ph.customer_code =
                         NVL (p_in_chr_customer_code, ph.customer_code)
            ORDER BY cust_num, ord_num;


        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab          l_error_records_tab_type;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Get the instance name - it will be shown in the report
        BEGIN
            SELECT instance_name INTO l_chr_instance FROM v$instance;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;


        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, flv.attribute10, flv.attribute11,
                   flv.attribute13
              INTO l_rid_lookup_rec_rowid, l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = g_chr_addr_corr_report_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_exe_no_interface_setup;
        END;


        -- Convert the FROM email id instance specific
        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids

        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');


        /*CUST_NAME*/
        fnd_file.put_line (
            fnd_file.output,
               'Customer Number'
            || CHR (9)
            || 'Customer Name'
            || CHR (9)
            || 'Warehouse Code'
            || CHR (9)
            || 'Order Number'
            || CHR (9)
            || 'Shipment Number'
            || CHR (9)
            || 'Pick Ticket - Address Line1'
            || CHR (9)
            || 'Pick Ticket - Address Line 2'
            || CHR (9)
            || 'Pick Ticket - Address Line 3'
            || CHR (9)
            || 'Pick Ticket - City'
            || CHR (9)
            || 'Pick Ticket - State'
            || CHR (9)
            || 'Pick Ticket - Zip'
            || CHR (9)
            || 'Pick Ticket - Country'
            || CHR (9)
            || 'Shipment - Address Line1'
            || CHR (9)
            || 'Shipment - Address Line2'
            || CHR (9)
            || 'Shipment - Address Line3'
            || CHR (9)
            || 'Shipment - City'
            || CHR (9)
            || 'Shipment - State'
            || CHR (9)
            || 'Shipment - Zip'
            || CHR (9)
            || 'Shipment - Country');

        -- Logic to send the error records
        OPEN cur_error_records;

        LOOP
            IF l_error_records_tab.EXISTS (1)
            THEN
                l_error_records_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_error_records
                    BULK COLLECT INTO l_error_records_tab
                    LIMIT 1000;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_error_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Ship confirm address records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - Address Correction Report'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);

                send_mail_line ('', l_num_return_value);
                --                   SEND_MAIL_LINE('Please refer the attached file for details of errors occurred in ' || g_chr_instance ||' between '
                --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
                --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
                --                                              l_num_return_value);
                send_mail_line (
                       'Please refer the attached file for details of address discrepancies occurred in '
                    || l_chr_instance
                    || '.',
                    l_num_return_Value);
                send_mail_line ('', l_num_return_value);

                send_mail_line ('--boundarystring', l_num_return_value);

                send_mail_line ('Content-Type: text/xls', l_num_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="Address_correction_report.xls"',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);


                send_mail_line (
                       'Customer Number'
                    || CHR (9)
                    || 'Customer Name'
                    || CHR (9)
                    ||                                           /*CUST_NAME*/
                       'Warehouse Code'
                    || CHR (9)
                    || 'Order Number'
                    || CHR (9)
                    || 'Shipment Number'
                    || CHR (9)
                    || 'Pick Ticket - Address Line1'
                    || CHR (9)
                    || 'Pick Ticket - Address Line 2'
                    || CHR (9)
                    || 'Pick Ticket - Address Line 3'
                    || CHR (9)
                    || 'Pick Ticket - City'
                    || CHR (9)
                    || 'Pick Ticket - State'
                    || CHR (9)
                    || 'Pick Ticket - Zip'
                    || CHR (9)
                    || 'Pick Ticket - Country'
                    || CHR (9)
                    || 'Shipment - Address Line1'
                    || CHR (9)
                    || 'Shipment - Address Line2'
                    || CHR (9)
                    || 'Shipment - Address Line3'
                    || CHR (9)
                    || 'Shipment - City'
                    || CHR (9)
                    || 'Shipment - State'
                    || CHR (9)
                    || 'Shipment - Zip'
                    || CHR (9)
                    || 'Shipment - Country'
                    || CHR (9),
                    l_num_return_value);

                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_error_records_tab.FIRST ..
                             l_error_records_tab.LAST
            LOOP
                IF (NVL (l_error_records_tab (l_num_ind).ship_addr1, '-1') != NVL (l_error_records_tab (l_num_ind).pick_addr1, '-1') OR NVL (l_error_records_tab (l_num_ind).ship_addr2, '-1') != NVL (l_error_records_tab (l_num_ind).pick_addr2, '-1') OR NVL (l_error_records_tab (l_num_ind).ship_addr3, '-1') != NVL (l_error_records_tab (l_num_ind).pick_addr3, '-1') OR NVL (l_error_records_tab (l_num_ind).ship_city, '-1') != NVL (l_error_records_tab (l_num_ind).pick_city, '-1') OR NVL (l_error_records_tab (l_num_ind).ship_state, '-1') != NVL (l_error_records_tab (l_num_ind).pick_state, '-1') OR NVL (l_error_records_tab (l_num_ind).ship_zip, '-1') != NVL (l_error_records_tab (l_num_ind).pick_zip, '-1') OR NVL (l_error_records_tab (l_num_ind).ship_country, '-1') != NVL (l_error_records_tab (l_num_ind).pick_country, '-1'))
                THEN
                    send_mail_line (
                           l_error_records_tab (l_num_ind).cust_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).cust_name
                        || CHR (9)                               /*CUST_NAME*/
                        || l_error_records_tab (l_num_ind).wh_code
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ord_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).shipment_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_addr1
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_addr2
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_addr3
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_city
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_state
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_zip
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_country
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_addr1
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_addr2
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_addr3
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_city
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_state
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_zip
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_country
                        || CHR (9),
                        l_num_return_value);

                    IF l_num_return_value <> 0
                    THEN
                        p_out_chr_errbuf   :=
                            'Unable to generate the attachment file';
                        RAISE l_exe_mail_error;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.output,
                           l_error_records_tab (l_num_ind).cust_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).cust_name
                        || CHR (9)                               /*CUST_NAME*/
                        || l_error_records_tab (l_num_ind).wh_code
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ord_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).shipment_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_addr1
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_addr2
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_addr3
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_city
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_state
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_zip
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).pick_country
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_addr1
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_addr2
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_addr3
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_city
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_state
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_zip
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).ship_country);



                    UPDATE xxdo_ont_ship_conf_order_stg sco
                       SET sco.address_verified   = 'REPORTED' --,   /*LAST_UPDATE_DATE*/
                     --    last_update_date= sysdate
                     WHERE     sco.address_verified IN ('NOT VERIFIED', 'N')
                           AND sco.wh_id =
                               l_error_records_tab (l_num_ind).wh_code
                           AND sco.order_number =
                               l_error_records_tab (l_num_ind).ord_num;
                ELSE
                    UPDATE xxdo_ont_ship_conf_order_stg sco
                       SET sco.address_verified   = 'VERIFIED'             --,
                     -- last_update_date= sysdate                                             -,   /*LAST_UPDATE_DATE*/
                     WHERE     sco.address_verified IN ('NOT VERIFIED', 'N')
                           AND sco.wh_id =
                               l_error_records_tab (l_num_ind).wh_code
                           AND sco.order_number =
                               l_error_records_tab (l_num_ind).ord_num;
                END IF;

                COMMIT;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_error_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate Address Correction report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at Address Correction report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_instance_not_known
        THEN
            p_out_chr_errbuf    := 'Unable to derive the instance';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at Address Correction report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END address_correction;


    /*
       PROCEDURE address_correction (
          p_out_chr_errbuf         OUT      VARCHAR2,
          p_out_chr_retcode        OUT      VARCHAR2,
          p_in_chr_customer_code   IN       VARCHAR2
       )
       IS
          CURSOR lcsr_shp_addr
          IS
             SELECT   sco.ROWID row_id, ph.customer_code cust_num,
                      ph.warehouse_code wh_code, ph.order_number ord_num,
                      sco.shipment_number shipment_num, ph.ship_to_code ship_to,
                      ph.ship_to_addr1 pick_addr1, ph.ship_to_addr2 pick_addr2,
                      ph.ship_to_addr3 pick_addr3, ph.ship_to_city pick_city,
                      ph.ship_to_state pick_state, ph.ship_to_zip pick_zip,
                      ph.ship_to_country_code pick_country,
                      sco.ship_to_addr1 ship_addr1, sco.ship_to_addr2 ship_addr2,
                      sco.ship_to_addr3 ship_addr3, sco.ship_to_city ship_city,
                      sco.ship_to_state ship_state, sco.ship_to_zip ship_zip,
                      sco.ship_to_country_code ship_country
                 FROM xxdo_ont_ship_conf_order_stg sco,
                      xxont_pick_intf_hdr_stg ph
                WHERE sco.address_verified IN( 'NOT VERIFIED','N')
                  AND ph.warehouse_code = sco.wh_id
                  AND ph.order_number = sco.order_number
                  AND ph.customer_code =
                                    NVL (p_in_chr_customer_code, ph.customer_code)
             ORDER BY cust_num, ord_num;
       BEGIN
          p_out_chr_errbuf := NULL;
          p_out_chr_retcode := '0';
    --------------------------------------------------
          fnd_file.put_line
             (fnd_file.output,
                'Customer Number' || CHR (9)|| 'Warehouse Code'|| CHR (9)||'Order Number'|| CHR (9)||'Shipment Number'|| CHR (9)||
                'Pick Ticket - Address Line1'|| CHR (9)||'Pick Ticket - Address Line 2'|| CHR (9)||'Pick Ticket - Address Line 3'|| CHR (9)||'Pick Ticket - City'|| CHR (9)||'Pick Ticket - State'|| CHR (9)||'Pick Ticket - Zip'|| CHR (9)||'Pick Ticket - Country'|| CHR (9)||
                'Shipment - Address Line1'|| CHR (9)||'Shipment - Address Line2'|| CHR (9)||'Shipment - Address Line3'|| CHR (9)||'Shipment - City'|| CHR (9)||'Shipment - State'|| CHR (9)||'Shipment - Zip'|| CHR (9)||'Shipment - Country'
             );

          FOR lrec_shp_addr IN lcsr_shp_addr
          LOOP
             IF (   NVL (lrec_shp_addr.ship_addr1, '-1') !=
                                              NVL (lrec_shp_addr.pick_addr1, '-1')
                 OR NVL (lrec_shp_addr.ship_addr2, '-1') !=
                                              NVL (lrec_shp_addr.pick_addr2, '-1')
                 OR NVL (lrec_shp_addr.ship_addr3, '-1') !=
                                              NVL (lrec_shp_addr.pick_addr3, '-1')
                 OR NVL (lrec_shp_addr.ship_city, '-1') !=
                                               NVL (lrec_shp_addr.pick_city, '-1')
                 OR NVL (lrec_shp_addr.ship_state, '-1') !=
                                              NVL (lrec_shp_addr.pick_state, '-1')
                 OR NVL (lrec_shp_addr.ship_zip, '-1') !=
                                                NVL (lrec_shp_addr.pick_zip, '-1')
                 OR NVL (lrec_shp_addr.ship_country, '-1') !=
                                            NVL (lrec_shp_addr.pick_country, '-1')
                )
             THEN
                fnd_file.put_line (fnd_file.output,
                                      lrec_shp_addr.cust_num || CHR (9)
                                   || lrec_shp_addr.wh_code || CHR (9)
                                   || lrec_shp_addr.ord_num || CHR (9)
                                   || lrec_shp_addr.shipment_num || CHR (9)
                                   || lrec_shp_addr.pick_addr1 || CHR (9)
                                   || lrec_shp_addr.pick_addr2 || CHR (9)
                                   || lrec_shp_addr.pick_addr3 || CHR (9)
                                   || lrec_shp_addr.pick_city || CHR (9)
                                   || lrec_shp_addr.pick_state || CHR (9)
                                   || lrec_shp_addr.pick_zip || CHR (9)
                                   || lrec_shp_addr.pick_country || CHR (9)
                                   || lrec_shp_addr.ship_addr1 || CHR (9)
                                   || lrec_shp_addr.ship_addr2 || CHR (9)
                                   || lrec_shp_addr.ship_addr3|| CHR (9)
                                   || lrec_shp_addr.ship_city || CHR (9)
                                   || lrec_shp_addr.ship_state || CHR (9)
                                   || lrec_shp_addr.ship_zip || CHR (9)
                                   || lrec_shp_addr.ship_country
                                  );

                UPDATE xxdo_ont_ship_conf_order_stg sco
                   SET sco.address_verified = 'REPORTED',
                   last_update_date= sysdate
                 WHERE sco.ROWID = lrec_shp_addr.row_id;
             ELSE
                UPDATE xxdo_ont_ship_conf_order_stg sco
                   SET sco.address_verified = 'VERIFIED',
                   last_update_date= sysdate
                 WHERE sco.ROWID = lrec_shp_addr.row_id;
             END IF;

             COMMIT;
          END LOOP;
       EXCEPTION
          WHEN OTHERS
          THEN
             p_out_chr_retcode := '2';
             p_out_chr_errbuf := SQLERRM;
             fnd_file.put_line
                            (fnd_file.LOG,
                                'ERROR in address correction report procedure : '
                             || p_out_chr_errbuf
                            );
             fnd_file.put_line
                             (fnd_file.output,
                                 'ERROR in address correction report procedure : '
                              || p_out_chr_errbuf
                             );
       END address_correction;
    */
    -- ***************************************************************************
    -- Procedure Name      :  lock_records
    --
    -- Description         :  This procedure is to lock the records for processing
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_chr_shipment_no  IN  : Shipment Number
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys            1.0   Initial Version.
    --
    -- ***************************************************************************


    PROCEDURE lock_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        UPDATE xxdo_ont_ship_conf_head_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_order_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_carton_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_cardtl_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_carser_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR in lock records procedure : ' || p_out_chr_errbuf);
    END lock_records;

    -- ***************************************************************************
    -- Procedure Name      :  reset_error_records
    --
    -- Description         :  This procedure is to reset the error records for the given shipment number
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_chr_shipment_no   IN  : Shipment Number
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE reset_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        UPDATE xxdo_ont_ship_conf_head_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'ERROR'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_order_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'ERROR'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_carton_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'ERROR'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_cardtl_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'ERROR'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);

        UPDATE xxdo_ont_ship_conf_carser_stg
           SET process_status = 'NEW', error_message = NULL, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'ERROR'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number);
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'ERROR in reset error records procedure : '
                || p_out_chr_errbuf);
    END reset_error_records;


    -- ***************************************************************************
    -- Procedure Name      :  update_error_records
    --
    -- Description         :  This procedure is to update the process status and error message of the processed
    --                              and errored records
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_chr_shipment_no     IN : Shipment Number
    --                              p_in_chr_delivery_no     IN :  Delivery Number
    --                              p_in_chr_carton_no       IN :  Carton Number
    --                              p_in_chr_error_level     IN :  Error Level
    --                              p_in_chr_error_message   IN :  Error message
    --                              p_in_chr_status          IN :  To Status
    --                              p_in_chr_source          IN : Program where the error occurred
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    -- To update a shipment, shipment number will be passed. delivery number will be blank, all deliveries will be updated as error
    ---To update a delivery alone, shipment number and delivery number need to be passed, all cartons will be updated as error
    -- To update a carton alone, shipment number, delivery number and carton number to be passed, all order lines will be updated as error
    -- Shipment will be updated always
    PROCEDURE update_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2, p_in_chr_delivery_no IN VARCHAR2, p_in_chr_carton_no IN VARCHAR2, p_in_chr_error_level IN VARCHAR2
                                    , p_in_chr_error_message IN VARCHAR2, p_in_chr_status IN VARCHAR2, p_in_chr_source IN VARCHAR2)
    IS
        l_num_errored_locked_count   NUMBER := 0;
        l_num_pending_proc_count     NUMBER := -1;
        l_chr_savepoint_name         VARCHAR2 (30);
        l_chr_errbuf                 VARCHAR2 (2000);
        l_chr_retcode                VARCHAR2 (30);
        l_num_trip_id                NUMBER := 0;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        /* ROLLBACK_ALL - Start */

        -- Rollback to the appropriate save point when there is error
        /*   IF p_in_chr_status = 'ERROR' THEN
               IF p_in_chr_source = 'DELIVERY_THREAD' THEN
                   l_chr_savepoint_name := 'SP_'||g_num_request_id;
               ELSIF p_in_chr_source = 'SHIPMENT_THREAD_BEFORE_DT' THEN
                   l_chr_savepoint_name := 'SP_'||g_num_request_id ||'_BEFORE_DT';
               ELSE
                   l_chr_savepoint_name := 'SP_'||g_num_request_id ||'_AFTER_DT';
               END IF;

               BEGIN
                     EXECUTE IMMEDIATE 'ROLLBACK TO ' || l_chr_savepoint_name;
               EXCEPTION
                     WHEN OTHERS THEN
                          fnd_file.put_line (fnd_file.LOG,
                                                'Unexpected Error While rolling back to save point : ' || l_chr_savepoint_name || '  ' || SQLERRM);
               END;

               IF p_in_chr_source = 'DELIVERY_THREAD' THEN

                     SELECT COUNT (1)
                        INTO l_num_pending_proc_count
                        FROM xxdo_ont_ship_conf_order_stg
                       WHERE shipment_number = p_in_chr_shipment_no
                         AND request_id = g_num_parent_req_id--g_num_request_id
                         AND order_number <> p_in_chr_delivery_no
                         AND process_status IN ('INPROCESS', 'NEW','PROCESSED');

                     IF l_num_pending_proc_count = 0 THEN

                             BEGIN
                                 SELECT trip_id
                                     INTO l_num_trip_id
                                    FROM wsh_trips
                                 WHERE  name = p_in_chr_shipment_no;
                             EXCEPTION
                                  WHEN OTHERS THEN
                                         l_num_trip_id := 0;
                             END;

                             IF l_num_trip_id <> 0 THEN

                                 update_trip (
                                               p_out_chr_errbuf        => l_chr_errbuf,
                                               p_out_chr_retcode      => l_chr_retcode,
                                               p_in_num_trip_id        => l_num_trip_id,
                                               p_in_chr_trip_name     => substr(substr(p_in_chr_shipment_no,1,12) || '_Err_'||g_num_request_id, 1,30));

                             END IF;

                     END IF;

               END IF;

           END IF;

           UPDATE xxdo_ont_ship_conf_order_stg
              SET process_status = p_in_chr_status,
                  error_message =
                     DECODE (p_in_chr_error_level,
                             'DELIVERY', p_in_chr_error_message,
                             NULL
                            ),
                  last_updated_by = g_num_user_id,
                  last_update_date = SYSDATE
            WHERE process_status = 'INPROCESS'
              AND shipment_number = p_in_chr_shipment_no
              AND order_number = NVL (p_in_chr_delivery_no, order_number);

           UPDATE xxdo_ont_ship_conf_carton_stg
              SET process_status = p_in_chr_status,
                  error_message =
                     DECODE (p_in_chr_error_level,
                             'CARTON', p_in_chr_error_message,
                             NULL
                            ),
                  last_updated_by = g_num_user_id,
                  last_update_date = SYSDATE
            WHERE process_status = 'INPROCESS'
              AND shipment_number = p_in_chr_shipment_no
              AND order_number = NVL (p_in_chr_delivery_no, order_number)
              AND carton_number = NVL (p_in_chr_carton_no, carton_number);

           UPDATE xxdo_ont_ship_conf_cardtl_stg
              SET process_status = p_in_chr_status,
                  error_message =
                     DECODE (p_in_chr_error_level,
                             'ORDER LINE', p_in_chr_error_message,
                             NULL
                            ),
                  last_updated_by = g_num_user_id,
                  last_update_date = SYSDATE
            WHERE process_status = 'INPROCESS'
              AND shipment_number = p_in_chr_shipment_no
              AND order_number = NVL (p_in_chr_delivery_no, order_number)
              AND carton_number = NVL (p_in_chr_carton_no, carton_number);

           UPDATE xxdo_ont_ship_conf_carser_stg
              SET process_status = p_in_chr_status,
                  error_message =
                     DECODE (p_in_chr_error_level,
                             'SERIAL', p_in_chr_error_message,
                             NULL
                            ),
                  last_updated_by = g_num_user_id,
                  last_update_date = SYSDATE
            WHERE process_status = 'INPROCESS'
              AND shipment_number = p_in_chr_shipment_no
              AND order_number = NVL (p_in_chr_delivery_no, order_number)
              AND carton_number = NVL (p_in_chr_carton_no, carton_number);

           IF p_in_chr_status <> 'PROCESSED'
           THEN
              UPDATE xxdo_ont_ship_conf_head_stg
                 SET process_status = p_in_chr_status,
                     error_message =
                        DECODE (p_in_chr_error_level,
                                'SHIPMENT', p_in_chr_error_message,
                                NULL
                               ),
                     last_updated_by = g_num_user_id,
                     last_update_date = SYSDATE
               WHERE process_status = 'INPROCESS'
                 AND shipment_number = p_in_chr_shipment_no;
           ELSE
              SELECT COUNT (1)
                INTO l_num_errored_locked_count
                FROM xxdo_ont_ship_conf_order_stg
               WHERE shipment_number = p_in_chr_shipment_no
                 AND request_id = g_num_parent_req_id --g_num_request_id
                 AND process_status IN ('INPROCESS', 'ERROR');

              IF l_num_errored_locked_count = 0
              THEN
                 UPDATE xxdo_ont_ship_conf_head_stg
                    SET process_status = p_in_chr_status,
                        error_message =
                           DECODE (p_in_chr_error_level,
                                   'SHIPMENT', p_in_chr_error_message,
                                   NULL
                                  ),
                        last_updated_by = g_num_user_id,
                        last_update_date = SYSDATE
                  WHERE process_status = 'INPROCESS'
                    AND shipment_number = p_in_chr_shipment_no;

                     -- Interface the QR Changes
     --               IF p_in_chr_status = 'PROCESSED' THEN

                        UPDATE xxdo.xxdo_serial_temp xst
                           SET (lpn_id, license_plate_number, source_code_reference, source_code,inventory_item_id) =
                                  (SELECT wlp.lpn_id, carton_number, line_number, 'SHIP_CONFIRM',msi.inventory_item_id
                                     FROM xxdo_ont_ship_conf_carser_stg xos,
                                          wms_license_plate_numbers wlp,
                                          mtl_parameters mp,
                                          mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
                                    WHERE wlp.license_plate_number = xos.carton_number
                                      --AND xos.item_number = msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3          --commented for BT Remediation
                                      AND xos.item_number = msi.concatenated_segments                                                   --Added for BT Remediation
                                      AND xos.wh_id = mp.organization_code
                                      AND msi.organization_id = mp.organization_id
                                      AND xos.serial_number = xst.serial_number
                                      AND xos.process_status = 'PROCESSED'
                                     AND xos.shipment_number = p_in_chr_shipment_no
                                     AND xos.request_id =  g_num_parent_req_id)
                         WHERE EXISTS (
                                  SELECT 1
                                    FROM xxdo_ont_ship_conf_carser_stg xos
                                   WHERE xos.process_status = 'PROCESSED'
                                     AND xos.serial_number = xst.serial_number
                                     AND xos.shipment_number = p_in_chr_shipment_no
                                     AND xos.request_id =  g_num_parent_req_id);                     /* change this */

              /*     INSERT INTO xxdo.xxdo_serial_temp xst
                               (serial_number, lpn_id, license_plate_number,
                                inventory_item_id, last_update_date, last_updated_by,
                                creation_date, created_by, organization_id, status_id,
                                source_code, source_code_reference)
                      SELECT xos.serial_number, wlp.lpn_id, xos.carton_number,
                             msi.inventory_item_id, SYSDATE, g_num_user_id, SYSDATE, g_num_user_id,
                             msi.organization_id, 1, 'SHIP_CONFIRM', xos.line_number
                        FROM xxdo_ont_ship_conf_carser_stg xos,
                             wms_license_plate_numbers wlp,
                             mtl_parameters mp,
                             mtl_system_items_kfv msi --Replaced table mtl_system_items with mtl_system_items_kfv for BT Remediation
                       WHERE wlp.license_plate_number = xos.carton_number
                         AND xos.process_status = 'PROCESSED'
                         --AND xos.item_number = msi.segment1 || '-' || msi.segment2 || '-' || msi.segment3              --Commented for BT Remediation
                         AND xos.item_number = msi.concatenated_segments                                                        --Added for BT Remediation
                         AND xos.wh_id = mp.organization_code
                         AND msi.organization_id = mp.organization_id
                         AND xos.shipment_number = p_in_chr_shipment_no
                         AND xos.request_id =  g_num_parent_req_id
                         AND NOT EXISTS (SELECT 1
                                                       FROM xxdo.xxdo_serial_temp xst
                                                      WHERE xos.serial_number = xst.serial_number);

--               END IF;

         END IF;
      END IF;

      COMMIT; */

        -- Rollback to the appropriate save point when there is error
        IF p_in_chr_status = 'ERROR'
        THEN
            l_chr_savepoint_name   :=
                'SP_' || g_num_request_id || '_BEFORE_DT';

            IF p_in_chr_source <> 'PICK_CONFIRM'
            THEN               -- Save point is established after pick confirm
                BEGIN
                    EXECUTE IMMEDIATE 'ROLLBACK TO ' || l_chr_savepoint_name;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unexpected Error While rolling back to save point : '
                            || l_chr_savepoint_name
                            || '  '
                            || SQLERRM);
                END;
            END IF;

            IF p_in_chr_source IN ('DELIVERY_THREAD', 'PICK_CONFIRM')
            THEN -- Update the error message at the correct delivery level and mark all other deliveries as ERROR
                UPDATE xxdo_ont_ship_conf_order_stg
                   SET process_status = p_in_chr_status, error_message = DECODE (p_in_chr_error_level, 'DELIVERY', p_in_chr_error_message, NULL), last_updated_by = g_num_user_id,
                       last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no
                       AND order_number =
                           NVL (p_in_chr_delivery_no, order_number);

                UPDATE xxdo_ont_ship_conf_carton_stg
                   SET process_status = p_in_chr_status, error_message = DECODE (p_in_chr_error_level, 'CARTON', p_in_chr_error_message, NULL), last_updated_by = g_num_user_id,
                       last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no
                       AND order_number =
                           NVL (p_in_chr_delivery_no, order_number)
                       AND carton_number =
                           NVL (p_in_chr_carton_no, carton_number);

                UPDATE xxdo_ont_ship_conf_cardtl_stg
                   SET process_status = p_in_chr_status, error_message = DECODE (p_in_chr_error_level, 'ORDER LINE', p_in_chr_error_message, NULL), last_updated_by = g_num_user_id,
                       last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no
                       AND order_number =
                           NVL (p_in_chr_delivery_no, order_number)
                       AND carton_number =
                           NVL (p_in_chr_carton_no, carton_number);

                UPDATE xxdo_ont_ship_conf_carser_stg
                   SET process_status = p_in_chr_status, error_message = DECODE (p_in_chr_error_level, 'SERIAL', p_in_chr_error_message, NULL), last_updated_by = g_num_user_id,
                       last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no
                       AND order_number =
                           NVL (p_in_chr_delivery_no, order_number)
                       AND carton_number =
                           NVL (p_in_chr_carton_no, carton_number);


                UPDATE xxdo_ont_ship_conf_order_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;


                UPDATE xxdo_ont_ship_conf_carton_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;

                UPDATE xxdo_ont_ship_conf_cardtl_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;

                UPDATE xxdo_ont_ship_conf_carser_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;
            ELSE                 -- If the error source is not delivery thread
                UPDATE xxdo_ont_ship_conf_order_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;


                UPDATE xxdo_ont_ship_conf_carton_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;

                UPDATE xxdo_ont_ship_conf_cardtl_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;

                UPDATE xxdo_ont_ship_conf_carser_stg
                   SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
                 WHERE     process_status = 'INPROCESS'
                       AND shipment_number = p_in_chr_shipment_no;
            END IF;                               -- End of error source check

            UPDATE xxdo_ont_ship_conf_head_stg
               SET process_status = p_in_chr_status, error_message = DECODE (p_in_chr_error_level, 'SHIPMENT', p_in_chr_error_message, NULL), last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND shipment_number = p_in_chr_shipment_no;
        ELSE                                     -- If the status is not error
            UPDATE xxdo_ont_ship_conf_head_stg
               SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND shipment_number = p_in_chr_shipment_no;


            UPDATE xxdo_ont_ship_conf_order_stg
               SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND shipment_number = p_in_chr_shipment_no;


            UPDATE xxdo_ont_ship_conf_carton_stg
               SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND shipment_number = p_in_chr_shipment_no;


            UPDATE xxdo_ont_ship_conf_cardtl_stg
               SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND shipment_number = p_in_chr_shipment_no;


            UPDATE xxdo_ont_ship_conf_carser_stg
               SET process_status = p_in_chr_status, last_updated_by = g_num_user_id, last_update_date = SYSDATE
             WHERE     process_status = 'INPROCESS'
                   AND shipment_number = p_in_chr_shipment_no;


            UPDATE xxdo.xxdo_serial_temp xst
               SET (lpn_id, license_plate_number, source_code_reference,
                    source_code, inventory_item_id)   =
                       (SELECT wlp.lpn_id, carton_number, line_number,
                               'SHIP_CONFIRM', msi.inventory_item_id
                          FROM xxdo_ont_ship_conf_carser_stg xos, wms_license_plate_numbers wlp, mtl_parameters mp,
                               mtl_system_items_kfv msi
                         WHERE     wlp.license_plate_number =
                                   xos.carton_number
                               AND xos.item_number = msi.segment1
                               AND xos.wh_id = mp.organization_code
                               AND msi.organization_id = mp.organization_id
                               AND xos.serial_number = xst.serial_number
                               AND xos.process_status = 'PROCESSED'
                               AND xos.shipment_number = p_in_chr_shipment_no
                               AND xos.request_id = g_num_parent_req_id)
             WHERE EXISTS
                       (SELECT 1
                          FROM xxdo_ont_ship_conf_carser_stg xos
                         WHERE     xos.process_status = 'PROCESSED'
                               AND xos.serial_number = xst.serial_number
                               AND xos.shipment_number = p_in_chr_shipment_no
                               AND xos.request_id = g_num_parent_req_id); /* change this */

            INSERT INTO xxdo.xxdo_serial_temp xst (serial_number,
                                                   lpn_id,
                                                   license_plate_number,
                                                   inventory_item_id,
                                                   last_update_date,
                                                   last_updated_by,
                                                   creation_date,
                                                   created_by,
                                                   organization_id,
                                                   status_id,
                                                   source_code,
                                                   source_code_reference)
                SELECT xos.serial_number, wlp.lpn_id, xos.carton_number,
                       msi.inventory_item_id, SYSDATE, g_num_user_id,
                       SYSDATE, g_num_user_id, msi.organization_id,
                       1, 'SHIP_CONFIRM', xos.line_number
                  FROM xxdo_ont_ship_conf_carser_stg xos, wms_license_plate_numbers wlp, mtl_parameters mp,
                       mtl_system_items_kfv msi
                 WHERE     wlp.license_plate_number = xos.carton_number
                       AND xos.process_status = 'PROCESSED'
                       AND xos.item_number = msi.segment1
                       AND xos.wh_id = mp.organization_code
                       AND msi.organization_id = mp.organization_id
                       AND xos.shipment_number = p_in_chr_shipment_no
                       AND xos.request_id = g_num_parent_req_id
                       AND NOT EXISTS
                               (SELECT 1
                                  FROM xxdo.xxdo_serial_temp xst
                                 WHERE xos.serial_number = xst.serial_number);
        END IF;                                         -- End of Status check

        COMMIT;
    /* ROLLBACK_ALL - End */
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'ERROR in update error records procedure : '
                || p_out_chr_errbuf);
    END update_error_records;

    -- ***************************************************************************
    -- Procedure Name      :  pick_line
    --
    -- Description         :  This procedure will allocate and transact specified
    --                        move order line.
    --
    -- Parameters          :   p_out_chr_errbuf      OUT : Error message
    --                                p_out_chr_retcode     OUT : Execution Status
    --                                p_in_num_mo_line_id IN :  Move Order Line
    --                                p_in_txn_hdr_id     IN:  Transaction Header Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0   Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE pick_line (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_mo_line_id IN NUMBER
                         , p_in_txn_hdr_id IN NUMBER)
    IS
        l_num_number_of_rows         NUMBER;
        l_num_detailed_qty           NUMBER;
        l_chr_return_status          VARCHAR2 (1);
        l_num_msg_count              NUMBER;
        l_chr_msg_data               VARCHAR2 (32767);
        l_num_revision               NUMBER;
        l_num_locator_id             NUMBER;
        l_num_transfer_to_location   NUMBER;
        l_num_lot_number             NUMBER;
        l_dte_expiration_date        DATE;
        l_num_transaction_temp_id    NUMBER;
        l_num_msg_cntr               NUMBER;
        l_num_msg_index_out          NUMBER;
        l_trolin_tbl                 inv_move_order_pub.trolin_tbl_type;
        l_mold_tbl                   inv_mo_line_detail_util.g_mmtt_tbl_type;
        l_mmtt_tbl                   inv_mo_line_detail_util.g_mmtt_tbl_type;
        o_trolin_tbl                 inv_move_order_pub.trolin_tbl_type;
    BEGIN
        --Reset status variables
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        fnd_file.put_line (
            fnd_file.LOG,
            'Processing the move order line id :' || p_in_num_mo_line_id /* PACKED_MSG_DATE_BUG */
                                                                        );

        -- Call standard oracle API to perform the allocation and transaction
        inv_replenish_detail_pub.line_details_pub (p_line_id => p_in_num_mo_line_id, x_number_of_rows => l_num_number_of_rows, x_detailed_qty => l_num_detailed_qty, x_return_status => l_chr_return_status, x_msg_count => l_num_msg_count, x_msg_data => l_chr_msg_data, x_revision => l_num_revision, x_locator_id => l_num_locator_id, x_transfer_to_location => l_num_transfer_to_location, x_lot_number => l_num_lot_number, x_expiration_date => l_dte_expiration_date, x_transaction_temp_id => l_num_transaction_temp_id, p_transaction_header_id => p_in_txn_hdr_id, p_transaction_mode => 1, --2, bsk value changed as per 3PL logic
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        p_move_order_type => inv_globals.g_move_order_pick_wave, --3,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 p_serial_flag => NULL, p_plan_tasks => FALSE, p_auto_pick_confirm => FALSE
                                                   , p_commit => FALSE);
        fnd_file.put_line (fnd_file.LOG,
                           'Number of rows :' || l_num_number_of_rows);

        IF l_num_number_of_rows > 0
        THEN
            l_trolin_tbl   :=
                inv_trolin_util.query_rows (p_line_id => p_in_num_mo_line_id);
            inv_pick_wave_pick_confirm_pub.pick_confirm (
                p_api_version_number   => 1.0,
                p_init_msg_list        => fnd_api.g_true,
                -- p_commit                  => fnd_api.g_false,  /* ROLLBACK_ALL - Start*/
                p_commit               => fnd_api.g_true, /* ROLLBACK_ALL - End */
                x_return_status        => l_chr_return_status,
                x_msg_count            => l_num_msg_count,
                x_msg_data             => l_chr_msg_data,
                p_move_order_type      => 3,
                p_transaction_mode     => 1,                              --2,
                p_trolin_tbl           => l_trolin_tbl,
                p_mold_tbl             => l_mold_tbl,
                x_mmtt_tbl             => l_mmtt_tbl,
                x_trolin_tbl           => o_trolin_tbl,
                --p_transaction_date        => NULL
                p_transaction_date     => SYSDATE        /* MOVE_ORDER_DATE */
                                                 );


            IF l_chr_return_status <> fnd_api.g_ret_sts_success
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'API to confirm picking failed with status: '
                    || l_chr_return_status
                    || ' Move Line ID : '
                    || p_in_num_mo_line_id
                    || 'Error: '
                    || l_chr_msg_data;               /* PACKED_MSG_DATE_BUG */
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                -- Retrieve messages
                l_num_msg_cntr      := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || l_chr_msg_data);
                END LOOP;
            ELSE
                p_out_chr_errbuf   :=
                       'API to confirm picking was successful with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

                UPDATE wsh_delivery_details
                   SET attribute15   = 'Pick Confirmed'
                 WHERE move_order_line_id = p_in_num_mo_line_id;
            END IF;
        ELSE
            /* PACKED_MSG_DATE_BUG  - Start*/

            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    :=
                   'API to allocate and transact line completed with status: '
                || l_chr_return_status
                || '. Since number of rows is: 0'
                || p_in_num_mo_line_id
                || ' line cannot be picked.';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            l_num_msg_cntr      := 1;

            fnd_file.put_line (fnd_file.LOG,
                               'l_chr_msg_data : ' || l_chr_msg_data);

            WHILE l_num_msg_cntr <= l_num_msg_count
            LOOP
                fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                 , p_msg_index_out => l_num_msg_index_out);
                l_num_msg_cntr   := l_num_msg_cntr + 1;
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message: ' || l_chr_msg_data);
            END LOOP;
        /* PACKED_MSG_DATE_BUG  - End*/
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    :=
                   'Error while picking move order line id '
                || p_in_num_mo_line_id
                || ': '
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END pick_line;

    -- ***************************************************************************
    -- Procedure Name      :  create_trip
    --
    -- Description         :  This procedure creates a trip with given information.
    --
    -- Parameters          :
    --                              p_out_chr_errbuf             OUT : Error Message
    --                              p_out_chr_retcode            OUT : Execution Status
    --                              p_in_chr_trip                IN  : Trip name / Shipment Number
    --                              p_in_chr_carrier             IN  : Carrier Name
    --                              p_in_num_carrier_id          IN  : Carrier Id
    --                              p_in_chr_vehicle_number      IN  : Vehicle Number
    --                              p_in_chr_mode_of_transport   IN  : Mode of Transport
    --                              p_in_chr_master_bol_number   IN  : Master BOL
    --                              p_out_num_trip_id            OUT : New Trip Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0   Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE create_trip (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_trip IN VARCHAR2, p_in_chr_carrier IN VARCHAR2, p_in_num_carrier_id IN NUMBER, p_in_chr_vehicle_number IN VARCHAR2
                           , p_in_chr_mode_of_transport IN VARCHAR2, p_in_chr_master_bol_number IN VARCHAR2, p_out_num_trip_id OUT NUMBER)
    IS
        l_chr_return_status    VARCHAR2 (30) := NULL;
        l_num_msg_count        NUMBER;
        l_num_msg_cntr         NUMBER;
        l_num_msg_index_out    NUMBER;
        l_chr_msg_data         VARCHAR2 (2000);
        l_num_trip_id          NUMBER;
        l_chr_trip_name        VARCHAR2 (240);
        l_num_carrier_id       NUMBER := NULL;
        l_rec_trip_info        wsh_trips_pub.trip_pub_rec_type;
        l_chr_transport_code   VARCHAR2 (50);
        excp_set_error         EXCEPTION;
    BEGIN
        --Reset status variables
        p_out_chr_errbuf                    := NULL;
        p_out_chr_retcode                   := '0';

        -- Resolve Carrier_ID
        IF p_in_num_carrier_id IS NOT NULL
        THEN
            l_rec_trip_info.carrier_id   := p_in_num_carrier_id;
        ELSE
            BEGIN
                SELECT wcv.carrier_id
                  INTO l_num_carrier_id
                  FROM wsh_carriers_v wcv
                 WHERE wcv.carrier_name = p_in_chr_carrier;

                l_rec_trip_info.carrier_id   := l_num_carrier_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_carrier_id   := NULL;
                    p_out_chr_errbuf   :=
                           'No Carrier found by the Name: '
                        || p_in_chr_carrier
                        || ' : Error is: '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'No Carrier found by the Name: '
                        || p_in_chr_carrier
                        || ' : Error is: '
                        || SQLERRM);
                    RAISE excp_set_error;
            END;
        END IF;

        IF p_in_chr_mode_of_transport IS NOT NULL
        THEN
            BEGIN
                SELECT lookup_code
                  INTO l_chr_transport_code
                  FROM fnd_lookup_values_vl flvv
                 WHERE     flvv.lookup_type = 'WSH_MODE_OF_TRANSPORT'
                       AND flvv.meaning = p_in_chr_mode_of_transport
                       AND flvv.enabled_flag = 'Y'
                       AND (TRUNC (SYSDATE) BETWEEN NVL (TRUNC (flvv.start_date_active), TRUNC (SYSDATE) - 1) AND NVL (TRUNC (flvv.end_date_active), TRUNC (SYSDATE) + 1));
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_chr_transport_code   := NULL;
                    p_out_chr_errbuf       :=
                           'Error while resolving mode of transport from lookup '
                        || 'WSH_MODE_OF_TRANSPORT for the transport code '
                        || p_in_chr_mode_of_transport
                        || '. '
                        || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while resolving mode of transport from lookup '
                        || 'WSH_MODE_OF_TRANSPORT for the transport code '
                        || p_in_chr_mode_of_transport
                        || '. '
                        || SQLERRM);
                    RAISE excp_set_error;
            END;
        END IF;

        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling CREATE_UPDATE_TRIP API...');
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Trip Name      : ' || p_in_chr_trip);
        fnd_file.put_line (fnd_file.LOG,
                           'Carrier ID      : ' || l_num_carrier_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Vehicle Number    :' || p_in_chr_vehicle_number);
        fnd_file.put_line (fnd_file.LOG,
                           'Mode Of Transport : ' || l_chr_transport_code);
        fnd_file.put_line (fnd_file.LOG, ' ');
        l_rec_trip_info.NAME                := p_in_chr_trip;
        l_rec_trip_info.carrier_id          := l_num_carrier_id;
        l_rec_trip_info.vehicle_number      := p_in_chr_vehicle_number;
        l_rec_trip_info.mode_of_transport   := l_chr_transport_code;
        --      l_rec_trip_info.attribute1 := p_in_chr_master_bol_number;  -- bsk removed
        wsh_trips_pub.create_update_trip (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_action_code          => 'CREATE',
            p_trip_info            => l_rec_trip_info,
            x_trip_id              => l_num_trip_id,
            x_trip_name            => l_chr_trip_name);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'API to create trip failed with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            IF l_num_msg_count > 0
            THEN
                p_out_num_trip_id   := 0;
                -- Retrieve messages
                l_num_msg_cntr      := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_errbuf    := l_chr_msg_data;
            END IF;
        ELSE
            p_out_num_trip_id   := l_num_trip_id;
            p_out_chr_retcode   := '0';
            p_out_chr_errbuf    :=
                   'API to create trip was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Trip ID > '
                || TO_CHAR (l_num_trip_id)
                || ': Trip Name > '
                || l_chr_trip_name);
        END IF;

        -- Reset stop seq number
        fnd_file.put_line (fnd_file.LOG,
                           'End Calling CREATE_UPDATE_TRIP API...');
    EXCEPTION
        WHEN excp_set_error
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'Unexpected error occurred in the Creation of Trip while creating trip for Shipment Number: '
                || p_in_chr_trip
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error occurred in the Creation of Trip while creating trip for Shipment Number: '
                || p_in_chr_trip
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END create_trip;

    -- ***************************************************************************
    -- Procedure Name      :  create_stop
    --
    -- Description         :  This procedure creates stops for a trip
    --
    -- Parameters          :
    --                            p_out_chr_errbuf            OUT : Error Message
    --                            p_out_chr_retcode           OUT : Execution Status
    --                            p_in_chr_ship_type          IN  : Shipment Type
    --                            p_in_num_trip_id            IN  :  Trip Id
    --                            p_in_num_stop_seq           IN  : Stop Sequence Number
    --                            p_in_num_stop_location_id   IN  : Stop Location Id
    --                            p_in_chr_dep_seal_code      IN  : Departure Seal Code
    --                            p_out_num_stop_id           OUT : New Stop Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/25    Infosys            1.0  Initial Version.
    -- ***************************************************************************
    PROCEDURE create_stop (p_out_chr_errbuf               OUT VARCHAR2,
                           p_out_chr_retcode              OUT VARCHAR2,
                           p_in_chr_ship_type          IN     VARCHAR2,
                           p_in_num_trip_id            IN     VARCHAR2,
                           p_in_num_stop_seq           IN     NUMBER,
                           p_in_num_stop_location_id   IN     VARCHAR2,
                           p_in_chr_dep_seal_code      IN     VARCHAR2,
                           p_out_num_stop_id              OUT NUMBER)
    IS
        l_num_msg_count       NUMBER;
        l_num_msg_cntr        NUMBER;
        l_num_msg_index_out   NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_chr_return_status   VARCHAR2 (30) := NULL;
        l_rec_stop_nfo        wsh_trip_stops_pub.trip_stop_pub_rec_type;
        l_num_stop_id         NUMBER := 0;
        l_num_seq             NUMBER := 0;
    /*
          CURSOR csr_stops
          IS
             SELECT stop_sequence_number
               FROM wsh_trip_stops
              WHERE trip_id = p_in_num_trip_id;
    */
    BEGIN
        --Reset status variables
        p_out_chr_errbuf                  := NULL;
        p_out_chr_retcode                 := '0';

        IF p_in_chr_ship_type = 'SHIP_TO'
        THEN
            --         l_rec_stop_nfo.attribute1 := TO_CHAR (p_in_num_stop_seq); -- bsk not required
            l_rec_stop_nfo.departure_seal_code   := p_in_chr_dep_seal_code;
        END IF;

        l_rec_stop_nfo.trip_id            := p_in_num_trip_id;
        l_rec_stop_nfo.stop_location_id   := p_in_num_stop_location_id;

        -- Set stop sequence number
        --      g_num_stop_seq := g_num_stop_seq + 10; --bsk not required
        IF p_in_num_stop_seq IS NULL
        THEN
            -- Resolve stop sequence number
            BEGIN
                SELECT MAX (stop_sequence_number)
                  INTO l_num_seq
                  FROM wsh_trip_stops
                 WHERE trip_id = p_in_num_trip_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_num_seq   := 0;
            END;

            --      g_num_stop_seq := NVL (l_num_seq, 0) + 10; --bsk not required
            --      l_rec_stop_nfo.stop_sequence_number := g_num_stop_seq; --bsk not required
            l_rec_stop_nfo.stop_sequence_number   := NVL (l_num_seq, 0) + 10;
        ELSE
            l_rec_stop_nfo.stop_sequence_number   := p_in_num_stop_seq;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Start Calling create update stop API for Stop Number: '
            || l_rec_stop_nfo.stop_sequence_number);
        wsh_trip_stops_pub.create_update_stop (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_action_code          => 'CREATE',
            p_stop_info            => l_rec_stop_nfo,
            x_stop_id              => l_num_stop_id);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'API to create update stop failed with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            IF l_num_msg_count > 0
            THEN
                p_out_num_stop_id   := 0;
                -- Retrieve messages
                l_num_msg_cntr      := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_errbuf    := l_chr_msg_data;
            END IF;
        ELSE
            p_out_num_stop_id   := l_num_stop_id;
            p_out_chr_retcode   := '0';
            p_out_chr_errbuf    :=
                   'API to create update stop was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                p_in_chr_ship_type || ' Stop ID : ' || l_num_stop_id);
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'End Calling create update stop API...');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'An unexpected error occurred in the Creation of Stop. Trip ID > '
                || p_in_num_trip_id
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE;
            fnd_file.put_line (
                fnd_file.LOG,
                   'An unexpected error occurred in the Creation of Stop. Trip ID > '
                || p_in_num_trip_id
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END create_stop;

    -- ***************************************************************************
    -- Procedure Name      :  create_delivery
    --
    -- Description         :  This procedure creates Delivery for partial and multiple shipment case
    --
    -- Parameters          :
    --                                p_out_chr_errbuf            OUT : Error Message
    --                                p_out_chr_retcode           OUT :    Execution Status
    --                                p_in_num_wdd_org_id         IN  :    Inventory Org Id
    --                                p_in_num_wdd_cust_id        IN  : Customer Id
    --                                p_in_num_wdd_ship_method    IN  : Shipment Method
    --                                p_in_num_ship_from_loc_id   IN  : Ship from Location Id
    --                                p_in_num_ship_to_loc_id     IN  : Ship To Location Id
    --                                p_in_chr_carrier            IN  : Carrier
    --                                p_in_chr_waybill            IN  : Waybill
    --                                p_in_chr_orig_del_name      IN  : Original Delivery Name
    --                                p_in_chr_tracking_number    IN  : Tracking Number
    --                                p_out_num_delivery_id       OUT : New Delivery Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/25    Infosys            1.0   Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE create_delivery (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_wdd_org_id IN NUMBER, p_in_num_wdd_cust_id IN NUMBER, p_in_num_wdd_ship_method IN VARCHAR2, p_in_num_ship_from_loc_id IN NUMBER, p_in_num_ship_to_loc_id IN NUMBER, p_in_chr_carrier IN VARCHAR2, p_in_chr_waybill IN VARCHAR2
                               , p_in_chr_orig_del_name IN VARCHAR2, p_in_chr_tracking_number IN VARCHAR2, p_out_num_delivery_id OUT NUMBER)
    IS
        l_chr_return_status   VARCHAR2 (30) := NULL;
        l_num_msg_count       NUMBER;
        l_num_msg_cntr        NUMBER;
        l_num_msg_index_out   NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_num_delivery_id     NUMBER;
        l_chr_delivery_name   VARCHAR2 (240);
        l_rec_delivery_info   wsh_deliveries_pub.delivery_pub_rec_type;
        l_num_trip_id         NUMBER;
        l_chr_trip_name       VARCHAR2 (240);
        l_num_to_stop         NUMBER;
    BEGIN
        --Reset status variables
        p_out_chr_retcode                      := '0';
        p_out_chr_errbuf                       := NULL;
        -- Set record info variables
        l_rec_delivery_info.organization_id    := p_in_num_wdd_org_id;
        l_rec_delivery_info.customer_id        := p_in_num_wdd_cust_id;
        l_rec_delivery_info.ship_method_code   := p_in_num_wdd_ship_method;
        l_rec_delivery_info.initial_pickup_location_id   :=
            p_in_num_ship_from_loc_id;
        l_rec_delivery_info.ultimate_dropoff_location_id   :=
            p_in_num_ship_to_loc_id;
        l_rec_delivery_info.waybill            :=
            p_in_chr_waybill;
        l_rec_delivery_info.attribute11        :=
            p_in_chr_orig_del_name;
        l_rec_delivery_info.attribute2         :=
            p_in_chr_carrier;
        l_rec_delivery_info.attribute1         :=
            p_in_chr_tracking_number;
        -- Call create_update_delivery api
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling create update delivery API..');
        wsh_deliveries_pub.create_update_delivery (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_action_code          => 'CREATE',
            p_delivery_info        => l_rec_delivery_info,
            x_delivery_id          => l_num_delivery_id,
            x_name                 => l_chr_delivery_name);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'API to create delivery failed with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            IF l_num_msg_count > 0
            THEN
                p_out_num_delivery_id   := 0;
                -- Retrieve messages
                l_num_msg_cntr          := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message:' || l_chr_msg_data);
                END LOOP;
            END IF;
        ELSE
            p_out_chr_errbuf        :=
                   'API to create delivery was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            p_out_num_delivery_id   := l_num_delivery_id;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery ID > '
                || TO_CHAR (l_num_delivery_id)
                || ' : Delivery Name > '
                || l_chr_delivery_name);
            fnd_file.put_line (fnd_file.LOG,
                               'End Calling create update delivery.api..');
        ---Update the original delivery name
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                'Error while creating delivery.' || SQLERRM;
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
    -- Procedure Name      :  ship_confirm_deliveries
    --
    -- Description         :  This procedure peforms ship confirmation of
    --                        Deliveries in a Shipment
    --
    -- Parameters          :
    --                            p_out_chr_errbuf             OUT : Error Message
    --                            p_out_chr_retcode            OUT : Execution Status
    --                            p_in_dt_actual_dep_date      IN  : Departure Date
    --                            p_in_tabtype_id_deliveries   IN  : Delivery ids which need to be ship confirmed
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/25    Infosys            1.0  Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE ship_confirm_deliveries (
        p_out_chr_errbuf                OUT VARCHAR2,
        p_out_chr_retcode               OUT VARCHAR2,
        p_in_dt_actual_dep_date      IN     DATE,
        p_in_tabtype_id_deliveries   IN     tabtype_id)
    IS
        l_chr_return_status    VARCHAR2 (30) := NULL;
        l_num_msg_count        NUMBER;
        l_num_msg_cntr         NUMBER;
        l_num_msg_index_out    NUMBER;
        l_chr_msg_data         VARCHAR2 (4000);
        l_chr_source_code      VARCHAR2 (15) := 'OE';
        l_num_trip_id          NUMBER;
        l_chr_trip_name        VARCHAR2 (240);
        l_num_del_id           NUMBER;
        excp_set_error         EXCEPTION;
        l_sc_close_trip_flag   VARCHAR2 (1) := 'N';
        l_chr_st               VARCHAR2 (5) := 'OP';
        l_chr_errbuf           VARCHAR2 (2000) := NULL;
        l_chr_ret_code         VARCHAR2 (1) := '0';
    BEGIN
        --Reset status variables
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;

        -- Start a loop over given deliveries
        IF p_in_tabtype_id_deliveries.COUNT > 0
        THEN
            FOR i IN 1 .. p_in_tabtype_id_deliveries.COUNT
            LOOP
                l_num_del_id   := p_in_tabtype_id_deliveries (i);
                fnd_file.put_line (fnd_file.LOG, ' ');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Start Calling delivery_action to confirm delivery'
                    || l_num_del_id);

                -- For last delivery set l_sc_close_trip_flag to Y
                IF i = p_in_tabtype_id_deliveries.COUNT
                THEN
                    l_sc_close_trip_flag   := 'Y';
                ELSE
                    l_sc_close_trip_flag   := 'N';
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Close Trip Flag: ' || l_sc_close_trip_flag);
                wsh_deliveries_pub.delivery_action (
                    p_api_version_number        => g_num_api_version,
                    p_init_msg_list             => fnd_api.g_true,
                    x_return_status             => l_chr_return_status,
                    x_msg_count                 => l_num_msg_count,
                    x_msg_data                  => l_chr_msg_data,
                    p_action_code               => 'CONFIRM',
                    p_delivery_id               => p_in_tabtype_id_deliveries (i),
                    p_sc_action_flag            => 'T',
                    -- B as per 3PL inteface
                    p_sc_close_trip_flag        => l_sc_close_trip_flag,
                    p_sc_stage_del_flag         => 'Y',
                    --                                            p_sc_intransit_flag       => 'Y'  ,
                    p_sc_defer_interface_flag   => 'Y',
                    p_sc_actual_dep_date        => p_in_dt_actual_dep_date,
                    x_trip_id                   => l_num_trip_id,
                    x_trip_name                 => l_chr_trip_name);

                IF l_chr_return_status NOT IN
                       (fnd_api.g_ret_sts_success, g_ret_sts_warning) /* SHIP_CONFIRM_WARNING */
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'API to confirm shipment completed with status: '
                        || l_chr_return_status;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

                    IF l_num_msg_count > 0
                    THEN
                        -- Retrieve messages
                        l_num_msg_cntr   := 1;

                        WHILE l_num_msg_cntr <= l_num_msg_count
                        LOOP
                            fnd_msg_pub.get (
                                p_msg_index       => l_num_msg_cntr,
                                p_encoded         => 'F',
                                p_data            => l_chr_msg_data,
                                p_msg_index_out   => l_num_msg_index_out);
                            l_num_msg_cntr   := l_num_msg_cntr + 1;
                            --fnd_file.put_line (fnd_file.LOG, l_chr_msg_data);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Error Message : ' || l_chr_msg_data);
                        END LOOP;
                    END IF;
                ELSE
                    p_out_chr_errbuf   :=
                           'API to confirm shipment was successful with status: '
                        || l_chr_return_status;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Ship Confirmed Delivery > '
                        || TO_CHAR (l_num_del_id));
                END IF;
            END LOOP;
        END IF;

        -- Call trip stop interface for each delivery
        IF p_out_chr_retcode = '0'
        THEN
            FOR i IN 1 .. p_in_tabtype_id_deliveries.COUNT
            LOOP
                l_num_del_id   := p_in_tabtype_id_deliveries (i);
                fnd_file.put_line (fnd_file.LOG, ' ');

                BEGIN
                    --Run the interface trip stop for current delivery id
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Calling interface_trip_stop for delivery: '
                        || p_in_tabtype_id_deliveries (i));
                    wsh_ship_confirm_actions.interface_all_wrp (
                        errbuf          => l_chr_errbuf,
                        retcode         => l_chr_ret_code,
                        p_mode          => 'ALL',
                        p_delivery_id   => p_in_tabtype_id_deliveries (i));
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Completed interface trip stop with return code '
                        || l_chr_ret_code);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error while running interface_trip_stop for delivery: '
                            || p_in_tabtype_id_deliveries (i));
                        p_out_chr_retcode   := '2';
                END;
            END LOOP;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'No Delivery to Ship Confirm.');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
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
    END ship_confirm_deliveries;

    -- ***************************************************************************
    -- Procedure Name      :  main
    --
    -- Description         :  This is the driver procedure for ship confirm interface
    --
    -- Parameters          :
    --                                  p_out_chr_errbuf       OUT : Error Message
    --                                  p_out_chr_retcode      OUT : Execution Status
    --                                  p_in_chr_shipment_no   IN  : Shipment Number
    --                                  p_in_chr_source        IN  : Source
    --                                  p_in_chr_dest          IN  : Destination
    --                                  p_in_num_purge_days    IN  : Purge Days
    --                                  p_in_num_bulk_limit    IN  : Bulk Limit
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2, p_in_chr_source IN VARCHAR2, p_in_chr_dest IN VARCHAR2, p_in_num_purge_days IN NUMBER
                    , p_in_num_bulk_limit IN NUMBER)
    IS
        l_chr_errbuf                 VARCHAR2 (4000);
        l_chr_retcode                VARCHAR2 (30);
        l_bol_req_status             BOOLEAN;
        l_chr_req_failure            VARCHAR2 (1) := 'N';
        l_chr_phase                  VARCHAR2 (100) := NULL;
        l_chr_status                 VARCHAR2 (100) := NULL;
        l_chr_dev_phase              VARCHAR2 (100) := NULL;
        l_chr_dev_status             VARCHAR2 (100) := NULL;
        l_chr_message                VARCHAR2 (1000) := NULL;
        l_num_request_id             NUMBER := 0;

        l_exe_bulk_fetch_failed      EXCEPTION;

        --      l_shipconf_headers_obj_tab   shipconf_headers_obj_tab_type;

        CURSOR cur_shipment_data IS
            SELECT shipment_number
              /*         SELECT shipconf_headers_obj_type
                                                      (wh_id,
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
                                                       NULL
                                                      )                  -- deliveries table
              */
              FROM xxdo_ont_ship_conf_head_stg shipment
             WHERE     process_status = 'INPROCESS'
                   AND request_id = g_num_request_id
                   AND shipment_number =
                       NVL (p_in_chr_shipment_no, shipment_number);

        TYPE l_ship_headers_obj_tab_type
            IS TABLE OF cur_shipment_data%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_shipconf_headers_obj_tab   l_ship_headers_obj_tab_type;

        CURSOR cur_shipment_data_ranked IS
            SELECT shipment_number
              FROM xxdo_ont_ship_conf_head_stg shipment
             WHERE     process_status = 'INPROCESS'
                   AND request_id = g_num_request_id
                   AND shipment_number IN
                           (SELECT ranked_ship.shipment_number
                              FROM xxdo_ont_ship_conf_order_stg ranked_ship
                             WHERE     ranked_ship.process_status =
                                       'INPROCESS'
                                   AND ranked_ship.request_id =
                                       g_num_request_id
                                   AND ranked_ship.order_number IN
                                           (  SELECT common_del.order_number
                                                FROM xxdo_ont_ship_conf_order_stg common_del
                                               WHERE     common_del.process_status =
                                                         'INPROCESS'
                                                     AND common_del.request_id =
                                                         g_num_request_id
                                            GROUP BY common_del.order_number
                                              HAVING COUNT (1) > 1));

        /* CHANGE_CARTON_NO - Start */
        CURSOR cur_existing_cartons IS
            SELECT carton_number
              FROM xxdo_ont_ship_conf_carton_stg carton, wms_license_plate_numbers lpn
             WHERE     carton.process_status = 'INPROCESS'
                   AND carton.request_id = g_num_request_id
                   AND carton.carton_number = lpn.license_plate_number;
    /* CHANGE_CARTON_NO - End */
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        -- If shipment no is passed, reset the status before processing
        IF p_in_chr_shipment_no IS NOT NULL
        THEN
            reset_error_records (
                p_out_chr_errbuf       => l_chr_errbuf,
                p_out_chr_retcode      => l_chr_retcode,
                p_in_chr_shipment_no   => p_in_chr_shipment_no);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error status is cleared for the shipment No:'
                || p_in_chr_shipment_no);
        END IF;

        -- Lock the records by updating the status to INPROCESS and request id to current request id
        lock_records (p_out_chr_errbuf       => l_chr_errbuf,
                      p_out_chr_retcode      => l_chr_retcode,
                      p_in_chr_shipment_no   => p_in_chr_shipment_no);

        /*  CHANGE_CARTON_NO - Start */
        -- If the carton is already existing,  change
        /* UPDATE_CARTON_NO - Start */

        /*
                FOR existing_cartons_rec IN cur_existing_cartons
                LOOP

                    UPDATE xxdo_ont_ship_conf_carton_stg carton
                         SET carton.carton_number = existing_cartons_rec.carton_number || '_1',
                                carton.attribute1 = existing_cartons_rec.carton_number,
                                last_update_date = SYSDATE,
                                last_updated_by = g_num_user_id
                      WHERE carton.process_status = 'INPROCESS'
                          AND carton.request_id = g_num_request_id
                          AND carton.carton_number = existing_cartons_rec.carton_number;

                    UPDATE xxdo_ont_ship_conf_cardtl_stg carton
                         SET carton.carton_number = existing_cartons_rec.carton_number || '_1',
                                carton.attribute1 = existing_cartons_rec.carton_number,
                                last_update_date = SYSDATE,
                                last_updated_by = g_num_user_id
                      WHERE carton.process_status = 'INPROCESS'
                          AND carton.request_id = g_num_request_id
                          AND carton.carton_number = existing_cartons_rec.carton_number;

                END LOOP;
        */
        FOR existing_cartons_rec IN cur_existing_cartons
        LOOP
            UPDATE wms_license_plate_numbers lpn
               SET license_plate_number = existing_cartons_rec.carton_number || '_1'
             WHERE license_plate_number = existing_cartons_rec.carton_number;

            UPDATE xxdo_ont_ship_conf_carton_stg carton
               SET carton.attribute1 = 'WMS Carton Number Suffixed with _1', last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     carton.process_status = 'INPROCESS'
                   AND carton.request_id = g_num_request_id
                   AND carton.carton_number =
                       existing_cartons_rec.carton_number;

            UPDATE xxdo_ont_ship_conf_cardtl_stg carton
               SET carton.attribute1 = 'WMS Carton Number Suffixed with _1', last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     carton.process_status = 'INPROCESS'
                   AND carton.request_id = g_num_request_id
                   AND carton.carton_number =
                       existing_cartons_rec.carton_number;
        END LOOP;


        COMMIT;

        /* UPDATE_CARTON_NO - End */

        /*  CHANGE_CARTON_NO - End */
        -- Process the shipments which share the same deliveries
        -- Each shipment will be processed one by one

        l_chr_req_failure   := 'N';
        fnd_file.put_line (fnd_file.LOG, '');
        fnd_file.put_line (
            fnd_file.LOG,
            '-------------Concurrent Requests Status Report ---------------');


        FOR shipment_data_ranked_rec IN cur_shipment_data_ranked
        LOOP
            l_num_request_id   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXDOSCST',
                    argument1     => shipment_data_ranked_rec.shipment_number,
                    argument2     => g_num_request_id,     --Parent Request ID
                    description   => NULL,
                    start_time    => NULL);
            COMMIT;

            IF l_num_request_id = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Shipment number : '
                    || shipment_data_ranked_rec.shipment_number
                    || '  Shipment Processor - Concurrent Request is not launched');
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                    'One or more Shipment Processor Threads are not launched. Please refer the log file for more details';
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Shipment number : '
                    || shipment_data_ranked_rec.shipment_number
                    || ' Shipment Processor - Concurrent Request ID : '
                    || l_num_request_id);
            END IF;


            l_bol_req_status   :=
                fnd_concurrent.wait_for_request (l_num_request_id,
                                                 10,
                                                 0,
                                                 l_chr_phase,
                                                 l_chr_status,
                                                 l_chr_dev_phase,
                                                 l_chr_dev_status,
                                                 l_chr_message);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Concurrent request ID : '
                || l_num_request_id
                || CHR (9)
                || ' Phase: '
                || l_chr_phase
                || CHR (9)
                || ' Status: '
                || l_chr_status
                || CHR (9)
                || ' Dev Phase: '
                || l_chr_dev_phase
                || CHR (9)
                || ' Dev Status: '
                || l_chr_dev_status
                || CHR (9)
                || ' Message: '
                || l_chr_message);

            IF NOT (UPPER (l_chr_phase) = 'COMPLETED' AND UPPER (l_chr_status) = 'NORMAL')
            THEN
                l_chr_req_failure   := 'Y';
            END IF;
        END LOOP;


        IF l_chr_req_failure = 'Y'
        THEN
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    :=
                'One or more Shipment Processor Threads ended in Warning or Error. Please refer the log file for more details';
        END IF;



        --- Fetch all other eligible shipments to be processed
        OPEN cur_shipment_data;

        LOOP
            IF l_shipconf_headers_obj_tab.EXISTS (1)
            THEN
                l_shipconf_headers_obj_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_shipment_data
                    BULK COLLECT INTO l_shipconf_headers_obj_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf   := 'Error in BULK Fetch : ' || SQLERRM;
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error in BULK Fetch : ' || p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;

            IF NOT l_shipconf_headers_obj_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF g_ship_request_ids_tab.EXISTS (1)
            THEN
                g_ship_request_ids_tab.DELETE;
            END IF;

            FOR l_num_index IN l_shipconf_headers_obj_tab.FIRST ..
                               l_shipconf_headers_obj_tab.LAST
            LOOP
                g_ship_request_ids_tab (l_num_index)   :=
                    fnd_request.submit_request (
                        application   => 'XXDO',
                        program       => 'XXDOSCST',
                        argument1     =>
                            l_shipconf_headers_obj_tab (l_num_index).shipment_number,
                        argument2     => g_num_request_id, --Parent Request ID
                        description   => NULL,
                        start_time    => NULL);
                COMMIT;

                IF g_ship_request_ids_tab (l_num_index) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Shipment number : '
                        || l_shipconf_headers_obj_tab (l_num_index).shipment_number
                        || '  Shipment Processor - Concurrent Request is not launched');
                    p_out_chr_retcode   := '1';
                    p_out_chr_errbuf    :=
                        'One or more Shipment Processor Threads are not launched. Please refer the log file for more details';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Shipment number : '
                        || l_shipconf_headers_obj_tab (l_num_index).shipment_number
                        || ' Shipment Processor - Concurrent Request ID : '
                        || g_ship_request_ids_tab (l_num_index));
                END IF;
            END LOOP;

            COMMIT;
            l_chr_req_failure   := 'N';

            --         fnd_file.put_line (fnd_file.LOG, '');
            --         fnd_file.put_line
            --             (fnd_file.LOG,
            --              '-------------Concurrent Requests Status Report ---------------'
            --             );

            FOR l_num_index IN 1 .. g_ship_request_ids_tab.COUNT
            LOOP
                l_bol_req_status   :=
                    fnd_concurrent.wait_for_request (
                        g_ship_request_ids_tab (l_num_index),
                        10,
                        0,
                        l_chr_phase,
                        l_chr_status,
                        l_chr_dev_phase,
                        l_chr_dev_status,
                        l_chr_message);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Concurrent request ID : '
                    || g_ship_request_ids_tab (l_num_index)
                    || CHR (9)
                    || ' Phase: '
                    || l_chr_phase
                    || CHR (9)
                    || ' Status: '
                    || l_chr_status
                    || CHR (9)
                    || ' Dev Phase: '
                    || l_chr_dev_phase
                    || CHR (9)
                    || ' Dev Status: '
                    || l_chr_dev_status
                    || CHR (9)
                    || ' Message: '
                    || l_chr_message);

                IF NOT (UPPER (l_chr_phase) = 'COMPLETED' AND UPPER (l_chr_status) = 'NORMAL')
                THEN
                    l_chr_req_failure   := 'Y';
                END IF;
            END LOOP;

            fnd_file.put_line (fnd_file.LOG, '');

            IF l_chr_req_failure = 'Y'
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                    'One or more Shipment Processor Threads ended in Warning or Error. Please refer the log file for more details';
            END IF;
        END LOOP;

        CLOSE cur_shipment_data;

        BEGIN
            generate_error_report (p_out_chr_errbuf    => l_chr_errbuf,
                                   p_out_chr_retcode   => l_chr_retcode);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    :=
                       'Error in Generate Error Report procedure : '
                    || l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                       'Unexpected error while Generate Error Report procedure : '
                    || SQLERRM;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;

        -- Purge the records
        BEGIN
            PURGE (p_out_chr_errbuf      => l_chr_errbuf,
                   p_out_chr_retcode     => l_chr_retcode,
                   p_in_num_purge_days   => p_in_num_purge_days);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    :=
                    'Error in Purge procedure : ' || l_chr_errbuf;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    p_in_num_purge_days || ' old days records are purged');
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                       'Unexpected error while invoking purge procedure : '
                    || SQLERRM;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error at main procedure : ' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END main;

    -- ***************************************************************************
    -- Procedure Name      :  generate_error_report
    --
    -- Description         :  This procedure is to generate the error report for the current run
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE generate_error_report (p_out_chr_errbuf    OUT VARCHAR2,
                                     p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_chr_mail_err_report   VARCHAR2 (1) := 'N';

        CURSOR cur_errored_shipments IS
            SELECT shipment.wh_id, shipment.shipment_number, shipment.master_load_ref,
                   shipment.customer_load_id, shipment.ship_date, shipment.employee_name,
                   delivery.order_number, carton.carton_number, carton.tracking_number,
                   shipment.error_message || ' ' || delivery.error_message || ' ' || carton.error_message error_message
              FROM xxdo_ont_ship_conf_head_stg shipment, xxdo_ont_ship_conf_order_stg delivery, xxdo_ont_ship_conf_carton_stg carton
             WHERE     shipment.wh_id = delivery.wh_id
                   AND delivery.wh_id = carton.wh_id
                   AND shipment.shipment_number = delivery.shipment_number
                   AND delivery.shipment_number = carton.shipment_number
                   AND delivery.order_number = carton.order_number
                   AND shipment.request_id = g_num_request_id
                   AND delivery.request_id = g_num_request_id
                   AND carton.request_id = g_num_request_id
                   AND shipment.process_status = 'ERROR'
                   AND delivery.process_status = 'ERROR'
                   AND delivery.process_status = 'ERROR';
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG, 'Generating error report...');
        fnd_file.put_line (
            fnd_file.output,
            'Warehouse Code|Shipment Number|Master Load Ref|Customer Load Id|Ship Date|Employee Name|Order Number|Carton Number|Tracking Number|Error Message');

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
                || errored_shipments_rec.carton_number
                || '|'
                || errored_shipments_rec.tracking_number
                || '|'
                || errored_shipments_rec.error_message);
            l_chr_mail_err_report   := 'Y';
        END LOOP;

        IF l_chr_mail_err_report = 'Y'
        THEN
            -- bsk -- mailing error report to be included
            NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at generate error report procedure : '
                || p_out_chr_errbuf);
    END generate_error_report;

    -- ***************************************************************************
    -- Procedure Name      :  shipment_thread
    --
    -- Description         :  This procedure is to process the shipment - create trip, stops, launch delivery threads and ship confirm
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_chr_shipment_no  IN  : Shipment number
    --                              p_in_num_parent_req_id IN : Parent - Main Thread - Request Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    -- 18-Jan-18    Krishna L            1.1       CCR0006947 - Seal, Trailer and BOL changes
    --
    -- ***************************************************************************

    PROCEDURE shipment_thread (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2
                               , p_in_num_parent_req_id IN NUMBER)
    IS
        l_bol_req_status             BOOLEAN;
        l_chr_req_failure            VARCHAR2 (1) := 'N';
        l_chr_phase                  VARCHAR2 (100) := NULL;
        l_chr_status                 VARCHAR2 (100) := NULL;
        l_chr_dev_phase              VARCHAR2 (100) := NULL;
        l_chr_dev_status             VARCHAR2 (100) := NULL;
        l_chr_message                VARCHAR2 (1000) := NULL;
        l_chr_errbuf                 VARCHAR2 (2000);
        l_chr_retcode                VARCHAR2 (30);
        l_num_ship_from_loc_id       NUMBER := 0;
        l_num_stop_id                NUMBER := 0;
        l_num_trip_id                NUMBER := 0;
        l_num_existing_trip_id       NUMBER := 0;
        l_num_shipment_index         NUMBER := 1;
        l_num_inventory_org_id       NUMBER := -1;
        l_chr_period_open_flag       VARCHAR2 (1) := 'N';
        l_num_carrier_id             NUMBER := -1;
        l_num_del_index              NUMBER := 1;
        l_num_shipment_id            NUMBER := 0;

        /* ROLLBACK_ALL - Start */
        l_chr_packed_proc_status     VARCHAR2 (30);
        l_chr_pick_conf_failure      VARCHAR2 (1);
        /* ROLLBACK_ALL - End */


        l_delivery_request_ids_tab   tabtype_id;
        l_shipconfirm_del_ids_tab    tabtype_id;
        l_shipconf_headers_obj_tab   shipconf_headers_obj_tab_type;
        l_hold_source_tbl            g_hold_source_tbl_type;
        l_all_hold_source_tbl        g_hold_source_tbl_type;
        l_exe_bulk_fetch_failed      EXCEPTION;

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
                                          p_in_num_parent_req_id)
                               AS shipconf_orders_obj_tab_type))
              FROM xxdo_ont_ship_conf_head_stg shipment
             WHERE     process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id
                   AND shipment_number =
                       NVL (p_in_chr_shipment_no, shipment_number);

        CURSOR cur_ship_to_stops IS
            SELECT DISTINCT ship_to_location_id
              FROM xxdo_ont_ship_conf_order_stg
             WHERE     shipment_number = p_in_chr_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id;

        CURSOR cur_same_stop_del_nums (p_num_ship_to_loc_id IN NUMBER)
        IS
            SELECT order_number
              FROM xxdo_ont_ship_conf_order_stg
             WHERE     shipment_number = p_in_chr_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id
                   AND NVL (ship_to_location_id, -1) =
                       NVL (p_num_ship_to_loc_id, -1);

        CURSOR cur_delivery_ids IS
            SELECT delivery_id
              FROM xxdo_ont_ship_conf_order_stg
             WHERE     shipment_number = p_in_chr_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id;

        CURSOR cur_order_header_id (p_chr_delivery_number IN VARCHAR2)
        IS
            SELECT wdd.source_header_id
              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda
             WHERE     wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.NAME = p_chr_delivery_number
                   AND ROWNUM < 2;

        CURSOR cur_pick_conf_deliveries IS
            SELECT order_number, wh_id
              FROM xxdo_ont_ship_conf_order_stg delivery
             WHERE     shipment_number = p_in_chr_shipment_no
                   AND process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id
                   AND EXISTS
                           (SELECT 1
                              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda
                             WHERE     wnd.delivery_id = wda.delivery_id
                                   AND wda.delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND wnd.NAME = delivery.order_number
                                   AND wdd.released_status = 'S');

        CURSOR cur_mo_lines (p_chr_delivery_number IN VARCHAR2)
        IS
            SELECT DISTINCT mtrl.transaction_header_id, mtrl.line_id mo_line_id
              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda,
                   mtl_txn_request_lines mtrl
             WHERE     wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.NAME = p_chr_delivery_number
                   AND wdd.source_line_id = mtrl.txn_source_line_id
                   AND wdd.move_order_line_id = mtrl.line_id
                   AND wdd.released_status = 'S';

        -- Commented REMOVE_SHIPSET_ALL
        /*CURSOR cur_ship_set_orders IS
       SELECT header_id
         FROM (  SELECT ship.ship_set_id,
                        ship.header_id,
                        COUNT (DISTINCT ship.line_id)
                   FROM apps.oe_order_lines_all o,
                        apps.oe_order_lines_all ship,
                        apps.xxdo_ont_ship_conf_cardtl_stg s
                  WHERE     s.shipment_number = p_in_chr_shipment_no
                        AND s.line_number = o.line_id
                        AND o.ship_set_id = ship.ship_set_id
                        AND o.header_id = ship.header_id
               GROUP BY ship.ship_set_id, ship.header_id
               MINUS
                 SELECT ship_set_id, header_id, COUNT (DISTINCT o.line_id)
                   FROM apps.xxdo_ont_ship_conf_cardtl_stg s,
                        apps.oe_order_lines_all o
                  WHERE s.shipment_number = p_in_chr_shipment_no
                       AND s.line_number = o.line_id
               GROUP BY ship_set_id, header_id);*/

        -- Start REMOVE_SHIPSET_ALL
        CURSOR cur_ship_set_orders IS
            SELECT DISTINCT wnd.source_header_id header_id
              FROM apps.xxdo_ont_ship_conf_order_stg s, apps.wsh_new_deliveries wnd
             WHERE     s.shipment_number = p_in_chr_shipment_no
                   AND s.order_number = wnd.delivery_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.oe_order_lines_all ool
                             WHERE     ool.header_id = wnd.source_header_id
                                   AND ool.ship_set_id IS NOT NULL);
    -- End REMOVE_SHIPSET_ALL

    BEGIN
        p_out_chr_errbuf         := NULL;
        p_out_chr_retcode        := '0';

        g_num_parent_req_id      := p_in_num_parent_req_id;

        fnd_file.put_line (fnd_file.LOG,
                           'Parent Request ID: ' || p_in_num_parent_req_id);
        fnd_file.put_line (
            fnd_file.LOG,
               'Processing started for Shipment Number : '
            || p_in_chr_shipment_no);

        /* ROLLBACK_ALL - Start */
        /* ROLLBACK_ALL - Start */

        FOR pick_conf_deliveries_rec IN cur_pick_conf_deliveries
        LOOP
            l_chr_packed_proc_status   := NULL;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Pick confirm started for the delivery : '
                || pick_conf_deliveries_rec.order_number);

            BEGIN
                SELECT process_status
                  INTO l_chr_packed_proc_status
                  FROM xxdo_ont_pick_status_order
                 WHERE     order_number =
                           pick_conf_deliveries_rec.order_number
                       AND shipment_number = p_in_chr_shipment_no
                       AND wh_id = pick_conf_deliveries_rec.wh_id
                       AND status = 'PACKED';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    l_chr_packed_proc_status   := NULL;
                WHEN OTHERS
                THEN
                    l_chr_packed_proc_status   := NULL;
            END;

            IF    l_chr_packed_proc_status IS NULL
               OR l_chr_packed_proc_status IN ('ERROR', 'NEW')
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   ' Pick confirm the entire delivery');
                l_chr_pick_conf_failure   := 'N';

                -- Pick confirm the entire delivery

                FOR mo_lines_rec
                    IN cur_mo_lines (pick_conf_deliveries_rec.order_number)
                LOOP
                    pick_line (
                        p_out_chr_errbuf      => l_chr_errbuf,
                        p_out_chr_retcode     => l_chr_retcode,
                        p_in_num_mo_line_id   => mo_lines_rec.mo_line_id,
                        p_in_txn_hdr_id       =>
                            mo_lines_rec.transaction_header_id);

                    IF l_chr_retcode <> '0'
                    THEN
                        l_chr_pick_conf_failure   := 'Y';
                        EXIT;
                    ELSE
                        COMMIT;
                    END IF;
                END LOOP;

                -- If API failed for any of the move order lines, update the delivery as failed
                IF l_chr_pick_conf_failure = 'Y'
                THEN
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     =>
                                pick_conf_deliveries_rec.order_number,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   =>
                                'Pick confirm failed : ' || l_chr_errbuf,
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'PICK_CONFIRM');
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Pick confirm failed for delivery : '
                            || pick_conf_deliveries_rec.order_number;
                        RETURN;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || l_chr_errbuf;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            RETURN;
                    END;
                ELSE
                    -- Pick confirmation is fully successful. Insert the packed message into order status table.
                    IF l_chr_packed_proc_status IS NULL
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
                                 VALUES (pick_conf_deliveries_rec.wh_id, pick_conf_deliveries_rec.order_number, SYSDATE, --p_in_dte_ship_date,  /* PACKED_MSG_DATE_BUG */
                                                                                                                         'PACKED', p_in_chr_shipment_no, 'NEW', -- bsk shipment status to be verified
                                                                                                                                                                'SHIP-AUTOINSERT', --bsk comments to be verified
                                                                                                                                                                                   NULL, g_num_user_id, SYSDATE, g_num_user_id, SYSDATE, g_num_login_id, 'PROCESSED', 'INSERT'
                                         ,                       --record type
                                           'WMS',                     --source
                                                  'EBS'         -- destination
                                                       );
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_out_chr_retcode   := '1';
                                p_out_chr_errbuf    :=
                                       'PACKED message is not inserted into order status table due to : '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   p_out_chr_errbuf);
                        END;
                    ELSE                 -- update the existing PACKED message
                        UPDATE xxdo.xxdo_ont_pick_status_order
                           SET process_status = 'PROCESSED', request_id = g_num_request_id, last_update_date = SYSDATE,
                               last_updated_by = g_num_user_id
                         WHERE     order_number =
                                   pick_conf_deliveries_rec.order_number
                               AND shipment_number = p_in_chr_shipment_no
                               AND wh_id = pick_conf_deliveries_rec.wh_id
                               AND status = 'PACKED';
                    END IF;    -- End of PACKED Message -update / insert check
                END IF;                       -- Pick confirm successful check
            END IF;                         -- End of l_chr_packed_proc_status
        END LOOP;

        /*  REMOVE_SHIPSET - Start */

        FOR ship_set_orders_rec IN cur_ship_set_orders
        LOOP
            UPDATE oe_order_lines_all
               SET ship_set_id   = NULL
             WHERE header_id = ship_set_orders_rec.header_id;

            UPDATE wsh_delivery_details
               SET ship_set_id   = NULL
             WHERE     source_header_id = ship_set_orders_rec.header_id
                   AND source_code = 'OE';
        END LOOP;

        COMMIT;


        /*  REMOVE_SHIPSET - End */
        /* ROLLBACK_ALL - End */

        fnd_file.put_line (
            fnd_file.LOG,
               'Establishing Save point : SP_'
            || g_num_request_id
            || '_BEFORE_DT');

        EXECUTE IMMEDIATE 'SAVEPOINT SP_' || g_num_request_id || '_BEFORE_DT';


        OPEN cur_shipment_data;

        BEGIN
            FETCH cur_shipment_data
                BULK COLLECT INTO l_shipconf_headers_obj_tab;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   := 'Error in BULK Fetch : ' || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in BULK Fetch : ' || p_out_chr_errbuf);
                RAISE l_exe_bulk_fetch_failed;
        END;

        CLOSE cur_shipment_data;

        /*
                    BEGIN
                     validate_shipping_data( p_out_chr_errbuf => l_chr_errbuf,
                                                        p_out_chr_retcode => l_chr_retcode,
                                                        p_in_chr_shipment_no =>p_in_chr_shipment_no,
                                                         );
                    EXCEPTION
                            WHEN OTHERS THEN
                                    p_out_chr_errbuf :=  SQLERRM;
                                    p_out_chr_retcode := '2';
                                    FND_FILE.PUT_LINE (FND_FILE.LOG, 'Unexpected error at validate shipping data procedure : ' || p_out_chr_errbuf);
                    END;
        */
        fnd_file.put_line (fnd_file.LOG, 'Validating the Shipment data...');
        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether the warehouse '
            || l_shipconf_headers_obj_tab (l_num_shipment_index).wh_id
            || ' is WMS enabled');

        BEGIN
            SELECT mp.organization_id
              INTO l_num_inventory_org_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code =
                       l_shipconf_headers_obj_tab (l_num_shipment_index).wh_id
                   AND mp.organization_code = flv.lookup_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_inventory_org_id   := -1;
        END;

        IF l_num_inventory_org_id = -1
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_delivery_no     => NULL,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'SHIPMENT',
                    p_in_chr_error_message   =>
                           l_shipconf_headers_obj_tab (l_num_shipment_index).wh_id
                        || ' - Warehouse is not WMS Enabled',
                    p_in_chr_status          => 'IGNORED',
                    p_in_chr_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (l_num_shipment_index).wh_id
                    || ' - Warehouse is not WMS Enabled');
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;

            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   l_shipconf_headers_obj_tab (l_num_shipment_index).wh_id
                || ' - Warehouse is not WMS Enabled';
            RETURN;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether the carrier '
            || l_shipconf_headers_obj_tab (l_num_shipment_index).carrier
            || '  is valid');

        BEGIN
            SELECT carrier_id
              INTO l_num_carrier_id
              FROM wsh_carriers_v
             WHERE freight_code =
                   l_shipconf_headers_obj_tab (l_num_shipment_index).carrier;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_carrier_id   := -1;
        END;

        IF l_num_carrier_id = -1
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_delivery_no     => NULL,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'SHIPMENT',
                    p_in_chr_error_message   =>
                           l_shipconf_headers_obj_tab (l_num_shipment_index).carrier
                        || ' - carrier is not valid',
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (l_num_shipment_index).carrier
                    || ' - carrier is not valid');
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;

            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   l_shipconf_headers_obj_tab (l_num_shipment_index).carrier
                || ' - carrier is not valid';
            RETURN;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
               'Validating whether deliveries are sent for the shipment : '
            || l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number);

        IF l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab.COUNT =
           0
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf       => l_chr_errbuf,
                    p_out_chr_retcode      => l_chr_retcode,
                    p_in_chr_shipment_no   =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_delivery_no   => NULL,
                    p_in_chr_carton_no     => NULL,
                    p_in_chr_error_level   => 'SHIPMENT',
                    p_in_chr_error_message   =>
                           'Delivery details are not sent from WMS for the shipment : '
                        || l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_status        => 'ERROR',
                    p_in_chr_source        => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Delivery details are not sent from WMS for the shipment : '
                    || l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;

            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'Delivery details are not sent from WMS for the shipment : '
                || l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number;
            RETURN;
        END IF;


        fnd_file.put_line (
            fnd_file.LOG,
            'Validating whether the ship date falls in open inventory accounting period');

        l_chr_period_open_flag   := 'N';

        BEGIN
            SELECT ocp.open_flag
              INTO l_chr_period_open_flag
              FROM org_acct_periods ocp
             WHERE     ocp.organization_id = l_num_inventory_org_id
                   AND l_shipconf_headers_obj_tab (l_num_shipment_index).ship_date BETWEEN ocp.period_start_date
                                                                                       AND ocp.schedule_close_date;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_chr_period_open_flag   := 'N';
        END;

        IF l_chr_period_open_flag = 'N'
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_delivery_no     => NULL,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'SHIPMENT',
                    p_in_chr_error_message   =>
                        'Inventory accounting period is not open',
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (fnd_file.LOG,
                                   'Inventory accounting period is not open');
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;

            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := 'Inventory accounting period is not open';
            RETURN;
        END IF;



        fnd_file.put_line (fnd_file.LOG,
                           'Validating whether the trip already exists');

        BEGIN
            SELECT COUNT (1)
              INTO l_num_existing_trip_id
              FROM wsh_trips
             WHERE name =
                   l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_existing_trip_id   := 0;
        END;

        IF l_num_existing_trip_id <> 0
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_delivery_no     => NULL,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'SHIPMENT',
                    p_in_chr_error_message   =>
                           l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number
                        || ' - Trip already exists',
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                       l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number
                    || ' - Trip already exists');
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;

            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number
                || ' - Trip already exists';
            RETURN;
        END IF;



        fnd_file.put_line (fnd_file.LOG, 'Creating the trip');

        -- Create a trip before invoking the delivery threads
        BEGIN
            create_trip (
                p_out_chr_errbuf             => l_chr_errbuf,
                p_out_chr_retcode            => l_chr_retcode,
                p_in_chr_trip                =>
                    l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                p_in_chr_carrier             =>
                    l_shipconf_headers_obj_tab (l_num_shipment_index).carrier,
                p_in_num_carrier_id          => l_num_carrier_id,
                p_in_chr_vehicle_number      => NULL,
                --bsk to be checked whether it is needed
                p_in_chr_mode_of_transport   => NULL,
                --bsk to be checked whether it is needed
                p_in_chr_master_bol_number   => NULL,
                --bsk to be checked whether it is needed
                p_out_num_trip_id            => l_num_trip_id);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    := SQLERRM;
                p_out_chr_retcode   := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexpected error while invoking create trip procedure : '
                    || p_out_chr_errbuf);
        END;

        IF l_chr_retcode <> '0'
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                    p_in_chr_delivery_no     => NULL,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'SHIPMENT',
                    p_in_chr_error_message   =>
                        'Trip creation failed - ' || l_chr_errbuf,
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'SHIPMENT_THREAD_BEFORE_DT');
                fnd_file.put_line (fnd_file.LOG,
                                   'Trip Creation failed - ' || l_chr_errbuf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END RETURN;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Trip Creation was succussful. Trip Id : ' || l_num_trip_id);
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Creating the SHIP FROM stop');

        -- Create SHIP FROM stop before invoking the delivery threads
        BEGIN
            SELECT location_id
              INTO l_num_ship_from_loc_id
              FROM hr_organization_units hou
             WHERE organization_id = l_num_inventory_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_num_ship_from_loc_id   := 0;
                p_out_chr_errbuf         := SQLERRM;
                p_out_chr_retcode        := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexpected error while getting ship from location : '
                    || p_out_chr_errbuf);
        END;

        IF l_num_ship_from_loc_id <> 0
        THEN
            BEGIN
                create_stop (
                    p_out_chr_errbuf            => l_chr_errbuf,
                    p_out_chr_retcode           => l_chr_retcode,
                    p_in_chr_ship_type          => 'SHIP_FROM',
                    p_in_num_trip_id            => l_num_trip_id,
                    p_in_num_stop_seq           => 10,
                    p_in_num_stop_location_id   => l_num_ship_from_loc_id,
                    p_in_chr_dep_seal_code      =>
                        l_shipconf_headers_obj_tab (l_num_shipment_index).seal_number,
                    -- bsk to be verified whether seal number is same as seal code
                    p_out_num_stop_id           => l_num_stop_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf    := SQLERRM;
                    p_out_chr_retcode   := '2';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while invoking create stop procedure : '
                        || p_out_chr_errbuf);
            END;

            IF l_chr_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        p_out_chr_errbuf       => l_chr_errbuf,
                        p_out_chr_retcode      => l_chr_retcode,
                        p_in_chr_shipment_no   =>
                            l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                        p_in_chr_delivery_no   => NULL,
                        p_in_chr_carton_no     => NULL,
                        p_in_chr_error_level   => 'SHIPMENT',
                        p_in_chr_error_message   =>
                               'Ship From Stop creation failed - '
                            || l_chr_errbuf,
                        p_in_chr_status        => 'ERROR',
                        p_in_chr_source        => 'SHIPMENT_THREAD_BEFORE_DT');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Ship From Stop Creation failed - ' || l_chr_errbuf);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RETURN;
                END RETURN;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Ship From Stop Creation was succussful. Trip Id : '
                    || l_num_stop_id);
                -- Storing the trip id at at the shipment header level
                l_shipconf_headers_obj_tab (l_num_shipment_index).attribute3   :=
                    l_num_stop_id;
            END IF;
        END IF;

        /* ROLLBACK_ALL - Start */
        /*
              IF l_delivery_request_ids_tab.EXISTS (1)
              THEN
                 l_delivery_request_ids_tab.DELETE;
              END IF;
        */

        /* ROLLBACK_ALL - End */
        -- Releasing the holds before launching the delivery threads
        fnd_file.put_line (
            fnd_file.LOG,
            'Releasing the holds before launching the delivery threads');

        /* ROLLBACK_ALL - Start */
        /*
              IF l_delivery_request_ids_tab.EXISTS (1)
              THEN
                 l_delivery_request_ids_tab.DELETE;
              END IF;
        */

        /* ROLLBACK_ALL - End */
        FOR l_num_index IN l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab.FIRST ..
                           l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab.LAST
        LOOP
            IF l_hold_source_tbl.EXISTS (1)
            THEN
                l_hold_source_tbl.DELETE;
            END IF;

            fnd_file.put_line (fnd_file.LOG, '1');

            FOR order_header_id_rec
                IN cur_order_header_id (
                       l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab (
                           l_num_index).order_number)
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Invoking the release hold procedure for the delivery : '
                    || l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab (
                           l_num_index).order_number);

                BEGIN
                    release_holds (
                        p_out_chr_errbuf       => l_chr_errbuf,
                        p_out_chr_retcode      => l_chr_retcode,
                        p_io_hold_source_tbl   => l_hold_source_tbl,
                        p_in_num_header_id     =>
                            order_header_id_rec.source_header_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error invoking the hold release procedure : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                END;

                -- If hold release is not successful, update the delivery record with error, dont launch the delivery thread
                IF l_chr_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf       => l_chr_errbuf,
                            p_out_chr_retcode      => l_chr_retcode,
                            p_in_chr_shipment_no   =>
                                l_shipconf_headers_obj_tab (
                                    l_num_shipment_index).shipment_number,
                            p_in_chr_delivery_no   =>
                                l_shipconf_headers_obj_tab (
                                    l_num_shipment_index).shipconf_orders_obj_tab (
                                    l_num_index).order_number,
                            p_in_chr_carton_no     => NULL,
                            p_in_chr_error_level   => 'DELIVERY',
                            p_in_chr_error_message   =>
                                'Hold release failed :  ' || l_chr_errbuf,
                            p_in_chr_status        => 'ERROR',
                            p_in_chr_source        =>
                                'SHIPMENT_THREAD_BEFORE_DT');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Hold release failed. Erroring the delivery : '
                            || l_shipconf_headers_obj_tab (
                                   l_num_shipment_index).shipconf_orders_obj_tab (
                                   l_num_index).order_number);
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                            'Hold release failed. Please refer the log file for more details';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || SQLERRM;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                    END;
                ELSE
                    -- hold release is successful - copy the hold sources into all hold sources table to reapply the hold later and launch the delivery thread
                    IF l_hold_source_tbl.EXISTS (1)
                    THEN
                        FOR l_num_hold_index IN 1 .. l_hold_source_tbl.COUNT
                        LOOP
                            l_all_hold_source_tbl (
                                l_all_hold_source_tbl.COUNT + 1)   :=
                                l_hold_source_tbl (l_num_hold_index);
                        END LOOP;
                    END IF;

                    /* ROLLBACK_ALL - Start */

                    fnd_file.put_line (fnd_file.LOG,
                                       'Invoking the Delivery procedure');

                    l_chr_retcode   := '0';
                    l_chr_errbuf    := NULL;

                    delivery_thread (
                        p_out_chr_errbuf         => l_chr_errbuf,
                        p_out_chr_retcode        => l_chr_retcode,
                        p_in_chr_shipment_no     =>
                            l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number,
                        p_in_chr_delivery_no     =>
                            l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab (
                                l_num_index).order_number,
                        p_in_num_trip_id         => l_num_trip_id,
                        p_in_chr_carrier         =>
                            l_shipconf_headers_obj_tab (l_num_shipment_index).carrier,
                        --p_in_dte_ship_date      IN DATE,
                        p_in_num_parent_req_id   => p_in_num_parent_req_id);


                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Control Back to the Shipment procedure');

                    IF l_chr_retcode <> '0'
                    THEN
                        p_out_chr_retcode   := l_chr_retcode;
                        p_out_chr_errbuf    := l_chr_errbuf;
                        RETURN;
                    END IF;
                -- If hold release is successful or there is no hold, launch the delivery thread
                /*     l_delivery_request_ids_tab (l_delivery_request_ids_tab.COUNT
                                                 + 1
                                                ) :=
                        fnd_request.submit_request
                           (application      => 'XXDO',
                            program          => 'XXDOSCDT',
                            argument1        => l_shipconf_headers_obj_tab
                                                               (l_num_shipment_index).shipment_number,
                            argument2        => l_shipconf_headers_obj_tab
                                                               (l_num_shipment_index).shipconf_orders_obj_tab
                                                                        (l_num_index).order_number,
                            argument3        => l_num_trip_id,
                            argument4        => l_shipconf_headers_obj_tab
                                                               (l_num_shipment_index).carrier,
      --                      argument5        => l_shipconf_headers_obj_tab
      --                                                         (l_num_shipment_index).ship_date,
                            argument5        => p_in_num_parent_req_id,
                            description      => NULL,
                            start_time       => NULL
                           );

                     IF l_delivery_request_ids_tab (l_delivery_request_ids_tab.COUNT) =
                                                                                   0
                     THEN
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Shipment Number : '
                            || l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number
                            || ' Delivery Number :  '
                            || l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab
                                                                        (l_num_index).order_number
                            || '  Shipment Processor - Concurrent Request is not launched'
                           );
                        p_out_chr_retcode := '1';
                        p_out_chr_errbuf :=
                           'One or more Shipment Processor Threads are not launched. Please refer the log file for more details';
                     ELSE
                        fnd_file.put_line
                           (fnd_file.LOG,
                               'Shipment number : '
                            || l_shipconf_headers_obj_tab (l_num_shipment_index).shipment_number
                            || ' Delivery Number :  '
                            || l_shipconf_headers_obj_tab (l_num_shipment_index).shipconf_orders_obj_tab
                                                                        (l_num_index).order_number
                            || ' Shipment Processor - Concurrent Request ID : '
                            || l_delivery_request_ids_tab
                                                   (l_delivery_request_ids_tab.COUNT)
                           );
                     END IF;
                                    */
                /* ROLLBACK_ALL - End */

                END IF;
            END LOOP;
        END LOOP;

        /* ROLLBACK_ALL - Start */

        /*
        COMMIT;
             l_chr_req_failure := 'N';
             fnd_file.put_line (fnd_file.LOG, '');
             fnd_file.put_line
                    (fnd_file.LOG,
                     '-------------Concurrent Requests Status Report ---------------'
                    );

             FOR l_num_index IN 1 .. l_delivery_request_ids_tab.COUNT
             LOOP
                l_bol_req_status :=
                   fnd_concurrent.wait_for_request
                                           (l_delivery_request_ids_tab (l_num_index),
                                            10,
                                            0,
                                            l_chr_phase,
                                            l_chr_status,
                                            l_chr_dev_phase,
                                            l_chr_dev_status,
                                            l_chr_message
                                           );
                fnd_file.put_line (fnd_file.LOG,
                                      'Concurrent request ID : '
                                   || l_delivery_request_ids_tab (l_num_index)
                                   || CHR (9)
                                   || ' Phase: '
                                   || l_chr_phase
                                   || CHR (9)
                                   || ' Status: '
                                   || l_chr_status
                                   || CHR (9)
                                   || ' Dev Phase: '
                                   || l_chr_dev_phase
                                   || CHR (9)
                                   || ' Dev Status: '
                                   || l_chr_dev_status
                                   || CHR (9)
                                   || ' Message: '
                                   || l_chr_message
                                  );

                IF NOT (    UPPER (l_chr_phase) = 'COMPLETED'
                        AND UPPER (l_chr_status) = 'NORMAL'
                       )
                THEN
                   l_chr_req_failure := 'Y';
                END IF;
             END LOOP;

             fnd_file.put_line (fnd_file.LOG, '');

             IF l_chr_req_failure = 'Y'
             THEN
                p_out_chr_retcode := '1';
                p_out_chr_errbuf :=
                   'One or more Shipment Processor - Delivery Threads ended in Warning or Error. Please refer the log file for more details';
             END IF;

                   fnd_file.put_line
                    (fnd_file.LOG,
                     'Establishing Save point : SP_'|| g_num_request_id ||'_AFTER_DT'
                    );

             EXECUTE IMMEDIATE 'SAVEPOINT SP_'||  g_num_request_id||'_AFTER_DT';
       */

        /* ROLLBACK_ALL - End */
        fnd_file.put_line (fnd_file.LOG, 'Creating Ship to Stop');

        -- Logic to create  ship to stops
        FOR ship_to_stops_rec IN cur_ship_to_stops
        LOOP
            IF ship_to_stops_rec.ship_to_location_id IS NOT NULL
            THEN
                BEGIN
                    create_stop (
                        p_out_chr_errbuf            => l_chr_errbuf,
                        p_out_chr_retcode           => l_chr_retcode,
                        p_in_chr_ship_type          => 'SHIP_TO',
                        p_in_num_trip_id            => l_num_trip_id,
                        p_in_num_stop_seq           => NULL,
                        -- create stop will derive the next sequence no
                        p_in_num_stop_location_id   =>
                            ship_to_stops_rec.ship_to_location_id,
                        p_in_chr_dep_seal_code      => NULL,
                        --l_shipconf_headers_obj_tab (l_num_shipment_index).seal_number, -- bsk to be verified whether seal number is same as seal code
                        p_out_num_stop_id           => l_num_stop_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_errbuf    := SQLERRM;
                        p_out_chr_retcode   := '2';
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Unexpected error while invoking create stop procedure for ship to location : '
                            || p_out_chr_errbuf);
                        RETURN;
                END;

                IF l_chr_retcode <> '0'
                THEN
                    -- Update all the deliveries of the current ship to location
                    FOR same_stop_del_nums_rec
                        IN cur_same_stop_del_nums (
                               ship_to_stops_rec.ship_to_location_id)
                    LOOP
                        BEGIN
                            update_error_records (
                                p_out_chr_errbuf       => l_chr_errbuf,
                                p_out_chr_retcode      => l_chr_retcode,
                                p_in_chr_shipment_no   => p_in_chr_shipment_no,
                                p_in_chr_delivery_no   =>
                                    same_stop_del_nums_rec.order_number,
                                p_in_chr_carton_no     => NULL,
                                p_in_chr_error_level   => 'DELIVERY',
                                p_in_chr_error_message   =>
                                       'Ship To Stop creation failed - '
                                    || l_chr_errbuf,
                                p_in_chr_status        => 'ERROR',
                                p_in_chr_source        =>
                                    'SHIPMENT_THREAD_AFTER_DT');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Ship To Stop Creation failed - '
                                || l_chr_errbuf);
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    := l_chr_errbuf;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_out_chr_retcode   := '2';
                                p_out_chr_errbuf    :=
                                       'Unexpected Error while updating error status :'
                                    || l_chr_errbuf;
                                fnd_file.put_line (fnd_file.LOG,
                                                   p_out_chr_errbuf);
                                RETURN;
                        END;
                    END LOOP;

                    RETURN;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Ship To Stop Creation was succussful for ship to location: '
                        || ship_to_stops_rec.ship_to_location_id
                        || ' Ship to Id : '
                        || l_num_stop_id);
                END IF;
            ELSE                                -- Ship to location id is null
                -- Update all the deliveries of the current ship to location
                FOR same_stop_del_nums_rec
                    IN cur_same_stop_del_nums (
                           ship_to_stops_rec.ship_to_location_id)
                LOOP
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf       => l_chr_errbuf,
                            p_out_chr_retcode      => l_chr_retcode,
                            p_in_chr_shipment_no   => p_in_chr_shipment_no,
                            p_in_chr_delivery_no   =>
                                same_stop_del_nums_rec.order_number,
                            p_in_chr_carton_no     => NULL,
                            p_in_chr_error_level   => 'DELIVERY',
                            p_in_chr_error_message   =>
                                'Ship To Stop creation failed Since Ship to location is blank',
                            p_in_chr_status        => 'ERROR',
                            p_in_chr_source        =>
                                'SHIPMENT_THREAD_AFTER_DT');
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Ship To Stop creation failed Since Ship to location is blank');
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                            'Ship To Stop creation failed Since Ship to location is blank';
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || l_chr_errbuf;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            RETURN;
                    END;
                END LOOP;

                RETURN;
            END IF;
        END LOOP;

        -- Populate the deliveries into the table
        l_num_del_index          := 1;

        FOR delivery_ids_rec IN cur_delivery_ids
        LOOP
            l_shipconfirm_del_ids_tab (l_num_del_index)   :=
                delivery_ids_rec.delivery_id;
            l_num_del_index   := l_num_del_index + 1;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Assigning delivery to the trip');


        -- Logic to assign the delivery to new trip
        FOR l_num_del_index IN 1 .. l_shipconfirm_del_ids_tab.COUNT
        LOOP
            BEGIN
                assign_del_to_trip (
                    p_out_chr_errbuf    => l_chr_errbuf,
                    p_out_chr_retcode   => l_chr_retcode,
                    p_in_num_trip_id    => l_num_trip_id,
                    p_in_num_delivery_id   =>
                        l_shipconfirm_del_ids_tab (l_num_del_index));
            --CASE WHEN  l_chr_new_delivery_reqd =  'N' THEN l_delivery_dtl_tab(1).delivery_id ELSE l_num_new_delivery_id END );
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf    := SQLERRM;
                    p_out_chr_retcode   := '2';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while invoking assign delivery to stop procedure : '
                        || p_out_chr_errbuf);
            END;

            IF l_chr_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        p_out_chr_errbuf       => l_chr_errbuf,
                        p_out_chr_retcode      => l_chr_retcode,
                        p_in_chr_shipment_no   => p_in_chr_shipment_no,
                        p_in_chr_delivery_no   => NULL,
                        p_in_chr_carton_no     => NULL,
                        p_in_chr_error_level   => 'SHIPMENT',
                        p_in_chr_error_message   =>
                               'Assigning Delivery to Trip failed - '
                            || l_chr_errbuf,
                        p_in_chr_status        => 'ERROR',
                        p_in_chr_source        => 'SHIPMENT_THREAD_AFTER_DT');
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Assigning Delivery to Trip failed - '
                        || l_chr_errbuf);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || l_chr_errbuf;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RETURN;
                END;

                RETURN;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Assigning Delivery to Trip is successful. Delivery Id: '
                    || l_shipconfirm_del_ids_tab (l_num_del_index));
            END IF;
        END LOOP;

        -- Ship confirm the delivery
        fnd_file.put_line (fnd_file.LOG, 'Ship confirm the deliveries');

        BEGIN
            ship_confirm_deliveries (
                p_out_chr_errbuf             => l_chr_errbuf,
                p_out_chr_retcode            => l_chr_retcode,
                p_in_dt_actual_dep_date      =>
                    l_shipconf_headers_obj_tab (l_num_shipment_index).ship_date,
                --bsk to be verified whether this is ship date
                p_in_tabtype_id_deliveries   => l_shipconfirm_del_ids_tab);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    := SQLERRM;
                p_out_chr_retcode   := '2';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unexpected error while invoking ship confirm deliveries procedure : '
                    || p_out_chr_errbuf);
        END;

        IF l_chr_retcode <> '0'
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     => p_in_chr_shipment_no,
                    p_in_chr_delivery_no     => NULL,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'SHIPMENT',
                    p_in_chr_error_message   =>
                        'Ship Confirm Deliveries Failed:  ' || l_chr_errbuf,
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'SHIPMENT_THREAD_AFTER_DT');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Ship Confirm Deliveries Failed:  ' || l_chr_errbuf);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;

            RETURN;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'Ship confirm deliveries is successful');
        END IF;

        IF l_all_hold_source_tbl.EXISTS (1)
        THEN
            BEGIN
                reapply_holds (
                    p_out_chr_errbuf       => l_chr_errbuf,
                    p_out_chr_retcode      => l_chr_retcode,
                    p_in_hold_source_tbl   => l_all_hold_source_tbl);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf    := SQLERRM;
                    p_out_chr_retcode   := '1';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while invoking reapply holds procedure : '
                        || p_out_chr_errbuf);
            END;

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf    :=
                    'Hold application has failed. Please refer the log file fore more details';
                p_out_chr_retcode   := '1';
            END IF;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Updating the processed records');

        --- Update the processed records
        BEGIN
            update_error_records (
                p_out_chr_errbuf         => l_chr_errbuf,
                p_out_chr_retcode        => l_chr_retcode,
                p_in_chr_shipment_no     => p_in_chr_shipment_no,
                p_in_chr_delivery_no     => NULL,
                p_in_chr_carton_no       => NULL,
                p_in_chr_error_level     => 'SHIPMENT',
                p_in_chr_error_message   => NULL,
                p_in_chr_status          => 'PROCESSED',
                p_in_chr_source          => 'SHIPMENT_THREAD_AFTER_DT');
        --         RETURN;      /* EDI Changes */
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'Unexpected Error while updating processed status :'
                    || l_chr_errbuf;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RETURN;
        END;

        /*  Logic for interfacing to EDI tables - EDI_INTERFACE Start*/
        -- commit all the changes since there is a rollback logic involved in EDI interfacing
        COMMIT;

        BEGIN
            interface_edi_asns (
                p_out_chr_errbuf       => l_chr_errbuf,
                p_out_chr_retcode      => l_chr_retcode,
                p_in_chr_shipment_no   => p_in_chr_shipment_no);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Unexpected Error while interfacing EDI ASNs :'
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RETURN;
        END;

        IF l_chr_retcode <> '0'
        THEN
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    :=
                'Error while interfacing EDI ASNs :' || l_chr_errbuf;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END IF;
    /*  EDI_INTERFACE End*/


    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at Shipment thread procedure : '
                || p_out_chr_errbuf);
            update_error_records (
                p_out_chr_errbuf         => l_chr_errbuf,
                p_out_chr_retcode        => l_chr_retcode,
                p_in_chr_shipment_no     => p_in_chr_shipment_no,
                p_in_chr_delivery_no     => NULL,
                p_in_chr_carton_no       => NULL,
                p_in_chr_error_level     => 'SHIPMENT',
                p_in_chr_error_message   =>
                       'Unexpected error at Shipment thread procedure : '
                    || p_out_chr_errbuf,
                p_in_chr_status          => 'ERROR',
                p_in_chr_source          => 'SHIPMENT_THREAD_AFTER_DT');
    END shipment_thread;

    -- ***************************************************************************
    -- Procedure Name      :  delivery_thread
    --
    -- Description         :  This procedure is to process the delivery - create delivery, assign/unassign delivery details, split delivery detail
    --                              create cartons and update freight charges
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                          p_in_chr_shipment_no     IN  : Shipment Number
    --                          p_in_chr_delivery_no     IN  : Delivery Number
    --                          p_in_num_trip_id         IN  : Trip id
    --                          p_in_chr_carrier         IN  : Carrier
    --                          p_in_num_parent_req_id   IN  : Parent - Main Thread - Request Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************


    PROCEDURE delivery_thread (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2, p_in_chr_delivery_no IN VARCHAR2, p_in_num_trip_id IN NUMBER, p_in_chr_carrier IN VARCHAR2
                               , --p_in_dte_ship_date       IN       DATE,
                                 p_in_num_parent_req_id IN NUMBER)
    IS
        l_chr_errbuf                    VARCHAR2 (2000) := NULL;
        l_chr_retcode                   VARCHAR2 (30) := '0';
        l_num_index                     NUMBER := 0;
        l_num_unship_del_dtl_id_ind     NUMBER := 0;
        l_num_ship_del_dtl_id_ind       NUMBER := 0;
        l_chr_delivery_found            VARCHAR2 (1) := 'N';
        l_chr_new_delivery_reqd         VARCHAR2 (1) := 'N';
        l_num_new_delivery_id           NUMBER;
        l_num_api_delivery_id           NUMBER := 0;
        l_num_new_del_detail_id         NUMBER := 0;
        l_num_container_id              NUMBER;
        l_num_ship_to_stop_exists       NUMBER := 0;
        l_num_stop_id                   NUMBER := 0;
        l_num_split_delivery_id         NUMBER := 0;
        l_chr_packed_proc_status        VARCHAR2 (30);
        l_chr_pick_conf_failure         VARCHAR2 (1);
        l_num_carton_exists             NUMBER := 0;
        p_in_dte_ship_date              DATE;
        l_num_initial_ebs_lines_count   NUMBER;
        l_num_ship_del_dtl_id_ind_mc    NUMBER;
        l_num_ship_qty                  NUMBER := 0;
        l_num_split_qty                 NUMBER := 0;
        l_num_req_qty                   NUMBER := 0;
        l_num_remaining_qty             NUMBER := 0;
        l_chr_split_required            VARCHAR2 (1) := 'Y';
        l_num_split_from_del_id         NUMBER;
        l_num_inv_item_id_qr            NUMBER := 0;
        l_num_org_id_qr                 NUMBER := 0;
        l_chr_serial_control_flag       VARCHAR2 (1);
        l_num_serials_count             NUMBER := 0;

        l_num_pick_ticket_line          NUMBER := 0;          /* SPLIT_LINE */

        l_unshipped_del_dtl_ids_tab     tabtype_id;
        l_shipped_del_dtl_ids_tab       tabtype_id;
        l_split_del_dtl_ids_tab         tabtype_id;
        l_delivery_dtl_tab              g_delivery_dtl_tab_type;
        l_shipments_tab                 g_shipments_tab_type;
        l_cur_shipments_tab             g_shipments_tab_type;
        l_cartons_obj_tab               cartons_obj_tab_type;

        l_exe_bulk_fetch_failed         EXCEPTION;

        CURSOR cur_shipment_data IS
            SELECT cartons_obj_type (
                       wh_id,
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
                       freight_charged,                  /* FREIGHT_CHARGED */
                       CAST (
                           MULTISET (
                               SELECT wh_id,
                                      shipment_number,
                                      order_number,
                                      carton_number,
                                      line_number,
                                      item_number,
                                      qty,
                                      uom,
                                      host_subinventory,
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
                                                     carton_number, line_number, serial_number,
                                                     item_number, process_status, error_message,
                                                     request_id, creation_date, created_by,
                                                     last_update_date, last_updated_by, source_type,
                                                     attribute1, attribute2, attribute3,
                                                     attribute4, attribute5, attribute6,
                                                     attribute7, attribute8, attribute9,
                                                     attribute10, attribute11, attribute12,
                                                     attribute13, attribute14, attribute15,
                                                     attribute16, attribute17, attribute18,
                                                     attribute19, attribute20, SOURCE,
                                                     destination, record_type
                                                FROM xxdo_ont_ship_conf_carser_stg serials
                                               WHERE     carton_dtl.shipment_number =
                                                         serials.shipment_number
                                                     AND carton_dtl.order_number =
                                                         serials.order_number
                                                     AND carton_dtl.carton_number =
                                                         serials.carton_number
                                                     AND carton_dtl.line_number =
                                                         serials.line_number
                                                     AND carton_dtl.item_number =
                                                         serials.item_number
                                                     /* SHIP_QTY_BUG Start*/
                                                     AND serials.process_status =
                                                         'INPROCESS'
                                                     AND serials.request_id =
                                                         p_in_num_parent_req_id /* SHIP_QTY_BUG End*/
                                                                               )
                                              AS carton_sers_obj_tab_type)
                                 FROM xxdo_ont_ship_conf_cardtl_stg carton_dtl
                                WHERE     carton.shipment_number =
                                          carton_dtl.shipment_number
                                      AND carton.order_number =
                                          carton_dtl.order_number
                                      AND carton.carton_number =
                                          carton_dtl.carton_number
                                      /* SHIP_QTY_BUG Start*/
                                      AND carton_dtl.process_status =
                                          'INPROCESS'
                                      AND carton_dtl.request_id =
                                          p_in_num_parent_req_id /* SHIP_QTY_BUG End*/
                                                                )
                               AS carton_dtls_obj_tab_type))
              FROM xxdo_ont_ship_conf_carton_stg carton
             WHERE     carton.shipment_number = p_in_chr_shipment_no
                   AND carton.order_number = p_in_chr_delivery_no
                   AND process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id;

        CURSOR cur_delivery_dtls_1 (p_in_chr_delivery_number IN VARCHAR2)
        IS
            SELECT wnd.NAME, wnd.delivery_id, ooh.header_id,
                   ooh.order_number, ool.line_id, ool.line_id line_number, /* VVAP - line ID need to be considered as line number for wms comparison*/
                   ool.ordered_item, ool.inventory_item_id, ool.order_quantity_uom,
                   ool.ship_from_org_id, hou.location_id ship_from_loc_id, ool.invoice_to_org_id,
                   ool.ship_to_org_id, hl.location_id ship_to_loc_id, wdd.requested_quantity,
                   wdd.released_status, mtrl.line_id mo_line_id, mtrl.transaction_header_id,
                   0 shipped_quantity, wdd.delivery_detail_id, wdd.organization_id,
                   wdd.customer_id, wdd.ship_method_code, NULL carton,
                   -1 orig_delivery_detail_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool, wsh_delivery_details wdd,
                   wsh_new_deliveries wnd, wsh_delivery_assignments wda, mtl_txn_request_lines mtrl,
                   hr_organization_units hou, hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa,
                   hz_party_sites hps, hz_locations hl
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_id = wdd.source_line_id
                   AND wdd.released_status IN ('S', 'Y')
                   -- S - released if no PACKED message, Y - staged/pick confirmed if PACKED message was processed
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND ool.line_id = mtrl.txn_source_line_id
                   AND wdd.move_order_line_id = mtrl.line_id
                   AND wnd.NAME = p_in_chr_delivery_number
                   AND hou.organization_id = ool.ship_from_org_id
                   AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                   AND hcasa.party_site_id = hps.party_site_id
                   AND hps.location_id = hl.location_id
                   AND hcsua.site_use_id = ool.ship_to_org_id;

        CURSOR cur_delivery_dtls_2 (p_in_chr_delivery_number IN VARCHAR2)
        IS
            SELECT '' NAME, -1 delivery_id, ooh.header_id,
                   ooh.order_number, ool.line_id, ool.line_id line_number, /* VVAP - line ID need to be considered as line number for wms comparison*/
                   ool.ordered_item, ool.inventory_item_id, ool.order_quantity_uom,
                   ool.ship_from_org_id, hou.location_id ship_from_loc_id, ool.invoice_to_org_id,
                   ool.ship_to_org_id, hl.location_id ship_to_loc_id, wdd.requested_quantity,
                   wdd.released_status, --                  mtrl.line_id mo_line_id,
                                        --                  mtrl.transaction_header_id,
                                        -1 mo_line_id, -1 transaction_header_id,
                   0 shipped_quantity, wdd.delivery_detail_id, wdd.organization_id,
                   wdd.customer_id, wdd.ship_method_code, NULL carton,
                   -1 orig_delivery_detail_id
              FROM oe_order_headers_all ooh, oe_order_lines_all ool, wsh_delivery_details wdd,
                   --        wsh_new_deliveries   wnd,
                   --        wsh_delivery_assignments  wda,
                   --        mtl_txn_request_lines mtrl,  -- Information about move order is not required since the delivery is already pick confirmed
                   hr_organization_units hou, hz_cust_site_uses_all hcsua, hz_cust_acct_sites_all hcasa,
                   hz_party_sites hps, hz_locations hl
             WHERE     ooh.header_id = ool.header_id
                   AND ool.line_id = wdd.source_line_id
                   AND wdd.released_status IN ('Y')
                   -- Y -  staged/pick confirmed since PACKED message was already processed
                   --       and  wnd.delivery_id        =  wda.delivery_id
                   --       AND  wda.delivery_detail_id = wdd.delivery_detail_id
                   --       AND ool.line_id = mtrl.txn_source_line_id
                   --       AND wdd.move_order_line_id = mtrl.line_id
                   AND wdd.attribute11 = p_in_chr_delivery_number
                   AND hou.organization_id = ool.ship_from_org_id
                   AND hcsua.cust_acct_site_id = hcasa.cust_acct_site_id
                   AND hcasa.party_site_id = hps.party_site_id
                   AND hps.location_id = hl.location_id
                   AND hcsua.site_use_id = ool.ship_to_org_id;

        CURSOR cur_order_holds (p_in_num_header_id IN NUMBER)
        IS
            SELECT header_id, hold_id
              FROM oe_order_holds_all ooha, oe_hold_sources_all ohsa
             WHERE     ooha.released_flag = 'N'
                   AND ooha.hold_source_id = ohsa.hold_source_id
                   AND ooha.header_id = p_in_num_header_id;


        CURSOR cur_unassign_dels (p_num_api_delivery_id IN NUMBER)
        IS
            SELECT wdd.delivery_detail_id
              FROM wsh_delivery_details wdd, wsh_new_deliveries wnd, wsh_delivery_assignments wda
             WHERE     wdd.released_status = 'Y'
                   AND wnd.delivery_id = wda.delivery_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.delivery_id = p_num_api_delivery_id
                   AND wdd.shipped_quantity = 0;

        i                               NUMBER;
        l_num_temp_line_id              NUMBER;
    BEGIN
        p_out_chr_errbuf                := NULL;
        p_out_chr_retcode               := '0';

        g_num_parent_req_id             := p_in_num_parent_req_id;

        fnd_file.put_line (
            fnd_file.LOG,
               'Processing started for Shipment Number : '
            || p_in_chr_shipment_no
            || ' Delivery Number: '
            || p_in_chr_delivery_no);

        /* ROLLBACK_ALL - Start*/
        /*
        fnd_file.put_line
               (fnd_file.LOG,
                'Establishing Save point : SP_'|| g_num_request_id
               );

        EXECUTE IMMEDIATE 'SAVEPOINT SP_'||  g_num_request_id;
      */

        /* ROLLBACK_ALL - End */
        OPEN cur_shipment_data;

        BEGIN
            FETCH cur_shipment_data BULK COLLECT INTO l_cartons_obj_tab;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';                 /* ROLLBACK_ALL */
                p_out_chr_errbuf    := 'Error in BULK Fetch : ' || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error in BULK Fetch : ' || p_out_chr_errbuf);
                RAISE l_exe_bulk_fetch_failed;
        END;

        CLOSE cur_shipment_data;

        fnd_file.put_line (
            fnd_file.LOG,
            'Validating whether the cartons are sent for the delivery');

        -- Validate whether cartons are sent from WBS
        IF l_cartons_obj_tab.COUNT = 0
        THEN
            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     => p_in_chr_shipment_no,
                    p_in_chr_delivery_no     => p_in_chr_delivery_no,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'DELIVERY',
                    p_in_chr_error_message   => 'No Cartons are sent from WMS',
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'DELIVERY_THREAD');
                fnd_file.put_line (fnd_file.LOG,
                                   'No Cartons are sent from WMS');
                /* ROLLBACK_ALL  - Start */
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    := 'No Cartons are sent from WMS';
                /* ROLLBACK_ALL  - End */
                RETURN;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Carton details are sent');


            l_num_carton_exists   := 0;

            FOR l_num_carton_check_ind IN l_cartons_obj_tab.FIRST ..
                                          l_cartons_obj_tab.LAST
            LOOP
                BEGIN
                    SELECT COUNT (1)
                      INTO l_num_carton_exists
                      FROM wms_license_plate_numbers
                     WHERE license_plate_number =
                           l_cartons_obj_tab (l_num_carton_check_ind).carton_number;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_num_carton_exists   := 0;
                END;

                IF l_num_carton_exists <> 0
                THEN
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   =>
                                   'Carton Number : '
                                || l_cartons_obj_tab (l_num_carton_check_ind).carton_number
                                || ' already exists in EBS',
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Carton Number : '
                            || l_cartons_obj_tab (l_num_carton_check_ind).carton_number
                            || ' already exists in EBS');
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Carton Number : '
                            || l_cartons_obj_tab (l_num_carton_check_ind).carton_number
                            || ' already exists in EBS';
                        RETURN;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || l_chr_errbuf;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            RETURN;
                    END;
                END IF;

                -- QR Check Start--
                FOR l_num_line_index IN 1 ..
                                        l_cartons_obj_tab (
                                            l_num_carton_check_ind).carton_dtls_obj_tab.COUNT
                LOOP
                    l_num_inv_item_id_qr   := 0;
                    l_num_org_id_qr        := 0;

                    BEGIN
                        SELECT msi.inventory_item_id, msi.organization_id
                          INTO l_num_inv_item_id_qr, l_num_org_id_qr
                          FROM mtl_system_items_kfv msi, mtl_parameters mp
                         WHERE     mp.organization_code =
                                   l_cartons_obj_tab (l_num_carton_check_ind).carton_dtls_obj_tab (
                                       l_num_line_index).wh_id
                               AND mp.organization_id = msi.organization_id
                               AND msi.concatenated_segments =
                                   l_cartons_obj_tab (l_num_carton_check_ind).carton_dtls_obj_tab (
                                       l_num_line_index).item_number;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_num_inv_item_id_qr   := 0;
                            l_num_org_id_qr        := 0;
                    END;

                    IF l_num_inv_item_id_qr = 0 OR l_num_org_id_qr = 0
                    THEN
                        BEGIN
                            update_error_records (
                                p_out_chr_errbuf         => l_chr_errbuf,
                                p_out_chr_retcode        => l_chr_retcode,
                                p_in_chr_shipment_no     => p_in_chr_shipment_no,
                                p_in_chr_delivery_no     => p_in_chr_delivery_no,
                                p_in_chr_carton_no       => NULL,
                                p_in_chr_error_level     => 'DELIVERY',
                                p_in_chr_error_message   =>
                                       'Item : '
                                    || l_cartons_obj_tab (
                                           l_num_carton_check_ind).carton_dtls_obj_tab (
                                           l_num_line_index).item_number
                                    || ' is not valid',
                                p_in_chr_status          => 'ERROR',
                                p_in_chr_source          => 'DELIVERY_THREAD');
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Item : '
                                || l_cartons_obj_tab (l_num_carton_check_ind).carton_dtls_obj_tab (
                                       l_num_line_index).item_number
                                || ' is not valid');

                            /* ROLLBACK_ALL  - Start */
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Item : '
                                || l_cartons_obj_tab (l_num_carton_check_ind).carton_dtls_obj_tab (
                                       l_num_line_index).item_number
                                || ' is not valid';
                            /* ROLLBACK_ALL  - End */

                            RETURN;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_out_chr_retcode   := '2';
                                p_out_chr_errbuf    :=
                                       'Unexpected Error while updating error status :'
                                    || l_chr_errbuf;
                                fnd_file.put_line (fnd_file.LOG,
                                                   p_out_chr_errbuf);
                                RETURN;
                        END;
                    ELSE                                  -- IF item is  valid
                        l_chr_serial_control_flag   := 'N';

                        BEGIN
                            l_chr_serial_control_flag   :=
                                xxdo_iid_to_serial (l_num_inv_item_id_qr,
                                                    l_num_org_id_qr);
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_chr_serial_control_flag   := 'N';
                        END;


                        IF NVL (l_chr_serial_control_flag, 'N') = 'Y'
                        THEN                   -- If item is serial controlled
                            l_num_serials_count   := 0;

                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_num_serials_count
                                  FROM xxdo_ont_ship_conf_carser_stg xos
                                 WHERE     request_id =
                                           p_in_num_parent_req_id
                                       AND process_status = 'INPROCESS'
                                       AND shipment_number =
                                           p_in_chr_shipment_no
                                       AND order_number =
                                           p_in_chr_delivery_no
                                       AND carton_number =
                                           l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).carton_number
                                       AND line_number =
                                           l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).line_number
                                       AND item_number =
                                           l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_serials_count   := 0;
                            END;


                            IF l_num_serials_count = 0
                            THEN
                                BEGIN
                                    update_error_records (
                                        p_out_chr_errbuf       => l_chr_errbuf,
                                        p_out_chr_retcode      => l_chr_retcode,
                                        p_in_chr_shipment_no   =>
                                            p_in_chr_shipment_no,
                                        p_in_chr_delivery_no   =>
                                            p_in_chr_delivery_no,
                                        p_in_chr_carton_no     => NULL,
                                        p_in_chr_error_level   => 'DELIVERY',
                                        p_in_chr_error_message   =>
                                               'Item : '
                                            || l_cartons_obj_tab (
                                                   l_num_carton_check_ind).carton_dtls_obj_tab (
                                                   l_num_line_index).item_number
                                            || ' is serialized, but serial details are not sent',
                                        p_in_chr_status        => 'ERROR',
                                        p_in_chr_source        =>
                                            'DELIVERY_THREAD');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Item : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number
                                        || ' is serialized, but serial details are not sent');

                                    /* ROLLBACK_ALL  - Start */
                                    p_out_chr_retcode   := '2';
                                    p_out_chr_errbuf    :=
                                           'Item : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number
                                        || ' is serialized, but serial details are not sent';
                                    /* ROLLBACK_ALL  - End */
                                    RETURN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_out_chr_retcode   := '2';
                                        p_out_chr_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || l_chr_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_out_chr_errbuf);
                                        RETURN;
                                END;
                            ELSIF l_num_serials_count <>
                                  l_cartons_obj_tab (l_num_carton_check_ind).carton_dtls_obj_tab (
                                      l_num_line_index).qty
                            THEN
                                BEGIN
                                    update_error_records (
                                        p_out_chr_errbuf       => l_chr_errbuf,
                                        p_out_chr_retcode      => l_chr_retcode,
                                        p_in_chr_shipment_no   =>
                                            p_in_chr_shipment_no,
                                        p_in_chr_delivery_no   =>
                                            p_in_chr_delivery_no,
                                        p_in_chr_carton_no     => NULL,
                                        p_in_chr_error_level   => 'DELIVERY',
                                        p_in_chr_error_message   =>
                                               'Item : '
                                            || l_cartons_obj_tab (
                                                   l_num_carton_check_ind).carton_dtls_obj_tab (
                                                   l_num_line_index).item_number
                                            || ' is serialized.'
                                            || ' Qty and Serias Count mismatch. Qty : '
                                            || l_cartons_obj_tab (
                                                   l_num_carton_check_ind).carton_dtls_obj_tab (
                                                   l_num_line_index).qty
                                            || ' Serials Count : '
                                            || l_num_serials_count,
                                        p_in_chr_status        => 'ERROR',
                                        p_in_chr_source        =>
                                            'DELIVERY_THREAD');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Item : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number
                                        || ' is serialized.'
                                        || ' Qty and Serias Count mismatch. Qty : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).qty
                                        || ' Serials Count : '
                                        || l_num_serials_count);

                                    /* ROLLBACK_ALL  - Start */
                                    p_out_chr_retcode   := '2';
                                    p_out_chr_errbuf    :=
                                           'Item : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number
                                        || ' is serialized.'
                                        || ' Qty and Serias Count mismatch. Qty : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).qty
                                        || ' Serials Count : '
                                        || l_num_serials_count;
                                    /* ROLLBACK_ALL  - End */
                                    RETURN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_out_chr_retcode   := '2';
                                        p_out_chr_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || l_chr_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_out_chr_errbuf);
                                        RETURN;
                                END;
                            END IF;
                        ELSE                  -- Item is not serial controlled
                            BEGIN
                                SELECT COUNT (1)
                                  INTO l_num_serials_count
                                  FROM xxdo_ont_ship_conf_carser_stg xos
                                 WHERE     request_id =
                                           p_in_num_parent_req_id
                                       AND process_status = 'INPROCESS'
                                       AND shipment_number =
                                           p_in_chr_shipment_no
                                       AND order_number =
                                           p_in_chr_delivery_no
                                       AND carton_number =
                                           l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).carton_number
                                       AND line_number =
                                           l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).line_number
                                       AND item_number =
                                           l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_num_serials_count   := 0;
                            END;


                            IF l_num_serials_count <> 0
                            THEN
                                BEGIN
                                    update_error_records (
                                        p_out_chr_errbuf       => l_chr_errbuf,
                                        p_out_chr_retcode      => l_chr_retcode,
                                        p_in_chr_shipment_no   =>
                                            p_in_chr_shipment_no,
                                        p_in_chr_delivery_no   =>
                                            p_in_chr_delivery_no,
                                        p_in_chr_carton_no     => NULL,
                                        p_in_chr_error_level   => 'DELIVERY',
                                        p_in_chr_error_message   =>
                                               'Item : '
                                            || l_cartons_obj_tab (
                                                   l_num_carton_check_ind).carton_dtls_obj_tab (
                                                   l_num_line_index).item_number
                                            || ' is not serialized, but serial details were sent',
                                        p_in_chr_status        => 'ERROR',
                                        p_in_chr_source        =>
                                            'DELIVERY_THREAD');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'Item : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number
                                        || ' is not serialized, but serial details were sent');

                                    /* ROLLBACK_ALL  - Start */
                                    p_out_chr_retcode   := '2';
                                    p_out_chr_errbuf    :=
                                           'Item : '
                                        || 'Item : '
                                        || l_cartons_obj_tab (
                                               l_num_carton_check_ind).carton_dtls_obj_tab (
                                               l_num_line_index).item_number
                                        || ' is not serialized, but serial details were sent';
                                    /* ROLLBACK_ALL  - End */
                                    RETURN;
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        p_out_chr_retcode   := '2';
                                        p_out_chr_errbuf    :=
                                               'Unexpected Error while updating error status :'
                                            || l_chr_errbuf;
                                        fnd_file.put_line (fnd_file.LOG,
                                                           p_out_chr_errbuf);
                                        RETURN;
                                END;
                            END IF;
                        END IF;
                    END IF;
                END LOOP;
            -- QR Check End --



            END LOOP;



            BEGIN
                SELECT ship_date
                  INTO p_in_dte_ship_date
                  FROM xxdo_ont_ship_conf_head_stg xos
                 WHERE     xos.shipment_number = p_in_chr_shipment_no
                       AND process_status = 'INPROCESS'
                       AND request_id = p_in_num_parent_req_id
                       AND ROWNUM = 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error while deriving ship date');
            END;
        END IF;

        IF l_delivery_dtl_tab.EXISTS (1)
        THEN
            l_delivery_dtl_tab.DELETE;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Finding the EBS Order lines');
        fnd_file.put_line (fnd_file.LOG,
                           'Checking whether it is single shipment case');


        -- Find the EBS Order lines
        FOR l_delivery_dtl_rec IN cur_delivery_dtls_1 (p_in_chr_delivery_no)
        LOOP
            l_num_index                        := l_num_index + 1;

            /* SPLIT_LINE  - Start */
            -- Check whether the order line is sent in the pick ticket. If it is sent, no need to get the parent line

            l_num_pick_ticket_line             := 0;

            SELECT COUNT (1)
              INTO l_num_pick_ticket_line
              FROM xxont_pick_intf_line_stg
             WHERE     line_number = l_delivery_dtl_rec.line_number
                   AND order_number = p_in_chr_delivery_no
                   AND process_status = 'PROCESSED';

            -- Start of PICK_INTERFACE_LOG
            IF l_num_pick_ticket_line = 0
            THEN
                SELECT COUNT (1)
                  INTO l_num_pick_ticket_line
                  FROM xxont_pick_intf_line_stg_log
                 WHERE     line_number = l_delivery_dtl_rec.line_number
                       AND order_number = p_in_chr_delivery_no
                       AND process_status = 'PROCESSED';
            END IF;

            -- End of PICK_INTERFACE_LOG

            IF l_num_pick_ticket_line = 0
            THEN
                /* VVAP - Below loop is added to identify ultimate parent line id if a sales order line gets split multiple time */
                l_num_temp_line_id   := NULL;

                FOR i IN 1 .. 50
                LOOP
                    BEGIN
                        SELECT split_from_line_id
                          INTO l_num_temp_line_id
                          FROM oe_order_lines_all
                         WHERE line_id = l_delivery_dtl_rec.line_number;

                        IF l_num_temp_line_id IS NULL
                        THEN
                            EXIT;
                        ELSE
                            l_delivery_dtl_rec.line_number   :=
                                l_num_temp_line_id;

                            /* SPLIT_LINE - Start */

                            l_num_pick_ticket_line   := 0;

                            SELECT COUNT (1)
                              INTO l_num_pick_ticket_line
                              FROM xxont_pick_intf_line_stg
                             WHERE     line_number =
                                       l_delivery_dtl_rec.line_number
                                   AND order_number = p_in_chr_delivery_no
                                   AND process_status = 'PROCESSED';

                            -- Start of PICK_INTERFACE_LOG
                            IF l_num_pick_ticket_line = 0
                            THEN
                                SELECT COUNT (1)
                                  INTO l_num_pick_ticket_line
                                  FROM xxont_pick_intf_line_stg_log
                                 WHERE     line_number =
                                           l_delivery_dtl_rec.line_number
                                       AND order_number =
                                           p_in_chr_delivery_no
                                       AND process_status = 'PROCESSED';
                            END IF;

                            -- End of PICK_INTERFACE_LOG

                            IF l_num_pick_ticket_line <> 0
                            THEN
                                EXIT;
                            END IF;
                        /* SPLIT_LINE - End */
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                END LOOP;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Line ID : ' || l_delivery_dtl_rec.line_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Parent Line ID : ' || l_delivery_dtl_rec.line_number);
            /* SPLIT_LINE  - End */
            END IF;                                                         --

            l_delivery_dtl_tab (l_num_index)   := l_delivery_dtl_rec;
        END LOOP;

        IF l_num_index > 0
        THEN
            l_chr_delivery_found   := 'Y';
            fnd_file.put_line (
                fnd_file.LOG,
                'Single Shipment case - EBS Order lines found');
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Single Shipment case - EBS Order lines not found');
        END IF;

        IF l_chr_delivery_found = 'N'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Checking whether it is multiple shipment case');

            FOR l_delivery_dtl_rec
                IN cur_delivery_dtls_2 (p_in_chr_delivery_no)
            LOOP
                l_num_index                        := l_num_index + 1;
                /* SPLIT_LINE  - Start */
                -- Check whether the order line is sent in the pick ticket. If it is sent, no need to get the parent line


                l_num_pick_ticket_line             := 0;

                SELECT COUNT (1)
                  INTO l_num_pick_ticket_line
                  FROM xxont_pick_intf_line_stg
                 WHERE     line_number = l_delivery_dtl_rec.line_number
                       AND order_number = p_in_chr_delivery_no
                       AND process_status = 'PROCESSED';

                -- Start of PICK_INTERFACE_LOG
                IF l_num_pick_ticket_line = 0
                THEN
                    SELECT COUNT (1)
                      INTO l_num_pick_ticket_line
                      FROM xxont_pick_intf_line_stg_log
                     WHERE     line_number = l_delivery_dtl_rec.line_number
                           AND order_number = p_in_chr_delivery_no
                           AND process_status = 'PROCESSED';
                END IF;

                -- End of PICK_INTERFACE_LOG

                IF l_num_pick_ticket_line = 0
                THEN
                    /* VVAP - Below loop is added to identify ultimate parent line id if a sales order line gets split multiple time */
                    l_num_temp_line_id   := NULL;

                    FOR i IN 1 .. 50
                    LOOP
                        BEGIN
                            SELECT split_from_line_id
                              INTO l_num_temp_line_id
                              FROM oe_order_lines_all
                             WHERE line_id = l_delivery_dtl_rec.line_number;

                            IF l_num_temp_line_id IS NULL
                            THEN
                                EXIT;
                            ELSE
                                l_delivery_dtl_rec.line_number   :=
                                    l_num_temp_line_id;
                                /* SPLIT_LINE - Start */

                                l_num_pick_ticket_line   := 0;

                                SELECT COUNT (1)
                                  INTO l_num_pick_ticket_line
                                  FROM xxont_pick_intf_line_stg
                                 WHERE     line_number =
                                           l_delivery_dtl_rec.line_number
                                       AND order_number =
                                           p_in_chr_delivery_no
                                       AND process_status = 'PROCESSED';

                                -- Start of PICK_INTERFACE_LOG
                                IF l_num_pick_ticket_line = 0
                                THEN
                                    SELECT COUNT (1)
                                      INTO l_num_pick_ticket_line
                                      FROM xxont_pick_intf_line_stg_log
                                     WHERE     line_number =
                                               l_delivery_dtl_rec.line_number
                                           AND order_number =
                                               p_in_chr_delivery_no
                                           AND process_status = 'PROCESSED';
                                END IF;

                                -- End of PICK_INTERFACE_LOG

                                IF l_num_pick_ticket_line <> 0
                                THEN
                                    EXIT;
                                END IF;
                            /* SPLIT_LINE - End */
                            END IF;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                NULL;
                        END;
                    END LOOP;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Line ID : ' || l_delivery_dtl_rec.line_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Parent Line ID : ' || l_delivery_dtl_rec.line_number);
                END IF;

                /* SPLIT_LINE  - End */
                l_delivery_dtl_tab (l_num_index)   := l_delivery_dtl_rec;
            END LOOP;

            IF l_num_index > 0
            THEN
                l_chr_delivery_found      := 'Y';
                l_chr_new_delivery_reqd   := 'Y';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Multiple Shipment case - EBS Order lines found');
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Multiple Shipment case - EBS Order lines not found');
            END IF;
        END IF;

        IF l_chr_delivery_found = 'N'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'EBS Order lines not found - Update the error status');

            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     => p_in_chr_shipment_no,
                    p_in_chr_delivery_no     => p_in_chr_delivery_no,
                    p_in_chr_carton_no       => NULL,
                    p_in_chr_error_level     => 'DELIVERY',
                    p_in_chr_error_message   =>
                        'Delivery number not found in EBS',
                    p_in_chr_status          => 'ERROR',
                    p_in_chr_source          => 'DELIVERY_THREAD');
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    := 'Delivery number not found in EBS';
                fnd_file.put_line (fnd_file.LOG,
                                   'Delivery number not found in EBS');
                RETURN;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while updating error status :'
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RETURN;
            END;
        END IF;

        /* ROLLBACK_ALL - Start  */
        /*    fnd_file.put_line
                          (fnd_file.LOG,
                           'Checking whether the delivery is pick confirmed already'
                          );
            l_chr_packed_proc_status := NULL;

            --  If delivery detail status is 'S'  - Pick confirm is not done - simulate PACKED message
            IF l_delivery_dtl_tab (1).released_status = 'S'
            THEN
               BEGIN
                  SELECT process_status
                    INTO l_chr_packed_proc_status
                    FROM xxdo_ont_pick_status_order
                   WHERE order_number = p_in_chr_delivery_no
                     AND shipment_number = p_in_chr_shipment_no
                     AND wh_id = l_cartons_obj_tab (1).wh_id
                     AND status = 'PACKED';
               EXCEPTION
                  WHEN NO_DATA_FOUND
                  THEN
                     l_chr_packed_proc_status := NULL;
                  WHEN OTHERS
                  THEN
                     l_chr_packed_proc_status := NULL;
               END;

               IF l_chr_packed_proc_status IS NULL
               THEN
                  fnd_file.put_line (fnd_file.LOG,
                                     'Pick confirm the entire delivery'
                                    );
                  l_chr_pick_conf_failure := 'N';

                  -- Pick confirm the entire delivery
                  FOR l_num_ind IN 1 .. l_delivery_dtl_tab.COUNT
                  LOOP
                     pick_line
                        (p_out_chr_errbuf         => l_chr_errbuf,
                         p_out_chr_retcode        => l_chr_retcode,
                         p_in_num_mo_line_id      => l_delivery_dtl_tab (l_num_ind).mo_line_id,
                         p_in_txn_hdr_id          => l_delivery_dtl_tab (l_num_ind).transaction_header_id
                        );

                     IF l_chr_retcode <> '0'
                     THEN
                        l_chr_pick_conf_failure := 'Y';
                     END IF;
                  END LOOP;

                  -- If API failed for any of the move order lines, update the delivery as failed
                  IF l_chr_pick_conf_failure = 'Y'
                  THEN
                     BEGIN
                        update_error_records
                                  (p_out_chr_errbuf            => l_chr_errbuf,
                                   p_out_chr_retcode           => l_chr_retcode,
                                   p_in_chr_shipment_no        => p_in_chr_shipment_no,
                                   p_in_chr_delivery_no        => p_in_chr_delivery_no,
                                   p_in_chr_carton_no          => NULL,
                                   p_in_chr_error_level        => 'DELIVERY',
                                   p_in_chr_error_message      => 'Pick confirm failed',
                                   p_in_chr_status             => 'ERROR',
                                   p_in_chr_source                  => 'DELIVERY_THREAD'
                                  );
                        p_out_chr_retcode := '2';
                        p_out_chr_errbuf := 'Pick confirm failed';
                        RETURN;
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           p_out_chr_retcode := '2';
                           p_out_chr_errbuf :=
                                 'Unexpected Error while updating error status :'
                              || l_chr_errbuf;
                           fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                           RETURN;
                     END;
                  ELSE
      -- Pick confirmation is fully successful. Insert the packed message into order status table.
                     BEGIN
                        INSERT INTO xxdo.xxdo_ont_pick_status_order
                                    (wh_id,
                                     order_number, tran_date,
                                     status, shipment_number, shipment_status,
                                     comments, error_msg, created_by,
                                     creation_date, last_updated_by,
                                     last_update_date, last_update_login,
                                     process_status, record_type, SOURCE,
                                     destination
                                    )
                             VALUES (l_cartons_obj_tab (1).wh_id,
                                     p_in_chr_delivery_no, p_in_dte_ship_date,
                                     'PACKED', p_in_chr_shipment_no, 'NEW',
                                               -- bsk shipment status to be verified
                                     'SHIP-AUTOINSERT',             --bsk comments to be verified
                                          NULL, g_num_user_id,
                                     SYSDATE, g_num_user_id,
                                     SYSDATE, g_num_login_id,
                                     'PROCESSED', 'INSERT',            --record type
                                                           'WMS',           --source
                                     'EBS'                            -- destination
                                    );
                     EXCEPTION
                        WHEN OTHERS
                        THEN
                           p_out_chr_retcode := '1';
                           p_out_chr_errbuf :=
                                 'PACKED message is not inserted into order status table due to : '
                              || SQLERRM;
                           fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                     END;
                  END IF;
               ELSIF l_chr_packed_proc_status IN ('PROCESSED', 'ERROR')
               THEN
                  BEGIN
                     update_error_records
                        (p_out_chr_errbuf            => l_chr_errbuf,
                         p_out_chr_retcode           => l_chr_retcode,
                         p_in_chr_shipment_no        => p_in_chr_shipment_no,
                         p_in_chr_delivery_no        => p_in_chr_delivery_no,
                         p_in_chr_carton_no          => NULL,
                         p_in_chr_error_level        => 'DELIVERY',
                         p_in_chr_error_message      => 'Pick confirm failed in Order status update program',
                         p_in_chr_status             => 'ERROR',
                         p_in_chr_source                  => 'DELIVERY_THREAD'
                        );
                     p_out_chr_retcode := '2';
                     p_out_chr_errbuf :=
                                'Pick confirm failed in Order status update program';
                     RETURN;
                  EXCEPTION
                     WHEN OTHERS
                     THEN
                        p_out_chr_retcode := '2';
                        p_out_chr_errbuf :=
                              'Unexpected Error while updating error status :'
                           || l_chr_errbuf;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RETURN;
                  END;
               END IF;
            END IF;
      */
        /* ROLLBACK_ALL - End */
        -- Store the order header id at the shipment level
        --    l_shipconf_headers_obj_tab (l_num_shipment_index).attribute1 := l_delivery_dtl_tab(1).header_id ;

        -- Logic to identify whether partial shipment
        fnd_file.put_line (fnd_file.LOG,
                           'Identify the shipped qty for all the EBS lines');
        l_num_initial_ebs_lines_count   := l_delivery_dtl_tab.COUNT;

        fnd_file.put_line (
            fnd_file.LOG,
            'Initial EBS lines count : ' || l_num_initial_ebs_lines_count);


        FOR l_num_ind IN 1 .. l_num_initial_ebs_lines_count -- Loop for delivery details from EBS
        LOOP
            -- Loop for Carton from WMS
            FOR l_num_carton_index IN 1 .. l_cartons_obj_tab.COUNT
            LOOP
                -- Loop for Carton details / lines from WMS
                FOR l_num_line_index IN 1 ..
                                        l_cartons_obj_tab (
                                            l_num_carton_index).carton_dtls_obj_tab.COUNT
                LOOP
                    IF l_delivery_dtl_tab (l_num_ind).line_number =
                       l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                           l_num_line_index).line_number
                    THEN
                        /* Validation - shipped qty > requested qty - Start - Bsk*/
                        IF l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                               l_num_line_index).qty >
                           l_delivery_dtl_tab (l_num_ind).requested_quantity
                        THEN --- If the shipped qty is more than requested qty, the entire delivery should error out
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'delivery detail count: ' || l_num_ind);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'l_num_carton_index : ' || l_num_carton_index);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'l_num_line_index : ' || l_num_line_index);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_delivery_dtl_tab (l_num_ind).line_number : '
                                || l_delivery_dtl_tab (l_num_ind).line_number);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab(l_num_line_index).line_number : '
                                || l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                       l_num_line_index).line_number);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab(l_num_line_index).item_number : '
                                || l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                       l_num_line_index).item_number);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_delivery_dtl_tab (l_num_ind).ordered_item : '
                                || l_delivery_dtl_tab (l_num_ind).ordered_item);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (l_num_line_index).qty : '
                                || l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                       l_num_line_index).qty);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_delivery_dtl_tab (l_num_ind).requested_quantity : '
                                || l_delivery_dtl_tab (l_num_ind).requested_quantity);


                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Shipped qty is more than requested qty on the line : '
                                || l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                       l_num_line_index).line_number;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            update_error_records (
                                p_out_chr_errbuf         => l_chr_errbuf,
                                p_out_chr_retcode        => l_chr_retcode,
                                p_in_chr_shipment_no     => p_in_chr_shipment_no,
                                p_in_chr_delivery_no     => p_in_chr_delivery_no,
                                p_in_chr_carton_no       => NULL,
                                p_in_chr_error_level     => 'DELIVERY',
                                p_in_chr_error_message   => p_out_chr_errbuf,
                                p_in_chr_status          => 'ERROR',
                                p_in_chr_source          => 'DELIVERY_THREAD');
                            RETURN;
                        END IF;

                        /* Validation - shipped qty > requested qty - End - Bsk*/

                        /* Multiple Cartons for same order line - Start - Bsk */

                        IF l_delivery_dtl_tab (l_num_ind).shipped_quantity =
                           0
                        THEN
                            l_delivery_dtl_tab (l_num_ind).shipped_quantity   :=
                                l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                    l_num_line_index).qty;
                            l_delivery_dtl_tab (l_num_ind).carton   :=
                                l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                    l_num_line_index).carton_number;
                        ELSE
                            l_delivery_dtl_tab (l_delivery_dtl_tab.COUNT + 1)   :=
                                l_delivery_dtl_tab (l_num_ind);
                            l_delivery_dtl_tab (l_delivery_dtl_tab.COUNT).shipped_quantity   :=
                                l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                    l_num_line_index).qty;

                            l_delivery_dtl_tab (l_delivery_dtl_tab.COUNT).carton   :=
                                l_cartons_obj_tab (l_num_carton_index).carton_dtls_obj_tab (
                                    l_num_line_index).carton_number;

                            l_delivery_dtl_tab (l_delivery_dtl_tab.COUNT).orig_delivery_detail_id   :=
                                l_delivery_dtl_tab (l_num_ind).delivery_detail_id;
                            l_delivery_dtl_tab (l_delivery_dtl_tab.COUNT).delivery_detail_id   :=
                                NULL;
                        END IF;
                    /* Multiple Cartons for same order line - End - Bsk */
                    END IF;
                END LOOP;
            END LOOP;
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            'EBS lines count after new logic  : ' || l_delivery_dtl_tab.COUNT);

        -- Logic to unassign the deliveries which are not shipped-- If new delivery required is No, there is a delivery already. Unshipped delivery details to be unassigned
        IF l_chr_new_delivery_reqd = 'N'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unassign the unshipped delivery details from the original delivery');
            l_num_unship_del_dtl_id_ind   := 0;

            FOR l_num_ind IN 1 .. l_delivery_dtl_tab.COUNT
            -- Loop for delivery details from EBS
            LOOP
                IF NVL (l_delivery_dtl_tab (l_num_ind).shipped_quantity, 0) =
                   0
                THEN
                    --                   IF   l_delivery_dtl_tab(l_num_ind).ship_status = 'NOT SHIPPED' THEN
                    l_num_unship_del_dtl_id_ind   :=
                        l_num_unship_del_dtl_id_ind + 1;
                    l_unshipped_del_dtl_ids_tab (l_num_unship_del_dtl_id_ind)   :=
                        l_delivery_dtl_tab (l_num_ind).delivery_detail_id;
                END IF;
            END LOOP;

            -- Invoke unassign procedure if atleast 1 unshipped delivery detail exists
            l_chr_errbuf                  := NULL;
            l_chr_retcode                 := '0';


            IF l_unshipped_del_dtl_ids_tab.EXISTS (1)
            THEN
                BEGIN
                    assign_detail_to_delivery (
                        p_out_chr_errbuf           => l_chr_errbuf,
                        p_out_chr_retcode          => l_chr_retcode,
                        p_in_num_delivery_id       =>
                            l_delivery_dtl_tab (1).delivery_id,
                        p_in_chr_delivery_name     =>
                            l_delivery_dtl_tab (1).delivery_name,
                        p_in_delivery_detail_ids   =>
                            l_unshipped_del_dtl_ids_tab,
                        p_in_chr_action            => 'UNASSIGN');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while invoking unassign delivery detail procedure :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   => p_out_chr_errbuf,
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        RETURN;
                END;

                IF l_chr_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   =>
                                'Unable to unassign the deliveries',
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                            'Unable to unassign the deliveries';
                        RETURN;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || l_chr_errbuf;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            RETURN;
                    END;
                END IF;
            END IF;
        END IF;

        -- Loop to find the shipped and partial shipped lines  -- Identify only the shipped/partial shipped lines
        l_num_ship_del_dtl_id_ind       := 0;
        l_num_ship_del_dtl_id_ind_mc    := 0;

        FOR l_num_ind IN 1 .. l_delivery_dtl_tab.COUNT -- Loop for delivery details from EBS
        LOOP
            IF NVL (l_delivery_dtl_tab (l_num_ind).shipped_quantity, 0) <> 0
            THEN
                --  /* Multiple Cartons for same order line - Start - Bsk */
                IF l_delivery_dtl_tab (l_num_ind).delivery_detail_id
                       IS NOT NULL
                THEN
                    l_num_ship_del_dtl_id_ind_mc   :=
                        l_num_ship_del_dtl_id_ind_mc + 1;
                    l_shipped_del_dtl_ids_tab (l_num_ship_del_dtl_id_ind_mc)   :=
                        l_delivery_dtl_tab (l_num_ind).delivery_detail_id;
                END IF;

                --  /* Multiple Cartons for same order line - End - Bsk */
                l_num_ship_del_dtl_id_ind   := l_num_ship_del_dtl_id_ind + 1;
                l_shipments_tab (l_num_ship_del_dtl_id_ind).delivery_detail_id   :=
                    l_delivery_dtl_tab (l_num_ind).delivery_detail_id;
                l_shipments_tab (l_num_ship_del_dtl_id_ind).quantity   :=
                    l_delivery_dtl_tab (l_num_ind).shipped_quantity;
                l_shipments_tab (l_num_ship_del_dtl_id_ind).inventory_item_id   :=
                    l_delivery_dtl_tab (l_num_ind).inventory_item_id;
                l_shipments_tab (l_num_ship_del_dtl_id_ind).carton   :=
                    l_delivery_dtl_tab (l_num_ind).carton;
            END IF;
        END LOOP;


        fnd_file.put_line (
            fnd_file.LOG,
            'Checking whether new delivery needs to be created');

        -- Create new delivery and assign the shipped delivery details
        IF l_chr_new_delivery_reqd = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Creating new delivery');
            -- Invoke assign procedure if atleast 1 shipped delivery detail exists
            l_chr_errbuf    := NULL;
            l_chr_retcode   := '0';

            IF l_shipped_del_dtl_ids_tab.EXISTS (1)
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Creating new delivery');

                -- Create delivery
                BEGIN
                    create_delivery (
                        p_out_chr_errbuf           => l_chr_errbuf,
                        p_out_chr_retcode          => l_chr_retcode,
                        p_in_num_wdd_org_id        =>
                            l_delivery_dtl_tab (1).organization_id,
                        p_in_num_wdd_cust_id       =>
                            l_delivery_dtl_tab (1).customer_id,
                        p_in_num_wdd_ship_method   =>
                            l_delivery_dtl_tab (1).ship_method_code,
                        p_in_num_ship_from_loc_id   =>
                            l_delivery_dtl_tab (1).ship_from_loc_id,
                        p_in_num_ship_to_loc_id    =>
                            l_delivery_dtl_tab (1).ship_to_loc_id,
                        p_in_chr_carrier           => p_in_chr_carrier,
                        p_in_chr_waybill           => NULL,
                        -- bsk way bill no to be passed
                        p_in_chr_tracking_number   => NULL,
                        -- bsk tracking no is at carton level
                        p_in_chr_orig_del_name     => p_in_chr_delivery_no,
                        p_out_num_delivery_id      => l_num_new_delivery_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'New delivery ID: ' || l_num_new_delivery_id);
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while invoking creating delivery procedure :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   => p_out_chr_errbuf,
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        RETURN;
                END;

                IF l_chr_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   =>
                                'Unable to create new delivery',
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                            'Unable to create new delivery';
                        RETURN;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || l_chr_errbuf;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            RETURN;
                    END;
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'New delivery created : ' || l_num_new_delivery_id);

                    /* DEL_SOURCE_HDR_ID  - Start */

                    /*  Assinging the delivery detail to new delivery was failing since Source header id is blank on the new delivery created in 12.2.3.
                     So, Source header id is updated on new delivery */

                    UPDATE wsh_new_deliveries
                       SET source_header_id = l_delivery_dtl_tab (1).header_id
                     WHERE delivery_id = l_num_new_delivery_id;
                /* DEL_SOURCE_HDR_ID  - End */


                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Assigning all the shipped delivery details to the new delivery');

                BEGIN
                    assign_detail_to_delivery (
                        p_out_chr_errbuf           => l_chr_errbuf,
                        p_out_chr_retcode          => l_chr_retcode,
                        p_in_num_delivery_id       => l_num_new_delivery_id,
                        p_in_chr_delivery_name     => NULL,
                        p_in_delivery_detail_ids   =>
                            l_shipped_del_dtl_ids_tab,
                        p_in_chr_action            => 'ASSIGN');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while invoking unassign delivery detail procedure :'
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   => p_out_chr_errbuf,
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        RETURN;
                END;

                IF l_chr_retcode <> '0'
                THEN
                    BEGIN
                        update_error_records (
                            p_out_chr_errbuf         => l_chr_errbuf,
                            p_out_chr_retcode        => l_chr_retcode,
                            p_in_chr_shipment_no     => p_in_chr_shipment_no,
                            p_in_chr_delivery_no     => p_in_chr_delivery_no,
                            p_in_chr_carton_no       => NULL,
                            p_in_chr_error_level     => 'DELIVERY',
                            p_in_chr_error_message   =>
                                'Unable to assign the deliveries',
                            p_in_chr_status          => 'ERROR',
                            p_in_chr_source          => 'DELIVERY_THREAD');
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                            'Unable to assign the deliveries';
                        RETURN;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            p_out_chr_retcode   := '2';
                            p_out_chr_errbuf    :=
                                   'Unexpected Error while updating error status :'
                                || l_chr_errbuf;
                            fnd_file.put_line (fnd_file.LOG,
                                               p_out_chr_errbuf);
                            RETURN;
                    END;
                END IF;
            END IF;
        END IF;

        l_num_api_delivery_id           :=
            CASE
                WHEN l_chr_new_delivery_reqd = 'N'
                THEN
                    l_delivery_dtl_tab (1).delivery_id
                ELSE
                    l_num_new_delivery_id
            END;
        fnd_file.put_line (
            fnd_file.LOG,
            'Spliting the delivery detail for partial shipment case and updating the shipped qty');

        -- Split the delivery detail for partial shipment case and update the shipped qty
        FOR l_num_del_dtl_ind IN 1 .. l_delivery_dtl_tab.COUNT
        LOOP
            IF     l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity <>
                   0
               AND l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity <>
                   l_delivery_dtl_tab (l_num_del_dtl_ind).requested_quantity
            THEN
                /* Multiple Cartons for same order line - Start - Bsk */
                l_chr_split_required   := 'Y';

                --                  IF l_delivery_dtl_tab(l_num_del_dtl_ind).delivery_detail_id IS NULL THEN

                SELECT MAX (src_requested_quantity), NVL (SUM (NVL (shipped_quantity, 0)), 0)
                  INTO l_num_req_qty, l_num_ship_qty
                  FROM wsh_delivery_details
                 WHERE     source_line_id =
                           l_delivery_dtl_tab (l_num_del_dtl_ind).line_id
                       AND source_code = 'OE';

                l_num_remaining_qty    :=
                      l_num_req_qty
                    - l_num_ship_qty
                    - l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity;

                l_num_split_qty        := l_num_remaining_qty;

                IF l_num_remaining_qty = 0
                THEN
                    SELECT MAX (delivery_detail_id)
                      INTO l_num_new_del_detail_id
                      FROM wsh_delivery_details
                     WHERE     source_line_id =
                               l_delivery_dtl_tab (l_num_del_dtl_ind).line_id
                           AND source_code = 'OE';

                    --                        AND shipped_quantity IS NULL;

                    l_chr_split_required   := 'N';

                    l_delivery_dtl_tab (l_num_del_dtl_ind).delivery_detail_id   :=
                        l_num_new_del_detail_id;
                --l_num_split_qty := l_num_remaining_qty - l_delivery_dtl_tab(l_num_del_dtl_ind).shipped_quantity;


                END IF;

                --         ELSE

                --                 l_num_split_qty := l_delivery_dtl_tab(l_num_del_dtl_ind).requested_quantity - l_delivery_dtl_tab(l_num_del_dtl_ind).shipped_quantity;

                --         END IF;


                SELECT MAX (delivery_detail_id)
                  INTO l_num_split_from_del_id      ---l_num_new_del_detail_id
                  FROM wsh_delivery_details
                 WHERE     source_line_id =
                           l_delivery_dtl_tab (l_num_del_dtl_ind).line_id
                       AND source_code = 'OE';

                IF l_chr_split_required = 'Y'
                THEN
                    split_delivery_detail (
                        p_out_chr_errbuf          => l_chr_errbuf,
                        p_out_chr_retcode         => l_chr_retcode,
                        -- /* Multiple Cartons for same order line - Bsk */
                        p_in_num_delivery_detail_id   =>
                            l_num_split_from_del_id,
                        --                p_in_num_delivery_detail_id       => NVL( l_delivery_dtl_tab
                        --                                                            (l_num_del_dtl_ind).delivery_detail_id,
                        --                                                                         l_delivery_dtl_tab
                        --                                                            (l_num_del_dtl_ind).orig_delivery_detail_id),
                        --                p_in_num_split_quantity           => l_delivery_dtl_tab(l_num_del_dtl_ind).requested_quantity - l_delivery_dtl_tab(l_num_del_dtl_ind).shipped_quantity,
                        p_in_num_split_quantity   => l_num_split_qty,
                        /* VVAP - changed the quantity that has been sent to split procedure */
                        --l_delivery_dtl_tab(l_num_del_dtl_ind).shipped_quantity,
                        p_in_chr_delivery_name    => p_in_chr_delivery_no,
                        p_out_num_delivery_detail_id   =>
                            l_num_new_del_detail_id);
                -- Update the shipped quantity as zero for the split line otherwise a new delivery will be created during ship confirm
                --           FND_FILE.PUT_LINE (FND_FILE.LOG, 'Updating the shipped quantity as zero for the split line :' || l_num_new_del_detail_id );
                END IF;

                /* Multiple Cartons for same order line - End - Bsk */

                /* VVAP - below update procedure is uncommented as for newly split line shipped qty is getting copied */
                update_shipping_attributes (
                    p_out_chr_errbuf              => l_chr_errbuf,
                    p_out_chr_retcode             => l_chr_retcode,
                    p_in_num_delivery_detail_id   => l_num_new_del_detail_id,
                    p_in_num_shipped_quantity     => 0, --CASE WHEN l_delivery_dtl_tab(l_num_del_dtl_ind).delivery_detail_id IS NULL THEN l_delivery_dtl_tab(l_num_del_dtl_ind).shipped_quantity
                    --ELSE 0 END,
                    p_in_num_order_line_id        => -1, -- line should not be updated
                    p_in_dte_ship_date            => p_in_dte_ship_date);
            /* Multiple Cartons for same order line - Start - Bsk */

            --               END IF;
            /* Multiple Cartons for same order line - End - Bsk */
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery Detail ID : '
                || l_delivery_dtl_tab (l_num_del_dtl_ind).delivery_detail_id);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Shipped Qty: '
                || l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity);

            update_shipping_attributes (
                p_out_chr_errbuf         => l_chr_errbuf,
                p_out_chr_retcode        => l_chr_retcode,
                p_in_num_delivery_detail_id   =>
                    NVL (
                        l_delivery_dtl_tab (l_num_del_dtl_ind).delivery_detail_id,
                        l_num_split_from_del_id),
                p_in_num_shipped_quantity   =>
                    l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity,
                p_in_num_order_line_id   =>
                    CASE
                        WHEN l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity <>
                             0
                        THEN
                            l_delivery_dtl_tab (l_num_del_dtl_ind).line_id
                        ELSE
                            -1
                    END,
                -- for unshipped lines - ship date at the line level should not be updated, so passing -1
                p_in_dte_ship_date       => p_in_dte_ship_date);

            /* Multiple Cartons for same order line - Start - Bsk */
            -- Populate the new delivery detail id
            IF l_delivery_dtl_tab (l_num_del_dtl_ind).delivery_detail_id
                   IS NULL
            THEN
                l_delivery_dtl_tab (l_num_del_dtl_ind).delivery_detail_id   :=
                    l_num_split_from_del_id;
            END IF;

            -- Shipment tabs does not have new delivery detail id
            FOR l_num_null_ind IN 1 .. l_shipments_tab.COUNT
            LOOP
                IF l_shipments_tab (l_num_null_ind).delivery_detail_id
                       IS NULL
                THEN
                    IF     l_shipments_tab (l_num_null_ind).carton =
                           l_delivery_dtl_tab (l_num_del_dtl_ind).carton
                       AND l_shipments_tab (l_num_null_ind).inventory_item_id =
                           l_delivery_dtl_tab (l_num_del_dtl_ind).inventory_item_id
                       AND l_shipments_tab (l_num_null_ind).quantity =
                           l_delivery_dtl_tab (l_num_del_dtl_ind).shipped_quantity
                    THEN
                        l_shipments_tab (l_num_null_ind).delivery_detail_id   :=
                            l_delivery_dtl_tab (l_num_del_dtl_ind).delivery_detail_id;
                    END IF;
                END IF;
            END LOOP;
        /* Multiple Cartons for same order line - End - Bsk */


        END LOOP;

        ---- Logic to unassign the unshipped qtys
        --- Added for multiple cartons case
        /* Multiple Cartons for same order line - Start - Bsk */

        IF l_split_del_dtl_ids_tab.EXISTS (1)
        THEN
            l_split_del_dtl_ids_tab.DELETE;
        END IF;


        FOR unassign_dels_rec IN cur_unassign_dels (l_num_api_delivery_id)
        LOOP
            l_split_del_dtl_ids_tab (l_split_del_dtl_ids_tab.COUNT + 1)   :=
                unassign_dels_rec.delivery_detail_id;
        END LOOP;

        IF l_split_del_dtl_ids_tab.EXISTS (1)
        THEN
            BEGIN
                assign_detail_to_delivery (
                    p_out_chr_errbuf           => l_chr_errbuf,
                    p_out_chr_retcode          => l_chr_retcode,
                    p_in_num_delivery_id       => l_num_api_delivery_id, --l_delivery_dtl_tab (1).delivery_id,
                    p_in_chr_delivery_name     => p_in_chr_delivery_no, --l_delivery_dtl_tab (1).delivery_name,/* VVAP - changed the delivery name value*/
                    p_in_delivery_detail_ids   => l_split_del_dtl_ids_tab,
                    p_in_chr_action            => 'UNASSIGN');
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while invoking unassign delivery detail procedure for split line :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    update_error_records (
                        p_out_chr_errbuf         => l_chr_errbuf,
                        p_out_chr_retcode        => l_chr_retcode,
                        p_in_chr_shipment_no     => p_in_chr_shipment_no,
                        p_in_chr_delivery_no     => p_in_chr_delivery_no,
                        p_in_chr_carton_no       => NULL,
                        p_in_chr_error_level     => 'DELIVERY',
                        p_in_chr_error_message   => p_out_chr_errbuf,
                        p_in_chr_status          => 'ERROR',
                        p_in_chr_source          => 'DELIVERY_THREAD');
                    RETURN;
            END;

            IF l_chr_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        p_out_chr_errbuf         => l_chr_errbuf,
                        p_out_chr_retcode        => l_chr_retcode,
                        p_in_chr_shipment_no     => p_in_chr_shipment_no,
                        p_in_chr_delivery_no     => p_in_chr_delivery_no,
                        p_in_chr_carton_no       => NULL,
                        p_in_chr_error_level     => 'DELIVERY',
                        p_in_chr_error_message   =>
                            'Unable to unassign the split deliveries',
                        p_in_chr_status          => 'ERROR',
                        p_in_chr_source          => 'DELIVERY_THREAD');
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                        'Unable to unassign the split deliveries';
                    RETURN;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || l_chr_errbuf;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RETURN;
                END;
            END IF;
        END IF;

        /* Multiple Cartons for same order line - End - Bsk */

        fnd_file.put_line (fnd_file.LOG,
                           'Creating container for each carton');

        FOR l_num_carton_ind IN 1 .. l_cartons_obj_tab.COUNT
        LOOP
            IF l_cur_shipments_tab.EXISTS (1)
            THEN
                l_cur_shipments_tab.DELETE;
            END IF;


            -- Logic to get the order/delivery line details of the current carton
            FOR l_num_ship_ind IN 1 .. l_shipments_tab.COUNT
            LOOP
                IF l_cartons_obj_tab (l_num_carton_ind).carton_number =
                   l_shipments_tab (l_num_ship_ind).carton
                THEN
                    l_cur_shipments_tab (l_cur_shipments_tab.COUNT + 1)   :=
                        l_shipments_tab (l_num_ship_ind);
                END IF;
            END LOOP;

            BEGIN
                pack_container (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_num_header_id       => l_delivery_dtl_tab (1).header_id,
                    p_in_num_delivery_id     => l_num_api_delivery_id,
                    -- CASE WHEN  l_chr_new_delivery_reqd =  'N' THEN l_delivery_dtl_tab(1).delivery_id ELSE l_num_new_delivery_id END,
                    p_in_chr_container_name   =>
                        l_cartons_obj_tab (l_num_carton_ind).carton_number,
                    p_in_shipments_tab       => l_cur_shipments_tab,
                    --l_shipments_tab,
                    --         p_in_num_freight_cost          => l_cartons_obj_tab(l_num_carton_ind).freight_actual,/*  FREIGHT_CHARGED */
                    p_in_num_freight_cost    =>
                        CASE
                            WHEN NVL (
                                     l_cartons_obj_tab (l_num_carton_ind).freight_charged,
                                     0) >
                                 0
                            THEN
                                l_cartons_obj_tab (l_num_carton_ind).freight_charged
                            ELSE
                                l_cartons_obj_tab (l_num_carton_ind).freight_actual
                        END,
                    p_in_num_container_weight   =>
                        l_cartons_obj_tab (l_num_carton_ind).weight,
                    p_in_chr_tracking_number   =>
                        l_cartons_obj_tab (l_num_carton_ind).tracking_number,
                    p_in_chr_carrier         => p_in_chr_carrier,
                    p_in_dte_shipment_date   => p_in_dte_ship_date,
                    p_in_num_org_id          =>
                        l_delivery_dtl_tab (1).organization_id,
                    p_in_chr_warehouse       =>
                        l_cartons_obj_tab (l_num_carton_ind).wh_id,
                    p_out_num_container_id   => l_num_container_id);
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Carton Number : '
                    || l_cartons_obj_tab (l_num_carton_ind).carton_number
                    || ' Container ID : '
                    || l_num_container_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unexpected Error while invoking pack container procedure :'
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    update_error_records (
                        p_out_chr_errbuf         => l_chr_errbuf,
                        p_out_chr_retcode        => l_chr_retcode,
                        p_in_chr_shipment_no     => p_in_chr_shipment_no,
                        p_in_chr_delivery_no     => p_in_chr_delivery_no,
                        p_in_chr_carton_no       => NULL,
                        p_in_chr_error_level     => 'DELIVERY',
                        p_in_chr_error_message   => p_out_chr_errbuf,
                        p_in_chr_status          => 'ERROR',
                        p_in_chr_source          => 'DELIVERY_THREAD');
                    RETURN;
            END;


            IF l_chr_retcode <> '0'
            THEN
                BEGIN
                    update_error_records (
                        p_out_chr_errbuf       => l_chr_errbuf,
                        p_out_chr_retcode      => l_chr_retcode,
                        p_in_chr_shipment_no   => p_in_chr_shipment_no,
                        p_in_chr_delivery_no   => p_in_chr_delivery_no,
                        p_in_chr_carton_no     => NULL,
                        p_in_chr_error_level   => 'DELIVERY',
                        p_in_chr_error_message   =>
                               'Unable create container for carton number '
                            || l_cartons_obj_tab (l_num_carton_ind).carton_number,
                        p_in_chr_status        => 'ERROR',
                        p_in_chr_source        => 'DELIVERY_THREAD');
                    p_out_chr_retcode   := '2';
                    p_out_chr_errbuf    :=
                           'Unable create container for carton number '
                        || l_cartons_obj_tab (l_num_carton_ind).carton_number;
                    RETURN;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_retcode   := '2';
                        p_out_chr_errbuf    :=
                               'Unexpected Error while updating error status :'
                            || l_chr_errbuf;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RETURN;
                END;
            END IF;
        END LOOP;

        -- Updating the delivery ids on the staging table for ship confirm and interface trip stop
        BEGIN
            UPDATE xxdo_ont_ship_conf_order_stg
               SET order_header_id = l_delivery_dtl_tab (1).header_id, delivery_id = l_num_api_delivery_id, ship_to_org_id = l_delivery_dtl_tab (1).ship_to_org_id,
                   ship_to_location_id = l_delivery_dtl_tab (1).ship_to_loc_id, last_update_date = SYSDATE, last_updated_by = g_num_user_id
             WHERE     shipment_number = p_in_chr_shipment_no
                   AND order_number = p_in_chr_delivery_no
                   AND process_status = 'INPROCESS'
                   AND request_id = p_in_num_parent_req_id;

            --         COMMIT;  /* ROLLBACK_ALL */
            p_out_chr_errbuf    := NULL;
            p_out_chr_retcode   := '0';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                       'Unexpected error while updating delivery details on the staging table:'
                    || SQLERRM;
                p_out_chr_retcode   := '2';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;
    EXCEPTION
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at delivery thread procedure : '
                || p_out_chr_errbuf);
            update_error_records (
                p_out_chr_errbuf         => l_chr_errbuf,
                p_out_chr_retcode        => l_chr_retcode,
                p_in_chr_shipment_no     => p_in_chr_shipment_no,
                p_in_chr_delivery_no     => p_in_chr_delivery_no,
                p_in_chr_carton_no       => NULL,
                p_in_chr_error_level     => 'DELIVERY',
                p_in_chr_error_message   =>
                       'Unexpected error at delivery thread procedure : '
                    || p_out_chr_errbuf,
                p_in_chr_status          => 'ERROR',
                p_in_chr_source          => 'DELIVERY_THREAD');
    END delivery_thread;

    -- ***************************************************************************
    -- Procedure Name      :  assign_detail_to_delivery
    --
    -- Description         :  This procedure assigns a Delivery detail to a
    --                        Delivery
    --
    -- Parameters          :
    --                                p_out_chr_errbuf         OUT : Error Message
    --                                p_out_chr_retcode        OUT : Execution status
    --                                p_in_num_delivery_id       IN   : Delivery Id
    --                                p_in_chr_delivery_name     IN   :    Delivery Name
    --                                p_in_delivery_detail_ids   IN   :    Delivery Detail Ids
    --                                p_in_chr_action            IN   :    Action - ASSIGN / UNASSIGN
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0  Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE assign_detail_to_delivery (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_id IN NUMBER
                                         , p_in_chr_delivery_name IN VARCHAR2, p_in_delivery_detail_ids IN tabtype_id, p_in_chr_action IN VARCHAR2 DEFAULT 'ASSIGN')
    IS
        l_chr_return_status     VARCHAR2 (30) := NULL;
        l_num_msg_count         NUMBER;
        l_num_msg_cntr          NUMBER;
        l_num_msg_index_out     NUMBER;
        l_chr_msg_data          VARCHAR2 (2000);
        l_del_details_ids_tab   wsh_delivery_details_pub.id_tab_type;
        excp_set_error          EXCEPTION;
    BEGIN
        --Reset status variables
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        --Set delivery detail id
        FOR l_num_ind IN 1 .. p_in_delivery_detail_ids.COUNT
        LOOP
            l_del_details_ids_tab (l_num_ind)   :=
                p_in_delivery_detail_ids (l_num_ind);
        END LOOP;

        wsh_delivery_details_pub.detail_to_delivery (
            p_api_version        => g_num_api_version,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => NULL,
            x_return_status      => l_chr_return_status,
            x_msg_count          => l_num_msg_count,
            x_msg_data           => l_chr_msg_data,
            p_tabofdeldets       => l_del_details_ids_tab,
            p_action             => p_in_chr_action,
            p_delivery_id        => p_in_num_delivery_id);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF l_num_msg_count > 0
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'API to '
                    || LOWER (p_in_chr_action)
                    || ' delivery detail id failed with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                -- Retrieve messages
                l_num_msg_cntr      := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || l_chr_msg_data);
                END LOOP;
            END IF;
        ELSE
            p_out_chr_errbuf   :=
                   'API to '
                || LOWER (p_in_chr_action)
                || ' delivery detail was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            --- Logic to update the delivery name on the unassigned delivery details
            IF p_in_chr_action = 'UNASSIGN'
            THEN
                FOR l_num_ind IN 1 .. p_in_delivery_detail_ids.COUNT
                LOOP
                    UPDATE wsh_delivery_details wdd
                       SET attribute11   = p_in_chr_delivery_name /* VVAP attribute11*/
                     WHERE delivery_detail_id =
                           p_in_delivery_detail_ids (l_num_ind);
                END LOOP;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'Unexpected error while '
                || LOWER (p_in_chr_action)
                || 'ing delivery detail.'
                || SQLERRM;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END assign_detail_to_delivery;

    -- ***************************************************************************
    -- Procedure Name      :  pack_into_container
    --
    -- Description         :  This procedure is to link the container, delivery and delivery details
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                            p_in_num_delivery_id       IN   : Delivery Id
    --                            p_in_num_container_id   IN  : Container Id
    --                            p_in_delivery_ids_tab   IN  : Delivery detail ids
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE pack_into_container (
        p_out_chr_errbuf           OUT VARCHAR2,
        p_out_chr_retcode          OUT VARCHAR2,
        p_in_num_delivery_id    IN     NUMBER,
        p_in_num_container_id   IN     NUMBER,
        p_in_delivery_ids_tab   IN     wsh_util_core.id_tab_type)
    IS
        l_num_msg_count   NUMBER;
        l_chr_msg_data    VARCHAR2 (4000);
        l_chr_retcode     VARCHAR2 (1);
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_msg_pub.initialize;
        fnd_file.put_line (
            fnd_file.LOG,
            'Trying to pack into container id: ' || p_in_num_container_id);
        fnd_file.put_line (fnd_file.LOG,
                           'delivery_id: ' || p_in_num_delivery_id);
        fnd_file.put_line (fnd_file.LOG,
                           'container_id: ' || p_in_num_container_id);

        FOR i IN 1 .. p_in_delivery_ids_tab.COUNT
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'delivery_detail_id ('
                || i
                || '): '
                || p_in_delivery_ids_tab (i));
        END LOOP;

        wsh_container_pub.container_actions (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            x_return_status      => l_chr_retcode,
            x_msg_count          => l_num_msg_count,
            x_msg_data           => l_chr_msg_data,
            p_detail_tab         => p_in_delivery_ids_tab,
            p_container_name     => NULL,
            p_cont_instance_id   => p_in_num_container_id,
            p_container_flag     => 'N',
            p_delivery_flag      => 'N',
            p_delivery_id        => p_in_num_delivery_id,
            p_delivery_name      => NULL,
            p_action_code        => 'PACK');

        IF l_chr_retcode <> 'S'
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'l_num_msg_count: ' || l_num_msg_count);

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                l_chr_msg_data   := fnd_msg_pub.get (j, 'F');
                l_chr_msg_data   := REPLACE (l_chr_msg_data, CHR (0), ' ');
                fnd_file.put_line (fnd_file.LOG,
                                   'l_chr_msg_data : ' || l_chr_msg_data);
            END LOOP;

            p_out_chr_errbuf    := l_chr_msg_data;
            p_out_chr_retcode   := '2';
        ELSE
            p_out_chr_errbuf    := l_chr_msg_data;
            p_out_chr_retcode   := '0';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Packing into Container was successful with status : '
                || l_chr_retcode);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at pack into container procedure : '
                || p_out_chr_errbuf);
    END pack_into_container;

    -- ***************************************************************************
    -- Procedure Name      :  process_delivery_freight
    --
    -- Description         :  This procedure is add the freight charges
    --
    -- Parameters          :
    --                                p_out_chr_errbuf         OUT : Error Message
    --                                p_out_chr_retcode        OUT : Execution status
    --                                p_in_num_header_id            IN : Order Header Id
    --                                p_in_num_delivery_id          IN : Delivery Id
    --                                p_in_num_freight_charge       IN : Freight Charge
    --                                p_in_num_delivery_detail_id   IN : Delivery Detail id
    --                                p_in_chr_carrier              IN : Carrier
    --                                p_in_chr_warehouse        IN     : Warehouse code
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE process_delivery_freight (
        p_out_chr_errbuf                 OUT VARCHAR2,
        p_out_chr_retcode                OUT VARCHAR2,
        p_in_num_header_id            IN     NUMBER,
        p_in_num_delivery_id          IN     NUMBER,
        p_in_num_freight_charge       IN     NUMBER,
        p_in_num_delivery_detail_id   IN     NUMBER,
        p_in_chr_carrier              IN     VARCHAR2,
        p_in_chr_warehouse            IN     VARCHAR2)
    IS
        l_chr_cust_flag          VARCHAR2 (1);
        l_chr_order_type_flag    VARCHAR2 (1);
        l_chr_carrier            VARCHAR2 (1) := 'Y';
        l_freight_rec            wsh_freight_costs_pub.pubfreightcostrectype;
        l_chr_currency_code      VARCHAR2 (10);
        l_chr_retstat            VARCHAR2 (1);
        l_num_msgcount           NUMBER;
        l_chr_msgdata            VARCHAR2 (2000);
        l_chr_message            VARCHAR2 (2000);
        l_chr_message1           VARCHAR2 (2000);
        ln_freight_overide_cnt   NUMBER;
    BEGIN
        p_out_chr_errbuf                  := NULL;
        p_out_chr_retcode                 := '0';

        /* 5/6/2016 changed carrier flag logic to shipmethod level */
        BEGIN
            SELECT wcs.attribute3
              INTO l_chr_carrier
              FROM apps.WSH_CARRIER_SERVICES wcs, wsh_carriers wc, wsh_deliverY_details wdd,
                   oe_order_lines_all ool
             WHERE     wc.carrier_id = wcs.carrier_id
                   AND wc.freight_code = p_in_chr_carrier
                   AND wcs.ship_method_code = ool.shipping_method_code
                   AND wdd.deliverY_detail_id = p_in_num_delivery_detail_id
                   AND ool.line_id = wdd.source_line_id
                   AND ROWNUM = 1;
        /*
                 SELECT TRIM (attribute1)
                   INTO l_chr_carrier
                   FROM org_freight f, org_organization_definitions o
                  WHERE     o.organization_id = f.organization_id
                        AND freight_code = p_in_chr_carrier
                        AND o.organization_code = p_in_chr_warehouse;        -- 'VNT';
        */
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_chr_carrier   := 'Y';
        END;

        BEGIN
            SELECT NVL (SUBSTR (rc.attribute6, 1, 1), 'N')
              INTO l_chr_cust_flag
              FROM ra_customers rc, oe_order_headers_all oh
             WHERE     rc.customer_id = oh.sold_to_org_id
                   AND oh.header_id = p_in_num_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_chr_cust_flag   := 'N';
        END;

        BEGIN
            SELECT NVL (ott.attribute4, 'N')
              INTO l_chr_order_type_flag
              FROM oe_transaction_types_all ott, oe_order_headers_all oh
             WHERE     ott.transaction_type_id = oh.order_type_id
                   AND oh.header_id = p_in_num_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_chr_order_type_flag   := 'N';
        END;

        /*CCR0007100 - Restict Freight Application when there is already a surchare applied*/

        SELECT COUNT (opa.header_id)
          INTO ln_freight_overide_cnt
          FROM apps.fnd_lookup_values flv, apps.oe_price_adjustments_v opa
         WHERE     flv.lookup_type = 'XXD_ONT_FREIGHT_MOD_EXCLUSION'
               AND flv.language = 'US'
               AND flv.enabled_flag = 'Y'
               AND flv.attribute1 = opa.list_header_id
               AND opa.header_id = p_in_num_header_id
               AND opa.operand <> 0
               AND opa.adjustment_type_code = 'FREIGHT_CHARGE'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (flv.start_date_active)
                                       AND TRUNC (
                                               NVL (flv.end_date_active,
                                                    SYSDATE));

        fnd_file.put_line (
            fnd_file.LOG,
            'Zero Freight - Customer Flag : ' || l_chr_cust_flag);
        fnd_file.put_line (
            fnd_file.LOG,
            'Zero Freight - Order Type Flag : ' || l_chr_order_type_flag);
        fnd_file.put_line (fnd_file.LOG,
                           'Zero Freight - Carrier Flag : ' || l_chr_carrier);
        fnd_file.put_line (
            fnd_file.LOG,
            'Freight Charge from WMS : ' || p_in_num_freight_charge);

        IF    l_chr_cust_flag = 'Y'
           OR l_chr_order_type_flag = 'Y'
           OR l_chr_carrier = 'N'
           OR p_in_num_freight_charge = 0
           OR ln_freight_overide_cnt <> 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Freight cost is not applied since the delivery is exempted');
            p_out_chr_retcode   := '0';
            RETURN;
        END IF;

        BEGIN
            SELECT currency_code
              INTO l_chr_currency_code
              FROM oe_order_headers_all ooha, qp_list_headers_all qlh
             WHERE     ooha.price_list_id = qlh.list_header_id
                   AND ooha.header_id = p_in_num_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                l_chr_currency_code   := 'USD';
        END;

        l_freight_rec.currency_code       := l_chr_currency_code; -- bsk needs to be derived
        l_freight_rec.action_code         := 'CREATE';
        l_freight_rec.delivery_id         := p_in_num_delivery_id;
        l_freight_rec.unit_amount         := p_in_num_freight_charge;
        l_freight_rec.attribute1          :=
            TO_CHAR (p_in_num_delivery_detail_id);
        --    l_freight_rec.delivery_detail_id := p_in_num_delivery_detail_id;
        --l_freight_rec.freight_cost_type_id := 1;
        l_freight_rec.freight_cost_type   := 'Shipping';

        UPDATE oe_order_lines_all
           SET calculate_price_flag   = 'Y'
         WHERE line_id IN
                   (SELECT source_line_id
                      FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                     WHERE     wda.delivery_id = p_in_num_delivery_id
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.container_flag = 'N');

        apps.wsh_freight_costs_pub.create_update_freight_costs (
            p_api_version_number   => 1.0,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => fnd_api.g_false,
            x_return_status        => l_chr_retstat,
            x_msg_count            => l_num_msgcount,
            x_msg_data             => l_chr_msgdata,
            p_pub_freight_costs    => l_freight_rec,
            p_action_code          => 'CREATE',
            x_freight_cost_id      => l_freight_rec.freight_cost_type_id);

        IF l_chr_retstat <> 'S'
        THEN
            FOR i IN 1 .. l_num_msgcount
            LOOP
                l_chr_message   := fnd_msg_pub.get (i, 'F');
                l_chr_message   := REPLACE (l_chr_message, CHR (0), ' ');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error during freight addition:  ' || l_chr_message);
            END LOOP;

            fnd_msg_pub.delete_msg ();
            p_out_chr_errbuf    := l_chr_message;
            p_out_chr_retcode   := '2';
        ELSE
            p_out_chr_retcode   := '0';
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
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at process delivery freight procedure : '
                || p_out_chr_errbuf);
    END process_delivery_freight;

    -- ***************************************************************************
    -- Procedure Name      :  process_container_tracking
    --
    -- Description         :  This procedure is to update the tracking number and weight on the delivery detail
    --
    -- Parameters          :
    --                            p_out_chr_errbuf         OUT : Error Message
    --                            p_out_chr_retcode        OUT : Execution status
    --                            p_in_num_delivery_detail_id   IN : Delivery Detail Id
    --                            p_in_chr_tracking_number      IN : Tracking Number
    --                            p_in_num_container_weight     IN : Container Weight
    --                            p_in_chr_carrier              IN : Carrier
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE process_container_tracking (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_detail_id IN NUMBER
                                          , p_in_chr_tracking_number IN VARCHAR2, p_in_num_container_weight IN NUMBER, p_in_chr_carrier IN VARCHAR2)
    IS
    BEGIN
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        fnd_file.put_line (
            fnd_file.LOG,
               'delivery_detail_id at process container tracking procedure = '
            || TO_CHAR (p_in_num_delivery_detail_id));

        UPDATE wsh_delivery_details
           SET tracking_number = TRIM (p_in_chr_tracking_number), net_weight = p_in_num_container_weight
         WHERE delivery_detail_id = p_in_num_delivery_detail_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at process container tracking procedure : '
                || p_out_chr_errbuf);
    END process_container_tracking;

    -- ***************************************************************************
    -- Procedure Name      :  create_container
    --
    -- Description         :  This procedure is to create the container for each carton
    --
    -- Parameters          :
    --                            p_out_chr_errbuf         OUT : Error Message
    --                            p_out_chr_retcode        OUT : Execution status
    --                            p_in_num_delivery_id          IN  : Delivery Id
    --                            p_in_num_container_item_id    IN  : Container Item Id
    --                            p_in_chr_container_name       IN  :,Container name - LPN
    --                            p_in_num_organization_id      IN  : Inventory Org Id
    --                            p_out_num_container_inst_id   OUT : Container Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE create_container (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_id IN NUMBER, p_in_num_container_item_id IN NUMBER, p_in_chr_container_name IN VARCHAR2, p_in_num_organization_id IN NUMBER
                                , p_out_num_container_inst_id OUT NUMBER)
    IS
        l_containers_tab      wsh_util_core.id_tab_type;
        l_num_msg_count       NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_num_api_version     NUMBER := 1.0;
        l_segs_array          fnd_flex_ext.segmentarray;
        l_chr_return_status   VARCHAR2 (1);
    BEGIN
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        fnd_msg_pub.initialize;
        wsh_container_pub.create_containers (
            p_api_version           => l_num_api_version,
            p_init_msg_list         => fnd_api.g_true,
            p_commit                => fnd_api.g_false,
            p_validation_level      => fnd_api.g_valid_level_full,
            x_return_status         => l_chr_return_status,
            x_msg_count             => l_num_msg_count,
            x_msg_data              => l_chr_msg_data,
            p_container_item_id     => g_num_container_item_id,
            p_container_item_name   => NULL,
            p_container_item_seg    => l_segs_array,
            p_organization_id       => p_in_num_organization_id,
            p_organization_code     => NULL,
            p_name_prefix           => NULL,
            p_name_suffix           => NULL,
            p_base_number           => NULL,
            p_num_digits            => NULL,
            p_quantity              => 1,
            p_container_name        => p_in_chr_container_name,
            x_container_ids         => l_containers_tab);
        fnd_file.put_line (fnd_file.LOG,
                           'Return Status: ' || l_chr_return_status);
        fnd_file.put_line (fnd_file.LOG,
                           'Message Count: ' || l_num_msg_count);
        fnd_file.put_line (fnd_file.LOG,
                           'Error Message Data: ' || l_chr_msg_data);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                l_chr_msg_data   := fnd_msg_pub.get (j, 'F');
                l_chr_msg_data   := REPLACE (l_chr_msg_data, CHR (0), ' ');
                fnd_file.put_line (fnd_file.LOG, l_chr_msg_data);
            END LOOP;

            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                'Error while creating container: ' || l_chr_msg_data;
            RETURN;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Container count:' || l_containers_tab.COUNT);

        -- Updating the attributes of each container
        FOR i IN 1 .. l_containers_tab.COUNT
        LOOP
            p_out_num_container_inst_id   := l_containers_tab (i);
            fnd_file.put_line (fnd_file.LOG,
                               'Container id:' || l_containers_tab (i));
            fnd_msg_pub.initialize;
            wsh_container_actions.update_cont_attributes (
                NULL,
                p_in_num_delivery_id,
                l_containers_tab (i),
                l_chr_return_status);
            fnd_file.put_line (
                fnd_file.LOG,
                'update attributes ret_stat: ' || l_chr_return_status);

            IF l_chr_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR j IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    l_chr_msg_data   := fnd_msg_pub.get (j, 'F');
                    l_chr_msg_data   :=
                        REPLACE (l_chr_msg_data, CHR (0), ' ');
                    fnd_file.put_line (fnd_file.LOG, l_chr_msg_data);
                END LOOP;

                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'Error while updating the attributes of container: '
                    || l_chr_msg_data;
                RETURN;
            END IF;

            fnd_msg_pub.initialize;
            wsh_container_actions.assign_to_delivery (l_containers_tab (i),
                                                      p_in_num_delivery_id,
                                                      l_chr_return_status);
            fnd_file.put_line (
                fnd_file.LOG,
                'assign to delivery ret_stat: ' || l_chr_return_status);

            IF l_chr_return_status <> fnd_api.g_ret_sts_success
            THEN
                FOR j IN 1 .. fnd_msg_pub.count_msg
                LOOP
                    l_chr_msg_data   := fnd_msg_pub.get (j, 'F');
                    l_chr_msg_data   :=
                        REPLACE (l_chr_msg_data, CHR (0), ' ');
                    fnd_file.put_line (fnd_file.LOG, l_chr_msg_data);
                END LOOP;

                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'Error while assigning container to delivery: '
                    || l_chr_msg_data;
                RETURN;
            ELSE
                /* CONTAINER_BUG Start */


                UPDATE wsh_delivery_Details
                   SET source_header_id   =
                           (SELECT source_header_id
                              FROM wsh_new_deliveries
                             WHERE delivery_id = p_in_num_delivery_id)
                 WHERE delivery_detail_id = p_out_num_container_inst_id;
            /* CONTAINER_BUG End */

            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at create container procedure : '
                || p_out_chr_errbuf);
    END create_container;

    -- ***************************************************************************
    -- Function Name      :  get_requested_quantity
    --
    -- Description         :  This function is to get the requested quantity of the given delivery detail
    --
    -- Parameters          : p_in_num_delivery_detail_id  IN : Delivery Detail id
    --
    -- Return/Exit         :  Requested Quantity
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************


    FUNCTION get_requested_quantity (p_in_num_delivery_detail_id IN NUMBER)
        RETURN NUMBER
    IS
        l_num_requested_qty   NUMBER;
    BEGIN
        SELECT requested_quantity
          INTO l_num_requested_qty
          FROM wsh_delivery_details
         WHERE delivery_detail_id = p_in_num_delivery_detail_id;

        RETURN l_num_requested_qty;
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
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                            p_out_chr_errbuf         OUT : Error Message
    --                            p_out_chr_retcode        OUT : Execution status
    --                            p_in_num_header_id          IN : Order Header Id
    --                            p_in_num_delivery_id        IN : Delivery Id
    --                            p_in_chr_container_name     IN : Container name - LPN
    --                            p_in_shipments_tab          IN : Delivery details to be linked to Container
    --                            p_in_num_freight_cost       IN : Freight cost
    --                            p_in_num_container_weight   IN : Container Weight
    --                            p_in_chr_tracking_number    IN : Tracking Number
    --                            p_in_chr_carrier            IN : Carrier
    --                            p_in_dte_shipment_date      IN : Ship Date
    --                            p_in_num_org_id             IN : Inventory Org Id
    --                            p_in_chr_warehouse          IN  : Warehouse Code
    --                            p_out_num_container_id      OUT : Container Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE pack_container (
        p_out_chr_errbuf               OUT VARCHAR2,
        p_out_chr_retcode              OUT VARCHAR2,
        p_in_num_header_id          IN     NUMBER,
        p_in_num_delivery_id        IN     NUMBER,
        p_in_chr_container_name     IN     VARCHAR2,
        p_in_shipments_tab          IN     g_shipments_tab_type,
        p_in_num_freight_cost       IN     NUMBER,
        p_in_num_container_weight   IN     NUMBER,
        p_in_chr_tracking_number    IN     VARCHAR2,
        p_in_chr_carrier            IN     VARCHAR2,
        p_in_dte_shipment_date      IN     DATE,
        p_in_num_org_id             IN     NUMBER,
        p_in_chr_warehouse          IN     VARCHAR2,
        p_out_num_container_id         OUT NUMBER)
    IS
        l_chr_errbuf                  VARCHAR2 (2000);
        l_chr_retcode                 VARCHAR2 (30);
        l_chr_return_status           VARCHAR2 (1);
        l_num_container_id            NUMBER;
        l_delivery_ids_tab            wsh_util_core.id_tab_type;
        l_row_ids_tab                 wsh_util_core.id_tab_type;
        create_container_failure      EXCEPTION;
        split_shipments_failure       EXCEPTION;
        pack_into_container_failure   EXCEPTION;
        process_freight_failure       EXCEPTION;
        process_tracking_failure      EXCEPTION;
    BEGIN
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;

        wsh_delivery_autocreate.autocreate_deliveries (
            p_line_rows           => l_row_ids_tab,
            p_init_flag           => 'N',
            p_pick_release_flag   => 'N',
            p_container_flag      => 'Y',
            p_check_flag          => 'Y',
            p_max_detail_commit   => 1000,
            x_del_rows            => l_row_ids_tab,
            x_grouping_rows       => l_row_ids_tab,
            x_return_status       => l_chr_return_status);

        create_container (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_num_delivery_id => p_in_num_delivery_id, p_in_num_container_item_id => g_num_container_item_id, p_in_chr_container_name => p_in_chr_container_name, p_in_num_organization_id => p_in_num_org_id
                          , p_out_num_container_inst_id => l_num_container_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Create Container Ret Stat: ' || l_chr_retcode);

        IF l_chr_retcode <> '0'
        THEN
            p_out_chr_errbuf   := l_chr_errbuf;
            RAISE create_container_failure;
        END IF;

        /*

        split_shipments (p_out_chr_errbuf => l_chr_errbuf,
                                              p_out_chr_retcode => l_chr_retcode,
                                              p_in_shipments_tab => p_in_shipments_tab,
                                              p_in_chr_carrier => p_in_chr_carrier,
                                              p_in_chr_tracking_no => p_in_chr_tracking_number,
                                              p_in_dte_shipment_date =>p_in_dte_shipment_date ,
                                              p_out_delivery_ids_tab => l_delivery_ids_tab
                                              );

        FND_FILE.PUT_LINE (FND_FILE.LOG,'Split Shipments Ret Stat: ' || l_chr_return_status);
        if l_chr_retcode <> '0' then
          p_out_chr_errbuf := l_chr_errbuf;
          raise split_shipments_failure;
        end if;
        FND_FILE.PUT_LINE (FND_FILE.LOG,'Delivery_id :' || p_in_num_delivery_id || ' container_id: ' || l_num_container_id || ' count of l_delivery_ids_tab: ' || l_delivery_ids_tab.count);
        for i in 1..l_delivery_ids_tab.count loop
          FND_FILE.PUT_LINE (FND_FILE.LOG,'     Delivery_id to be packed: ' || l_delivery_ids_tab(i));
        end loop;
      */


        FOR l_num_del_dtl_ind IN 1 .. p_in_shipments_tab.COUNT
        LOOP
            l_delivery_ids_tab (l_num_del_dtl_ind)   :=
                p_in_shipments_tab (l_num_del_dtl_ind).delivery_detail_id;
        END LOOP;

        pack_into_container (p_out_chr_errbuf        => l_chr_errbuf,
                             p_out_chr_retcode       => l_chr_retcode,
                             p_in_num_delivery_id    => p_in_num_delivery_id,
                             p_in_num_container_id   => l_num_container_id,
                             p_in_delivery_ids_tab   => l_delivery_ids_tab);
        fnd_file.put_line (fnd_file.LOG,
                           'Pack into container Ret Stat: ' || l_chr_retcode);

        IF l_chr_retcode <> '0'
        THEN
            p_out_chr_errbuf   := l_chr_errbuf;
            RAISE pack_into_container_failure;
        END IF;


        process_delivery_freight (
            p_out_chr_errbuf              => l_chr_errbuf,
            p_out_chr_retcode             => l_chr_retcode,
            p_in_num_header_id            => p_in_num_header_id,
            p_in_num_delivery_id          => p_in_num_delivery_id,
            p_in_num_freight_charge       => p_in_num_freight_cost,
            p_in_num_delivery_detail_id   => l_delivery_ids_tab (1),
            p_in_chr_carrier              => p_in_chr_carrier,
            p_in_chr_warehouse            => p_in_chr_warehouse);
        fnd_file.put_line (
            fnd_file.LOG,
            'process_delivery_freight Ret Stat: ' || l_chr_retcode);

        IF l_chr_retcode <> '0'
        THEN
            p_out_chr_errbuf   := l_chr_errbuf;
            RAISE process_freight_failure;
        END IF;

        FOR l_num_ind IN 1 .. l_delivery_ids_tab.COUNT
        LOOP
            process_container_tracking (
                p_out_chr_errbuf              => l_chr_errbuf,
                p_out_chr_retcode             => l_chr_retcode,
                p_in_num_delivery_detail_id   =>
                    l_delivery_ids_tab (l_num_ind),
                p_in_chr_tracking_number      => p_in_chr_tracking_number,
                p_in_num_container_weight     => p_in_num_container_weight,
                p_in_chr_carrier              => p_in_chr_carrier);
            fnd_file.put_line (
                fnd_file.LOG,
                'process_container_tracking Ret Stat: ' || l_chr_retcode);
        END LOOP;

        /* Start Update tracking number for carton  TRACKING_NUMBER*/
        BEGIN
            UPDATE wsh_deliverY_details
               SET tracking_number   = TRIM (p_in_chr_tracking_number)
             WHERE     delivery_detail_id = l_num_container_id
                   AND source_code = 'WSH';
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while updating tracking number to carton');
        END;

        /* ENDs Update tracking number for carton TRACKING_NUMBER*/

        IF l_chr_retcode <> '0'
        THEN
            p_out_chr_errbuf   := l_chr_errbuf;
            RAISE process_tracking_failure;
        END IF;

        p_out_chr_retcode   := '0';
    EXCEPTION
        WHEN create_container_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN split_shipments_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN pack_into_container_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN process_freight_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN process_tracking_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at package container procedure : '
                || p_out_chr_errbuf);
    END pack_container;

    -- ***************************************************************************
    -- Procedure Name      :  assign_del_to_trip
    --
    -- Description         :  This procedure is to assign the delivery to the trip
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                             p_in_num_trip_id       IN  : Trip id
    --                             p_in_num_delivery_id   IN  : Delivery Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE assign_del_to_trip (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_trip_id IN NUMBER
                                  , p_in_num_delivery_id IN NUMBER)
    IS
        l_chr_return_status   VARCHAR2 (30) := NULL;
        l_num_msg_count       NUMBER;
        l_num_msg_cntr        NUMBER;
        l_num_msg_index_out   NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_num_trip_id         NUMBER;
        l_chr_trip_name       VARCHAR2 (240);
    BEGIN
        --Reset status variables
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        -- Assign new delivery created to the specified trip id
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (
            fnd_file.LOG,
               'Start Calling delivery action api to assign delivery '
            || p_in_num_delivery_id
            || ' to trip '
            || p_in_num_trip_id);
        -- Call delivery_action api
        wsh_deliveries_pub.delivery_action (p_api_version_number => g_num_api_version, p_init_msg_list => fnd_api.g_true, x_return_status => l_chr_return_status, x_msg_count => l_num_msg_count, x_msg_data => l_chr_msg_data, p_action_code => 'ASSIGN-TRIP', p_delivery_id => p_in_num_delivery_id, p_asg_trip_id => p_in_num_trip_id, x_trip_id => l_num_trip_id
                                            , x_trip_name => l_chr_trip_name);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'API to assign delivery to trip failed with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            IF l_num_msg_count > 0
            THEN
                -- Retrieve messages
                l_num_msg_cntr   := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message:' || l_chr_msg_data);
                END LOOP;
            END IF;

            p_out_chr_errbuf    := l_chr_msg_data;
        ELSE
            p_out_chr_retcode   := '0';
            p_out_chr_errbuf    :=
                   'API to assign delivery to trip was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            fnd_file.put_line (fnd_file.LOG,
                               'Trip Id from API : ' || l_num_trip_id);
            fnd_file.put_line (fnd_file.LOG,
                               'Trip Name from API : ' || l_chr_trip_name);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                'Error while creating delivery.' || SQLERRM;
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
    -- Function Name      :  get_sku
    --
    -- Description         :  This function is to get the item number for the given inventory item id
    --
    -- Parameters          : p_in_num_inventory_item_id  IN : Inventory item Id
    --
    -- Return/Exit         :  Item Number
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************
    /*************************Commented for BT Remediation***************************
       FUNCTION get_sku (p_in_num_inventory_item_id IN NUMBER)
          RETURN VARCHAR2
       IS
          l_chr_sku   VARCHAR2 (50);
       BEGIN
          SELECT segment1 || '-' || segment2 || '-' || segment3
            INTO l_chr_sku
            FROM mtl_system_items_b
           WHERE organization_id = 7
             AND inventory_item_id = p_in_num_inventory_item_id;

          RETURN l_chr_sku;
       EXCEPTION
          WHEN OTHERS
          THEN
             RETURN NULL;
       END get_sku;
    */
    -- ***************************************************************************
    -- Procedure/Function Name  :  upload_xml
    --
    -- Description              :  The purpose of this procedure is to load the xml file into the database
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                   p_in_chr_inbound_directory IN : Input file directory
    --                                  p_in_chr_file_name IN : Input Xml file name
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- ***************************************************************************


    PROCEDURE upload_xml (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_inbound_directory VARCHAR2
                          , p_in_chr_file_name VARCHAR2)
    AS
        l_bfi_file_location   BFILE;
        l_num_amount          INTEGER := DBMS_LOB.lobmaxsize;
        l_clo_xml_doc         CLOB;
        l_num_warning         NUMBER;
        l_num_lang_ctx        NUMBER := DBMS_LOB.default_lang_ctx;
        l_num_src_off         NUMBER := 1;
        l_num_dest_off        NUMBER := 1;
        l_xml_doc             XMLTYPE;
        l_chr_errbuf          VARCHAR2 (2000);
        l_chr_retcode         VARCHAR2 (30);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Directory Name: ' || p_in_chr_inbound_directory);
        fnd_file.put_line (fnd_file.LOG, 'File Name: ' || p_in_chr_file_name);
        -- Reading the OS Location for XML Files
        l_bfi_file_location   :=
            BFILENAME (p_in_chr_inbound_directory, p_in_chr_file_name);
        DBMS_LOB.createtemporary (l_clo_xml_doc, FALSE);
        DBMS_LOB.OPEN (l_bfi_file_location, DBMS_LOB.lob_readonly);
        fnd_file.put_line (fnd_file.LOG, 'Loading the file into CLOB');
        DBMS_LOB.loadclobfromfile (l_clo_xml_doc, l_bfi_file_location, l_num_amount, l_num_src_off, l_num_dest_off, DBMS_LOB.default_csid
                                   , l_num_lang_ctx, l_num_warning);
        DBMS_LOB.CLOSE (l_bfi_file_location);
        fnd_file.put_line (fnd_file.LOG, 'converting the data into XML type');
        l_xml_doc   := XMLTYPE (l_clo_xml_doc);
        DBMS_LOB.freetemporary (l_clo_xml_doc);

        BEGIN
            -- Insert statement to upload the XML files

            INSERT INTO xxdo_ont_ship_conf_xml_stg (process_status,
                                                    xml_document,
                                                    file_name,
                                                    request_id,
                                                    created_by,
                                                    creation_date,
                                                    last_updated_by,
                                                    last_update_date)
                 VALUES ('NEW', l_xml_doc, p_in_chr_file_name,
                         fnd_global.conc_request_id, fnd_global.user_id, SYSDATE
                         , fnd_global.user_id, SYSDATE);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                       'Error while Inserting XML file into XML Staging table'
                    || SQLERRM;
                p_out_chr_retcode   := '2';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;

        COMMIT;

        BEGIN
            extract_xml_data (p_out_chr_errbuf      => l_chr_errbuf,
                              p_out_chr_retcode     => l_chr_retcode,
                              p_in_num_bulk_limit   => 1000);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'XML data is not loaded into database due to :'
                    || SQLERRM);
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    := SQLERRM;
        END;

        IF l_chr_retcode <> '0'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'XML data is not loaded into database due to :'
                || l_chr_errbuf);
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := l_chr_errbuf;
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'XML data is loaded into database');
            p_out_chr_retcode   := '0';
            p_out_chr_errbuf    := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'Unexpected error while loading the XML into database : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while loading the XML into database.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
    END upload_xml;

    -- ***************************************************************************
    -- Procedure/Function Name  :  extract_xml_data
    --
    -- Description              :  The purpose of this procedure is to parse the xml file and load the data into staging tables
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                  p_in_num_bulk_limit IN : Bulk Limit
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0   Initial Version
    -- 18-Jan-18     Krishna L          1.1   CCR0006947 - Seal, Trailer and BOL changes
    -- ***************************************************************************

    PROCEDURE extract_xml_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER)
    IS
        l_num_request_id           NUMBER := fnd_global.conc_request_id;
        l_num_user_id              NUMBER := fnd_global.user_id;

        CURSOR cur_xml_file_counts IS
            SELECT ROWID row_id, file_name
              FROM xxdo_ont_ship_conf_xml_stg
             WHERE process_status = 'NEW';

        CURSOR cur_shipment_headers IS
                         SELECT wh_id, shipment_number, master_load_ref,
                                customer_load_id, carrier, service_level,
                                pro_number, comments, TO_DATE (ship_date, 'YYYY-MM-DD HH24:MI:SS'),
                                seal_number, trailer_number, employee_id,
                                employee_name, 'NEW' process_status, NULL error_message,
                                l_num_request_id request_id, SYSDATE creation_date, l_num_user_id created_by,
                                SYSDATE last_update_date, l_num_user_id last_updated_by, 'ORDER' source_type,
                                NULL attribute1, NULL attribute2, NULL attribute3,
                                NULL attribute4, NULL attribute5, NULL attribute6,
                                NULL attribute7, NULL attribute8, NULL attribute9,
                                NULL attribute10, NULL attribute11, NULL attribute12,
                                NULL attribute13, NULL attribute14, NULL attribute15,
                                NULL attribute16, NULL attribute17, NULL attribute18,
                                NULL attribute19, NULL attribute20, 'WMS' SOURCE,
                                'EBS' destination, 'INSERT' record_type, bol_number /* Added for CCR0006947 */
                           FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                XMLTABLE (
                                    xmlnamespaces (DEFAULT 'http://www.example.org'), --Added for change 2.16
                                    'OutboundShipmentsMessage/Shipments/Shipment'
                                    PASSING xml_tab.xml_document
                                    COLUMNS Wh_Id               VARCHAR2 (2000) PATH 'wh_id', Shipment_Number     VARCHAR2 (2000) PATH 'shipment_number', Master_Load_Ref     VARCHAR2 (2000) PATH 'master_load_ref',
                                            Customer_Load_Id    VARCHAR2 (2000) PATH 'customer_load_id', Carrier             VARCHAR2 (2000) PATH 'carrier', Service_Level       VARCHAR2 (2000) PATH 'service_level',
                                            Pro_Number          VARCHAR2 (2000) PATH 'pro_number', Comments            VARCHAR2 (2000) PATH 'comments', Ship_Date           VARCHAR2 (2000) PATH 'ship_date',
                                            Seal_Number         VARCHAR2 (2000) PATH 'seal_number', Trailer_Number      VARCHAR2 (2000) PATH 'trailer_number', Bol_Number          VARCHAR2 (2000) PATH 'bol_number', /* Added for CCR0006947 */
                                            Employee_Id         VARCHAR2 (2000) PATH 'employee_id', Employee_Name       VARCHAR2 (2000) PATH 'employee_name')
                          WHERE process_status = 'NEW';

        TYPE shipconf_headers_tab_type
            IS TABLE OF xxdo_ont_ship_conf_head_stg%ROWTYPE;

        l_shipconf_headers_tab     shipconf_headers_tab_type;

        CURSOR cur_deliveries IS
                             SELECT wh_id, shipment_number, order_number,
                                    ship_to_name, ship_to_attention, ship_to_addr1,
                                    ship_to_addr2, ship_to_addr3, ship_to_city,
                                    ship_to_state, ship_to_zip, ship_to_country_code,
                                    'NEW' process_status, NULL error_message, l_num_request_id request_id,
                                    SYSDATE creation_date, l_num_user_id created_by, SYSDATE last_update_date,
                                    l_num_user_id last_updated_by, 'ORDER' source_type, NULL attribute1,
                                    NULL attribute2, NULL attribute3, NULL attribute4,
                                    NULL attribute5, NULL attribute6, NULL attribute7,
                                    NULL attribute8, NULL attribute9, NULL attribute10,
                                    NULL attribute11, NULL attribute12, NULL attribute13,
                                    NULL attribute14, NULL attribute15, NULL attribute16,
                                    NULL attribute17, NULL attribute18, NULL attribute19,
                                    NULL attribute20, 'WMS' SOURCE, 'EBS' destination,
                                    'INSERT' record_type, 'NOT VERIFIED' address_verified, NULL order_header_id,
                                    NULL delivery_id, NULL ship_to_org_id, NULL ship_to_location_id
                               FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                    XMLTABLE (
                                        xmlnamespaces (DEFAULT 'http://www.example.org'), --Added for change 2.16
                                        'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder'
                                        PASSING xml_tab.xml_document
                                        COLUMNS Wh_Id                   VARCHAR2 (2000) PATH 'wh_id', Shipment_Number         VARCHAR2 (2000) PATH 'shipment_number', Order_Number            VARCHAR2 (2000) PATH 'order_number',
                                                Ship_To_Name            VARCHAR2 (2000) PATH 'ship_to_name', Ship_To_Attention       VARCHAR2 (2000) PATH 'ship_to_attention', Ship_To_Addr1           VARCHAR2 (2000) PATH 'ship_to_addr1',
                                                Ship_To_Addr2           VARCHAR2 (2000) PATH 'ship_to_addr2', Ship_To_Addr3           VARCHAR2 (2000) PATH 'ship_to_addr3', Ship_To_City            VARCHAR2 (2000) PATH 'ship_to_city',
                                                Ship_To_State           VARCHAR2 (2000) PATH 'ship_to_state', Ship_To_Zip             VARCHAR2 (2000) PATH 'ship_to_zip', Ship_To_Country_Code    VARCHAR2 (2000) PATH 'ship_to_country_code')
                              WHERE process_status = 'NEW';

        TYPE shipconf_orders_tab_type
            IS TABLE OF xxdo_ont_ship_conf_order_stg%ROWTYPE;

        l_shipconf_orders_tab      shipconf_orders_tab_type;

        CURSOR cur_cartons IS
                        SELECT wh_id, shipment_number, order_number,
                               carton_number, tracking_number, freight_list,
                               freight_actual, weight, LENGTH,
                               width, height, 'NEW' process_status,
                               NULL error_message, l_num_request_id request_id, SYSDATE creation_date,
                               l_num_user_id created_by, SYSDATE last_update_date, l_num_user_id last_updated_by,
                               'ORDER' source_type, NULL attribute1, NULL attribute2,
                               NULL attribute3, NULL attribute4, NULL attribute5,
                               NULL attribute6, NULL attribute7, NULL attribute8,
                               NULL attribute9, NULL attribute10, NULL attribute11,
                               NULL attribute12, NULL attribute13, NULL attribute14,
                               NULL attribute15, NULL attribute16, NULL attribute17,
                               NULL attribute18, NULL attribute19, NULL attribute20,
                               'WMS' SOURCE, 'EBS' destination, 'INSERT' record_type,
                               freight_charged           /* FREIGHT_CHARGED */
                          FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                               XMLTABLE (
                                   xmlnamespaces (DEFAULT 'http://www.example.org'), --Added for change 2.16
                                   'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder/OutboundOrderCartons/OutboundOrderCarton'
                                   PASSING xml_tab.xml_document
                                   COLUMNS Wh_Id              VARCHAR2 (2000) PATH 'wh_id', Shipment_Number    VARCHAR2 (2000) PATH 'shipment_number', Order_Number       VARCHAR2 (2000) PATH 'order_number',
                                           Carton_Number      VARCHAR2 (2000) PATH 'carton_number', Tracking_Number    VARCHAR2 (2000) PATH 'tracking_number', Freight_List       VARCHAR2 (2000) PATH 'freight_list',
                                           Freight_Actual     VARCHAR2 (2000) PATH 'freight_actual', Freight_Charged    VARCHAR2 (2000) PATH 'freight_charged', /* FREIGHT_CHARGED */
                                                                                                                                                                Weight             VARCHAR2 (2000) PATH 'weight',
                                           LENGTH             VARCHAR2 (2000) PATH 'length', Width              VARCHAR2 (2000) PATH 'width', Height             VARCHAR2 (2000) PATH 'height')
                         WHERE process_status = 'NEW';

        TYPE cartons_tab_type
            IS TABLE OF xxdo_ont_ship_conf_carton_stg%ROWTYPE;

        l_cartons_tab              cartons_tab_type;

        CURSOR cur_order_lines IS
                          SELECT wh_id, shipment_number, order_number,
                                 carton_number, line_number, item_number,
                                 qty, uom, host_subinventory,
                                 'NEW' process_status, NULL error_message, l_num_request_id request_id,
                                 SYSDATE creation_date, l_num_user_id created_by, SYSDATE last_update_date,
                                 l_num_user_id last_updated_by, 'ORDER' source_type, NULL attribute1,
                                 NULL attribute2, NULL attribute3, NULL attribute4,
                                 NULL attribute5, NULL attribute6, NULL attribute7,
                                 NULL attribute8, NULL attribute9, NULL attribute10,
                                 NULL attribute11, NULL attribute12, NULL attribute13,
                                 NULL attribute14, NULL attribute15, NULL attribute16,
                                 NULL attribute17, NULL attribute18, NULL attribute19,
                                 NULL attribute20, 'WMS' SOURCE, 'EBS' destination,
                                 'INSERT' record_type
                            FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                                 XMLTABLE (
                                     xmlnamespaces (DEFAULT 'http://www.example.org'), --Added for change 2.16
                                     'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder/OutboundOrderCartons/OutboundOrderCarton/OutboundOrderCartonDetails/OutboundOrderCartonDetail'
                                     PASSING xml_tab.xml_document
                                     COLUMNS Wh_Id                VARCHAR2 (2000) PATH 'wh_id', Shipment_Number      VARCHAR2 (2000) PATH 'shipment_number', Order_Number         VARCHAR2 (2000) PATH 'order_number',
                                             Carton_Number        VARCHAR2 (2000) PATH 'carton_number', Line_Number          VARCHAR2 (2000) PATH 'line_number', Item_Number          VARCHAR2 (2000) PATH 'item_number',
                                             Qty                  VARCHAR2 (2000) PATH 'qty', UOM                  VARCHAR2 (2000) PATH 'uom', Host_Subinventory    VARCHAR2 (2000) PATH 'host_subinventory')
                           WHERE process_status = 'NEW';

        TYPE carton_dtls_tab_type
            IS TABLE OF xxdo_ont_ship_conf_cardtl_stg%ROWTYPE;

        l_carton_dtls_tab          carton_dtls_tab_type;

        CURSOR cur_serials IS
                        SELECT serials.wh_id, serials.shipment_number, serials.order_number,
                               serials.carton_number, serials.line_number, serials.serial_number,
                               serials.item_number, 'NEW' process_status, NULL error_message,
                               l_num_request_id request_id, SYSDATE creation_date, l_num_user_id created_by,
                               SYSDATE last_update_date, l_num_user_id last_updated_by, 'ORDER' source_type,
                               NULL attribute1, NULL attribute2, NULL attribute3,
                               NULL attribute4, NULL attribute5, NULL attribute6,
                               NULL attribute7, NULL attribute8, NULL attribute9,
                               NULL attribute10, NULL attribute11, NULL attribute12,
                               NULL attribute13, NULL attribute14, NULL attribute15,
                               NULL attribute16, NULL attribute17, NULL attribute18,
                               NULL attribute19, NULL attribute20, 'WMS' SOURCE,
                               'EBS' destination, 'INSERT' record_type
                          FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                               XMLTABLE (
                                   xmlnamespaces (DEFAULT 'http://www.example.org'), --Added for change 2.16
                                   'OutboundShipmentsMessage/Shipments/Shipment/OutboundOrders/OutboundOrder/OutboundOrderCartons/OutboundOrderCarton/OutboundOrderCartonDetails/OutboundOrderCartonDetail/OutboundOrderCartonDetailSerials/OutboundOrderCartonDetailSerial'
                                   PASSING xml_tab.xml_document
                                   COLUMNS Wh_Id              VARCHAR2 (2000) PATH 'wh_id', Shipment_Number    VARCHAR2 (2000) PATH 'shipment_number', Order_Number       VARCHAR2 (2000) PATH 'order_number',
                                           Carton_Number      VARCHAR2 (2000) PATH 'carton_number', Line_Number        VARCHAR2 (2000) PATH 'line_number', Item_Number        VARCHAR2 (2000) PATH 'item_number',
                                           Serial_Number      VARCHAR2 (2000) PATH 'serial_number')
                               serials
                         WHERE process_status = 'NEW';

        TYPE carton_sers_tab_type
            IS TABLE OF xxdo_ont_ship_conf_carser_stg%ROWTYPE;

        l_carton_sers_tab          carton_sers_tab_type;
        l_chr_xml_message_type     VARCHAR2 (30);
        l_chr_xml_environment      VARCHAR2 (30);
        l_chr_environment          VARCHAR2 (30);
        l_num_error_count          NUMBER := 0;
        l_exe_env_no_match         EXCEPTION;
        l_exe_msg_type_no_match    EXCEPTION;
        l_exe_bulk_fetch_failed    EXCEPTION;
        l_exe_bulk_insert_failed   EXCEPTION;
        l_exe_dml_errors           EXCEPTION;
        PRAGMA EXCEPTION_INIT (l_exe_dml_errors, -24381);
    BEGIN
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        fnd_file.put_line (fnd_file.LOG,
                           'Starting the XML Specific validations');

        /*
              -- Get the instance name from DBA view
              BEGIN
                 SELECT NAME
                   INTO l_chr_environment
                   FROM v$database;
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    l_chr_environment := '-1';
              END;

              fnd_file.put_line (fnd_file.LOG,
                                 'Current Database name : ' || l_chr_environment
                                );

        */

        -- Get the message type and environment details from XML
        BEGIN
                     /* --Commented for change 2.16 (below as the new XML file will have name spaces and below select stmt won't handle it)
                     SELECT stg.xml_document.EXTRACT (
                               '//OutboundShipmentsMessage/MessageHeader/MessageType/text()').getstringval (),
                            stg.xml_document.EXTRACT (
                               '//OutboundShipmentsMessage/MessageHeader/Environment/text()').getstringval ()
                       INTO l_chr_xml_message_type, l_chr_xml_environment
                       FROM xxdo_ont_ship_conf_xml_stg stg
                      WHERE stg.process_status = 'NEW';
                     */
                     --Added for change 2.16 for handling namespaces in XML file
                     SELECT xml_ext.MESSAGE_TYPE, xml_ext.environment
                       INTO l_chr_xml_message_type, l_chr_xml_environment
                       FROM xxdo_ont_ship_conf_xml_stg xml_tab,
                            (XMLTABLE (
                                 xmlnamespaces (DEFAULT 'http://www.example.org'),
                                 '/OutboundShipmentsMessage/MessageHeader'
                                 PASSING xml_tab.xml_document
                                 COLUMNS MESSAGE_TYPE    NUMBER PATH 'MessageType', Environment     VARCHAR2 (2000) PATH 'Environment'))
                            xml_ext
                      WHERE 1 = 1 AND process_status = 'NEW';
        EXCEPTION
            WHEN OTHERS
            THEN
                l_chr_xml_message_type   := '-1';
                l_chr_xml_environment    := '-1';
        END;

        /*
              fnd_file.put_line (fnd_file.LOG,
                                 'Database name in XML: ' || l_chr_xml_environment
                                );
        */
        fnd_file.put_line (fnd_file.LOG,
                           'Message type in XML: ' || l_chr_xml_message_type);

        /*
              IF l_chr_environment <> l_chr_xml_environment
              THEN
                 RAISE l_exe_env_no_match;
              END IF;


              fnd_file.put_line (fnd_file.LOG, 'Environment Validation is Successful');
        */

        IF l_chr_xml_message_type <> g_chr_ship_confirm_msg_type
        THEN
            RAISE l_exe_msg_type_no_match;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Message Type Validation is Successful');

        -- Establish a save point
        -- If error at any stage, rollback to this save point
        SAVEPOINT l_savepoint_before_load;
        fnd_file.put_line (fnd_file.LOG,
                           'l_savepoint_before_load - Savepoint Established');
        fnd_file.put_line (fnd_file.LOG,
                           'Loading the XML file into database');


        -- Logic to insert shipment headers
        OPEN cur_shipment_headers;

        LOOP
            IF l_shipconf_headers_tab.EXISTS (1)
            THEN
                l_shipconf_headers_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_shipment_headers
                    BULK COLLECT INTO l_shipconf_headers_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_shipment_headers;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Shipment Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_shipconf_headers_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_shipconf_headers_tab.FIRST ..
                       l_shipconf_headers_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_head_stg
                         VALUES l_shipconf_headers_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Shipment Headers: '
                        || l_num_error_count);

                    FOR i IN 1 .. l_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_shipment_headers;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_shipment_headers;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of Shipment Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_shipment_headers;

        fnd_file.put_line (fnd_file.LOG,
                           'Shipment Headers Load is successful');

        -- Logic to insert deliveries
        OPEN cur_deliveries;

        LOOP
            IF l_shipconf_orders_tab.EXISTS (1)
            THEN
                l_shipconf_orders_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_deliveries
                    BULK COLLECT INTO l_shipconf_orders_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_deliveries;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Deliveries : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_shipconf_orders_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_shipconf_orders_tab.FIRST ..
                       l_shipconf_orders_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_order_stg
                         VALUES l_shipconf_orders_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of deliveries: '
                        || l_num_error_count);

                    FOR i IN 1 .. l_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_deliveries;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_deliveries;

                    p_out_chr_errbuf   :=
                           'Unexpected error in BULK Insert of deliveries : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_deliveries;

        fnd_file.put_line (fnd_file.LOG,
                           'Deliveries/Orders Load is successful');

        -- Logic to insert cartons
        OPEN cur_cartons;

        LOOP
            IF l_cartons_tab.EXISTS (1)
            THEN
                l_cartons_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_cartons
                    BULK COLLECT INTO l_cartons_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_cartons;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Cartons : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_cartons_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind IN l_cartons_tab.FIRST .. l_cartons_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_carton_stg
                         VALUES l_cartons_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Cartons: '
                        || l_num_error_count);

                    FOR i IN 1 .. l_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_cartons;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_cartons;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of Cartons : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_cartons;

        fnd_file.put_line (fnd_file.LOG, 'Cartons Load is successful');

        -- Logic to insert order lines
        OPEN cur_order_lines;

        LOOP
            IF l_carton_dtls_tab.EXISTS (1)
            THEN
                l_carton_dtls_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_order_lines
                    BULK COLLECT INTO l_carton_dtls_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_order_lines;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Carton details/Order lines : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_carton_dtls_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_carton_dtls_tab.FIRST .. l_carton_dtls_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_cardtl_stg
                         VALUES l_carton_dtls_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Carton details/Order lines: '
                        || l_num_error_count);

                    FOR i IN 1 .. l_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_order_lines;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_order_lines;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of Carton details/Order lines : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_order_lines;

        fnd_file.put_line (fnd_file.LOG,
                           'Carton Details/Order Lines Load is successful');

        -- Logic to insert serials
        OPEN cur_serials;

        LOOP
            IF l_carton_sers_tab.EXISTS (1)
            THEN
                l_carton_sers_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_serials
                    BULK COLLECT INTO l_carton_sers_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_serials;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Serials : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_carton_sers_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_carton_sers_tab.FIRST .. l_carton_sers_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_ont_ship_conf_carser_stg
                         VALUES l_carton_sers_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of Serials: '
                        || l_num_error_count);

                    FOR i IN 1 .. l_num_error_count
                    LOOP
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error #'
                            || i
                            || ' occurred during '
                            || 'iteration #'
                            || SQL%BULK_EXCEPTIONS (i).ERROR_INDEX);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Error message is '
                            || SQLERRM (-SQL%BULK_EXCEPTIONS (i).ERROR_CODE));
                    END LOOP;

                    CLOSE cur_serials;

                    RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_serials;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of Serials : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;

        CLOSE cur_serials;

        fnd_file.put_line (fnd_file.LOG, 'Serials Load is successful');
        fnd_file.put_line (fnd_file.LOG, 'All Details are loaded');

        -- Update the XML file extract status and commit
        BEGIN
            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to PROCESSED');
            -- Commit the status update along with all the inserts done before
            COMMIT;
            fnd_file.put_line (fnd_file.LOG, 'Commited the changes');
            fnd_file.put_line (fnd_file.LOG, 'End of Loading');
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'Updating the process status in the XML table failed due to : '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Updating the process status in the XML table failed due to : '
                    || SQLERRM);
                ROLLBACK TO l_savepoint_before_load;
        END;
    EXCEPTION
        WHEN l_exe_env_no_match
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := 'Environment name in XML is not correct';

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = p_out_chr_errbuf, last_update_date = SYSDATE,
                   last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN l_exe_msg_type_no_match
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := 'Message Type in XML is not correct';

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = p_out_chr_errbuf, last_update_date = SYSDATE,
                   last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
            ROLLBACK TO l_savepoint_before_load;

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = p_out_chr_errbuf, last_update_date = SYSDATE,
                   last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN l_exe_bulk_insert_failed
        THEN
            p_out_chr_retcode   := '2';
            ROLLBACK TO l_savepoint_before_load;

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = p_out_chr_errbuf, last_update_date = SYSDATE,
                   last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'Unexpected error while extracting the data from XML : '
                || SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error while extracting the data from XML.'
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE);
            ROLLBACK TO l_savepoint_before_load;

            UPDATE xxdo_ont_ship_conf_xml_stg
               SET process_status = 'ERROR', error_message = p_out_chr_errbuf, last_update_date = SYSDATE,
                   last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
    /*
          WHEN l_exe_env_no_match
          THEN
             p_out_chr_retcode := '2';
             p_out_chr_errbuf := 'Environment name in XML is not correct';
          WHEN l_exe_msg_type_no_match
          THEN
             p_out_chr_retcode := '2';
             p_out_chr_errbuf := 'Message Type in XML is not correct';
          WHEN l_exe_bulk_fetch_failed
          THEN
             p_out_chr_retcode := '2';
             ROLLBACK TO l_savepoint_before_load;
          WHEN l_exe_bulk_insert_failed
          THEN
             p_out_chr_retcode := '2';
             ROLLBACK TO l_savepoint_before_load;
          WHEN OTHERS
          THEN
             p_out_chr_retcode := '2';
             p_out_chr_errbuf :=
                   'Unexpected error while extracting the data from XML : '
                || SQLERRM;
             fnd_file.put_line
                        (fnd_file.LOG,
                            'Unexpected error while extracting the data from XML.'
                         || CHR (10)
                         || 'Error : '
                         || SQLERRM
                         || CHR (10)
                         || 'Error Code : '
                         || SQLCODE
                        );
             ROLLBACK TO l_savepoint_before_load;
    */
    END extract_xml_data;

    -- ***************************************************************************
    -- Procedure Name      :  split_delivery_detail
    --
    -- Description         :  This procedure splits a delivery detail when the
    --                        shipped quantity is less than the ordered quantity
    --
    -- Parameters          :
    --                            p_out_chr_errbuf         OUT : Error Message
    --                            p_out_chr_retcode        OUT : Execution status
    --                            p_in_num_delivery_detail_id    IN : Delivery Detail Id
    --                            p_in_num_split_quantity        IN : Split Quantity - Requested Qty in the new delivery detail
    --                            p_in_chr_delivery_name         IN : Delivery name
    --                            p_out_num_delivery_detail_id   OUT : New Delivery detail id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0   Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE split_delivery_detail (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_detail_id IN NUMBER
                                     , p_in_num_split_quantity IN NUMBER, p_in_chr_delivery_name IN VARCHAR2, p_out_num_delivery_detail_id OUT NUMBER)
    IS
        l_chr_return_status        VARCHAR2 (30) := NULL;
        l_num_msg_count            NUMBER;
        l_num_msg_cntr             NUMBER;
        l_num_msg_index_out        NUMBER;
        l_chr_msg_data             VARCHAR2 (2000);
        l_num_delivery_detail_id   NUMBER := 0;
        l_num_split_quantity       NUMBER := p_in_num_split_quantity;
        l_num_split_quantity2      NUMBER;
    BEGIN
        --Reset status variables
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        -- Start calling api
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG, 'Start Calling split line api');
        fnd_file.put_line (fnd_file.LOG,
                           'delivery name: ' || p_in_chr_delivery_name);

        wsh_delivery_details_pub.split_line (
            p_api_version        => g_num_api_version,
            p_init_msg_list      => fnd_api.g_true,
            p_commit             => fnd_api.g_false,
            p_validation_level   => NULL,
            x_return_status      => l_chr_return_status,
            x_msg_count          => l_num_msg_count,
            x_msg_data           => l_chr_msg_data,
            p_from_detail_id     => p_in_num_delivery_detail_id,
            x_new_detail_id      => l_num_delivery_detail_id,
            x_split_quantity     => l_num_split_quantity,
            x_split_quantity2    => l_num_split_quantity2);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF l_num_msg_count > 0
            THEN
                p_out_num_delivery_detail_id   := 0;
                p_out_chr_retcode              := '2';
                p_out_chr_errbuf               :=
                       'API to split the delivery detail failed with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                -- Retrieve messages
                l_num_msg_cntr                 := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_errbuf               := l_chr_msg_data;
            END IF;
        ELSE
            p_out_num_delivery_detail_id   := l_num_delivery_detail_id;
            p_out_chr_errbuf               :=
                   'API to split delivery line was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery Detail > '
                || TO_CHAR (p_in_num_delivery_detail_id)
                || ' : Split. New Delivery Detail > '
                || TO_CHAR (l_num_delivery_detail_id));
            fnd_file.put_line (
                fnd_file.LOG,
                'Updating the delivery number on the new delivery detail created');


            UPDATE wsh_delivery_details
               SET attribute11   = p_in_chr_delivery_name /*VVAP attribute11*/
             WHERE delivery_detail_id = l_num_delivery_detail_id;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf   := '2';
            p_out_chr_errbuf   :=
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
    --                            p_out_chr_errbuf         OUT : Error Message
    --                            p_out_chr_retcode        OUT : Execution status
    --                            p_in_num_delivery_detail_id   IN : Delivery Detail Id
    --                            p_in_num_split_quantity       IN : Split Quantity - Requested Qty in the new delivery detail
    --                            p_in_num_order_line_id        IN : Order Line id
    --                            p_in_dte_ship_date            IN : Ship Date
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24    Infosys            1.0  Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE update_shipping_attributes (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_delivery_detail_id IN NUMBER
                                          , p_in_num_shipped_quantity IN NUMBER, p_in_num_order_line_id IN NUMBER, p_in_dte_ship_date IN DATE)
    IS
        l_chr_return_status        VARCHAR2 (30) := NULL;
        l_num_msg_count            NUMBER;
        l_num_msg_cntr             NUMBER;
        l_num_msg_index_out        NUMBER;
        l_chr_msg_data             VARCHAR2 (2000);
        l_chr_source_code          VARCHAR2 (15) := 'OE';
        l_changed_attributes_tab   wsh_delivery_details_pub.changedattributetabtype;
    BEGIN
        --Reset status variables
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling update shipping attributes API...');
        l_changed_attributes_tab (1).delivery_detail_id   :=
            p_in_num_delivery_detail_id;
        l_changed_attributes_tab (1).shipped_quantity   :=
            p_in_num_shipped_quantity;
        wsh_delivery_details_pub.update_shipping_attributes (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            p_commit               => fnd_api.g_false,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_changed_attributes   => l_changed_attributes_tab,
            p_source_code          => l_chr_source_code);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            IF l_num_msg_count > 0
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'API to update shipping attributes failed with status: '
                    || l_chr_return_status;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                -- Retrieve messages
                l_num_msg_cntr      := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message : ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_errbuf    := l_chr_msg_data;
            END IF;
        ELSE
            p_out_chr_errbuf   :=
                   'API to update shipping attributes was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Delivery Detail > '
                || TO_CHAR (p_in_num_delivery_detail_id)
                || ' : Updated Ship Quantity > '
                || TO_CHAR (p_in_num_shipped_quantity));
            fnd_file.put_line (fnd_file.LOG,
                               'Updating the ship date at order line level');
        /* VVAP - below update is not required */
        /*
        UPDATE oe_order_lines_all ool
                   SET ool.schedule_ship_date =
                                     NVL (p_in_dte_ship_date, ool.schedule_ship_date),
       --                      ool.schedule_arrival_date =
       --                         NVL (rec_confirmed_lines.delivery_date,
       --                              ool.schedule_arrival_date
       --                             ),
                       ool.last_update_date = SYSDATE,
                       ool.last_updated_by = g_num_user_id,
                       ool.last_update_login = g_num_login_id
                 WHERE ool.line_id = p_in_num_order_line_id;
         */
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
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
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_hold_source_tbl   IN   : Hold Ids
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE reapply_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_hold_source_tbl IN g_hold_source_tbl_type)
    IS
        l_num_rec_cnt         NUMBER;
        l_num_msg_count       NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_chr_return_status   VARCHAR2 (1);
        l_num_msg_index_out   NUMBER;
        l_num_org_id          NUMBER;                               /*OU_BUG*/
        l_num_resp_id         NUMBER;
        l_num_resp_appl_id    NUMBER;
        l_hold_source_rec     oe_holds_pvt.hold_source_rec_type;
        l_result              VARCHAR2 (240);

        CURSOR c_lines (p_order_header_id IN NUMBER)
        IS
            SELECT oola.line_id
              FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
             WHERE     oola.header_id = ooha.header_id
                   AND oola.flow_status_code = 'SHIPPED'
                   AND ooha.header_id = p_order_header_id;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        FOR l_num_index IN 1 .. p_in_hold_source_tbl.COUNT
        LOOP
            -- Addedd for CCR0006947
            FOR r_lines
                IN c_lines (p_in_hold_source_tbl (l_num_index).header_id)
            LOOP
                apps.OE_Standard_WF.OEOL_SELECTOR (
                    p_itemtype   => 'OEOL',
                    p_itemkey    => TO_CHAR (r_lines.line_id),
                    p_actid      => 12345,
                    p_funcmode   => 'SET_CTX',
                    p_result     => l_result);

                apps.wf_engine.HandleError ('OEOL', TO_CHAR (r_lines.line_id), 'INVOICE_INTERFACE'
                                            , 'RETRY', '');
            END LOOP;

            COMMIT;

            -- End CCR0006947

            SELECT org_id
              INTO l_num_org_id
              FROM oe_order_headers_all
             WHERE     header_id =
                       p_in_hold_source_tbl (l_num_index).header_id
                   AND open_flag = 'Y';

            SELECT COUNT (1)
              INTO l_num_rec_cnt
              FROM oe_order_lines_all /* OU_BUG , replaced with oe_order_lines_all*/
             WHERE     header_id =
                       p_in_hold_source_tbl (l_num_index).header_id
                   AND open_flag = 'Y';

            IF l_num_rec_cnt > 0
            THEN
                l_hold_source_rec   := oe_holds_pvt.g_miss_hold_source_rec;
                l_hold_source_rec.hold_id   :=
                    p_in_hold_source_tbl (l_num_index).hold_id;
                l_hold_source_rec.hold_entity_code   :=
                    p_in_hold_source_tbl (l_num_index).hold_entity_code;
                l_hold_source_rec.hold_entity_id   :=
                    p_in_hold_source_tbl (l_num_index).hold_entity_id;
                l_hold_source_rec.header_id   :=
                    p_in_hold_source_tbl (l_num_index).header_id;
                l_hold_source_rec.line_id   :=
                    p_in_hold_source_tbl (l_num_index).line_id;
                /* OU_BUG */
                get_resp_details (l_num_org_id, 'ONT', l_num_resp_id,
                                  l_num_resp_appl_id);

                apps.fnd_global.apps_initialize (
                    user_id        => g_num_user_id,
                    resp_id        => l_num_resp_id,
                    resp_appl_id   => l_num_resp_appl_id);
                mo_global.init ('ONT');
                /* OU_BUG */
                oe_holds_pub.apply_holds (
                    p_api_version        => 1.0,
                    p_init_msg_list      => fnd_api.g_true,
                    p_commit             => fnd_api.g_false,
                    p_validation_level   => fnd_api.g_valid_level_none,
                    p_hold_source_rec    => l_hold_source_rec,
                    x_msg_count          => l_num_msg_count,
                    x_msg_data           => l_chr_msg_data,
                    x_return_status      => l_chr_return_status);

                IF l_chr_return_status <> fnd_api.g_ret_sts_success
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           p_in_hold_source_tbl (l_num_index).hold_name
                        || ' is not reapplied on the order - header Id: '
                        || p_in_hold_source_tbl (l_num_index).header_id);

                    FOR l_num_msg_cntr IN 1 .. l_num_msg_count
                    LOOP
                        fnd_msg_pub.get (
                            p_msg_index       => l_num_msg_cntr,
                            p_encoded         => 'F',
                            p_data            => l_chr_msg_data,
                            p_msg_index_out   => l_num_msg_index_out);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Error Message: ' || l_chr_msg_data);
                    END LOOP;

                    p_out_chr_retcode   := '2';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           p_in_hold_source_tbl (l_num_index).hold_name
                        || ' is reapplied successfully on the order - header Id: '
                        || p_in_hold_source_tbl (l_num_index).header_id);
                END IF;
            ELSE
                fnd_file.put_line (
                    fnd_file.LOG,
                       p_in_hold_source_tbl (l_num_index).hold_name
                    || ' is not reapplied since no open lines in the order - header Id: '
                    || p_in_hold_source_tbl (l_num_index).header_id);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at reapply hold procedure : '
                || p_out_chr_errbuf);
    END reapply_holds;

    -- ***************************************************************************
    -- Procedure Name      :  release_holds
    --
    -- Description         :  This procedure is to release the order holds before ship confirm
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                             p_io_hold_source_tbl   IN OUT :  Hold Ids
    --                             p_in_num_header_id     IN  : Order header Id
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE release_holds (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_io_hold_source_tbl IN OUT g_hold_source_tbl_type
                             , p_in_num_header_id IN NUMBER)
    IS
        l_num_msg_count       NUMBER;
        l_chr_msg_data        VARCHAR2 (300);
        l_chr_return_status   VARCHAR2 (1);
        l_chr_message         VARCHAR2 (2000);
        l_chr_message1        VARCHAR2 (2000);
        l_num_msg_index_out   NUMBER;
        /*OU_BUG*/
        l_num_org_id          NUMBER;
        l_num_resp_id         NUMBER;
        l_num_resp_appl_id    NUMBER;
        /*OU_BUG*/
        l_hold_release_rec    oe_holds_pvt.hold_release_rec_type;
        l_hold_source_rec     oe_holds_pvt.hold_source_rec_type;

        CURSOR cur_holds (p_num_header_id IN NUMBER)
        IS
            SELECT DECODE (hold_srcs.hold_entity_code,  'S', 'Ship-To',  'B', 'Bill-To',  'I', 'Item',  'W', 'Warehouse',  'O', 'Order',  'C', 'Customer',  hold_srcs.hold_entity_code) AS hold_type, hold_defs.NAME AS hold_name, hold_defs.type_code,
                   holds.header_id, holds.org_id hold_org_id, holds.line_id,
                   hold_srcs.*
              FROM oe_hold_definitions hold_defs, oe_hold_sources_all hold_srcs, /*OU_BUG replaced wih tables _all*/
                                                                                 oe_order_holds_all holds /*OU_BUG replaced wih tables _all*/
             WHERE     hold_srcs.hold_source_id = holds.hold_source_id
                   AND hold_defs.hold_id = hold_srcs.hold_id
                   AND holds.header_id = p_num_header_id
                   AND holds.released_flag = 'N';
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        FOR holds_rec IN cur_holds (p_in_num_header_id)
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
                    g_chr_ar_release_reason;
            ELSE
                l_hold_release_rec.release_reason_code   :=
                    g_chr_om_release_reason;
            END IF;

            l_hold_release_rec.release_comment   :=
                'Auto-release for ship-confirm.';
            l_hold_release_rec.request_id        :=
                NVL (fnd_global.conc_request_id, -100);
            /* OU_BUG */
            get_resp_details (holds_rec.hold_org_id, 'ONT', l_num_resp_id,
                              l_num_resp_appl_id);

            apps.fnd_global.apps_initialize (
                user_id        => g_num_user_id,
                resp_id        => l_num_resp_id,
                resp_appl_id   => l_num_resp_appl_id);
            mo_global.init ('ONT');
            /* OU_BUG */
            oe_holds_pub.release_holds (
                p_api_version        => 1.0,
                p_init_msg_list      => fnd_api.g_true,
                p_commit             => fnd_api.g_false,
                p_validation_level   => fnd_api.g_valid_level_none,
                p_hold_source_rec    => l_hold_source_rec,
                p_hold_release_rec   => l_hold_release_rec,
                x_msg_count          => l_num_msg_count,
                x_msg_data           => l_chr_msg_data,
                x_return_status      => l_chr_return_status);

            IF l_chr_return_status <> fnd_api.g_ret_sts_success
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       holds_rec.hold_name
                    || ' is released from the order - header Id: '
                    || holds_rec.header_id);

                FOR l_num_msg_cntr IN 1 .. l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_retcode   := '2';
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
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at release hold procedure : '
                || p_out_chr_errbuf);
    END release_holds;

    -- ***************************************************************************
    -- Procedure Name      :  update_trip
    --
    -- Description         :  This procedure is to update the trip name when there is any error
    --
    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retcode     OUT : Execution status
    --                              p_in_num_trip_id            IN  : Trip Id
    --                              p_in_chr_trip_name         IN  :  Trip Name
    --
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/24   Infosys              1.0       Initial Version.
    --
    -- ***************************************************************************

    PROCEDURE update_trip (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_trip_id IN VARCHAR2
                           , p_in_chr_trip_name IN VARCHAR2)
    IS
        l_chr_return_status   VARCHAR2 (30) := NULL;
        l_num_msg_count       NUMBER;
        l_num_msg_cntr        NUMBER;
        l_num_msg_index_out   NUMBER;
        l_chr_msg_data        VARCHAR2 (2000);
        l_num_trip_id         NUMBER;
        l_chr_trip_name       VARCHAR2 (240);
        l_num_carrier_id      NUMBER := NULL;
        l_rec_trip_info       wsh_trips_pub.trip_pub_rec_type;
    BEGIN
        --Reset status variables
        p_out_chr_errbuf          := NULL;
        p_out_chr_retcode         := '0';

        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Start Calling CREATE_UPDATE_TRIP API...');
        fnd_file.put_line (fnd_file.LOG, ' ');
        fnd_file.put_line (fnd_file.LOG,
                           'Trip Name      : ' || p_in_chr_trip_name);
        fnd_file.put_line (fnd_file.LOG, ' ');
        l_rec_trip_info.NAME      := p_in_chr_trip_name;
        l_rec_trip_info.trip_id   := p_in_num_trip_id;

        wsh_trips_pub.create_update_trip (
            p_api_version_number   => g_num_api_version,
            p_init_msg_list        => fnd_api.g_true,
            x_return_status        => l_chr_return_status,
            x_msg_count            => l_num_msg_count,
            x_msg_data             => l_chr_msg_data,
            p_action_code          => 'UPDATE',
            p_trip_info            => l_rec_trip_info,
            x_trip_id              => l_num_trip_id,
            x_trip_name            => l_chr_trip_name);

        IF l_chr_return_status <> fnd_api.g_ret_sts_success
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'API to update trip failed with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);

            IF l_num_msg_count > 0
            THEN
                -- Retrieve messages
                l_num_msg_cntr     := 1;

                WHILE l_num_msg_cntr <= l_num_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => l_num_msg_cntr, p_encoded => 'F', p_data => l_chr_msg_data
                                     , p_msg_index_out => l_num_msg_index_out);
                    l_num_msg_cntr   := l_num_msg_cntr + 1;
                    fnd_file.put_line (fnd_file.LOG,
                                       'Error Message: ' || l_chr_msg_data);
                END LOOP;

                p_out_chr_errbuf   := l_chr_msg_data;
            END IF;
        ELSE
            p_out_chr_retcode   := '0';
            p_out_chr_errbuf    :=
                   'API to update trip was successful with status: '
                || l_chr_return_status;
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Trip ID > '
                || TO_CHAR (l_num_trip_id)
                || ': Trip Name > '
                || p_in_chr_trip_name);
        END IF;

        -- Reset stop seq number
        fnd_file.put_line (fnd_file.LOG,
                           'End Calling CREATE_UPDATE_TRIP API...');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    :=
                   'Unexpected error occurred in the Updation of Trip while updating trip for Shipment Number: '
                || p_in_chr_trip_name
                || CHR (10)
                || 'Error : '
                || SQLERRM
                || CHR (10)
                || 'Error Code : '
                || SQLCODE;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error occurred in the Updation of Trip while updating trip for Shipment Number: '
                || p_in_chr_trip_name
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

    PROCEDURE interface_edi_asns (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2)
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
                     NVL (ool.deliver_to_org_id, 1) deliver_to_org_id --Added for change v2.14
                FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts_all hca,
                     oe_order_lines_all ool           --Added for change v2.14
               WHERE     ord.shipment_number = p_in_chr_shipment_no
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
             WHERE     ord.shipment_number = p_in_chr_shipment_no
                   AND ord.order_header_id = ooh.header_id
                   AND ooh.sold_to_org_id = p_num_sold_to_org_id
                   AND ooh.attribute5 = p_chr_brand
                   AND ooh.header_id = ool.header_id
                   AND NVL (ool.deliver_to_org_id, 1) =
                       NVL (p_deliver_to_org_id, 1)   --Added for change v2.14
                   AND NVL (ord.delivery_id, ord.order_number) =
                       wda.delivery_id                --Added for change v2.14
                   AND wda.delivery_detail_id = wdd.delivery_detail_id --Added for change v2.14
                   AND wdd.source_code = 'OE'         --Added for change v2.14
                   AND wdd.source_line_id = ool.line_id --Added for change v2.14
                                                       ;

        CURSOR cur_customer_picktickets_track IS
            SELECT DISTINCT ooh.sold_to_org_id--ooh.ship_to_org_id,  -- Commented EDI856_SHIP_TO_ORG
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
                            NVL (ool.deliver_to_org_id, 1) deliver_to_org_id --Added for change v2.14
              FROM xxdo_ont_ship_conf_order_stg ord, oe_order_headers_all ooh, hz_cust_accounts hca,
                   oe_order_lines_all ool             --Added for change v2.14
             WHERE     ord.shipment_number = p_in_chr_shipment_no
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
             WHERE     ord.shipment_number = p_in_chr_shipment_no
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
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        fnd_file.put_line (fnd_file.LOG,
                           'Interfacing the shipments to EDI tables');

        /* update carrier code in attribute2 of WND - WND_ATTRIBUTE2 */
        UPDATE wsh_new_deliveries
           SET attribute2   =
                   (SELECT h.carrier
                      FROM apps.xxdo_ont_ship_conf_head_stg h
                     WHERE h.shipment_number = p_in_chr_shipment_no)
         WHERE     delivery_id IN
                       (SELECT NVL (delivery_id, order_number)
                          FROM apps.xxdo_ont_ship_conf_order_stg
                         WHERE shipment_number = p_in_chr_shipment_no)
               AND attribute2 IS NULL;

        /* CUST_LOAD_ID - Start */

        UPDATE wsh_new_deliveries
           SET attribute15   =
                   (SELECT h.customer_load_id
                      FROM apps.xxdo_ont_ship_conf_head_stg h
                     WHERE h.shipment_number = p_in_chr_shipment_no)
         WHERE     delivery_id IN
                       (SELECT NVL (delivery_id, order_number)
                          FROM apps.xxdo_ont_ship_conf_order_stg
                         WHERE shipment_number = p_in_chr_shipment_no)
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
             WHERE shipment_number = p_in_chr_shipment_no;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                p_out_chr_errbuf    := 'Shipment Number does not exists';
                p_out_chr_retcode   := '2';
            WHEN TOO_MANY_ROWS
            THEN
                p_out_chr_errbuf    := 'Duplicate Shipment records found';
                p_out_chr_retcode   := '2';
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                    'Unexpected error while deriving BOL no : ' || SQLERRM;
                p_out_chr_retcode   := '2';
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
             WHERE     delivery_id IN
                           (SELECT NVL (delivery_id, order_number)
                              FROM apps.xxdo_ont_ship_conf_order_stg
                             WHERE shipment_number = p_in_chr_shipment_no)
                   AND waybill IS NULL;

            /* Added for CCR0006947 */
            UPDATE wsh_delivery_details
               SET seal_code   = l_chr_seal_number
             WHERE delivery_detail_id IN
                       (SELECT wda.delivery_detail_id
                          FROM wsh_delivery_assignments wda
                         WHERE wda.delivery_id IN
                                   (SELECT NVL (delivery_id, order_number)
                                      FROM apps.xxdo_ont_ship_conf_order_stg
                                     WHERE shipment_number =
                                           p_in_chr_shipment_no));

            /* BOL_TRACK_NO - Start */
            UPDATE wsh_delivery_details
               SET tracking_number   = l_chr_bol_number
             WHERE     tracking_number IS NULL
                   AND delivery_detail_id IN
                           (SELECT wda.delivery_detail_id
                              FROM wsh_new_deliveries wnd, wsh_delivery_assignments wda
                             WHERE     wnd.delivery_id = wda.delivery_id
                                   AND wnd.delivery_id IN
                                           (SELECT NVL (delivery_id, order_number)
                                              FROM apps.xxdo_ont_ship_conf_order_stg
                                             WHERE shipment_number =
                                                   p_in_chr_shipment_no));

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
                                                        seal_code, /* Modified for CCR0006947 */
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
                           l_chr_seal_number,    /* Modified for CCR0006947 */
                           l_chr_trailer_number, /* Modified for CCR0006947 */
                           NULL
                               tracking_number,
                           head.pro_number,
                           head.ship_date + 3
                               est_delivery_date,
                           SYSDATE
                               creation_date,
                           g_num_user_id
                               created_by,
                           SYSDATE
                               last_update_date,
                           g_num_user_id
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
                     WHERE     head.shipment_number = p_in_chr_shipment_no
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
                                                 p_in_chr_shipment_no
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
                                                 p_in_chr_shipment_no
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
                                     g_num_user_id
                                         created_by,
                                     SYSDATE
                                         last_update_date,
                                     g_num_user_id
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
                                                 p_in_chr_shipment_no
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
                               WHERE     ord.shipment_number =
                                         p_in_chr_shipment_no
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
                               AND shipment_number = p_in_chr_shipment_no;

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
                     WHERE     ord.shipment_number = p_in_chr_shipment_no
                           AND carton.shipment_number = p_in_chr_shipment_no
                           AND carton.order_number = ord.order_number
                           AND ord.order_header_id = ooh.header_id
                           AND ooh.attribute5 = customer_track_rec.brand
                           AND ooh.sold_to_org_id =
                               customer_track_rec.sold_to_org_id
                           AND ooh.ship_to_org_id =
                               customer_track_rec.ship_to_org_id
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
                        || p_in_chr_shipment_no
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
                                                        seal_code, /* Added for CCR0006947 */
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
                           g_num_user_id
                               created_by,
                           SYSDATE
                               last_update_date,
                           g_num_user_id
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
                     WHERE     head.shipment_number = p_in_chr_shipment_no
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
                                                 p_in_chr_shipment_no
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
                                                 p_in_chr_shipment_no
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
                                     g_num_user_id
                                         created_by,
                                     SYSDATE
                                         last_update_date,
                                     g_num_user_id
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
                                                 p_in_chr_shipment_no
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
                               WHERE     ord.shipment_number =
                                         p_in_chr_shipment_no
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
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at while EDI interfacing : '
                || p_out_chr_errbuf);
    END interface_edi_asns;
/*

PROCEDURE process_delivery_line ( p_out_chr_errbuf OUT VARCHAR2,
                                                p_out_chr_retcode OUT VARCHAR2,
                                                p_in_num_delivery_detail_id IN NUMBER,
                                                p_in_num_ship_qty IN NUMBER,
                                                p_in_dte_ship_date IN DATE,
                                                p_in_chr_carrier IN VARCHAR2,
                                                p_out_chr_tracking_number IN VARCHAR2
                                                )
IS

l_changed_attributes_tab Wsh_Delivery_Details_Pub.CHANGEDATTRIBUTETABTYPE;
l_chr_return_status  VARCHAR2(1);
l_num_msgcount NUMBER;
l_chr_msgdata  VARCHAR2(2000);
l_chr_message                 VARCHAR2(2000);
l_chr_message1                 VARCHAR2(2000);
l_num_inv_item_id number;
begin

    p_out_chr_retcode := '0';
    p_out_chr_errbuf := NULL;


  FND_FILE.PUT_LINE (FND_FILE.LOG,'delivery_detail_id = ' || to_char(p_in_num_delivery_detail_id));
  l_CHANGED_ATTRIBUTES_tab(1).DELIVERY_DETAIL_ID   := p_in_num_delivery_detail_id;
  l_CHANGED_ATTRIBUTES_tab(1).DATE_SCHEDULED       := p_in_dte_ship_date;
  l_CHANGED_ATTRIBUTES_tab(1).FREIGHT_CARRIER_CODE := p_in_chr_carrier;
  l_CHANGED_ATTRIBUTES_tab(1).TRACKING_NUMBER         := trim(p_out_chr_tracking_number); --08/26/2003 - KWG  Trim for searching performance
  l_CHANGED_ATTRIBUTES_tab(1).SHIPPED_QUANTITY   := p_in_num_ship_qty;
  FND_FILE.PUT_LINE (FND_FILE.LOG,'before select');
  select source_line_id,
           organization_id,
         requested_quantity-p_in_num_ship_qty,
         inventory_item_id
    into l_CHANGED_ATTRIBUTES_tab(1).SOURCE_LINE_ID,
         l_CHANGED_ATTRIBUTES_tab(1).SHIP_FROM_ORG_ID,
         l_CHANGED_ATTRIBUTES_tab(1).CYCLE_COUNT_QUANTITY,
         l_num_inv_item_id
    from wsh_delivery_details
    where delivery_detail_id = p_in_num_delivery_detail_id;
  for i in 1..l_CHANGED_ATTRIBUTES_tab.count loop
    FND_FILE.PUT_LINE (FND_FILE.LOG,'SKU: ' || iid_to_sku(l_num_inv_item_id) ||
                       ' DDID: ' || to_char(l_CHANGED_ATTRIBUTES_tab(1).DELIVERY_DETAIL_ID) ||
                        ' Requested: ' || to_char(l_CHANGED_ATTRIBUTES_tab(1).SHIPPED_QUANTITY+l_CHANGED_ATTRIBUTES_tab(1).CYCLE_COUNT_QUANTITY)||
                       ' Shipped: ' || to_char(l_CHANGED_ATTRIBUTES_tab(1).SHIPPED_QUANTITY)||
                       ' Cycle_count: ' || to_char(l_CHANGED_ATTRIBUTES_tab(1).CYCLE_COUNT_QUANTITY));
  end loop;
  FND_FILE.PUT_LINE (FND_FILE.LOG,'before update_shipping_attributes');
  Wsh_Delivery_Details_Pub.UPDATE_SHIPPING_ATTRIBUTES(
                                P_API_VERSION_NUMBER => 1.0,
                                P_INIT_MSG_LIST      => NULL,
                                P_COMMIT             => NULL,
                                X_RETURN_STATUS      => l_chr_return_status,
                                X_MSG_COUNT          => l_num_MSGCOUNT,
                                X_MSG_DATA           => l_chr_MSGDATA,
                                P_CHANGED_ATTRIBUTES => l_CHANGED_ATTRIBUTES_tab,
                                P_SOURCE_CODE        => 'OE');

    FND_FILE.PUT_LINE (FND_FILE.LOG,'l_chr_return_status: '|| l_chr_return_status);
    FND_FILE.PUT_LINE (FND_FILE.LOG,'Message count: '|| l_num_MSGCOUNT);

   IF l_chr_return_status <> fnd_api.g_ret_sts_success THEN

        FOR i in 1..l_num_MSGCOUNT LOOP
          l_chr_message := fnd_msg_pub.get(i,'F');
          l_chr_message := replace(l_chr_message,chr(0),' ');
          FND_FILE.PUT_LINE (FND_FILE.LOG,'Error message: ' || substr(l_chr_message, 1, 200));
        END LOOP;
  fnd_msg_pub.delete_msg();
    p_out_chr_retcode := '2';
    p_out_chr_errbuf := 'Error while processing delivery line: '|| l_chr_message;

ELSE
    p_out_chr_retcode := '0';

END IF;

EXCEPTION
        WHEN OTHERS THEN
                p_out_chr_errbuf :=  SQLERRM;
                p_out_chr_retcode := '2';
                FND_FILE.PUT_LINE (FND_FILE.LOG, 'Unexpected error at process delivery line procedure : ' || p_out_chr_errbuf);
end process_delivery_line;

procedure process_delivery_line(  p_out_chr_errbuf OUT VARCHAR2,
                                                p_out_chr_retcode OUT VARCHAR2,
                                                p_in_num_delivery_detail_id IN NUMBER,
                                                p_in_dte_ship_date IN DATE,
                                                p_in_chr_carrier IN VARCHAR2,
                                                p_out_chr_tracking_number IN VARCHAR2
                                                )
IS

l_CHANGED_ATTRIBUTES_tab Wsh_Delivery_Details_Pub.CHANGEDATTRIBUTETABTYPE;
l_chr_return_status  VARCHAR2(1);
l_num_MSGCOUNT NUMBER;
l_chr_MSGDATA  VARCHAR2(2000);
l_chr_message                 VARCHAR2(2000);
l_chr_message1                 VARCHAR2(2000);
l_num_inv_item_id number;
begin

    p_out_chr_retcode := '0';
    p_out_chr_errbuf := NULL;

  FND_FILE.PUT_LINE (FND_FILE.LOG,'delivery_detail_id = ' || to_char(p_in_num_delivery_detail_id));
  l_CHANGED_ATTRIBUTES_tab(1).DELIVERY_DETAIL_ID   := p_in_num_delivery_detail_id;
  l_CHANGED_ATTRIBUTES_tab(1).DATE_SCHEDULED       := p_in_dte_ship_date;
  if p_in_chr_carrier <> fnd_api.g_miss_char then
    l_CHANGED_ATTRIBUTES_tab(1).FREIGHT_CARRIER_CODE := p_in_chr_carrier;
  end if;
  if p_out_chr_tracking_number <> fnd_api.g_miss_char then
    l_CHANGED_ATTRIBUTES_tab(1).TRACKING_NUMBER         := trim(p_out_chr_tracking_number);
  end if;
  FND_FILE.PUT_LINE (FND_FILE.LOG,'before select');
  for i in 1..l_CHANGED_ATTRIBUTES_tab.count loop
    FND_FILE.PUT_LINE (FND_FILE.LOG,'SKU: ' || get_sku(l_num_inv_item_id) ||
                       ' DDID: ' || to_char(l_CHANGED_ATTRIBUTES_tab(1).DELIVERY_DETAIL_ID));
  end loop;
  FND_FILE.PUT_LINE (FND_FILE.LOG,'before update_shipping_attributes');
  Wsh_Delivery_Details_Pub.UPDATE_SHIPPING_ATTRIBUTES(
                                P_API_VERSION_NUMBER => 1.0,
                                P_INIT_MSG_LIST      => NULL,
                                P_COMMIT             => NULL,
                                X_RETURN_STATUS      => l_chr_return_status,
                                X_MSG_COUNT          => l_num_MSGCOUNT,
                                X_MSG_DATA           => l_chr_MSGDATA,
                                P_CHANGED_ATTRIBUTES => l_CHANGED_ATTRIBUTES_tab,
                                P_SOURCE_CODE        => 'OE');
    FND_FILE.PUT_LINE (FND_FILE.LOG,'l_chr_return_status: '|| l_chr_return_status);
    FND_FILE.PUT_LINE (FND_FILE.LOG,'Message count: '|| l_num_MSGCOUNT);

   IF l_chr_return_status <> fnd_api.g_ret_sts_success THEN

        FOR i in 1..l_num_MSGCOUNT LOOP
          l_chr_message := fnd_msg_pub.get(i,'F');
          l_chr_message := replace(l_chr_message,chr(0),' ');
          FND_FILE.PUT_LINE (FND_FILE.LOG,'Error message: ' || substr(l_chr_message, 1, 200));
        END LOOP;
  fnd_msg_pub.delete_msg();
    p_out_chr_retcode := '2';
    p_out_chr_errbuf := 'Error while processing delivery line: '|| l_chr_message;

ELSE
    p_out_chr_retcode := '0';

END IF;

EXCEPTION
        WHEN OTHERS THEN
                p_out_chr_errbuf :=  SQLERRM;
                p_out_chr_retcode := '2';
                FND_FILE.PUT_LINE (FND_FILE.LOG, 'Unexpected error at process delivery line procedure : ' || p_out_chr_errbuf);
end process_delivery_line;

*/


END xxdo_ont_ship_confirm_pkg;
/
