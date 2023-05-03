--
-- XXDO_PO_ASN_RECEIPT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:08 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_ASN_RECEIPT_PKG"
AS
    /*
    *************************************************************************************************
    $Header:  xxdo_po_asn_receipt_pkg_b.sql   1.0    2014/08/18    10:00:00   Infosys $
    *************************************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_po_asn_receipt_pkg
    --
    -- Description  :  This is package  for WMS to EBS ASN Receipt Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 18-Aug-14    Infosys            1.0       Created
    -- 02-Apr-15    Infosys            2.0       Modified to handle multiple adjustment cases; Identified by MULTIPLE_NEG
    --21-Sep-15     Infosys            3.0      Modified to handle code for past receipt date ; Identified by PAST_RECEIPT
    --21-Sep-15     Infosys            3.0      Modified to handle code for deletion from RCV tables for error record ; Identified by DELETE_TRAN
    --21-Sep-15     Infosys            3.0      Modified to handle code for Over shipment; Identified by OVER_SHIP
    --21-Sep-15     Infosys            3.0      Modified to handle code for purge XML staging table ; Identified by XML_PURGE
    --28-Jun-16     Infosys            4.0      Added request ID condition in extract_xml_data procedure; Identified by REQ_ID
    --18-JUL-16     Infosys            5.0      Added condition to status update statement to check record exists in RCV or not
    --15-SEP-19     Kranthi Bollam     5.1      Modified for CCR0008193 - ASN Receipt Improvements
    --                                           1. Records being stuck in INPROCESS status in the Integration tables which was restricting the ASN receipts.
    --                                           2. Restrict decimal value in the ASN receipt quantity
    --20-MAY-2021   GJensen            5.2      Modified lookup check for multiple HJ instances CCR0009292
    --22-NOV-2021   Showkath Ali       5.3      CCR0009689 changes in locking process
    --16-Mar-2022   Gaurav Joshi    5.4      CCR0009823  hj timezone issue for us6
    -- *************************************************************************************************
    ----------------------
    -- Global Variables --
    ----------------------
    -- Return code (0 for success, 1 for failure)
    g_chr_status_code       VARCHAR2 (1) := '0';
    g_chr_status_msg        VARCHAR2 (4000);
    g_ret_sts_warning       VARCHAR2 (1) := 'W';
    g_sub_inventories_tab   g_ids_var_tab_type;
    g_inv_org_attr_tab      g_inv_org_attr_tab_type;
    g_pst_offset            NUMBER := 8;                                -- 5.3

    -- ***************************************************************************
    -- Procedure/Function Name  :  Purge
    --
    -- Description              :  The purpose of this procedure
    -- is to purge the old ASN receipt records
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_num_purge_days  IN : Purge days
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
    -- Function to get the Time Zone difference for Organization.
    FUNCTION get_offset_time (p_organization_code IN VARCHAR2)
        RETURN NUMBER
    IS
        l_timezone   VARCHAR2 (100);
        l_offset     NUMBER;
    BEGIN
        -- query to get timezone based on organization
        BEGIN
            SELECT hra.timezone_code
              INTO l_timezone
              FROM apps.hr_locations_all hra, apps.hr_organization_units hou
             WHERE     hou.location_id = hra.location_id
                   AND location_code LIKE '%' || p_organization_code || '%';

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Time Zone for the organization:'
                || p_organization_code
                || ' is:'
                || l_timezone);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_timezone   := NULL;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Failed to get Time Zone for the organization:'
                    || p_organization_code
                    || ' is:'
                    || l_timezone);
        END;

        -- query to get time deviation
        BEGIN
            -- SELECT - (SUM (gmt_deviation_hours) / 24)
            SELECT -(g_pst_offset - SUM (gmt_deviation_hours)) / 24
              INTO l_offset
              FROM (SELECT -ht.gmt_deviation_hours AS gmt_deviation_hours
                      FROM apps.hz_timezones ht, apps.hz_timezones_tl htt
                     WHERE     htt.name = l_timezone
                           AND htt.language = 'US'
                           AND ht.timezone_id = htt.timezone_id);

            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   'Time deviation for the organization:'
                || p_organization_code
                || ' is:'
                || l_offset);
        EXCEPTION
            WHEN OTHERS
            THEN
                l_offset   := 0;
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                       'Failed to fetch Time deviation for the organization:'
                    || p_organization_code
                    || ' is:'
                    || l_offset);
        END;

        RETURN NVL (l_offset, 0);
    END;


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
            /***********************************************************************/
            /*Infosys Ver 5.0: Purge only processed and marked processed records;  */
            /*                   condition to check records not in error status    */
            /***********************************************************************/
            INSERT INTO xxdo_po_asn_receipt_head_log (wh_id, appointment_id, receipt_date, employee_id, employee_name, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, SOURCE, destination, record_type, receipt_header_seq_id, organization_id, archive_date
                                                      , archive_request_id)
                SELECT wh_id, appointment_id, receipt_date,
                       employee_id, employee_name, process_status,
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
                       receipt_header_seq_id, organization_id, SYSDATE,
                       g_num_request_id
                  FROM xxdo_po_asn_receipt_head_stg
                 WHERE     creation_date <
                           l_dte_sysdate - p_in_num_purge_days
                       AND process_status = 'PROCESSED';

            DELETE FROM
                xxdo_po_asn_receipt_head_stg
                  WHERE     creation_date <
                            l_dte_sysdate - p_in_num_purge_days
                        AND process_status = 'PROCESSED';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN Receipt headers data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN Receipt headers data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_po_asn_receipt_dtl_log (wh_id,
                                                     appointment_id,
                                                     shipment_number,
                                                     po_number,
                                                     carton_id,
                                                     line_number,
                                                     item_number,
                                                     rcpt_type,
                                                     qty,
                                                     ordered_uom,
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
                                                     shipment_header_id,
                                                     po_header_id,
                                                     lpn_id,
                                                     inventory_item_id,
                                                     receipt_header_seq_id,
                                                     receipt_dtl_seq_id,
                                                     organization_id,
                                                     receipt_source_code,
                                                     open_qty,
                                                     po_line_id,
                                                     shipment_line_id,
                                                     requisition_header_id,
                                                     requisition_line_id,
                                                     GROUP_ID,
                                                     org_id,
                                                     LOCATOR,
                                                     locator_id,
                                                     archive_date,
                                                     archive_request_id,
                                                     vendor_id)
                SELECT wh_id, appointment_id, shipment_number,
                       po_number, carton_id, line_number,
                       item_number, rcpt_type, qty,
                       ordered_uom, host_subinventory, process_status,
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
                       shipment_header_id, po_header_id, lpn_id,
                       inventory_item_id, receipt_header_seq_id, receipt_dtl_seq_id,
                       organization_id, receipt_source_code, open_qty,
                       po_line_id, shipment_line_id, requisition_header_id,
                       requisition_line_id, GROUP_ID, org_id,
                       LOCATOR, locator_id, SYSDATE,
                       g_num_request_id, vendor_id
                  FROM xxdo_po_asn_receipt_dtl_stg
                 WHERE     creation_date <
                           l_dte_sysdate - p_in_num_purge_days
                       AND process_status = 'PROCESSED';

            DELETE FROM
                xxdo_po_asn_receipt_dtl_stg
                  WHERE     creation_date <
                            l_dte_sysdate - p_in_num_purge_days
                        AND process_status = 'PROCESSED';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN receipt detail data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN receipt detail data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_po_asn_receipt_ser_log (wh_id,
                                                     appointment_id,
                                                     shipment_number,
                                                     po_number,
                                                     carton_id,
                                                     line_number,
                                                     item_number,
                                                     serial_number,
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
                                                     receipt_header_seq_id,
                                                     receipt_dtl_seq_id,
                                                     receipt_serial_seq_id,
                                                     archive_date,
                                                     archive_request_id)
                SELECT wh_id, appointment_id, shipment_number,
                       po_number, carton_id, line_number,
                       item_number, serial_number, process_status,
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
                       receipt_header_seq_id, receipt_dtl_seq_id, receipt_serial_seq_id,
                       SYSDATE, g_num_request_id
                  FROM xxdo_po_asn_receipt_ser_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_po_asn_receipt_ser_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN serials data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN serials data: '
                    || SQLERRM);
        END;

        COMMIT;

        /*Start of XML_PURGE*/
        BEGIN
            INSERT INTO xxdo_po_asn_receipt_xml_log (process_status,
                                                     xml_document,
                                                     file_name,
                                                     error_message,
                                                     request_id,
                                                     creation_date,
                                                     created_by,
                                                     last_update_date,
                                                     last_updated_by,
                                                     --        record_type,
                                                     asn_xml_seq_id,
                                                     archive_request_id,
                                                     archive_date)
                SELECT process_status, xml_document, file_name,
                       error_message, request_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       --     record_type,
                       asn_xml_seq_id, g_num_request_id, l_dte_sysdate
                  FROM xxdo_po_asn_receipt_xml_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_in_num_purge_days;

            DELETE FROM
                xxdo_po_asn_receipt_xml_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_in_num_purge_days;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN XML  data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN XML data: '
                    || SQLERRM);
        END;
    /*END of XML_PURGE*/
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

    /*
    PROCEDURE reset_error_records (p_out_chr_errbuf        OUT VARCHAR2,
    p_out_chr_retcode      OUT VARCHAR2,
    p_in_chr_shipment_no  IN VARCHAR2)
    IS
    BEGIN
    p_out_chr_errbuf := NULL;
    p_out_chr_retcode := '0';
    UPDATE xxdo_ont_ship_conf_head_stg
    SET process_status = 'NEW',
    error_message= NULL,
    last_updated_by  = g_num_user_id,
    last_update_date = SYSDATE
    WHERE process_status = 'ERROR'
    AND shipment_number = NVL(p_in_chr_shipment_no, shipment_number );
    UPDATE xxdo_ont_ship_conf_order_stg
    SET process_status = 'NEW',
    error_message= NULL ,
    last_updated_by  = g_num_user_id,
    last_update_date = SYSDATE
    WHERE process_status = 'ERROR'
    AND shipment_number = NVL(p_in_chr_shipment_no, shipment_number );
    UPDATE xxdo_ont_ship_conf_carton_stg
    SET process_status = 'NEW',
    error_message= NULL ,
    last_updated_by  = g_num_user_id,
    last_update_date = SYSDATE
    WHERE process_status = 'ERROR'
    AND shipment_number = NVL(p_in_chr_shipment_no, shipment_number );
    UPDATE xxdo_ont_ship_conf_cardtl_stg
    SET process_status = 'NEW',
    error_message= NULL ,
    last_updated_by  = g_num_user_id,
    last_update_date = SYSDATE
    WHERE process_status = 'ERROR'
    AND shipment_number = NVL(p_in_chr_shipment_no, shipment_number );
    UPDATE xxdo_ont_ship_conf_carser_stg
    SET process_status = 'NEW',
    error_message= NULL ,
    last_updated_by  = g_num_user_id,
    last_update_date = SYSDATE
    WHERE process_status = 'ERROR'
    AND shipment_number = NVL(p_in_chr_shipment_no, shipment_number );
    EXCEPTION
    WHEN OTHERS THEN
    p_out_chr_retcode := '2';
    p_out_chr_errbuf := SQLERRM;
    FND_FILE.PUT_LINE (FND_FILE.LOG,'ERROR in reset error records procedure : ' || p_out_chr_errbuf);
    END reset_error_records;
    */
    -- ***************************************************************************
    -- Procedure/Function Name  :  update_error_records
    --
    -- Description              :  The purpose of this procedure is to update the process status of the records
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message at procedure level
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_chr_shipment_no  IN : ASN Number
    --                                  p_in_chr_error_message IN : Error message at record level
    --                                 p_in_chr_from_status   IN : From Process status
    --                                 p_in_chr_to_status       IN : To Process status
    --
    -- Return/Exit              :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  ----------------------------------------
    -- 2014/08/11    Infosys            1.0   Initial Version
    -- 2015/02/03    Infosys            2.0   Commenting the update on header stage table
    -- **********************************************************************************
    PROCEDURE update_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_appointment_id IN VARCHAR2, p_in_num_receipt_head_id IN NUMBER, p_in_chr_shipment_no IN VARCHAR2, p_in_num_rcpt_dtl_seq_id IN NUMBER, p_in_chr_error_message IN VARCHAR2, p_in_chr_from_status IN VARCHAR2, p_in_chr_to_status IN VARCHAR2
                                    , p_in_chr_warehouse IN VARCHAR2)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        /*Commenting the update on header stage table BEGIN*/
        /*      UPDATE xxdo_po_asn_receipt_head_stg
        SET process_status = p_in_chr_to_status,
        --             error_message = p_in_chr_error_message,
        last_updated_by = g_num_user_id,
        last_update_date = SYSDATE
        WHERE process_status = p_in_chr_from_status
        AND appointment_id = NVL (p_in_chr_appointment_id, appointment_id)
        AND wh_id = NVL (p_in_chr_warehouse, wh_id)
        AND receipt_header_seq_id = p_in_num_receipt_head_id
        AND request_id = g_num_request_id; */
        /*Commenting the update on header stage table END*/
        UPDATE xxdo_po_asn_receipt_dtl_stg
           SET process_status = p_in_chr_to_status, error_message = p_in_chr_error_message, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND receipt_header_seq_id = p_in_num_receipt_head_id
               AND receipt_dtl_seq_id =
                   NVL (p_in_num_rcpt_dtl_seq_id, receipt_dtl_seq_id)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_receipt_ser_stg
           SET process_status = p_in_chr_to_status, --             error_message = p_in_chr_error_message,
                                                    last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND receipt_header_seq_id = p_in_num_receipt_head_id
               AND receipt_dtl_seq_id =
                   NVL (p_in_num_rcpt_dtl_seq_id, receipt_dtl_seq_id)
               AND request_id = g_num_request_id;

        COMMIT;
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
    -- Procedure/Function Name  :  lock_records
    --
    -- Description              :  The purpose of this procedure is to lock the records before validating and receiving ASNs
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_chr_appointment_id IN : Appointment id
    --                                  p_out_num_record_count  OUT: updated records count
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- 2021/11/22    SHowkath ALi       1.1   CCR0009689 changes
    -- ***************************************************************************
    PROCEDURE lock_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_warehouse IN VARCHAR2
                            , p_in_chr_appointment_id IN VARCHAR2, p_in_chr_rcpt_type IN VARCHAR2, p_out_num_record_count OUT NUMBER)
    IS
    BEGIN
        p_out_chr_errbuf         := NULL;
        p_out_chr_retcode        := '0';

        UPDATE xxdo_po_asn_receipt_head_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_po_asn_receipt_dtl_stg dtl
                         WHERE     process_status = 'NEW'
                               AND appointment_id =
                                   NVL (p_in_chr_appointment_id,
                                        appointment_id)
                               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
                               AND rcpt_type =
                                   NVL (p_in_chr_rcpt_type, rcpt_type)
                               AND shipment_number IS NOT NULL);

        fnd_file.put_line (
            fnd_file.LOG,
               'Receipt Type: '
            || p_in_chr_rcpt_type
            || ' Header Update Count in Lock Procedure : '
            || SQL%ROWCOUNT);

        /***********************************************************************/
        /*Infosys Ver 5.0: Identify duplicate records and mark status as       */
        /*                   Duplicate                                         */
        /***********************************************************************/
        UPDATE apps.xxdo_po_asn_receipt_dtl_stg dtl
           SET process_status = 'DUPLICATE', error_message = 'RECORD EXISTS IN STAGING', request_id = g_num_request_id,
               last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND EXISTS
                       (SELECT '1'
                          FROM apps.xxdo_po_asn_receipt_dtl_stg dt2
                         WHERE     1 = 1
                               AND dtl.shipment_number = dt2.shipment_number
                               AND dtl.ITEM_NUMBER = dt2.item_number
                               AND dtl.CARTON_ID = dt2.carton_id
                               AND dtl.qty = dt2.qty
                               AND dtl.RECEIPT_DTL_SEQ_ID !=
                                   dt2.receipt_dtl_seq_id);

        fnd_file.put_line (
            fnd_file.LOG,
               'Receipt Type : '
            || p_in_chr_rcpt_type
            || ' Duplicate in staging table : '
            || SQL%ROWCOUNT);

        /***********************************************************************/
        /*Infosys Ver 5.0: Identify duplicate records and mark status as       */
        /*                   Duplicate                                         */
        /***********************************************************************/
        UPDATE apps.xxdo_po_asn_receipt_dtl_stg dtl
           SET process_status = 'DUPLICATE', error_message = 'RECORD EXISTS IN RCV', request_id = g_num_request_id,
               last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND EXISTS
                       (SELECT 1
                          FROM rcv_transactions rt1, PO.RCV_SHIPMENT_LINES rsl, PO.RCV_SHIPMENT_HEADERS rsh
                         -- mtl_system_items_b       msi -- ver 5.4 commented as per greg recommdation
                         WHERE     1 = 1
                               AND rsl.SHIPMENT_HEADER_ID =
                                   rsh.SHIPMENT_HEADER_ID
                               AND rt1.shipment_line_id =
                                   rsl.shipment_line_id
                               --AND rsl.ITEM_ID = msi.INVENTORY_ITEM_ID
                               --AND msi.organization_id = 106
                               AND rt1.transaction_type =
                                   DECODE (dtl.rcpt_type,
                                           'RECEIPT', 'RECEIVE',
                                           'ADJUST', 'CORRECT')
                               AND rt1.DESTINATION_TYPE_CODE = 'RECEIVING'
                               --and rsl.shipment_line_id=1692281
                               AND rsh.SHIPMENT_NUM = dtl.shipment_number
                               -- AND msi.segment1 = dtl.item_number
                               AND rt1.attribute6 = dtl.carton_id
                               AND apps.iid_to_sku (rsl.item_id) =
                                   dtl.item_number -- ver 5.4 Using function to get item_number rather than joining to MSI
                               AND rt1.quantity = dtl.qty);

        fnd_file.put_line (
            fnd_file.LOG,
               'Receipt Type : '
            || p_in_chr_rcpt_type
            || ' Duplicate in RCV table : '
            || SQL%ROWCOUNT);

        /***********************************************************************/
        /*Infosys Ver 5.0: Mark records for process only if record is not      */
        /*                   not exists in RCV                                 */
        /***********************************************************************/
        UPDATE xxdo_po_asn_receipt_dtl_stg dtl
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND rcpt_type = NVL (p_in_chr_rcpt_type, rcpt_type)
               AND shipment_number IS NOT NULL
               AND NOT EXISTS
                       (SELECT 1
                          FROM rcv_transactions rt1, PO.RCV_SHIPMENT_LINES rsl, PO.RCV_SHIPMENT_HEADERS rsh
                         -- mtl_system_items_b       msi  -- ver 5.4 commented as per greg recommdation
                         WHERE     1 = 1
                               AND rsl.SHIPMENT_HEADER_ID =
                                   rsh.SHIPMENT_HEADER_ID
                               AND rt1.shipment_line_id =
                                   rsl.shipment_line_id
                               --   AND rsl.ITEM_ID = msi.INVENTORY_ITEM_ID -- ver 5.4 commented as per greg recommdation
                               --AND msi.organization_id = 106 -- ver 5.4 commented as per greg recommdation
                               AND apps.iid_to_sku (rsl.item_id) =
                                   dtl.item_number -- ver 5.4 Using function to get item_number rather than joining to MSI
                               AND rt1.transaction_type =
                                   DECODE (dtl.rcpt_type,
                                           'RECEIPT', 'RECEIVE',
                                           'ADJUST', 'CORRECT')
                               AND rt1.DESTINATION_TYPE_CODE = 'RECEIVING'
                               --and rsl.shipment_line_id=1692281
                               AND rsh.SHIPMENT_NUM = dtl.shipment_number
                               --  AND msi.segment1 = dtl.item_number -- ver 5.4 commented as per greg recommdation
                               AND rt1.attribute6 = dtl.carton_id
                               AND rt1.quantity = dtl.qty)
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_po_asn_receipt_head_stg hdr
                         WHERE hdr.receipt_header_seq_id =
                               dtl.receipt_header_seq_id);



        p_out_num_record_count   := SQL%ROWCOUNT;
        fnd_file.put_line (
            fnd_file.LOG,
               'Receipt Type: '
            || p_in_chr_rcpt_type
            || ' Detail Update Count in Lock Procedure: '
            || SQL%ROWCOUNT);

        --Added for change 5.1 - START
        --Error out the records with decimal ASN qty(ASN qty should be a whole number)
        BEGIN
            UPDATE xxdo_po_asn_receipt_dtl_stg
               SET process_status = 'ERROR', error_message = 'QTY cannot have Decimals', last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND request_id = g_num_request_id
                   --AND TRUNC(qty) <> qty  --Decimal Check(Both Works)
                   AND MOD (qty, 1) <> 0           --Decimal Check(Both Works)
                   AND wh_id = NVL (p_in_chr_warehouse, wh_id)
                   AND rcpt_type = NVL (p_in_chr_rcpt_type, rcpt_type)
                   AND shipment_number IS NOT NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Unexpected error while Updating the records with Decimal QTY Error : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;

        --Added for change 5.1 - END

        UPDATE xxdo_po_asn_receipt_ser_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND shipment_number IS NOT NULL;

        COMMIT;
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
    -- Procedure/Function Name  :  get_inventory_item_id
    --
    -- Description              :  The purpose of this function is to derive the inventory item id for the given item number
    --
    -- parameters               :  p_in_chr_item_number IN : Item Number
    --
    -- Return/Exit              :  Inventory item id
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0      Initial Version
    -- 2015/01/06    Infosys            2.0      Modified for BT Remediation
    -- ***************************************************************************
    FUNCTION get_inventory_item_id (p_in_chr_item_number     IN VARCHAR2,
                                    p_in_num_master_org_id   IN NUMBER)
        RETURN NUMBER
    IS
        l_num_inventory_item_id   NUMBER;
    BEGIN
        SELECT msi.inventory_item_id
          INTO l_num_inventory_item_id
          FROM mtl_system_items_kfv msi, -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                                         mtl_parameters mp -- Added for BT Remediation
         WHERE     mp.organization_id = p_in_num_master_org_id -- Added for BT Remediation
               AND msi.concatenated_segments = p_in_chr_item_number
               AND msi.organization_id = mp.organization_id; -- Added for BT Remediation

        RETURN l_num_inventory_item_id;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END get_inventory_item_id;

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
    PROCEDURE upload_xml (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_inbound_directory IN VARCHAR2
                          , p_in_chr_file_name IN VARCHAR2)
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
        l_xml_doc           := XMLTYPE (l_clo_xml_doc);
        DBMS_LOB.freetemporary (l_clo_xml_doc);
        fnd_file.put_line (fnd_file.LOG,
                           'Loading the XML file into database');

        BEGIN
            -- Insert statement to upload the XML files
            INSERT INTO xxdo_po_asn_receipt_xml_stg (process_status,
                                                     xml_document,
                                                     file_name,
                                                     request_id,
                                                     created_by,
                                                     creation_date,
                                                     last_updated_by,
                                                     last_update_date,
                                                     asn_xml_seq_id)
                     VALUES ('NEW',
                             l_xml_doc,
                             p_in_chr_file_name,
                             fnd_global.conc_request_id,
                             fnd_global.user_id,
                             SYSDATE,
                             fnd_global.user_id,
                             SYSDATE,
                             xxdo_po_asn_receipt_xml_stg_s.NEXTVAL);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                       'Error while Inserting XML file into XML Staging table'
                    || SQLERRM;
                p_out_chr_retcode   := '2';
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

        IF l_chr_retcode = '2'
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'XML data is not loaded into database due to :'
                || l_chr_errbuf);
        ELSIF l_chr_retcode = '1'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        ELSE
            fnd_file.put_line (fnd_file.LOG,
                               'XML data is loaded into database');
        END IF;

        p_out_chr_retcode   := l_chr_retcode;
        p_out_chr_errbuf    := l_chr_errbuf;
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
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- ***************************************************************************
    PROCEDURE extract_xml_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER)
    IS
        l_num_request_id            NUMBER := fnd_global.conc_request_id;
        l_num_user_id               NUMBER := fnd_global.user_id;
        l_chr_xml_message_type      VARCHAR2 (30);
        l_chr_xml_environment       VARCHAR2 (30);
        l_chr_environment           VARCHAR2 (30);
        l_num_error_count           NUMBER := 0;
        l_asn_receipt_headers_tab   g_asn_receipt_headers_tab_type;
        l_asn_receipt_dtls_tab      g_asn_receipt_dtls_tab_type;
        l_carton_sers_tab           g_carton_sers_tab_type;
        l_exe_env_no_match          EXCEPTION;
        l_exe_msg_type_no_match     EXCEPTION;
        l_exe_bulk_fetch_failed     EXCEPTION;
        l_exe_bulk_insert_failed    EXCEPTION;
        l_exe_dml_errors            EXCEPTION;
        PRAGMA EXCEPTION_INIT (l_exe_dml_errors, -24381);
        l_chr_xml_message_id        VARCHAR2 (30);      --Added for change 5.1

        n_cnt                       NUMBER;                       --CCR0009292

        CURSOR cur_xml_file_counts IS
            SELECT ROWID row_id, file_name
              FROM xxdo_po_asn_receipt_xml_stg
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

        /*REQ_ID*/
        CURSOR cur_asn_receipt_headers IS
            SELECT EXTRACTVALUE (VALUE (par), 'Receipt/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'Receipt/appointment_id') appointment_id, TO_DATE (EXTRACTVALUE (VALUE (par), 'Receipt/receipt_date'), 'YYYY-MM-DD HH24:MI:SS') receipt_date,
                   EXTRACTVALUE (VALUE (par), 'Receipt/employee_id') employee_id, EXTRACTVALUE (VALUE (par), 'Receipt/employee_name') employee_name, 'NEW' process_status,
                   NULL error_message, l_num_request_id request_id, SYSDATE creation_date,
                   l_num_user_id created_by, SYSDATE last_update_date, l_num_user_id last_updated_by,
                   'ORDER' source_type, --NULL attribute1, --Commented for change 5.1
                                        l_chr_xml_message_id attribute1, --Added for change 5.1
                                                                         NULL attribute2,
                   NULL attribute3, NULL attribute4, NULL attribute5,
                   NULL attribute6, NULL attribute7, NULL attribute8,
                   NULL attribute9, NULL attribute10, NULL attribute11,
                   NULL attribute12, NULL attribute13, NULL attribute14,
                   NULL attribute15, NULL attribute16, NULL attribute17,
                   NULL attribute18, NULL attribute19, NULL attribute20,
                   'WMS' SOURCE, 'EBS' destination, 'INSERT' record_type,
                   xxdo_po_asn_receipt_head_s.NEXTVAL receipt_header_seq_id, NULL organization_id
              FROM xxdo_po_asn_receipt_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'ReceiptMessage/Receipts' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

        /*REQ_ID*/
        CURSOR cur_asn_receipt_dtls IS
            SELECT EXTRACTVALUE (VALUE (par), 'ReceiptDetail/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/appointment_id') appointment_id, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/shipment_number') shipment_number,
                   EXTRACTVALUE (VALUE (par), 'ReceiptDetail/po_number') po_number, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/carton_id') carton_id, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/line_number') line_number,
                   EXTRACTVALUE (VALUE (par), 'ReceiptDetail/item_number') item_number, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/rcpt_type') rcpt_type, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/qty') qty,
                   EXTRACTVALUE (VALUE (par), 'ReceiptDetail/ordered_uom') ordered_uom, EXTRACTVALUE (VALUE (par), 'ReceiptDetail/host_subinventory') host_subinventory, 'NEW' process_status,
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
                   NULL shipment_header_id, NULL po_header_id, NULL lpn_id,
                   NULL inventory_item_id, NULL receipt_header_seq_id, xxdo_po_asn_receipt_dtl_stg_s.NEXTVAL receipt_dtl_seq_id,
                   NULL organization_id, NULL receipt_source_code, NULL open_qty,
                   NULL po_line_id, NULL shipment_line_id, NULL requisition_header_id,
                   NULL requisition_line_id, NULL GROUP_ID, NULL org_id,
                   EXTRACTVALUE (VALUE (par), 'ReceiptDetail/locator') LOCATOR, NULL locator_id, NULL vendor_id
              FROM xxdo_po_asn_receipt_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'ReceiptMessage/Receipts/Receipt/ReceiptDetails' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

        /*REQ_ID*/
        CURSOR cur_serials IS
            SELECT EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/wh_id') wh_id, EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/appointment_id') appointment_id, EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/shipment_number') shipment_number,
                   EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/po_number') po_number, EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/carton_id') carton_id, EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/line_number') line_number,
                   EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/item_number') item_number, EXTRACTVALUE (VALUE (par), 'ReceiptDetailSerial/serial_number') serial_number, 'NEW' process_status,
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
                   NULL receipt_header_seq_id, NULL receipt_dtl_seq_id, xxdo_po_asn_receipt_ser_stg_s.NEXTVAL receipt_serial_seq_id
              FROM xxdo_po_asn_receipt_xml_stg xml_tab, TABLE (XMLSEQUENCE (EXTRACT (xml_tab.xml_document, (CHR (47) || CHR (47) || 'ReceiptMessage/Receipts/Receipt/ReceiptDetails/ReceiptDetail/ReceiptDetailSerials' || CHR (47) || CHR (42))))) par
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;
    /*REQ_ID*/
    BEGIN
        p_out_chr_retcode   := '0';
        p_out_chr_errbuf    := NULL;
        fnd_file.put_line (fnd_file.LOG,
                           'Starting the XML Specific validations');

        /*--CCR0009292 Commented as we are going to do the lookup in the reverse way due to multiple HJ instances per EBS Env
              -- Get the instance name from DBA view
              BEGIN
                 --SELECT NAME INTO l_chr_environment FROM v$database; --Commented for change 5.1
                 --Added query for change 5.1 --START
                 SELECT flv.description hj_instance
                   INTO l_chr_environment
                   FROM apps.fnd_lookup_values flv
                       ,v$database db
                  WHERE 1=1
                    AND flv.lookup_type = 'XXD_EBS_HJ_INSTANCE_MAP'
                    AND flv.language = 'US'
                    AND flv.enabled_flag = 'Y'
                    AND SYSDATE BETWEEN NVL(flv.start_date_active, SYSDATE) AND NVL(flv.end_date_active, SYSDATE)
                    AND flv.lookup_code = db.name
                 ;
                 --Added query for change 5.1 --END
              EXCEPTION
                 WHEN OTHERS
                 THEN
                    l_chr_environment := '-1';
              END;
              */
        --End CCR0009292

        fnd_file.put_line (fnd_file.LOG,
                           'Current Database name : ' || l_chr_environment);

        -- Get the message type and environment details from XML
        BEGIN
            SELECT                                --stg.xml_document.EXTRACT (
                   --   '//OutboundShipmentsMessage/MessageHeader/MessageType/text()').getstringval (), --Commented for change 5.1
                   --stg.xml_document.EXTRACT (
                   --   '//OutboundShipmentsMessage/MessageHeader/Environment/text()').getstringval () --Commented for change 5.1
                   stg.xml_document.EXTRACT ('//ReceiptMessage/MessageHeader/MessageType/text()').getstringval (), --Added for change 5.1
                                                                                                                   stg.xml_document.EXTRACT ('//ReceiptMessage/MessageHeader/Environment/text()').getstringval () --Added for change 5.1
                                                                                                                                                                                                                 , stg.xml_document.EXTRACT ('//ReceiptMessage/MessageHeader/MessageID/text()').getstringval () --Added for change 5.1
              INTO l_chr_xml_message_type, l_chr_xml_environment, l_chr_xml_message_id --Added for change 5.1
              FROM xxdo_po_asn_receipt_xml_stg stg
             WHERE     stg.process_status = 'NEW'
                   AND request_id = g_num_request_id;
        /*REQ_ID*/
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Evironment value in XML is not present due to Error'
                    || SQLERRM);
                l_chr_xml_message_type   := '-1';
                l_chr_xml_environment    := '-1';
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'Database name in XML: ' || l_chr_xml_environment);
        fnd_file.put_line (fnd_file.LOG,
                           'Message type in XML: ' || l_chr_xml_message_type);

        --Begin CCR0009292

        --Using the HJ instance from the XML check if there is a lookup record pointing to the current EBSENV
        SELECT COUNT (*)
          INTO n_cnt
          FROM apps.fnd_lookup_values flv, v$database db
         WHERE     1 = 1
               AND flv.lookup_type = 'XXD_EBS_HJ_INSTANCE_MAP'
               AND flv.language = 'US'
               AND flv.enabled_flag = 'Y'
               AND SYSDATE BETWEEN NVL (flv.start_date_active, SYSDATE)
                               AND NVL (flv.end_date_active, SYSDATE)
               AND flv.tag = db.name
               AND meaning = l_chr_xml_environment;

        --End End CCR0009292

        --  IF l_chr_environment <> l_chr_xml_environment
        IF n_cnt = 0                                              --CCR0009292
        THEN
            RAISE l_exe_env_no_match;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Environment Validation is Successful');

        IF l_chr_xml_message_type <> g_chr_asn_receipt_msg_type
        THEN
            RAISE l_exe_msg_type_no_match;
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Message Type Validation is Successful');
        -- Establish a save point
        -- If error at any stage, rollback to this save point
        SAVEPOINT l_sv_before_load_asn_xml;
        fnd_file.put_line (
            fnd_file.LOG,
            'l_sv_before_load_asn_xml - Savepoint Established');

        -- Logic to insert ASN Headers
        OPEN cur_asn_receipt_headers;

        LOOP
            IF l_asn_receipt_headers_tab.EXISTS (1)
            THEN
                l_asn_receipt_headers_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_asn_receipt_headers
                    BULK COLLECT INTO l_asn_receipt_headers_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_receipt_headers;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_asn_receipt_headers_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_asn_receipt_headers_tab.FIRST ..
                       l_asn_receipt_headers_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_po_asn_receipt_head_stg
                         VALUES l_asn_receipt_headers_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of ASN Receipt headers: '
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
                --                              CLOSE cur_asn_receipt_headers;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_receipt_headers;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of ASN Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;                                -- Receipt headers fetch loop

        CLOSE cur_asn_receipt_headers;

        -- Logic to insert ASN Details
        OPEN cur_asn_receipt_dtls;

        LOOP
            IF l_asn_receipt_dtls_tab.EXISTS (1)
            THEN
                l_asn_receipt_dtls_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_asn_receipt_dtls
                    BULK COLLECT INTO l_asn_receipt_dtls_tab
                    LIMIT p_in_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_receipt_dtls;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Details : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_asn_receipt_dtls_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            BEGIN
                FORALL l_num_ind
                    IN l_asn_receipt_dtls_tab.FIRST ..
                       l_asn_receipt_dtls_tab.LAST
                  SAVE EXCEPTIONS
                    INSERT INTO xxdo_po_asn_receipt_dtl_stg
                         VALUES l_asn_receipt_dtls_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of ASN Receipt Details: '
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
                --                              CLOSE cur_asn_receipt_dtls;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_receipt_headers;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of ASN Receipt Details: '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;                                -- Receipt details fetch loop

        CLOSE cur_asn_receipt_dtls;

        -- Logic to insert ASN Serials
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
                           'Unexcepted error in BULK Fetch of ASN Serials : '
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
                    INSERT INTO xxdo_po_asn_receipt_ser_stg
                         VALUES l_carton_sers_tab (l_num_ind);
            EXCEPTION
                WHEN l_exe_dml_errors
                THEN
                    l_num_error_count   := SQL%BULK_EXCEPTIONS.COUNT;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Number of statements that failed during Bulk Insert of ASN Serials: '
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
                --                              CLOSE cur_serials;
                --                              RAISE l_exe_bulk_insert_failed;
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_receipt_headers;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Insert of ASN Serials : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_insert_failed;
            END;
        END LOOP;                                -- Receipt details fetch loop

        CLOSE cur_serials;

        -- Update the XML file extract status and commit

        BEGIN
            UPDATE xxdo_po_asn_receipt_xml_stg
               SET process_status = 'PROCESSED', last_update_date = SYSDATE, last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to PROCESSED');
            -- Commit the status update along with all the inserts done before
            COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               'Commited the staging tables load');
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
                ROLLBACK TO l_sv_before_load_asn_xml;
        END;

        -- Logic to link the child records
        -- Update the details table

        BEGIN
            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET dtl.receipt_header_seq_id   =              --sequence Issue
                       (SELECT receipt_header_seq_id
                          FROM xxdo_po_asn_receipt_head_stg headers
                         WHERE     headers.request_id = g_num_request_id
                               AND headers.process_status = 'NEW'
                               AND headers.wh_id = dtl.wh_id
                               AND headers.appointment_id =
                                   dtl.appointment_id
                               AND ROWNUM < 2)
             WHERE     dtl.request_id = g_num_request_id
                   AND dtl.process_status = 'NEW';

            /***********************************************************************/
            /*Infosys Ver 5.0: Mark status to ERROR if unable to find suitable     */
            /*                   receipt header sequenc header id                  */
            /***********************************************************************/

            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET dtl.process_status = 'ERROR', dtl.error_message = 'RECEIPT_HEADER_SEQ_ID is NULL'
             WHERE     dtl.request_id = g_num_request_id
                   AND dtl.process_status = 'NEW'
                   AND dtl.receipt_header_seq_id IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'Unexpected error while updating the sequence ids in the ASN receipt details table : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                ROLLBACK TO l_sv_before_load_asn_xml;
        END;

        -- Update the serials table

        BEGIN
            UPDATE xxdo_po_asn_receipt_ser_stg ser
               SET (ser.receipt_header_seq_id, ser.receipt_dtl_seq_id)   =
                       (SELECT receipt_header_seq_id, receipt_dtl_seq_id
                          FROM xxdo_po_asn_receipt_dtl_stg dtl
                         WHERE     dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'NEW'
                               AND dtl.wh_id = ser.wh_id
                               AND dtl.appointment_id = ser.appointment_id
                               AND NVL (dtl.shipment_number, '-1') =
                                   NVL (ser.shipment_number, '-1')
                               AND NVL (dtl.po_number, '-1') =
                                   NVL (ser.po_number, '-1')
                               AND NVL (dtl.carton_id, '-1') =
                                   NVL (ser.carton_id, '-1')
                               AND dtl.line_number = ser.line_number
                               AND dtl.item_number = ser.item_number)
             WHERE     ser.request_id = g_num_request_id
                   AND ser.process_status = 'NEW';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '2';
                p_out_chr_errbuf    :=
                       'Unexpected error while updating the sequence ids in the ASN receipt serials table : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                ROLLBACK TO l_sv_before_load_asn_xml;
        END;

        -- Error out the records which don't have parent

        l_num_error_count   := 0;

        BEGIN
            UPDATE xxdo_po_asn_receipt_dtl_stg
               SET process_status = 'ERROR', error_message = 'No ASN Receipt Header Record in XML', last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     process_status = 'NEW'
                   AND request_id = g_num_request_id
                   AND receipt_header_seq_id IS NULL;

            l_num_error_count   := SQL%ROWCOUNT;

            UPDATE xxdo_po_asn_receipt_ser_stg
               SET process_status = 'ERROR', error_message = 'No ASN Receipt Detail Parent Record in XML', last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     process_status = 'NEW'
                   AND request_id = g_num_request_id
                   AND receipt_dtl_seq_id IS NULL;

            IF l_num_error_count = 0
            THEN
                l_num_error_count   := SQL%ROWCOUNT;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Unexpected error while Updating the records without parent : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        --                 ROLLBACK TO l_sv_before_load_asn_xml;
        END;

        IF l_num_error_count <> 0
        THEN
            p_out_chr_retcode   := '1';
            p_out_chr_errbuf    :=
                'There are detail or serial records without parent records in XML. Please review the XML';
        END IF;

        --Commit all the changes
        COMMIT;
    EXCEPTION
        WHEN l_exe_env_no_match
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := 'Environment name in XML is not correct';

            UPDATE xxdo_po_asn_receipt_xml_stg
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

            UPDATE xxdo_po_asn_receipt_xml_stg
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
            ROLLBACK TO l_sv_before_load_asn_xml;

            UPDATE xxdo_po_asn_receipt_xml_stg
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
            ROLLBACK TO l_sv_before_load_asn_xml;

            UPDATE xxdo_po_asn_receipt_xml_stg
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
            ROLLBACK TO l_sv_before_load_asn_xml;

            UPDATE xxdo_po_asn_receipt_xml_stg
               SET process_status = 'ERROR', error_message = p_out_chr_errbuf, last_update_date = SYSDATE,
                   last_updated_by = l_num_user_id
             WHERE process_status = 'NEW' AND request_id = g_num_request_id;

            fnd_file.put_line (fnd_file.LOG,
                               'Updated the process status to ERROR');
            -- Commit the status update
            COMMIT;
    END extract_xml_data;

    -- ***************************************************************************
    -- Procedure/Function Name  :  main
    --
    -- Description              :  This is the driver procedure which processes the receipts
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                p_in_chr_process_mode IN : Process mode - Process or Reprocess
    --                                p_in_chr_warehouse    IN  : Warehouse code
    --                                p_in_chr_shipment_no  IN  : Shipment number
    --                                p_in_chr_source       IN  : Source  - WMS
    --                                p_in_chr_dest         IN   : Destination  - EBS
    --                                p_in_num_purge_days   IN  : Purge days
    --                                p_in_num_bulk_limit   IN  : Bulk Limit
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- 2015/02/03    Infosys            2.0   Changing the process adjustment sequence
    -- ***************************************************************************

    PROCEDURE main (p_out_chr_errbuf             OUT VARCHAR2,
                    p_out_chr_retcode            OUT VARCHAR2,
                    p_in_chr_warehouse        IN     VARCHAR2,
                    p_in_chr_appointment_id   IN     VARCHAR2,
                    p_in_chr_source           IN     VARCHAR2,
                    p_in_chr_dest             IN     VARCHAR2,
                    p_in_num_purge_days       IN     NUMBER,
                    p_in_num_bulk_limit       IN     NUMBER)
    IS
        l_chr_errbuf              VARCHAR2 (4000);
        l_chr_retcode             VARCHAR2 (30);
        l_bol_req_status          BOOLEAN;
        l_chr_req_failure         VARCHAR2 (1) := 'N';
        l_chr_phase               VARCHAR2 (100) := NULL;
        l_chr_status              VARCHAR2 (100) := NULL;
        l_chr_dev_phase           VARCHAR2 (100) := NULL;
        l_chr_dev_status          VARCHAR2 (100) := NULL;
        l_chr_message             VARCHAR2 (1000) := NULL;
        l_num_group_id            NUMBER;
        l_num_record_count        NUMBER := 0;
        l_num_po_record_count     NUMBER := 0;
        l_chr_organization        VARCHAR2 (3) := NULL;
        l_org_ids_tab             g_ids_int_tab_type;
        l_request_ids_tab         g_ids_int_tab_type;
        l_exe_bulk_fetch_failed   EXCEPTION;
        l_exe_request_failure     EXCEPTION;
        l_exe_update_failure      EXCEPTION;
        l_exe_lock_err            EXCEPTION;
        l_exe_insert_asn_err      EXCEPTION;
        l_exe_adj_err             EXCEPTION;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        IF p_in_chr_warehouse IS NOT NULL
        THEN
            BEGIN                                                       -- 5.3
                SELECT organization_code
                  INTO l_chr_organization
                  FROM mtl_parameters
                 --WHERE organization_id = p_in_chr_warehouse;--5.3
                 --5.3 changes start
                 WHERE organization_code = p_in_chr_warehouse;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_chr_organization   := NULL;
            END;
        -- 5.3 changes end
        END IF;

        /*Commenting the process adjustment logic BEGIN*/
        -- Process the adjustments first
        /*    BEGIN
        process_corrections (
        p_out_chr_errbuf      => l_chr_errbuf,
        p_out_chr_retcode    => l_chr_retcode,
        p_in_chr_warehouse  => l_chr_organization );
        IF l_chr_retcode <> '0'
        THEN
        p_out_chr_errbuf :=
        'Error in Process corrections procedure : ' || l_chr_errbuf;
        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        RAISE l_exe_adj_err;
        END IF;
        EXCEPTION
        WHEN OTHERS
        THEN
        p_out_chr_errbuf :=
        'Unexpected error while invoking process corrections procedure : '
        || SQLERRM;
        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        RAISE l_exe_adj_err;
        END;
        */
        /*Commenting the process adjustment logic END*/
        -- Lock the records by updating the status to INPROCESS and request id to current request id
        BEGIN
            lock_records (
                p_out_chr_errbuf          => l_chr_errbuf,
                p_out_chr_retcode         => l_chr_retcode,
                p_in_chr_warehouse        => l_chr_organization,
                p_in_chr_appointment_id   => p_in_chr_appointment_id,
                p_in_chr_rcpt_type        => 'RECEIPT',
                p_out_num_record_count    => l_num_record_count);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf   :=
                    'Error in lock records procedure : ' || l_chr_errbuf;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_lock_err;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                       'Unexpected error while invoking lock records procedure : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_lock_err;
        END;

        IF NVL (l_num_record_count, 0) = 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no eligible ASN data in the staging table');
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Validating and Inserting the ASN Data into interface tables');

            BEGIN
                insert_asn_data (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_num_bulk_limit => p_in_num_bulk_limit
                                 , p_out_num_group_id => l_num_group_id);

                IF l_chr_retcode <> '0'
                THEN
                    p_out_chr_errbuf   :=
                           'Error in insert asn data  procedure : '
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_insert_asn_err;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf   :=
                           'Unexpected error while invoking insert asn data procedure : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_insert_asn_err;
            END;

            -- Get all the org ids into a table type variable
            BEGIN
                SELECT DISTINCT org_id
                  BULK COLLECT INTO l_org_ids_tab
                  FROM rcv_transactions_interface
                 WHERE GROUP_ID = l_num_group_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF l_org_ids_tab.EXISTS (1)
                    THEN
                        l_org_ids_tab.DELETE;
                    END IF;
            END;

            IF NOT l_org_ids_tab.EXISTS (1)
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no eligible records to launch the transaction processor');
            ELSE
                --Launch the transaction processor for each org
                fnd_file.put_line (fnd_file.LOG,
                                   'Launching the transaction processor');

                IF l_request_ids_tab.EXISTS (1)
                THEN
                    l_request_ids_tab.DELETE;
                END IF;

                FOR l_num_index IN 1 .. l_org_ids_tab.COUNT
                LOOP
                    l_request_ids_tab (l_num_index)   :=
                        fnd_request.submit_request (
                            application   => 'PO',
                            program       => 'RVCTP',
                            argument1     => 'BATCH',
                            argument2     => TO_CHAR (l_num_group_id),
                            argument3     =>
                                TO_CHAR (l_org_ids_tab (l_num_index)));
                    COMMIT;

                    IF l_request_ids_tab (l_num_index) = 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Org Id :  '
                            || l_org_ids_tab (l_num_index)
                            || '  Transaction Processor is not launched');
                        p_out_chr_retcode   := '1';
                        p_out_chr_errbuf    :=
                            'Transaction Processor is not launched for one or more org ids. Please refer the log file for more details';
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Org Id :  '
                            || l_org_ids_tab (l_num_index)
                            || '  Transaction Processor request id : '
                            || l_request_ids_tab (l_num_index));
                    END IF;
                END LOOP;

                COMMIT;
                l_chr_req_failure   := 'N';
                fnd_file.put_line (fnd_file.LOG, '');
                fnd_file.put_line (
                    fnd_file.LOG,
                    '-------------Concurrent Requests Status Report ---------------');

                FOR l_num_index IN 1 .. l_request_ids_tab.COUNT
                LOOP
                    l_bol_req_status   :=
                        fnd_concurrent.wait_for_request (
                            l_request_ids_tab (l_num_index),
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
                        || l_request_ids_tab (l_num_index)
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
                        'One or more Transaction Processor requests ended in Warning or Error. Please refer the log file for more details';
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Updating the process status of the records ');

                -- Update the failed ASN lines records
                BEGIN
                    UPDATE xxdo_po_asn_receipt_dtl_stg dtl
                       SET (dtl.error_message, dtl.process_status, dtl.last_updated_by
                            , dtl.last_update_date)   =
                               (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                                       SYSDATE
                                  FROM po_interface_errors pie, rcv_transactions_interface rti
                                 WHERE     1 = 1
                                       --AND pie.interface_line_id = rti.interface_transaction_id--Commented for change 5.1
                                       AND pie.interface_line_id(+) =
                                           rti.interface_transaction_id --Added for change 5.1(Added outer join on pie)
                                       AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                       AND rti.shipment_header_id =
                                           dtl.shipment_header_id
                                       AND rti.shipment_line_id =
                                           dtl.shipment_line_id
                                       AND dtl.GROUP_ID = rti.GROUP_ID
                                       AND ROWNUM < 2)
                     WHERE     dtl.process_status = 'INPROCESS'
                           AND dtl.shipment_number IS NOT NULL
                           AND dtl.rcpt_type = 'RECEIPT'
                           AND dtl.request_id = g_num_request_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM po_interface_errors pie, rcv_transactions_interface rti
                                     WHERE     1 = 1
                                           --AND pie.interface_line_id = rti.interface_transaction_id --Commented for change 5.1
                                           AND pie.interface_line_id(+) =
                                               rti.interface_transaction_id --Added for change 5.1(Added outer join on pie)
                                           AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                           AND rti.shipment_header_id =
                                               dtl.shipment_header_id
                                           AND rti.shipment_line_id =
                                               dtl.shipment_line_id
                                           AND dtl.GROUP_ID = rti.GROUP_ID);

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Receipt Type: ASN RECEIPT Detail ERROR Update Count in Main Procedure : '
                        || SQL%ROWCOUNT);

                    /***********************************************************************/
                    /*Infosys Ver 5.0: Add Rcv header interface error details              */
                    /***********************************************************************/

                    UPDATE xxdo_po_asn_receipt_dtl_stg dtl
                       SET (dtl.error_message, dtl.process_status, dtl.last_updated_by
                            , dtl.last_update_date)   =
                               (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                                       SYSDATE
                                  FROM po_interface_errors pie, rcv_transactions_interface rti
                                 WHERE     1 = 1
                                       --AND pie.interface_header_id = rti.header_interface_id --Commented for change 5.1
                                       AND pie.interface_header_id(+) =
                                           rti.header_interface_id --Added for change 5.1(Added outer join on pie)
                                       AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                       AND rti.shipment_header_id =
                                           dtl.shipment_header_id
                                       AND rti.shipment_line_id =
                                           dtl.shipment_line_id
                                       AND dtl.GROUP_ID = rti.GROUP_ID
                                       AND ROWNUM < 2)
                     WHERE     dtl.process_status = 'INPROCESS'
                           AND dtl.shipment_number IS NOT NULL
                           AND dtl.rcpt_type = 'RECEIPT'
                           AND dtl.request_id = g_num_request_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM po_interface_errors pie, rcv_transactions_interface rti
                                     WHERE     1 = 1
                                           --AND pie.interface_header_id = rti.header_interface_id --Commented for change 5.1
                                           AND pie.interface_header_id(+) =
                                               rti.header_interface_id --Added for change 5.1(Added outer join on pie)
                                           AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                           AND rti.shipment_header_id =
                                               dtl.shipment_header_id
                                           AND rti.shipment_line_id =
                                               dtl.shipment_line_id
                                           AND dtl.GROUP_ID = rti.GROUP_ID);

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Receipt Type: ASN RECEIPT Header ERROR Update Count in Main Procedure : '
                        || SQL%ROWCOUNT);



                    UPDATE xxdo_po_asn_receipt_ser_stg serial
                       SET serial.process_status = 'ERROR', serial.last_updated_by = g_num_user_id, serial.last_update_date = SYSDATE
                     WHERE     serial.process_status = 'INPROCESS'
                           AND serial.request_id = g_num_request_id
                           AND serial.receipt_dtl_seq_id IN
                                   (SELECT dtl.receipt_dtl_seq_id
                                      FROM xxdo_po_asn_receipt_dtl_stg dtl
                                     WHERE     dtl.request_id =
                                               g_num_request_id
                                           AND dtl.shipment_number
                                                   IS NOT NULL
                                           AND dtl.rcpt_type = 'RECEIPT'
                                           AND dtl.process_status = 'ERROR');

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Receipt Type: ASN RECEIPT Serial ERROR Update Count in Main Procedure : '
                        || SQL%ROWCOUNT);

                    /*
                    -- Update the processed ASN lines records
                    UPDATE xxdo_po_asn_receipt_dtl_stg dtl
                    SET dtl.process_status = 'PROCESSED'
                    WHERE dtl.process_status = 'INPROCESS'
                    AND dtl.request_id = g_num_request_id;

                               -- Update the failed ASN receipt header records
                    UPDATE xxdo_po_asn_receipt_head_stg head
                    SET head.process_status = 'ERROR'
                    WHERE head.process_status = 'INPROCESS'
                    AND head.request_id = g_num_request_id
                    AND EXISTS (
                    SELECT 1
                    FROM xxdo_po_asn_receipt_dtl_stg dtl
                    WHERE dtl.receipt_header_seq_id =
                    head.receipt_header_seq_id
                    AND dtl.request_id = g_num_request_id
                    AND dtl.process_status = 'ERROR');
                    -- Update the processed records
                    UPDATE xxdo_po_asn_receipt_head_stg head
                    SET head.process_status = 'PROCESSED'
                    WHERE head.process_status = 'INPROCESS'
                    AND head.request_id = g_num_request_id;
                    */
                    /* 9/15 delete error records from receiving interface */
                    /*Start of DELETE_TRAN*/
                    /***********************************************************************/
                    /*Infosys Ver 5.0: Add delete for both header and line level errors    */
                    /***********************************************************************/

                    DELETE FROM
                        po_interface_errors pie
                          WHERE pie.interface_line_id IN
                                    (SELECT rti.interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE     1 = 1
                                            AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                            AND rti.GROUP_ID IN
                                                    (SELECT x.GROUP_ID
                                                       FROM xxdo_po_asn_receipt_dtl_stg x
                                                      WHERE     x.process_status =
                                                                'ERROR'
                                                            AND x.request_id =
                                                                g_num_request_id));

                    DELETE FROM
                        po_interface_errors pie
                          WHERE pie.interface_header_id IN
                                    (SELECT rti.header_interface_id
                                       FROM rcv_transactions_interface rti
                                      WHERE     1 = 1
                                            AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                            AND rti.GROUP_ID IN
                                                    (SELECT x.GROUP_ID
                                                       FROM xxdo_po_asn_receipt_dtl_stg x
                                                      WHERE     x.process_status =
                                                                'ERROR'
                                                            AND x.request_id =
                                                                g_num_request_id));



                    DELETE FROM
                        rcv_headers_interface rhi
                          WHERE rhi.header_interface_id IN
                                    (SELECT rti.header_interface_id
                                       FROM rcv_transactions_interface rti
                                      WHERE     1 = 1
                                            AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                            AND rti.GROUP_ID IN
                                                    (SELECT x.GROUP_ID
                                                       FROM xxdo_po_asn_receipt_dtl_stg x
                                                      WHERE     x.process_status =
                                                                'ERROR'
                                                            AND x.request_id =
                                                                g_num_request_id));

                    DELETE FROM
                        rcv_transactions_interface rti
                          WHERE     (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                AND rti.GROUP_ID IN
                                        (SELECT x.GROUP_ID
                                           FROM xxdo_po_asn_receipt_dtl_stg x
                                          WHERE     x.process_status =
                                                    'ERROR'
                                                AND x.request_id =
                                                    g_num_request_id);


                    COMMIT;
                    /*End of DELETE_TRAN*/
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_errbuf   :=
                               'Unexpected error while updating the process status : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RAISE l_exe_update_failure;
                END;
            END IF;                              -- checking the org ids table
        END IF;                    -- checking the lock records - record count

        /*******************
        ***** PO receiving ****
        ******************/
        -- Lock the records by updating the status to INPROCESS and request id to current request id
        BEGIN
            lock_po_records (
                p_out_chr_errbuf          => l_chr_errbuf,
                p_out_chr_retcode         => l_chr_retcode,
                p_in_chr_warehouse        => l_chr_organization,
                p_in_chr_appointment_id   => p_in_chr_appointment_id,
                p_in_chr_rcpt_type        => 'RECEIPT',
                p_out_num_record_count    => l_num_po_record_count);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf   :=
                       'Error in lock records procedure while locking PO records : '
                    || l_chr_errbuf;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_lock_err;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                       'Unexpected error while invoking lock records procedure : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_lock_err;
        END;

        IF NVL (l_num_po_record_count, 0) = 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no eligible PO data in the staging table');
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                'Validating and Inserting the PO Data into interface tables');

            BEGIN
                insert_po_data (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_num_bulk_limit => p_in_num_bulk_limit
                                , p_out_num_group_id => l_num_group_id);

                IF l_chr_retcode <> '0'
                THEN
                    p_out_chr_errbuf   :=
                           'Error in insert PO data  procedure : '
                        || l_chr_errbuf;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_insert_asn_err;
                END IF;
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf   :=
                           'Unexpected error while invoking insert PO data procedure : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_insert_asn_err;
            END;

            IF l_org_ids_tab.EXISTS (1)
            THEN
                l_org_ids_tab.DELETE;
            END IF;

            -- Get all the org ids into a table type variable
            BEGIN
                SELECT DISTINCT org_id
                  BULK COLLECT INTO l_org_ids_tab
                  FROM rcv_transactions_interface
                 WHERE GROUP_ID = l_num_group_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    IF l_org_ids_tab.EXISTS (1)
                    THEN
                        l_org_ids_tab.DELETE;
                    END IF;
            END;

            IF NOT l_org_ids_tab.EXISTS (1)
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'There are no eligible PO records to launch the transaction processor');
            ELSE
                --Launch the transaction processor for each org
                fnd_file.put_line (fnd_file.LOG,
                                   'Launching the transaction processor');

                IF l_request_ids_tab.EXISTS (1)
                THEN
                    l_request_ids_tab.DELETE;
                END IF;

                FOR l_num_index IN 1 .. l_org_ids_tab.COUNT
                LOOP
                    l_request_ids_tab (l_num_index)   :=
                        fnd_request.submit_request (
                            application   => 'PO',
                            program       => 'RVCTP',
                            argument1     => 'BATCH',
                            argument2     => TO_CHAR (l_num_group_id),
                            argument3     =>
                                TO_CHAR (l_org_ids_tab (l_num_index)));
                    COMMIT;

                    IF l_request_ids_tab (l_num_index) = 0
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Org Id :  '
                            || l_org_ids_tab (l_num_index)
                            || '  Transaction Processor is not launched');
                        p_out_chr_retcode   := '1';
                        p_out_chr_errbuf    :=
                            'Transaction Processor is not launched for one or more org ids. Please refer the log file for more details';
                    ELSE
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Org Id :  '
                            || l_org_ids_tab (l_num_index)
                            || '  Transaction Processor request id : '
                            || l_request_ids_tab (l_num_index));
                    END IF;
                END LOOP;

                COMMIT;
                l_chr_req_failure   := 'N';
                fnd_file.put_line (fnd_file.LOG, '');
                fnd_file.put_line (
                    fnd_file.LOG,
                    '-------------Concurrent Requests Status Report ---------------');

                FOR l_num_index IN 1 .. l_request_ids_tab.COUNT
                LOOP
                    l_bol_req_status   :=
                        fnd_concurrent.wait_for_request (
                            l_request_ids_tab (l_num_index),
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
                        || l_request_ids_tab (l_num_index)
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
                        'One or more Transaction Processor requests ended in Warning or Error. Please refer the log file for more details';
                END IF;

                fnd_file.put_line (
                    fnd_file.LOG,
                    'Updating the process status of the records ');

                -- Update the failed PO lines records
                BEGIN
                    UPDATE xxdo_po_asn_receipt_dtl_stg dtl
                       SET (dtl.error_message, dtl.process_status, dtl.last_updated_by
                            , dtl.last_update_date)   =
                               (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                                       SYSDATE
                                  FROM po_interface_errors pie, rcv_transactions_interface rti
                                 WHERE     1 = 1
                                       --AND pie.interface_line_id = rti.interface_transaction_id --Commented for change 5.1
                                       AND pie.interface_line_id(+) =
                                           rti.interface_transaction_id --Added for change 5.1(Added outer join on pie)
                                       AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                       AND rti.po_header_id =
                                           dtl.po_header_id
                                       AND rti.po_line_id = dtl.po_line_id
                                       AND dtl.GROUP_ID = rti.GROUP_ID
                                       AND ROWNUM < 2)
                     WHERE     dtl.process_status = 'INPROCESS'
                           AND dtl.shipment_number IS NULL
                           AND dtl.rcpt_type = 'RECEIPT'
                           AND dtl.request_id = g_num_request_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM po_interface_errors pie, rcv_transactions_interface rti
                                     WHERE     1 = 1
                                           --AND pie.interface_line_id = rti.interface_transaction_id --Commented for change 5.1
                                           AND pie.interface_line_id(+) =
                                               rti.interface_transaction_id --Added for change 5.1(Added outer join on pie)
                                           AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                           AND rti.po_header_id =
                                               dtl.po_header_id
                                           AND rti.po_line_id =
                                               dtl.po_line_id
                                           AND dtl.GROUP_ID = rti.GROUP_ID);

                    UPDATE xxdo_po_asn_receipt_dtl_stg dtl
                       SET (dtl.error_message, dtl.process_status, dtl.last_updated_by
                            , dtl.last_update_date)   =
                               (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                                       SYSDATE
                                  FROM po_interface_errors pie, rcv_transactions_interface rti
                                 WHERE     1 = 1
                                       --AND pie.interface_header_id = rti.header_interface_id --Commented for change 5.1
                                       AND pie.interface_header_id(+) =
                                           rti.header_interface_id --Added for change 5.1(Added outer join on pie)
                                       AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                       AND rti.shipment_header_id =
                                           dtl.shipment_header_id
                                       AND rti.shipment_line_id =
                                           dtl.shipment_line_id
                                       AND dtl.GROUP_ID = rti.GROUP_ID
                                       AND ROWNUM < 2)
                     WHERE     dtl.process_status = 'INPROCESS'
                           AND dtl.shipment_number IS NULL
                           AND dtl.rcpt_type = 'RECEIPT'
                           AND dtl.request_id = g_num_request_id
                           AND EXISTS
                                   (SELECT 1
                                      FROM po_interface_errors pie, rcv_transactions_interface rti
                                     WHERE     1 = 1
                                           --AND pie.interface_header_id = rti.header_interface_id --Commented for change 5.1
                                           AND pie.interface_header_id(+) =
                                               rti.header_interface_id --Added for change 5.1(Added outer join on pie)
                                           AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                           AND rti.shipment_header_id =
                                               dtl.shipment_header_id
                                           AND rti.shipment_line_id =
                                               dtl.shipment_line_id
                                           AND dtl.GROUP_ID = rti.GROUP_ID);

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Receipt Type: ASN RECEIPT Header ERROR Update Count in Main Procedure : '
                        || SQL%ROWCOUNT);

                    DELETE FROM
                        po_interface_errors pie
                          WHERE pie.interface_line_id IN
                                    (SELECT rti.interface_transaction_id
                                       FROM rcv_transactions_interface rti
                                      WHERE     1 = 1
                                            AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                            AND rti.GROUP_ID IN
                                                    (SELECT x.GROUP_ID
                                                       FROM xxdo_po_asn_receipt_dtl_stg x
                                                      WHERE     x.process_status =
                                                                'ERROR'
                                                            AND x.request_id =
                                                                g_num_request_id));

                    DELETE FROM
                        po_interface_errors pie
                          WHERE pie.interface_header_id IN
                                    (SELECT rti.header_interface_id
                                       FROM rcv_transactions_interface rti
                                      WHERE     1 = 1
                                            AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                            AND rti.GROUP_ID IN
                                                    (SELECT x.GROUP_ID
                                                       FROM xxdo_po_asn_receipt_dtl_stg x
                                                      WHERE     x.process_status =
                                                                'ERROR'
                                                            AND x.request_id =
                                                                g_num_request_id));



                    DELETE FROM
                        rcv_headers_interface rhi
                          WHERE rhi.header_interface_id IN
                                    (SELECT rti.header_interface_id
                                       FROM rcv_transactions_interface rti
                                      WHERE     1 = 1
                                            AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                            AND rti.GROUP_ID IN
                                                    (SELECT x.GROUP_ID
                                                       FROM xxdo_po_asn_receipt_dtl_stg x
                                                      WHERE     x.process_status =
                                                                'ERROR'
                                                            AND x.request_id =
                                                                g_num_request_id));

                    DELETE FROM
                        rcv_transactions_interface rti
                          WHERE     (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                AND rti.GROUP_ID IN
                                        (SELECT x.GROUP_ID
                                           FROM xxdo_po_asn_receipt_dtl_stg x
                                          WHERE     x.process_status =
                                                    'ERROR'
                                                AND x.request_id =
                                                    g_num_request_id);

                    /*Ver 5.0: End of change*/
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Receipt Type: PO RECEIPT Detail ERROR Update Count in Main Procedure : '
                        || SQL%ROWCOUNT);

                    UPDATE xxdo_po_asn_receipt_ser_stg serial
                       SET serial.process_status = 'ERROR', serial.last_updated_by = g_num_user_id, serial.last_update_date = SYSDATE
                     WHERE     serial.process_status = 'INPROCESS'
                           AND serial.request_id = g_num_request_id
                           AND serial.receipt_dtl_seq_id IN
                                   (SELECT dtl.receipt_dtl_seq_id
                                      FROM xxdo_po_asn_receipt_dtl_stg dtl
                                     WHERE     dtl.request_id =
                                               g_num_request_id
                                           AND dtl.shipment_number IS NULL
                                           AND dtl.rcpt_type = 'RECEIPT'
                                           AND dtl.process_status = 'ERROR');

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Receipt Type: PO RECEIPT Serial ERROR Update Count in Main Procedure : '
                        || SQL%ROWCOUNT);
                    COMMIT;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_errbuf   :=
                               'Unexpected error while updating the process status : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RAISE l_exe_update_failure;
                END;
            END IF;                              -- checking the org ids table
        END IF;                    -- checking the lock records - record count

        --- Update the processed records
        IF l_num_record_count <> 0 OR l_num_po_record_count <> 0
        THEN
            -- Update the processed ASN lines records
            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET dtl.process_status = 'PROCESSED', dtl.last_updated_by = g_num_user_id, dtl.last_update_date = SYSDATE
             WHERE     dtl.process_status = 'INPROCESS' /*Added condition for Receipt type Begin*/
                   AND dtl.rcpt_type = 'RECEIPT' /*Added condition for Receipt type End */
                   AND dtl.request_id = g_num_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM rcv_transactions rt1, po.rcv_shipment_lines rsl, po.rcv_shipment_headers rsh,
                                   mtl_system_items_b msi
                             WHERE     1 = 1
                                   AND rsl.shipment_header_id =
                                       rsh.shipment_header_id
                                   AND rt1.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND rsl.item_id = msi.inventory_item_id
                                   AND msi.organization_id = 106
                                   AND rt1.transaction_type =
                                       DECODE (dtl.rcpt_type,
                                               'RECEIPT', 'RECEIVE',
                                               'ADJUST', 'CORRECT')
                                   AND rt1.destination_type_code =
                                       'RECEIVING'
                                   --and rsl.shipment_line_id=1692281
                                   AND rsh.shipment_num = dtl.shipment_number
                                   AND msi.segment1 = dtl.item_number
                                   AND rt1.attribute6 = dtl.carton_id
                                   AND rt1.quantity = dtl.qty);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Receipt Type: RECEIPT Detail PROCESSED Update Count in Main Procedure : '
                || SQL%ROWCOUNT);

            UPDATE xxdo_po_asn_receipt_ser_stg serial
               SET serial.process_status = 'PROCESSED', serial.last_updated_by = g_num_user_id, serial.last_update_date = SYSDATE
             WHERE     serial.process_status = 'INPROCESS'
                   AND serial.request_id = g_num_request_id
                   AND serial.receipt_dtl_seq_id IN
                           (SELECT dtl.receipt_dtl_seq_id
                              FROM xxdo_po_asn_receipt_dtl_stg dtl
                             WHERE     dtl.request_id = g_num_request_id
                                   AND dtl.process_status = 'PROCESSED');

            fnd_file.put_line (
                fnd_file.LOG,
                   'Receipt Type: RECEIPT Serial PROCESSED Update Count in Main Procedure : '
                || SQL%ROWCOUNT);
        END IF;

        --Added for change 5.1 --START
        --Mark the leftover ASN lines(rcpt_type = RECEIPT)) which are still in INPROCESS status to ERROR
        -- Update the INPROCESS status ASN lines records to ERROR after marking the INPROCESS to PROCESSED
        UPDATE xxdo_po_asn_receipt_dtl_stg dtl
           SET dtl.process_status = 'ERROR', dtl.last_updated_by = g_num_user_id, dtl.last_update_date = SYSDATE
         WHERE     dtl.process_status = 'INPROCESS'
               AND dtl.rcpt_type = 'RECEIPT'
               AND dtl.request_id = g_num_request_id;

        fnd_file.put_line (
            fnd_file.LOG,
               'Receipt Type: RECEIPT Detail - Marking INPROCESS to ERROR Update Count in Main Procedure : '
            || SQL%ROWCOUNT);

        UPDATE xxdo_po_asn_receipt_ser_stg serial
           SET serial.process_status = 'ERROR', serial.last_updated_by = g_num_user_id, serial.last_update_date = SYSDATE
         WHERE     1 = 1
               AND serial.process_status = 'INPROCESS'
               AND serial.request_id = g_num_request_id
               AND serial.receipt_dtl_seq_id IN
                       (SELECT dtl.receipt_dtl_seq_id
                          FROM xxdo_po_asn_receipt_dtl_stg dtl
                         WHERE     1 = 1
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'ERROR'
                               AND dtl.rcpt_type = 'RECEIPT');

        fnd_file.put_line (
            fnd_file.LOG,
               'Receipt Type: RECEIPT Serial - Marking INPROCESS to ERROR Update Count in Main Procedure : '
            || SQL%ROWCOUNT);

        --Added for change 5.1 --END

        /*Logic for processing the adjustments Begin*/
        -- Process the adjustments at the end
        BEGIN
            process_corrections (p_out_chr_errbuf     => l_chr_errbuf,
                                 p_out_chr_retcode    => l_chr_retcode,
                                 p_in_chr_warehouse   => l_chr_organization);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf   :=
                       'Error in Process corrections procedure : '
                    || l_chr_errbuf;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_adj_err;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                       'Unexpected error while invoking process corrections procedure : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_adj_err;
        END;

        /*Logic for processing the adjustments End*/
        -- Update the failed ASN receipt header records
        UPDATE xxdo_po_asn_receipt_head_stg head
           SET head.process_status   = 'ERROR'
         WHERE     head.process_status = 'INPROCESS'
               AND head.request_id = g_num_request_id
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_po_asn_receipt_dtl_stg dtl
                         WHERE     dtl.receipt_header_seq_id =
                                   head.receipt_header_seq_id
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status IN
                                       ('ERROR', 'DUPLICATE'));

        fnd_file.put_line (
            fnd_file.LOG,
            'Header ERROR Update Count in Main Procedure : ' || SQL%ROWCOUNT);

        -- Update the processed records
        UPDATE xxdo_po_asn_receipt_head_stg head
           SET head.process_status = 'PROCESSED', head.last_updated_by = g_num_user_id, head.last_update_date = SYSDATE
         WHERE     head.process_status = 'INPROCESS'
               AND head.request_id = g_num_request_id
               /*Condition for checking Processed records Begin*/
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_po_asn_receipt_dtl_stg dtl
                         WHERE     dtl.receipt_header_seq_id =
                                   head.receipt_header_seq_id
                               AND dtl.request_id = g_num_request_id
                               AND dtl.process_status = 'PROCESSED');

        /*Condition for checking Processed records End*/
        fnd_file.put_line (
            fnd_file.LOG,
               'PROCESSED Header Update Count in Main Procedure: '
            || SQL%ROWCOUNT);

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
        WHEN l_exe_request_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_update_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_lock_err
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_adj_err
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
    -- Procedure/Function Name  :  insert_asn_data
    --
    -- Description              :  This purpose of this procedure is to validate the asn receipt data and insert into the interface tables
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                p_in_chr_warehouse    IN  : Warehouse code
    --
    --                                p_in_chr_shipment_no  IN  : Shipment number
    --                                p_in_num_purge_days   IN  : Purge days
    --                                p_in_num_bulk_limit   IN  : Bulk Limit
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/25    Infosys            1.0   Initial Version
    -- 2021/11/22    Showkath Ali       1.1   CCR0009689
    -- ***************************************************************************

    PROCEDURE insert_asn_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER
                               , p_out_num_group_id OUT NUMBER)
    IS
        l_chr_errbuf                 VARCHAR2 (4000);
        l_chr_retcode                VARCHAR2 (30);
        l_chr_err_shipment_number    VARCHAR2 (60) := '-1';
        l_num_err_head_seq_id        NUMBER := -1;
        l_chr_asn_line_exists        VARCHAR2 (1) := 'N';
        l_chr_prev_shipment_number   VARCHAR2 (60) := '-1';
        l_num_group_id               NUMBER;
        l_num_header_inf_id          NUMBER;
        l_num_deliver                NUMBER;
        l_chr_trx_type               VARCHAR2 (20);
        l_chr_source_document_code   VARCHAR2 (30);
        l_exe_warehouse_err          EXCEPTION;
        l_exe_asn_err                EXCEPTION;
        l_exe_item_err               EXCEPTION;
        l_exe_qty_err                EXCEPTION;
        l_exe_subinv_err             EXCEPTION;
        l_exe_item_line_no_err       EXCEPTION;
        l_exe_uom_err                EXCEPTION;
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_locator_err            EXCEPTION;

        CURSOR cur_inv_arg_attributes IS
            SELECT flv.lookup_code organization_code, mp.attribute15 lpn_receiving, mp.attribute12 partial_asn,
                   mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.lookup_code
                   AND mp.organization_code IN
                           (SELECT wh_id
                              FROM xxdo_po_asn_receipt_head_stg
                             WHERE request_id = g_num_request_id);

        CURSOR cur_sub_inventories (p_num_organization_id IN NUMBER)
        IS
            SELECT secondary_inventory_name subinventory
              FROM mtl_secondary_inventories
             WHERE organization_id = p_num_organization_id;

        CURSOR cur_asn_details IS
              SELECT headers.receipt_header_seq_id, headers.wh_id, headers.receipt_date,
                     headers.employee_id, mp.organization_id, dtl.receipt_dtl_seq_id,
                     dtl.shipment_number, dtl.po_number, dtl.line_number,
                     dtl.item_number, get_inventory_item_id (dtl.item_number, mp.master_organization_id) inventory_item_id, -- Modified for BT Remediation
                                                                                                                            dtl.rcpt_type,
                     dtl.qty, dtl.ordered_uom, dtl.host_subinventory,
                     dtl.carton_id, NULL receipt_source_code, NULL shipment_header_id,
                     NULL ebs_shipment_number, NULL vendor_id, dtl.LOCATOR,
                     NULL locator_id
                FROM xxdo_po_asn_receipt_head_stg headers, xxdo_po_asn_receipt_dtl_stg dtl, mtl_parameters mp
               WHERE     headers.receipt_header_seq_id =
                         dtl.receipt_header_seq_id
                     AND headers.request_id = g_num_request_id
                     AND headers.process_status = 'INPROCESS'
                     AND dtl.process_status = 'INPROCESS'
                     AND headers.wh_id = mp.organization_code
                     AND dtl.shipment_number IS NOT NULL --  /* PO_Receiving */
                     AND dtl.rcpt_type = 'RECEIPT'
            ORDER BY dtl.shipment_number, dtl.po_number, dtl.line_number,
                     headers.receipt_date;                      --MULTIPLE_NEG

        /*SELECT headers.receipt_header_seq_id,
        headers.wh_id,
        headers.receipt_date,
        headers.employee_id,
        mp.organization_id,
        dtl.receipt_dtl_seq_id,
        dtl.shipment_number,
        dtl.po_number,
        dtl.carton_id,
        dtl.line_number,
        dtl.item_number,
        get_inventory_item_id (dtl.item_number,mp.master_organization_id) inventory_item_id,        -- Modified for BT Remediation
        dtl.rcpt_type,
        dtl.qty,
        dtl.ordered_uom,
        dtl.host_subinventory,
        rsh.receipt_source_code,
        rsh.shipment_header_id,
        rsh.shipment_num ebs_shipment_number,
        rsh.vendor_id
        FROM xxdo_po_asn_receipt_head_stg headers,
        xxdo_po_asn_receipt_dtl_stg dtl,
        rcv_shipment_headers rsh,
        mtl_parameters mp
        WHERE headers.receipt_header_seq_id = dtl.receipt_header_seq_id
        AND headers.wh_id = mp.organization_code
        AND dtl.shipment_number = rsh.shipment_num(+)
        AND mp.organization_id = rsh.ship_to_org_id
        AND headers.request_id = g_num_request_id
        AND headers.process_status = 'INPROCESS'
        ORDER BY dtl.shipment_number, dtl.po_number;
        */
        TYPE l_asn_details_tab_type IS TABLE OF cur_asn_details%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_asn_details_tab            l_asn_details_tab_type;

        CURSOR cur_ebs_shipment_lines (p_num_shipment_header_id IN NUMBER, p_chr_receipt_source_code IN VARCHAR2, p_num_line_number IN NUMBER
                                       , p_num_item_id IN NUMBER)
        IS
            SELECT DISTINCT pha.org_id, rsl.shipment_line_status_code, rsl.quantity_shipped,
                            rsl.quantity_received, --    rsl.unit_of_measure, -- Commented by Infosys , CRP Issue 25122014
                                                   muom.uom_code unit_of_measure, -- Added by Infosys , CRP Issue 25122014
                                                                                  rsl.locator_id,
                            rsl.deliver_to_location_id, pha.po_header_id, pla.po_line_id,
                            NULL req_header_id, NULL req_line_id, rsl.shipment_line_id,
                            rsl.from_organization_id, rsl.to_organization_id, rsl.req_distribution_id,
                            rsl.deliver_to_person_id, rsl.source_document_code
              FROM rcv_shipment_lines rsl, po_line_locations_all plla, po_lines_all pla,
                   po_headers_all pha, mtl_units_of_measure muom
             WHERE     rsl.shipment_header_id = p_num_shipment_header_id
                   AND rsl.line_num = p_num_line_number
                   AND rsl.item_id = p_num_item_id
                   AND rsl.po_line_location_id = plla.line_location_id
                   AND plla.po_header_id = pha.po_header_id
                   AND plla.po_line_id = pla.po_line_id
                   AND rsl.unit_of_measure = muom.unit_of_measure
                   AND p_chr_receipt_source_code = 'VENDOR'
            UNION ALL
            SELECT prha.org_id, rsl.shipment_line_status_code, rsl.quantity_shipped,
                   rsl.quantity_received, --    rsl.unit_of_measure, -- Commented by Infosys , CRP Issue 25122014
                                          muom.uom_code unit_of_measure, -- Added by Infosys , CRP Issue 25122014
                                                                         rsl.locator_id,
                   rsl.deliver_to_location_id, NULL po_header_id, NULL po_line_id,
                   prha.requisition_header_id req_header_id, prla.requisition_line_id req_line_id, rsl.shipment_line_id,
                   rsl.from_organization_id, rsl.to_organization_id, rsl.req_distribution_id,
                   rsl.deliver_to_person_id, rsl.source_document_code
              FROM rcv_shipment_lines rsl, po_requisition_lines_all prla, po_requisition_headers_all prha,
                   mtl_units_of_measure muom
             WHERE     rsl.shipment_header_id = p_num_shipment_header_id
                   AND rsl.line_num = p_num_line_number
                   AND rsl.item_id = p_num_item_id
                   AND rsl.unit_of_measure = muom.unit_of_measure
                   AND rsl.requisition_line_id = prla.requisition_line_id
                   AND prla.requisition_header_id =
                       prha.requisition_header_id
                   AND p_chr_receipt_source_code = 'INTERNAL ORDER';

        ebs_shipment_lines_rec       cur_ebs_shipment_lines%ROWTYPE;
        l_offset_time                NUMBER := 0;                        --5.3
    BEGIN
        p_out_chr_errbuf     := NULL;
        p_out_chr_retcode    := '0';
        fnd_file.put_line (fnd_file.LOG, 'Getting WMS warehouse details');

        --Get WMS warehouse details
        FOR inv_arg_attributes_rec IN cur_inv_arg_attributes
        LOOP
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).organization_id   :=
                inv_arg_attributes_rec.organization_id;
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).warehouse_code   :=
                inv_arg_attributes_rec.organization_code;
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).lpn_receiving   :=
                NVL (inv_arg_attributes_rec.lpn_receiving, '2');
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).partial_asn   :=
                NVL (inv_arg_attributes_rec.partial_asn, '1');

            -- query to get offset details -- 5.3
            BEGIN
                l_offset_time   :=
                    get_offset_time (
                        inv_arg_attributes_rec.organization_code);
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_offset_time   := 0;
            END;

            -- 5.3 end

            FOR sub_inventories_rec
                IN cur_sub_inventories (
                       inv_arg_attributes_rec.organization_id)
            LOOP
                g_sub_inventories_tab (
                       inv_arg_attributes_rec.organization_code
                    || '|'
                    || sub_inventories_rec.subinventory)   :=
                    inv_arg_attributes_rec.organization_id;
            END LOOP;
        END LOOP;

        --Generate the group id
        SELECT rcv_interface_groups_s.NEXTVAL INTO l_num_group_id FROM DUAL;

        p_out_num_group_id   := l_num_group_id;
        fnd_file.put_line (fnd_file.LOG, 'Group Id : ' || l_num_group_id);

        OPEN cur_asn_details;

        LOOP
            IF l_asn_details_tab.EXISTS (1)
            THEN
                l_asn_details_tab.DELETE;
            END IF;

            BEGIN
                fnd_file.put_line (fnd_file.LOG, 'Fetching the ASN Details');

                FETCH cur_asn_details
                    BULK COLLECT INTO l_asn_details_tab
                    LIMIT p_in_num_bulk_limit;

                fnd_file.put_line (fnd_file.LOG, 'Fetched the ASN details');
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_details;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_asn_details_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Processing the ASN Details');

            FOR l_num_ind IN l_asn_details_tab.FIRST ..
                             l_asn_details_tab.LAST
            LOOP
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing started for the ASN header : '
                        || l_asn_details_tab (l_num_ind).shipment_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'PO number: '
                        || l_asn_details_tab (l_num_ind).po_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'line number : '
                        || l_asn_details_tab (l_num_ind).line_number);

                    -- Validate whether inventory org is WMS enabled for current ASN receipt header - appointment
                    IF l_num_err_head_seq_id <>
                       l_asn_details_tab (l_num_ind).receipt_header_seq_id
                    THEN
                        BEGIN
                            l_asn_details_tab (l_num_ind).organization_id   :=
                                g_inv_org_attr_tab (
                                    l_asn_details_tab (l_num_ind).wh_id).organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_asn_details_tab (l_num_ind).organization_id   :=
                                    NULL;
                        END;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Validating whether '
                            || l_asn_details_tab (l_num_ind).wh_id
                            || ' is WMS warehouse');

                        IF l_asn_details_tab (l_num_ind).organization_id
                               IS NULL
                        THEN
                            RAISE l_exe_warehouse_err;
                        END IF;
                    END IF;

                    -- Validate whether ASN number is valid at the given inventory org, for the current shipment number
                    IF l_chr_err_shipment_number <>
                       l_asn_details_tab (l_num_ind).shipment_number
                    THEN
                        BEGIN
                            SELECT rsh.receipt_source_code, rsh.shipment_header_id, rsh.shipment_num,
                                   rsh.vendor_id
                              INTO l_asn_details_tab (l_num_ind).receipt_source_code, l_asn_details_tab (l_num_ind).shipment_header_id, l_asn_details_tab (l_num_ind).ebs_shipment_number,
                                   l_asn_details_tab (l_num_ind).vendor_id
                              FROM rcv_shipment_headers rsh
                             WHERE     rsh.ship_to_org_id =
                                       l_asn_details_tab (l_num_ind).organization_id
                                   AND rsh.shipment_num =
                                       l_asn_details_tab (l_num_ind).shipment_number;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_asn_details_tab (l_num_ind).receipt_source_code   :=
                                    NULL;
                                l_asn_details_tab (l_num_ind).shipment_header_id   :=
                                    NULL;
                                l_asn_details_tab (l_num_ind).ebs_shipment_number   :=
                                    NULL;
                                l_asn_details_tab (l_num_ind).vendor_id   :=
                                    NULL;
                        END;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Validating whether shipment number is valid at the given org');

                        IF l_asn_details_tab (l_num_ind).ebs_shipment_number
                               IS NULL
                        THEN
                            RAISE l_exe_asn_err;
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_asn_details_tab (l_num_ind).item_number
                        || ' is valid item');

                    -- Validate whether item number is valid for each ASN line in XML
                    IF l_asn_details_tab (l_num_ind).inventory_item_id
                           IS NULL
                    THEN
                        RAISE l_exe_item_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_asn_details_tab (l_num_ind).host_subinventory
                        || ' is valid sub inventory');
                    -- adding offset time to the receipt date -- 5.3
                    FND_FILE.PUT_LINE (FND_FILE.LOG,
                                       'l_offset_time:' || l_offset_time);
                    l_asn_details_tab (l_num_ind).receipt_date   :=
                          l_asn_details_tab (l_num_ind).receipt_date
                        + NVL (l_offset_time, 0);
                    FND_FILE.PUT_LINE (
                        FND_FILE.LOG,
                           'Receipt date after adding offset time:'
                        || l_asn_details_tab (l_num_ind).receipt_date);

                    -- 5.3 changes end

                    -- Validate whether subinventory is valid for each ASN line in XML
                    IF l_asn_details_tab (l_num_ind).host_subinventory
                           IS NOT NULL
                    THEN
                        IF NOT g_sub_inventories_tab.EXISTS (
                                      l_asn_details_tab (l_num_ind).wh_id
                                   || '|'
                                   || l_asn_details_tab (l_num_ind).host_subinventory)
                        THEN
                            RAISE l_exe_subinv_err;
                        END IF;
                    END IF;

                    -- Reset the shipment line id
                    ebs_shipment_lines_rec.shipment_line_id   := NULL;
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_asn_details_tab (l_num_ind).shipment_header_id : '
                        || l_asn_details_tab (l_num_ind).shipment_header_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_asn_details_tab (l_num_ind).receipt_source_code : '
                        || l_asn_details_tab (l_num_ind).receipt_source_code);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_asn_details_tab (l_num_ind).line_number : '
                        || l_asn_details_tab (l_num_ind).line_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_asn_details_tab (l_num_ind).inventory_item_id : '
                        || l_asn_details_tab (l_num_ind).inventory_item_id);

                    -- Fetch the EBS ASN lines and other details
                    BEGIN
                        OPEN cur_ebs_shipment_lines (
                            l_asn_details_tab (l_num_ind).shipment_header_id,
                            l_asn_details_tab (l_num_ind).receipt_source_code,
                            l_asn_details_tab (l_num_ind).line_number,
                            l_asn_details_tab (l_num_ind).inventory_item_id);

                        FETCH cur_ebs_shipment_lines
                            INTO ebs_shipment_lines_rec;

                        CLOSE cur_ebs_shipment_lines;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ebs_shipment_lines_rec.shipment_line_id   := NULL;
                    END;

                    -- Validate whether shipment line is fetched - line number and item number are present in the ASN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validating whether item number and line number combination is valid');

                    IF ebs_shipment_lines_rec.shipment_line_id IS NULL
                    THEN
                        RAISE l_exe_item_line_no_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_asn_details_tab (l_num_ind).ordered_uom
                        || ' is valid UOM');

                    IF ebs_shipment_lines_rec.unit_of_measure <>
                       l_asn_details_tab (l_num_ind).ordered_uom
                    THEN
                        RAISE l_exe_uom_err;
                    END IF;

                    /*Start of OVER_SHIP*/
                    /*  9/15 - commented over receipt quantity validation as we are getting over receipts from GTN and same is being received in HighJump
                    -- Validate whether the received qty in XML is less than or equal to open qty
                    fnd_file.put_line
                    (fnd_file.LOG,
                    'Validating whether the received qty is less than or equal to open qty '
                    );
                    IF   ebs_shipment_lines_rec.quantity_shipped
                    - NVL (ebs_shipment_lines_rec.quantity_received, 0) <
                    l_asn_details_tab (l_num_ind).qty
                    THEN
                    RAISE l_exe_qty_err;
                    END IF;
                    */
                    /*END of OVER_SHIP*/
                    -- Insert header record only once for each shipment number
                    IF l_chr_prev_shipment_number <>
                       l_asn_details_tab (l_num_ind).shipment_number
                    THEN
                        SELECT rcv_headers_interface_s.NEXTVAL
                          INTO l_num_header_inf_id
                          FROM DUAL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Inserting data into rcv_headers_interface for the shipment number: '
                            || l_asn_details_tab (l_num_ind).shipment_number);

                        INSERT INTO apps.rcv_headers_interface (
                                        header_interface_id,
                                        GROUP_ID,
                                        processing_status_code,
                                        receipt_source_code,
                                        transaction_type,
                                        auto_transact_code,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login,
                                        creation_date,
                                        created_by,
                                        shipment_num,
                                        ship_to_organization_id,
                                        expected_receipt_date,
                                        --                               employee_id,
                                        validation_flag,
                                        customer_id,
                                        vendor_id)
                                 VALUES (
                                            l_num_header_inf_id --header_interface_id
                                                               ,
                                            l_num_group_id          --group_id
                                                          ,
                                            'PENDING' --processing_status_code
                                                     ,
                                            l_asn_details_tab (l_num_ind).receipt_source_code --receipt_source_code
                                                                                             ,
                                            'NEW'           --transaction_type
                                                 ,
                                            'DELIVER'     --auto_transact_code
                                                     ,
                                            SYSDATE         --last_update_date
                                                   ,
                                            apps.fnd_global.user_id --last_update_by
                                                                   ,
                                            USERENV ('SESSIONID') --last_update_login
                                                                 ,
                                            SYSDATE            --creation_date
                                                   ,
                                            apps.fnd_global.user_id --created_by
                                                                   ,
                                            l_asn_details_tab (l_num_ind).shipment_number --shipment_num
                                                                                         ,
                                            l_asn_details_tab (l_num_ind).organization_id --ship_to_organization_id
                                                                                         ,
                                            NVL (
                                                l_asn_details_tab (l_num_ind).receipt_date,
                                                SYSDATE + 1) --expected_receipt_date
                                                            ,
                                            --                               NVL
                                            --                                  (l_asn_details_tab (l_num_ind).employee_id,
                                            --                                   fnd_global.employee_id
                                            --                                  )                              --employee_id
                                            --                                   ,
                                            'Y'              --validation_flag
                                               ,
                                            NULL                -- customer_id
                                                ,
                                            l_asn_details_tab (l_num_ind).vendor_id);

                        l_chr_prev_shipment_number   :=
                            l_asn_details_tab (l_num_ind).shipment_number;
                    END IF;

                    SELECT COUNT (1)
                      INTO l_num_deliver
                      FROM apps.rcv_shipment_lines rsl, apps.po_line_locations_all plla, apps.fnd_lookup_values flv
                     WHERE     rsl.shipment_line_id =
                               ebs_shipment_lines_rec.shipment_line_id
                           AND plla.line_location_id =
                               rsl.po_line_location_id
                           AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
                           AND flv.LANGUAGE = 'US'
                           AND flv.lookup_code =
                               TO_CHAR (plla.receiving_routing_id)
                           AND flv.view_application_id = 0
                           AND flv.security_group_id = 0
                           AND flv.meaning = 'Standard Receipt';

                    IF l_num_deliver = 1
                    THEN
                        l_chr_trx_type   := 'DELIVER';
                    ELSE
                        l_chr_trx_type   := 'RECEIVE';
                    END IF;

                    IF l_asn_details_tab (l_num_ind).LOCATOR IS NOT NULL
                    THEN
                        BEGIN
                            SELECT inventory_location_id
                              INTO l_asn_details_tab (l_num_ind).locator_id
                              FROM mtl_item_locations_kfv
                             WHERE     organization_id =
                                       l_asn_details_tab (l_num_ind).organization_id
                                   AND subinventory_code =
                                       l_asn_details_tab (l_num_ind).host_subinventory
                                   AND concatenated_segments =
                                       l_asn_details_tab (l_num_ind).LOCATOR
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                                   AND NVL (disable_date, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_asn_details_tab (l_num_ind).locator_id   :=
                                    NULL;
                        END;
                    ELSE
                        l_asn_details_tab (l_num_ind).locator_id   := NULL;
                    END IF;

                    -- Validate whether locator passed is valid
                    IF     l_asn_details_tab (l_num_ind).LOCATOR IS NOT NULL
                       AND l_asn_details_tab (l_num_ind).locator_id IS NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Validating whether the locator '
                            || l_asn_details_tab (l_num_ind).LOCATOR
                            || ' is valid');
                        RAISE l_exe_locator_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into rcv_transactions_interface for the shipment line id: '
                        || ebs_shipment_lines_rec.shipment_line_id);

                    -- Insert one record for each ASN Line
                    INSERT INTO rcv_transactions_interface (interface_transaction_id, GROUP_ID, org_id, last_update_date, last_updated_by, creation_date, created_by, last_update_login, transaction_type, transaction_date, processing_status_code, processing_mode_code, transaction_status_code, quantity, uom_code, -- Added by Infosys , CRP Issue 25122014
                                                                                                                                                                                                                                                                                                                        --  unit_of_measure, -- Commented by Infosys , CRP Issue 25122014
                                                                                                                                                                                                                                                                                                                        interface_source_code, item_id, --                            employee_id,
                                                                                                                                                                                                                                                                                                                                                        auto_transact_code, shipment_header_id, shipment_line_id, ship_to_location_id, receipt_source_code, to_organization_id, source_document_code, requisition_line_id, req_distribution_id, destination_type_code, deliver_to_person_id, location_id, deliver_to_location_id, subinventory, locator_id, shipment_num, expected_receipt_date, header_interface_id, validation_flag, oe_order_header_id, oe_order_line_id, customer_id, customer_site_id, vendor_id, parent_transaction_id
                                                            , attribute6)
                         VALUES (rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                                     , l_num_group_id --group_id
                                                                                     , ebs_shipment_lines_rec.org_id, SYSDATE --last_update_date
                                                                                                                             , fnd_global.user_id --last_updated_by
                                                                                                                                                 , SYSDATE --creation_date
                                                                                                                                                          , fnd_global.user_id --created_by
                                                                                                                                                                              , USERENV ('SESSIONID') --last_update_login
                                                                                                                                                                                                     , l_chr_trx_type --transaction_type
                                                                                                                                                                                                                     , --SYSDATE                         --transaction_date   --MULTIPLE_NEG
                                                                                                                                                                                                                       /* 9/15 if the receipt date is in old month, default it to sysdate */
                                                                                                                                                                                                                       DECODE (TO_CHAR (l_asn_details_tab (l_num_ind).receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), l_asn_details_tab (l_num_ind).receipt_date, SYSDATE), --PAST_RECEIPT
                                                                                                                                                                                                                                                                                                                                                                                  'PENDING' --processing_status_code
                                                                                                                                                                                                                                                                                                                                                                                           , 'BATCH' --processing_mode_code
                                                                                                                                                                                                                                                                                                                                                                                                    , 'PENDING' --transaction_status_code
                                                                                                                                                                                                                                                                                                                                                                                                               , l_asn_details_tab (l_num_ind).qty --quantity
                                                                                                                                                                                                                                                                                                                                                                                                                                                  , l_asn_details_tab (l_num_ind).ordered_uom --unit_of_measure
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , 'RCV' --interface_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , l_asn_details_tab (l_num_ind).inventory_item_id --item_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , --                            NVL
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       --                               (l_asn_details_tab (l_num_ind).employee_id,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       --                                fnd_global.employee_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       --                               )                                 --employee_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       --                                ,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       'DELIVER' --auto_transact_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , l_asn_details_tab (l_num_ind).shipment_header_id --shipment_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , ebs_shipment_lines_rec.shipment_line_id --shipment_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           , ebs_shipment_lines_rec.deliver_to_location_id --ship_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , l_asn_details_tab (l_num_ind).receipt_source_code --receipt_source_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             , ebs_shipment_lines_rec.to_organization_id --to_organization_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        , ebs_shipment_lines_rec.source_document_code --source_document_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , ebs_shipment_lines_rec.req_line_id --requisition_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         , ebs_shipment_lines_rec.req_distribution_id --req_distribution_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , 'INVENTORY' --destination_type_code
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  , ebs_shipment_lines_rec.deliver_to_person_id --deliver_to_person_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , NULL --location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , ebs_shipment_lines_rec.deliver_to_location_id --deliver_to_location_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , l_asn_details_tab (l_num_ind).host_subinventory --subinventory
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     , l_asn_details_tab (l_num_ind).locator_id, l_asn_details_tab (l_num_ind).shipment_number --shipment_num
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              , l_asn_details_tab (l_num_ind).receipt_date --expected_receipt_date,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , l_num_header_inf_id --header_interface_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               , 'Y' --validation_flag
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    , NULL --oe_order_header_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          , NULL --oe_order_line_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                , NULL --customer_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      , NULL --customer_site_id
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            , l_asn_details_tab (l_num_ind).vendor_id, NULL
                                 ,                   --p_parent_transaction_id
                                   l_asn_details_tab (l_num_ind).carton_id);

                    UPDATE xxdo_po_asn_receipt_dtl_stg
                       SET shipment_header_id = l_asn_details_tab (l_num_ind).shipment_header_id, po_header_id = ebs_shipment_lines_rec.po_header_id, lpn_id = NULL,
                           inventory_item_id = l_asn_details_tab (l_num_ind).inventory_item_id, organization_id = ebs_shipment_lines_rec.to_organization_id, receipt_source_code = l_asn_details_tab (l_num_ind).receipt_source_code,
                           open_qty = ebs_shipment_lines_rec.quantity_shipped - NVL (ebs_shipment_lines_rec.quantity_received, 0), po_line_id = ebs_shipment_lines_rec.po_line_id, shipment_line_id = ebs_shipment_lines_rec.shipment_line_id,
                           requisition_header_id = ebs_shipment_lines_rec.req_header_id, requisition_line_id = ebs_shipment_lines_rec.req_line_id, GROUP_ID = l_num_group_id,
                           org_id = ebs_shipment_lines_rec.org_id, locator_id = l_asn_details_tab (l_num_ind).locator_id, vendor_id = l_asn_details_tab (l_num_ind).vendor_id
                     WHERE     receipt_dtl_seq_id =
                               l_asn_details_tab (l_num_ind).receipt_dtl_seq_id
                           AND process_status = 'INPROCESS'
                           AND request_id = g_num_request_id;
                EXCEPTION
                    WHEN l_exe_warehouse_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => NULL, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'Inventory Org is not WMS enabled', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                        l_num_err_head_seq_id   :=
                            l_asn_details_tab (l_num_ind).receipt_header_seq_id;
                    WHEN l_exe_asn_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'Shipment Number : ' || l_asn_details_tab (l_num_ind).shipment_number || ' is not valid at the org : ' || l_asn_details_tab (l_num_ind).wh_id, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                        l_chr_err_shipment_number   :=
                            l_asn_details_tab (l_num_ind).shipment_number;
                    WHEN l_exe_item_line_no_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Item number and line number combination is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_item_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Item number is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_qty_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Receipt Qty is more than Open Qty', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_uom_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Receipt UOM does not match with EBS ASN UOM', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_subinv_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Sub-inventory is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_locator_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Locator is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN OTHERS
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Unexpected Error : ' || SQLERRM, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                END;
            END LOOP;                           -- ASN details processing loop
        END LOOP;                                    -- ASN details fetch loop

        CLOSE cur_asn_details;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at validate insert_asn_data procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END insert_asn_data;

    -- ***************************************************************************
    -- Procedure/Function Name  :  update_error_records
    --
    -- Description              :  The purpose of this procedure is to update the process status of the records
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message at procedure level
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_chr_shipment_no  IN : ASN Number
    --                                  p_in_chr_error_message IN : Error message at record level
    --                                 p_in_chr_from_status   IN : From Process status
    --                                 p_in_chr_to_status       IN : To Process status
    --
    -- Return/Exit              :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/11    Infosys            1.0   Initial Version
    -- ***************************************************************************

    PROCEDURE update_po_error_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_appointment_id IN VARCHAR2, p_in_num_receipt_head_id IN NUMBER, p_in_chr_po_no IN VARCHAR2, p_in_num_rcpt_dtl_seq_id IN NUMBER, p_in_chr_error_message IN VARCHAR2, p_in_chr_from_status IN VARCHAR2, p_in_chr_to_status IN VARCHAR2
                                       , p_in_chr_warehouse IN VARCHAR2)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        /*Comment update section Begin*/
        /*    UPDATE xxdo_po_asn_receipt_head_stg
        SET process_status = p_in_chr_to_status,
        --             error_message = p_in_chr_error_message,
        last_updated_by = g_num_user_id,
        last_update_date = SYSDATE
        WHERE process_status = p_in_chr_from_status
        AND appointment_id = NVL (p_in_chr_appointment_id, appointment_id)
        AND wh_id = NVL (p_in_chr_warehouse, wh_id)
        AND receipt_header_seq_id = p_in_num_receipt_head_id
        AND request_id = g_num_request_id;  */
        /*Comment update section End*/
        UPDATE xxdo_po_asn_receipt_dtl_stg
           SET process_status = p_in_chr_to_status, error_message = p_in_chr_error_message, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND po_number = NVL (p_in_chr_po_no, po_number)
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND receipt_header_seq_id = p_in_num_receipt_head_id
               AND receipt_dtl_seq_id =
                   NVL (p_in_num_rcpt_dtl_seq_id, receipt_dtl_seq_id)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_receipt_ser_stg
           SET process_status = p_in_chr_to_status, --             error_message = p_in_chr_error_message,
                                                    last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND po_number = NVL (p_in_chr_po_no, po_number)
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND receipt_header_seq_id = p_in_num_receipt_head_id
               AND receipt_dtl_seq_id =
                   NVL (p_in_num_rcpt_dtl_seq_id, receipt_dtl_seq_id)
               AND request_id = g_num_request_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                   'ERROR in update error records procedure : '
                || p_out_chr_errbuf);
    END update_po_error_records;

    -- ***************************************************************************
    -- Procedure/Function Name  :  insert_po_data
    --
    -- Description              :  This purpose of this procedure is to validate the asn receipt data and insert into the interface tables
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                p_in_chr_warehouse    IN  : Warehouse code
    --
    --                                p_in_chr_shipment_no  IN  : Shipment number
    --                                p_in_num_purge_days   IN  : Purge days
    --                                p_in_num_bulk_limit   IN  : Bulk Limit
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

    PROCEDURE insert_po_data (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_bulk_limit IN NUMBER
                              , p_out_num_group_id OUT NUMBER)
    IS
        l_chr_errbuf                 VARCHAR2 (4000);
        l_chr_retcode                VARCHAR2 (30);
        l_chr_err_po_number          VARCHAR2 (60) := '-1';
        l_num_err_head_seq_id        NUMBER := -1;
        l_chr_asn_line_exists        VARCHAR2 (1) := 'N';
        l_chr_prev_po_number         VARCHAR2 (60) := '-1';
        l_num_group_id               NUMBER;
        l_num_header_inf_id          NUMBER;
        l_num_deliver                NUMBER;
        l_chr_trx_type               VARCHAR2 (20);
        l_chr_source_document_code   VARCHAR2 (30);
        l_chr_shipment_num           VARCHAR2 (25) := '-1';
        l_chr_custom_asn_no          VARCHAR2 (25) := '-1';
        l_exe_po_err                 EXCEPTION;
        l_exe_asn_exists             EXCEPTION;
        l_exe_custom_asn_exists      EXCEPTION;
        l_exe_warehouse_err          EXCEPTION;
        l_exe_asn_err                EXCEPTION;
        l_exe_item_err               EXCEPTION;
        l_exe_qty_err                EXCEPTION;
        l_exe_subinv_err             EXCEPTION;
        l_exe_item_line_no_err       EXCEPTION;
        l_exe_uom_err                EXCEPTION;
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_locator_err            EXCEPTION;

        CURSOR cur_po_details IS
              SELECT headers.receipt_header_seq_id, headers.wh_id, headers.receipt_date,
                     headers.employee_id, mp.organization_id, dtl.receipt_dtl_seq_id,
                     dtl.po_number, dtl.line_number, dtl.item_number,
                     get_inventory_item_id (dtl.item_number, mp.master_organization_id) inventory_item_id, -- Modified for BT Remediation
                                                                                                           dtl.rcpt_type, dtl.qty,
                     dtl.ordered_uom, dtl.host_subinventory, dtl.carton_id,
                     NULL vendor_id, dtl.LOCATOR, NULL locator_id
                FROM xxdo_po_asn_receipt_head_stg headers, xxdo_po_asn_receipt_dtl_stg dtl, mtl_parameters mp
               WHERE     headers.receipt_header_seq_id =
                         dtl.receipt_header_seq_id
                     AND headers.request_id = g_num_request_id
                     AND headers.process_status = 'INPROCESS'
                     AND dtl.process_status = 'INPROCESS'
                     AND headers.wh_id = mp.organization_code
                     AND dtl.shipment_number IS NULL    --  /* PO_Receiving */
                     AND dtl.rcpt_type = 'RECEIPT'
            ORDER BY dtl.po_number, dtl.line_number, headers.receipt_date; -- MULTIPLE_NEG

        TYPE l_po_details_tab_type IS TABLE OF cur_po_details%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_po_details_tab             l_po_details_tab_type;

        CURSOR cur_ebs_po_lines (p_chr_po_number IN VARCHAR2, p_num_line_number IN NUMBER, p_num_item_id IN NUMBER
                                 , p_num_inv_org_id IN NUMBER)
        IS
            SELECT DISTINCT pha.org_id, pha.po_header_id, pha.vendor_id,
                            (plla.quantity - NVL (plla.quantity_cancelled, 0)) quantity_shipped, plla.quantity_received, --           plla.unit_meas_lookup_code  unit_of_measure,  -- Commented by Infosys , CRP Issue 25122014
                                                                                                                         muom.uom_code unit_of_measure, -- Added by Infosys , CRP Issue 25122014
                            --     plla.unit_meas_lookup_code  unit_of_measure,
                            plla.line_location_id, pla.po_line_id, plla.ship_to_organization_id to_organization_id,
                            plla.shipment_num, pda.destination_type_code, pda.deliver_to_person_id,
                            pda.deliver_to_location_id, pda.destination_subinventory, pda.destination_organization_id
              FROM po_line_locations_all plla, po_lines_all pla, po_headers_all pha,
                   po_distributions_all pda, mtl_units_of_measure muom
             WHERE     pha.segment1 = p_chr_po_number
                   AND pla.line_num = p_num_line_number
                   AND pla.item_id = p_num_item_id
                   AND plla.po_header_id = pha.po_header_id
                   AND plla.po_line_id = pla.po_line_id
                   AND plla.line_location_id = pda.line_location_id
                   AND plla.unit_meas_lookup_code = muom.unit_of_measure
                   AND plla.ship_to_organization_id = p_num_inv_org_id;

        ebs_po_lines_rec             cur_ebs_po_lines%ROWTYPE;

        CURSOR cur_inv_arg_attributes IS
            SELECT flv.lookup_code organization_code, mp.attribute15 lpn_receiving, mp.attribute12 partial_asn,
                   mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.lookup_code
                   AND mp.organization_code IN
                           (SELECT wh_id
                              FROM xxdo_po_asn_receipt_head_stg
                             WHERE request_id = g_num_request_id);

        CURSOR cur_sub_inventories (p_num_organization_id IN NUMBER)
        IS
            SELECT secondary_inventory_name subinventory
              FROM mtl_secondary_inventories
             WHERE organization_id = p_num_organization_id;
    BEGIN
        p_out_chr_errbuf     := NULL;
        p_out_chr_retcode    := '0';
        fnd_file.put_line (fnd_file.LOG, 'Getting WMS warehouse details');

        IF NOT g_inv_org_attr_tab.EXISTS (1)
        THEN
            --Get WMS warehouse details
            FOR inv_arg_attributes_rec IN cur_inv_arg_attributes
            LOOP
                g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).organization_id   :=
                    inv_arg_attributes_rec.organization_id;
                g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).warehouse_code   :=
                    inv_arg_attributes_rec.organization_code;
                g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).lpn_receiving   :=
                    NVL (inv_arg_attributes_rec.lpn_receiving, '2');
                g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).partial_asn   :=
                    NVL (inv_arg_attributes_rec.partial_asn, '1');



                FOR sub_inventories_rec
                    IN cur_sub_inventories (
                           inv_arg_attributes_rec.organization_id)
                LOOP
                    g_sub_inventories_tab (
                           inv_arg_attributes_rec.organization_code
                        || '|'
                        || sub_inventories_rec.subinventory)   :=
                        inv_arg_attributes_rec.organization_id;
                END LOOP;
            END LOOP;
        END IF;

        --Generate the group id
        SELECT rcv_interface_groups_s.NEXTVAL INTO l_num_group_id FROM DUAL;

        p_out_num_group_id   := l_num_group_id;
        fnd_file.put_line (fnd_file.LOG, 'Group Id : ' || l_num_group_id);

        OPEN cur_po_details;

        LOOP
            IF l_po_details_tab.EXISTS (1)
            THEN
                l_po_details_tab.DELETE;
            END IF;

            BEGIN
                fnd_file.put_line (fnd_file.LOG, 'Fetching the PO Details');

                FETCH cur_po_details
                    BULK COLLECT INTO l_po_details_tab
                    LIMIT p_in_num_bulk_limit;

                fnd_file.put_line (fnd_file.LOG, 'Fetched the PO details');
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_po_details;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_po_details_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Processing the PO Details');

            FOR l_num_ind IN l_po_details_tab.FIRST .. l_po_details_tab.LAST
            LOOP
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing started for the PO header : '
                        || l_po_details_tab (l_num_ind).po_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'line number : '
                        || l_po_details_tab (l_num_ind).line_number);

                    -- Validate whether inventory org is WMS enabled for current ASN receipt header - appointment
                    IF l_num_err_head_seq_id <>
                       l_po_details_tab (l_num_ind).receipt_header_seq_id
                    THEN
                        BEGIN
                            l_po_details_tab (l_num_ind).organization_id   :=
                                g_inv_org_attr_tab (
                                    l_po_details_tab (l_num_ind).wh_id).organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_po_details_tab (l_num_ind).organization_id   :=
                                    NULL;
                        END;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Validating whether '
                            || l_po_details_tab (l_num_ind).wh_id
                            || ' is WMS warehouse');

                        IF l_po_details_tab (l_num_ind).organization_id
                               IS NULL
                        THEN
                            RAISE l_exe_warehouse_err;
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_po_details_tab (l_num_ind).po_number
                        || ' is valid PO');

                    -- Validate whether PO number is valid
                    IF l_po_details_tab (l_num_ind).po_number IS NULL
                    THEN
                        RAISE l_exe_po_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_po_details_tab (l_num_ind).item_number
                        || ' is valid item');

                    -- Validate whether item number is valid for each ASN line in XML
                    IF l_po_details_tab (l_num_ind).inventory_item_id IS NULL
                    THEN
                        RAISE l_exe_item_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_po_details_tab (l_num_ind).host_subinventory
                        || ' is valid sub inventory');

                    -- Validate whether subinventory is valid for each ASN line in XML
                    IF l_po_details_tab (l_num_ind).host_subinventory
                           IS NOT NULL
                    THEN
                        IF NOT g_sub_inventories_tab.EXISTS (
                                      l_po_details_tab (l_num_ind).wh_id
                                   || '|'
                                   || l_po_details_tab (l_num_ind).host_subinventory)
                        THEN
                            RAISE l_exe_subinv_err;
                        END IF;
                    END IF;

                    -- Reset the shipment line id
                    ebs_po_lines_rec.po_line_id   := NULL;

                    -- Fetch the EBS ASN lines and other details
                    BEGIN
                        OPEN cur_ebs_po_lines (
                            l_po_details_tab (l_num_ind).po_number,
                            l_po_details_tab (l_num_ind).line_number,
                            l_po_details_tab (l_num_ind).inventory_item_id,
                            l_po_details_tab (l_num_ind).organization_id);

                        FETCH cur_ebs_po_lines INTO ebs_po_lines_rec;

                        CLOSE cur_ebs_po_lines;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ebs_po_lines_rec.po_line_id   := NULL;
                    END;

                    -- Validate whether shipment line is fetched - line number and item number are present in the ASN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validating whether item number and line number combination is valid');

                    IF ebs_po_lines_rec.po_line_id IS NULL
                    THEN
                        RAISE l_exe_item_line_no_err;
                    END IF;

                    -- Validate whether shipment line is fetched - line number and item number are present in the ASN
                    fnd_file.put_line (fnd_file.LOG,
                                       'Validating whether ASN exists');
                    l_chr_shipment_num            := '-1';

                    BEGIN
                        SELECT shipment_num
                          INTO l_chr_shipment_num
                          FROM rcv_shipment_lines rsl, rcv_shipment_headers rsh
                         WHERE     rsl.po_line_id =
                                   ebs_po_lines_rec.po_line_id
                               AND rsl.po_header_id =
                                   ebs_po_lines_rec.po_header_id
                               AND rsl.po_line_location_id =
                                   ebs_po_lines_rec.line_location_id
                               AND rsl.shipment_header_id =
                                   rsh.shipment_header_id
                               AND ROWNUM < 2;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_shipment_num   := '-1';
                    END;

                    IF l_chr_shipment_num <> '-1'
                    THEN
                        RAISE l_exe_asn_exists;
                    END IF;

                    -- Validate whether shipment line is fetched - line number and item number are present in the ASN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validating whether ASN exists in custom tables');
                    l_chr_custom_asn_no           := 'N';

                    BEGIN
                        SELECT 'Y'
                          INTO l_chr_custom_asn_no
                          FROM do_items
                         WHERE     organization_id =
                                   ebs_po_lines_rec.to_organization_id
                               AND order_id = ebs_po_lines_rec.po_header_id
                               AND order_line_id =
                                   ebs_po_lines_rec.po_line_id
                               AND line_location_id =
                                   ebs_po_lines_rec.line_location_id
                               AND ROWNUM < 2;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            l_chr_custom_asn_no   := 'N';
                    END;

                    IF l_chr_custom_asn_no <> 'N'
                    THEN
                        RAISE l_exe_custom_asn_exists;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_po_details_tab (l_num_ind).ordered_uom
                        || ' is valid UOM');

                    IF ebs_po_lines_rec.unit_of_measure <>
                       l_po_details_tab (l_num_ind).ordered_uom
                    THEN
                        RAISE l_exe_uom_err;
                    END IF;

                    -- Validate whether the received qty in XML is less than or equal to open qty
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validating whether the received qty is less than or equal to open qty ');

                    IF   ebs_po_lines_rec.quantity_shipped
                       - NVL (ebs_po_lines_rec.quantity_received, 0) <
                       l_po_details_tab (l_num_ind).qty
                    THEN
                        RAISE l_exe_qty_err;
                    END IF;

                    -- Insert header record only once for each shipment number
                    IF l_chr_prev_po_number <>
                       l_po_details_tab (l_num_ind).po_number
                    THEN
                        SELECT rcv_headers_interface_s.NEXTVAL
                          INTO l_num_header_inf_id
                          FROM DUAL;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Inserting data into rcv_headers_interface for the PO number: '
                            || l_po_details_tab (l_num_ind).po_number);

                        INSERT INTO apps.rcv_headers_interface (header_interface_id, GROUP_ID, processing_status_code, receipt_source_code, transaction_type, last_update_date, last_updated_by, last_update_login, creation_date, created_by, expected_receipt_date, validation_flag
                                                                , vendor_id)
                             VALUES (l_num_header_inf_id, --header_interface_id
                                                          l_num_group_id, --group_id
                                                                          'PENDING', --processing_status_code
                                                                                     'VENDOR', --receipt_source_code
                                                                                               'NEW', --transaction_type
                                                                                                      SYSDATE, --last_update_date
                                                                                                               apps.fnd_global.user_id, --last_update_by
                                                                                                                                        0, --last_update_login
                                                                                                                                           SYSDATE, --creation_date
                                                                                                                                                    apps.fnd_global.user_id, --created_by
                                                                                                                                                                             NVL (l_po_details_tab (l_num_ind).receipt_date, SYSDATE + 1), --expected_receipt_date
                                                                                                                                                                                                                                           'Y'
                                     ,                       --validation_flag
                                       ebs_po_lines_rec.vendor_id -- vendor_id
                                                                 );

                        l_chr_prev_po_number   :=
                            l_po_details_tab (l_num_ind).po_number;
                    END IF;

                    SELECT COUNT (1)
                      INTO l_num_deliver
                      FROM apps.po_line_locations_all plla, apps.fnd_lookup_values flv
                     WHERE     plla.line_location_id =
                               ebs_po_lines_rec.line_location_id
                           AND flv.lookup_type = 'RCV_ROUTING_HEADERS'
                           AND flv.LANGUAGE = 'US'
                           AND flv.lookup_code =
                               TO_CHAR (plla.receiving_routing_id)
                           AND flv.view_application_id = 0
                           AND flv.security_group_id = 0
                           AND flv.meaning = 'Standard Receipt';

                    IF l_num_deliver = 1
                    THEN
                        l_chr_trx_type   := 'DELIVER';
                    ELSE
                        l_chr_trx_type   := 'RECEIVE';
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into rcv_transactions_interface for the PO line id: '
                        || ebs_po_lines_rec.po_line_id);

                    -- Insert one record for each PO Line
                    /*
                    INSERT INTO rcv_transactions_interface
                    (
                    interface_transaction_id ,
                    group_id ,
                    org_id,
                    last_update_date ,
                    last_updated_by ,
                    creation_date ,
                    created_by ,
                    last_update_login ,
                    transaction_type ,
                    transaction_date ,
                    processing_status_code ,
                    processing_mode_code ,
                    transaction_status_code ,
                    po_header_id,
                    po_line_id ,
                    item_id ,
                    quantity ,
                    unit_of_measure ,
                    po_line_location_id ,
                    auto_transact_code ,
                    receipt_source_code ,
                    to_organization_code ,
                    source_document_code ,
                    header_interface_id ,
                    validation_flag,
                    attribute6,
                    --                                    shipment_header_id,
                    destination_type_code,
                    --                                    po_release_id,
                    --                                    receipt_number
                    --                                    document_line_num
                    --                                    shipment_num,
                    document_num
                    )
                    VALUES
                    (
                    rcv_transactions_interface_s.nextval ,
                    l_num_group_id ,
                    ebs_po_lines_rec.org_id,
                    SYSDATE ,
                    fnd_global.user_id ,
                    SYSDATE ,
                    fnd_global.user_id ,
                    USERENV ('SESSIONID'),
                    'RECEIVE', --l_chr_trx_type, --'RECEIVE' ,
                    SYSDATE ,
                    'PENDING' ,
                    'BATCH' ,
                    'PENDING' ,
                    ebs_po_lines_rec.po_header_id,
                    ebs_po_lines_rec.po_line_id ,
                    l_po_details_tab (l_num_ind).inventory_item_id ,
                    l_po_details_tab (l_num_ind).qty ,
                    ebs_po_lines_rec.unit_of_measure ,
                    ebs_po_lines_rec.line_location_id ,
                    'DELIVER',--'RECEIVE' ,
                    'VENDOR' ,
                    l_po_details_tab (l_num_ind).wh_id ,
                    'PO' ,
                    l_num_header_inf_id,
                    'Y',
                    --                                    NULL,
                    l_po_details_tab (l_num_ind).carton_id,
                    'INVENTORY',
                    '103'
                    --                                    9999
                    --                                    l_po_details_tab (l_num_ind).line_number,
                    --                                    '9999'
                    );
                    */
                    INSERT INTO rcv_transactions_interface (interface_transaction_id, GROUP_ID, org_id, last_update_date, last_updated_by, creation_date, created_by, last_update_login, transaction_type, transaction_date, processing_status_code, processing_mode_code, transaction_status_code, po_header_id, po_line_id, item_id, quantity, uom_code, --unit_of_measure ,
                                                                                                                                                                                                                                                                                                                                                           po_line_location_id, auto_transact_code, receipt_source_code, to_organization_code, source_document_code, document_num, destination_type_code, deliver_to_person_id, deliver_to_location_id, subinventory, header_interface_id, validation_flag
                                                            , attribute6)
                         VALUES (rcv_transactions_interface_s.NEXTVAL, l_num_group_id, ebs_po_lines_rec.org_id, SYSDATE, fnd_global.user_id, SYSDATE, fnd_global.user_id, 0, l_chr_trx_type, --'RECEIVE' ,
                                                                                                                                                                                             -- SYSDATE ,    --MULTIPLE_NEG
                                                                                                                                                                                             l_po_details_tab (l_num_ind).receipt_date, -- transaction date  -- MULTIPLE_NEG
                                                                                                                                                                                                                                        'PENDING', 'BATCH', 'PENDING', ebs_po_lines_rec.po_header_id, ebs_po_lines_rec.po_line_id, l_po_details_tab (l_num_ind).inventory_item_id, l_po_details_tab (l_num_ind).qty, ebs_po_lines_rec.unit_of_measure, ebs_po_lines_rec.line_location_id, 'DELIVER', 'VENDOR', l_po_details_tab (l_num_ind).wh_id, 'PO', l_po_details_tab (l_num_ind).po_number, ebs_po_lines_rec.destination_type_code, ebs_po_lines_rec.deliver_to_person_id, ebs_po_lines_rec.deliver_to_location_id, -- ebs_po_lines_rec.destination_subinventory,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         l_po_details_tab (l_num_ind).host_subinventory, l_num_header_inf_id, 'Y'
                                 , l_po_details_tab (l_num_ind).carton_id);

                    UPDATE xxdo_po_asn_receipt_dtl_stg
                       SET po_header_id = ebs_po_lines_rec.po_header_id, inventory_item_id = l_po_details_tab (l_num_ind).inventory_item_id, organization_id = ebs_po_lines_rec.to_organization_id,
                           open_qty = ebs_po_lines_rec.quantity_shipped - NVL (ebs_po_lines_rec.quantity_received, 0), po_line_id = ebs_po_lines_rec.po_line_id, GROUP_ID = l_num_group_id,
                           org_id = ebs_po_lines_rec.org_id, vendor_id = l_po_details_tab (l_num_ind).vendor_id
                     WHERE     receipt_dtl_seq_id =
                               l_po_details_tab (l_num_ind).receipt_dtl_seq_id
                           AND process_status = 'INPROCESS'
                           AND request_id = g_num_request_id;
                EXCEPTION
                    WHEN l_exe_warehouse_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => NULL, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'Inventory Org is not WMS enabled', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                        l_num_err_head_seq_id   :=
                            l_po_details_tab (l_num_ind).receipt_header_seq_id;
                    WHEN l_exe_po_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'PO Number is blank', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                        l_chr_err_po_number   := '-1';
                    --                                 l_po_details_tab (l_num_ind).po_number;
                    WHEN l_exe_asn_exists
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'ASN :' || l_chr_shipment_num || ' exists for this PO', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                        l_chr_err_po_number   :=
                            l_po_details_tab (l_num_ind).po_number;
                    WHEN l_exe_custom_asn_exists
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'ASN records exist for this PO in the custom tables', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                        l_chr_err_po_number   :=
                            l_po_details_tab (l_num_ind).po_number;
                    WHEN l_exe_asn_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'PO Number : ' || l_po_details_tab (l_num_ind).po_number || ' is not valid at the org : ' || l_po_details_tab (l_num_ind).wh_id, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                        l_chr_err_po_number   :=
                            l_po_details_tab (l_num_ind).po_number;
                    WHEN l_exe_item_line_no_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Item number and line number combination is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                    WHEN l_exe_item_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Item number is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                    WHEN l_exe_qty_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Receipt Qty is more than Open Qty', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                    WHEN l_exe_uom_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Receipt UOM does not match with EBS ASN UOM', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                    WHEN l_exe_subinv_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Sub-inventory is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                    WHEN l_exe_locator_err
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Locator is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                    WHEN OTHERS
                    THEN
                        update_po_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_po_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_po_no => l_po_details_tab (l_num_ind).po_number, p_in_num_rcpt_dtl_seq_id => l_po_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Unexpected Error : ' || SQLERRM, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                                 , p_in_chr_warehouse => NULL);
                END;
            END LOOP;                           -- ASN details processing loop
        END LOOP;                                    -- ASN details fetch loop

        CLOSE cur_po_details;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error at insert_po_data procedure : ' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END insert_po_data;

    -- Standard ASN present
    -- DO Shipments
    -- Org check
    -- Attribute6 -- carton number

    PROCEDURE lock_po_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_warehouse IN VARCHAR2
                               , p_in_chr_appointment_id IN VARCHAR2, p_in_chr_rcpt_type IN VARCHAR2, p_out_num_record_count OUT NUMBER)
    IS
    BEGIN
        p_out_chr_errbuf         := NULL;
        p_out_chr_retcode        := '0';

        UPDATE xxdo_po_asn_receipt_head_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_po_asn_receipt_dtl_stg
                         WHERE     process_status = 'NEW'
                               AND appointment_id =
                                   NVL (p_in_chr_appointment_id,
                                        appointment_id)
                               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
                               AND rcpt_type =
                                   NVL (p_in_chr_rcpt_type, rcpt_type)
                               AND shipment_number IS NULL);

        UPDATE xxdo_po_asn_receipt_dtl_stg dtl
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND rcpt_type = NVL (p_in_chr_rcpt_type, rcpt_type)
               AND shipment_number IS NULL
               AND EXISTS
                       (SELECT 1
                          FROM xxdo_po_asn_receipt_head_stg hdr
                         WHERE hdr.receipt_header_seq_id =
                               dtl.receipt_header_seq_id);


        p_out_num_record_count   := SQL%ROWCOUNT;

        --Added for change 5.1 - START
        --Error out the records with decimal ASN qty(ASN qty should be a whole number)
        BEGIN
            UPDATE xxdo_po_asn_receipt_dtl_stg
               SET process_status = 'ERROR', error_message = 'QTY cannot have Decimals', last_updated_by = g_num_user_id,
                   last_update_date = SYSDATE
             WHERE     1 = 1
                   AND process_status = 'INPROCESS'
                   AND request_id = g_num_request_id
                   --AND TRUNC(qty) <> qty  --Decimal Check(Both Works)
                   AND MOD (qty, 1) <> 0           --Decimal Check(Both Works)
                   AND wh_id = NVL (p_in_chr_warehouse, wh_id)
                   AND rcpt_type = NVL (p_in_chr_rcpt_type, rcpt_type)
                   AND shipment_number IS NULL;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Unexpected error while Updating the records with Decimal QTY Error : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;

        --Added for change 5.1 - END

        UPDATE xxdo_po_asn_receipt_ser_stg
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND appointment_id =
                   NVL (p_in_chr_appointment_id, appointment_id)
               AND wh_id = NVL (p_in_chr_warehouse, wh_id)
               AND shipment_number IS NULL;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_out_chr_retcode   := '2';
            p_out_chr_errbuf    := SQLERRM;
            fnd_file.put_line (
                fnd_file.LOG,
                'ERROR in lock records procedure : ' || p_out_chr_errbuf);
    END lock_po_records;

    -- ***************************************************************************
    -- Procedure/Function Name  :  insert_asn_data
    --
    -- Description              :  This purpose of this procedure is to validate the asn receipt data and insert into the interface tables
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                p_in_chr_warehouse    IN  : Warehouse code
    --
    --                                p_in_chr_shipment_no  IN  : Shipment number
    --                                p_in_num_purge_days   IN  : Purge days
    --                                p_in_num_bulk_limit   IN  : Bulk Limit
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

    PROCEDURE process_corrections (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_warehouse IN VARCHAR2)
    IS
        l_chr_errbuf                 VARCHAR2 (4000);
        l_chr_retcode                VARCHAR2 (30);
        l_chr_err_shipment_number    VARCHAR2 (60) := '-1';
        l_num_err_head_seq_id        NUMBER := -1;
        l_chr_asn_line_exists        VARCHAR2 (1) := 'N';
        l_chr_prev_shipment_number   VARCHAR2 (60) := '-1';
        l_num_group_id               NUMBER;
        l_num_header_inf_id          NUMBER;
        l_num_deliver                NUMBER;
        l_chr_trx_type               VARCHAR2 (20);
        l_chr_source_document_code   VARCHAR2 (30);
        l_chr_first_trans_type       VARCHAR2 (30);
        l_chr_sec_trans_type         VARCHAR2 (30);
        l_num_qty_to_be_adj          NUMBER;
        l_num_curr_trans_qty         NUMBER;
        l_num_sec_group_id           NUMBER;
        l_chr_organization           VARCHAR2 (3) := NULL;
        l_num_record_count           NUMBER := 0;
        l_bol_req_status             BOOLEAN;
        l_chr_req_failure            VARCHAR2 (1) := 'N';
        l_chr_phase                  VARCHAR2 (100) := NULL;
        l_chr_status                 VARCHAR2 (100) := NULL;
        l_chr_dev_phase              VARCHAR2 (100) := NULL;
        l_chr_dev_status             VARCHAR2 (100) := NULL;
        l_chr_message                VARCHAR2 (1000) := NULL;
        l_chr_qty_err_msg            VARCHAR2 (1000) := NULL;
        l_num_car_rcvd_qty           NUMBER;
        l_org_ids_tab                g_ids_int_tab_type;
        l_request_ids_tab            g_ids_int_tab_type;
        l_exe_warehouse_err          EXCEPTION;
        l_exe_asn_err                EXCEPTION;
        l_exe_item_err               EXCEPTION;
        l_exe_qty_err                EXCEPTION;
        l_exe_subinv_err             EXCEPTION;
        l_exe_item_line_no_err       EXCEPTION;
        l_exe_uom_err                EXCEPTION;
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_locator_err            EXCEPTION;
        l_exe_lock_err               EXCEPTION;
        l_exe_request_failure        EXCEPTION;
        l_exe_update_failure         EXCEPTION;

        CURSOR cur_inv_arg_attributes IS
            SELECT flv.lookup_code organization_code, mp.attribute15 lpn_receiving, mp.attribute12 partial_asn,
                   mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.lookup_code
                   AND mp.organization_code IN
                           (SELECT wh_id
                              FROM xxdo_po_asn_receipt_head_stg
                             WHERE request_id = g_num_request_id);

        CURSOR cur_sub_inventories (p_num_organization_id IN NUMBER)
        IS
            SELECT secondary_inventory_name subinventory
              FROM mtl_secondary_inventories
             WHERE organization_id = p_num_organization_id;

        CURSOR cur_asn_details IS
              SELECT headers.receipt_header_seq_id, headers.wh_id, headers.receipt_date,
                     headers.employee_id, mp.organization_id, mp.organization_code, -- ver 5.7
                     dtl.receipt_dtl_seq_id, dtl.shipment_number, dtl.po_number,
                     dtl.line_number, dtl.item_number, get_inventory_item_id (dtl.item_number, mp.master_organization_id) inventory_item_id, -- Modified for BT Remediation
                     dtl.rcpt_type, dtl.qty, dtl.ordered_uom,
                     dtl.host_subinventory, dtl.carton_id, dtl.receipt_source_code,
                     dtl.shipment_header_id, dtl.shipment_line_id, dtl.po_header_id,
                     dtl.po_line_id, dtl.requisition_header_id, dtl.requisition_line_id,
                     dtl.org_id, NULL ebs_shipment_number, dtl.vendor_id,
                     dtl.LOCATOR, dtl.locator_id
                FROM xxdo_po_asn_receipt_head_stg headers, xxdo_po_asn_receipt_dtl_stg dtl, mtl_parameters mp
               WHERE     headers.receipt_header_seq_id =
                         dtl.receipt_header_seq_id
                     AND headers.request_id = g_num_request_id
                     AND headers.process_status = 'INPROCESS'
                     AND dtl.process_status = 'INPROCESS'
                     AND headers.wh_id = mp.organization_code
                     AND dtl.shipment_number IS NOT NULL
                     AND dtl.rcpt_type = 'ADJUST'
                     /* AND mp.organization_id = NVL(p_in_chr_warehouse, mp.organization_id)*/
                     /*Change condition to Organization code Begin*/
                     AND mp.organization_code =
                         NVL (p_in_chr_warehouse, mp.organization_code)
            /*Change condition to Organization code End*/
            ORDER BY dtl.shipment_number, dtl.po_number, dtl.line_number,
                     headers.receipt_date;                     -- MULTIPLE_NEG

        TYPE l_asn_details_tab_type IS TABLE OF cur_asn_details%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_asn_details_tab            l_asn_details_tab_type;

        CURSOR cur_ebs_shipment_lines (p_num_shipment_header_id IN NUMBER, p_chr_receipt_source_code IN VARCHAR2, p_num_line_number IN NUMBER
                                       , p_num_item_id IN NUMBER)
        IS
            SELECT DISTINCT pha.org_id, rsl.shipment_line_status_code, rsl.quantity_shipped,
                            rsl.quantity_received, --rsl.unit_of_measure, -- Commented by Infosys , CRP Issue 25122014
                                                   muom.uom_code unit_of_measure, -- Added by Infosys , CRP Issue 25122014
                                                                                  rsl.locator_id,
                            rsl.deliver_to_location_id, pha.po_header_id, pla.po_line_id,
                            NULL req_header_id, NULL req_line_id, rsl.shipment_line_id,
                            rsl.from_organization_id, rsl.to_organization_id, rsl.req_distribution_id,
                            rsl.deliver_to_person_id, rsl.source_document_code
              FROM rcv_shipment_lines rsl, po_line_locations_all plla, po_lines_all pla,
                   po_headers_all pha, mtl_units_of_measure muom
             WHERE     rsl.shipment_header_id = p_num_shipment_header_id
                   AND rsl.line_num = p_num_line_number
                   AND rsl.item_id = p_num_item_id
                   AND rsl.po_line_location_id = plla.line_location_id
                   AND plla.po_header_id = pha.po_header_id
                   AND plla.po_line_id = pla.po_line_id
                   AND rsl.unit_of_measure = muom.unit_of_measure
                   AND p_chr_receipt_source_code = 'VENDOR'
            UNION ALL
            SELECT prha.org_id, rsl.shipment_line_status_code, rsl.quantity_shipped,
                   rsl.quantity_received, --rsl.unit_of_measure, -- Commented by Infosys , CRP Issue 25122014
                                          muom.uom_code unit_of_measure, -- Added by Infosys , CRP Issue 25122014
                                                                         rsl.locator_id,
                   rsl.deliver_to_location_id, NULL po_header_id, NULL po_line_id,
                   prha.requisition_header_id req_header_id, prla.requisition_line_id req_line_id, rsl.shipment_line_id,
                   rsl.from_organization_id, rsl.to_organization_id, rsl.req_distribution_id,
                   rsl.deliver_to_person_id, rsl.source_document_code
              FROM rcv_shipment_lines rsl, po_requisition_lines_all prla, po_requisition_headers_all prha,
                   mtl_units_of_measure muom
             WHERE     rsl.shipment_header_id = p_num_shipment_header_id
                   AND rsl.line_num = p_num_line_number
                   AND rsl.item_id = p_num_item_id
                   AND rsl.requisition_line_id = prla.requisition_line_id
                   AND prla.requisition_header_id =
                       prha.requisition_header_id
                   AND rsl.unit_of_measure = muom.unit_of_measure
                   AND p_chr_receipt_source_code = 'INTERNAL ORDER';

        ebs_shipment_lines_rec       cur_ebs_shipment_lines%ROWTYPE;

        CURSOR cur_trans (p_num_shipment_line_id IN NUMBER, p_chr_transaction_type IN VARCHAR2, p_chr_carton_no IN VARCHAR2)
        IS
              SELECT transaction_id,
                     quantity,
                       quantity
                     + NVL (attribute11, 0)
                     + NVL (
                           (SELECT SUM (quantity)
                              FROM rcv_transactions rt_corr
                             WHERE     shipment_line_id =
                                       p_num_shipment_line_id
                                   AND transaction_type = 'CORRECT'
                                   AND NVL (attribute6, '-1') =
                                       NVL (p_chr_carton_no, '-1')
                                   AND rt_corr.parent_transaction_id =
                                       rt.transaction_id),
                           0) available_qty
                FROM rcv_transactions rt
               WHERE     shipment_line_id = p_num_shipment_line_id
                     AND transaction_type = p_chr_transaction_type
                     AND NVL (attribute6, '-1') = NVL (p_chr_carton_no, '-1')
            ORDER BY transaction_date;

        TYPE l_transactions_tab_type IS TABLE OF cur_trans%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_transactions_tab           l_transactions_tab_type;
        l_transaction_date           DATE;                          -- ver 5.7
        l_offset_time                NUMBER := 0;                        --5.7
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        IF p_in_chr_warehouse IS NOT NULL
        THEN
            /*
            SELECT organization_code
            INTO l_chr_organization
            FROM mtl_parameters
            WHERE organization_id = p_in_chr_warehouse;
            */
            l_chr_organization   := p_in_chr_warehouse;
        END IF;

        BEGIN
            lock_records (p_out_chr_errbuf          => l_chr_errbuf,
                          p_out_chr_retcode         => l_chr_retcode,
                          p_in_chr_warehouse        => l_chr_organization,
                          p_in_chr_appointment_id   => NULL,
                          p_in_chr_rcpt_type        => 'ADJUST',
                          p_out_num_record_count    => l_num_record_count);

            IF l_chr_retcode <> '0'
            THEN
                p_out_chr_errbuf   :=
                    'Error in lock records procedure : ' || l_chr_errbuf;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_lock_err;
            END IF;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                       'Unexpected error while invoking lock records procedure : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_lock_err;
        END;

        IF NVL (l_num_record_count, 0) = 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no eligible adjustments in the staging table');
            RETURN;
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'Getting WMS warehouse details');

        --Get WMS warehouse details
        FOR inv_arg_attributes_rec IN cur_inv_arg_attributes
        LOOP
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).organization_id   :=
                inv_arg_attributes_rec.organization_id;
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).warehouse_code   :=
                inv_arg_attributes_rec.organization_code;
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).lpn_receiving   :=
                NVL (inv_arg_attributes_rec.lpn_receiving, '2');
            g_inv_org_attr_tab (inv_arg_attributes_rec.organization_code).partial_asn   :=
                NVL (inv_arg_attributes_rec.partial_asn, '1');

            FOR sub_inventories_rec
                IN cur_sub_inventories (
                       inv_arg_attributes_rec.organization_id)
            LOOP
                g_sub_inventories_tab (
                       inv_arg_attributes_rec.organization_code
                    || '|'
                    || sub_inventories_rec.subinventory)   :=
                    inv_arg_attributes_rec.organization_id;
            END LOOP;
        END LOOP;

        -------------------------------------------------------------------------------------------------------------------
        --- Processing deliver transactions for -ve corrections and transactions for +ve corrections ---
        --------------------------------------------------------------------------------------------------------------------
        --Generate the group id
        SELECT rcv_interface_groups_s.NEXTVAL INTO l_num_group_id FROM DUAL;

        fnd_file.put_line (fnd_file.LOG, 'Group Id : ' || l_num_group_id);

        OPEN cur_asn_details;

        LOOP
            IF l_asn_details_tab.EXISTS (1)
            THEN
                l_asn_details_tab.DELETE;
            END IF;

            BEGIN
                fnd_file.put_line (fnd_file.LOG, 'Fetching the ASN Details');

                FETCH cur_asn_details
                    BULK COLLECT INTO l_asn_details_tab
                    LIMIT 1000;

                fnd_file.put_line (fnd_file.LOG, 'Fetched the ASN details');
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_details;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_asn_details_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Processing the ASN Details');

            FOR l_num_ind IN l_asn_details_tab.FIRST ..
                             l_asn_details_tab.LAST
            LOOP
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing started for the ASN header : '
                        || l_asn_details_tab (l_num_ind).shipment_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'PO number: '
                        || l_asn_details_tab (l_num_ind).po_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'line number : '
                        || l_asn_details_tab (l_num_ind).line_number);

                    -- Validate whether inventory org is WMS enabled for current ASN receipt header - appointment
                    IF l_num_err_head_seq_id <>
                       l_asn_details_tab (l_num_ind).receipt_header_seq_id
                    THEN
                        BEGIN
                            l_asn_details_tab (l_num_ind).organization_id   :=
                                g_inv_org_attr_tab (
                                    l_asn_details_tab (l_num_ind).wh_id).organization_id;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_asn_details_tab (l_num_ind).organization_id   :=
                                    NULL;
                        END;

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Validating whether '
                            || l_asn_details_tab (l_num_ind).wh_id
                            || ' is WMS warehouse');

                        IF l_asn_details_tab (l_num_ind).organization_id
                               IS NULL
                        THEN
                            RAISE l_exe_warehouse_err;
                        END IF;
                    END IF;

                    -- Validate whether ASN number is valid at the given inventory org, for the current shipment number
                    IF l_chr_err_shipment_number <>
                       l_asn_details_tab (l_num_ind).shipment_number
                    THEN
                        BEGIN
                            SELECT rsh.receipt_source_code, rsh.shipment_header_id, rsh.shipment_num,
                                   rsh.vendor_id
                              INTO l_asn_details_tab (l_num_ind).receipt_source_code, l_asn_details_tab (l_num_ind).shipment_header_id, l_asn_details_tab (l_num_ind).ebs_shipment_number,
                                   l_asn_details_tab (l_num_ind).vendor_id
                              FROM rcv_shipment_headers rsh
                             WHERE     rsh.ship_to_org_id =
                                       l_asn_details_tab (l_num_ind).organization_id
                                   AND rsh.shipment_num =
                                       l_asn_details_tab (l_num_ind).shipment_number;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_asn_details_tab (l_num_ind).receipt_source_code   :=
                                    NULL;
                                l_asn_details_tab (l_num_ind).shipment_header_id   :=
                                    NULL;
                                l_asn_details_tab (l_num_ind).ebs_shipment_number   :=
                                    NULL;
                                l_asn_details_tab (l_num_ind).vendor_id   :=
                                    NULL;
                        END;

                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Validating whether shipment number is valid at the given org');

                        IF l_asn_details_tab (l_num_ind).ebs_shipment_number
                               IS NULL
                        THEN
                            RAISE l_exe_asn_err;
                        END IF;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_asn_details_tab (l_num_ind).item_number
                        || ' is valid item');

                    -- Validate whether item number is valid for each ASN line in XML
                    IF l_asn_details_tab (l_num_ind).inventory_item_id
                           IS NULL
                    THEN
                        RAISE l_exe_item_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_asn_details_tab (l_num_ind).host_subinventory
                        || ' is valid sub inventory');

                    -- Validate whether subinventory is valid for each ASN line in XML
                    IF l_asn_details_tab (l_num_ind).host_subinventory
                           IS NOT NULL
                    THEN
                        IF NOT g_sub_inventories_tab.EXISTS (
                                      l_asn_details_tab (l_num_ind).wh_id
                                   || '|'
                                   || l_asn_details_tab (l_num_ind).host_subinventory)
                        THEN
                            RAISE l_exe_subinv_err;
                        END IF;
                    END IF;

                    -- Reset the shipment line id
                    ebs_shipment_lines_rec.shipment_line_id   := NULL;

                    -- Fetch the EBS ASN lines and other details
                    BEGIN
                        OPEN cur_ebs_shipment_lines (
                            l_asn_details_tab (l_num_ind).shipment_header_id,
                            l_asn_details_tab (l_num_ind).receipt_source_code,
                            l_asn_details_tab (l_num_ind).line_number,
                            l_asn_details_tab (l_num_ind).inventory_item_id);

                        FETCH cur_ebs_shipment_lines
                            INTO ebs_shipment_lines_rec;

                        CLOSE cur_ebs_shipment_lines;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ebs_shipment_lines_rec.shipment_line_id   := NULL;
                    END;

                    -- Validate whether shipment line is fetched - line number and item number are present in the ASN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validating whether item number and line number combination is valid');

                    IF ebs_shipment_lines_rec.shipment_line_id IS NULL
                    THEN
                        RAISE l_exe_item_line_no_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Validating whether '
                        || l_asn_details_tab (l_num_ind).ordered_uom
                        || ' is valid UOM');

                    IF ebs_shipment_lines_rec.unit_of_measure <>
                       l_asn_details_tab (l_num_ind).ordered_uom
                    THEN
                        RAISE l_exe_uom_err;
                    END IF;

                    -- Validate whether the received qty in XML is less than or equal to open qty
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Validating whether the received qty is less than or equal to open qty ');

                    IF l_asn_details_tab (l_num_ind).qty < 0
                    THEN
                        IF NVL (ebs_shipment_lines_rec.quantity_received, 0) <
                           ABS (l_asn_details_tab (l_num_ind).qty)
                        THEN
                            l_chr_qty_err_msg   :=
                                'Adjusted Qty is more than already Received Qty';
                            RAISE l_exe_qty_err;
                        END IF;
                    ELSE
                        IF   ebs_shipment_lines_rec.quantity_shipped
                           - NVL (ebs_shipment_lines_rec.quantity_received,
                                  0) <
                           l_asn_details_tab (l_num_ind).qty
                        THEN
                            l_chr_qty_err_msg   :=
                                'Adjusted Qty  is more than Open Qty';
                            RAISE l_exe_qty_err;
                        END IF;
                    END IF;

                    /*Qty validation logicbased on carton in adjustment processing Begin*/
                    IF l_asn_details_tab (l_num_ind).qty < 0
                    THEN
                        l_chr_first_trans_type   := 'DELIVER';
                        l_num_qty_to_be_adj      :=
                            ABS (l_asn_details_tab (l_num_ind).qty);
                    ELSE
                        l_chr_first_trans_type   := 'RECEIVE';
                    END IF;

                    IF l_asn_details_tab (l_num_ind).qty < 0
                    THEN
                        BEGIN
                            SELECT NVL (
                                       SUM (
                                             quantity
                                           + NVL (
                                                 (SELECT SUM (quantity)
                                                    FROM rcv_transactions rt_corr
                                                   WHERE     shipment_line_id =
                                                             ebs_shipment_lines_rec.shipment_line_id
                                                         AND transaction_type =
                                                             'CORRECT'
                                                         AND NVL (attribute6,
                                                                  '-1') =
                                                             NVL (
                                                                 l_asn_details_tab (
                                                                     l_num_ind).carton_id,
                                                                 '-1')
                                                         AND rt_corr.parent_transaction_id =
                                                             rt.transaction_id),
                                                 0)),
                                       0) available_qty
                              INTO l_num_car_rcvd_qty
                              FROM rcv_transactions rt
                             WHERE     shipment_line_id =
                                       ebs_shipment_lines_rec.shipment_line_id
                                   AND transaction_type =
                                       l_chr_first_trans_type
                                   AND NVL (attribute6, '-1') =
                                       NVL (
                                           l_asn_details_tab (l_num_ind).carton_id,
                                           '-1');
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_num_car_rcvd_qty   := 0;
                        END;

                        IF NVL (l_num_car_rcvd_qty, 0) <
                           ABS (l_asn_details_tab (l_num_ind).qty)
                        THEN
                            l_chr_qty_err_msg   :=
                                   'Adjusted Qty is more than already Received Qty in Carton : '
                                || l_asn_details_tab (l_num_ind).carton_id;
                            RAISE l_exe_qty_err;
                        END IF;
                    END IF;

                    /*Qty validation logicbased on carton in adjustment processing End*/
                    -- Insert header record only once for each shipment number
                    l_num_header_inf_id                       := NULL;
                    l_chr_trx_type                            := 'CORRECT';

                    IF l_asn_details_tab (l_num_ind).LOCATOR IS NOT NULL
                    THEN
                        BEGIN
                            SELECT inventory_location_id
                              INTO l_asn_details_tab (l_num_ind).locator_id
                              FROM mtl_item_locations_kfv
                             WHERE     organization_id =
                                       l_asn_details_tab (l_num_ind).organization_id
                                   AND subinventory_code =
                                       l_asn_details_tab (l_num_ind).host_subinventory
                                   AND concatenated_segments =
                                       l_asn_details_tab (l_num_ind).LOCATOR
                                   AND SYSDATE BETWEEN NVL (
                                                           start_date_active,
                                                           SYSDATE - 1)
                                                   AND NVL (end_date_active,
                                                            SYSDATE + 1)
                                   AND NVL (disable_date, SYSDATE + 1) >
                                       SYSDATE
                                   AND enabled_flag = 'Y';
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_asn_details_tab (l_num_ind).locator_id   :=
                                    NULL;
                        END;
                    ELSE
                        l_asn_details_tab (l_num_ind).locator_id   := NULL;
                    END IF;

                    -- Validate whether locator passed is valid
                    IF     l_asn_details_tab (l_num_ind).LOCATOR IS NOT NULL
                       AND l_asn_details_tab (l_num_ind).locator_id IS NULL
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'Validating whether the locator '
                            || l_asn_details_tab (l_num_ind).LOCATOR
                            || ' is valid');
                        RAISE l_exe_locator_err;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into rcv_transactions_interface for the shipment line id: '
                        || ebs_shipment_lines_rec.shipment_line_id);

                    FOR trans_rec
                        IN cur_trans (
                               ebs_shipment_lines_rec.shipment_line_id,
                               l_chr_first_trans_type,
                               l_asn_details_tab (l_num_ind).carton_id)
                    LOOP
                        l_num_curr_trans_qty   := 0;

                        IF l_asn_details_tab (l_num_ind).qty < 0
                        THEN                    -- Logic for negative quantity
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_asn_details_tab (l_num_ind).qty : '
                                || l_asn_details_tab (l_num_ind).qty);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_num_qty_to_be_adj : '
                                || l_num_qty_to_be_adj);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'trans_rec.transaction_id : ' || trans_rec.transaction_id);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'trans_rec.quantity : ' || trans_rec.quantity);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'trans_rec.available_qty : ' || trans_rec.transaction_id);

                            IF l_num_qty_to_be_adj >= trans_rec.available_qty
                            THEN            --l_num_qty_to_be_adj is ABS value
                                IF trans_rec.available_qty > 0
                                THEN -- If already correction was done, the available qty can be zero
                                    l_num_curr_trans_qty   :=
                                        -trans_rec.available_qty;
                                END IF;
                            ELSE
                                l_num_curr_trans_qty   :=
                                    -l_num_qty_to_be_adj;
                            END IF;

                            l_num_qty_to_be_adj   :=
                                l_num_qty_to_be_adj + l_num_curr_trans_qty;

                            /* MULTIPLE_NEG - Start */
                            UPDATE rcv_transactions
                               SET attribute11 = NVL (attribute11, 0) + l_num_curr_trans_qty
                             WHERE transaction_id = trans_rec.transaction_id;

                            /* MULTIPLE_NEG - End */
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'l_num_curr_trans_qty : '
                                || l_num_curr_trans_qty);
                        ELSE -- Entire positive qty can be adjusted on the last transaction
                            l_num_curr_trans_qty   :=
                                l_asn_details_tab (l_num_ind).qty;
                        END IF;

                        -- begin ver 5.7
                        IF l_asn_details_tab (l_num_ind).organization_code =
                           'US6'
                        THEN
                            BEGIN
                                l_offset_time   :=
                                    get_offset_time (
                                        l_asn_details_tab (l_num_ind).organization_code);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_offset_time   := 0;
                            END;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'process correction: inside US6 , l_offset_time is : '
                                || l_offset_time);

                            -- below logic was  used directly in the insert statement. but as part of ver 5.8, we extract it, put it into the variable (l_transaction_date)
                            -- and then use that variable in the insert.
                            SELECT DECODE (TO_CHAR (l_asn_details_tab (l_num_ind).receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), (l_asn_details_tab (l_num_ind).receipt_date + NVL (l_offset_time, 0)), (SYSDATE))
                              INTO l_transaction_date
                              FROM DUAL;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'inside US6 , trans time after offset is : '
                                || TO_CHAR (l_transaction_date,
                                            'DD-MON-YYYY HH24:MI:SS'));
                        ELSE
                            SELECT DECODE (TO_CHAR (l_asn_details_tab (l_num_ind).receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), l_asn_details_tab (l_num_ind).receipt_date, SYSDATE)
                              INTO l_transaction_date
                              FROM DUAL;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'process correction inside <> us6 , trans time is : '
                                || l_transaction_date);
                        END IF;

                        -- end ver 5.7
                        IF l_num_curr_trans_qty <> 0
                        THEN
                            -- Insert one record for each ASN Line
                            INSERT INTO rcv_transactions_interface (
                                            interface_transaction_id,
                                            GROUP_ID,
                                            org_id,
                                            last_update_date,
                                            last_updated_by,
                                            creation_date,
                                            created_by,
                                            last_update_login,
                                            transaction_type,
                                            transaction_date,
                                            processing_status_code,
                                            processing_mode_code,
                                            transaction_status_code,
                                            quantity,
                                            --     unit_of_measure,  -- Commented by Infosys , CRP Issue 25122014
                                            uom_code, -- Added by Infosys , CRP Issue 25122014
                                            interface_source_code,
                                            item_id,
                                            --                            employee_id,
                                            --                            auto_transact_code,
                                            shipment_header_id,
                                            shipment_line_id,
                                            ship_to_location_id,
                                            receipt_source_code,
                                            to_organization_id,
                                            source_document_code,
                                            requisition_line_id,
                                            req_distribution_id,
                                            --                            destination_type_code,
                                            deliver_to_person_id,
                                            location_id,
                                            deliver_to_location_id,
                                            subinventory,
                                            locator_id,
                                            shipment_num,
                                            --                            expected_receipt_date,
                                            header_interface_id,
                                            validation_flag,
                                            oe_order_header_id,
                                            oe_order_line_id,
                                            customer_id,
                                            customer_site_id,
                                            vendor_id,
                                            parent_transaction_id,
                                            attribute6)
                                     VALUES (
                                                rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                                                    ,
                                                l_num_group_id      --group_id
                                                              ,
                                                ebs_shipment_lines_rec.org_id,
                                                SYSDATE     --last_update_date
                                                       ,
                                                fnd_global.user_id --last_updated_by
                                                                  ,
                                                SYSDATE        --creation_date
                                                       ,
                                                fnd_global.user_id --created_by
                                                                  ,
                                                USERENV ('SESSIONID') --last_update_login
                                                                     ,
                                                l_chr_trx_type --transaction_type
                                                              ,
                                                --                          SYSDATE                         --transaction_date  -- MULTIPLE_NEG
                                                l_transaction_date  -- ver 5.7
                                                                  /*DECODE (
                                                                     TO_CHAR (
                                                                        l_asn_details_tab (l_num_ind).receipt_date,
                                                                        'YYYYMM'),
                                                                     TO_CHAR (SYSDATE, 'YYYYMM'), l_asn_details_tab (
                                                                                                     l_num_ind).receipt_date,
                                                                     SYSDATE) */
                                                                  -- MULTIPLE_NEG include Change of date logic/*<Ver5.0 : Added Receipt date logic>*/
                                                                  ,
                                                'PENDING' --processing_status_code
                                                         ,
                                                'BATCH' --processing_mode_code
                                                       ,
                                                'PENDING' --transaction_status_code
                                                         ,
                                                l_num_curr_trans_qty --quantity
                                                                    ,
                                                l_asn_details_tab (l_num_ind).ordered_uom --unit_of_measure
                                                                                         ,
                                                'RCV'  --interface_source_code
                                                     ,
                                                l_asn_details_tab (l_num_ind).inventory_item_id --item_id
                                                                                               ,
                                                --                            NVL
                                                --                               (l_asn_details_tab (l_num_ind).employee_id,
                                                --                                fnd_global.employee_id
                                                --                               )                                 --employee_id
                                                --                                ,
                                                --                            'DELIVER'                     --auto_transact_code
                                                --                                     ,
                                                l_asn_details_tab (l_num_ind).shipment_header_id --shipment_header_id
                                                                                                ,
                                                ebs_shipment_lines_rec.shipment_line_id --shipment_line_id
                                                                                       ,
                                                ebs_shipment_lines_rec.deliver_to_location_id --ship_to_location_id
                                                                                             ,
                                                l_asn_details_tab (l_num_ind).receipt_source_code --receipt_source_code
                                                                                                 ,
                                                ebs_shipment_lines_rec.to_organization_id --to_organization_id
                                                                                         ,
                                                ebs_shipment_lines_rec.source_document_code --source_document_code
                                                                                           ,
                                                ebs_shipment_lines_rec.req_line_id --requisition_line_id
                                                                                  ,
                                                ebs_shipment_lines_rec.req_distribution_id --req_distribution_id
                                                                                          ,
                                                --                          'INVENTORY'                --destination_type_code
                                                --                                       ,
                                                ebs_shipment_lines_rec.deliver_to_person_id --deliver_to_person_id
                                                                                           ,
                                                NULL             --location_id
                                                    ,
                                                ebs_shipment_lines_rec.deliver_to_location_id --deliver_to_location_id
                                                                                             ,
                                                l_asn_details_tab (l_num_ind).host_subinventory --subinventory
                                                                                               ,
                                                l_asn_details_tab (l_num_ind).locator_id,
                                                l_asn_details_tab (l_num_ind).shipment_number --shipment_num
                                                                                             ,
                                                --                            l_asn_details_tab (l_num_ind).receipt_date
                                                --                                                                      --expected_receipt_date,
                                                --               ,
                                                NULL     --header_interface_id
                                                    ,
                                                'Y'          --validation_flag
                                                   ,
                                                NULL      --oe_order_header_id
                                                    ,
                                                NULL        --oe_order_line_id
                                                    ,
                                                NULL             --customer_id
                                                    ,
                                                NULL        --customer_site_id
                                                    ,
                                                l_asn_details_tab (l_num_ind).vendor_id,
                                                trans_rec.transaction_id, --p_parent_transaction_id
                                                l_asn_details_tab (l_num_ind).carton_id);
                        ELSE
                            l_chr_qty_err_msg   :=
                                'Adjusted Qty  is more than Open Qty';
                            RAISE l_exe_qty_err;
                        END IF;

                        IF    l_asn_details_tab (l_num_ind).qty > 0
                           OR l_num_qty_to_be_adj = 0
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;

                    UPDATE xxdo_po_asn_receipt_dtl_stg
                       SET shipment_header_id = l_asn_details_tab (l_num_ind).shipment_header_id, po_header_id = ebs_shipment_lines_rec.po_header_id, lpn_id = NULL,
                           inventory_item_id = l_asn_details_tab (l_num_ind).inventory_item_id, organization_id = ebs_shipment_lines_rec.to_organization_id, receipt_source_code = l_asn_details_tab (l_num_ind).receipt_source_code,
                           open_qty = ebs_shipment_lines_rec.quantity_shipped - NVL (ebs_shipment_lines_rec.quantity_received, 0), po_line_id = ebs_shipment_lines_rec.po_line_id, shipment_line_id = ebs_shipment_lines_rec.shipment_line_id,
                           requisition_header_id = ebs_shipment_lines_rec.req_header_id, requisition_line_id = ebs_shipment_lines_rec.req_line_id, GROUP_ID = l_num_group_id,
                           org_id = ebs_shipment_lines_rec.org_id, locator_id = l_asn_details_tab (l_num_ind).locator_id, vendor_id = l_asn_details_tab (l_num_ind).vendor_id
                     WHERE     receipt_dtl_seq_id =
                               l_asn_details_tab (l_num_ind).receipt_dtl_seq_id
                           AND process_status = 'INPROCESS'
                           AND request_id = g_num_request_id;
                EXCEPTION
                    WHEN l_exe_warehouse_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => NULL, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'Inventory Org is not WMS enabled', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                        l_num_err_head_seq_id   :=
                            l_asn_details_tab (l_num_ind).receipt_header_seq_id;
                    WHEN l_exe_asn_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => NULL, p_in_chr_error_message => 'Shipment Number : ' || l_asn_details_tab (l_num_ind).shipment_number || ' is not valid at the org : ' || l_asn_details_tab (l_num_ind).wh_id, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                        l_chr_err_shipment_number   :=
                            l_asn_details_tab (l_num_ind).shipment_number;
                    WHEN l_exe_item_line_no_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Item number and line number combination is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_item_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Item number is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_qty_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, --                      p_in_chr_error_message        => 'Receipt Qty is more than Open Qty',
                                                                                                                                                                                                                                                                                                                                                                                           p_in_chr_error_message => l_chr_qty_err_msg, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_uom_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Receipt UOM does not match with EBS ASN UOM', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_subinv_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Sub-inventory is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN l_exe_locator_err
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Locator is not valid', p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                    WHEN OTHERS
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Unexpected Error : ' || SQLERRM, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                END;
            END LOOP;                           -- ASN details processing loop
        END LOOP;                                    -- ASN details fetch loop

        CLOSE cur_asn_details;

        COMMIT;

        -- Get all the org ids into a table type variable
        BEGIN
            SELECT DISTINCT org_id
              BULK COLLECT INTO l_org_ids_tab
              FROM rcv_transactions_interface
             WHERE GROUP_ID = l_num_group_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                IF l_org_ids_tab.EXISTS (1)
                THEN
                    l_org_ids_tab.DELETE;
                END IF;
        END;

        IF NOT l_org_ids_tab.EXISTS (1)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no eligible records to launch the transaction processor for corrections');
        ELSE
            --Launch the transaction processor for each org
            fnd_file.put_line (fnd_file.LOG,
                               'Launching the transaction processor');

            IF l_request_ids_tab.EXISTS (1)
            THEN
                l_request_ids_tab.DELETE;
            END IF;

            FOR l_num_index IN 1 .. l_org_ids_tab.COUNT
            LOOP
                l_request_ids_tab (l_num_index)   :=
                    fnd_request.submit_request (
                        application   => 'PO',
                        program       => 'RVCTP',
                        argument1     => 'BATCH',
                        argument2     => TO_CHAR (l_num_group_id),
                        argument3     => TO_CHAR (l_org_ids_tab (l_num_index)));
                COMMIT;

                IF l_request_ids_tab (l_num_index) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Org Id :  '
                        || l_org_ids_tab (l_num_index)
                        || '  Transaction Processor is not launched');
                    p_out_chr_retcode   := '1';
                    p_out_chr_errbuf    :=
                        'Transaction Processor is not launched for one or more org ids. Please refer the log file for more details';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Org Id :  '
                        || l_org_ids_tab (l_num_index)
                        || '  Transaction Processor request id : '
                        || l_request_ids_tab (l_num_index));
                END IF;
            END LOOP;

            COMMIT;
            l_chr_req_failure   := 'N';
            fnd_file.put_line (fnd_file.LOG, '');
            fnd_file.put_line (
                fnd_file.LOG,
                '-------------Concurrent Requests Status Report ---------------');

            FOR l_num_index IN 1 .. l_request_ids_tab.COUNT
            LOOP
                l_bol_req_status   :=
                    fnd_concurrent.wait_for_request (
                        l_request_ids_tab (l_num_index),
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
                    || l_request_ids_tab (l_num_index)
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
                    'One or more Transaction Processor requests ended in Warning or Error. Please refer the log file for more details';
            END IF;
        END IF;

        -------------------------------------------------------------------------------------------------------------------
        --- Processing Receiving transactions for -ve corrections  transactions for +ve corrections ---
        --------------------------------------------------------------------------------------------------------------------
        --Generate the group id
        SELECT rcv_interface_groups_s.NEXTVAL
          INTO l_num_sec_group_id
          FROM DUAL;

        fnd_file.put_line (fnd_file.LOG, 'Group Id : ' || l_num_sec_group_id);

        OPEN cur_asn_details;

        LOOP
            IF l_asn_details_tab.EXISTS (1)
            THEN
                l_asn_details_tab.DELETE;
            END IF;

            BEGIN
                fnd_file.put_line (fnd_file.LOG, 'Fetching the ASN Details');

                FETCH cur_asn_details
                    BULK COLLECT INTO l_asn_details_tab
                    LIMIT 1000;

                fnd_file.put_line (fnd_file.LOG, 'Fetched the ASN details');
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_asn_details;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of ASN Receipt Headers : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_asn_details_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            fnd_file.put_line (fnd_file.LOG, 'Processing the ASN Details');

            FOR l_num_ind IN l_asn_details_tab.FIRST ..
                             l_asn_details_tab.LAST
            LOOP
                BEGIN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Processing started for the ASN header : '
                        || l_asn_details_tab (l_num_ind).shipment_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'PO number: '
                        || l_asn_details_tab (l_num_ind).po_number);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'line number : '
                        || l_asn_details_tab (l_num_ind).line_number);
                    l_num_header_inf_id   := NULL;
                    l_chr_trx_type        := 'CORRECT';
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Inserting data into rcv_transactions_interface for the shipment line id: '
                        || l_asn_details_tab (l_num_ind).shipment_line_id);

                    IF l_asn_details_tab (l_num_ind).qty < 0
                    THEN
                        l_chr_sec_trans_type   := 'RECEIVE';
                        l_num_qty_to_be_adj    :=
                            ABS (l_asn_details_tab (l_num_ind).qty);
                    ELSE
                        l_chr_sec_trans_type   := 'DELIVER';
                    END IF;

                    FOR trans_rec
                        IN cur_trans (
                               l_asn_details_tab (l_num_ind).shipment_line_id,
                               l_chr_sec_trans_type,
                               l_asn_details_tab (l_num_ind).carton_id)
                    LOOP
                        l_num_curr_trans_qty   := 0;
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_asn_details_tab (l_num_ind).qty : '
                            || l_asn_details_tab (l_num_ind).qty);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'l_num_qty_to_be_adj : ' || l_num_qty_to_be_adj);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'trans_rec.transaction_id : ' || trans_rec.transaction_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'trans_rec.quantity : ' || trans_rec.quantity);
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'trans_rec.available_qty : ' || trans_rec.transaction_id);

                        IF l_asn_details_tab (l_num_ind).qty < 0
                        THEN
                            IF l_num_qty_to_be_adj >= trans_rec.available_qty
                            THEN
                                IF trans_rec.available_qty > 0
                                THEN -- If already correction was done, the available qty can be zero
                                    l_num_curr_trans_qty   :=
                                        -trans_rec.available_qty;
                                END IF;
                            ELSE
                                l_num_curr_trans_qty   :=
                                    -l_num_qty_to_be_adj;
                            END IF;

                            l_num_qty_to_be_adj   :=
                                l_num_qty_to_be_adj + l_num_curr_trans_qty;
                        ELSE -- Entire positive qty can be adjusted on the last transaction
                            l_num_curr_trans_qty   :=
                                l_asn_details_tab (l_num_ind).qty;
                        END IF;

                        /* MULTIPLE_NEG - Start */
                        UPDATE rcv_transactions
                           SET attribute11 = NVL (attribute11, 0) + l_num_curr_trans_qty
                         WHERE transaction_id = trans_rec.transaction_id;

                        /* MULTIPLE_NEG - End */
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'l_num_curr_trans_qty : ' || l_num_curr_trans_qty);

                        -- begin ver 5.7
                        IF l_asn_details_tab (l_num_ind).organization_code =
                           'US6'
                        THEN
                            BEGIN
                                l_offset_time   :=
                                    get_offset_time (
                                        l_asn_details_tab (l_num_ind).organization_code);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    l_offset_time   := 0;
                            END;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'process correction: inside US6 , l_offset_time is : '
                                || l_offset_time);

                            -- below logic was  used directly in the insert statement. but as part of ver 5.8, we extract it, put it into the variable (l_transaction_date)
                            -- and then use that variable in the insert.
                            SELECT DECODE (TO_CHAR (l_asn_details_tab (l_num_ind).receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), (l_asn_details_tab (l_num_ind).receipt_date + NVL (l_offset_time, 0)), (SYSDATE))
                              INTO l_transaction_date
                              FROM DUAL;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'inside US6 , trans time after offset is : '
                                || TO_CHAR (l_transaction_date,
                                            'DD-MON-YYYY HH24:MI:SS'));
                        ELSE
                            SELECT DECODE (TO_CHAR (l_asn_details_tab (l_num_ind).receipt_date, 'YYYYMM'), TO_CHAR (SYSDATE, 'YYYYMM'), l_asn_details_tab (l_num_ind).receipt_date, SYSDATE)
                              INTO l_transaction_date
                              FROM DUAL;

                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'process correction inside <> us6 , trans time is : '
                                || l_transaction_date);
                        END IF;

                        -- end ver 5.7


                        IF l_num_curr_trans_qty <> 0
                        THEN
                            -- Insert one record for each ASN Line
                            INSERT INTO rcv_transactions_interface (
                                            interface_transaction_id,
                                            GROUP_ID,
                                            org_id,
                                            last_update_date,
                                            last_updated_by,
                                            creation_date,
                                            created_by,
                                            last_update_login,
                                            transaction_type,
                                            transaction_date,
                                            processing_status_code,
                                            processing_mode_code,
                                            transaction_status_code,
                                            quantity,
                                            uom_code,
                                            --unit_of_measure,
                                            interface_source_code,
                                            item_id,
                                            --                            employee_id,
                                            --                            auto_transact_code,
                                            shipment_header_id,
                                            shipment_line_id,
                                            --                            ship_to_location_id,
                                            receipt_source_code,
                                            to_organization_id,
                                            source_document_code,
                                            --                            requisition_line_id,
                                            --                            req_distribution_id,
                                            --                            destination_type_code,
                                            --                            deliver_to_person_id,
                                            --                            location_id,
                                            --                            deliver_to_location_id,
                                            subinventory,
                                            locator_id,
                                            shipment_num,
                                            --                            expected_receipt_date,
                                            header_interface_id,
                                            validation_flag,
                                            oe_order_header_id,
                                            oe_order_line_id,
                                            customer_id,
                                            customer_site_id,
                                            vendor_id,
                                            parent_transaction_id,
                                            attribute6)
                                     VALUES (
                                                rcv_transactions_interface_s.NEXTVAL -- interface_transaction_id
                                                                                    ,
                                                l_num_sec_group_id  --group_id
                                                                  ,
                                                l_asn_details_tab (l_num_ind).org_id,
                                                SYSDATE     --last_update_date
                                                       ,
                                                fnd_global.user_id --last_updated_by
                                                                  ,
                                                SYSDATE        --creation_date
                                                       ,
                                                fnd_global.user_id --created_by
                                                                  ,
                                                USERENV ('SESSIONID') --last_update_login
                                                                     ,
                                                l_chr_trx_type --transaction_type
                                                              ,
                                                --                          SYSDATE                         --transaction_date   -- MULTIPLE_NEG
                                                l_transaction_date, -- ver 5.7 l_asn_details_tab (l_num_ind).receipt_date -- MULTIPLE_NEG
                                                'PENDING' --processing_status_code
                                                         ,
                                                'BATCH' --processing_mode_code
                                                       ,
                                                'PENDING' --transaction_status_code
                                                         ,
                                                l_num_curr_trans_qty --quantity
                                                                    ,
                                                l_asn_details_tab (l_num_ind).ordered_uom --unit_of_measure
                                                                                         ,
                                                'RCV'  --interface_source_code
                                                     ,
                                                l_asn_details_tab (l_num_ind).inventory_item_id --item_id
                                                                                               ,
                                                --                            NVL
                                                --                               (l_asn_details_tab (l_num_ind).employee_id,
                                                --                                fnd_global.employee_id
                                                --                               )                                 --employee_id
                                                --                                ,
                                                --                            'DELIVER'                     --auto_transact_code
                                                --                                     ,
                                                l_asn_details_tab (l_num_ind).shipment_header_id --shipment_header_id
                                                                                                ,
                                                l_asn_details_tab (l_num_ind).shipment_line_id --shipment_line_id
                                                                                              ,
                                                --                            ebs_shipment_lines_rec.deliver_to_location_id
                                                --ship_to_location_id
                                                --               ,
                                                l_asn_details_tab (l_num_ind).receipt_source_code --receipt_source_code
                                                                                                 ,
                                                l_asn_details_tab (l_num_ind).organization_id --to_organization_id
                                                                                             ,
                                                DECODE (
                                                    l_asn_details_tab (
                                                        l_num_ind).receipt_source_code,
                                                    'VENDOR', 'PO',
                                                    'INTERNAL ORDER', 'REQ') --source_document_code
                                                                            ,
                                                --                            ebs_shipment_lines_rec.req_line_id
                                                --                                                              --requisition_line_id
                                                --               ,
                                                --                            ebs_shipment_lines_rec.req_distribution_id
                                                --                                                                      --req_distribution_id
                                                --               ,
                                                --                          'INVENTORY'                --destination_type_code
                                                --                                       ,
                                                --                            ebs_shipment_lines_rec.deliver_to_person_id
                                                --                                                                       --deliver_to_person_id
                                                --               ,
                                                --                            NULL                                 --location_id
                                                --                                ,
                                                --                            ebs_shipment_lines_rec.deliver_to_location_id
                                                --                                                                         --deliver_to_location_id
                                                --               ,
                                                l_asn_details_tab (l_num_ind).host_subinventory --subinventory
                                                                                               ,
                                                l_asn_details_tab (l_num_ind).locator_id,
                                                l_asn_details_tab (l_num_ind).shipment_number --shipment_num
                                                                                             ,
                                                --                            l_asn_details_tab (l_num_ind).receipt_date
                                                --                                                                      --expected_receipt_date,
                                                --               ,
                                                NULL     --header_interface_id
                                                    ,
                                                'Y'          --validation_flag
                                                   ,
                                                NULL      --oe_order_header_id
                                                    ,
                                                NULL        --oe_order_line_id
                                                    ,
                                                NULL             --customer_id
                                                    ,
                                                NULL        --customer_site_id
                                                    ,
                                                l_asn_details_tab (l_num_ind).vendor_id,
                                                trans_rec.transaction_id, --p_parent_transaction_id
                                                l_asn_details_tab (l_num_ind).carton_id);
                        END IF;

                        IF    l_asn_details_tab (l_num_ind).qty > 0
                           OR l_num_qty_to_be_adj = 0
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        update_error_records (p_out_chr_errbuf => l_chr_errbuf, p_out_chr_retcode => l_chr_retcode, p_in_chr_appointment_id => NULL, p_in_num_receipt_head_id => l_asn_details_tab (l_num_ind).receipt_header_seq_id, p_in_chr_shipment_no => l_asn_details_tab (l_num_ind).shipment_number, p_in_num_rcpt_dtl_seq_id => l_asn_details_tab (l_num_ind).receipt_dtl_seq_id, p_in_chr_error_message => 'Unexpected Error : ' || SQLERRM, p_in_chr_from_status => 'INPROCESS', p_in_chr_to_status => 'ERROR'
                                              , p_in_chr_warehouse => NULL);
                END;
            END LOOP;                           -- ASN details processing loop
        END LOOP;                                    -- ASN details fetch loop

        CLOSE cur_asn_details;

        COMMIT;

        IF l_org_ids_tab.EXISTS (1)
        THEN
            l_org_ids_tab.DELETE;
        END IF;

        -- Get all the org ids into a table type variable
        BEGIN
            SELECT DISTINCT org_id
              BULK COLLECT INTO l_org_ids_tab
              FROM rcv_transactions_interface
             WHERE GROUP_ID = l_num_sec_group_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                IF l_org_ids_tab.EXISTS (1)
                THEN
                    l_org_ids_tab.DELETE;
                END IF;
        END;

        IF NOT l_org_ids_tab.EXISTS (1)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'There are no eligible records to launch the transaction processor for corrections');
        ELSE
            --Launch the transaction processor for each org
            fnd_file.put_line (fnd_file.LOG,
                               'Launching the transaction processor');

            IF l_request_ids_tab.EXISTS (1)
            THEN
                l_request_ids_tab.DELETE;
            END IF;

            FOR l_num_index IN 1 .. l_org_ids_tab.COUNT
            LOOP
                l_request_ids_tab (l_num_index)   :=
                    fnd_request.submit_request (
                        application   => 'PO',
                        program       => 'RVCTP',
                        argument1     => 'BATCH',
                        argument2     => TO_CHAR (l_num_sec_group_id),
                        argument3     => TO_CHAR (l_org_ids_tab (l_num_index)));
                COMMIT;

                IF l_request_ids_tab (l_num_index) = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Org Id :  '
                        || l_org_ids_tab (l_num_index)
                        || '  Transaction Processor is not launched');
                    p_out_chr_retcode   := '1';
                    p_out_chr_errbuf    :=
                        'Transaction Processor is not launched for one or more org ids. Please refer the log file for more details';
                ELSE
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Org Id :  '
                        || l_org_ids_tab (l_num_index)
                        || '  Transaction Processor request id : '
                        || l_request_ids_tab (l_num_index));
                END IF;
            END LOOP;

            COMMIT;
            l_chr_req_failure   := 'N';
            fnd_file.put_line (fnd_file.LOG, '');
            fnd_file.put_line (
                fnd_file.LOG,
                '-------------Concurrent Requests Status Report ---------------');

            FOR l_num_index IN 1 .. l_request_ids_tab.COUNT
            LOOP
                l_bol_req_status   :=
                    fnd_concurrent.wait_for_request (
                        l_request_ids_tab (l_num_index),
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
                    || l_request_ids_tab (l_num_index)
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
                    'One or more Transaction Processor requests ended in Warning or Error. Please refer the log file for more details';
            END IF;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Updating the process status of the adjustment records ');

        -- Update the failed ASN adjustment records
        BEGIN
            /***********************************************************************/
            /*Infosys Ver 5.0: Add Rcv header interface error details              */
            /*                   condition to check records not in error status    */
            /***********************************************************************/

            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET (dtl.error_message, dtl.process_status, dtl.last_updated_by
                    , dtl.last_update_date)   =
                       (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                               SYSDATE
                          FROM po_interface_errors pie, rcv_transactions_interface rti
                         WHERE     1 = 1
                               --AND pie.interface_line_id = rti.interface_transaction_id --Commented for change 5.1
                               AND pie.interface_line_id(+) =
                                   rti.interface_transaction_id --Added for change 5.1(Added outer join on pie)
                               AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                               AND rti.po_header_id = dtl.po_header_id
                               AND rti.po_line_id = dtl.po_line_id
                               AND dtl.GROUP_ID = rti.GROUP_ID
                               AND ROWNUM < 2)
             WHERE     dtl.process_status = 'INPROCESS'
                   AND dtl.shipment_number IS NOT NULL
                   AND dtl.rcpt_type = 'ADJUST'
                   AND dtl.request_id = g_num_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM po_interface_errors pie, rcv_transactions_interface rti
                             WHERE     1 = 1
                                   --AND pie.interface_line_id = rti.interface_transaction_id --Commented for change 5.1
                                   AND pie.interface_line_id(+) =
                                       rti.interface_transaction_id --Added for change 5.1(Added outer join on pie)
                                   AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                   AND rti.po_header_id = dtl.po_header_id
                                   AND rti.po_line_id = dtl.po_line_id
                                   AND dtl.GROUP_ID = rti.GROUP_ID);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Detail Update Count in Process Corrections Procedure: '
                || SQL%ROWCOUNT);

            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET (dtl.error_message, dtl.process_status, dtl.last_updated_by
                    , dtl.last_update_date)   =
                       (SELECT REPLACE (pie.error_message, CHR (10), ';'), 'ERROR', g_num_user_id,
                               SYSDATE
                          FROM po_interface_errors pie, rcv_transactions_interface rti
                         WHERE     1 = 1
                               --AND pie.interface_header_id = rti.header_interface_id --Commented for change 5.1
                               AND pie.interface_header_id(+) =
                                   rti.header_interface_id --Added for change 5.1(Added outer join on pie)
                               AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                               AND rti.shipment_header_id =
                                   dtl.shipment_header_id
                               AND rti.shipment_line_id =
                                   dtl.shipment_line_id
                               AND dtl.GROUP_ID = rti.GROUP_ID
                               AND ROWNUM < 2)
             WHERE     dtl.process_status = 'INPROCESS'
                   AND dtl.shipment_number IS NOT NULL
                   AND dtl.rcpt_type = 'ADJUST'
                   AND dtl.request_id = g_num_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM po_interface_errors pie, rcv_transactions_interface rti
                             WHERE     1 = 1
                                   --AND pie.interface_header_id = rti.header_interface_id --Commented for change 5.1
                                   AND pie.interface_header_id(+) =
                                       rti.header_interface_id --Added for change 5.1(Added outer join on pie)
                                   AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                   AND rti.shipment_header_id =
                                       dtl.shipment_header_id
                                   AND rti.shipment_line_id =
                                       dtl.shipment_line_id
                                   AND dtl.GROUP_ID = rti.GROUP_ID);

            fnd_file.put_line (
                fnd_file.LOG,
                   'Receipt Type: ASN RECEIPT Header ERROR Update Count in Main Procedure : '
                || SQL%ROWCOUNT);

            UPDATE xxdo_po_asn_receipt_ser_stg serial
               SET serial.process_status = 'ERROR', serial.last_updated_by = g_num_user_id, serial.last_update_date = SYSDATE
             WHERE     serial.process_status = 'INPROCESS'
                   AND serial.request_id = g_num_request_id
                   AND serial.receipt_dtl_seq_id IN
                           (SELECT dtl.receipt_dtl_seq_id
                              FROM xxdo_po_asn_receipt_dtl_stg dtl
                             WHERE     dtl.request_id = g_num_request_id
                                   AND dtl.rcpt_type = 'ADJUST'
                                   AND dtl.process_status = 'ERROR');

            /***********************************************************************/
            /*Infosys Ver 5.0: Add delete for both header and line level errors    */
            /***********************************************************************/

            DELETE FROM
                po_interface_errors pie
                  WHERE pie.interface_line_id IN
                            (SELECT rti.interface_transaction_id
                               FROM rcv_transactions_interface rti, xxdo_po_asn_receipt_dtl_stg dtl
                              WHERE     (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                    AND rti.shipment_header_id =
                                        dtl.shipment_header_id
                                    AND rti.shipment_line_id =
                                        dtl.shipment_line_id
                                    AND dtl.GROUP_ID = rti.GROUP_ID);

            DELETE FROM
                po_interface_errors pie
                  WHERE pie.interface_header_id IN
                            (SELECT rti.header_interface_id
                               FROM rcv_transactions_interface rti
                              WHERE     1 = 1
                                    AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                    AND rti.GROUP_ID IN
                                            (SELECT x.GROUP_ID
                                               FROM xxdo_po_asn_receipt_dtl_stg x
                                              WHERE     x.process_status =
                                                        'ERROR'
                                                    AND x.request_id =
                                                        g_num_request_id));

            DELETE FROM
                rcv_headers_interface rhi
                  WHERE rhi.header_interface_id IN
                            (SELECT rti.header_interface_id
                               FROM rcv_transactions_interface rti
                              WHERE     1 = 1
                                    AND (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                                    AND rti.GROUP_ID IN
                                            (SELECT x.GROUP_ID
                                               FROM xxdo_po_asn_receipt_dtl_stg x
                                              WHERE     x.process_status =
                                                        'ERROR'
                                                    AND x.request_id =
                                                        g_num_request_id));

            DELETE FROM
                rcv_transactions_interface rti
                  WHERE     (rti.processing_status_code = 'ERROR' OR rti.transaction_status_code = 'ERROR')
                        AND rti.GROUP_ID IN
                                (SELECT x.GROUP_ID
                                   FROM xxdo_po_asn_receipt_dtl_stg x
                                  WHERE     x.process_status = 'ERROR'
                                        AND x.request_id = g_num_request_id);


            fnd_file.put_line (
                fnd_file.LOG,
                   'ERROR Serial Update Count in Process Corrections Procedure: '
                || SQL%ROWCOUNT);

            -- Update the processed ASN lines records
            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET dtl.process_status = 'PROCESSED', dtl.last_updated_by = g_num_user_id, dtl.last_update_date = SYSDATE
             WHERE     dtl.process_status = 'INPROCESS'
                   AND dtl.rcpt_type = 'ADJUST'
                   AND dtl.request_id = g_num_request_id
                   AND EXISTS
                           (SELECT 1
                              FROM rcv_transactions rt1, PO.RCV_SHIPMENT_LINES rsl, PO.RCV_SHIPMENT_HEADERS rsh,
                                   mtl_system_items_b msi
                             WHERE     1 = 1
                                   AND rsl.SHIPMENT_HEADER_ID =
                                       rsh.SHIPMENT_HEADER_ID
                                   AND rt1.shipment_line_id =
                                       rsl.shipment_line_id
                                   AND rsl.ITEM_ID = msi.INVENTORY_ITEM_ID
                                   AND msi.organization_id = 106
                                   AND rt1.transaction_type =
                                       DECODE (dtl.rcpt_type,
                                               'RECEIPT', 'RECEIVE',
                                               'ADJUST', 'CORRECT') --add decode
                                   AND rt1.DESTINATION_TYPE_CODE =
                                       'RECEIVING'
                                   --and rsl.shipment_line_id=1692281
                                   AND rsh.SHIPMENT_NUM = dtl.shipment_number
                                   AND msi.segment1 = dtl.item_number
                                   AND rt1.attribute6 = dtl.carton_id
                                   AND rt1.quantity = dtl.qty);   --Add Exists

            fnd_file.put_line (
                fnd_file.LOG,
                   'Processed Detail Update Count in Process Corrections Procedure: '
                || SQL%ROWCOUNT);

            UPDATE xxdo_po_asn_receipt_ser_stg serial
               SET serial.process_status = 'PROCESSED', serial.last_updated_by = g_num_user_id, serial.last_update_date = SYSDATE
             WHERE     serial.process_status = 'INPROCESS'
                   AND serial.request_id = g_num_request_id
                   AND serial.receipt_dtl_seq_id IN
                           (SELECT dtl.receipt_dtl_seq_id
                              FROM xxdo_po_asn_receipt_dtl_stg dtl
                             WHERE     dtl.request_id = g_num_request_id
                                   AND dtl.rcpt_type = 'ADJUST'
                                   AND dtl.process_status = 'PROCESSED');

            fnd_file.put_line (
                fnd_file.LOG,
                   'PROCESSED Serial Update Count in Process Corrections Procedure: '
                || SQL%ROWCOUNT);

            --Added for change 5.1 - START
            --Mark the leftover ADJUSTMENT records which are stuck in INPROCESS to ERROR
            -- Update the ASN lines records that are still stuck in INPROCESS status to ERROR
            UPDATE xxdo_po_asn_receipt_dtl_stg dtl
               SET dtl.process_status = 'PROCESSED', dtl.last_updated_by = g_num_user_id, dtl.last_update_date = SYSDATE
             WHERE     1 = 1
                   AND dtl.process_status = 'INPROCESS'
                   AND dtl.rcpt_type = 'ADJUST'
                   AND dtl.request_id = g_num_request_id;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Receipt Type: ADJUST Detail - Marking INPROCESS to ERROR Update Count in PROCESS_CORRECTIONS Procedure : '
                || SQL%ROWCOUNT);
            --Added for change 5.1 - END
            /*
            -- Update the failed ASN receipt header records
            UPDATE xxdo_po_asn_receipt_head_stg head
            SET head.process_status = 'ERROR',
            head.last_updated_by = g_num_user_id,
            head.last_update_date = SYSDATE
            WHERE head.process_status = 'INPROCESS'
            AND head.request_id = g_num_request_id
            AND EXISTS (
            SELECT 1
            FROM xxdo_po_asn_receipt_dtl_stg dtl
            WHERE dtl.receipt_header_seq_id =
            head.receipt_header_seq_id
            AND dtl.request_id = g_num_request_id
            AND dtl.rcpt_type = 'ADJUST'
            AND dtl.process_status = 'ERROR');
            fnd_file.put_line(fnd_file.log, 'Error Header Update Count in Process Corrections Procedure: ' || SQL%ROWCOUNT);
            -- Update the processed records
            UPDATE xxdo_po_asn_receipt_head_stg head
            SET head.process_status = 'PROCESSED',
            head.last_updated_by = g_num_user_id,
            head.last_update_date = SYSDATE
            WHERE head.process_status = 'INPROCESS'
            AND head.request_id = g_num_request_id
            AND EXISTS (
            SELECT 1
            FROM xxdo_po_asn_receipt_dtl_stg dtl
            WHERE dtl.receipt_header_seq_id =
            head.receipt_header_seq_id
            AND dtl.request_id = g_num_request_id
            AND dtl.rcpt_type = 'ADJUST'
            AND dtl.process_status = 'PROCESSED')
            AND NOT EXISTS (
            SELECT 1
            FROM xxdo_po_asn_receipt_dtl_stg dtl
            WHERE dtl.receipt_header_seq_id =
            head.receipt_header_seq_id
            --AND dtl.request_id = g_num_request_id
            AND dtl.rcpt_type = 'RECEIPT'
            AND dtl.process_status IN ( 'NEW','INPROCESS'));
            fnd_file.put_line(fnd_file.log, 'Processed Header Update Count in Process Corrections Procedure: ' || SQL%ROWCOUNT);
            */
            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                       'Unexpected error while updating the process status : '
                    || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_update_failure;
        END;
    EXCEPTION
        WHEN l_exe_request_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_update_failure
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_lock_err
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at process_correctons procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END process_corrections;
END xxdo_po_asn_receipt_pkg;
/
