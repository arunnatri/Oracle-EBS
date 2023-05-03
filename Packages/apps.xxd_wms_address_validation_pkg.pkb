--
-- XXD_WMS_ADDRESS_VALIDATION_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WMS_ADDRESS_VALIDATION_PKG"
AS
    /****************************************************************************************
       * Change#      : CCR0007832 - Ship Confirm Interface Redesign(HJ to EBS)
       * Package      : XXD_WMS_ADDRESS_VALIDATION_PKG
       * Description  : This is package validates the Ship-To address in Pick ticket interface
       *                staging tables with ship confirm interface staging tables and sends
       *                notification
       * Notes        :
       * Modification :
       -- ===========  ========    ======================= =====================================
       -- Date         Version#    Name                    Comments
       -- ===========  ========    ======================= =======================================
       -- 29-Jun-2019  1.0         Kranthi Bollam          Initial Version
       --
       -- ===========  ========    ======================= =======================================
       ******************************************************************************************/

    --Global Variables
    gv_addr_corr_report_name   CONSTANT VARCHAR2 (30)
                                            := 'XXDO_ADDR_CORR_REPORT' ;
    gn_connection_flag                  NUMBER := 0;
    g_smtp_connection                   UTL_SMTP.connection := NULL;

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
        IF gn_connection_flag <> 0
        THEN
            RAISE l_exe_conn_already_open;
        END IF;

        g_smtp_connection    := UTL_SMTP.open_connection ('127.0.0.1');
        gn_connection_flag   := 1;
        l_num_status         := 1;
        UTL_SMTP.helo (g_smtp_connection, 'localhost');
        UTL_SMTP.mail (g_smtp_connection, p_in_chr_msg_from);


        l_chr_mail_temp      := TRIM (p_in_chr_msg_to);

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


        l_chr_msg_to         :=
            '  ' || TRANSLATE (TRIM (p_in_chr_msg_to), ';', ' ');


        UTL_SMTP.open_data (g_smtp_connection);
        l_num_status         := 2;
        UTL_SMTP.write_data (g_smtp_connection,
                             'To: ' || l_chr_msg_to || UTL_TCP.CRLF);
        UTL_SMTP.write_data (g_smtp_connection,
                             'From: ' || p_in_chr_msg_from || UTL_TCP.CRLF);
        UTL_SMTP.write_data (
            g_smtp_connection,
            'Subject: ' || p_in_chr_msg_subject || UTL_TCP.CRLF);

        p_out_num_status     := 0;
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

            gn_connection_flag   := 0;
            p_out_num_status     := -255;
    END send_mail_header;


    PROCEDURE send_mail_line (p_in_chr_msg_text   IN     VARCHAR2,
                              p_out_num_status       OUT NUMBER)
    IS
        l_exe_not_connected   EXCEPTION;
    BEGIN
        IF gn_connection_flag = 0
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
        IF gn_connection_flag = 0
        THEN
            RAISE l_exe_not_connected;
        END IF;

        UTL_SMTP.close_data (g_smtp_connection);
        UTL_SMTP.quit (g_smtp_connection);

        gn_connection_flag   := 0;
        p_out_num_status     := 0;
    EXCEPTION
        WHEN l_exe_not_connected
        THEN
            p_out_num_status   := 0;
        WHEN OTHERS
        THEN
            p_out_num_status     := -255;
            gn_connection_flag   := 0;
    END send_mail_close;

    -- ***************************************************************************
    -- Procedure Name      : address_correction
    -- Description         : Procedure creates report if any disccrpeancies are found in the
    --                       order address details
    --
    -- Parameters          : pv_errbuf           OUT : Error message
    --                       pv_retcode          OUT : Execution status
    --                       pv_customer_code    IN  : Customer Number
    --
    -- Return/Exit         :  none
    --
    -- DEVELOPMENT and MAINTENANCE HISTORY
    --
    -- date          author              Version Description
    -- ------------  -----------------   ------- --------------------------------
    -- 2014/06/29    Kranthi Bollam      1.0     Initial Version.
    --
    -- ***************************************************************************
    PROCEDURE address_correction (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_customer_code IN VARCHAR2)
    IS
        --Local Variables Declaration
        lv_rowid                  ROWID;
        lv_from_mail_id           VARCHAR2 (2000);
        lv_to_mail_ids            VARCHAR2 (2000);
        lv_report_last_run_time   VARCHAR2 (60);
        ld_report_last_run_time   DATE;
        ln_return_value           NUMBER;
        lv_header_sent            VARCHAR2 (1) := 'N';
        lv_instance               VARCHAR2 (100);

        --Exceptions Declaration
        l_ex_bulk_fetch_failed    EXCEPTION;
        l_ex_no_interface_setup   EXCEPTION;
        l_ex_mail_error           EXCEPTION;
        l_ex_instance_not_known   EXCEPTION;

        CURSOR cur_error_records IS
              SELECT DISTINCT ph.customer_code cust_num, ph.customer_name cust_name, ph.warehouse_code wh_code,
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
                         NVL (pv_customer_code, ph.customer_code)
            ORDER BY cust_num, ord_num;

        TYPE l_error_records_tab_type IS TABLE OF cur_error_records%ROWTYPE
            INDEX BY BINARY_INTEGER;

        l_error_records_tab       l_error_records_tab_type;
    BEGIN
        pv_errbuf        := NULL;
        pv_retcode       := '0';
        fnd_file.put_line (fnd_file.LOG, '');

        -- Get the instance name - it will be shown in the report
        BEGIN
            SELECT instance_name INTO lv_instance FROM v$instance;
        EXCEPTION
            WHEN OTHERS
            THEN
                RAISE l_ex_instance_not_known;
        END;

        -- Derive the last report run time, FROM email id and TO email ids
        BEGIN
            SELECT flv.ROWID row_id, flv.attribute10 from_email_id, flv.attribute11 to_email_ids,
                   flv.attribute13 report_last_run_time
              INTO lv_rowid, lv_from_mail_id, lv_to_mail_ids, lv_report_last_run_time
              FROM fnd_lookup_values flv
             WHERE     flv.language = 'US'
                   AND flv.lookup_type = 'XXDO_WMS_INTERFACES_SETUP'
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code = gv_addr_corr_report_name;
        EXCEPTION
            WHEN OTHERS
            THEN
                FND_FILE.PUT_LINE (
                    FND_FILE.LOG,
                    'Unable to get the inteface setup due to ' || SQLERRM);
                RAISE l_ex_no_interface_setup;
        END;


        -- Convert the FROM email id instance specific
        IF lv_from_mail_id IS NULL
        THEN
            lv_from_mail_id   := 'WMSInterfacesErrorReporting@deckers.com';
        END IF;

        -- Replace comma with semicolon in TO Ids

        lv_to_mail_ids   := TRANSLATE (lv_to_mail_ids, ',', ';');

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

                    pv_errbuf   :=
                           'Unexcepted error in BULK Fetch of Ship confirm address records : '
                        || SQLERRM;
                    fnd_file.put_line (fnd_file.LOG, pv_errbuf);
                    RAISE l_ex_bulk_fetch_failed;
            END;                                           --end of bulk fetch

            IF NOT l_error_records_tab.EXISTS (1)
            THEN
                EXIT;
            END IF;

            IF lv_header_sent = 'N'
            THEN
                send_mail_header (lv_from_mail_id, lv_to_mail_ids, lv_instance || ' - Address Correction Report'
                                  , ln_return_value);

                IF ln_return_value <> 0
                THEN
                    pv_errbuf   := 'Unable to send the mail header';
                    RAISE l_ex_mail_error;
                END IF;

                send_mail_line (
                    'Content-Type: multipart/mixed; boundary=boundarystring',
                    ln_return_value);
                send_mail_line ('--boundarystring', ln_return_value);
                send_mail_line ('Content-Type: text/plain', ln_return_value);

                send_mail_line ('', ln_return_value);
                send_mail_line (
                       'Please refer the attached file for details of address discrepancies occurred in '
                    || lv_instance
                    || '.',
                    ln_return_value);
                send_mail_line ('', ln_return_value);

                send_mail_line ('--boundarystring', ln_return_value);

                send_mail_line ('Content-Type: text/xls', ln_return_value);
                send_mail_line (
                    'Content-Disposition: attachment; filename="Address_correction_report.xls"',
                    ln_return_value);
                send_mail_line ('--boundarystring', ln_return_value);


                send_mail_line (
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
                    || 'Shipment - Country'
                    || CHR (9),
                    ln_return_value);

                lv_header_sent   := 'Y';
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
                        || CHR (9)
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
                        ln_return_value);

                    IF ln_return_value <> 0
                    THEN
                        pv_errbuf   :=
                            'Unable to generate the attachment file';
                        RAISE l_ex_mail_error;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.output,
                           l_error_records_tab (l_num_ind).cust_num
                        || CHR (9)
                        || l_error_records_tab (l_num_ind).cust_name
                        || CHR (9)
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
                       SET sco.address_verified   = 'REPORTED'
                     WHERE     sco.address_verified IN ('NOT VERIFIED', 'N')
                           AND sco.wh_id =
                               l_error_records_tab (l_num_ind).wh_code
                           AND sco.order_number =
                               l_error_records_tab (l_num_ind).ord_num;
                ELSE
                    UPDATE xxdo_ont_ship_conf_order_stg sco
                       SET sco.address_verified   = 'VERIFIED'
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
        send_mail_close (ln_return_value);

        IF ln_return_value <> 0
        THEN
            pv_errbuf   := 'Unable to close the mail connection';
            RAISE l_ex_mail_error;
        END IF;
    EXCEPTION
        WHEN l_ex_mail_error
        THEN
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        WHEN l_ex_no_interface_setup
        THEN
            pv_errbuf    :=
                'No Interface setup to generate Address Correction report';
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        WHEN l_ex_bulk_fetch_failed
        THEN
            pv_errbuf    :=
                'Bulk fetch failed at Address Correction report procedure';
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        WHEN l_ex_instance_not_known
        THEN
            pv_errbuf    := 'Unable to derive the instance';
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
        WHEN OTHERS
        THEN
            pv_errbuf    :=
                   'Unexpected error at Address Correction report procedure : '
                || SQLERRM;
            pv_retcode   := '2';
            fnd_file.put_line (fnd_file.LOG, pv_errbuf);
    END address_correction;
END xxd_wms_address_validation_pkg;
/
