--
-- XXDO_WMS_3PL_DEMAND_CONS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:11 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_3PL_DEMAND_CONS_PKG"
AS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_WMS_3PL_DEMAND_CONS_PKG.pkb
    * Language     : PL/SQL
    * Description  : This package is used for process the Ecommerce transactions(Sales Order/Returns).
    *                   It will Convert Ecommerce material transactions (Sales and Returns)  to Sales Order(s)
    *                   Once Create the SOs, it will do
    *                    1. Auto Pick Release and Ship confirm of Ecommerce Orders.
    *                    2. Auto Receipt of Ecommerce Return Orders lines
    *                    3. Updating Transactions status of Adjustment records
    *                    4. Generate Oracle PL/SQL Alert for Exception Notification
    * History      :
    * This is copy from the original package XXDO_WMS_3PL_ADJ_CONV_PKG
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 10-Mar-2018  1.0        Viswanathan Pandian     Initial Version
    -- 28-Dec-2020  1.1        Viswanathan Pandian     Changes for CCR0008983
    -- 23-Jul-2021  1.2        Damodara Gupta          Changes for CCR0009333
    -- 04-Jan-2022  1.3        Shivanshu Talwar        Changes for CCR0009736 - OM: Grouping Issue on China eComm Order creation
    *****************************************************************************************/
    PROCEDURE write_log (p_mesg IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_mesg);
        DBMS_OUTPUT.put_line ('p_mesg' || p_mesg);
    END write_log;

    PROCEDURE write_output (p_mesg IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_mesg);
    END write_output;

    FUNCTION email_recips (p_email IN VARCHAR2)
        RETURN do_mail_utils.tbl_recips
    IS
        v_def_mail_recips   do_mail_utils.tbl_recips;
        l_differentiator    VARCHAR2 (10) := ',';
    BEGIN
        v_def_mail_recips.delete;

        BEGIN
            IF p_email IS NOT NULL
            THEN
                FOR i IN 1 ..
                           LENGTH (p_email)
                         - LENGTH (REPLACE (p_email, ',', ''))
                         + 1
                LOOP
                    v_def_mail_recips (i)   :=
                        SUBSTR (
                            l_differentiator || p_email || l_differentiator,
                              INSTR (l_differentiator || p_email || l_differentiator, l_differentiator, 1
                                     , i)
                            + 1,
                              INSTR (l_differentiator || p_email || l_differentiator, l_differentiator, 1
                                     , i + 1)
                            - INSTR (l_differentiator || p_email || l_differentiator, l_differentiator, 1
                                     , i)
                            - 1);

                    apps.fnd_file.put_line (
                        apps.fnd_file.LOG,
                           'Email Addresses  in function '
                        || v_def_mail_recips (i));
                END LOOP;
            END IF;

            RETURN v_def_mail_recips;
        END;
    END email_recips;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : create_sales_order
    -- Decription                : Invoke Order Import with Order Source
    --                             Once done Update the statge tables.
    -----------------------------------------------------------------------------------
    PROCEDURE create_sales_order (x_errbuf             OUT VARCHAR2,
                                  x_retcode            OUT VARCHAR2,
                                  p_order_source    IN     NUMBER,
                                  p_order_type_id   IN     NUMBER,
                                  -- Start changes for CCR0009333
                                  p_num_instances   IN     NUMBER)
    -- End changes for CCR0009333
    IS
        lv_request_num       NUMBER;

        TYPE gv_child_req_id IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lv_child_req_id      gv_child_req_id;
        lv_def_org_id        NUMBER := mo_utils.get_default_org_id;
        lv_message           VARCHAR2 (2000);
        lb_wait              BOOLEAN;
        lv_phase             VARCHAR2 (80);
        lv_status            VARCHAR2 (80);
        lv_dev_phase         VARCHAR2 (30);
        lv_dev_status        VARCHAR2 (30);
        lv_org_id            NUMBER := gn_org_id;
        lv_adj_line_id       gt_adj_line_id_tbl;
        lv_order_type_name   oe_transaction_types_vl.name%TYPE;
        ln_order_type_id     oe_headers_iface_all.order_type_id%TYPE;
    BEGIN
        --Invoke the Order Import concurrent program.
        BEGIN
            write_log (
                '**------------------------------------------------------**');
            write_log ('Inside Procedure create_sales_order_prc');
            write_log ('--2.1 Submit Request "Order Import"');
            write_log ('-- Input Parameter: ');
            write_log ('p_order_source: ' || p_order_source);
            write_log ('p_order_type_id: ' || p_order_type_id);
            lv_request_num   :=
                fnd_request.submit_request (application   => 'ONT',
                                            program       => 'OEOIMP',
                                            description   => 'Order Import',
                                            start_time    => SYSDATE,
                                            argument1     => lv_org_id,
                                            argument2     => p_order_source,
                                            argument3     => NULL,
                                            argument4     => NULL,
                                            argument5     => 'N',
                                            argument6     => '1', --Debug Level
                                            -- Start changes for CCR0009333
                                            -- argument7     => '4',
                                            argument7     => p_num_instances,
                                            -- End changes for CCR0009333
                                            argument8     => NULL,
                                            argument9     => NULL,
                                            argument10    => NULL,
                                            argument11    => 'Y',
                                            argument12    => 'N',
                                            argument13    => 'Y',
                                            argument14    => lv_def_org_id,
                                            argument15    => 'Y',
                                            argument16    => CHR (0));
            COMMIT;
            write_log ('Order Import Request Id:' || lv_request_num);

            IF lv_request_num > 0
            THEN
                LOOP
                    lb_wait   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => lv_request_num,
                            interval     => 1,
                            max_wait     => 200,
                            phase        => lv_phase,
                            status       => lv_status,
                            dev_phase    => lv_dev_phase,
                            dev_status   => lv_dev_status,
                            MESSAGE      => lv_message);

                    IF ((UPPER (lv_dev_phase) = 'COMPLETE') OR (UPPER (lv_phase) = 'COMPLETED'))
                    THEN
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            BEGIN
                SELECT DISTINCT ott.transaction_type_id, ott.name
                  INTO ln_order_type_id, lv_order_type_name
                  FROM oe_transaction_types_vl ott, oe_transaction_types_all ota, apps.fnd_lookup_values_vl flv
                 WHERE     ott.name = flv.attribute1
                       AND flv.lookup_type = gc_order_mapping
                       AND flv.enabled_flag = 'Y'
                       AND ott.transaction_type_id = ota.transaction_type_id
                       AND ota.org_id = gn_org_id;

                FOR i
                    IN (SELECT DISTINCT wah.adj_header_id, wal.adj_line_id
                          FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, oe_order_headers_all ooha,
                               oe_order_lines_all oola
                         WHERE     wah.adj_header_id = wal.adj_header_id
                               AND ooha.header_id = oola.header_id
                               AND TO_CHAR (wal.adj_line_id) =
                                   oola.orig_sys_line_ref
                               AND ooha.order_type_id = ln_order_type_id
                               AND oola.ship_from_org_id =
                                   wah.organization_id
                               AND wah.process_status = 'P'
                               AND wal.process_status = 'O'
                        UNION
                        SELECT DISTINCT wah.adj_header_id, wal.adj_line_id
                          FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, oe_headers_iface_all ohia,
                               oe_lines_iface_all olia
                         WHERE     wah.adj_header_id = wal.adj_header_id
                               AND ohia.orig_sys_document_ref =
                                   olia.orig_sys_document_ref
                               AND TO_CHAR (wal.adj_line_id) =
                                   olia.orig_sys_line_ref
                               AND ohia.order_type_id = ln_order_type_id
                               AND olia.ship_from_org_id =
                                   wah.organization_id
                               AND wah.process_status = 'P'
                               AND wal.process_status = 'O')
                LOOP
                    UPDATE xxdo.xxdo_wms_3pl_adj_h wah
                       SET wah.process_status = gc_process_success, wah.error_message = 'Processing Complete'
                     WHERE adj_header_id = i.adj_header_id;


                    UPDATE xxdo.xxdo_wms_3pl_adj_l wal
                       SET wal.process_status = gc_process_success, wal.error_message = 'Processing Complete'
                     WHERE adj_header_id = i.adj_header_id;
                END LOOP;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_errbuf   := SUBSTR (SQLERRM, 1, 2000);
                    write_log (x_errbuf);
            END;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_errbuf    := SUBSTR (SQLERRM, 1, 2000);
                write_log (x_errbuf);
                x_retcode   := 1;
        END;

        BEGIN
            lv_adj_line_id.delete;

            SELECT l.orig_sys_line_ref
              BULK COLLECT INTO lv_adj_line_id
              FROM oe_order_lines_all l, oe_order_headers_all h
             WHERE     h.order_type_id = p_order_type_id
                   AND h.order_source_id = p_order_source
                   AND h.header_id = l.header_id
                   AND h.flow_status_code = 'BOOKED'
                   AND l.flow_status_code IN
                           ('AWAITING_SHIPPING', 'AWAITING_RETURN')
                   AND EXISTS
                           (SELECT 'Y'
                              FROM xxdo.xxdo_wms_3pl_adj_l ls
                             WHERE     TO_CHAR (ls.adj_line_id) =
                                       l.orig_sys_line_ref
                                   AND ls.process_status = 'O');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_adj_line_id.delete;
                write_log (
                       'Exception while get adj_line_id in Create Sales Order Prc'
                    || SQLERRM);
        END;

        IF lv_adj_line_id.COUNT > 0
        THEN
            write_log ('crt lv_adj_line_id.COUNT ' || lv_adj_line_id.COUNT);

            FOR i IN 1 .. lv_adj_line_id.COUNT
            LOOP
                write_log ('lv_adj_line_id.COUNT ' || i);
                write_log ('Updating stage tables : ' || lv_adj_line_id (i));
                updating_process_status (gc_process_import,
                                         'SO Created',
                                         lv_adj_line_id (i));
            END LOOP;
        END IF;

        BEGIN
            lv_child_req_id.delete;

            SELECT request_id
              BULK COLLECT INTO lv_child_req_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = lv_request_num;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_child_req_id.delete;
                write_log (
                       gc_package_name
                    || ': Error in Order Importing in package '
                    || SUBSTR (SQLERRM, 1, 2000));
        END;

        IF lv_child_req_id IS NOT NULL
        THEN
            FOR i IN 1 .. lv_child_req_id.COUNT
            LOOP
                FOR error_cur
                    IN (SELECT ol.orig_sys_line_ref, b.MESSAGE_TEXT
                          FROM oe_lines_iface_all ol, oe_headers_iface_all oh, oe_processing_msgs a,
                               oe_processing_msgs_vl b
                         WHERE     oh.order_source_id = ol.order_source_id
                               AND oh.orig_sys_document_ref =
                                   ol.orig_sys_document_ref
                               AND oh.order_type_id = p_order_type_id
                               AND oh.order_source_id = a.order_source_id
                               AND oh.orig_sys_document_ref =
                                   a.original_sys_document_ref
                               AND a.transaction_id = b.transaction_id
                               AND a.request_id = oh.request_id
                               AND oh.request_id = lv_child_req_id (i))
                LOOP
                    updating_process_status (
                        gc_process_error,
                        'Order Import Failed',
                        TO_NUMBER (error_cur.orig_sys_line_ref));
                    write_log (error_cur.MESSAGE_TEXT);
                END LOOP;
            END LOOP;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SUBSTR (SQLERRM, 1, 2000);
            x_retcode   := 2;
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : updating_process_status
    -- Decription                : updating the process status of stage table
    -----------------------------------------------------------------------------------
    PROCEDURE updating_process_status (p_process_status IN VARCHAR2, p_message IN VARCHAR2, p_adj_line_id IN NUMBER)
    IS
    BEGIN
        write_log (
            '**------------------------------------------------------**');
        write_log ('--1.3 updating the process status of stage table');

        IF p_process_status IS NOT NULL
        THEN
            BEGIN
                UPDATE xxdo.xxdo_wms_3pl_adj_h
                   SET process_status = p_process_status, error_message = p_message, last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 WHERE adj_header_id = (SELECT adj_header_id
                                          FROM xxdo.xxdo_wms_3pl_adj_l
                                         WHERE adj_line_id = p_adj_line_id);

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    write_log (
                           'Excception In Update Temp table :'
                        || SUBSTR (SQLERRM, 1, 2000));
            END;

            BEGIN
                UPDATE xxdo.xxdo_wms_3pl_adj_l
                   SET process_status = p_process_status, error_message = p_message, last_updated_by = gn_user_id,
                       last_update_date = SYSDATE
                 WHERE adj_line_id = p_adj_line_id;

                COMMIT;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ROLLBACK;
                    write_log (
                           'Excception In Update Temp table :'
                        || SUBSTR (SQLERRM, 1, 2000));
            END;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            write_log (
                   'Excception In Update Temp table :'
                || SUBSTR (SQLERRM, 1, 2000));
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : book_order
    -- Decription                : Using API to Book Sales Orders.
    -----------------------------------------------------------------------------------
    PROCEDURE book_order (p_order_source_id   IN NUMBER,
                          p_order_type_id     IN NUMBER)
    IS
        CURSOR order_header_details (lv_org_id IN NUMBER, lv_order_source_id IN NUMBER, lv_order_type_id IN NUMBER)
        IS
            SELECT DISTINCT oh.header_id
              FROM oe_order_headers_all oh, oe_order_lines_all ol
             WHERE     oh.org_id = lv_org_id
                   AND oh.order_type_id = lv_order_type_id
                   AND oh.order_source_id = lv_order_source_id
                   AND oh.flow_status_code = 'ENTERED'
                   AND ol.header_id = oh.header_id
                   AND ol.org_id = oh.org_id
                   AND ol.flow_status_code = 'ENTERED'
                   AND EXISTS
                           (SELECT l.adj_line_id
                              FROM xxdo.xxdo_wms_3pl_adj_l l
                             WHERE     TO_CHAR (l.adj_line_id) =
                                       ol.orig_sys_line_ref
                                   AND l.process_status = 'O');

        CURSOR line_book_status_upt (p_header_id IN NUMBER)
        IS
            SELECT ol.orig_sys_line_ref
              FROM oe_order_lines_all ol
             WHERE     ol.header_id = p_header_id
                   AND ol.org_id = gn_org_id
                   AND ol.flow_status_code IN ('BOOKED', 'ENTERED')
                   AND EXISTS
                           (SELECT l.adj_line_id
                              FROM xxdo.xxdo_wms_3pl_adj_l l
                             WHERE     TO_CHAR (l.adj_line_id) =
                                       ol.orig_sys_line_ref
                                   AND l.process_status = 'O');

        ln_api_version_number          NUMBER := 1;
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
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
        lc_return_status               VARCHAR2 (10);
        ln_msg_count                   NUMBER;
        lc_msg_data                    VARCHAR2 (2000);
        l_action_request_tbl_out       oe_order_pub.request_tbl_type;
        lv_org_id                      NUMBER := gn_org_id;
    BEGIN
        write_log ('--3.1 In BOOKING Order Procedure');

        FOR i
            IN order_header_details (lv_org_id,
                                     p_order_source_id,
                                     p_order_type_id)
        LOOP
            lc_return_status                        := NULL;
            ln_msg_count                            := 0;
            lc_msg_data                             := NULL;
            l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
            l_action_request_tbl (1).entity_id      := i.header_id;
            l_action_request_tbl (1).entity_code    :=
                oe_globals.g_entity_header;
            l_action_request_tbl (1).request_type   :=
                oe_globals.g_book_order;
            l_header_rec.header_id                  := i.header_id;
            oe_order_pub.process_order (
                p_api_version_number       => ln_api_version_number,
                p_header_rec               => l_header_rec,
                p_action_request_tbl       => l_action_request_tbl,
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
                x_return_status            => lc_return_status,
                x_msg_count                => ln_msg_count,
                x_msg_data                 => lc_msg_data);

            IF lc_return_status = fnd_api.g_ret_sts_success
            THEN
                COMMIT;
                write_log ('--3.1.1 Book Order successed');
            ELSE
                write_log ('ERROR in Booking Orders--');

                FOR i IN 1 .. ln_msg_count
                LOOP
                    lc_msg_data   :=
                           lc_msg_data
                        || 'Error '
                        || i
                        || ' is: '
                        || ' '
                        || fnd_msg_pub.get (i, 'F');
                    write_log ('ERROR with' || lc_msg_data);
                END LOOP;

                ROLLBACK;
            END IF;

            FOR line_bool_upt IN line_book_status_upt (i.header_id)
            LOOP
                updating_process_status (
                    gc_process_error,
                    'Booked Error',
                    TO_NUMBER (line_bool_upt.orig_sys_line_ref));
            END LOOP;
        END LOOP;

        write_log ('End Book Order Prc');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Exception In Book Order' || SQLERRM);
    END book_order;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : rcv_orders_process_prc
    -- Decription                : Post order import process automatic receipts needs to performed
    --                             to increment inventory for all line types
    --                               of  Line Flow - Return with Receipt Only, No Credit  in Awaiting Return status.
    --                            1. Insert return orders information into RCV interface tables
    --                            2. invoking procedure 'auto_receipt_retn_orders'
    -----------------------------------------------------------------------------------
    PROCEDURE rcv_orders_process_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                      , p_order_type_id IN NUMBER)
    IS
        CURSOR cur_ret_order_info (p_order_source_id IN NUMBER, p_order_type_id IN NUMBER, p_org_id IN NUMBER)
        IS
            SELECT DISTINCT oh.sold_to_org_id customer_id,
                            oh.header_id,
                            -- Start changes for CCR0008983
                            (SELECT MIN (TRUNC (adjh.adjust_date))
                               FROM xxdo.xxdo_wms_3pl_adj_h adjh, xxdo.xxdo_wms_3pl_adj_l adjl
                              WHERE     adjh.adj_header_id =
                                        adjl.adj_header_id
                                    AND adjl.adj_line_id =
                                        ol.orig_sys_line_ref) adjust_date
              -- End changes for CCR0008983
              FROM oe_order_headers_all oh, oe_order_lines_all ol
             WHERE     oh.header_id = ol.header_id
                   AND oh.org_id = ol.org_id
                   AND oh.booked_flag = 'Y'
                   AND NVL (ol.cancelled_flag, 'N') <> 'Y'
                   AND ol.flow_status_code = 'AWAITING_RETURN'
                   AND oh.order_source_id = p_order_source_id
                   AND oh.order_type_id = p_order_type_id
                   AND oh.org_id = p_org_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM rcv_transactions_interface
                             WHERE oe_order_line_id = ol.line_id);

        CURSOR cur_ret_order_details (p_header_id   IN NUMBER,
                                      p_org_id      IN NUMBER)
        IS
            SELECT ol.header_id, ol.line_id, ol.ordered_quantity,
                   ol.subinventory, ol.inventory_item_id, ol.ship_from_org_id,
                   hou.location_id, msb.primary_unit_of_measure uom, ol.ship_to_org_id cust_site_id,
                   ol.sold_to_org_id cust_id
              FROM oe_order_lines_all ol, mtl_system_items_b msb, hr_organization_units_v hou
             WHERE     header_id = p_header_id
                   AND ol.inventory_item_id = msb.inventory_item_id
                   AND ol.ship_from_org_id = msb.organization_id
                   AND hou.organization_id = ol.ship_from_org_id
                   AND ol.flow_status_code = 'AWAITING_RETURN'
                   AND ol.booked_flag = 'Y';

        lv_org_id            NUMBER := gn_org_id;
        lv_employee_id       NUMBER := fnd_global.employee_id;
        x_return_status      VARCHAR2 (2);
        lv_request_id        NUMBER;
        lv_count             NUMBER := 0;
        return_process_exp   EXCEPTION;
        lv_adj_line_id       gt_adj_line_id_tbl;
    BEGIN
        lv_count   := 0;
        write_log (
            '**------------------------------------------------------**');
        write_log ('--4.1 Inside Doing Receive Prc');

        FOR ret_order_info
            IN cur_ret_order_info (p_order_source_id,
                                   p_order_type_id,
                                   lv_org_id)
        LOOP
            x_return_status   := NULL;
            write_log ('--4.1.1 Inserting rcv interface');

            BEGIN
                INSERT INTO rcv_headers_interface (header_interface_id,
                                                   GROUP_ID,
                                                   processing_status_code,
                                                   receipt_source_code,
                                                   transaction_type,
                                                   last_update_date,
                                                   last_updated_by,
                                                   last_update_login,
                                                   customer_id,
                                                   expected_receipt_date,
                                                   validation_flag)
                    SELECT rcv_headers_interface_s.NEXTVAL, rcv_interface_groups_s.NEXTVAL, 'PENDING',
                           'CUSTOMER', 'NEW', SYSDATE,
                           gn_user_id,                               --USER_ID
                                       gn_login_id, ret_order_info.customer_id, --CUSTOMER_ID
                           SYSDATE, 'Y'
                      FROM DUAL;

                COMMIT;
            END;

            FOR ret_order_details
                IN cur_ret_order_details (ret_order_info.header_id,
                                          lv_org_id)
            LOOP
                BEGIN
                    INSERT INTO rcv_transactions_interface (
                                    interface_transaction_id,
                                    GROUP_ID,
                                    header_interface_id,
                                    last_update_date,
                                    last_updated_by,
                                    creation_date,
                                    created_by,
                                    transaction_type,
                                    transaction_date,
                                    processing_status_code,
                                    processing_mode_code,
                                    transaction_status_code,
                                    quantity,
                                    unit_of_measure,
                                    interface_source_code,
                                    item_id,
                                    employee_id,
                                    auto_transact_code,
                                    receipt_source_code,
                                    to_organization_id,
                                    source_document_code,
                                    destination_type_code,
                                    deliver_to_location_id,
                                    subinventory,
                                    expected_receipt_date,
                                    oe_order_header_id,
                                    oe_order_line_id,
                                    customer_id,
                                    customer_site_id,
                                    org_id,
                                    validation_flag)
                         VALUES (rcv_transactions_interface_s.NEXTVAL, rcv_interface_groups_s.CURRVAL, --GROUP_ID
                                                                                                       rcv_headers_interface_s.CURRVAL, SYSDATE, gn_user_id, --LAST_UPDATED_BY
                                                                                                                                                             SYSDATE, --CREATION_DATE
                                                                                                                                                                      gn_user_id, --CREATED_BY
                                                                                                                                                                                  'RECEIVE', --TRANSACTION_TYPE
                                                                                                                                                                                             -- Start changes for CCR0008983
                                                                                                                                                                                             -- SYSDATE,                             --TRANSACTION_DATE
                                                                                                                                                                                             ret_order_info.adjust_date, -- End changes for CCR0008983
                                                                                                                                                                                                                         'PENDING', --PROCESSING_STATUS_CODE
                                                                                                                                                                                                                                    'BATCH', --PROCESSING_MODE_CODE
                                                                                                                                                                                                                                             'PENDING', --TRANSACTION_MODE_CODE
                                                                                                                                                                                                                                                        ret_order_details.ordered_quantity, ret_order_details.uom, --UNIT_OF_MEASURE
                                                                                                                                                                                                                                                                                                                   'RCV', ret_order_details.inventory_item_id, --ITEM_ID
                                                                                                                                                                                                                                                                                                                                                               lv_employee_id, --EMPLOYEE_ID
                                                                                                                                                                                                                                                                                                                                                                               'DELIVER', --AUTO_TRANSACT_CODE
                                                                                                                                                                                                                                                                                                                                                                                          'CUSTOMER', --RECEIPT_SOURCE_CODE
                                                                                                                                                                                                                                                                                                                                                                                                      ret_order_details.ship_from_org_id, 'RMA', --SOURCE_DOCUMENT_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                 'INVENTORY', --DESTINATION_TYPE_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                              ret_order_details.location_id, ret_order_details.subinventory, --SUBINVENTORY
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             SYSDATE, ret_order_details.header_id, --OE_ORDER_HEADER_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ret_order_details.line_id, --OE_ORDER_LINE_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              ret_order_details.cust_id, --CUSTOMER_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         ret_order_details.cust_site_id, --CUSTOMER_SITE_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         lv_org_id
                                 ,                                    --org_id
                                   'Y');
                END;

                COMMIT;
            END LOOP;

            lv_count          := lv_count + 1;
        END LOOP;

        write_log ('End Doing Receive Prc');
    EXCEPTION
        WHEN return_process_exp
        THEN
            x_retcode   := 2;
            x_errbuf    := 'Error in Receiving Transaction Processor';
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    := SQLERRM;
            write_log ('In Rcv Process Procedure: error ' || x_errbuf);
    END rcv_orders_process_prc;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : generate_exception_notifaction
    -- Decription                : Generate the exception notifaction to Ecommerce contact.
    --                             1. If there are adjustment records from 3PL (in staging table)
    --                                  that has not been flipped into an order (stuck there for more than 3 days)
    --                              2. If auto pick /ship process fails for the ecommerce shipment records
    --                             3. If auto receipt process fails for the ecommerce return records
    --                              4. If ship only sales orders are open / not processed for more than a couple of days
    -----------------------------------------------------------------------------------
    PROCEDURE generate_exception_notifaction (retcode   OUT VARCHAR2,
                                              errbuf    OUT VARCHAR2)
    IS
        CURSOR cur_3pl_no_processed IS
            SELECT wal.adj_header_id, wal.adj_line_id, wal.sku_code,
                   wal.adj_type_code, wal.process_status, wal.error_message
              FROM xxdo.xxdo_wms_3pl_adj_l wal
             WHERE     process_status = 'O'
                   AND adj_type_code IN
                           (SELECT lookup_code
                              FROM fnd_lookup_values_vl flv
                             WHERE     flv.lookup_type = gc_order_mapping
                                   AND flv.enabled_flag = 'Y')
                   AND TRUNC (creation_date) < TRUNC (SYSDATE - 3);

        CURSOR cur_open_ship_so IS
            SELECT TO_CHAR (oh.order_number) order_number, ol.line_number, ol.ordered_item,
                   ol.flow_status_code
              FROM oe_order_headers_all oh, oe_order_lines_all ol, apps.oe_transaction_types_tl ott,
                   apps.fnd_lookup_values flv
             WHERE     oh.header_id = ol.header_id
                   AND ott.transaction_type_id = oh.order_type_id
                   AND flv.lookup_type = gc_order_mapping
                   AND flv.attribute1 = ott.name
                   AND flv.lookup_code = 'ECOMMERCE'
                   AND flv.language = 'US'
                   AND ott.language = 'US'
                   AND flv.enabled_flag = 'Y'
                   AND ol.open_flag = 'Y'
                   AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE + 1)) >=
                       TRUNC (SYSDATE)
                   AND ol.org_id = fnd_global.org_id
            UNION
            SELECT SUBSTR (ohia.orig_sys_document_ref, 1, 20) order_number, NULL line_number, msib.segment1 ordered_item,
                   'Order Import Failed' flow_status_code
              FROM oe_headers_iface_all ohia, oe_lines_iface_all olia, oe_transaction_types_vl otta,
                   fnd_lookup_values_vl flv, mtl_system_items_b msib
             WHERE     ohia.orig_sys_document_ref =
                       olia.orig_sys_document_ref
                   AND ohia.order_type_id = otta.transaction_type_id
                   AND msib.inventory_item_id = olia.inventory_item_id
                   AND msib.organization_id = olia.ship_from_org_id
                   AND otta.name = flv.attribute1
                   AND flv.lookup_type = gc_order_mapping
                   AND olia.org_id = fnd_global.org_id
                   AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE + 1)) >=
                       TRUNC (SYSDATE)
                   AND flv.enabled_flag = 'Y';

        ln_no_process_cnt            NUMBER := 0;
        ln_open_so_cnt               NUMBER := 0;
        stage_no_processed_details   cur_3pl_no_processed%ROWTYPE;
        open_ship_so_details         cur_open_ship_so%ROWTYPE;
        lt_users_email_lst           do_mail_utils.tbl_recips;
        lc_status                    NUMBER := 0;
        le_mail_exception            EXCEPTION;
        lc_from_address              VARCHAR2 (50);
        lv_subject                   VARCHAR2 (100)
            := 'Ecommerce Demand Class Consumption - Deckers';
        l_lookup_type                VARCHAR2 (100) := '';
        l_emails                     VARCHAR2 (150);
    BEGIN
        write_log (
               'IN PACKAGE - '
            || gc_package_name
            || '.generate_exception_notifaction ');
        write_log ('Send Email to users');

        OPEN cur_3pl_no_processed;

        LOOP
            FETCH cur_3pl_no_processed INTO stage_no_processed_details;

            ln_no_process_cnt   := cur_3pl_no_processed%ROWCOUNT;
            EXIT WHEN cur_3pl_no_processed%NOTFOUND;
        END LOOP;

        CLOSE cur_3pl_no_processed;

        OPEN cur_open_ship_so;

        LOOP
            FETCH cur_open_ship_so INTO open_ship_so_details;

            ln_open_so_cnt   := cur_open_ship_so%ROWCOUNT;
            EXIT WHEN cur_open_ship_so%NOTFOUND;
        END LOOP;

        CLOSE cur_open_ship_so;

        write_log (
            '**------------------------------------------------------**');
        write_log ('Total count : ');
        write_log ('So Not Processed : ' || TO_CHAR (ln_no_process_cnt));
        write_log ('Open Ship So Processed: ' || TO_CHAR (ln_open_so_cnt));

        BEGIN
            SELECT fscpv.parameter_value
              INTO lc_from_address
              FROM fnd_svc_comp_params_tl fscpt, fnd_svc_comp_param_vals fscpv, fnd_svc_components fsc
             WHERE     fscpt.parameter_id = fscpv.parameter_id
                   AND fscpv.component_id = fsc.component_id
                   AND fscpt.display_name = 'Reply-to Address'
                   AND fsc.component_name = 'Workflow Notification Mailer';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                write_log ('No Data deriving FROM email address');
                RAISE le_mail_exception;
            WHEN OTHERS
            THEN
                write_log ('Error deriving FROM email address:' || SQLERRM);
                RAISE le_mail_exception;
        END;

        BEGIN
            SELECT flv.attribute2
              INTO l_emails
              FROM fnd_lookup_values_vl flv, oe_transaction_types_vl ott
             WHERE     ott.name = flv.attribute1
                   AND ott.org_id = fnd_global.org_id
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_type = gc_order_mapping
                   AND ROWNUM = 1;

            lt_users_email_lst   := email_recips (l_emails);
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                write_log ('No Email Data found for user ' || gn_user_id);
            WHEN OTHERS
            THEN
                lt_users_email_lst.delete;
                write_log ('Error in Get Receiver Email: ' || SQLERRM);
        END;

        IF lt_users_email_lst.COUNT < 1
        THEN
            RAISE le_mail_exception;
        END IF;

        IF ln_no_process_cnt > 0 OR ln_open_so_cnt > 0
        THEN
            write_log ('--6.1 Begin Sending the email alert');
            do_mail_utils.send_mail_header (lc_from_address, lt_users_email_lst, lv_subject
                                            , lc_status);
            do_mail_utils.send_mail_line (
                   UTL_TCP.crlf
                || UTL_TCP.crlf
                || 'You are receiving this message as one or more Notification as Below: '
                || UTL_TCP.crlf
                || UTL_TCP.crlf,
                lc_status);

            IF ln_no_process_cnt > 0
            THEN
                do_mail_utils.send_mail_line (
                       UTL_TCP.crlf
                    || UTL_TCP.crlf
                    || '**There are adjustment records from 3PL (in staging table) that has not been flipped into an order (stuck there for more than 3 days.'
                    || UTL_TCP.crlf,
                    lc_status);
            END IF;

            IF ln_open_so_cnt > 0
            THEN
                do_mail_utils.send_mail_line (
                       UTL_TCP.crlf
                    || UTL_TCP.crlf
                    || '**Sales Orders that are open/not processed/stuck in interface for more than a couple of days .'
                    || UTL_TCP.crlf
                    || UTL_TCP.crlf,
                    lc_status);
            END IF;

            do_mail_utils.send_mail_line (
                   UTL_TCP.crlf
                || '3PL Stage Tables Lines '
                || UTL_TCP.crlf
                || UTL_TCP.crlf
                || RPAD ('Adjustment Header', 20, ' ')
                || RPAD ('|Adjustment Line', 20, ' ')
                || RPAD ('|SKU ', 30, ' ')
                || RPAD ('|Process Status', 20, ' ')
                || RPAD ('|Error Message ', 20, ' ')
                || UTL_TCP.crlf,
                lc_status);

            IF ln_no_process_cnt > 0
            THEN
                FOR stage_no_processed IN cur_3pl_no_processed
                LOOP
                    do_mail_utils.send_mail_line (
                           RPAD (stage_no_processed.adj_header_id, 20, ' ')
                        || RPAD (stage_no_processed.adj_line_id, 30, ' ')
                        || RPAD (stage_no_processed.sku_code, 20, ' ')
                        || RPAD (stage_no_processed.process_status, 20, ' ')
                        || stage_no_processed.error_message,
                        lc_status);
                END LOOP;
            END IF;

            IF ln_open_so_cnt > 0
            THEN
                FOR open_ship_so IN cur_open_ship_so
                LOOP
                    do_mail_utils.send_mail_line (
                           RPAD (open_ship_so.order_number, 20, ' ')
                        || RPAD (open_ship_so.line_number, 30, ' ')
                        || RPAD (open_ship_so.ordered_item, 20, ' ')
                        || RPAD (open_ship_so.flow_status_code, 20, ' '),
                        lc_status);
                END LOOP;
            END IF;

            do_mail_utils.send_mail_line (
                   UTL_TCP.crlf
                || '**Each of the columns above will have some errors found when this program is run.'
                || UTL_TCP.crlf,
                lc_status);
            do_mail_utils.send_mail_close (lc_status);
        END IF;
    EXCEPTION
        WHEN le_mail_exception
        THEN
            retcode   := '2';
            errbuf    := 'Program completed without sending email';
            write_log ('Program completed without sending email');
            do_mail_utils.send_mail_close (lc_status);

            IF (cur_3pl_no_processed%ISOPEN)
            THEN
                CLOSE cur_3pl_no_processed;
            END IF;

            IF (cur_open_ship_so%ISOPEN)
            THEN
                CLOSE cur_open_ship_so;
            END IF;
        WHEN OTHERS
        THEN
            retcode   := '2';
            errbuf    := 'Program completed without sending email';
            write_log ('Step 99: Error in Send email- ' || SQLERRM);
            do_mail_utils.send_mail_close (lc_status);

            IF (cur_3pl_no_processed%ISOPEN)
            THEN
                CLOSE cur_3pl_no_processed;
            END IF;

            IF (cur_open_ship_so%ISOPEN)
            THEN
                CLOSE cur_open_ship_so;
            END IF;
    END;

    PROCEDURE get_customer (p_item_brand IN VARCHAR2, p_adj_type_code IN VARCHAR2, p_platform IN VARCHAR2
                            , x_customer_acct OUT VARCHAR2, x_customer_id OUT NUMBER, x_sales_channel_code OUT VARCHAR2)
    IS
        lv_customer_num    hz_cust_accounts.account_number%TYPE;
        lv_sales_channel   hz_cust_accounts.sales_channel_code%TYPE;
        lv_customer_id     hz_cust_accounts.cust_account_id%TYPE;
    BEGIN
        write_log ('IN PACKAGE- ' || gc_package_name || ': Get Customer');

        BEGIN
            SELECT hca.account_number, hca.sales_channel_code, hca.cust_account_id
              INTO lv_customer_num, lv_sales_channel, lv_customer_id
              FROM hz_cust_accounts hca, fnd_lookup_values_vl flv
             WHERE     flv.lookup_type = 'XXDO_CHINA_ECOM_CUST_LKP'
                   AND flv.enabled_flag = 'Y'
                   AND TRUNC (NVL (flv.end_date_active, (SYSDATE + 1))) >=
                       TRUNC (SYSDATE)
                   AND UPPER (flv.tag) =
                       UPPER (p_item_brand) || ';' || UPPER (p_platform)
                   AND flv.description = hca.account_number
                   AND hca.status = 'A';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                write_log (
                    'Customer Number / Sales Channel: Value is not found.');
            WHEN OTHERS
            THEN
                lv_customer_num    := NULL;
                lv_sales_channel   := NULL;
                lv_customer_id     := NULL;
                write_log (
                       'Customer Number / Sales Channel in Header: ERROR with'
                    || SUBSTR (SQLERRM, 1, 2000));
        END;

        x_customer_acct        := lv_customer_num;
        x_customer_id          := lv_customer_id;
        x_sales_channel_code   := lv_sales_channel;
    END get_customer;

    PROCEDURE get_line_type_id (p_order_type_id IN NUMBER, p_ord_cate_code IN VARCHAR2, x_line_type_id OUT NUMBER)
    IS
    BEGIN
        SELECT wf.line_type_id
          INTO x_line_type_id
          FROM oe_workflow_assignments wf, oe_transaction_types_vl ott, oe_transaction_types_all ota
         WHERE     wf.line_type_id = ott.transaction_type_id
               AND wf.line_type_id IS NOT NULL
               AND wf.order_type_id = p_order_type_id
               AND ota.transaction_type_id = ott.transaction_type_id
               AND ota.order_category_code = p_ord_cate_code
               AND wf.end_date_active IS NULL;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_log ('Line Type Id : Value is not found.');
        WHEN OTHERS
        THEN
            x_line_type_id   := NULL;
            write_log (
                   'Line Type Id in line: ERROR with'
                || SUBSTR (SQLERRM, 1, 2000));
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : so_interface_load_prc
    -- Decription                : Converting  Ecommerce material transactions to sales orders
    -----------------------------------------------------------------------------------
    PROCEDURE so_interface_load_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                     , p_order_type_id IN NUMBER, -- Start changes for CCR0009333
                                                                  p_batch_size IN NUMBER, p_num_instances IN NUMBER)
    -- End changes for CCR0009333
    IS
        CURSOR wms_3pl_adj_cur IS
            -- Start changes for CCR0009333
            SELECT *
              FROM (  SELECT *
                        FROM (-- End changes for CCR0009333
                              SELECT ROW_NUMBER () OVER (PARTITION BY wah.adj_header_id, wah.adj_type_code ORDER BY wah.adj_header_id) AS rnum, MIN (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS orig_sys_doc_ref, MIN (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS cust_po_num,
                                     mc.segment1 brand, wah.adj_header_id, wah.adjust_date,
                                     wal.adj_line_id, TO_NUMBER (-wal.quantity_to_adjust) quantity_to_adjust, wal.inventory_item_id,
                                     wal.sku_code, wal.transaction_id, wah.organization_id,
                                     wah.adj_type_code, wal.adj_type_code adj_line_type_code, wal.subinventory_code,
                                     wah.ecom_platform platform, -- Start changes for CCR0009333
                                                                 wah.creation_date
                                -- End changes for CCR0009333
                                FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, mtl_system_items_b mtl,
                                     mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                                     org_organization_definitions org, oe_transaction_types_vl ott, oe_transaction_types_all ota,
                                     apps.fnd_lookup_values_vl flv
                               WHERE     wah.process_status = 'P'
                                     AND wal.process_status = 'O'
                                     AND wal.adj_type_code = 'ECOMMERCE'
                                     AND mcs.category_set_name = 'Inventory'
                                     AND wah.adj_header_id = wal.adj_header_id
                                     AND mtl.inventory_item_id =
                                         wal.inventory_item_id
                                     AND mtl.organization_id =
                                         wah.organization_id
                                     AND mtl.inventory_item_id =
                                         mic.inventory_item_id
                                     AND mtl.organization_id =
                                         mic.organization_id
                                     AND mcs.category_set_id =
                                         mic.category_set_id
                                     AND mc.category_id = mic.category_id
                                     AND mtl.organization_id =
                                         org.organization_id
                                     AND ott.name = flv.attribute1
                                     AND flv.lookup_type = gc_order_mapping
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.lookup_code =
                                         NVL (wah.adj_type_code,
                                              wal.adj_type_code)
                                     AND ott.transaction_type_id =
                                         ota.transaction_type_id
                              UNION ALL
                              SELECT ROW_NUMBER () OVER (PARTITION BY wah.adj_header_id, wah.adj_type_code ORDER BY wah.adj_header_id) AS rnum, MIN (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS orig_sys_doc_ref, MIN (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS cust_po_num,
                                     mc.segment1 brand, wah.adj_header_id, wah.adjust_date,
                                     wal.adj_line_id, TO_NUMBER (-wal.quantity_to_adjust) quantity_to_adjust, wal.inventory_item_id,
                                     wal.sku_code, wal.transaction_id, wah.organization_id,
                                     wah.adj_type_code, wal.adj_type_code adj_line_type_code, wal.subinventory_code,
                                     wah.ecom_platform platform, -- Start changes for CCR0009333
                                                                 wah.creation_date
                                -- End changes for CCR0009333
                                FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, mtl_system_items_b mtl,
                                     mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                                     org_organization_definitions org, oe_transaction_types_vl ott, oe_transaction_types_all ota,
                                     apps.fnd_lookup_values_vl flv
                               WHERE     wah.process_status = 'O'
                                     AND wal.process_status = 'P'
                                     AND wah.adj_type_code IN
                                             ('SHIPECOMM', 'RETURNECOMM')
                                     AND mcs.category_set_name = 'Inventory'
                                     AND wah.adj_header_id = wal.adj_header_id
                                     AND mtl.inventory_item_id =
                                         wal.inventory_item_id
                                     AND mtl.organization_id =
                                         wah.organization_id
                                     AND mtl.inventory_item_id =
                                         mic.inventory_item_id
                                     AND mtl.organization_id =
                                         mic.organization_id
                                     AND mcs.category_set_id =
                                         mic.category_set_id
                                     AND mc.category_id = mic.category_id
                                     AND mtl.organization_id =
                                         org.organization_id
                                     AND ott.name = flv.attribute1
                                     AND flv.lookup_type = gc_order_mapping
                                     AND flv.enabled_flag = 'Y'
                                     AND flv.lookup_code =
                                         NVL (wah.adj_type_code,
                                              wal.adj_type_code)
                                     AND ott.transaction_type_id =
                                         ota.transaction_type_id)
                    -- Start changes for CCR0009333
                    -- ORDER BY NVL (adjust_date, creation_date)) --Commented for CCR0009736
                    ORDER BY NVL (adjust_date, creation_date), orig_sys_doc_ref, rnum) --added for CCR0009736
             WHERE ROWNUM <= p_batch_size;

        -- End changes for CCR0009333

        TYPE lr_iface_tab IS TABLE OF ont.oe_headers_iface_all%ROWTYPE
            INDEX BY BINARY_INTEGER;

        TYPE lr_iface_lines_tab IS TABLE OF ont.oe_lines_iface_all%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lr_iface_rec            lr_iface_tab;
        lr_iface_lines_rec      lr_iface_lines_tab;
        ln_order_source_id      oe_order_headers_all.order_source_id%TYPE;
        lv_orig_sys_doc_ref     VARCHAR2 (1000);
        lv_operation_code       VARCHAR2 (10) := 'INSERT';
        ln_order_type_id        oe_headers_iface_all.order_type_id%TYPE;
        ln_price_list_id        oe_headers_iface_all.price_list_id%TYPE;
        ln_payment_term_id      oe_headers_iface_all.payment_term_id%TYPE;
        lv_shipping_method      oe_transaction_types_all.shipping_method_code%TYPE;
        ln_warehouse_id         oe_transaction_types_all.warehouse_id%TYPE;
        lv_fob                  oe_transaction_types_all.fob_point_code%TYPE;
        lv_freight_terms_code   oe_transaction_types_all.freight_terms_code%TYPE;
        lv_shipment_priority    oe_transaction_types_all.shipment_priority_code%TYPE;
        lv_customer_num         hz_cust_accounts.account_number%TYPE;
        lv_sales_channel        hz_cust_accounts.sales_channel_code%TYPE;
        lv_payment              ra_terms_vl.name%TYPE := 'Net 30';
        lv_line_type_id         oe_transaction_types_all.transaction_type_id%TYPE;
        lv_customer_id          hz_cust_accounts.cust_account_id%TYPE;
        lv_cust_po              VARCHAR2 (500);
        lv_subinventory         VARCHAR2 (10);
        lv_order_type_name      oe_transaction_types_vl.name%TYPE;
        lv_header_idx           NUMBER := 0;
        lv_org_id               NUMBER;
        lf_valid_flag           VARCHAR2 (1) := 'Y';
        lv_err_adj_line_id      gt_adj_line_id_tbl;
        too_many_order_type     EXCEPTION;
        validationexcp          EXCEPTION;
        lv_platform             VARCHAR2 (100) := NULL;
    BEGIN
        write_log (
            '-------------In Extract Data into Interface----------------');
        lv_orig_sys_doc_ref     := NULL;
        ln_price_list_id        := NULL;
        ln_order_source_id      := NULL;
        ln_order_type_id        := NULL;
        lv_order_type_name      := NULL;
        lv_shipping_method      := NULL;
        ln_warehouse_id         := NULL;
        lv_fob                  := NULL;
        lv_freight_terms_code   := NULL;
        lv_shipment_priority    := NULL;
        ln_payment_term_id      := NULL;
        lv_customer_num         := NULL;
        lv_sales_channel        := NULL;
        lv_line_type_id         := NULL;
        lv_customer_id          := 0;
        lf_valid_flag           := 'Y';
        lv_org_id               := NULL;
        lv_header_idx           := 0;
        lv_err_adj_line_id.delete;
        write_log (
            '---------------------------------------------------------');
        ln_order_source_id      := p_order_source_id;
        write_log ('Order Source ID ' || ln_order_source_id);

        BEGIN
            SELECT term_id
              INTO ln_payment_term_id
              FROM ra_terms_vl
             WHERE name = lv_payment AND in_use = 'Y';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                lf_valid_flag   := 'N';
                write_log (
                    'Payment Term ID in Header : ''Net 30'' is not found.');
                write_output (
                    'Payment Term ID in Header : ''Net 30'' is not found.');
            WHEN OTHERS
            THEN
                lf_valid_flag        := 'N';
                ln_payment_term_id   := NULL;
                write_log (
                       'Payment Term ID in Header : ERROR with'
                    || SUBSTR (SQLERRM, 1, 2000));
                write_output (
                       'Payment Term ID in Header : ERROR with'
                    || SUBSTR (SQLERRM, 1, 2000));
        END;

        write_log ('Payment Item ID ' || ln_payment_term_id);

        IF lf_valid_flag <> 'N'
        THEN
            FOR wms_3pl_adj_rec IN wms_3pl_adj_cur
            LOOP
                lf_valid_flag   := 'Y';
                write_log (
                       'wms_3pl_adj_rec.rnum '
                    || wms_3pl_adj_rec.rnum
                    || ' '
                    || wms_3pl_adj_rec.adj_line_id);

                IF wms_3pl_adj_rec.rnum = 1
                THEN
                    write_log (
                        '---------------------------------------------------------');
                    lv_header_idx           := lv_header_idx + 1;
                    ln_order_type_id        := NULL;
                    ln_price_list_id        := NULL;
                    lv_shipping_method      := NULL;
                    lv_fob                  := NULL;
                    lv_freight_terms_code   := NULL;
                    lv_shipment_priority    := NULL;
                    lv_org_id               := NULL;
                    lv_subinventory         := NULL;
                    lv_order_type_name      := NULL;
                    lv_cust_po              := NULL;
                    lv_orig_sys_doc_ref     := NULL;
                    lv_customer_num         := NULL;
                    lv_customer_id          := NULL;
                    lv_sales_channel        := NULL;
                    ln_warehouse_id         := NULL;

                    IF lv_header_idx > 1 AND wms_3pl_adj_rec.rnum = 1
                    THEN
                        write_log (
                            '--------------------------------------------------');
                        write_log ('Insert previous record ');
                        write_log (
                            'lr_iface_rec.COUNT ' || lr_iface_rec.COUNT);

                        FOR i IN 1 .. lr_iface_rec.COUNT
                        LOOP
                            BEGIN
                                INSERT INTO ont.oe_headers_iface_all
                                     VALUES lr_iface_rec (i);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ROLLBACK;
                                    write_log (
                                           'Error in load data into Header Interface setp 2 '
                                        || SQLERRM);
                            END;
                        END LOOP;

                        write_log (
                            'lr_iface_lines_rec.COUNT ' || lr_iface_lines_rec.COUNT);

                        FOR i IN 1 .. lr_iface_lines_rec.COUNT
                        LOOP
                            BEGIN
                                INSERT INTO ont.oe_lines_iface_all
                                     VALUES lr_iface_lines_rec (i);

                                write_log (
                                       'lr_iface_lines_rec(i) '
                                    || lr_iface_lines_rec (i).orig_sys_line_ref);
                            EXCEPTION
                                WHEN OTHERS
                                THEN
                                    ROLLBACK;
                                    write_log (
                                           'Error in load data into Line Interface step 2 '
                                        || SQLERRM);
                            END;
                        END LOOP;

                        lr_iface_rec.delete;
                        lr_iface_lines_rec.delete;
                        COMMIT;
                        write_log (
                            '-----------------End Previous Insert----------------------------');
                    END IF;

                    BEGIN
                        SELECT ott.transaction_type_id, ota.price_list_id, ota.shipping_method_code,
                               ota.warehouse_id, ota.fob_point_code, ota.freight_terms_code,
                               ota.shipment_priority_code, ota.org_id, ota.attribute7,
                               ott.name
                          INTO ln_order_type_id, ln_price_list_id, lv_shipping_method, ln_warehouse_id,
                                               lv_fob, lv_freight_terms_code, lv_shipment_priority,
                                               lv_org_id, lv_subinventory, lv_order_type_name
                          FROM oe_transaction_types_vl ott, oe_transaction_types_all ota, apps.fnd_lookup_values_vl flv
                         WHERE     ott.name = flv.attribute1
                               AND flv.lookup_type = gc_order_mapping
                               AND flv.enabled_flag = 'Y'
                               AND flv.lookup_code =
                                   NVL (wms_3pl_adj_rec.adj_type_code,
                                        wms_3pl_adj_rec.adj_line_type_code)
                               AND ott.transaction_type_id =
                                   ota.transaction_type_id;
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lf_valid_flag   := 'N';
                            write_log (
                                'Order Type/Price List/Shipping Method/FOB/Freight Terms/Shipment Priority  in Header : Value is not found.');
                        WHEN OTHERS
                        THEN
                            lf_valid_flag           := 'N';
                            ln_order_type_id        := NULL;
                            ln_price_list_id        := NULL;
                            lv_shipping_method      := NULL;
                            ln_warehouse_id         := NULL;
                            lv_fob                  := NULL;
                            lv_freight_terms_code   := NULL;
                            lv_shipment_priority    := NULL;
                            lv_org_id               := NULL;
                            lv_subinventory         := NULL;
                            lv_order_type_name      := NULL;
                            write_log (
                                   'Order Type/Price List/Shipping Method/FOB/Freight Terms/Shipment Priority in Header : ERROR with'
                                || SUBSTR (SQLERRM, 1, 2000));
                    END;

                    write_log ('Order Type Id ' || ln_order_type_id);
                    lv_orig_sys_doc_ref     :=
                        wms_3pl_adj_rec.orig_sys_doc_ref;
                    lv_cust_po              := wms_3pl_adj_rec.cust_po_num;
                    write_log ('Orig Sys Doc Ref ' || lv_orig_sys_doc_ref);
                    write_log ('Customper PO ' || lv_cust_po);
                    get_customer (
                        wms_3pl_adj_rec.brand,
                        NVL (wms_3pl_adj_rec.adj_type_code,
                             wms_3pl_adj_rec.adj_line_type_code),
                        wms_3pl_adj_rec.platform,
                        lv_customer_num,
                        lv_customer_id,
                        lv_sales_channel);
                    write_log ('Customer ID ' || lv_customer_id);

                    IF (lv_orig_sys_doc_ref IS NULL OR lv_customer_id IS NULL)
                    THEN
                        lf_valid_flag   := 'N';
                        lv_err_adj_line_id (lv_err_adj_line_id.COUNT + 1)   :=
                            wms_3pl_adj_rec.adj_line_id;
                    END IF;

                    BEGIN
                        IF lf_valid_flag <> 'N'
                        THEN
                            write_log ('INSERT HEADER' || lv_header_idx);
                            lr_iface_rec (wms_3pl_adj_rec.rnum).last_update_date   :=
                                SYSDATE;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).last_updated_by   :=
                                gn_user_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).creation_date   :=
                                SYSDATE;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).created_by   :=
                                gn_user_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).last_update_login   :=
                                gn_login_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).org_id   :=
                                lv_org_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).order_source_id   :=
                                ln_order_source_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).orig_sys_document_ref   :=
                                lv_orig_sys_doc_ref;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).operation_code   :=
                                lv_operation_code;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).ready_flag   :=
                                'Y';
                            lr_iface_rec (wms_3pl_adj_rec.rnum).ordered_date   :=
                                wms_3pl_adj_rec.adjust_date - 2;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).order_type_id   :=
                                ln_order_type_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).price_list_id   :=
                                ln_price_list_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).payment_term_id   :=
                                ln_payment_term_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).sold_from_org_id   :=
                                lv_org_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).sold_to_org_id   :=
                                lv_customer_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).ship_from_org_id   :=
                                ln_warehouse_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).customer_number   :=
                                lv_customer_num;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).customer_po_number   :=
                                lv_cust_po;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).sales_channel_code   :=
                                lv_sales_channel;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).fob_point_code   :=
                                lv_fob;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).freight_terms_code   :=
                                lv_freight_terms_code;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).shipment_priority_code   :=
                                lv_shipment_priority;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).attribute1   :=
                                TO_CHAR (SYSDATE + 30,
                                         'YYYY/MM/DD HH24:MI:SS');
                            lr_iface_rec (wms_3pl_adj_rec.rnum).attribute5   :=
                                wms_3pl_adj_rec.brand;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).booked_flag   :=
                                'Y';
                            lr_iface_rec (wms_3pl_adj_rec.rnum).closed_flag   :=
                                'N';
                        END IF;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            lf_valid_flag   := 'N';
                            write_log ('STEP 99- Error ' || SQLERRM);
                    END;
                END IF;

                BEGIN
                    IF lf_valid_flag <> 'N'
                    THEN
                        write_log ('INSERT LINE' || wms_3pl_adj_rec.rnum);
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).last_update_date   :=
                            SYSDATE;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).last_updated_by   :=
                            gn_user_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).creation_date   :=
                            SYSDATE;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).created_by   :=
                            gn_user_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).last_update_login   :=
                            gn_login_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).org_id   :=
                            lv_org_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).order_source_id   :=
                            ln_order_source_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).orig_sys_document_ref   :=
                            lv_orig_sys_doc_ref;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).orig_sys_line_ref   :=
                            TO_CHAR (wms_3pl_adj_rec.adj_line_id);
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).ship_from_org_id   :=
                            ln_warehouse_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).operation_code   :=
                            lv_operation_code;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).line_number   :=
                            wms_3pl_adj_rec.rnum;

                        IF TO_NUMBER (wms_3pl_adj_rec.quantity_to_adjust) > 0
                        THEN
                            get_line_type_id (ln_order_type_id,
                                              'ORDER',
                                              lv_line_type_id);

                            IF lv_line_type_id IS NOT NULL
                            THEN
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).schedule_ship_date   :=
                                    SYSDATE;
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).line_type_id   :=
                                    lv_line_type_id;
                            ELSE
                                lv_err_adj_line_id (
                                    lv_err_adj_line_id.COUNT + 1)   :=
                                    wms_3pl_adj_rec.adj_line_id;
                            END IF;
                        ELSE
                            get_line_type_id (ln_order_type_id,
                                              'RETURN',
                                              lv_line_type_id);

                            IF lv_line_type_id IS NOT NULL
                            THEN
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).line_type_id   :=
                                    lv_line_type_id;
                            ELSE
                                lv_err_adj_line_id (
                                    lv_err_adj_line_id.COUNT + 1)   :=
                                    wms_3pl_adj_rec.adj_line_id;
                            END IF;
                        END IF;

                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).sold_to_org_id   :=
                            lv_customer_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).inventory_item_id   :=
                            wms_3pl_adj_rec.inventory_item_id;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).ordered_quantity   :=
                            TO_NUMBER (wms_3pl_adj_rec.quantity_to_adjust);
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).subinventory   :=
                            wms_3pl_adj_rec.subinventory_code;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).request_date   :=
                            wms_3pl_adj_rec.adjust_date - 2;
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).attribute1   :=
                            TO_CHAR (
                                  lr_iface_lines_rec (wms_3pl_adj_rec.rnum).request_date
                                + 30,
                                'YYYY/MM/DD HH24:MI:SS');
                    END IF;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        lf_valid_flag   := 'N';
                        write_log ('STEP 99- Error ' || SQLERRM);
                END;
            END LOOP;                       -- End Loop Cursor wms_3pl_adj_cur

            IF lf_valid_flag <> 'N'
            THEN
                write_log (
                       'Step 1 Load data into Intf header table '
                    || lr_iface_rec.COUNT);

                FOR i IN 1 .. lr_iface_rec.COUNT
                LOOP
                    BEGIN
                        INSERT INTO ont.oe_headers_iface_all
                             VALUES lr_iface_rec (i);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ROLLBACK;
                            write_log (
                                   'Error in load data into Header Interface step1 '
                                || SQLERRM);
                    END;
                END LOOP;

                write_log (
                    'lr_iface_lines_rec.COUNT ' || lr_iface_lines_rec.COUNT);

                FOR i IN 1 .. lr_iface_lines_rec.COUNT
                LOOP
                    BEGIN
                        INSERT INTO ont.oe_lines_iface_all
                             VALUES lr_iface_lines_rec (i);
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ROLLBACK;
                            write_log (
                                   'Error in load data into Line Interface step1 '
                                || SQLERRM);
                    END;
                END LOOP;

                COMMIT;

                IF lv_err_adj_line_id.COUNT > 0
                THEN
                    FOR i IN 1 .. lv_err_adj_line_id.COUNT
                    LOOP
                        updating_process_status (gc_process_error,
                                                 'Validation Failed',
                                                 lv_err_adj_line_id (i));
                    END LOOP;

                    lv_err_adj_line_id.delete;
                END IF;

                -- Start changes for CCR0009333
                /*xxdo_wms_3pl_adj_conv_pkg.create_sales_order (x_errbuf,
                                                              x_retcode,
                                                              ln_order_source_id,
                                                              p_order_type_id);*/

                xxdo_wms_3pl_demand_cons_pkg.create_sales_order (
                    x_errbuf,
                    x_retcode,
                    ln_order_source_id,
                    p_order_type_id,
                    p_num_instances);
            -- End changes for CCR0009333

            END IF;
        ELSE
            write_log (
                'Error in Package' || gc_package_name || 'with Validation');
            RAISE validationexcp;
        END IF;
    EXCEPTION
        WHEN validationexcp
        THEN
            x_retcode   := 2;
            write_output (
                'Error in Package' || gc_package_name || 'with Validation');
        WHEN too_many_order_type
        THEN
            x_errbuf    := x_errbuf || 'Too Many order type in Current OU';
            x_retcode   := 2;
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode   := 2;
            x_errbuf    := SUBSTR (SQLERRM, 10, 2000);
            write_log (x_errbuf);
    END so_interface_load_prc;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : main
    -- Decription                : The main procedure
    -----------------------------------------------------------------------------------
    PROCEDURE main (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2)
    IS
        lv_request_id         NUMBER;
        lv_exc_cnt            NUMBER;
        lv_success_flag       BOOLEAN;
        submit_failed         EXCEPTION;
        error_others          EXCEPTION;
        ln_order_type_id      NUMBER;
        ln_order_source_id    NUMBER;
        too_many_order_type   EXCEPTION;
        excp_no_data          EXCEPTION;
        success               BOOLEAN;
        lv_message            VARCHAR2 (2000);
        lb_wait               BOOLEAN;
        lv_phase              VARCHAR2 (80);
        lv_status             VARCHAR2 (80);
        lv_dev_phase          VARCHAR2 (30);
        lv_dev_status         VARCHAR2 (30);
        lv_order_type_name    oe_transaction_types_vl.name%TYPE;
    BEGIN
        lv_exc_cnt           := 0;
        lv_order_type_name   := NULL;
        write_log ('Org id is ' || fnd_global.org_id);

        SELECT COUNT (wah.adj_header_id)
          INTO lv_exc_cnt
          FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, org_organization_definitions org
         WHERE     wah.process_status IN ('O', 'P')
               AND wah.adj_header_id = wal.adj_header_id
               AND wal.process_status IN ('O', 'P')
               AND wah.organization_id = org.organization_id
               AND NVL (wal.adj_type_code, wah.adj_type_code) IN
                       (SELECT lookup_code
                          FROM fnd_lookup_values_vl flv
                         WHERE     flv.lookup_type = gc_order_mapping
                               AND flv.enabled_flag = 'Y');

        IF lv_exc_cnt > 0
        THEN
            write_log ('--1.1 Begain the Main Proc');

            BEGIN
                SELECT DISTINCT ott.transaction_type_id, ott.name
                  INTO ln_order_type_id, lv_order_type_name
                  FROM oe_transaction_types_vl ott, oe_transaction_types_all ota, apps.fnd_lookup_values_vl flv
                 WHERE     ott.name = flv.attribute1
                       AND flv.lookup_type = gc_order_mapping
                       AND flv.enabled_flag = 'Y'
                       AND ott.transaction_type_id = ota.transaction_type_id
                       AND ota.org_id = gn_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    write_log ('No Data found For Order Type ID');
                    write_output ('No Data found For Order Type ID');
                    RAISE excp_no_data;
                WHEN TOO_MANY_ROWS
                THEN
                    write_log ('Too Many Rows For Order Type ID');
                    write_output ('No Data found For Order Type ID');
                    RAISE too_many_order_type;
                WHEN OTHERS
                THEN
                    RAISE error_others;
            END;

            BEGIN
                SELECT order_source_id
                  INTO ln_order_source_id
                  FROM oe_order_sources
                 WHERE name = gc_order_source_nm AND enabled_flag = 'Y';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    write_log (
                        'Order Source in Header: ''Ecomm Consumption'' is not found.');
                    RAISE excp_no_data;
                WHEN TOO_MANY_ROWS
                THEN
                    write_log ('Too Many Rows For Order Source ID');
                    write_output ('No Data found For Order Source ID');
                    RAISE too_many_order_type;
                WHEN OTHERS
                THEN
                    ln_order_source_id   := NULL;
                    write_log (
                           'Order Source in Header: ERROR with'
                        || SUBSTR (SQLERRM, 1, 2000));
                    RAISE error_others;
            END;

            write_log ('ln_order_type_id ' || ln_order_type_id);
            write_log ('ln_order_source_id ' || ln_order_source_id);
            lv_success_flag   :=
                fnd_submit.set_request_set ('XXDO',
                                            'XXDO_WMS_3PL_ADJ_REQ_SET');

            IF (lv_success_flag)
            THEN
                success         :=
                    fnd_submit.submit_program (
                        application   => 'XXDO',
                        program       => 'XXDO_WMS_3PL_ADJ_SO_CRT_CP',
                        stage         => 'STAGE10',
                        argument1     => ln_order_source_id,
                        argument2     => ln_order_type_id);

                IF (NOT success)
                THEN
                    write_log (
                           'Error in Submit Requst: '
                        || 'Submit Program XXDO_WMS_3PL_ADJ_SO_CRT_CP');
                    RAISE submit_failed;
                END IF;

                success         :=
                    fnd_submit.submit_program (
                        application   => 'XXDO',
                        program       => 'XXDO_WMS_3PL_ADJ_SO_RCV_CP',
                        stage         => 'STAGE20',
                        argument1     => ln_order_source_id,
                        argument2     => ln_order_type_id);

                IF (NOT success)
                THEN
                    write_log (
                           'Error in Submit Requst: '
                        || 'Submit Program XXDO_WMS_3PL_ADJ_SO_RCV_CP');
                    RAISE submit_failed;
                END IF;

                success         :=
                    fnd_submit.submit_program (
                        application   => 'XXDO',
                        program       => 'XXDO_WMS_3PL_ADJ_SO_SHIP_CP',
                        stage         => 'STAGE30',
                        argument1     => ln_order_source_id,
                        argument2     => ln_order_type_id);

                IF (NOT success)
                THEN
                    write_log (
                           'Error in Submit Requst: '
                        || 'Submit Program XXDO_WMS_3PL_ADJ_SO_SHIP_CP');
                    RAISE submit_failed;
                END IF;

                lv_request_id   := fnd_submit.submit_set (NULL, FALSE);
                COMMIT;
            END IF;

            write_log ('Request Set ID :' || lv_request_id);

            BEGIN
                IF lv_request_id > 0
                THEN
                    LOOP
                        lb_wait   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => lv_request_id,
                                interval     => 1,
                                max_wait     => 200,
                                phase        => lv_phase,
                                status       => lv_status,
                                dev_phase    => lv_dev_phase,
                                dev_status   => lv_dev_status,
                                MESSAGE      => lv_message);

                        IF ((UPPER (lv_dev_phase) = 'COMPLETE') OR (UPPER (lv_phase) = 'COMPLETED'))
                        THEN
                            EXIT;
                        END IF;
                    END LOOP;
                END IF;
            END;
        END IF;

        generate_exception_notifaction (x_retcode, x_errbuf);
    EXCEPTION
        WHEN submit_failed
        THEN
            x_errbuf    :=
                'Submit Program with error: ' || SUBSTR (SQLERRM, 1, 2000);
            x_retcode   := 2;
            write_log ('Error in Submit Requst' || SUBSTR (SQLERRM, 1, 2000));
        WHEN excp_no_data
        THEN
            x_errbuf    := 'No Data found For:' || SUBSTR (SQLERRM, 1, 2000);
            x_retcode   := 2;
        WHEN too_many_order_type
        THEN
            x_errbuf    := 'Too Many Rows found For Order Type ID';
            x_retcode   := 2;
            write_log ('Too Many Rows found For Order Type ID');
            write_output ('Too Many Rows found For Order Type ID');
        WHEN error_others
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            write_log ('Error in Submit Requst' || SUBSTR (SQLERRM, 1, 2000));
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            write_log ('Error in Submit Requst' || SUBSTR (SQLERRM, 1, 2000));
    END main;
END xxdo_wms_3pl_demand_cons_pkg;
/
