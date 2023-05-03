--
-- XXDO_3PL_INV_SYNC  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:36 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_3PL_INV_SYNC"
AS
    /*
       REM $Header: APPS."XXDO_3PL_INV_SYNC".PKB 1.0 13-SEP-2016 $
      REM ===================================================================================================
      REM             (c) Copyright Deckers Outdoor Corporation
      REM                       All Rights Reserved
      REM ===================================================================================================
      REM
      REM Name          : APPS."XXDO_3PL_INV_SYNC".PKB
      REM
      REM Procedure     :
      REM Special Notes : Main Procedure called by Concurrent Manager
      REM
      REM Procedure     :
      REM Special Notes :
      REM
      REM         CR #  :
      REM ===================================================================================================
      REM History:  Creation Date :13-SEP-2016
      REM
      REM Modification History
      REM Person                  Date              Version              Comments and changes made
      REM -------------------    ----------         ----------           ------------------------------------
      REM Chaithanya            13-SEP-2016            1.0                 1. Base lined for delivery
      REM Chaithanya            25-JUN-2017            2.0                 1. CCR0006355 changes
      REM GJensen                7-JUL-2018            3.0                 1. CCR0007323 changes
      REM
      REM ===================================================================================================
    */

    --Begin CCR0007323
    FUNCTION get_brand_for_item (p_inventory_item_id IN NUMBER)
        RETURN VARCHAR2
    IS
        l_brand   VARCHAR2 (50);
    BEGIN
        SELECT c.segment1
          INTO l_brand
          FROM mtl_system_items_b i, mtl_item_categories ic, mtl_categories_b c
         WHERE     i.inventory_item_id = p_inventory_item_id
               AND i.organization_id = 106                               --MST
               AND i.organization_id = ic.organization_id
               AND i.inventory_item_id = ic.inventory_item_id
               AND ic.category_set_id = 1
               AND ic.category_id = c.category_id
               AND c.structure_id = 101;

        RETURN l_brand;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN NULL;
    END;

    --End CCR0007323


    PROCEDURE print_line (p_mode    IN VARCHAR2 DEFAULT 'L',
                          p_input   IN VARCHAR2)
    IS
    BEGIN
        IF p_mode = 'O'
        THEN
            apps.fnd_file.put_line (apps.fnd_file.output, p_input);
        ELSE
            apps.fnd_file.put_line (apps.fnd_file.LOG, p_input);
        END IF;
    END print_line;

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
            print_line ('L', CHR (10) || 'Email ID: ' || l_chr_mail_id);
            UTL_SMTP.rcpt (g_smtp_connection, TRIM (l_chr_mail_id));
        ELSE
            WHILE (LENGTH (l_chr_mail_temp) > 0)
            LOOP
                IF (INSTR (l_chr_mail_temp, ';', 1) = 0)
                THEN
                    -- Last Mail ID
                    l_chr_mail_id   := l_chr_mail_temp;
                    print_line ('L',
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
                    print_line ('L',
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


    PROCEDURE mail_inv_sync_report (p_out_chr_errbuf OUT VARCHAR2, p_out_chr_retcode OUT VARCHAR2, p_org_code IN VARCHAR2)
    IS
        CURSOR cur_inv_sync_records (g_num_request_id IN NUMBER)
        IS
            SELECT mp.organization_code,                      /*MAIL_COLUMNS*/
                                         l.sku_code, l.brand,     --CCR0007323
                   l.subinventory_code, l.inventory_item_id, l.upc_code,
                   l.quantity, l.ebs_onhand_qty, DECODE (l.quantity, l.ebs_onhand_qty, 'Y', 'N') onhand_match,
                   (ebs_ship_pend_qty + ebs_ship_err_qty + ebs_rma_pend_qty + ebs_rma_err_qty + ebs_asn_pend_qty + ebs_asn_err_qty + ebs_adj_pend_qty + ebs_adj_err_qty + ebs_3pl_stg_err_qty) ebs_interface_qty, (NVL (l.quantity, 0) - NVL (ebs_onhand_qty, 0) - NVL (ebs_ship_pend_qty, 0) - NVL (ebs_ship_err_qty, 0) - NVL (ebs_rma_pend_qty, 0) - NVL (ebs_rma_err_qty, 0) - NVL (ebs_asn_pend_qty, 0) - NVL (ebs_asn_err_qty, 0) - NVL (ebs_adj_pend_qty, 0) - NVL (ebs_adj_err_qty, 0) - NVL (ebs_3pl_stg_err_qty, 0)) difference, ebs_ship_pend_qty,
                   ebs_ship_err_qty, ebs_rma_pend_qty, ebs_rma_err_qty,
                   ebs_asn_pend_qty, ebs_asn_err_qty, ebs_adj_pend_qty,
                   ebs_adj_err_qty, ebs_3pl_stg_err_qty
              FROM xxdo.xxdo_wms_3pl_ohr_h h, xxdo.xxdo_wms_3pl_ohr_l l, apps.mtl_parameters mp
             WHERE     h.ohr_header_id = l.ohr_header_id
                   AND CONC_REQUEST_ID = g_num_request_id
                   AND h.organization_id = mp.organization_id
                   AND mp.organization_code = p_org_code
            UNION  --Added as per the CCR #CCR0006355 by Chaithanya Chimmapudi
              SELECT DISTINCT mp.organization_code,           /*MAIL_COLUMNS*/
                                                    apps.iid_to_sku (moqd.inventory_item_id), l.brand,
                              moqd.subinventory_code, moqd.inventory_item_id, apps.iid_to_upc (moqd.inventory_item_id), --Get UPC from function CCR0007323
                              0 quantity, SUM (moqd.primary_transaction_quantity) ebs_onhand_qty, 'N' onhand_match,
                              0 ebsqty, SUM (moqd.primary_transaction_quantity) difference, 0,
                              0, 0, 0,
                              0, 0, 0,
                              0, 0
                /*   FROM apps.mtl_parameters mp,
                        apps.mtl_onhand_quantities_detail moqd,
                        xxdo.xxdo_wms_3pl_ohr_h h,
                        xxdo.xxdo_wms_3pl_ohr_l l
                  WHERE     h.ohr_header_id = l.ohr_header_id
                        AND CONC_REQUEST_ID = g_num_request_id
                        AND h.organization_id = mp.organization_id
                        AND moqd.organization_id = mp.organization_id
                        AND mp.organization_code = p_org_code
                        AND moqd.inventory_item_id = l.inventory_item_id
                        AND moqd.subinventory_code NOT IN
                               (SELECT DISTINCT l.subinventory_code
                                  FROM xxdo.XXDO_WMS_3PL_OHR_L l
                                 WHERE     ohr_header_id = h.ohr_header_id
                                       AND moqd.inventory_item_id = l.inventory_item_id)*/
                --Begin CCR0007323
                --Changed NOT IN to an outer join looking at the side where OHR is missing
                FROM apps.mtl_parameters mp,
                     inv.mtl_onhand_quantities_detail moqd,
                     (SELECT ohrh.organization_id, ohrl.*
                        FROM xxdo.xxdo_wms_3pl_ohr_h ohrh, xxdo.xxdo_wms_3pl_ohr_l ohrl
                       WHERE     ohrl.ohr_header_id = ohrh.ohr_header_id
                             AND ohrh.CONC_REQUEST_ID = g_num_request_id) l
               WHERE     1 = 1
                     AND moqd.organization_id = l.organization_id(+)
                     AND moqd.subinventory_code = l.subinventory_code(+)
                     AND moqd.organization_id = mp.organization_id
                     AND moqd.inventory_item_id = l.inventory_item_id(+)
                     AND mp.organization_code = p_org_code
                     AND l.organization_id IS NULL
            --END CCR0007323
            GROUP BY mp.organization_code, moqd.inventory_item_id, l.brand,
                     moqd.subinventory_code, moqd.inventory_item_id, l.upc_code,
                     quantity, 'N', 0,
                     0, 0, 0,
                     0, 0, 0,
                     0, 0, 0;            --End changes per the CCR #CCR0006355

        TYPE l_inv_sync_rec_tab_type IS TABLE OF cur_inv_sync_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_inv_sync_rec_tab         l_inv_sync_rec_tab_type;
        l_brand                    VARCHAR2 (50);

        l_chr_instance             VARCHAR2 (20);
        l_chr_from_mail_id         VARCHAR2 (2000);
        l_chr_to_mail_ids          VARCHAR2 (2000);
        l_num_return_value         NUMBER;
        l_chr_header_sent          VARCHAR2 (1) := 'N';
        l_exe_bulk_fetch_failed    EXCEPTION;
        l_exe_no_interface_setup   EXCEPTION;
        l_exe_mail_error           EXCEPTION;
        l_exe_instance_not_known   EXCEPTION;
    BEGIN
        print_line ('L', 'In the mail_inv_sync_report..');

        BEGIN
            SELECT NAME INTO l_chr_instance FROM v$database;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_exe_instance_not_known;
        END;

        /*
        We can create a lookup to retrieve from and to mail ids
        */
        BEGIN
            SELECT tag, description
              INTO l_chr_from_mail_id, l_chr_to_mail_ids
              FROM apps.FND_LOOKUP_VALUES
             WHERE     lookup_type = 'XXDO_3PL_INV_RECON_REPORT'
                   AND NVL (language, USERENV ('LANG')) = USERENV ('LANG')
                   AND enabled_flag = 'Y'
                   AND lookup_code = p_org_code;
        EXCEPTION
            WHEN OTHERS
            THEN
                print_line (
                    'L',
                    'Exception while fetching mail ids...' || SQLERRM);
        END;

        IF l_chr_from_mail_id IS NULL
        THEN
            l_chr_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        l_chr_to_mail_ids   := TRANSLATE (l_chr_to_mail_ids, ',', ';');

        print_line ('L', 'From Mail ID..' || l_chr_from_mail_id);
        print_line ('L', 'To Mail ID..' || l_chr_to_mail_ids);

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
                    print_line ('L', p_out_chr_errbuf);
                    RAISE l_exe_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_inv_sync_rec_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF l_chr_header_sent = 'N'
            THEN
                print_line ('L', 'Before calling send_mail_header...');

                send_mail_header (l_chr_from_mail_id, l_chr_to_mail_ids, l_chr_instance || ' - Inventory Sync Report for ' || p_org_code
                                  , l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   := 'Unable to send the mail header';
                    RAISE l_exe_mail_error;
                END IF;

                print_line ('L',
                            'Before initiating send_mail_line contents...');
                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    l_num_return_value);
                send_mail_line ('--boundarystring', l_num_return_value);
                send_mail_line ('Content-Type: text/plain',
                                l_num_return_value);
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
                       'Warehouse'
                    || CHR (9)
                    || 'Brand'                                    --CCR0007323
                    || CHR (9)
                    || 'SKU Code'
                    || CHR (9)
                    || 'Subinventory Code'
                    || CHR (9)
                    || 'UPC Code'
                    || CHR (9)
                    || '3PL Quantity'
                    || CHR (9)
                    || 'EBS OnHand Quantity'
                    || CHR (9)
                    || 'OnHand Match?'
                    || CHR (9)
                    || 'EBS Interface Quantity'
                    || CHR (9)
                    || 'Difference'
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
                    || CHR (9),
                    l_num_return_value);
                l_chr_header_sent   := 'Y';
            END IF;

            FOR l_num_ind IN l_inv_sync_rec_tab.FIRST ..
                             l_inv_sync_rec_tab.LAST
            LOOP
                --Get brand for item if NULL
                --CCR0007323
                l_brand   :=
                    NVL (
                        l_inv_sync_rec_tab (l_num_ind).brand,
                        get_brand_for_item (
                            l_inv_sync_rec_tab (l_num_ind).inventory_item_id));

                send_mail_line (
                       l_inv_sync_rec_tab (l_num_ind).organization_code
                    || CHR (9)
                    || l_brand                                    --CCR0007323
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).sku_code
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).subinventory_code
                    || CHR (9)
                    || ''''
                    || l_inv_sync_rec_tab (l_num_ind).upc_code
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).quantity
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).ebs_onhand_qty
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).onhand_match
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).ebs_interface_qty
                    || CHR (9)
                    || l_inv_sync_rec_tab (l_num_ind).difference
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
                    || CHR (9),
                    l_num_return_value);

                IF l_num_return_value <> 0
                THEN
                    p_out_chr_errbuf   :=
                        'Unable to generate the attachment file';
                    RAISE l_exe_mail_error;
                END IF;
            END LOOP;
        END LOOP;                                  -- Error headers fetch loop

        -- Close the cursor
        CLOSE cur_inv_sync_records;

        -- Close the mail connection
        send_mail_close (l_num_return_value);
    EXCEPTION
        WHEN l_exe_mail_error
        THEN
            p_out_chr_retcode   := '2';
            print_line ('L', p_out_chr_errbuf);
        WHEN l_exe_no_interface_setup
        THEN
            p_out_chr_errbuf    :=
                'No Interface setup to generate Inventory Sync report';
            p_out_chr_retcode   := '2';
            print_line ('L', p_out_chr_errbuf);
        WHEN l_exe_bulk_fetch_failed
        THEN
            p_out_chr_errbuf    :=
                'Bulk fetch failed at Inventory Sync report procedure';
            p_out_chr_retcode   := '2';
            print_line ('L', p_out_chr_errbuf);
        WHEN OTHERS
        THEN
            p_out_chr_errbuf    :=
                   'Unexpected error at Inventory Sync report procedure : '
                || SQLERRM;
            p_out_chr_retcode   := '2';
            print_line ('L', p_out_chr_errbuf);
    END mail_inv_sync_report;



    PROCEDURE main (errbuff         OUT VARCHAR2,
                    retcode         OUT VARCHAR2,
                    p_org_code   IN     VARCHAR2)
    IS
        l_ret_stat      VARCHAR2 (1);
        l_message       VARCHAR2 (2000);
        l_chr_errbuf    VARCHAR2 (2000);
        l_chr_retcode   VARCHAR2 (20);

        l_grn_qty       NUMBER;
        l_osc_qty       NUMBER;
        l_adj_qty       NUMBER;
        l_tra_qty       NUMBER;
    BEGIN
        FOR c_header
            IN (SELECT h.site_id, h.ohr_header_id, h.organization_id,
                       h.snapshot_date
                  FROM xxdo.xxdo_wms_3pl_ohr_h h
                 WHERE     h.process_status = 'S'
                       AND h.organization_id =
                           (SELECT mp.organization_id
                              FROM apps.mtl_parameters mp
                             WHERE mp.organization_code = p_org_code)
                       AND h.INV_CONCILLATION_DATE IS NULL)
        LOOP
            BEGIN
                SAVEPOINT begin_header;
                l_ret_stat   := g_ret_success;
                print_line ('L', 'In the header loop..');

                FOR c_line
                    IN (SELECT l.ohr_line_id, l.sku_code, l.inventory_item_id,
                               l.quantity, l.subinventory_code
                          FROM xxdo.xxdo_wms_3pl_ohr_l l
                         WHERE     l.ohr_header_id = c_header.ohr_header_id
                               AND l.process_status = 'S'
                               AND l.error_message = 'Processing Complete')
                LOOP
                    --Logic to verify the quantity and update the line staging table column values
                    print_line ('L', 'In the line loop..');

                    /* onhand */
                    BEGIN
                        print_line (
                            'L',
                            'Before updating Onhand quantity columns..');

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET ebs_onhand_qty   =
                                   NVL (
                                       (SELECT NVL (SUM (transaction_quantity), 0)
                                          FROM apps.mtl_onhand_quantities moqd
                                         WHERE     moqd.inventory_item_id =
                                                   c_line.inventory_item_id
                                               AND moqd.organization_id =
                                                   c_header.organization_id
                                               AND moqd.subinventory_code =
                                                   c_line.subinventory_code),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;
                    --Added as per the CCR #CCR0006355 by Chaithanya Chimmapudi

                    /*UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                    SET ebs_qty_other_subinvs = NVL ( (SELECT SUM (primary_transaction_quantity)
                                                        FROM apps.mtl_onhand_quantities_detail moqd
                                                        WHERE organization_id = c_header.organization_id
                                                        AND moqd.inventory_item_id = c_line.inventory_item_id
                                                        AND moqd.subinventory_code NOT IN
                                                                            (SELECT DISTINCT l.subinventory_code
                                                                            FROM     xxdo.XXDO_WMS_3PL_OHR_L l
                                                                            WHERE    ohr_header_id = c_header.ohr_header_id
                                                                            AND     moqd.inventory_item_id = l.inventory_item_id)
                                                                            ),
                                                        0)
                    WHERE ohr_line_id = c_line.ohr_line_id;
                    --End for CCR0006355
                    */
                    --print_line ('L','STG table Onhand columns updated..');

                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_line (
                                'L',
                                   'Excpetion, updating Onhand quantity..'
                                || SQLERRM);
                            ROLLBACK TO begin_header;
                    END;


                    /* ship pending and error quantities */
                    print_line (
                        'L',
                        'Before updating Ship Pending/Error quantity columns..');

                    BEGIN
                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_SHIP_PEND_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (transaction_quantity), 0)
                                          FROM apps.mtl_transactions_interface mti
                                         WHERE     mti.inventory_item_id =
                                                   c_line.inventory_item_id
                                               AND mti.organization_id =
                                                   c_header.organization_id
                                               AND mti.subinventory_code =
                                                   c_line.subinventory_code
                                               AND mti.ERROR_CODE IS NULL -- Pending status
                                               AND mti.transaction_date <=
                                                   c_header.snapshot_date
                                               AND mti.transaction_type_id IN
                                                       (SELECT DISTINCT
                                                               mtt.transaction_type_id
                                                          FROM apps.mtl_transaction_types mtt
                                                         WHERE     UPPER (
                                                                       mtt.transaction_type_name) LIKE
                                                                       '%ORDER%'
                                                               AND mtt.disable_date
                                                                       IS NULL)),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_SHIP_ERR_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (transaction_quantity), 0)
                                          FROM apps.mtl_transactions_interface mti
                                         WHERE     mti.inventory_item_id =
                                                   c_line.inventory_item_id
                                               AND mti.organization_id =
                                                   c_header.organization_id
                                               AND mti.subinventory_code =
                                                   c_line.subinventory_code
                                               AND mti.ERROR_CODE IS NOT NULL -- Error status
                                               AND mti.transaction_date <=
                                                   c_header.snapshot_date
                                               AND mti.transaction_type_id IN
                                                       (SELECT DISTINCT
                                                               mtt.transaction_type_id
                                                          FROM apps.mtl_transaction_types mtt
                                                         WHERE     UPPER (
                                                                       mtt.transaction_type_name) LIKE
                                                                       '%ORDER%'
                                                               AND mtt.disable_date
                                                                       IS NULL)),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_line (
                                'L',
                                   'Excpetion, updating Ship Pending/Error quantity..'
                                || SQLERRM);
                            ROLLBACK TO begin_header;
                    END;

                    /* RMA pending and error */
                    BEGIN
                        print_line (
                            'L',
                            'Before updating RMA Pending/Error columns..');

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_RMA_PEND_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (quantity), 0)
                                          FROM apps.rcv_transactions_interface rti
                                         WHERE     rti.item_id =
                                                   c_line.inventory_item_id
                                               AND rti.to_organization_id =
                                                   c_header.organization_id
                                               AND rti.subinventory =
                                                   c_line.subinventory_code
                                               AND rti.transaction_status_code =
                                                   'PENDING' -- Pending status
                                               AND rti.source_document_code =
                                                   'RMA'
                                               AND rti.transaction_date <=
                                                   c_header.snapshot_date),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_RMA_ERR_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (quantity), 0)
                                          FROM apps.rcv_transactions_interface rti
                                         WHERE     rti.item_id =
                                                   c_line.inventory_item_id
                                               AND rti.to_organization_id =
                                                   c_header.organization_id
                                               AND rti.subinventory =
                                                   c_line.subinventory_code
                                               AND rti.transaction_status_code =
                                                   'ERROR'   -- Pending status
                                               AND rti.source_document_code =
                                                   'RMA'
                                               AND rti.transaction_date <=
                                                   c_header.snapshot_date),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_line (
                                'L',
                                   'Excpetion, updating RMA Pending/Error quantity..'
                                || SQLERRM);
                            ROLLBACK TO begin_header;
                    END;

                    /* ASN pending and error */
                    BEGIN
                        print_line (
                            'L',
                            'Before updating ASN Pending/Error columns..');

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_ASN_PEND_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (quantity), 0)
                                          FROM apps.rcv_transactions_interface rti
                                         WHERE     rti.item_id =
                                                   c_line.inventory_item_id
                                               AND rti.to_organization_id =
                                                   c_header.organization_id
                                               AND rti.subinventory =
                                                   c_line.subinventory_code
                                               AND rti.transaction_status_code =
                                                   'PENDING' -- Pending status
                                               AND rti.source_document_code =
                                                   'PO'
                                               AND rti.transaction_date <=
                                                   c_header.snapshot_date),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_ASN_ERR_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (quantity), 0)
                                          FROM apps.rcv_transactions_interface rti
                                         WHERE     rti.item_id =
                                                   c_line.inventory_item_id
                                               AND rti.to_organization_id =
                                                   c_header.organization_id
                                               AND rti.subinventory =
                                                   c_line.subinventory_code
                                               AND rti.transaction_status_code =
                                                   'ERROR'   -- Pending status
                                               AND rti.source_document_code =
                                                   'PO'
                                               AND rti.transaction_date <=
                                                   c_header.snapshot_date),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_line (
                                'L',
                                   'Excpetion, updating ASN Pending/Error quantity..'
                                || SQLERRM);
                            ROLLBACK TO begin_header;
                    END;

                    /* Inventory Adjustment/transfer pending and error quantities */
                    BEGIN
                        print_line (
                            'L',
                            'Before updating Adjustment/Transfer Pending/Error columns..');

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_ADJ_PEND_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (transaction_quantity), 0)
                                          FROM apps.mtl_transactions_interface mti
                                         WHERE     mti.inventory_item_id =
                                                   c_line.inventory_item_id
                                               AND mti.organization_id =
                                                   c_header.organization_id
                                               AND mti.subinventory_code =
                                                   c_line.subinventory_code
                                               AND mti.ERROR_CODE IS NULL -- Pending status
                                               AND mti.transaction_date <=
                                                   c_header.snapshot_date
                                               AND mti.transaction_type_id IN
                                                       (SELECT DISTINCT
                                                               mtt.transaction_type_id
                                                          FROM apps.mtl_transaction_types mtt
                                                         WHERE mtt.transaction_type_id IN
                                                                   (1, 2, 4,
                                                                    5, 31, 32,
                                                                    40, 41, 42))),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_ADJ_ERR_QTY   =
                                   NVL (
                                       (SELECT NVL (SUM (transaction_quantity), 0)
                                          FROM apps.mtl_transactions_interface mti
                                         WHERE     mti.inventory_item_id =
                                                   c_line.inventory_item_id
                                               AND mti.organization_id =
                                                   c_header.organization_id
                                               AND mti.subinventory_code =
                                                   c_line.subinventory_code
                                               AND mti.ERROR_CODE IS NOT NULL -- Error status
                                               AND mti.transaction_date <=
                                                   c_header.snapshot_date
                                               AND mti.transaction_type_id IN
                                                       (SELECT DISTINCT
                                                               mtt.transaction_type_id
                                                          FROM apps.mtl_transaction_types mtt
                                                         WHERE mtt.transaction_type_id IN
                                                                   (1, 2, 4,
                                                                    5, 31, 32,
                                                                    40, 41, 42))),
                                       0)
                         WHERE ohr_line_id = c_line.ohr_line_id;
                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_line (
                                'L',
                                   'Excpetion, updating Adjustment/Transfer Pending/Error quantity..'
                                || SQLERRM);
                            ROLLBACK TO begin_header;
                    END;


                    --For 3PL STG table data
                    --Begin CCR0007323
                    BEGIN
                        print_line (
                            'L',
                            'Before updating 3PL STG TABLE Pending/Error columns..');

                        BEGIN
                            SELECT NVL (SUM (qty_received), 0)
                              INTO l_grn_qty
                              FROM xxdo.xxdo_wms_3pl_grn_h h, xxdo.xxdo_wms_3pl_grn_l l
                             WHERE     h.grn_header_id = l.grn_header_id
                                   AND h.organization_id =
                                       c_header.organization_id
                                   AND h.site_id = c_header.site_id
                                   AND l.inventory_item_id =
                                       c_line.inventory_item_id
                                   AND l.subinventory_code =
                                       c_line.subinventory_code
                                   AND h.process_status IN ('P', 'E')
                                   AND h.receiving_date <=
                                       c_header.snapshot_date;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_grn_qty   := 0;
                        END;

                        print_line ('L', 'GRN QTY : ' || l_grn_qty);

                        BEGIN
                            SELECT NVL (SUM (qty_shipped), 0)
                              INTO l_osc_qty
                              FROM xxdo.xxdo_wms_3pl_osc_h h, xxdo.xxdo_wms_3pl_osc_l l
                             WHERE     h.osc_header_id = l.osc_header_id
                                   AND h.organization_id =
                                       c_header.organization_id
                                   AND h.site_id = c_header.site_id
                                   AND l.inventory_item_id =
                                       c_line.inventory_item_id
                                   --and     l.subinventory_code = c_line.subinventory_code
                                   AND h.process_status IN ('P', 'E')
                                   AND h.ship_confirm_date <=
                                       c_header.snapshot_date;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_osc_qty   := 0;
                        END;

                        print_line ('L', 'OSC QTY : ' || l_osc_qty);

                        BEGIN
                            SELECT NVL (SUM (qty_change), 0)
                              INTO l_adj_qty
                              FROM xxdo.xxdo_wms_3pl_adj_h h, xxdo.xxdo_wms_3pl_adj_l l
                             WHERE     h.adj_header_id = l.adj_header_id
                                   AND h.organization_id =
                                       c_header.organization_id
                                   AND h.site_id = c_header.site_id
                                   AND l.inventory_item_id =
                                       c_line.inventory_item_id
                                   AND l.subinventory_code =
                                       c_line.subinventory_code
                                   AND h.process_status IN ('P', 'E')
                                   AND h.adjust_date <=
                                       c_header.snapshot_date;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_adj_qty   := 0;
                        END;

                        print_line ('L', 'ADJ QTY : ' || l_adj_qty);

                        BEGIN
                            SELECT NVL (SUM (qty_change), 0)
                              INTO l_tra_qty
                              FROM xxdo.xxdo_wms_3pl_tra_h h, xxdo.xxdo_wms_3pl_tra_l l
                             WHERE     h.tra_header_id = l.tra_header_id
                                   AND h.organization_id =
                                       c_header.organization_id
                                   AND h.site_id = c_header.site_id
                                   AND l.inventory_item_id =
                                       c_line.inventory_item_id
                                   AND (l.from_subinventory_code = c_line.subinventory_code OR l.to_subinventory_code = c_line.subinventory_code)
                                   AND h.process_status IN ('P', 'E')
                                   AND h.xfer_date <= c_header.snapshot_date;
                        EXCEPTION
                            WHEN OTHERS
                            THEN
                                l_tra_qty   := 0;
                        END;

                        print_line ('L', 'TRA QTY : ' || l_tra_qty);

                        UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                           SET EBS_3PL_STG_ERR_QTY = NVL (l_grn_qty + l_osc_qty + l_adj_qty + l_tra_qty, 0)
                         WHERE ohr_line_id = c_line.ohr_line_id;

                        print_line (
                            'L',
                               'Sum to stg : '
                            || NVL (
                                     l_grn_qty
                                   + l_osc_qty
                                   + l_adj_qty
                                   + l_tra_qty,
                                   0));
                    --End CCR0007323

                    --Commented out per CCR0007323
                    /*  UPDATE xxdo.xxdo_wms_3pl_ohr_l x
                         SET EBS_3PL_STG_ERR_QTY =
                                (SELECT   (SELECT NVL (SUM (qty_received), 0)
                                             FROM xxdo.xxdo_wms_3pl_grn_h h,
                                                  xxdo.xxdo_wms_3pl_grn_l l
                                            WHERE     h.grn_header_id =
                                                         l.grn_header_id
                                                  AND h.organization_id =
                                                         c_header.organization_id
                                                  AND h.site_id =
                                                         c_header.site_id
                                                  AND l.inventory_item_id =
                                                         c_line.inventory_item_id
                                                  AND l.subinventory_code =
                                                         c_line.subinventory_code
                                                  AND h.process_status IN
                                                         ('P', 'E')
                                                  AND h.receiving_date <=
                                                         c_header.snapshot_date)
                                        + (SELECT NVL (SUM (qty_shipped), 0)
                                             FROM xxdo.xxdo_wms_3pl_osc_h h,
                                                  xxdo.xxdo_wms_3pl_osc_l l
                                            WHERE     h.osc_header_id =
                                                         l.osc_header_id
                                                  AND h.organization_id =
                                                         c_header.organization_id
                                                  AND h.site_id =
                                                         c_header.site_id
                                                  AND l.inventory_item_id =
                                                         c_line.inventory_item_id
                                                  --and     l.subinventory_code = c_line.subinventory_code
                                                  AND h.process_status IN
                                                         ('P', 'E')
                                                  AND h.ship_confirm_date <=
                                                         c_header.snapshot_date)
                                        + (SELECT NVL (SUM (qty_change), 0)
                                             FROM xxdo.xxdo_wms_3pl_adj_h h,
                                                  xxdo.xxdo_wms_3pl_adj_l l
                                            WHERE     h.adj_header_id =
                                                         l.adj_header_id
                                                  AND h.organization_id =
                                                         c_header.organization_id
                                                  AND h.site_id =
                                                         c_header.site_id
                                                  AND l.inventory_item_id =
                                                         c_line.inventory_item_id
                                                  AND l.subinventory_code =
                                                         c_line.subinventory_code
                                                  AND h.process_status IN
                                                         ('P', 'E')
                                                  AND h.adjust_date <=
                                                         c_header.snapshot_date)
                                        + (SELECT NVL (SUM (qty_change), 0)
                                             FROM xxdo.xxdo_wms_3pl_tra_h h,
                                                  xxdo.xxdo_wms_3pl_tra_l l
                                            WHERE     h.tra_header_id =
                                                         l.tra_header_id
                                                  AND h.organization_id =
                                                         c_header.organization_id
                                                  AND h.site_id =
                                                         c_header.site_id
                                                  AND l.inventory_item_id =
                                                         c_line.inventory_item_id
                                                  AND (   l.from_subinventory_code =
                                                             c_line.subinventory_code
                                                       OR l.to_subinventory_code =
                                                             c_line.subinventory_code)
                                                  AND h.process_status IN
                                                         ('P', 'E')
                                                  AND h.xfer_date <=
                                                         c_header.snapshot_date)
                                   FROM DUAL)
                       WHERE ohr_line_id = c_line.ohr_line_id;*/

                    --COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            print_line (
                                'L',
                                   'Exception, updating 3PL STG TABLE Pending/Error quantity..'
                                || SQLERRM);
                            ROLLBACK TO begin_header;
                    END;

                    print_line (
                        'L',
                        'STG Table Quantity columns are updated successfully..');
                END LOOP;                                    -- End for c_line
            EXCEPTION
                WHEN OTHERS
                THEN
                    l_ret_stat   := g_ret_unexp_error;
                    l_message    := SQLERRM;
            END;

            BEGIN
                UPDATE xxdo.xxdo_wms_3pl_ohr_h
                   SET CONC_REQUEST_ID = g_num_request_id, INV_CONCILLATION_DATE = SYSDATE
                 WHERE ohr_header_id = c_header.ohr_header_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_line (
                        'L',
                           'Excpetion, updating 3PL STG Header Table..'
                        || SQLERRM);
                    ROLLBACK TO begin_header;
            END;
        END LOOP;                                           --end for c_header

        /*MAIL_REPORT - BEGIN*/
        BEGIN
            print_line ('L',
                        'Calling procedure to send Inventory Sync Report: ');
            print_line ('L', 'Request ID :' || g_num_request_id);
            mail_inv_sync_report (l_chr_errbuf, l_chr_retcode, p_org_code);
        EXCEPTION
            WHEN OTHERS
            THEN
                errbuff   :=
                    'Unable to get the inteface setup due to ' || SQLERRM;
                retcode   := '2';
                print_line ('L', errbuff);
        END;
    /*MAIL_REPORT - END*/

    EXCEPTION
        WHEN OTHERS
        THEN
            print_line ('L', 'Error occurred in main procedure-' || SQLERRM);
    END;                                                                --main
END XXDO_3PL_INV_SYNC;
/
