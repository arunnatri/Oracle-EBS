--
-- XXDO_PO_ASN_EXTRACT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:09 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_PO_ASN_EXTRACT_PKG"
AS
    /*
    **********************************************************************************************
    $Header: xxdo_po_asn_extract_pkg.sql 1.0 2014/08/06 10:00:00 Infosys $
    **********************************************************************************************
    */
    -- ***************************************************************************
    -- (c) Copyright Deckers Outdoor Corp.
    -- All rights reserved
    -- ***************************************************************************
    --
    -- Package Name : APPS.xxdo_po_asn_extract_pkg
    --
    -- Description : This is package  for EBS to WMS ASN Interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version    Description
    -- ------------  -----------------  -------    --------------------------------
    -- 06-Aug-14     Infosys            1.0        Created
    -- 05-Feb-15     Infosys            1.1        Defect - xxdo_po_asn_po_lines_log , addtion of warehouse_code column
    -- 11-Aug-15     Infosys            1.2        Defect - Adding  substr for all varchar2 field, Identified by SUBSTR
    -- 07-Oct-15     Infosys            1.3        Modified for Cross Dock - Identified by XDOCK
    -- 11-Aug-16     Infosys            1.4        Modified cursor cur_eligible_asns to pick all eligible ASN's
    -- 05-Dec-17     Infosys   1.5        Change in status as Open for partially received lines
    --                                             Identified by OPEN_PARTIALLY_RECEIVED
    -- 27-Jan-20     Showkath           1.6        Enhancement - CCR0008389
    -- ***************************************************************************

    -- ***************************************************************************
    -- Procedure/Function Name  :  Purge
    --
    -- Description              :  The purpose of this procedure is to purge the old ASN records
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
    -- 2014/08/11    Infosys            1.0   Initial Version
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
            INSERT INTO xxdo_po_asn_headers_log (warehouse_code,
                                                 shipment_number,
                                                 shipment_type,
                                                 bol_number,
                                                 factory_invoice_number,
                                                 vessel_name,
                                                 container,
                                                 container_alias,
                                                 shipment_mode,
                                                 load_date,
                                                 shipped_date,
                                                 estimated_arrival_date,
                                                 country_of_orgin,
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
                                                 organization_id,
                                                 shipment_id,
                                                 vendor_id,
                                                 asn_header_seq_id,
                                                 archive_date,
                                                 archive_request_id)
                SELECT warehouse_code, shipment_number, shipment_type,
                       bol_number, factory_invoice_number, vessel_name,
                       container, container_alias, shipment_mode,
                       load_date, shipped_date, estimated_arrival_date,
                       country_of_orgin, process_status, error_message,
                       request_id, creation_date, created_by,
                       last_update_date, last_updated_by, source_type,
                       attribute1, attribute2, attribute3,
                       attribute4, attribute5, attribute6,
                       attribute7, attribute8, attribute9,
                       attribute10, attribute11, attribute12,
                       attribute13, attribute14, attribute15,
                       attribute16, attribute17, attribute18,
                       attribute19, attribute20, SOURCE,
                       destination, record_type, shipment_header_id,
                       organization_id, shipment_id, vendor_id,
                       asn_header_seq_id, SYSDATE, g_num_request_id
                  FROM xxdo_po_asn_headers_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_po_asn_headers_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN Headers data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN Headers data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_po_asn_pos_log (warehouse_code,
                                             shipment_number,
                                             po_number,
                                             po_type,
                                             factory_code,
                                             factory_name,
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
                                             po_header_id,
                                             po_seq_id,
                                             asn_header_seq_id,
                                             archive_date,
                                             archive_request_id)
                SELECT warehouse_code, shipment_number, po_number,
                       po_type, factory_code, factory_name,
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
                       record_type, po_header_id, po_seq_id,
                       asn_header_seq_id, SYSDATE, g_num_request_id
                  FROM xxdo_po_asn_pos_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_po_asn_pos_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN - POs data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN - POs data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_po_asn_po_lines_log (warehouse_code, /*Defect Addition of warehouse_code*/
                                                                  shipment_number, po_number, carton_id, line_number, item_number, status, qty, ordered_uom, carton_weight, carton_length, carton_width, carton_height, inspection_type, carton_dim_uom, carton_weight_uom, carton_crossdock_ref, overage_allowance_type, overage_allowance_qty, overage_allowance_percent, process_status, error_message, request_id, creation_date, created_by, last_update_date, last_updated_by, source_type, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, SOURCE, destination, record_type, po_line_id, shipment_line_id, po_line_seq_id, po_seq_id, asn_header_seq_id, archive_date
                                                  , archive_request_id)
                SELECT warehouse_code,   /*Defect Addition of warehouse_code*/
                                       shipment_number, po_number,
                       carton_id, line_number, item_number,
                       status, qty, ordered_uom,
                       carton_weight, carton_length, carton_width,
                       carton_height, inspection_type, carton_dim_uom,
                       carton_weight_uom, carton_crossdock_ref, overage_allowance_type,
                       overage_allowance_qty, overage_allowance_percent, process_status,
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
                       po_line_id, shipment_line_id, po_line_seq_id,
                       po_seq_id, asn_header_seq_id, SYSDATE,
                       g_num_request_id
                  FROM xxdo_po_asn_po_lines_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_po_asn_po_lines_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN - PO  Lines data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN - PO Lines data: '
                    || SQLERRM);
        END;

        BEGIN
            INSERT INTO xxdo_po_asn_serials_log (warehouse_code,
                                                 shipment_number,
                                                 po_number,
                                                 carton_id,
                                                 line_number,
                                                 item_number,
                                                 serial_number,
                                                 serial_grade,
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
                                                 po_line_id,
                                                 shipment_line_id,
                                                 serial_seq_id,
                                                 po_line_seq_id,
                                                 po_seq_id,
                                                 asn_header_seq_id,
                                                 archive_date,
                                                 archive_request_id)
                SELECT warehouse_code, shipment_number, po_number,
                       carton_id, line_number, item_number,
                       serial_number, serial_grade, process_status,
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
                       po_line_id, shipment_line_id, serial_seq_id,
                       po_line_seq_id, po_seq_id, asn_header_seq_id,
                       SYSDATE, g_num_request_id
                  FROM xxdo_po_asn_serials_stg
                 WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;

            DELETE FROM xxdo_po_asn_serials_stg
                  WHERE creation_date < l_dte_sysdate - p_in_num_purge_days;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retcode   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving ASN - Serials data: '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving ASN - Serials data: '
                    || SQLERRM);
        END;

        COMMIT;
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

    --***********************************************************************************
    -- Procedure/Function Name  :  wait_for_request
    --
    -- Description              :  The purpose of this procedure is to make the
    --                             parent request to wait untill unless child
    --                             request completes
    --
    -- parameters               :  in_num_parent_req_id  in : Parent Request Id
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2009/08/03    Infosys            12.0.1    Initial Version
    -- ***************************************************************************
    PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
    AS
        ------------------------------
        --Local Variable Declaration--
        ------------------------------
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

        ------------------------------------------
        --Cursor to fetch the child request id's--
        ------------------------------------------
        CURSOR cur_child_req_id IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = in_num_parent_req_id;
    ---------------
    --Begin Block--
    ---------------
    BEGIN
        ------------------------------------------------------
        --Loop for each child request to wait for completion--
        ------------------------------------------------------
        FOR rec_child_req_id IN cur_child_req_id
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (rec_child_req_id.request_id,
                                                 ln_num_intvl,
                                                 ln_num_max_wait,
                                                 lv_chr_phase, -- out parameter
                                                 lv_chr_status, -- out parameter
                                                 lv_chr_dev_phase,
                                                 -- out parameter
                                                 lv_chr_dev_status,
                                                 -- out parameter
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

    /*
    ***********************************************************************************
     Procedure/Function Name  :  Copy Files
     Description              :  Copy files to out directory
    **********************************************************************************

    */
    PROCEDURE copy_files (in_num_request_id IN NUMBER, in_chr_entity IN VARCHAR2, in_chr_warehouse IN VARCHAR2
                          , retcode OUT VARCHAR2, errbuf OUT VARCHAR2)
    IS
        l_num_request_id      NUMBER;
        l_chr_transfer_flag   VARCHAR2 (1);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Start of copy files');

        SELECT attribute8
          INTO l_chr_transfer_flag
          FROM fnd_lookup_values
         WHERE     lookup_type LIKE 'XXDO_WMS_INTERFACES_SETUP'
               AND LANGUAGE = 'US'
               AND enabled_flag = 'Y'
               AND lookup_code =
                   DECODE (in_chr_entity,
                           'PO', 'XXDO_PO_EXT',
                           'PICK', 'XXDO_PICK_PROC',
                           'RMA', 'XXONT_RMA_PROC',
                           'ASN', 'XXDOASNE',
                           'REQRES', 'XXDO_REQ_RESP');

        IF l_chr_transfer_flag = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Copy flag is Yes');
            l_num_request_id   :=
                fnd_request.submit_request ('XXDO', 'XXDOCOPYFILES', NULL,
                                            NULL, FALSE, in_chr_warehouse,
                                            in_num_request_id, in_chr_entity);
            COMMIT;
            wait_for_request (g_num_request_id);
        ELSE
            fnd_file.put_line (fnd_file.LOG, 'Copy flag is No');
        END IF;

        fnd_file.put_line (fnd_file.LOG, 'End of copy files');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Unexpected error in copy files :' || SQLERRM);
            retcode   := '2';
            errbuf    := 'Erorr in file copy';
    END copy_files;


    -- ***************************************************************************
    -- Procedure/Function Name  :  lock_records
    --
    -- Description              :  The purpose of this procedure is to lock the records before XML generation
    --
    -- parameters               :  p_out_chr_errbuf  out : Error message
    --                                   p_out_chr_retcode  out : Execution status
    --                                  p_in_chr_shipment_no  IN : ASN Number
    --
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/11    Infosys            1.0   Initial Version
    -- ***************************************************************************
    PROCEDURE lock_records (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_chr_shipment_no IN VARCHAR2)
    IS
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        UPDATE xxdo_po_asn_headers_stg
           SET process_status = 'INPROCESS', last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_pos_stg
           SET process_status = 'INPROCESS', last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_po_lines_stg
           SET process_status = 'INPROCESS', last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_serials_stg
           SET process_status = 'INPROCESS', last_updated_by = g_num_user_id, last_update_date = SYSDATE
         WHERE     process_status = 'NEW'
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND request_id = g_num_request_id;
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
    PROCEDURE update_error_records (
        p_out_chr_errbuf            OUT VARCHAR2,
        p_out_chr_retcode           OUT VARCHAR2,
        p_in_chr_shipment_no     IN     VARCHAR2,
        p_in_chr_error_message   IN     VARCHAR2,
        p_in_chr_from_status     IN     VARCHAR2,
        p_in_chr_to_status       IN     VARCHAR2,
        p_in_chr_warehouse       IN     VARCHAR2 DEFAULT NULL)
    IS
        l_num_errored_locked_count   NUMBER := 0;
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';

        UPDATE xxdo_po_asn_headers_stg
           SET process_status = p_in_chr_to_status, error_message = p_in_chr_error_message, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND warehouse_code = NVL (p_in_chr_warehouse, warehouse_code)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_pos_stg
           SET process_status = p_in_chr_to_status, error_message = p_in_chr_error_message, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND warehouse_code = NVL (p_in_chr_warehouse, warehouse_code)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_po_lines_stg
           SET process_status = p_in_chr_to_status, error_message = p_in_chr_error_message, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND warehouse_code = NVL (p_in_chr_warehouse, warehouse_code)
               AND request_id = g_num_request_id;

        UPDATE xxdo_po_asn_serials_stg
           SET process_status = p_in_chr_to_status, error_message = p_in_chr_error_message, last_updated_by = g_num_user_id,
               last_update_date = SYSDATE
         WHERE     process_status = p_in_chr_from_status
               AND shipment_number =
                   NVL (p_in_chr_shipment_no, shipment_number)
               AND warehouse_code = NVL (p_in_chr_warehouse, warehouse_code)
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
    -- Procedure/Function Name  :  get_next_suffix
    --
    -- Description              :  The purpose of this procedure is to derive the next suffix of the shipment number
    --                                     in case of partially shipped ASN. This also updates the old interfaced records to OBSOLETE
    --
    -- parameters               :   p_in_chr_shipment_no  IN : ASN Number
    --
    -- Return/Exit              :  Next suffix number
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/11    Infosys            1.0   Initial Version
    -- ***************************************************************************
    FUNCTION get_next_suffix (p_in_chr_shipment_number IN VARCHAR2)
        RETURN NUMBER
    IS
        l_num_curr_suffix   NUMBER := 0;
        l_chr_errbuf        VARCHAR2 (2000);
        l_chr_retcode       VARCHAR2 (30);
    BEGIN
        BEGIN
            SELECT TO_NUMBER (REGEXP_SUBSTR (shipment_number, '[^.]+', 1,
                                             1))
              INTO l_num_curr_suffix
              FROM xxdo_po_asn_headers_stg
             WHERE     shipment_number LIKE p_in_chr_shipment_number || '.%'
                   AND process_status = 'PROCESSED';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_num_curr_suffix   := 0;
            WHEN OTHERS
            THEN
                l_num_curr_suffix   := 0;
        END;

        IF l_num_curr_suffix > 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Updating the processed records');

            BEGIN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     =>
                        p_in_chr_shipment_number || '.' || l_num_curr_suffix,
                    p_in_chr_error_message   => NULL,
                    p_in_chr_from_status     => 'PROCESSED',
                    p_in_chr_to_status       => 'OBSOLETE');
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected Error while updating old records status to OBSOLETE :'
                        || l_chr_errbuf);
            END;

            IF l_chr_retcode <> '0'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error while marking the old records as OBSOLETE :'
                    || l_chr_errbuf);
            ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Old records are marked as OBSOLETE');
            END IF;
        END IF;

        RETURN l_num_curr_suffix + 1;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error at Get next prefix procedure : ' || SQLERRM);
            RETURN -1;
    END get_next_suffix;

    -- ***************************************************************************
    -- Procedure/Function Name  :  get_shipment_container
    --
    -- Description              :  The purpose of this procedure is to derive the container number
    --
    -- parameters               :  p_in_chr_shipment_type IN : Shipment type - PO or Internal order
    --                                 p_in_num_organization_id   IN : Ship to org id
    --                                 p_in_num_grouping_id       IN : Grouping  ID
    --
    -- Return/Exit              :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/11    Infosys            1.0   Initial Version
    -- ***************************************************************************
    FUNCTION get_shipment_container (p_in_num_organization_id   IN NUMBER,
                                     p_in_num_grouping_id       IN NUMBER)
        RETURN VARCHAR2
    IS
        l_chr_container_ref   custom.do_containers.container_ref%TYPE;
    BEGIN
        l_chr_container_ref   := NULL;

        SELECT DISTINCT dc.container_ref
          INTO l_chr_container_ref
          FROM custom.do_items di, custom.do_containers dc, apps.oe_order_lines_all oola,
               apps.po_line_locations_all plla, apps.wsh_delivery_assignments wda, apps.wsh_delivery_details wdd,
               apps.rcv_shipment_headers rsh
         WHERE     dc.container_id = di.container_id
               AND di.order_line_id = plla.po_line_id
               AND di.line_location_id = plla.line_location_id
               AND plla.line_location_id = TO_NUMBER (oola.attribute16)
               AND oola.line_id = wdd.source_line_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.source_code = 'OE'
               AND wda.delivery_id = TO_NUMBER (rsh.shipment_num)
               AND rsh.receipt_source_code = 'INTERNAL ORDER'
               AND TO_NUMBER (rsh.attribute2) = p_in_num_grouping_id
               AND rsh.ship_to_org_id = p_in_num_organization_id;

        RETURN l_chr_container_ref;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            RETURN NULL;
        WHEN TOO_MANY_ROWS
        THEN
            RETURN 'Multiple';
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Unexpected error at get shipment container procedure : '
                || SQLERRM);
            RETURN NULL;
    END get_shipment_container;

    -- ***************************************************************************
    -- Procedure/Function Name  :  main
    --
    -- Description              :  This is the main procedure which extracts the ASN details and generates the XML
    --
    -- parameters               :  p_out_chr_errbuf     OUT : Error message
    --                                    p_out_chr_retcode    OUT : Execution status
    --                                    p_in_chr_warehouse    IN : Warehouse code
    --                                    p_in_chr_shipment_no  IN : ASN Number
    --                                    p_in_chr_source       IN : Source - EBS
    --                                    p_in_chr_dest         IN : Destination - WMS
    --                                    p_in_num_purge_days   IN : Purge days
    --                                    p_in_num_bulk_limit   IN : Bulk limit for fetch
    --
    -- Return/Exit              :  N/A
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/08/11    Infosys            1.0      Initial Version
    -- 2014/12/30    Infosys            2.0      Modified for BT Remediation
    -- 2015/02/19    Infosys            3.0      Added logic to derive crossdock reference
    -- ***************************************************************************
    PROCEDURE main (p_out_chr_errbuf          OUT VARCHAR2,
                    p_out_chr_retcode         OUT VARCHAR2,
                    p_in_chr_warehouse     IN     VARCHAR2,
                    p_in_chr_shipment_no   IN     VARCHAR2,
                    p_in_chr_source        IN     VARCHAR2,
                    p_in_chr_dest          IN     VARCHAR2,
                    p_in_num_purge_days    IN     NUMBER,
                    p_in_num_bulk_limit    IN     NUMBER)
    IS
        l_chr_errbuf                 VARCHAR2 (4000);
        l_chr_retcode                VARCHAR2 (30);
        l_num_error_count            NUMBER;
        l_chr_warehouse              VARCHAR2 (30);
        l_chr_shipment_number        VARCHAR2 (60);
        l_chr_weight_primary_uom     VARCHAR2 (30);
        l_chr_length_primary_uom     VARCHAR2 (30);
        l_dte_last_run_time          DATE;
        l_dte_next_run_time          DATE;
        l_num_next_suffix            NUMBER;
        l_chr_orig_shipment_number   VARCHAR2 (60);
        l_num_request_id             NUMBER;
        l_bol_req_status             BOOLEAN;
        l_chr_phase                  VARCHAR2 (100) := NULL;
        l_chr_status                 VARCHAR2 (100) := NULL;
        l_chr_dev_phase              VARCHAR2 (100) := NULL;
        l_chr_dev_status             VARCHAR2 (100) := NULL;
        l_chr_message                VARCHAR2 (1000) := NULL;
        l_chr_asn_headers_selected   VARCHAR2 (1) := 'N';
        l_num_inv_org_id             NUMBER;
        l_num_prev_asn_header_id     NUMBER := -1;
        l_chr_prev_shipment_num      VARCHAR2 (60) := '-1';
        l_chr_prev_po_number         VARCHAR2 (60) := '-1';
        l_num_asn_header_seq_id      NUMBER;
        l_num_asn_po_seq_id          NUMBER;
        l_num_asn_po_line_seq_id     NUMBER;
        l_chr_commit                 VARCHAR2 (1) := 'N';
        l_num_inv_assign_ind         NUMBER;
        l_exe_xml_req_not_launched   EXCEPTION;
        l_exe_xml_req_error          EXCEPTION;
        l_exe_next_run_not_updated   EXCEPTION;
        l_exe_unable_to_lock         EXCEPTION;
        l_exe_processed_not_marked   EXCEPTION;
        l_exe_not_wms_warehouse      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_bulk_insert_failed     EXCEPTION;
        l_exe_dml_errors             EXCEPTION;
        PRAGMA EXCEPTION_INIT (l_exe_dml_errors, -24381);
        l_interface_setup_rec        fnd_lookup_values%ROWTYPE;
        l_inv_org_attr_tab           g_inv_org_attr_tab_type;
        l_asn_headers_tab            g_asn_headers_tab_type;
        l_asn_pos_tab                g_asn_pos_tab_type;
        l_asn_po_lines_tab           g_asn_po_lines_tab_type;

        CURSOR cur_asn_headers (p_num_shipment_header_id    IN NUMBER,
                                p_chr_receipt_source_code   IN VARCHAR2)
        IS
            SELECT DISTINCT l_chr_warehouse warehouse_code, rsh.shipment_num shipment_number, rsh.receipt_source_code shipment_type,
                            NVL (ship.bill_of_lading, rsh.waybill_airbill_num) bol_number, NVL (ship.invoice_num, rsh.packing_slip) factory_invoice_number, ship.vessel_name vessel_name,
                            cont.container_ref container, cont.container_num container_alias, ship.shipment_type shipment_mode,
                            NVL (ship.creation_date, rsh.creation_date) load_date, NVL (ship.etd, rsh.shipped_date) shipped_date, NVL (ship.eta, rsh.expected_receipt_date) estimated_arrival_date,
                            ship.discharge_port country_of_origin, 'NEW' process_status, NULL error_message,
                            g_num_request_id request_id, SYSDATE creation_date, g_num_user_id created_by,
                            SYSDATE last_update_date, g_num_user_id last_updated_by, NULL source_type,
                            NULL attribute1, NULL attribute2, NULL attribute3,
                            NULL attribute4, NULL attribute5, NULL attribute6,
                            NULL attribute7, NULL attribute8, NULL attribute9,
                            NULL attribute10, NULL attribute11, NULL attribute12,
                            NULL attribute13, NULL attribute14, NULL attribute15,
                            NULL attribute16, NULL attribute17, NULL attribute18,
                            NULL attribute19, NULL attribute20, 'EBS' SOURCE,
                            'WMS' destination, 'INSERT' record_type, rsh.shipment_header_id,
                            l_num_inv_org_id, ship.shipment_id, rsh.vendor_id,
                            NULL asn_header_seq_id
              FROM rcv_shipment_headers rsh, do_shipments ship, do_containers cont,
                   do_items item
             WHERE     p_chr_receipt_source_code = 'VENDOR'
                   AND ship.shipment_id(+) = cont.shipment_id
                   AND cont.container_id(+) = item.container_id
                   AND item.atr_number(+) = rsh.shipment_num
                   AND rsh.shipment_header_id = p_num_shipment_header_id
            UNION ALL
            SELECT l_chr_warehouse warehouse_code, rsh.shipment_num shipment_number, rsh.receipt_source_code shipment_type,
                   rsh.waybill_airbill_num bol_number, rsh.packing_slip factory_invoice_number, NULL vessel_name,
                   get_shipment_container (rsh.ship_to_org_id, TO_NUMBER (rsh.attribute2)) container, NULL container_alias, NULL shipment_mode,
                   rsh.creation_date load_date, rsh.shipped_date shipped_date, rsh.expected_receipt_date estimated_arrival_date,
                   NULL country_of_origin, 'NEW' process_status, NULL error_message,
                   g_num_request_id request_id, SYSDATE creation_date, g_num_user_id created_by,
                   SYSDATE last_update_date, g_num_user_id last_updated_by, NULL source_type,
                   NULL attribute1, NULL attribute2, NULL attribute3,
                   NULL attribute4, NULL attribute5, NULL attribute6,
                   NULL attribute7, NULL attribute8, NULL attribute9,
                   NULL attribute10, NULL attribute11, NULL attribute12,
                   NULL attribute13, NULL attribute14, NULL attribute15,
                   NULL attribute16, NULL attribute17, NULL attribute18,
                   NULL attribute19, NULL attribute20, 'EBS' SOURCE,
                   'WMS' destination, 'INSERT' record_type, rsh.shipment_header_id,
                   l_num_inv_org_id, NULL shipment_id, rsh.vendor_id,
                   NULL asn_header_seq_id
              FROM rcv_shipment_headers rsh
             WHERE     p_chr_receipt_source_code = 'INTERNAL ORDER'
                   AND rsh.shipment_header_id = p_num_shipment_header_id;

        CURSOR cur_asn_pos (p_chr_shipment_number IN VARCHAR2, p_num_asn_header_id IN NUMBER, p_chr_receipt_source_code IN VARCHAR2)
        IS
            SELECT DISTINCT l_chr_warehouse warehouse_code, l_chr_shipment_number shipment_number, poha.segment1 po_number,
                            rsl.source_document_code po_type, pvsa.vendor_site_code factory_code, pvsa.vendor_site_code_alt facory_name,
                            'NEW' process_status, NULL error_message, g_num_request_id request_id,
                            SYSDATE creation_date, g_num_user_id created_by, SYSDATE last_update_date,
                            g_num_user_id last_updated_by, NULL source_type, NULL attribute1,
                            NULL attribute2, NULL attribute3, NULL attribute4,
                            NULL attribute5, NULL attribute6, NULL attribute7,
                            NULL attribute8, NULL attribute9, NULL attribute10,
                            NULL attribute11, NULL attribute12, NULL attribute13,
                            NULL attribute14, NULL attribute15, NULL attribute16,
                            NULL attribute17, NULL attribute18, NULL attribute19,
                            NULL attribute20, 'EBS' SOURCE, 'WMS' destination,
                            'INSERT' record_type, poha.po_header_id, NULL po_seq_id,
                            NULL asn_header_seq_id
              FROM po_vendor_sites_all pvsa, po_headers_all poha, rcv_shipment_lines rsl
             WHERE     rsl.shipment_header_id = p_num_asn_header_id
                   AND rsl.po_header_id = poha.po_header_id
                   AND poha.vendor_site_id = pvsa.vendor_site_id
                   AND p_chr_receipt_source_code = 'VENDOR'
            UNION ALL
            SELECT DISTINCT l_chr_warehouse warehouse_code, l_chr_shipment_number shipment_number, prh.segment1 po_number,
                            rsl.source_document_code po_type, mp.organization_code factory_code, hou.NAME facory_name,
                            'NEW' process_status, NULL error_message, g_num_request_id request_id,
                            SYSDATE creation_date, g_num_user_id created_by, SYSDATE last_update_date,
                            g_num_user_id last_updated_by, NULL source_type, NULL attribute1,
                            NULL attribute2, NULL attribute3, NULL attribute4,
                            NULL attribute5, NULL attribute6, NULL attribute7,
                            NULL attribute8, NULL attribute9, NULL attribute10,
                            NULL attribute11, NULL attribute12, NULL attribute13,
                            NULL attribute14, NULL attribute15, NULL attribute16,
                            NULL attribute17, NULL attribute18, NULL attribute19,
                            NULL attribute20, 'EBS' SOURCE, 'WMS' destination,
                            'INSERT' record_type, prh.requisition_header_id po_header_id, NULL po_seq_id,
                            NULL asn_header_seq_id
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, po_requisition_headers_all prh,
                   po_requisition_lines_all prl, oe_order_headers_all ooh, oe_order_lines_all ool,
                   oe_order_sources oos, hr_all_organization_units hou, mtl_parameters mp
             WHERE     1 = 1
                   AND rsh.shipment_num = l_chr_orig_shipment_number
                   AND rsh.receipt_source_code = 'INTERNAL ORDER'
                   AND rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsl.requisition_line_id = prl.requisition_line_id
                   AND prl.requisition_header_id = prh.requisition_header_id
                   AND oos.NAME = 'Internal'
                   AND oos.order_source_id = ooh.order_source_id
                   AND prh.segment1 = ooh.orig_sys_document_ref
                   AND ooh.header_id = ool.header_id
                   AND ool.source_document_line_id = prl.requisition_line_id
                   AND hou.organization_id = ool.org_id
                   AND mp.organization_id = ool.ship_from_org_id
                   AND p_chr_receipt_source_code = 'INTERNAL ORDER';

        CURSOR cur_asn_po_lines (p_num_asn_header_id         IN NUMBER,
                                 p_chr_partial_asn           IN VARCHAR2,
                                 p_chr_lpn_receiving         IN VARCHAR2,
                                 p_chr_receipt_source_code   IN VARCHAR2,
                                 p_chr_po_number             IN VARCHAR2)
        IS
              /*
              Vendor ASN Case1:
               Fetcth ASN data directly from EBS tables if :
                  a: ASN data does not exist in custom tables (or)
                  b. There is no need to check custom tables because warehouse LPN flag is 'No' (i.e., 2 or blank)
               */
              SELECT *
                FROM (SELECT l_chr_warehouse
                                 warehouse_code,
                             l_chr_shipment_number
                                 shipment_number,
                             p_chr_po_number
                                 po_number,
                             NULL
                                 carton_id,
                             rsl.line_num
                                 line_num,
                             /*   msi.segment1
                               || '-'
                               || msi.segment2
                               || '-'
                               || msi.segment3 item_num, */
                             msi.concatenated_segments
                                 item_number,      -- Added for BT Remediation
                             rsl.shipment_line_status_code
                                 status,
                             rsl.quantity_shipped
                                 qty,
                             (SELECT muom.uom_code
                                FROM mtl_units_of_measure muom
                               WHERE muom.unit_of_measure = rsl.unit_of_measure)
                                 ordered_uom,
                             NULL
                                 carton_weight,
                             NULL
                                 carton_length,
                             NULL
                                 carton_width,
                             NULL
                                 carton_height,
                             (SELECT rrh.routing_name
                                FROM rcv_routing_headers rrh
                               WHERE rrh.routing_header_id =
                                     rsl.routing_header_id)
                                 inspection_type,
                             NULL
                                 carton_dim_uom,
                             NULL
                                 carton_weight_uom,
                             /*Modifying the crossdock ref derivation BEGIN*/
                             --pola.project_id carton_crossdock_ref,
                             --plla.ATTRIBUTE9 carton_crossdock_ref, -- commented for XDOCK
                             DECODE (plla.attribute15,
                                     NULL, NULL,
                                     plla.line_location_id)
                                 carton_crossdock_ref,      -- Added for XDOCK
                             /*Modifying the crossdock ref derivation END*/
                             'PERCENT'
                                 overage_allowance_type,
                             NULL
                                 overage_allowance_qty,
                             pola.qty_rcv_tolerance
                                 overage_allowance_percent,
                             'NEW'
                                 process_status,
                             NULL
                                 error_message,
                             g_num_request_id
                                 request_id,
                             SYSDATE
                                 creation_date,
                             g_num_user_id
                                 created_by,
                             SYSDATE
                                 last_update_date,
                             g_num_user_id
                                 last_updated_by,
                             NULL
                                 source_type,
                             NULL
                                 attribute1,
                             NULL
                                 attribute2,
                             NULL
                                 attribute3,
                             NULL
                                 attribute4,
                             NULL
                                 attribute5,
                             NULL
                                 attribute6,
                             NULL
                                 attribute7,
                             NULL
                                 attribute8,
                             NULL
                                 attribute9,
                             NULL
                                 attribute10,
                             NULL
                                 attribute11,
                             NULL
                                 attribute12,
                             NULL
                                 attribute13,
                             NULL
                                 attribute14,
                             NULL
                                 attribute15,
                             NULL
                                 attribute16,
                             NULL
                                 attribute17,
                             NULL
                                 attribute18,
                             NULL
                                 attribute19,
                             NULL
                                 attribute20,
                             'EBS'
                                 SOURCE,
                             'WMS'
                                 destination,
                             'INSERT'
                                 record_type,
                             pola.po_line_id,
                             NULL
                                 shipment_line_id,
                             NULL
                                 po_line_seq_id,
                             NULL
                                 po_seq_id,
                             NULL
                                 asn_header_seq_id,
                             msi.inventory_item_id,
                             msi.organization_id
                        FROM rcv_shipment_lines rsl, po_lines_all pola, po_headers_all poha,
                             po_line_locations_all plla, mtl_system_items_kfv msi -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation\
                       WHERE     poha.segment1 = p_chr_po_number
                             AND poha.po_header_id = pola.po_header_id
                             AND poha.po_header_id = rsl.po_header_id
                             AND plla.po_header_id = poha.po_header_id --Added for crossdock reference
                             AND plla.po_line_id = pola.po_line_id --Added for crossdock reference
                             AND rsl.shipment_header_id = p_num_asn_header_id
                             AND rsl.po_line_id = pola.po_line_id
                             AND msi.inventory_item_id = rsl.item_id
                             AND msi.organization_id = rsl.to_organization_id
                             AND (   NOT EXISTS
                                         (SELECT 1
                                            FROM custom.do_items di
                                           WHERE di.atr_number =
                                                 l_chr_shipment_number)
                                  OR p_chr_lpn_receiving = '2')
                             AND p_chr_receipt_source_code = 'VENDOR'
                      UNION ALL
                      /*
                      Vendor ASN Case2:
                       Fetcth ASN data from EBS + custom tables if :
                          a: warehouse LPN flag is ''Yes' (i.e., value = 1) AND
                          b. ASN data exists in custom tables
                       */
                      SELECT l_chr_warehouse
                                 warehouse_code,
                             l_chr_shipment_number
                                 shipment_number,
                             p_chr_po_number
                                 po_number,
                             carton.carton_number
                                 carton_id,
                             rsl.line_num
                                 line_num,
                             /*   msi.segment1
                               || '-'
                               || msi.segment2
                               || '-'
                               || msi.segment3 item_num, */
                             msi.concatenated_segments
                                 item_number,      -- Added for BT Remediation
                             rsl.shipment_line_status_code
                                 status,
                             NVL (carton.quantity, rsl.quantity_shipped)
                                 qty,
                             (SELECT muom.uom_code
                                FROM mtl_units_of_measure muom
                               WHERE muom.unit_of_measure = rsl.unit_of_measure)
                                 ordered_uom,
                             TO_CHAR (carton.weight)
                                 carton_weight,
                             TO_CHAR (carton.ctn_length)
                                 carton_length,
                             TO_CHAR (carton.ctn_width)
                                 carton_width,
                             TO_CHAR (carton.ctn_height)
                                 carton_height,
                             (SELECT rrh.routing_name
                                FROM rcv_routing_headers rrh
                               WHERE rrh.routing_header_id =
                                     rsl.routing_header_id)
                                 inspection_type,
                             l_chr_length_primary_uom
                                 carton_dim_uom,
                             l_chr_weight_primary_uom
                                 carton_weight_uom,
                             /*Modifying the crossdock ref derivation BEGIN*/
                             --pola.project_id carton_crossdock_ref,
                             --plla.ATTRIBUTE9 carton_crossdock_ref, -- Commented for XDOCK
                             DECODE (plla.attribute15,
                                     NULL, NULL,
                                     plla.line_location_id)
                                 carton_crossdock_ref,      -- Added for XDOCK
                             /*Modifying the crossdock ref derivation END*/
                             'PERCENT'
                                 overage_allowance_type,
                             NULL
                                 overage_allowance_qty,
                             pola.qty_rcv_tolerance
                                 overage_allowance_percent,
                             'NEW'
                                 process_status,
                             NULL
                                 error_message,
                             g_num_request_id
                                 request_id,
                             SYSDATE
                                 creation_date,
                             g_num_user_id
                                 created_by,
                             SYSDATE
                                 last_update_date,
                             g_num_user_id
                                 last_updated_by,
                             NULL
                                 source_type,
                             NULL
                                 attribute1,
                             NULL
                                 attribute2,
                             NULL
                                 attribute3,
                             NULL
                                 attribute4,
                             NULL
                                 attribute5,
                             NULL
                                 attribute6,
                             NULL
                                 attribute7,
                             NULL
                                 attribute8,
                             NULL
                                 attribute9,
                             NULL
                                 attribute10,
                             NULL
                                 attribute11,
                             NULL
                                 attribute12,
                             NULL
                                 attribute13,
                             NULL
                                 attribute14,
                             NULL
                                 attribute15,
                             NULL
                                 attribute16,
                             NULL
                                 attribute17,
                             NULL
                                 attribute18,
                             NULL
                                 attribute19,
                             NULL
                                 attribute20,
                             'EBS'
                                 SOURCE,
                             'WMS'
                                 destination,
                             'INSERT'
                                 record_type,
                             pola.po_line_id,
                             NULL
                                 shipment_line_id,
                             NULL
                                 po_line_seq_id,
                             NULL
                                 po_seq_id,
                             NULL
                                 asn_header_seq_id,
                             msi.inventory_item_id,
                             msi.organization_id
                        FROM rcv_shipment_lines rsl, po_lines_all pola, po_headers_all poha,
                             po_line_locations_all plla, custom.do_cartons carton, do_items item,
                             mtl_system_items_kfv msi -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                       WHERE     poha.segment1 = p_chr_po_number
                             AND poha.po_header_id = pola.po_header_id
                             AND poha.po_header_id = rsl.po_header_id
                             AND plla.po_header_id = poha.po_header_id --Added for crossdock reference
                             AND plla.po_line_id = pola.po_line_id --Added for crossdock reference
                             AND rsl.shipment_header_id = p_num_asn_header_id
                             AND rsl.po_line_id = pola.po_line_id
                             AND rsl.po_line_location_id =
                                 item.line_location_id
                             AND item.atr_number = l_chr_orig_shipment_number
                             AND item.container_id = carton.container_id(+)
                             AND item.line_location_id =
                                 carton.line_location_id(+)
                             AND (rsl.bar_code_label IS NULL OR rsl.bar_code_label = carton.carton_number)
                             AND msi.inventory_item_id = rsl.item_id
                             AND msi.organization_id = rsl.to_organization_id
                             AND p_chr_receipt_source_code = 'VENDOR'
                             AND p_chr_lpn_receiving = '1'
                      UNION ALL
                      /*
                      INTERNAL CASE 1:
                      Internal Requistion is converted to Internal Sales Order and
                      Internal sales order does not have any Vendor PO reference.
                      */
                      SELECT l_chr_warehouse
                                 warehouse_code,
                             l_chr_shipment_number
                                 shipment_number,
                             prh.segment1
                                 po_number,
                             DECODE (p_chr_lpn_receiving,
                                     '2', NULL,
                                     wlp.license_plate_number)
                                 carton_id,
                             rsl.line_num
                                 line_num,
                             /*   msi.segment1
                               || '-'
                               || msi.segment2
                               || '-'
                               || msi.segment3 item_num, */
                             msi.concatenated_segments
                                 item_number,      -- Added for BT Remediation
                             rsl.shipment_line_status_code
                                 status,
                             rsl.quantity_shipped
                                 qty,
                             (SELECT muom.uom_code
                                FROM mtl_units_of_measure muom
                               WHERE muom.unit_of_measure = rsl.unit_of_measure)
                                 ordered_uom,
                             DECODE (p_chr_lpn_receiving,
                                     '2', NULL,
                                     wlp.gross_weight)
                                 carton_weight,
                             NULL
                                 carton_length,
                             NULL
                                 carton_width,
                             NULL
                                 carton_height,
                             (SELECT rrh.routing_name
                                FROM rcv_routing_headers rrh
                               WHERE rrh.routing_header_id =
                                     rsl.routing_header_id)
                                 inspection_type,
                             NULL
                                 carton_dim_uom,
                             DECODE (p_chr_lpn_receiving,
                                     '2', NULL,
                                     wlp.gross_weight_uom_code)
                                 carton_weight_uom,
                             NULL
                                 carton_crossdock_ref,
                             'PERCENT'
                                 overage_allowance_type,
                             NULL
                                 overage_allowance_qty,
                             NULL
                                 overage_allowance_percent,
                             'NEW'
                                 process_status,
                             NULL
                                 error_message,
                             g_num_request_id
                                 request_id,
                             SYSDATE
                                 creation_date,
                             g_num_user_id
                                 created_by,
                             SYSDATE
                                 last_update_date,
                             g_num_user_id
                                 last_updated_by,
                             NULL
                                 source_type,
                             NULL
                                 attribute1,
                             NULL
                                 attribute2,
                             NULL
                                 attribute3,
                             NULL
                                 attribute4,
                             NULL
                                 attribute5,
                             NULL
                                 attribute6,
                             NULL
                                 attribute7,
                             NULL
                                 attribute8,
                             NULL
                                 attribute9,
                             NULL
                                 attribute10,
                             NULL
                                 attribute11,
                             NULL
                                 attribute12,
                             NULL
                                 attribute13,
                             NULL
                                 attribute14,
                             NULL
                                 attribute15,
                             NULL
                                 attribute16,
                             NULL
                                 attribute17,
                             NULL
                                 attribute18,
                             NULL
                                 attribute19,
                             NULL
                                 attribute20,
                             'EBS'
                                 SOURCE,
                             'WMS'
                                 destination,
                             'INSERT'
                                 record_type,
                             prl.requisition_line_id,
                             NULL
                                 shipment_line_id,
                             NULL
                                 po_line_seq_id,
                             NULL
                                 po_seq_id,
                             NULL
                                 asn_header_seq_id,
                             msi.inventory_item_id,
                             msi.organization_id
                        FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, po_requisition_headers_all prh,
                             po_requisition_lines_all prl, oe_order_headers_all ooh, oe_order_lines_all ool,
                             oe_order_sources oos, mtl_system_items_kfv msi, -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                                                                             wms_license_plate_numbers wlp
                       WHERE     1 = 1
                             AND rsh.shipment_num = l_chr_orig_shipment_number
                             AND rsh.receipt_source_code = 'INTERNAL ORDER'
                             AND rsh.shipment_header_id =
                                 rsl.shipment_header_id
                             AND rsl.requisition_line_id =
                                 prl.requisition_line_id
                             AND prl.requisition_header_id =
                                 prh.requisition_header_id
                             AND prh.segment1 = p_chr_po_number
                             AND oos.NAME = 'Internal'
                             AND oos.order_source_id = ooh.order_source_id
                             AND prh.segment1 = ooh.orig_sys_document_ref
                             AND ooh.header_id = ool.header_id
                             AND ool.source_document_line_id =
                                 prl.requisition_line_id
                             AND (ool.attribute16 IS NULL OR p_chr_lpn_receiving = '2')
                             AND msi.inventory_item_id = rsl.item_id
                             AND msi.organization_id = rsl.to_organization_id
                             AND rsl.asn_lpn_id = wlp.lpn_id(+)
                             AND p_chr_receipt_source_code = 'INTERNAL ORDER'
                      UNION ALL
                      /*
                      INTERNAL CASE 2:
                          Internal Requistion is converted to Internal Sales Order and
                               Internal sales order has Vendor PO reference.

                      */
                      SELECT l_chr_warehouse
                                 warehouse_code,
                             l_chr_shipment_number
                                 shipment_number,
                             prh.segment1
                                 po_number,
                             dc.carton_number
                                 carton_id,
                             rsl.line_num
                                 line_num,
                             /*   msi.segment1
                               || '-'
                               || msi.segment2
                               || '-'
                               || msi.segment3 item_num, */
                             msi.concatenated_segments
                                 item_number,      -- Added for BT Remediation
                             rsl.shipment_line_status_code
                                 status,
                             NVL (dc.quantity, rsl.quantity_shipped)
                                 qty,
                             (SELECT muom.uom_code
                                FROM mtl_units_of_measure muom
                               WHERE muom.unit_of_measure = rsl.unit_of_measure)
                                 ordered_uom,
                             TO_CHAR (dc.weight)
                                 carton_weight,
                             TO_CHAR (dc.ctn_length)
                                 carton_length,
                             TO_CHAR (dc.ctn_width)
                                 carton_width,
                             TO_CHAR (dc.ctn_height)
                                 carton_height,
                             (SELECT rrh.routing_name
                                FROM rcv_routing_headers rrh
                               WHERE rrh.routing_header_id =
                                     rsl.routing_header_id)
                                 inspection_type,
                             l_chr_length_primary_uom
                                 carton_dim_uom,
                             l_chr_weight_primary_uom
                                 carton_weight_uom,
                             NULL
                                 carton_crossdock_ref,
                             'PERCENT'
                                 overage_allowance_type,
                             NULL
                                 overage_allowance_qty,
                             NULL
                                 overage_allowance_percent,
                             'NEW'
                                 process_status,
                             NULL
                                 error_message,
                             g_num_request_id
                                 request_id,
                             SYSDATE
                                 creation_date,
                             g_num_user_id
                                 created_by,
                             SYSDATE
                                 last_update_date,
                             g_num_user_id
                                 last_updated_by,
                             NULL
                                 source_type,
                             NULL
                                 attribute1,
                             NULL
                                 attribute2,
                             NULL
                                 attribute3,
                             NULL
                                 attribute4,
                             NULL
                                 attribute5,
                             NULL
                                 attribute6,
                             NULL
                                 attribute7,
                             NULL
                                 attribute8,
                             NULL
                                 attribute9,
                             NULL
                                 attribute10,
                             NULL
                                 attribute11,
                             NULL
                                 attribute12,
                             NULL
                                 attribute13,
                             NULL
                                 attribute14,
                             NULL
                                 attribute15,
                             NULL
                                 attribute16,
                             NULL
                                 attribute17,
                             NULL
                                 attribute18,
                             NULL
                                 attribute19,
                             NULL
                                 attribute20,
                             'EBS'
                                 SOURCE,
                             'WMS'
                                 destination,
                             'INSERT'
                                 record_type,
                             prl.requisition_line_id,
                             NULL
                                 shipment_line_id,
                             NULL
                                 po_line_seq_id,
                             NULL
                                 po_seq_id,
                             NULL
                                 asn_header_seq_id,
                             msi.inventory_item_id,
                             msi.organization_id
                        FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, po_requisition_headers_all prh,
                             po_requisition_lines_all prl, oe_order_headers_all ooh, oe_order_lines_all ool,
                             oe_order_sources oos, mtl_system_items_kfv msi, -- Replaced table mtl_system_items_b with mtl_system_items_kfv for BT Remediation
                                                                             do_items di,
                             rcv_shipment_headers parent_rsh, rcv_shipment_lines parent_rsl, custom.do_cartons dc
                       WHERE     1 = 1
                             --and rsh.shipment_num in (247894262, 610118,638695,638697)
                             AND rsh.shipment_num = l_chr_orig_shipment_number
                             AND rsh.receipt_source_code = 'INTERNAL ORDER'
                             AND rsh.shipment_header_id =
                                 rsl.shipment_header_id
                             AND rsl.requisition_line_id =
                                 prl.requisition_line_id
                             AND prl.requisition_header_id =
                                 prh.requisition_header_id
                             AND prh.segment1 = p_chr_po_number
                             AND oos.NAME = 'Internal'
                             AND oos.order_source_id = ooh.order_source_id
                             AND prh.segment1 = ooh.orig_sys_document_ref
                             AND ooh.header_id = ool.header_id
                             AND ool.source_document_line_id =
                                 prl.requisition_line_id
                             AND ool.attribute16 IS NOT NULL
                             AND msi.inventory_item_id = rsl.item_id
                             AND msi.organization_id = rsl.to_organization_id
                             AND p_chr_receipt_source_code = 'INTERNAL ORDER'
                             AND di.line_location_id = ool.attribute16
                             AND di.atr_number = parent_rsh.shipment_num
                             AND parent_rsh.shipment_header_id =
                                 parent_rsl.shipment_header_id
                             AND parent_rsl.po_line_location_id =
                                 di.line_location_id
                             AND di.container_id = dc.container_id(+)
                             AND di.line_location_id = dc.line_location_id(+)
                             AND (parent_rsl.bar_code_label IS NULL OR parent_rsl.bar_code_label = dc.carton_number)
                             AND p_chr_lpn_receiving = '1') x
            ORDER BY shipment_number, TO_NUMBER (line_num);

        CURSOR cur_inv_arg_attributes (p_chr_warehouse IN VARCHAR2)
        IS
            SELECT flv.lookup_code organization_code, mp.attribute11 manual_pre_adv_grouping, mp.attribute12 partial_asn,
                   mp.attribute15 lpn_receiving, mp.organization_id
              FROM fnd_lookup_values flv, mtl_parameters mp
             WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                   AND NVL (flv.LANGUAGE, USERENV ('LANG')) =
                       USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                   AND NVL (end_date_active, SYSDATE + 1)
                   AND mp.organization_code = flv.lookup_code
                   AND mp.organization_id =
                       NVL (p_chr_warehouse, mp.organization_id);

        CURSOR cur_eligible_asns (p_num_inv_org_id IN NUMBER, p_chr_shipment_no IN VARCHAR2, p_dte_last_run_time IN DATE
                                  , p_chr_pre_adv_grouping IN VARCHAR2)
        IS
            /* Begin Change - Infosys - Modified cursor cur_eligible_asns to pick all eligible ASN's*/
            /*SELECT DISTINCT rsh.shipment_num, rsh.shipment_header_id,
                            rsh.receipt_source_code
                       FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl
                      WHERE 1 = 1
                        AND rsh.shipment_header_id = rsl.shipment_header_id
                        AND rsh.ship_to_org_id = p_num_inv_org_id
                        AND rsh.shipment_num =
                                        NVL (p_chr_shipment_no, rsh.shipment_num)
                        AND (   p_chr_shipment_no IS NOT NULL
                             OR rsh.last_update_date >= p_dte_last_run_time
                             OR rsl.last_update_date >= p_dte_last_run_time
                            )
                        AND rsh.ship_to_org_id = p_num_inv_org_id
                        AND (   p_chr_pre_adv_grouping = '2'
                             OR (    p_chr_pre_adv_grouping = '1'
                                 AND rsh.attribute2 IS NOT NULL
                                )
                            )
                        AND rsl.shipment_line_status_code <> 'FULLY RECEIVED'
                        AND rsl.quantity_received = 0;*/
            SELECT DISTINCT rsh.shipment_num, rsh.shipment_header_id, rsh.receipt_source_code
              FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl
             WHERE     1 = 1
                   AND rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsh.ship_to_org_id = p_num_inv_org_id
                   AND rsh.shipment_num =
                       NVL (p_chr_shipment_no, rsh.shipment_num)
                   AND (   (p_chr_shipment_no IS NOT NULL OR rsh.last_update_date >= p_dte_last_run_time OR rsl.last_update_date >= p_dte_last_run_time)
                        OR     (NOT EXISTS
                                    (SELECT 'Y'
                                       FROM xxdo.xxdo_po_asn_headers_stg asn_stg
                                      WHERE rsh.shipment_num =
                                            asn_stg.shipment_number))
                           AND NOT EXISTS
                                   (SELECT 1
                                      FROM apps.xxdo_po_asn_po_lines_log po_line
                                     WHERE     1 = 1
                                           AND po_line.line_number =
                                               rsl.line_num
                                           AND po_line.shipment_number =
                                               rsh.shipment_num))
                   -- 1.6 changes start
                   AND NOT EXISTS
                           (SELECT 1
                              FROM rcv_transactions_interface rti, rcv_headers_interface rhi
                             WHERE     rti.header_interface_id =
                                       rhi.header_interface_id
                                   AND rhi.ship_to_organization_id =
                                       rsh.ship_to_org_id
                                   AND rhi.shipment_num = rsh.shipment_num) -- To restrict Partial Factory PO ASN's
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_transactions_interface mti
                             WHERE     mti.organization_id =
                                       rsh.organization_id
                                   AND mti.shipment_number = rsh.shipment_num) -- To restrict Partial DC To DC Orders
                   -- 1.6 changes end
                   AND (p_chr_pre_adv_grouping = '2' OR (p_chr_pre_adv_grouping = '1' AND rsh.attribute2 IS NOT NULL))
                   AND rsl.shipment_line_status_code <> 'FULLY RECEIVED'
                   AND rsl.quantity_received = 0;

        /* End Change - Infosys - Modified cursor cur_eligible_asns to pick all eligible ASN's*/


        CURSOR cur_org IS
            SELECT DISTINCT warehouse_code
              FROM xxdo_po_asn_headers_stg
             WHERE request_id = g_num_request_id;

        TYPE l_eligible_asns_tab_type IS TABLE OF cur_eligible_asns%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_chr_instance               VARCHAR2 (10);
        l_eligible_asns_tab          l_eligible_asns_tab_type;
    BEGIN
        p_out_chr_errbuf       := NULL;
        p_out_chr_retcode      := '0';
        fnd_file.put_line (fnd_file.LOG,
                           'Fetching the Inventory org level attributes');
        l_num_inv_assign_ind   := 1;

        FOR inv_arg_attributes_rec
            IN cur_inv_arg_attributes (p_in_chr_warehouse)
        LOOP
            l_inv_org_attr_tab (l_num_inv_assign_ind).manual_pre_adv_grouping   :=
                NVL (inv_arg_attributes_rec.manual_pre_adv_grouping, '2');
            l_inv_org_attr_tab (l_num_inv_assign_ind).partial_asn   :=
                NVL (inv_arg_attributes_rec.partial_asn, '1');
            l_inv_org_attr_tab (l_num_inv_assign_ind).lpn_receiving   :=
                NVL (inv_arg_attributes_rec.lpn_receiving, '2');
            l_inv_org_attr_tab (l_num_inv_assign_ind).organization_id   :=
                inv_arg_attributes_rec.organization_id;
            l_inv_org_attr_tab (l_num_inv_assign_ind).warehouse_code   :=
                inv_arg_attributes_rec.organization_code;
            l_num_inv_assign_ind   := l_num_inv_assign_ind + 1;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Fetching the last run time');

        -- Get the interface setup
        BEGIN
            l_dte_last_run_time   :=
                xxdo_ont_wms_intf_util_pkg.get_last_run_time (
                    p_in_chr_interface_prgm_name => NULL);

            IF l_dte_last_run_time IS NULL
            THEN
                l_dte_last_run_time   := SYSDATE - 90;
            END IF;

            fnd_file.put_line (
                fnd_file.LOG,
                   'Last run time : '
                || TO_CHAR (l_dte_last_run_time, 'DD-Mon-RRRR HH24:MI:SS'));
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                    'Unable to get the inteface setup due to ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                RAISE l_exe_no_interface_setup;
        END;

        BEGIN
            SELECT uom_code
              INTO l_chr_length_primary_uom
              FROM mtl_units_of_measure
             WHERE uom_class = 'Length' AND base_uom_flag = 'Y';

            SELECT uom_code
              INTO l_chr_weight_primary_uom
              FROM mtl_units_of_measure
             WHERE uom_class = 'Weight' AND base_uom_flag = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf    :=
                    'Unable to get the Primary UOMs due to ' || SQLERRM;
                p_out_chr_retcode   := '1';
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;

        --         l_dte_last_run_time  := TO_DATE (l_interface_setup_rec.attribute12, 'DD-Mon-RRRR HH24:MI:SS');
        l_dte_next_run_time    := SYSDATE;

        --- Extraction logic starts here
        --- Process for each warehouse
        FOR l_num_inv_ind IN l_inv_org_attr_tab.FIRST ..
                             l_inv_org_attr_tab.LAST
        LOOP
            fnd_file.put_line (
                fnd_file.LOG,
                   'Extraction started for the warehouse : '
                || l_inv_org_attr_tab (l_num_inv_ind).warehouse_code);
            l_chr_warehouse   :=
                l_inv_org_attr_tab (l_num_inv_ind).warehouse_code;
            l_num_inv_org_id   :=
                l_inv_org_attr_tab (l_num_inv_ind).organization_id;
            -- Fetch the eligible ASNs for the current warehouse
            fnd_file.put_line (
                fnd_file.LOG,
                   'Pre advise flag value : '
                || l_inv_org_attr_tab (l_num_inv_ind).manual_pre_adv_grouping);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Partial ASN flag value : '
                || l_inv_org_attr_tab (l_num_inv_ind).partial_asn);
            fnd_file.put_line (
                fnd_file.LOG,
                   'LPN Receiving flag value : '
                || l_inv_org_attr_tab (l_num_inv_ind).lpn_receiving);
            fnd_file.put_line (
                fnd_file.LOG,
                   'Fetching the eligible ASNs for the warehouse : '
                || l_inv_org_attr_tab (l_num_inv_ind).warehouse_code);

            OPEN cur_eligible_asns (
                l_inv_org_attr_tab (l_num_inv_ind).organization_id,
                p_in_chr_shipment_no,
                l_dte_last_run_time,
                l_inv_org_attr_tab (l_num_inv_ind).manual_pre_adv_grouping);

            LOOP
                IF l_eligible_asns_tab.EXISTS (1)
                THEN
                    l_eligible_asns_tab.DELETE;
                END IF;

                BEGIN
                    FETCH cur_eligible_asns
                        BULK COLLECT INTO l_eligible_asns_tab
                        LIMIT p_in_num_bulk_limit;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        p_out_chr_errbuf   :=
                               'Error in BULK Fetch of Eligible ASNs : '
                            || SQLERRM;
                        fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                        RAISE l_exe_bulk_fetch_failed;
                END;

                IF NOT l_eligible_asns_tab.EXISTS (1)
                THEN
                    EXIT;
                END IF;

                FOR l_num_eligible_asn_ind IN l_eligible_asns_tab.FIRST ..
                                              l_eligible_asns_tab.LAST
                LOOP
                    fnd_file.put_line (fnd_file.LOG,
                                       'Fetching the ASN headers');

                    --- Fetch all the eligible ASN Headers
                    OPEN cur_asn_headers (
                        l_eligible_asns_tab (l_num_eligible_asn_ind).shipment_header_id,
                        l_eligible_asns_tab (l_num_eligible_asn_ind).receipt_source_code);

                    LOOP
                        IF l_asn_headers_tab.EXISTS (1)
                        THEN
                            l_asn_headers_tab.DELETE;
                        END IF;

                        BEGIN
                            FETCH cur_asn_headers
                                BULK COLLECT INTO l_asn_headers_tab
                                LIMIT p_in_num_bulk_limit;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                p_out_chr_errbuf   :=
                                       'Error in BULK Fetch of ASN Headers : '
                                    || SQLERRM;
                                fnd_file.put_line (fnd_file.LOG,
                                                   p_out_chr_errbuf);
                                RAISE l_exe_bulk_fetch_failed;
                        END;

                        IF NOT l_asn_headers_tab.EXISTS (1)
                        THEN
                            EXIT;
                        END IF;

                        FOR l_num_asn_header_ind IN l_asn_headers_tab.FIRST ..
                                                    l_asn_headers_tab.LAST
                        LOOP
                            l_chr_prev_shipment_num   := 'xxx';
                            -- Logic to get the asn pos
                            l_chr_orig_shipment_number   :=
                                l_asn_headers_tab (l_num_asn_header_ind).shipment_number;
                            l_chr_shipment_number     :=
                                l_asn_headers_tab (l_num_asn_header_ind).shipment_number;
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Shipment header ID:'
                                || l_asn_headers_tab (l_num_asn_header_ind).shipment_header_id);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'shipment number:' || l_chr_shipment_number);
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'Shipment type:'
                                || l_asn_headers_tab (l_num_asn_header_ind).shipment_type);

                            /*
                            -- Temporary pseudo code to handle partial ASN logic. This can be helpful for future requirements
                            x_shipm = l_chr_shipment_number
                            if warehouse partial flag = '2' then
                               query staging table for max shipment number for current shipment ID
                               x_shipm = max ship number

                               if called from receving prcess then
                               increment x_shipm by 1
                               else if called directly from asn extract don't increment
                               end if
                            end if;

                            */
                            OPEN cur_asn_pos (
                                l_chr_shipment_number,
                                l_asn_headers_tab (l_num_asn_header_ind).shipment_header_id,
                                l_asn_headers_tab (l_num_asn_header_ind).shipment_type);

                            IF l_asn_pos_tab.EXISTS (1)
                            THEN
                                l_asn_pos_tab.DELETE;
                            END IF;

                            fnd_file.put_line (fnd_file.LOG,
                                               'Fetching the PO details');

                            BEGIN
                                FETCH cur_asn_pos
                                    BULK COLLECT INTO l_asn_pos_tab
                                    LIMIT p_in_num_bulk_limit;
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    p_out_chr_errbuf   :=
                                           'Error in BULK Fetch of PO details: '
                                        || SQLERRM;
                                    fnd_file.put_line (fnd_file.LOG,
                                                       p_out_chr_errbuf);
                                    RAISE l_exe_bulk_fetch_failed;
                            END;

                            -- Loop for POs
                            FOR l_num_po_ind IN l_asn_pos_tab.FIRST ..
                                                l_asn_pos_tab.LAST
                            LOOP
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Shipment header ID:'
                                    || l_asn_headers_tab (
                                           l_num_asn_header_ind).shipment_header_id);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'PO number:'
                                    || l_asn_pos_tab (l_num_po_ind).po_number);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Shipment type:'
                                    || l_asn_headers_tab (
                                           l_num_asn_header_ind).shipment_type);

                                OPEN cur_asn_po_lines (
                                    l_asn_headers_tab (l_num_asn_header_ind).shipment_header_id,
                                    l_inv_org_attr_tab (l_num_inv_ind).partial_asn,
                                    l_inv_org_attr_tab (l_num_inv_ind).lpn_receiving,
                                    l_asn_headers_tab (l_num_asn_header_ind).shipment_type,
                                    l_asn_pos_tab (l_num_po_ind).po_number);

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'Fetching the PO Lines for PO : '
                                    || l_asn_pos_tab (l_num_po_ind).po_number);

                                LOOP                          -- PO lines loop
                                    BEGIN
                                        FETCH cur_asn_po_lines
                                            BULK COLLECT INTO l_asn_po_lines_tab
                                            LIMIT p_in_num_bulk_limit;
                                    EXCEPTION
                                        WHEN OTHERS
                                        THEN
                                            p_out_chr_errbuf   :=
                                                   'Error in BULK Fetch of PO Lines /Cartons: '
                                                || SQLERRM;
                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                p_out_chr_errbuf);
                                            RAISE l_exe_bulk_fetch_failed;
                                    END;

                                    IF NOT l_asn_po_lines_tab.EXISTS (1)
                                    THEN
                                        EXIT;
                                    END IF;

                                    -- Insert all the records
                                    FOR l_num_po_line_ind IN l_asn_po_lines_tab.FIRST ..
                                                             l_asn_po_lines_tab.LAST
                                    LOOP
                                        fnd_file.put_line (
                                            fnd_file.LOG,
                                            'Inside the PO Lines');

                                        -- Insert the ASN header
                                        IF l_chr_prev_shipment_num <>
                                           l_asn_headers_tab (
                                               l_num_asn_header_ind).shipment_number
                                        THEN
                                            IF l_chr_commit = 'Y'
                                            THEN
                                                COMMIT;
                                                /*Commit previous ASN if that is already inserted */
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'commit records for warehouse, ASN number: '
                                                    || l_chr_warehouse
                                                    || '  '
                                                    || l_chr_prev_shipment_num);
                                            ELSIF l_chr_prev_shipment_num <>
                                                  '-1'
                                            THEN
                                                ROLLBACK;
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'rollback records for warehouse, ASN number: '
                                                    || l_chr_warehouse
                                                    || '  '
                                                    || l_chr_prev_shipment_num);
                                            END IF;

                                            l_chr_commit   := 'Y';

                                            BEGIN
                                                SELECT xxdo_po_asn_headers_stg_s.NEXTVAL
                                                  INTO l_num_asn_header_seq_id
                                                  FROM DUAL;

                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Inserting the ASN Header : '
                                                    || l_asn_headers_tab (
                                                           l_num_asn_header_ind).shipment_number);

                                                UPDATE xxdo_po_asn_headers_stg
                                                   SET process_status = 'OBSOLETE', last_updated_by = g_num_user_id, last_update_date = SYSDATE
                                                 WHERE     shipment_number =
                                                           l_asn_headers_tab (
                                                               l_num_asn_header_ind).shipment_number
                                                       AND process_status <>
                                                           'OBSOLETE';

                                                UPDATE xxdo_po_asn_pos_stg
                                                   SET process_status = 'OBSOLETE', last_updated_by = g_num_user_id, last_update_date = SYSDATE
                                                 WHERE     shipment_number =
                                                           l_asn_headers_tab (
                                                               l_num_asn_header_ind).shipment_number
                                                       AND process_status <>
                                                           'OBSOLETE';

                                                UPDATE xxdo_po_asn_po_lines_stg
                                                   SET process_status = 'OBSOLETE', last_updated_by = g_num_user_id, last_update_date = SYSDATE
                                                 WHERE     shipment_number =
                                                           l_asn_headers_tab (
                                                               l_num_asn_header_ind).shipment_number
                                                       AND process_status <>
                                                           'OBSOLETE';

                                                UPDATE xxdo_po_asn_serials_stg
                                                   SET process_status = 'OBSOLETE', last_updated_by = g_num_user_id, last_update_date = SYSDATE
                                                 WHERE     shipment_number =
                                                           l_asn_headers_tab (
                                                               l_num_asn_header_ind).shipment_number
                                                       AND process_status <>
                                                           'OBSOLETE';

                                                COMMIT;

                                                INSERT INTO xxdo_po_asn_headers_stg (
                                                                warehouse_code,
                                                                shipment_number,
                                                                shipment_type,
                                                                bol_number,
                                                                factory_invoice_number,
                                                                vessel_name,
                                                                container,
                                                                container_alias,
                                                                shipment_mode,
                                                                load_date,
                                                                shipped_date,
                                                                estimated_arrival_date,
                                                                country_of_orgin,
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
                                                                organization_id,
                                                                shipment_id,
                                                                vendor_id,
                                                                asn_header_seq_id)
                                                         /*SUBSTR*/
                                                         VALUES (
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).warehouse_code,
                                                                        1,
                                                                        10),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).shipment_number,
                                                                        1,
                                                                        30),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).shipment_type,
                                                                        1,
                                                                        30),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).bol_number,
                                                                        1,
                                                                        30),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).factory_invoice_number,
                                                                        1,
                                                                        30),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).vessel_name,
                                                                        1,
                                                                        100),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).container,
                                                                        1,
                                                                        30),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).container_alias,
                                                                        1,
                                                                        7),
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).shipment_mode,
                                                                        1,
                                                                        15),
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).load_date,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).shipped_date,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).estimated_arrival_date,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).country_of_orgin,
                                                                    SUBSTR (
                                                                        l_asn_headers_tab (
                                                                            l_num_asn_header_ind).process_status,
                                                                        1,
                                                                        10),
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).error_message,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).request_id,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).creation_date,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).created_by,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).last_update_date,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).last_updated_by,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).source_type,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute1,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute2,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute3,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute4,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute5,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute6,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute7,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute8,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute9,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute10,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute11,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute12,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute13,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute14,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute15,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute16,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute17,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute18,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute19,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).attribute20,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).SOURCE,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).destination,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).record_type,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).shipment_header_id,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).organization_id,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).shipment_id,
                                                                    l_asn_headers_tab (
                                                                        l_num_asn_header_ind).vendor_id,
                                                                    l_num_asn_header_seq_id); /*SUBSTR*/
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    p_out_chr_retcode   := 2;
                                                    p_out_chr_errbuf    :=
                                                           'Error occured for ASN Header insert '
                                                        || SQLERRM;
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                        p_out_chr_errbuf);
                                                    l_chr_commit        :=
                                                        'N';
                                            END;

                                            l_chr_prev_shipment_num   :=
                                                l_asn_headers_tab (
                                                    l_num_asn_header_ind).shipment_number;
                                            l_chr_prev_po_number   :=
                                                '-zzz';

                                            IF l_chr_prev_po_number <>
                                               l_asn_pos_tab (l_num_po_ind).po_number
                                            THEN
                                                BEGIN
                                                    SELECT xxdo_po_asn_pos_stg_s.NEXTVAL
                                                      INTO l_num_asn_po_seq_id
                                                      FROM DUAL;

                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                           'Inserting the PO  Number: '
                                                        || l_asn_pos_tab (
                                                               l_num_po_ind).po_number);

                                                    INSERT INTO xxdo_po_asn_pos_stg (
                                                                    warehouse_code,
                                                                    shipment_number,
                                                                    po_number,
                                                                    po_type,
                                                                    factory_code,
                                                                    factory_name,
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
                                                                    po_header_id,
                                                                    po_seq_id,
                                                                    asn_header_seq_id) /*SUBSTR*/
                                                             VALUES (
                                                                        SUBSTR (
                                                                            l_asn_pos_tab (
                                                                                l_num_po_ind).warehouse_code,
                                                                            1,
                                                                            10),
                                                                        SUBSTR (
                                                                            l_asn_pos_tab (
                                                                                l_num_po_ind).shipment_number,
                                                                            1,
                                                                            30),
                                                                        SUBSTR (
                                                                            l_asn_pos_tab (
                                                                                l_num_po_ind).po_number,
                                                                            1,
                                                                            30),
                                                                        SUBSTR (
                                                                            l_asn_pos_tab (
                                                                                l_num_po_ind).po_type,
                                                                            1,
                                                                            30),
                                                                        SUBSTR (
                                                                            l_asn_pos_tab (
                                                                                l_num_po_ind).factory_code,
                                                                            1,
                                                                            20),
                                                                        SUBSTR (
                                                                            l_asn_pos_tab (
                                                                                l_num_po_ind).factory_name,
                                                                            1,
                                                                            50),
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).process_status,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).error_message,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).request_id,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).creation_date,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).created_by,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).last_update_date,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).last_updated_by,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).source_type,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute1,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute2,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute3,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute4,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute5,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute6,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute7,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute8,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute9,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute10,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute11,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute12,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute13,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute14,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute15,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute16,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute17,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute18,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute19,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).attribute20,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).SOURCE,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).destination,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).record_type,
                                                                        l_asn_pos_tab (
                                                                            l_num_po_ind).po_header_id,
                                                                        l_num_asn_po_seq_id,
                                                                        l_num_asn_header_seq_id); /*SUBSTR*/
                                                EXCEPTION
                                                    WHEN OTHERS
                                                    THEN
                                                        p_out_chr_retcode   :=
                                                            2;
                                                        p_out_chr_errbuf   :=
                                                               'Error occured for PO Header insert '
                                                            || SQLERRM;
                                                        fnd_file.put_line (
                                                            fnd_file.LOG,
                                                            p_out_chr_errbuf);
                                                        l_chr_commit   := 'N';
                                                END;

                                                l_chr_prev_po_number   :=
                                                    l_asn_pos_tab (
                                                        l_num_po_ind).po_number;
                                            END IF;
                                        END IF;

                                        BEGIN
                                            SELECT xxdo_po_asn_po_lines_stg_s.NEXTVAL
                                              INTO l_num_asn_po_line_seq_id
                                              FROM DUAL;

                                            fnd_file.put_line (
                                                fnd_file.LOG,
                                                   'Inserting the PO Line: '
                                                || l_asn_po_lines_tab (
                                                       l_num_po_line_ind).line_number);

                                            INSERT INTO xxdo_po_asn_po_lines_stg (
                                                            warehouse_code,
                                                            shipment_number,
                                                            po_number,
                                                            carton_id,
                                                            line_number,
                                                            item_number,
                                                            status,
                                                            qty,
                                                            ordered_uom,
                                                            carton_weight,
                                                            carton_length,
                                                            carton_width,
                                                            carton_height,
                                                            inspection_type,
                                                            carton_dim_uom,
                                                            carton_weight_uom,
                                                            carton_crossdock_ref,
                                                            overage_allowance_type,
                                                            overage_allowance_qty,
                                                            overage_allowance_percent,
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
                                                            po_line_id,
                                                            shipment_line_id,
                                                            po_line_seq_id,
                                                            po_seq_id,
                                                            asn_header_seq_id,
                                                            inventory_item_id,
                                                            organization_id) /*SUBSTR*/
                                                     VALUES (
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).warehouse_code,
                                                                    1,
                                                                    10),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).shipment_number,
                                                                    1,
                                                                    30),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).po_number,
                                                                    1,
                                                                    30),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_id,
                                                                    1,
                                                                    250),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).line_number,
                                                                    1,
                                                                    5),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).item_number,
                                                                    1,
                                                                    30),
                                                                SUBSTR (
                                                                    DECODE (
                                                                        l_asn_po_lines_tab (
                                                                            l_num_po_line_ind).status,
                                                                        'EXPECTED', 'O',
                                                                        'PARTIALLY RECEIVED', 'O', -- Change in status for partially received OPEN_PARTIALLY_RECEIVED
                                                                        'C'),
                                                                    1,
                                                                    10),
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).qty,
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).ordered_uom,
                                                                    1,
                                                                    10),
                                                                ROUND (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_weight,
                                                                    2),
                                                                ROUND (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_length,
                                                                    2),
                                                                ROUND (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_width,
                                                                    2),
                                                                ROUND (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_height,
                                                                    2),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).inspection_type,
                                                                    1,
                                                                    30),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_dim_uom,
                                                                    1,
                                                                    10),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_weight_uom,
                                                                    1,
                                                                    10),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).carton_crossdock_ref,
                                                                    1,
                                                                    30),
                                                                SUBSTR (
                                                                    l_asn_po_lines_tab (
                                                                        l_num_po_line_ind).overage_allowance_type,
                                                                    1,
                                                                    10),
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).overage_allowance_qty,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).overage_allowance_percent,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).process_status,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).error_message,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).request_id,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).creation_date,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).created_by,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).last_update_date,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).last_updated_by,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).source_type,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute1,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute2,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute3,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute4,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute5,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute6,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute7,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute8,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute9,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute10,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute11,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute12,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute13,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute14,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute15,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute16,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute17,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute18,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute19,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).attribute20,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).SOURCE,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).destination,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).record_type,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).po_line_id,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).shipment_line_id,
                                                                l_num_asn_po_line_seq_id,
                                                                l_num_asn_po_seq_id,
                                                                l_num_asn_header_seq_id,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).inventory_item_id,
                                                                l_asn_po_lines_tab (
                                                                    l_num_po_line_ind).organization_id); /*SUBSTR*/
                                        EXCEPTION
                                            WHEN OTHERS
                                            THEN
                                                p_out_chr_retcode   := 2;
                                                p_out_chr_errbuf    :=
                                                       'Error occured for PO Lines insert '
                                                    || SQLERRM;
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                    p_out_chr_errbuf);
                                                l_chr_commit        := 'N';
                                        END;

                                        /* Insert Serial details for Serial controlled items */
                                        IF apps.xxdo_iid_to_serial (
                                               l_asn_po_lines_tab (
                                                   l_num_po_line_ind).inventory_item_id,
                                               l_asn_po_lines_tab (
                                                   l_num_po_line_ind).organization_id) =
                                           'Y'
                                        THEN
                                            BEGIN
                                                fnd_file.put_line (
                                                    fnd_file.LOG,
                                                       'Inserting the PO Serial : '
                                                    || l_asn_po_lines_tab (
                                                           l_num_po_line_ind).line_number);

                                                INSERT INTO xxdo_po_asn_serials_stg (
                                                                serial_seq_id,
                                                                warehouse_code,
                                                                shipment_number,
                                                                po_number,
                                                                carton_id,
                                                                line_number,
                                                                item_number,
                                                                serial_number,
                                                                serial_grade,
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
                                                                po_line_id,
                                                                shipment_line_id,
                                                                po_line_seq_id,
                                                                po_seq_id,
                                                                asn_header_seq_id)
                                                    SELECT xxdo_po_asn_po_serials_stg_s.NEXTVAL, SUBSTR (l_asn_po_lines_tab (l_num_po_line_ind).warehouse_code, 1, 10), SUBSTR (l_asn_po_lines_tab (l_num_po_line_ind).shipment_number, 1, 30),
                                                           SUBSTR (l_asn_po_lines_tab (l_num_po_line_ind).po_number, 1, 30), SUBSTR (l_asn_po_lines_tab (l_num_po_line_ind).carton_id, 1, 250), SUBSTR (l_asn_po_lines_tab (l_num_po_line_ind).line_number, 1, 5),
                                                           SUBSTR (l_asn_po_lines_tab (l_num_po_line_ind).item_number, 1, 30), SUBSTR (xst.serial_number, 1, 30), SUBSTR (DECODE (xst.status_id,  1, 'A',  2, 'B',  'C'), 1, 30),
                                                           l_asn_po_lines_tab (l_num_po_line_ind).process_status, l_asn_po_lines_tab (l_num_po_line_ind).error_message, l_asn_po_lines_tab (l_num_po_line_ind).request_id,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).creation_date, l_asn_po_lines_tab (l_num_po_line_ind).created_by, l_asn_po_lines_tab (l_num_po_line_ind).last_update_date,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).last_updated_by, l_asn_po_lines_tab (l_num_po_line_ind).source_type, l_asn_po_lines_tab (l_num_po_line_ind).attribute1,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute2, l_asn_po_lines_tab (l_num_po_line_ind).attribute3, l_asn_po_lines_tab (l_num_po_line_ind).attribute4,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute5, l_asn_po_lines_tab (l_num_po_line_ind).attribute6, l_asn_po_lines_tab (l_num_po_line_ind).attribute7,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute8, l_asn_po_lines_tab (l_num_po_line_ind).attribute9, l_asn_po_lines_tab (l_num_po_line_ind).attribute10,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute11, l_asn_po_lines_tab (l_num_po_line_ind).attribute12, l_asn_po_lines_tab (l_num_po_line_ind).attribute13,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute14, l_asn_po_lines_tab (l_num_po_line_ind).attribute15, l_asn_po_lines_tab (l_num_po_line_ind).attribute16,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute17, l_asn_po_lines_tab (l_num_po_line_ind).attribute18, l_asn_po_lines_tab (l_num_po_line_ind).attribute19,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).attribute20, l_asn_po_lines_tab (l_num_po_line_ind).SOURCE, l_asn_po_lines_tab (l_num_po_line_ind).destination,
                                                           l_asn_po_lines_tab (l_num_po_line_ind).record_type, l_asn_po_lines_tab (l_num_po_line_ind).po_line_id, l_asn_po_lines_tab (l_num_po_line_ind).shipment_line_id,
                                                           l_num_asn_po_line_seq_id, l_num_asn_po_seq_id, l_num_asn_header_seq_id
                                                      FROM xxdo.xxdo_serial_temp xst
                                                     WHERE     xst.license_plate_number =
                                                               l_asn_po_lines_tab (
                                                                   l_num_po_line_ind).carton_id
                                                           AND xst.inventory_item_id =
                                                               l_asn_po_lines_tab (
                                                                   l_num_po_line_ind).inventory_item_id;
                                            EXCEPTION
                                                WHEN OTHERS
                                                THEN
                                                    p_out_chr_retcode   := 2;
                                                    p_out_chr_errbuf    :=
                                                           'Error occured for PO Serial insert '
                                                        || SQLERRM;
                                                    fnd_file.put_line (
                                                        fnd_file.LOG,
                                                        p_out_chr_errbuf);
                                                    l_chr_commit        :=
                                                        'N';
                                            END;
                                        END IF;
                                    END LOOP;       -- PO lines insertion loop
                                END LOOP;               -- PO Lines fetch loop

                                IF cur_asn_po_lines%ISOPEN
                                THEN
                                    CLOSE cur_asn_po_lines;
                                END IF;
                            END LOOP;                         -- PO fetch loop

                            IF cur_asn_pos%ISOPEN
                            THEN
                                CLOSE cur_asn_pos;
                            END IF;
                        END LOOP;        -- End of asn headers processing loop
                    END LOOP;                 -- End of asn headers fetch loop

                    IF cur_asn_headers%ISOPEN
                    THEN
                        CLOSE cur_asn_headers;
                    END IF;
                END LOOP;              -- End of eligible ASNs processing loop
            END LOOP;                             -- End of eligible ASNs loop

            IF cur_eligible_asns%ISOPEN
            THEN
                CLOSE cur_eligible_asns;
            END IF;
        END LOOP;                                     -- End of Warehouse loop

        -- Commit the insertion of last ASN
        IF l_chr_commit = 'Y'
        THEN
            COMMIT;
            /*Commit previous ASN if that is already inserted */
            fnd_file.put_line (
                fnd_file.LOG,
                   'commmit records for warehouse, ASN number: '
                || l_chr_warehouse
                || '  '
                || l_chr_prev_shipment_num);
            fnd_file.put_line (fnd_file.LOG,
                               'ASN Extraction logic is complete');
        ELSIF l_chr_prev_shipment_num <> '-1'
        THEN
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                   'rollback records for warehouse, ASN number: '
                || l_chr_warehouse
                || '  '
                || l_chr_prev_shipment_num);
        END IF;

        SELECT NAME INTO l_chr_instance FROM v$database;

        lock_records (p_out_chr_errbuf       => l_chr_errbuf,
                      p_out_chr_retcode      => l_chr_retcode,
                      p_in_chr_shipment_no   => NULL);

        FOR cur_org_rec IN cur_org
        LOOP
            fnd_file.put_line (fnd_file.LOG,
                               'Warehouse  : ' || cur_org_rec.warehouse_code);
            l_num_request_id   :=
                fnd_request.submit_request ('XXDO',
                                            'XXDOASNX',
                                            NULL,
                                            NULL,
                                            FALSE,
                                            cur_org_rec.warehouse_code,
                                            l_chr_instance,
                                            g_num_request_id);
            COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               'Child request ID: ' || l_num_request_id);
        END LOOP;

        COMMIT;
        /* wait for child program completion - below procesure will wait till all child programs are completed */
        wait_for_request (g_num_request_id);
        fnd_file.put_line (fnd_file.LOG, 'Updating staging table status');
        /* update staging table entries as processed */
        fnd_file.put_line (fnd_file.LOG,
                           'Updating status for staging records');

        FOR cur_org_rec IN cur_org
        LOOP
            l_chr_status       := '-z';
            fnd_file.put_line (fnd_file.LOG,
                               'Warehouse' || cur_org_rec.warehouse_code);

            l_num_request_id   := 0;

            BEGIN
                SELECT status_code, request_id
                  INTO l_chr_status, l_num_request_id
                  FROM fnd_concurrent_requests
                 WHERE     parent_request_id = g_num_request_id
                       AND argument1 = cur_org_rec.warehouse_code;
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_chr_status       := '-z';
                    l_num_request_id   := 0;
            END;

            fnd_file.put_line (fnd_file.LOG, ' status code' || l_chr_status);
            fnd_file.put_line (fnd_file.LOG,
                               'request id ' || l_num_request_id);

            IF l_chr_status IN ('C', 'G')
            THEN
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     => NULL,
                    p_in_chr_error_message   => NULL,
                    p_in_chr_from_status     => 'INPROCESS',
                    p_in_chr_to_status       => 'PROCESSED',
                    p_in_chr_warehouse       => cur_org_rec.warehouse_code);

                copy_files (l_num_request_id, 'ASN', cur_org_rec.warehouse_code
                            , p_out_chr_retcode, p_out_chr_errbuf);
            ELSE
                update_error_records (
                    p_out_chr_errbuf         => l_chr_errbuf,
                    p_out_chr_retcode        => l_chr_retcode,
                    p_in_chr_shipment_no     => NULL,
                    p_in_chr_error_message   => 'XML Program ended in error',
                    p_in_chr_from_status     => 'INPROCESS',
                    p_in_chr_to_status       => 'ERROR',
                    p_in_chr_warehouse       => cur_org_rec.warehouse_code);
            END IF;
        END LOOP;

        IF p_in_chr_warehouse IS NULL AND p_in_chr_shipment_no IS NULL
        THEN
            -- updating the interface with next run time
            BEGIN
                xxdo_ont_wms_intf_util_pkg.set_last_run_time (
                    p_in_chr_interface_prgm_name   => NULL,
                    p_in_dte_run_time              => l_dte_next_run_time);
            EXCEPTION
                WHEN OTHERS
                THEN
                    p_out_chr_errbuf   :=
                           'Unexpected error while updating the next run time : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_next_run_not_updated;
            END;
        END IF;

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
        WHEN l_exe_xml_req_error
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_xml_req_not_launched
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_next_run_not_updated
        THEN
            p_out_chr_retcode   := '1';
        WHEN l_exe_bulk_insert_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_unable_to_lock
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_processed_not_marked
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_not_wms_warehouse
        THEN
            p_out_chr_retcode   := '2';
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_retcode   := '2';
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                'Unexpected error at main procedure : ' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END main;
END xxdo_po_asn_extract_pkg;
/
