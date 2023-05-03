--
-- XXDO_INV_INV_SYNC_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:33:42 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_INV_INV_SYNC_PKG"
AS
    /*
    *****************************************************************************
    $Header:  xxdo_inv_inv_sync_pkg_b.sql   1.0    2014/09/03    10:00:00   Infosys $
    *****************************************************************************
    */
    -- ***************************************************************************
    --                (c) Copyright Deckers Outdoor Corp.
    --                    All rights reserved
    -- ***************************************************************************
    --
    -- Package Name :  xxdo_inv_inv_sync_pkg
    --
    -- Description  :  This is package for WMS to EBS Inventory Synchronization interface
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- Date          Author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 03-Sep-14    Infosys            1.0       Created
    -- 29-Jan-15    Infosys            1.1       combine STAGE with PICK for comparison
    -- 17-Jul-15    Infosys            1.2       Added logic for emailing the Inv Sync report;
    --                                           Identified by MAIL_REPORT
    -- 05-Oct-15  Infosys              1.3      Added columns in MAIL_SYNC_REPORT procedure
    --                                           Indentified by MAIL_COLUMNS
    -- 25-Oct-22    TechM        1.4       Commented Attachment logic as per CCR0010106
    -- ***************************************************************************
    -- ***************************************************************************
    -- Procedure/Function Name  :  main
    --
    -- Description              :  This is the driver procedure which processes the comparisons for
    --                                   inventory Synchronization
    --
    -- parameters               :  p_out_chr_errbuf OUT : Error message
    --                                   p_out_chr_retcode OUT : Execution status
    --                                  p_in_num_snapshot_id   IN : Snapshot ID
    ----
    -- Return/Exit              :  N/A
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------  --------------------------------
    -- 2014/09/03    Infosys            1.0   Initial Version
    --2015/04/02    Infosys            1.1      Addtion of Archive Logic(PURGE_ARCHIVE) procedure
    -- ***************************************************************************


    /****************************************************************************
    -- Procedure Name      :  purge_archive
    --
    -- Description         :  This procedure is to archive and purge the old records


    -- Parameters          : p_out_chr_errbuf      OUT : Error message
    --                              p_out_chr_retocde     OUT : Return Code
    -
    -- Return/Exit         :  none
    --
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author             Version  Description
    -- ------------  -----------------  -------

    --------------------------------
    -- 2015/02/02 Infosys            1.0  Initial Version.
    --
    --
    ***************************************************************************/
    PROCEDURE purge_archive (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retocde OUT VARCHAR2, p_purge IN NUMBER)
    IS
        lv_procedure    VARCHAR2 (100) := '.PURGE_ARCHIVE';
        l_dte_sysdate   DATE := SYSDATE;
    BEGIN
        /*Inventory header interface*/
        BEGIN
            INSERT INTO xxdo_inv_sync_stg_log (wh_id, host_subinventory, snapshot_datetime, item_number, wms_qty, uom, organization_id, inventory_item_id, int_status, ebs_uom, ebs_onhand_qty, ebs_ship_pend_qty, ebs_ship_err_qty, ebs_rma_pend_qty, ebs_rma_err_qty, ebs_asn_pend_qty, ebs_asn_err_qty, ebs_adj_pend_qty, ebs_adj_err_qty, ebs_host_pend_qty, ebs_host_err_qty, result, process_status, error_message, request_id, source_type, record_type, remarks, locator, locator_id, snapshot_id, record_id, creation_date, created_by, last_update_date, last_updated_by, last_update_login, attribute1, attribute2, attribute3, attribute4, attribute5, attribute6, attribute7, attribute8, attribute9, attribute10, attribute11, attribute12, attribute13, attribute14, attribute15, attribute16, attribute17, attribute18, attribute19, attribute20, source, destination, archive_request_id
                                               , archive_date)
                SELECT wh_id, host_subinventory, snapshot_datetime,
                       item_number, wms_qty, uom,
                       organization_id, inventory_item_id, int_status,
                       ebs_uom, ebs_onhand_qty, ebs_ship_pend_qty,
                       ebs_ship_err_qty, ebs_rma_pend_qty, ebs_rma_err_qty,
                       ebs_asn_pend_qty, ebs_asn_err_qty, ebs_adj_pend_qty,
                       ebs_adj_err_qty, ebs_host_pend_qty, ebs_host_err_qty,
                       result, process_status, error_message,
                       request_id, source_type, record_type,
                       remarks, locator, locator_id,
                       snapshot_id, record_id, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, attribute1, attribute2,
                       attribute3, attribute4, attribute5,
                       attribute6, attribute7, attribute8,
                       attribute9, attribute10, attribute11,
                       attribute12, attribute13, attribute14,
                       attribute15, attribute16, attribute17,
                       attribute18, attribute19, attribute20,
                       source, destination, g_num_request_id,
                       l_dte_sysdate
                  FROM xxdo_inv_sync_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_inv_sync_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retocde   := '1';
                p_out_chr_errbuf    :=
                    'Error happened while archiving Syn  Header ' || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving Syn  HeaderHeader Data '
                    || SQLERRM);
        END;

        /*Inventory Sync serial details interface*/
        BEGIN
            INSERT INTO xxdo_inv_sync_serial_stg_log (wh_id,
                                                      item_number,
                                                      host_subinventory,
                                                      serial_number,
                                                      serial_seq_id,
                                                      result,
                                                      ebs_ship_pend_qty,
                                                      ebs_ship_err_qty,
                                                      ebs_rma_pend_qty,
                                                      ebs_rma_err_qty,
                                                      ebs_asn_pend_qty,
                                                      ebs_asn_err_qty,
                                                      ebs_adj_pend_qty,
                                                      ebs_adj_err_qty,
                                                      ebs_host_pend_qty,
                                                      ebs_host_err_qty,
                                                      locator_id,
                                                      snapshot_id,
                                                      record_id,
                                                      locator,
                                                      snapshot_datetime,
                                                      wms_qty,
                                                      uom,
                                                      creation_date,
                                                      created_by,
                                                      last_update_date,
                                                      last_updated_by,
                                                      last_update_login,
                                                      process_status,
                                                      error_message,
                                                      request_id,
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
                                                      source,
                                                      destination,
                                                      record_type,
                                                      ebs_onhand_qty,
                                                      organization_id,
                                                      inventory_item_id,
                                                      archive_request_id,
                                                      archive_date)
                SELECT wh_id, item_number, host_subinventory,
                       serial_number, serial_seq_id, result,
                       ebs_ship_pend_qty, ebs_ship_err_qty, ebs_rma_pend_qty,
                       ebs_rma_err_qty, ebs_asn_pend_qty, ebs_asn_err_qty,
                       ebs_adj_pend_qty, ebs_adj_err_qty, ebs_host_pend_qty,
                       ebs_host_err_qty, locator_id, snapshot_id,
                       record_id, locator, snapshot_datetime,
                       wms_qty, uom, creation_date,
                       created_by, last_update_date, last_updated_by,
                       last_update_login, process_status, error_message,
                       request_id, source_type, attribute1,
                       attribute2, attribute3, attribute4,
                       attribute5, attribute6, attribute7,
                       attribute8, attribute9, attribute10,
                       attribute11, attribute12, attribute13,
                       attribute14, attribute15, attribute16,
                       attribute17, attribute18, attribute19,
                       attribute20, source, destination,
                       record_type, ebs_onhand_qty, organization_id,
                       inventory_item_id, g_num_request_id, l_dte_sysdate
                  FROM xxdo_inv_sync_serial_stg
                 WHERE TRUNC (creation_date) <
                       TRUNC (l_dte_sysdate) - p_purge;

            DELETE FROM
                xxdo_inv_sync_serial_stg
                  WHERE TRUNC (creation_date) <
                        TRUNC (l_dte_sysdate) - p_purge;

            COMMIT;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_retocde   := '1';
                p_out_chr_errbuf    :=
                       'Error happened while archiving Syn SerialDetails '
                    || SQLERRM;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error happened while archiving Syn Serial  Details '
                    || SQLERRM);
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error occured in PROCEDURE  '
                || lv_procedure
                || '-'
                || SQLERRM);
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retocde   := '2';
    END purge_archive;

    /*MAIL_REPORT-BEGIN*/
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
                             'To: ' || l_chr_msg_to || UTL_TCP.crlf);
        UTL_SMTP.write_data (g_smtp_connection,
                             'From: ' || p_in_chr_msg_from || UTL_TCP.crlf);
        UTL_SMTP.write_data (
            g_smtp_connection,
            'Subject: ' || p_in_chr_msg_subject || UTL_TCP.crlf);
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
                             p_in_chr_msg_text || UTL_TCP.crlf);
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

    PROCEDURE mail_inv_sync_report (p_out_chr_errbuf    OUT VARCHAR2,
                                    p_out_chr_retcode   OUT VARCHAR2)
    IS
        l_rid_lookup_rec_rowid       ROWID;
        l_chr_from_mail_id           VARCHAR2 (2000);
        l_chr_to_mail_ids            VARCHAR2 (2000);
        l_chr_report_last_run_time   VARCHAR2 (60);
        l_dte_report_last_run_time   DATE;
        l_num_return_value           NUMBER;
        l_chr_header_sent            VARCHAR2 (1) := 'N';
        l_chr_instance               VARCHAR2 (60);
        l_exe_bulk_fetch_failed      EXCEPTION;
        l_exe_no_interface_setup     EXCEPTION;
        l_exe_mail_error             EXCEPTION;
        l_exe_instance_not_known     EXCEPTION;
        l_warehouse                  VARCHAR2 (10);

        CURSOR cur_inv_sync_records (g_num_request_id IN NUMBER)
        IS
              SELECT snapshot_datetime, attribute1 brand,     /*MAIL_COLUMNS*/
                                                          attribute2 gender,
                     attribute3 product_group, wh_id,         /*MAIL_COLUMNS*/
                                                      host_subinventory,
                     item_number, inventory_item_id, uom,
                     wms_qty, ebs_onhand_qty, (ebs_ship_pend_qty + ebs_ship_err_qty + ebs_rma_pend_qty + ebs_rma_err_qty + ebs_asn_pend_qty + ebs_asn_err_qty + ebs_adj_pend_qty + ebs_adj_err_qty + ebs_host_pend_qty + ebs_host_err_qty) ebs_interface_qty,
                     (NVL (wms_qty, 0) - NVL (ebs_onhand_qty, 0) - NVL (ebs_ship_pend_qty, 0) - NVL (ebs_ship_err_qty, 0) - NVL (ebs_rma_pend_qty, 0) - NVL (ebs_rma_err_qty, 0) - NVL (ebs_asn_pend_qty, 0) - NVL (ebs_asn_err_qty, 0) - NVL (ebs_adj_pend_qty, 0) - NVL (ebs_adj_err_qty, 0) - NVL (ebs_host_pend_qty, 0) - NVL (ebs_host_err_qty, 0)) difference, RESULT, ebs_ship_pend_qty,
                     ebs_ship_err_qty, ebs_rma_pend_qty, ebs_rma_err_qty,
                     ebs_asn_pend_qty, ebs_asn_err_qty, ebs_adj_pend_qty,
                     ebs_adj_err_qty, ebs_host_pend_qty, ebs_host_err_qty,
                     process_status, error_message, request_id
                FROM xxdo.xxdo_inv_sync_stg
               WHERE request_id = g_num_request_id
            ORDER BY wh_id, attribute1, attribute2,
                     attribute3, item_number, host_subinventory;

        TYPE l_inv_sync_rec_tab_type IS TABLE OF cur_inv_sync_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_inv_sync_rec_tab           l_inv_sync_rec_tab_type;
    BEGIN
        BEGIN
            SELECT NAME INTO l_chr_instance FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID, NVL (flv.attribute12, g_dte_sysdate), flv.attribute10,
                   flv.attribute11
              INTO l_rid_lookup_rec_rowid, l_chr_report_last_run_time, l_chr_from_mail_id, l_chr_to_mail_ids
              FROM fnd_lookup_values flv
             WHERE     flv.LANGUAGE = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = 'XXDO_INVSYNC';

            l_dte_report_last_run_time   :=
                TO_DATE (l_chr_report_last_run_time,
                         'DD-MON-RRRR HH24:MI:SS');
            fnd_file.put_line (
                fnd_file.LOG,
                   'XXDO_INVSYNC Last run time : '
                || l_chr_report_last_run_time
                || ' '
                || l_dte_report_last_run_time);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
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

        -- Logic to send the inv sync records
        OPEN cur_inv_sync_records (g_num_request_id);

        LOOP
            IF l_inv_sync_rec_tab.EXISTS (1)
            THEN
                l_inv_sync_rec_tab.DELETE;
            END IF;

            BEGIN
                FETCH cur_inv_sync_records
                    BULK COLLECT INTO l_inv_sync_rec_tab
                    LIMIT g_num_bulk_limit;
            EXCEPTION
                WHEN OTHERS
                THEN
                    CLOSE cur_inv_sync_records;

                    p_out_chr_errbuf   :=
                           'Unexcepted error in BULK Fetch of Inventory Sync records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_inv_sync_rec_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - Inventory Sync Report'
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                -- START Added per CCR0010106
                BEGIN
                    SELECT DISTINCT wh_id
                      INTO l_warehouse
                      FROM xxdo.xxdo_inv_sync_stg
                     WHERE request_id = g_num_request_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        l_warehouse   := NULL;
                END;

                send_mail_line (
                       'The Inventory Synchronization process has completed for '
                    || TO_CHAR (SYSDATE, 'DD-MON-RRRR')
                    || ' ('
                    || l_warehouse
                    || '). '
                    || 'Please run the '
                    || '"'
                    || 'Deckers - WMS to EBS Inventory Synchronization Report'
                    || '"'
                    || ' program to view the output.',
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;
        -- END Added per CCR0010106
        /* -- START Commented as per CCR0010106
        send_mail_line (
           'Content-Type: multipart/mixed; boundary=boundarystring',
           l_num_return_value);
        send_mail_line ('--boundarystring', l_num_return_value);
        send_mail_line ('Content-Type: text/plain', l_num_return_value);
        send_mail_line ('', l_num_return_value);
        --                   SEND_MAIL_LINE('Please refer the attached file for Inventory Sync Report ' || g_chr_instance ||' between '
        --                                              || to_char(l_dte_report_last_run_time, 'DD-Mon-RRRR HH24:MI:SS') || ' and '
        --                                              || to_char(g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS'),
        --                                              l_num_return_value);
        send_mail_line (
           'Please refer the attached file for Inventory Sync Report from '
           || l_chr_instance
           || ' for the date '
           || SYSDATE,
           l_num_return_value);
        send_mail_line ('', l_num_return_value);
        send_mail_line ('--boundarystring', l_num_return_value);
        send_mail_line ('Content-Type: text/xls', l_num_return_value);
        send_mail_line (
           'Content-Disposition: attachment; filename="Inventory_Sync_Report.xls"',
           l_num_return_value);
        send_mail_line ('--boundarystring', l_num_return_value);
        send_mail_line (
              'SnapShot Date Time'
           || CHR (9)
           || 'Warehouse'
           || CHR (9)
           ||   'Brand'
           || CHR (9)
           ||   'Gender'
           || CHR (9)
           ||   'Product Group'
           || CHR (9)
           || 'Item Number'
           || CHR (9)
           || 'Host SubInventory'
           || CHR (9)
           || 'UOM'
           || CHR (9)
           || 'WMS Quantity'
           || CHR (9)
           || 'EBS OnHand Quantity'
           || CHR (9)
           || 'EBS Interface Quantity'
           || CHR (9)
           || 'Difference'
           || CHR (9)
           || 'Result'
           || CHR (9)
           || 'EBS Ship Pend Qty'
           || CHR (9)
           || 'EBS Ship Error Qty'
           || CHR (9)
           || 'EBS RMA Pend Qty'
           || CHR (9)
           || 'EBS RMA Error Qty'
           || CHR (9)
           || 'EBS ASN Pend Qty'
           || CHR (9)
           || 'EBS ASN Error Qty'
           || CHR (9)
           || 'EBS ADJ Pend Qty'
           || CHR (9)
           || 'EBS ADJ Error Qty'
           || CHR (9)
           || 'EBS Host Pend Qty'
           || CHR (9)
           || 'EBS Host Error Qty'
           || CHR (9)
           || 'Process Status'
           || CHR (9)
           || 'Error Message'
           || CHR (9)
           || 'Request ID'
           || CHR (9),
           l_num_return_value);
        l_chr_header_sent := 'Y';
     END IF;

     FOR l_num_ind IN l_inv_sync_rec_tab.FIRST .. l_inv_sync_rec_tab.LAST
     LOOP
        send_mail_line (
           TO_CHAR (l_inv_sync_rec_tab (l_num_ind).snapshot_datetime,
                    'DD-Mon-RRRR HH24:MI:SS')
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).wh_id
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).brand
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).Gender
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).Product_group
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).item_number
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).host_subinventory
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).uom
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).wms_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_onhand_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_interface_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).difference
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).result
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_ship_pend_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_ship_err_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_rma_pend_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_rma_err_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_asn_pend_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_asn_err_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_adj_pend_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_adj_err_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_host_pend_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).ebs_host_err_qty
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).process_status
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).error_message
           || CHR (9)
           || l_inv_sync_rec_tab (l_num_ind).request_id
           || CHR (9),
           l_num_return_value);

        IF l_num_return_value <> 0
        THEN
           p_out_chr_errbuf := 'Unable to generate the attachment file';
           RAISE l_exe_mail_error;
        END IF;
     END LOOP; */
        -- END Commented as per CCR0010106
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_inv_sync_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);

        IF l_num_return_value <> 0
        THEN
            p_out_chr_errbuf   := 'Unable to close the mail connection';
            RAISE l_exe_mail_error;
        END IF;

        -- Update the report last run time for scheduled run
        IF g_num_no_of_days IS NULL
        THEN
            BEGIN
                UPDATE fnd_lookup_values flv
                   SET attribute13 = TO_CHAR (g_dte_sysdate, 'DD-Mon-RRRR HH24:MI:SS')
                 WHERE flv.ROWID = l_rid_lookup_rec_rowid;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Unexpected error while updating the next run time : '
                        || SQLERRM);
            END;
        END IF;
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate Inventory Sync report';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at Inventory Sync report procedure';
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at Inventory Sync report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
    END mail_inv_sync_report;

    /*MAIL_REPORT-END*/

    PROCEDURE set_in_process (p_retcode     OUT VARCHAR2,
                              p_error_buf   OUT VARCHAR2)
    IS
    BEGIN
        p_error_buf   := NULL;
        p_retcode     := '0';

        UPDATE XXDO_INV_SYNC_STG
           SET process_status = 'INPROCESS', request_id = g_num_request_id, last_updated_by = g_num_user_id,
               last_update_login = g_num_login_id, last_update_date = SYSDATE, RESULT = NULL,
               inventory_item_id = NULL, organization_id = NULL, ebs_onhand_qty = 0,
               ebs_uom = NULL, ebs_ship_pend_qty = 0, ebs_ship_err_qty = 0,
               ebs_rma_pend_qty = 0, ebs_rma_err_qty = 0, ebs_asn_pend_qty = 0,
               ebs_asn_err_qty = 0, ebs_adj_pend_qty = 0, ebs_adj_err_qty = 0,
               ebs_host_pend_qty = 0, ebs_host_err_qty = 0, error_message = NULL
         WHERE     1 = 1
               AND process_status = 'NEW'
               AND request_id IS NULL
               AND wh_id IN
                       (SELECT lookup_code
                          FROM fnd_lookup_values
                         WHERE     lookup_type = 'XXONT_WMS_WHSE'
                               AND NVL (LANGUAGE, USERENV ('LANG')) =
                                   USERENV ('LANG')
                               AND enabled_flag = 'Y');

        fnd_file.put_line (
            fnd_file.LOG,
               'No of rows updated  from XXDO_INV_SYNC_STG  to INPROCESS '
            || SQL%ROWCOUNT);
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error_buf   := SQLERRM;
            p_retcode     := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected Error in Set_on_process:' || p_error_buf);
    END set_in_process;


    PROCEDURE main (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_in_num_snapshot_id IN NUMBER
                    , p_in_num_purge_days IN NUMBER DEFAULT 30)
    IS
        l_num_ebs_qty_tran        NUMBER;
        l_num_ebs_qty_trans       NUMBER;
        l_num_ebs_qty_trand       NUMBER;
        l_num_ebs_qty_asn         NUMBER;
        l_num_ebs_qty_shp         NUMBER;
        l_num_ebs_qty_rma         NUMBER;
        l_num_ebs_qtye_tran       NUMBER;
        l_num_ebs_qtye_trans      NUMBER;
        l_num_ebs_qtye_trand      NUMBER;
        l_num_ebs_qtye_asn        NUMBER;
        l_num_ebs_qtye_shp        NUMBER;
        l_num_ebs_qtye_rma        NUMBER;
        l_num_inventory_item_id   NUMBER;
        l_chr_primary_uom_code    VARCHAR2 (10);
        l_num_bulk_limit          NUMBER := 1000;
        l_num_error_count         NUMBER := 0;
        l_chr_delimiter           VARCHAR2 (100) := CHR (9);
        l_chr_mail_string1        VARCHAR2 (32767);
        l_chr_crlf                VARCHAR2 (2) := CHR (13) || CHR (10);
        l_chr_details             VARCHAR2 (32767);
        l_chr_header              VARCHAR2 (32767);
        l_chr_retcode             VARCHAR2 (100) := '0';
        l_chr_errbuf              VARCHAR2 (2000) := NULL;
        l_inv_sync_stg_tab        g_inv_sync_stg_tab_type;
        l_inv_sync_rec_tab        g_inv_sync_rec_tab_type;
        l_sub_inventories_tab     g_ids_var_tab_type;
        l_inv_org_attr_tab        g_inv_org_attr_tab_type;
        l_exe_warehouse_err       EXCEPTION;
        l_exe_subinv_err          EXCEPTION;
        l_exe_invalid_snapshot    EXCEPTION;
        l_exe_invalid_uom         EXCEPTION;
        l_exe_invalid_item        EXCEPTION;
        --l_exe_locator_err            EXCEPTION;
        l_exe_bulk_fetch_failed   EXCEPTION;
        l_exe_output_rep_err      EXCEPTION;
        l_exe_dml_errors          EXCEPTION;
        PRAGMA EXCEPTION_INIT (l_exe_dml_errors, -24381);

        /*    CURSOR cur_inv_arg_attributes
            IS
               SELECT flv.lookup_code organization_code, mp.organization_id
                 FROM fnd_lookup_values flv, mtl_parameters mp
                WHERE     flv.lookup_type = 'XXONT_WMS_WHSE'
                      AND NVL (flv.LANGUAGE, USERENV ('LANG')) = USERENV ('LANG')
                      AND flv.enabled_flag = 'Y'
                      AND SYSDATE BETWEEN NVL (start_date_active, SYSDATE - 1)
                                      AND NVL (end_date_active, SYSDATE + 1)
                      AND mp.organization_code = flv.lookup_code;

            CURSOR cur_sub_inventories (p_num_organization_id IN NUMBER)
            IS
               SELECT secondary_inventory_name subinventory
                 FROM mtl_secondary_inventories
                WHERE organization_id = p_num_organization_id;
                */

        CURSOR cur_inv_sync IS
            SELECT *
              FROM xxdo_inv_sync_stg
             WHERE     NVL (snapshot_id, -1) =
                       NVL (p_in_num_snapshot_id, NVL (snapshot_id, -1))
                   AND process_status = 'PROCESSED'
                   AND request_id = g_num_request_id;
    /*
           CURSOR cur_inv_subinv IS
              SELECT DISTINCt wh_id,
                          host_subinventory
                FROM xxdo_inv_sync_stg
                WHERE snapshot_id = nvl(p_in_num_snapshot_id,snapshot_id)
                    AND process_status ='NEW';


    CURSOR cur_inv_subinv
    IS
       SELECT mp.organization_code wh_id,
              subinv.secondary_inventory_name host_subinventory
         FROM mtl_secondary_inventories subinv, mtl_parameters mp
        WHERE mp.organization_id = subinv.organization_id
              AND subinv.secondary_inventory_name <> 'STAGE'
              /*added for version 1.1*/
    /*     AND mp.organization_code IN
                (SELECT wh_id
                   FROM xxdo_inv_sync_stg
                  WHERE NVL (snapshot_id, -1) =
                           NVL (p_in_num_snapshot_id,
                                NVL (snapshot_id, -1))
                        AND process_status = 'NEW');    */
    BEGIN
        p_out_chr_errbuf    := NULL;
        p_out_chr_retcode   := '0';
        g_dte_sysdate       := SYSDATE;
        fnd_file.put_line (fnd_file.LOG, 'Creating Reconciliation Report...');

        --  lch_filename := 'EBS_INVENTORY_SYNC_RECON_REPORT'||g_num_request_id||'.csv';
        -- lch_subject :=  ': EBS_INVENTORY_SYNC_RECON_REPORT for snapshot_id : ' || p_in_num_snapshot_id;
        -- lch_sender_addr := fnd_profile.VALUE ('CETS_INVSYNC_DISCREC_SENDER_MAIL_ID');-----should change
        --DBMS_LOB.createtemporary (lch_mail_string_temp, TRUE);   -- Creates a temporary CLOB lch_mail_string_temp.
        --DBMS_LOB.OPEN (lch_mail_string_temp, DBMS_LOB.lob_readwrite); -- Opens the CLOB in read write mode.
        /* Print the header line */
        /*
               l_chr_mail_string1 :=
                                   l_chr_delimiter
                                || l_chr_delimiter
                                || l_chr_delimiter
                                || 'EBS-WMS INVENTORY SYNC RECON REPORT'
                                || l_chr_delimiter
                                || l_chr_delimiter
                                || l_chr_delimiter
                                || CHR (32)
                                || CHR (10);
                              --   DBMS_LOB.writeappend (lch_mail_string_temp,  LENGTH (l_chr_mail_string1), l_chr_mail_string1 );
                                   fnd_file.put_line (fnd_file.output, l_chr_mail_string1);
                                   -- Append the CLOB with the string l_chr_mail_string1, containing the column names.
                                    -- Insert Column Headings

        l_chr_header :=
              'Snapshot Id'
           || l_chr_delimiter
           || 'Snapshot Time'
           || l_chr_delimiter
           || 'Warehouse Code'
           || l_chr_delimiter
           || 'Subinventory'
           || l_chr_delimiter
           || 'Item Number'
           || l_chr_delimiter
           || 'UOM'
           || l_chr_delimiter
           || 'WMS Onhand Qty'
           || l_chr_delimiter
           || 'Ebs Onhand Qty'
           || l_chr_delimiter
           || 'Result'
           || l_chr_delimiter
           || 'Error Message'
           || l_chr_delimiter
           || 'Pending Qty - Inventory Adjustments'
           || l_chr_delimiter
           || 'Pending Qty - Host Transfers'
           || l_chr_delimiter
           || 'Pending Qty - ASN Receipt'
           || l_chr_delimiter
           || 'Pending Qty - RMA Receipt'
           || l_chr_delimiter
           || 'Pending Qty - Ship Confirm'
           || l_chr_delimiter
           || 'Errored Qty - Inventory Adjustments'
           || l_chr_delimiter
           || 'Errored Qty - Host Transfers'
           || l_chr_delimiter
           || 'Errored Qty - ASN Receipt'
           || l_chr_delimiter
           || 'Errored Qty - RMA Receipt'
           || l_chr_delimiter
           || 'Errored Qty - Ship Confirm';
        -- write column headers to file
        --   DBMS_LOB.writeappend (lch_mail_string_temp,  LENGTH (l_chr_header),  l_chr_header  );
        fnd_file.put_line (fnd_file.output, l_chr_header);
  */
        BEGIN
            set_in_process (p_out_chr_errbuf, p_out_chr_retcode);
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while Changing prcess status ' || SQLERRM);
                p_out_chr_errbuf    :=
                    'Error while Changing prcess status ' || SQLERRM;
                p_out_chr_retcode   := '2';
        END;

        --Validations Error

        /* inventory item id , organization Id */

        BEGIN
            UPDATE apps.xxdo_inv_sync_stg x
               SET (inventory_item_id, organization_id)   =
                       (SELECT msi.inventory_item_id, msi.organization_id
                          FROM apps.mtl_system_items_kfv msi, apps.mtl_parameters mp
                         WHERE     msi.organization_id = mp.organization_id
                               AND mp.organization_code = x.wh_id
                               AND msi.segment1 = x.item_number)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS';

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'updated item id '
                || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24:mi:ss'));
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while updating staging table ' || SQLERRM);
                p_out_chr_errbuf    :=
                    'Error while updating staging table ' || SQLERRM;
                p_out_chr_retcode   := '2';
        END;

        BEGIN
            UPDATE apps.xxdo_inv_sync_stg x
               SET error_message = 'Invalid item or organization', process_status = 'ERROR'
             WHERE     request_id = g_num_request_id
                   AND (inventory_item_id IS NULL OR organization_id IS NULL);

            COMMIT;

            /* insert additional items */

            BEGIN
                INSERT INTO apps.xxdo_inv_sync_stg (wh_id,
                                                    host_subinventory,
                                                    snapshot_datetime,
                                                    item_number,
                                                    wms_qty,
                                                    organization_id,
                                                    inventory_item_id,
                                                    process_status,
                                                    uom,
                                                    ebs_onhand_qty,
                                                    creation_date,
                                                    last_update_date,
                                                    created_by,
                                                    last_updated_by,
                                                    last_update_login,
                                                    request_id,
                                                    ebs_ship_pend_qty,
                                                    ebs_ship_err_qty,
                                                    ebs_rma_pend_qty,
                                                    ebs_rma_err_qty,
                                                    ebs_asn_pend_qty,
                                                    ebs_asn_err_qty,
                                                    ebs_adj_pend_qty,
                                                    ebs_adj_err_qty,
                                                    ebs_host_pend_qty,
                                                    ebs_host_err_qty)
                      SELECT organization_code, subinv, SYSDATE,
                             item, 0 wms_qty, organization_id,
                             inventory_item_id, 'INPROCESS' status, primary_uom_code,
                             SUM (ebs_qty) ebs_qty, SYSDATE, SYSDATE,
                             -999, -999, -999,
                             g_num_request_id, 0, 0,
                             0, 0, 0,
                             0, 0, 0,
                             0, 0
                        FROM (  SELECT mp.organization_code, DECODE (moq.subinventory_code, 'STAGE', 'PICK', moq.subinventory_code) subinv, msi.segment1 item,
                                       msi.organization_id, msi.inventory_item_id, msi.primary_uom_code,
                                       SUM (transaction_quantity) ebs_qty
                                  FROM apps.mtl_system_items_kfv msi, apps.mtl_onhand_quantities moq, apps.mtl_parameters mp
                                 WHERE     mp.organization_code IN
                                               (SELECT lookup_code
                                                  FROM fnd_lookup_values
                                                 WHERE     lookup_type =
                                                           'XXONT_WMS_WHSE'
                                                       AND NVL (LANGUAGE,
                                                                USERENV ('LANG')) =
                                                           USERENV ('LANG')
                                                       AND enabled_flag = 'Y')
                                       AND mp.organization_code IN
                                               (SELECT DISTINCT wh_id --Only add WH for INPROCESS Files
                                                  FROM apps.xxdo_inv_sync_stg s1
                                                 WHERE     s1.request_id =
                                                           g_num_request_id
                                                       AND s1.process_status =
                                                           'INPROCESS'
                                                       AND s1.inventory_item_id =
                                                           msi.inventory_item_id
                                                       AND s1.host_subinventory =
                                                           DECODE (
                                                               moq.subinventory_code,
                                                               'STAGE', 'PICK',
                                                               moq.subinventory_code))
                                       AND mp.organization_id =
                                           msi.organization_id
                                       AND NOT EXISTS
                                               (SELECT 1
                                                  FROM apps.xxdo_inv_sync_stg s1
                                                 WHERE     s1.request_id =
                                                           g_num_request_id
                                                       AND s1.process_status =
                                                           'INPROCESS'
                                                       AND s1.inventory_item_id =
                                                           msi.inventory_item_id
                                                       AND s1.host_subinventory =
                                                           DECODE (
                                                               moq.subinventory_code,
                                                               'STAGE', 'PICK',
                                                               moq.subinventory_code))
                                       AND moq.inventory_item_id =
                                           msi.inventory_item_id
                                       AND moq.organization_id =
                                           msi.organization_id
                                HAVING SUM (transaction_quantity) > 0
                              GROUP BY moq.inventory_item_id, mp.organization_code, msi.segment1,
                                       moq.subinventory_code, msi.organization_id, msi.inventory_item_id,
                                       msi.primary_uom_code) x
                    GROUP BY organization_code, subinv, item,
                             organization_id, inventory_item_id, primary_uom_code;

                COMMIT;
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Inserted missing items '
                    || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24:mi:ss'));
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Error while Inserting into  staging table '
                        || SQLERRM);
                    p_out_chr_errbuf    :=
                           'Error while Inserting into  staging table '
                        || SQLERRM;
                    p_out_chr_retcode   := '2';
            END;



            --COMMIT;
            /*added for version 1.1*/

            /*
            UPDATE xxdo_inv_sync_stg xis
               SET ebs_onhand_qty =
                        NVL (ebs_onhand_qty, 0)
                      + NVL (
                           (SELECT SUM (transaction_quantity)
                              FROM mtl_onhand_quantities moq
                             WHERE     moq.organization_id = xis.organization_id
                                   AND moq.subinventory_code = 'STAGE'
                                   AND moq.inventory_item_id =
                                          xis.inventory_item_id),
                           0)
             WHERE xis.process_status = 'NEW' AND host_subinventory = 'PICK';

            COMMIT;



               UPDATE apps.xxdo_inv_sync_stg x
                  SET error_message = 'Invalid Snapshot date',
                      process_status = 'ERROR'
                WHERE request_id = g_num_request_id AND process_status = 'INPROCESS'
                AND (snapshot_datetime IS NULL);

               COMMIT;

               UPDATE apps.xxdo_inv_sync_stg x
                  SET error_message = 'Invalid Snapshot date',
                      process_status = 'ERROR'
                WHERE request_id = g_num_request_id
                AND process_status = 'INPROCESS' AND (snapshot_datetime IS NULL);

               COMMIT;

               UPDATE apps.xxdo_inv_sync_stg x
                  SET error_message = 'IInvalid UOM', process_status = 'ERROR'
                WHERE request_id = g_num_request_id AND ebs_uom <> uom
                AND process_status = 'INPROCESS';

               COMMIT;
      */
            /* brand gender prod group */
            UPDATE apps.xxdo_inv_sync_stg x
               SET (attribute1, attribute2, attribute3)   =
                       (SELECT mc.segment1, mc.segment3, mc.segment2
                          FROM apps.mtl_categories_b mc, apps.mtl_item_categories mic
                         WHERE     x.organization_id = mic.organization_id
                               AND mic.inventory_item_id =
                                   x.inventory_item_id
                               AND mic.category_set_id = 1
                               AND mc.category_id = mic.category_id)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS';

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Updated brand and gender '
                || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24:mi:ss'));



            /* onhand */
            UPDATE apps.xxdo_inv_sync_stg x
               SET ebs_onhand_qty   =
                       NVL (
                           (SELECT NVL (SUM (transaction_quantity), 0)
                              FROM apps.mtl_onhand_quantities moq
                             WHERE     moq.inventory_item_id =
                                       x.inventory_item_id
                                   AND moq.organization_id =
                                       x.organization_id
                                   AND DECODE (moq.subinventory_code,
                                               'STAGE', 'PICK',
                                               moq.subinventory_code) =
                                       x.host_subinventory),
                           0)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS';

            fnd_file.put_line (
                fnd_file.LOG,
                   'Updated onhand '
                || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24:mi:ss'));
            COMMIT;

            /* ship pending and error quantities */
            UPDATE apps.xxdo_inv_sync_stg x
               SET ebs_ship_pend_qty   =
                       NVL (
                           (SELECT (-NVL (SUM (qty), 0))
                              FROM apps.xxdo_ont_ship_conf_cardtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.host_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status IN
                                           ('NEW', 'INPROCESS')),
                           0),
                   ebs_ship_err_qty   =
                       NVL (
                           (SELECT (-NVL (SUM (qty), 0))
                              FROM apps.xxdo_ont_ship_conf_cardtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.host_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status = 'ERROR'),
                           0)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND item_number IN
                           (SELECT s1.item_number
                              FROM apps.xxdo_ont_ship_conf_cardtl_stg s1
                             WHERE s1.process_status IN
                                       ('NEW', 'INPROCESS', 'ERROR'));

            COMMIT;

            /* RMA pending and error */
            UPDATE apps.xxdo_inv_sync_stg x
               SET ebs_rma_pend_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_ont_rma_line_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.host_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status IN
                                           ('NEW', 'INPROCESS', 'HOLD')),
                           0),
                   ebs_rma_err_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_ont_rma_line_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.host_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status = 'ERROR'),
                           0)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND item_number IN (SELECT s1.item_number
                                         FROM apps.xxdo_ont_rma_line_stg s1
                                        WHERE s1.process_status IN ('NEW', 'INPROCESS', 'ERROR',
                                                                    'HOLD'));

            COMMIT;

            /* ASN pending and error */
            UPDATE apps.xxdo_inv_sync_stg x
               SET ebs_asn_pend_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_po_asn_receipt_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.host_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status IN
                                           ('NEW', 'INPROCESS')),
                           0),
                   ebs_asn_err_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_po_asn_receipt_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.host_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status = 'ERROR'),
                           0)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND item_number IN
                           (SELECT s1.item_number
                              FROM apps.xxdo_po_asn_receipt_dtl_stg s1
                             WHERE s1.process_status IN
                                       ('NEW', 'INPROCESS', 'ERROR'));

            COMMIT;

            /* INV adjustment and  HOST transfer */
            UPDATE apps.xxdo_inv_sync_stg x
               SET ebs_adj_pend_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.source_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status IN
                                           ('NEW', 'INPROCESS')
                                   AND s.dest_subinventory IS NULL),
                           0),
                   ebs_adj_err_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.source_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status = 'ERROR'
                                   AND s.dest_subinventory IS NULL),
                           0),
                   ebs_host_pend_qty   =
                       NVL (
                           (SELECT -1 * NVL (SUM (qty), 0)
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.source_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status IN
                                           ('NEW', 'INPROCESS')
                                   AND s.dest_subinventory IS NOT NULL),
                           0),
                   ebs_host_err_qty   =
                       NVL (
                           (SELECT -1 * NVL (SUM (qty), 0)
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.source_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status = 'ERROR'
                                   AND s.dest_subinventory IS NOT NULL),
                           0)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND item_number IN
                           (SELECT s1.item_number
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s1
                             WHERE s1.process_status IN
                                       ('NEW', 'INPROCESS', 'ERROR'));

            COMMIT;

            /* HOST TRANSFER in target sub inventory */

            /* INV adjustment and transfer */
            UPDATE apps.xxdo_inv_sync_stg x
               SET ebs_host_pend_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.dest_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status IN
                                           ('NEW', 'INPROCESS')
                                   AND s.dest_subinventory IS NOT NULL),
                           0),
                   ebs_host_err_qty   =
                       NVL (
                           (SELECT NVL (SUM (qty), 0)
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s
                             WHERE     s.wh_id = x.wh_id
                                   AND s.dest_subinventory =
                                       x.host_subinventory
                                   AND s.item_number = x.item_number
                                   AND s.process_status = 'ERROR'
                                   AND s.dest_subinventory IS NOT NULL),
                           0)
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND item_number IN
                           (SELECT s1.item_number
                              FROM apps.xxdo_inv_trans_adj_dtl_stg s1
                             WHERE     s1.dest_subinventory IS NOT NULL
                                   AND s1.process_status IN
                                           ('NEW', 'INPROCESS', 'ERROR'));

            COMMIT;

            UPDATE apps.xxdo_inv_sync_stg x
               SET attribute4 = ebs_onhand_qty + ebs_ship_pend_qty + ebs_ship_err_qty + ebs_rma_pend_qty + ebs_rma_err_qty + ebs_asn_pend_qty + ebs_asn_err_qty + ebs_adj_pend_qty + ebs_adj_err_qty + ebs_host_pend_qty + ebs_host_err_qty
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS';

            COMMIT;

            UPDATE apps.xxdo_inv_sync_stg x
               SET RESULT = 'PERFECT_MATCH', process_status = 'PROCESSED', attribute5 = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND x.wms_qty = x.ebs_onhand_qty
                   AND ebs_ship_pend_qty = 0
                   AND ebs_ship_err_qty = 0
                   AND ebs_rma_pend_qty = 0
                   AND ebs_rma_err_qty = 0
                   AND ebs_asn_pend_qty = 0
                   AND ebs_asn_err_qty = 0
                   AND ebs_adj_pend_qty = 0
                   AND ebs_adj_err_qty = 0
                   AND ebs_host_pend_qty = 0
                   AND ebs_host_err_qty = 0;

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Updated Interfaces '
                || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24:mi:ss'));

            UPDATE apps.xxdo_inv_sync_stg x
               SET RESULT = 'PARTIAL_MATCH', process_status = 'PROCESSED', attribute5 = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND x.wms_qty = x.attribute4
                   AND RESULT IS NULL;

            COMMIT;

            UPDATE apps.xxdo_inv_sync_stg x
               SET RESULT = 'MISMATCH', process_status = 'PROCESSED', attribute5 = TO_CHAR (SYSDATE, 'MM/DD/YYYY HH24:MI:SS')
             WHERE     request_id = g_num_request_id
                   AND process_status = 'INPROCESS'
                   AND RESULT IS NULL;

            COMMIT;
            fnd_file.put_line (
                fnd_file.LOG,
                   'Updated Result '
                || TO_CHAR (SYSDATE, 'dd-mon-yyyy hh24:mi:ss'));
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while Updating at last ' || SQLERRM);
                p_out_chr_errbuf    :=
                    'Error while Updating at last ' || SQLERRM;
                p_out_chr_retcode   := '2';
        END;



        --Get WMS warehouse details

        /*    FOR cur_inv_sync_rec IN cur_inv_sync
            LOOP
               BEGIN
                  l_chr_details :=
                     p_in_num_snapshot_id || l_chr_delimiter
                     || TO_CHAR (cur_inv_sync_rec.snapshot_datetime,
                                 'DD-Mon-RRRR HH:MI:SS AM')
                     || l_chr_delimiter
                     || cur_inv_sync_rec.wh_id
                     || l_chr_delimiter
                     || cur_inv_sync_rec.host_subinventory
                     || l_chr_delimiter
                     || cur_inv_sync_rec.item_number
                     || l_chr_delimiter
                     || cur_inv_sync_rec.uom
                     || l_chr_delimiter
                     || cur_inv_sync_rec.wms_qty
                     || l_chr_delimiter
                     || NVL (cur_inv_sync_rec.ebs_onhand_qty, 0)
                     || l_chr_delimiter
                     || cur_inv_sync_rec.RESULT
                     || l_chr_delimiter
                     || cur_inv_sync_rec.error_message
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_adj_pend_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_host_pend_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_asn_pend_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_rma_pend_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_ship_pend_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_adj_err_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_host_err_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_asn_err_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_rma_err_qty
                     || l_chr_delimiter
                     || cur_inv_sync_rec.ebs_ship_err_qty;
                  -- to write column values to output file
                  -- DBMS_LOB.writeappend (lch_mail_string_temp, LENGTH (l_chr_details), l_chr_details );
                  fnd_file.put_line (fnd_file.output, l_chr_details);
               EXCEPTION
                  WHEN OTHERS
                  THEN
                     RAISE l_exe_output_rep_err;
               END;
            END LOOP;


            --   COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               'End Creating Reconciliation Report...');

            /*MAIL_REPORT - BEGIN*/
        BEGIN
            fnd_file.put_line (
                fnd_file.LOG,
                'Calling procedure to send Inventory Sync Report: ');
            fnd_file.put_line (fnd_file.LOG,
                               'Request ID :' || g_num_request_id);
            mail_inv_sync_report (l_chr_errbuf, l_chr_retcode);
        EXCEPTION
            WHEN OTHERS
            THEN
                p_out_chr_errbuf   :=
                    'Unable to get the inteface setup due to ' || SQLERRM;
                fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        END;

        /*MAIL_REPORT - END*/

        ----------------------------------------------------------------
        /*Start of PURGE_ARCHIVE*/
        purge_archive (p_out_chr_retcode,
                       p_out_chr_errbuf,
                       p_in_num_purge_days);
    /*End of PURGE_ARCHIVE*/
    EXCEPTION
        WHEN l_exe_output_rep_err
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Fatal Exception in Output writing:' || SQLERRM);
            p_out_chr_errbuf    :=
                'Fatal Exception in Output writing:' || SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    := SQLERRM;
            p_out_chr_retcode   := '2';
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error in main procedure : ' || p_out_chr_errbuf);
    END main;
END xxdo_inv_inv_sync_pkg;
/
