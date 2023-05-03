--
-- XXDO_WMS_3PL_ADJ_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:12 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_3PL_ADJ_CONV_PKG"
AS
    /*******************************************************************************
    * $Header$
    * Program Name : XXDO_WMS_3PL_ADJ_CONV_PKG.pkb
    * Language     : PL/SQL
    * Description  : This package is used for process the Ecommerce transactions(Sales Order/Returns).
    *                   It will Convert Ecommerce material transactions (Sales and Returns)  to Sales Order(s)
    *                   Once Create the SOs, it will do
    *                    1. Auto Pick Release and Ship confirm of Ecommerce Orders.
    *                    2. Auto Receipt of Ecommerce Return Orders lines
    *                    3. Updating Transactions status of Adjustment records
    *                    4. Generate Oracle PL/SQL Alert for Exception Notification
    * History      :
    * 2-Jun-2015 Created as Initial
    * ------------------------------------------------------------------------
    * VERSION         WHO                        WHAT                       WHEN
    * -------   ------------------------  ---------------------------  -------------
    * 1.0       BT Technology Team        Initial                       02-Jun-2015
    * 1.1       Viswanathan Pandian       Changes for CCR0005950        08-Feb-2017
    * 1.2       Siva                      CCR : CCR0006185              16-Apr-2017
    * 1.3       Siva                      CCR : CCR0006261              24-Jul-2017
    * 1.4       Infosys                   CCR : CCR0006678              26-Sep-2017
    *******************************************************************************/
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
    --
    -- Parameters
    -- x_errbuf                 OUTPUT
    -- x_retcode                 OUTPUT
    -- p_order_source            INPUT
    -- p_order_type_id          INPUT
    -- Modification History
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE create_sales_order (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source IN NUMBER
                                  , p_order_type_id IN NUMBER)
    IS
        lv_request_num       NUMBER;

        TYPE gv_child_req_id IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lv_child_req_id      gv_child_req_id;
        lv_def_org_id        NUMBER := mo_utils.get_default_org_id;
        -- lv_adj_line_id  gt_adj_line_id_tbl;
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
            -- 1.1 Invoke Order Import with order source
            lv_request_num   :=
                fnd_request.submit_request (application   => 'ONT',
                                            program       => 'OEOIMP',
                                            description   => 'Order Import',
                                            start_time    => SYSDATE,
                                            argument1     => lv_org_id,
                                            --Operating Unit
                                            argument2     => p_order_source,
                                            argument3     => NULL,
                                            --Original System Document Ref
                                            argument4     => NULL,
                                            --Operation Code
                                            argument5     => 'N',
                                            --Validate Only?
                                            argument6     => '1', --Debug Level
                                            argument7     => '4',
                                            --Number of Order Import instances
                                            argument8     => NULL,
                                            --Sold To Org Id
                                            argument9     => NULL,
                                            --Sold To Org
                                            argument10    => NULL,
                                            --Change Sequence
                                            argument11    => 'Y',
                                            --Enable Single Line Queue for Instances
                                            argument12    => 'N',
                                            --Trim Trailing Blanks
                                            argument13    => 'Y',
                                            --Process Orders With No Org Specified
                                            argument14    => lv_def_org_id,
                                            --Default Operating Unit
                                            argument15    => 'Y',
                                            --Validate Description Flexfields?
                                            argument16    => CHR (0));
            COMMIT;
            write_log ('Order Import Request Id:' || lv_request_num);

            --   dbms_output.put_line('Order Import Request Id:' || lv_request_num);
            IF lv_request_num > 0
            THEN
                LOOP
                    lb_wait   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => lv_request_num --ln_concurrent_request_id
                                                          ,
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


            -- Start code change by Viswanathan Pandian for CCR0005950

            BEGIN
                -- UPDATING Staging table with 'S'
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
        -- End of code change by Viswanathan Pandian for CCR0005950

        EXCEPTION
            WHEN OTHERS
            THEN
                x_errbuf    := SUBSTR (SQLERRM, 1, 2000);
                write_log (x_errbuf);
                x_retcode   := 1;
        END;

        -- Commented by Viswanathan Pandian for CCR0005950
        --book order
        /*IF (   (UPPER (lv_dev_phase) = 'COMPLETE')
            OR (UPPER (lv_phase) = 'COMPLETED'))
        THEN
           book_order (p_order_source, p_order_type_id);
        END IF;*/
        -- Commented by Viswanathan Pandian for CCR0005950

        --begin update staging table
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

            --   dbms_output.put_line('lv_adj_line_id.COUNT ' || lv_adj_line_id.COUNT);
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
    --
    --
    -- Parameters
    -- p_process_status        INPUT
    -- p_message              INPUT
    -- p_adj_line_id             INPUT
    -- Comments
    -- gc_process_error   'E'
    -- gc_process_import  'I'
    -- gc_process_returned 'R'
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
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
    -- Procedure/Function Name   : pick_release
    -- Decription                : Using API to Pick Releasse the Ship Orders.
    --
    --
    -- Parameters
    -- p_delivery_id   IN
    -- p_delivery_name IN
    -- x_return_status IN OUT NOCOPY
    -- x_msg_count     IN OUT NOCOPY
    -- x_msg_data      IN OUT NOCOPY
    -- x_trip_id       OUT
    -- x_trip_name     OUT
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    /*  PROCEDURE pick_release(p_delivery_id   IN NUMBER,
                             p_delivery_name IN VARCHAR2,
                             x_return_status IN OUT NOCOPY VARCHAR2,
                             x_msg_count     IN OUT NOCOPY NUMBER,
                             x_msg_data      IN OUT NOCOPY VARCHAR2,
                             x_trip_id       OUT VARCHAR2,
                             x_trip_name     OUT VARCHAR2) IS
      BEGIN
        write_log('--5.2.1 In Pick Release');
        wsh_deliveries_pub.delivery_action(p_api_version_number      => 1.0,
                                           p_init_msg_list           => NULL,
                                           x_return_status           => x_return_status,
                                           x_msg_count               => x_msg_count,
                                           x_msg_data                => x_msg_data,
                                           p_action_code             => 'PICK-RELEASE',
                                           p_delivery_id             => p_delivery_id,
                                           p_delivery_name           => p_delivery_name,
                                           p_asg_trip_id             => NULL,
                                           p_asg_trip_name           => NULL,
                                           p_asg_pickup_stop_id      => NULL,
                                           p_asg_pickup_loc_id       => NULL,
                                           p_asg_pickup_stop_seq     => NULL,
                                           p_asg_pickup_loc_code     => NULL,
                                           p_asg_pickup_arr_date     => NULL,
                                           p_asg_pickup_dep_date     => NULL,
                                           p_asg_dropoff_stop_id     => NULL,
                                           p_asg_dropoff_loc_id      => NULL,
                                           p_asg_dropoff_stop_seq    => NULL,
                                           p_asg_dropoff_loc_code    => NULL,
                                           p_asg_dropoff_arr_date    => NULL,
                                           p_asg_dropoff_dep_date    => NULL,
                                           p_sc_action_flag          => 'S',
                                           p_sc_intransit_flag       => 'N',
                                           p_sc_close_trip_flag      => 'N',
                                           p_sc_create_bol_flag      => 'N',
                                           p_sc_stage_del_flag       => 'Y',
                                           p_sc_trip_ship_method     => NULL,
                                           p_sc_actual_dep_date      => NULL,
                                           p_sc_report_set_id        => NULL,
                                           p_sc_report_set_name      => NULL,
                                           p_sc_defer_interface_flag => 'Y',
                                           p_sc_send_945_flag        => NULL,
                                           p_sc_rule_id              => NULL,
                                           p_sc_rule_name            => NULL,
                                           p_wv_override_flag        => 'N',
                                           x_trip_id                 => x_trip_id,
                                           x_trip_name               => x_trip_name);

        IF x_return_status <> fnd_api.g_ret_sts_success THEN
          FOR i IN 1 .. x_msg_count LOOP
            write_log('--5.2.1 ERROR in Pick Release--' || x_msg_data);
          END LOOP;
          ROLLBACK;
        ELSE
          COMMIT;
          write_log('--5.2.1 Pick Release Successfully.');
        END IF;
      EXCEPTION
        WHEN OTHERS THEN
          write_log('Exception In Pick Release' || SQLERRM);
      END pick_release;*/

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : book_order
    -- Decription                : Using API to Book Sales Orders.
    --
    --
    -- Parameters
    -- p_order_source_id IN
    -- p_order_type_id   IN
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
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
        -- INPUT VARIABLES FOR PROCESS_ORDER API
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        --out
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
    /*    x_msg_summary                VARCHAR2(2000);
    x_msg_details                VARCHAR2(2000);
    x_msg_count                  number;*/
    BEGIN
        write_log ('--3.1 In BOOKING Order Procedure');

        /*    x_msg_summary := null;
        x_msg_details := null;*/
        FOR i
            IN order_header_details (lv_org_id,
                                     p_order_source_id,
                                     p_order_type_id)
        LOOP
            lc_return_status                        := NULL;
            ln_msg_count                            := 0;
            lc_msg_data                             := NULL;
            /*    l_line_tbl       := oe_order_pub.g_miss_line_tbl;

              FOR cur_line IN (SELECT line_id, line_number
                               FROM oe_order_lines_all
                              WHERE header_id = i.header_id
                                AND flow_status_code = 'ENTERED'
                                AND line_category_code = 'ORDER') LOOP
              -- x_valid_flag := 'N';
              DBMS_OUTPUT.put_line('cur_line ' || cur_line.line_id);
              l_line_tbl(l_line_tbl.COUNT + 1) := oe_order_pub.g_miss_line_rec;
              l_line_tbl(l_line_tbl.COUNT + 1).line_id := cur_line.line_id;
              l_line_tbl(l_line_tbl.COUNT + 1).line_number := cur_line.line_number;
              l_line_tbl(l_line_tbl.COUNT + 1).operation := oe_globals.g_opr_update;
              l_line_tbl(l_line_tbl.COUNT + 1).schedule_ship_date := SYSDATE + 400;
              l_line_tbl(l_line_tbl.COUNT + 1).schedule_action_code := 'SCHEDULE';
              --                    := FND_API.G_MISS_CHAR;
              l_line_tbl(l_line_tbl.COUNT + 1).override_atp_date_code := 'Y';
              l_line_tbl(l_line_tbl.COUNT + 1).visible_demand_flag := fnd_api.g_miss_char;
            END LOOP;*/

            l_action_request_tbl (1)                := oe_order_pub.g_miss_request_rec;
            l_action_request_tbl (1).entity_id      := i.header_id;
            l_action_request_tbl (1).entity_code    :=
                oe_globals.g_entity_header;
            l_action_request_tbl (1).request_type   :=
                oe_globals.g_book_order;
            l_header_rec.header_id                  := i.header_id;
            --UPDATE ATP FLAG ?
            oe_order_pub.process_order (
                p_api_version_number       => ln_api_version_number,
                p_header_rec               => l_header_rec,
                /* p_line_tbl           => l_line_tbl,*/
                p_action_request_tbl       => l_action_request_tbl,
                -- OUT variables
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
                -- x_valid_flag := 'N';
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
    -- Procedure/Function Name   : pick_release_prc
    -- Decription                : Auto Pick Release and Ship confirm of Ecommerce Orders.
    --                             1. Using wsh_delivery_details_pub.autocreate_deliveries to create delivery
    --                             2. Invoking Pick_Release to process pick release
    --                             3. Invoking Ship_confirm to Confirm the Shipping Sales Orders
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -- p_order_source_id IN
    -- p_order_type_id   IN
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE pick_release_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                , p_order_type_id IN NUMBER)
    IS
        CURSOR c_del_details IS
            SELECT DISTINCT delivery_id
              FROM apps.oe_order_headers_all oha, apps.oe_order_lines_all ola, apps.wsh_delivery_details wdd,
                   wsh_delivery_assignments wda
             WHERE     oha.header_id = ola.header_id
                   AND oha.org_id = ola.org_id
                   AND oha.header_id = wdd.source_header_id
                   AND ola.line_id = wdd.source_line_id
                   AND oha.booked_flag = 'Y'
                   AND NVL (ola.cancelled_flag, 'N') <> 'Y'
                   AND wdd.released_status = 'Y'
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND oha.order_type_id = p_order_type_id
                   AND oha.order_source_id = p_order_source_id
                   AND oha.org_id = gn_org_id;

        -- Commented by Viswanathan Pandian for CCR0005950
        /*AND EXISTS
      (SELECT 'Y'
               FROM xxdo.xxdo_wms_3pl_adj_l ls
              WHERE TO_CHAR(ls.adj_line_id) = ola.orig_sys_line_ref
                AND ls.process_status = gc_process_import); */
        -- Commented by Viswanathan Pandian for CCR0005950

        CURSOR c_req_date IS
            SELECT MIN (ola.request_date), MAX (ola.request_date), MAX (ola.ship_from_org_id)
              FROM apps.oe_order_headers_all oha, apps.oe_order_lines_all ola, apps.wsh_delivery_details wdd,
                   wsh_delivery_assignments wda
             WHERE     oha.header_id = ola.header_id
                   AND oha.org_id = ola.org_id
                   AND oha.header_id = wdd.source_header_id
                   AND ola.line_id = wdd.source_line_id
                   AND oha.booked_flag = 'Y'
                   AND NVL (ola.cancelled_flag, 'N') <> 'Y'
                   AND wdd.released_status IN ('R', 'B')
                   AND ola.flow_status_code = 'AWAITING_SHIPPING'
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wda.delivery_id IS NULL
                   AND oha.order_type_id = p_order_type_id
                   AND oha.order_source_id = p_order_source_id
                   AND oha.org_id = gn_org_id;

        -- Commented by Viswanathan Pandian for CCR0005950
        /*AND EXISTS
      (SELECT 'Y'
               FROM xxdo.xxdo_wms_3pl_adj_l ls
              WHERE TO_CHAR(ls.adj_line_id) = ola.orig_sys_line_ref
                AND ls.process_status = gc_process_import); -- imported*/
        -- Commented by Viswanathan Pandian for CCR0005950

        TYPE t_del_details_rec IS TABLE OF c_del_details%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_del_details_rec      t_del_details_rec;

        /*   CURSOR c_ord_details(lv_order_type_id   IN NUMBER,
                                  lv_order_source_id IN NUMBER,
                                  lv_org_id          IN NUMBER) IS
             SELECT oha.order_number sales_order,
                    oha.org_id,
                    ola.line_number,
                    ola.shipment_number,
                    ola.flow_status_code,
                    wdd.delivery_detail_id,
                    wdd.inv_interfaced_flag,
                    wdd.oe_interfaced_flag,
                    wdd.released_status
               FROM apps.oe_order_headers_all oha,
                    apps.oe_order_lines_all   ola,
                    apps.wsh_delivery_details wdd,
                    wsh_delivery_assignments  wda
              WHERE oha.header_id = ola.header_id
                AND oha.org_id = ola.org_id
                AND oha.header_id = wdd.source_header_id
                AND ola.line_id = wdd.source_line_id
                AND oha.booked_flag = 'Y'
                AND NVL(ola.cancelled_flag, 'N') <> 'Y'
                AND wdd.released_status IN ('R', 'B')
                AND ola.flow_status_code = 'AWAITING_SHIPPING'
                AND wda.delivery_detail_id = wdd.delivery_detail_id
                AND wda.delivery_id IS NULL
                AND oha.order_type_id = lv_order_type_id
                AND oha.order_source_id = lv_order_source_id
                AND oha.org_id = lv_org_id
                AND EXISTS
              (SELECT 'Y'
                       FROM xxdo.xxdo_wms_3pl_adj_l ls
                      WHERE TO_CHAR(ls.adj_line_id) = ola.orig_sys_line_ref
                        AND ls.process_status = gc_process_import); -- imported

           CURSOR cur_oe_error_delivery(p_delivery_detail_id in number) IS
             SELECT ola.orig_sys_line_ref
               FROM apps.oe_order_lines_all ola, apps.wsh_delivery_details wdd
              WHERE 1 = 1
                AND ola.line_id = wdd.source_line_id
                AND ola.header_id = wdd.source_header_id
                and wdd.delivery_detail_id = p_delivery_detail_id;

           CURSOR cur_oe_err_pick(p_delivery_id in number) is
             SELECT ola.orig_sys_line_ref
               FROM apps.oe_order_lines_all   ola,
                    apps.wsh_delivery_details wdd,
                    wsh_delivery_assignments  wda
              WHERE 1 = 1
                AND ola.line_id = wdd.source_line_id
                AND ola.header_id = wdd.source_header_id
                AND wda.delivery_detail_id = wdd.delivery_detail_id
                AND wda.delivery_id = p_delivery_id;*/

        lv_line_row            wsh_util_core.id_tab_type;
        lv_line_err_row        wsh_util_core.id_tab_type;
        lv_commit              VARCHAR2 (50) := fnd_api.g_true;
        exep_api               EXCEPTION;
        x_return_status        VARCHAR2 (2);
        x_msg_count            NUMBER;
        x_msg_data             VARCHAR2 (4000);
        x_del_rows             wsh_util_core.id_tab_type;
        x_msg_summary          VARCHAR2 (2000);
        x_msg_details          VARCHAR2 (2000);
        lv_delivery_id         wsh_util_core.id_tab_type;
        lv_delivery_pick_id    wsh_util_core.id_tab_type;
        x_trip_id              VARCHAR2 (30);
        x_trip_name            VARCHAR2 (30);
        lv_line_err_pick_row   wsh_util_core.id_tab_type;
        lv_request_id          NUMBER;
        lc_dev_phase           VARCHAR2 (30) := NULL;
        lc_dev_status          VARCHAR2 (30) := NULL;
        lb_wait                BOOLEAN;
        lc_phase               VARCHAR2 (30) := NULL;
        lc_status              VARCHAR2 (30) := NULL;
        lc_message             VARCHAR2 (2000);
        lv_request_id1         NUMBER;
        lc_dev_phase1          VARCHAR2 (30) := NULL;
        lc_dev_status1         VARCHAR2 (30) := NULL;
        lb_wait1               BOOLEAN;
        lc_phase1              VARCHAR2 (30) := NULL;
        lc_status1             VARCHAR2 (30) := NULL;
        lc_message1            VARCHAR2 (2000);
        lv_adj_line_id         gt_adj_line_id_tbl;
        lv_concreqcallstat     BOOLEAN := FALSE;
        ld_min_req_date        DATE;
        ld_max_req_date        DATE;
        ln_ship_from_org_id    NUMBER;
        lc_boolean2            BOOLEAN;
    BEGIN
        OPEN c_req_date;

        FETCH c_req_date INTO ld_min_req_date, ld_max_req_date, ln_ship_from_org_id;

        CLOSE c_req_date;


        IF     ld_min_req_date IS NOT NULL
           AND ld_min_req_date IS NOT NULL
           AND ln_ship_from_org_id IS NOT NULL
        THEN
            fnd_request.set_org_id (fnd_global.org_id);

            lc_boolean2   :=
                fnd_request.add_layout (
                    template_appl_name   => 'XXDO',
                    template_code        => 'DO_PICK_RELEASE',
                    template_language    => 'en', --Use language from template definition
                    template_territory   => 'US', --Use territory from template definition
                    output_format        => 'EXCEL' --Use output format from template definition
                                                   );

            lv_request_id1   :=
                apps.fnd_request.submit_request (application => 'XXDO', program => 'DO_PICK_RELEASE', description => 'Pick Release - Deckers', start_time => TO_CHAR (SYSDATE, 'DD-MON-YY'), sub_request => FALSE, argument1 => 'Commit Only Mode', -- Changed from Commit Mode by Viswanathan Pandian for CCR0005950
                                                                                                                                                                                                                                                    argument2 => ln_ship_from_org_id, argument3 => NULL, argument4 => NULL, argument5 => TO_CHAR (SYSDATE - 55, 'DD-MON-YYYY'), argument6 => TO_CHAR (SYSDATE, 'DD-MON-YYYY'), argument7 => NULL, argument8 => NULL, argument9 => NULL, argument10 => NULL, argument11 => NULL, argument12 => '100', argument13 => '100', argument14 => '100', argument15 => '100', argument16 => '1', argument17 => '0', argument18 => gc_order_source_nm, argument19 => NULL
                                                 , argument20 => NULL -- Added by Sivakumar boothathan for CCR0006185
                                                                     );
            COMMIT;

            lv_concreqcallstat   :=
                apps.fnd_concurrent.wait_for_request (lv_request_id1,
                                                      5, -- wait 5 seconds between db checks
                                                      0,
                                                      lc_phase1,
                                                      lc_status1,
                                                      lc_dev_phase1,
                                                      lc_dev_status1,
                                                      lc_message1);

            IF ((UPPER (lc_dev_phase1) = 'COMPLETE') OR (UPPER (lc_phase1) = 'COMPLETED'))
            THEN
                OPEN c_del_details;

                FETCH c_del_details BULK COLLECT INTO l_del_details_rec;

                CLOSE c_del_details;

                IF l_del_details_rec.COUNT > 0
                THEN
                    FOR i IN 1 .. l_del_details_rec.COUNT
                    LOOP
                        ship_confirm (l_del_details_rec (i).delivery_id,
                                      x_return_status);
                        write_log (
                            'Ship Confirm with status ' || x_return_status);
                    END LOOP;

                    --Trip Stops Program
                    BEGIN
                        lv_request_id   := 0;

                        SELECT request_id
                          INTO lv_request_id
                          FROM fnd_concurrent_requests
                         WHERE     concurrent_program_id =
                                   (SELECT concurrent_program_id
                                      FROM fnd_concurrent_programs_vl
                                     WHERE user_concurrent_program_name =
                                           'Interface Trip Stop')
                               AND phase_code <> 'C';
                    EXCEPTION
                        WHEN NO_DATA_FOUND
                        THEN
                            lv_request_id   := 0;
                            write_log (
                                'No Interface Trip Stop Request was Triggered ');
                        WHEN OTHERS
                        THEN
                            write_log (
                                'Error in Get Interface Trip Stop Rquest Id');
                            lv_request_id   := 0;
                    END;

                    IF lv_request_id > 0
                    THEN
                        LOOP
                            lc_dev_phase    := NULL;
                            lc_dev_status   := NULL;
                            lb_wait         :=
                                fnd_concurrent.wait_for_request (
                                    request_id   => lv_request_id --ln_concurrent_request_id
                                                                 ,
                                    interval     => 1,
                                    max_wait     => 1,
                                    phase        => lc_phase,
                                    status       => lc_status,
                                    dev_phase    => lc_dev_phase,
                                    dev_status   => lc_dev_status,
                                    MESSAGE      => lc_message);

                            IF ((UPPER (lc_dev_phase) = 'COMPLETE') OR (UPPER (lc_phase) = 'COMPLETED'))
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;
                    END IF;

                    --   DBMS_OUTPUT.put_line('STEP44' || x_return_status);

                    -- Commented by Viswanathan Pandian for CCR0005950
                    /*
                    -- updating staging table with status 'P'
                    BEGIN
                      lv_adj_line_id.DELETE;

                      SELECT l.orig_sys_line_ref BULK COLLECT
                        INTO lv_adj_line_id
                        FROM oe_order_lines_all l, oe_order_headers_all h
                       WHERE h.order_type_id = p_order_type_id
                         AND h.order_source_id = p_order_source_id
                         AND h.header_id = l.header_id
                         AND h.org_id = l.org_id
                         AND h.org_id = gn_org_id
                         AND h.flow_status_code = 'BOOKED'
                         AND l.flow_status_code IN ('SHIPPED')
                         AND EXISTS
                       (SELECT 'Y'
                                FROM xxdo.xxdo_wms_3pl_adj_l ls
                               WHERE TO_CHAR(ls.adj_line_id) = l.orig_sys_line_ref
                                 AND ls.process_status = gc_process_import);

                      write_log(' Pick lv_adj_line_id.COUNT ' || lv_adj_line_id.COUNT || ' ' ||
                                SYSDATE);
                    EXCEPTION
                      WHEN OTHERS THEN
                        lv_adj_line_id.DELETE;
                        write_log('Exception while get adj_line_id in Pick Release Prc');
                    END;

                    IF lv_adj_line_id.COUNT > 0 THEN
                      FOR i IN 1 .. lv_adj_line_id.COUNT LOOP
                        write_log('UPDATING WITH ' || lv_adj_line_id(i));
                        updating_process_status(gc_process_shipped,
                                                'SO Shipped',
                                                TO_NUMBER(lv_adj_line_id(i)));
                      END LOOP;
                    END IF;*/
                    -- Commented by Viswanathan Pandian for CCR0005950

                    write_log ('-5.1 End Pick Release PRC');
                END IF;
            END IF;
        END IF;
    /*   x_return_status := wsh_util_core.g_ret_sts_success;
       x_msg_count     := NULL;
       x_msg_data      := NULL;
       x_msg_summary   := NULL;
       x_msg_details   := NULL;
       write_log('--5.1 IN Package ' || gc_package_name || ' Pick Release');
       write_log('Org_id:' || l_org_id);
       write_log('Calling WSH_DELIVERY_DETAILS_PUB to Perform AutoCreate Delivery');

       FOR ord_details IN c_ord_details(p_order_type_id,
                                        p_order_source_id,
                                        l_org_id) LOOP
         write_log('-5.1.1 Inside loop');
         lv_line_row(1) := ord_details.delivery_detail_id;
         -- Auto Create delivery for Shipping Sales orders
         wsh_delivery_details_pub.autocreate_deliveries(p_api_version_number => 1.0,
                                                        p_init_msg_list      => apps.fnd_api.g_true,
                                                        p_commit             => lv_commit,
                                                        x_return_status      => x_return_status,
                                                        x_msg_count          => x_msg_count,
                                                        x_msg_data           => x_msg_data,
                                                        p_line_rows          => lv_line_row,
                                                        x_del_rows           => x_del_rows);

         IF x_return_status <> wsh_util_core.g_ret_sts_success THEN
           lv_line_err_row(lv_line_err_row.COUNT + 1) := ord_details.delivery_detail_id;
           write_log('autocreate_deliveries for Order' ||
                     ord_details.sales_order);
           RAISE exep_api;
         ELSE
           COMMIT;
           write_log('Success:  Auto create delivery');
         END IF;
         --Pick Release
         lv_delivery_id(lv_delivery_id.COUNT + 1) := x_del_rows(1);
       END LOOP;
       --PICK error update the stage table
       IF lv_line_err_row.COUNT > 0 THEN
         FOR i in 1 .. lv_line_err_pick_row.count loop
           FOR delivery_crt_err in cur_oe_error_delivery(lv_line_err_pick_row(i)) loop
             updating_process_status(gc_process_error,
                                     'Auto create delivery Error',
                                     TO_NUMBER(delivery_crt_err.orig_sys_line_ref));
           END LOOP;
         end loop;
       END IF;
       write_log('Calling WSH_DELIVERIS_PUB to Perform Pick Release of SO');
       FOR i IN 1 .. lv_delivery_id.COUNT LOOP
         -- API Call for Pick Release
         pick_release(lv_delivery_id(i),
                      TO_CHAR(lv_delivery_id(i)),
                      x_return_status,
                      x_msg_count,
                      x_msg_data,
                      x_trip_id,
                      x_trip_name);

         IF x_return_status <> wsh_util_core.g_ret_sts_success THEN
           lv_line_err_pick_row(lv_line_err_pick_row.COUNT + 1) := lv_delivery_id(i);
           write_log('Pick Release Status' || x_return_status);
           RAISE exep_api;
         ELSE
           lv_delivery_pick_id(lv_delivery_pick_id.COUNT + 1) := lv_delivery_id(i);
           write_log('Success: Pick Release');
           --  DBMS_OUTPUT.put_line('STEP44' || lv_delivery_id);
         END IF;

         BEGIN
           lv_request_id := 0;

           SELECT request_id
             INTO lv_request_id
             FROM fnd_concurrent_requests
            WHERE concurrent_program_id =
                  (SELECT concurrent_program_id
                     FROM fnd_concurrent_programs_vl
                    WHERE user_concurrent_program_name =
                          'Pick Selection List Generation')
              AND phase_code <> 'C';
         EXCEPTION
           WHEN OTHERS THEN
             write_log('Error in Get Pick Release Rquest Id');
             lv_request_id := 0;
         END;

         IF lv_request_id > 0 THEN
           LOOP
             lc_dev_phase  := NULL;
             lc_dev_status := NULL;
             lb_wait       := fnd_concurrent.wait_for_request(request_id => lv_request_id
                                                              --ln_concurrent_request_id
                                                             ,
                                                              INTERVAL   => 1,
                                                              max_wait   => 1,
                                                              phase      => lc_phase,
                                                              status     => lc_status,
                                                              dev_phase  => lc_dev_phase,
                                                              dev_status => lc_dev_status,
                                                              MESSAGE    => lc_message);

             IF ((UPPER(lc_dev_phase) = 'COMPLETE') OR
                (UPPER(lc_phase) = 'COMPLETED')) THEN
               EXIT;
             END IF;
           END LOOP;
         END IF;
       END LOOP;

       IF lv_line_err_pick_row.COUNT > 0 THEN
         for i in 1 .. lv_line_err_pick_row.COUNT loop
           FOR oe_err_pick IN cur_oe_err_pick(lv_line_err_pick_row(i)) loop
             updating_process_status(gc_process_error,
                                     'Pick Release Error',
                                     TO_NUMBER(oe_err_pick.orig_sys_line_ref));
           end loop;

         end loop;
       END IF;

       FOR i IN 1 .. lv_delivery_pick_id.COUNT LOOP
         ship_confirm(lv_delivery_pick_id(i), x_return_status);
         write_log('Ship Confirm with status ' || x_return_status);
       END LOOP;

       --Trip Stops Program
       BEGIN
         lv_request_id := 0;

         SELECT request_id
           INTO lv_request_id
           FROM fnd_concurrent_requests
          WHERE concurrent_program_id =
                (SELECT concurrent_program_id
                   FROM fnd_concurrent_programs_vl
                  WHERE user_concurrent_program_name = 'Interface Trip Stop')
            AND phase_code <> 'C';
       EXCEPTION
         WHEN NO_DATA_FOUND THEN
           lv_request_id := 0;
           write_log('No Interface Trip Stop Request was Triggered ');
         WHEN OTHERS THEN
           write_log('Error in Get Interface Trip Stop Rquest Id');
           lv_request_id := 0;
       END;

       IF lv_request_id > 0 THEN
         LOOP
           lc_dev_phase  := NULL;
           lc_dev_status := NULL;
           lb_wait       := fnd_concurrent.wait_for_request(request_id => lv_request_id
                                                            --ln_concurrent_request_id
                                                           ,
                                                            INTERVAL   => 1,
                                                            max_wait   => 1,
                                                            phase      => lc_phase,
                                                            status     => lc_status,
                                                            dev_phase  => lc_dev_phase,
                                                            dev_status => lc_dev_status,
                                                            MESSAGE    => lc_message);

           IF ((UPPER(lc_dev_phase) = 'COMPLETE') OR
              (UPPER(lc_phase) = 'COMPLETED')) THEN
             EXIT;
           END IF;
         END LOOP;
       END IF;

       --   DBMS_OUTPUT.put_line('STEP44' || x_return_status);

       -- updating staging table with status 'P'
       BEGIN
         lv_adj_line_id.DELETE;

         SELECT l.orig_sys_line_ref BULK COLLECT
           INTO lv_adj_line_id
           FROM oe_order_lines_all l, oe_order_headers_all h
          WHERE h.order_type_id = p_order_type_id
            AND h.order_source_id = p_order_source_id
            AND h.header_id = l.header_id
            AND h.org_id = l.org_id
            AND h.org_id = gn_org_id
            AND h.flow_status_code = 'BOOKED'
            AND l.flow_status_code IN ('SHIPPED')
            AND EXISTS
          (SELECT 'Y'
                   FROM xxdo.xxdo_wms_3pl_adj_l ls
                  WHERE TO_CHAR(ls.adj_line_id) = l.orig_sys_line_ref
                    AND ls.process_status = gc_process_import);

         write_log(' Pick lv_adj_line_id.COUNT ' || lv_adj_line_id.COUNT || ' ' ||
                   SYSDATE);
       EXCEPTION
         WHEN OTHERS THEN
           lv_adj_line_id.DELETE;
           write_log('Exception while get adj_line_id in Pick Release Prc');
       END;

       IF lv_adj_line_id.COUNT > 0 THEN
         FOR i IN 1 .. lv_adj_line_id.COUNT LOOP
           write_log('UPDATING WITH ' || lv_adj_line_id(i));
           updating_process_status(gc_process_shipped,
                                   'SO Shipped',
                                   TO_NUMBER(lv_adj_line_id(i)));
         END LOOP;
       END IF;

       write_log('-5.1 End Pick Release PRC');*/
    EXCEPTION
        WHEN exep_api
        THEN
            wsh_util_core.get_messages ('Y', x_msg_summary, x_msg_details,
                                        x_msg_count);
            x_msg_data   :=
                   SUBSTR (x_msg_summary, 1, 2000)
                || SUBSTR (x_msg_details, 1, 2000);
            ROLLBACK;
            write_log ('Error in Pick Release' || x_msg_data);
        --    DBMS_OUTPUT.PUT_LINE('Error in Pick Release' || x_msg_data);
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
    END pick_release_prc;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : ship_confirm
    -- Decription                : Using API to do the Shipping Confirm
    -- Parameters
    -- p_delivery_id          IN
    -- x_return_status        OUT
    --
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE ship_confirm (p_delivery_id     IN     NUMBER,
                            x_return_status      OUT VARCHAR2)
    IS
        -- Start : Commented by Infosys for CCR0006678- version 1.4
        /* x_msg_summary   VARCHAR2 (2000);
           x_msg_details   VARCHAR2 (2000);*/
        -- End : Commented by Infosys for CCR0006678- version 1.4

        x_msg_summary   VARCHAR2 (4000); --Modified by Infosys for CCR0006678- version 1.4
        x_msg_details   VARCHAR2 (4000); --Modified by Infosys for CCR0006678- version 1.4
        x_msg_count     NUMBER;
        lx_msg_count    NUMBER;
        lx_msg_data     VARCHAR2 (4000);
        lx_trip_id      VARCHAR2 (30);
        lx_trip_name    VARCHAR2 (30);
        shipexception   EXCEPTION;
    BEGIN
        write_log ('--5.3.1 In Ship Confirm');
        x_msg_summary   := NULL;
        x_msg_details   := NULL;
        x_msg_count     := NULL;
        lx_msg_count    := NULL;
        lx_msg_data     := NULL;
        apps.wsh_deliveries_pub.delivery_action (
            p_api_version_number        => 1.0,
            p_init_msg_list             => NULL,
            x_return_status             => x_return_status,
            x_msg_count                 => lx_msg_count,
            x_msg_data                  => lx_msg_data,
            p_action_code               => 'CONFIRM',
            p_delivery_id               => p_delivery_id,
            p_sc_action_flag            => 'S',
            p_sc_intransit_flag         => 'Y',
            p_sc_close_trip_flag        => 'Y',
            p_sc_defer_interface_flag   => 'N',
            --Need Trip Stop.
            x_trip_id                   => lx_trip_id,
            x_trip_name                 => lx_trip_name);

        IF (x_return_status <> wsh_util_core.g_ret_sts_success)
        THEN
            RAISE shipexception;
        ELSE
            COMMIT;
            write_log (
                   'The confirm action on the delivery '
                || p_delivery_id
                || ' is successful');
        END IF;
    EXCEPTION
        WHEN shipexception
        THEN
            wsh_util_core.get_messages ('Y', x_msg_summary, x_msg_details,
                                        x_msg_count);

            IF x_msg_count > 1
            THEN
                lx_msg_data   :=
                       SUBSTR (x_msg_summary, 1, 2000)
                    || SUBSTR (x_msg_details, 1, 2000);
                write_log ('Message Data : ' || lx_msg_data);
            ELSE
                lx_msg_data   := x_msg_summary;
                write_log ('Message Data : ' || lx_msg_data);
            END IF;
        --  DBMS_OUTPUT.put_line('STEP55' || lx_msg_data);
        WHEN OTHERS
        THEN
            write_log (
                   'Exception in Wsh_Deliveries_Pub.DELIVERY_ACTION: '
                || SQLERRM);
    END ship_confirm;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : rcv_orders_process_prc
    -- Decription                : Post order import process automatic receipts needs to performed
    --                             to increment inventory for all line types
    --                               of  Line Flow - Return with Receipt Only, No Credit  in Awaiting Return status.
    --                            1. Insert return orders information into RCV interface tables
    --                            2. invoking procedure 'auto_receipt_retn_orders'
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -- p_order_source_id IN
    -- p_order_type_id   IN
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE rcv_orders_process_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                      , p_order_type_id IN NUMBER)
    IS
        CURSOR cur_ret_order_info (p_order_source_id IN NUMBER, p_order_type_id IN NUMBER, p_org_id IN NUMBER)
        IS
            SELECT DISTINCT oh.sold_to_org_id customer_id, oh.header_id
              FROM oe_order_headers_all oh, oe_order_lines_all ol
             WHERE     oh.header_id = ol.header_id
                   AND oh.org_id = ol.org_id
                   AND oh.booked_flag = 'Y'
                   AND NVL (ol.cancelled_flag, 'N') <> 'Y'
                   AND ol.flow_status_code = 'AWAITING_RETURN'
                   AND oh.order_source_id = p_order_source_id
                   AND oh.order_type_id = p_order_type_id
                   AND oh.org_id = p_org_id
                   -- Start code change by Viswanathan Pandian for CCR0005950
                   AND NOT EXISTS
                           (SELECT 1
                              FROM rcv_transactions_interface
                             WHERE oe_order_line_id = ol.line_id);

        /*AND EXISTS
      (SELECT 'Y'
               FROM xxdo.xxdo_wms_3pl_adj_l ls
              WHERE TO_CHAR(ls.adj_line_id) = ol.orig_sys_line_ref
                AND ls.process_status = gc_process_import);*/
        -- End code change by Viswanathan Pandian for CCR0005950

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
                   --AND ol.org_id = p_org_id--Viswa
                   AND hou.organization_id = ol.ship_from_org_id
                   AND ol.flow_status_code = 'AWAITING_RETURN'
                   AND ol.booked_flag = 'Y';

        -- Commented by Viswanathan Pandian for CCR0005950
        /*AND EXISTS
      (SELECT 'Y'
               FROM xxdo.xxdo_wms_3pl_adj_l ls
              WHERE TO_CHAR(ls.adj_line_id) = ol.orig_sys_line_ref
                AND ls.process_status = 'I'); -- Imported*/
        -- Commented by Viswanathan Pandian for CCR0005950

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

            /*  dbms_output.put_line('step 11' || gn_org_id || ' ' || ND_PROFILE.VALUE('ORG_ID') || ' ');*/
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
                /* dbms_output.put_line('step 22' || lv_org_id);*/
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
                         VALUES (rcv_transactions_interface_s.NEXTVAL, --INTERFACE_TRANSACTION_ID
                                                                       rcv_interface_groups_s.CURRVAL, --GROUP_ID
                                                                                                       rcv_headers_interface_s.CURRVAL, --HEADER_INTERFACE_ID
                                                                                                                                        SYSDATE, --LAST_UPDATE_DATE
                                                                                                                                                 gn_user_id, --LAST_UPDATED_BY
                                                                                                                                                             SYSDATE, --CREATION_DATE
                                                                                                                                                                      gn_user_id, --CREATED_BY
                                                                                                                                                                                  'RECEIVE', --TRANSACTION_TYPE
                                                                                                                                                                                             SYSDATE, --TRANSACTION_DATE
                                                                                                                                                                                                      'PENDING', --PROCESSING_STATUS_CODE
                                                                                                                                                                                                                 'BATCH', --PROCESSING_MODE_CODE
                                                                                                                                                                                                                          'PENDING', --TRANSACTION_MODE_CODE
                                                                                                                                                                                                                                     ret_order_details.ordered_quantity, --QUANTITY
                                                                                                                                                                                                                                                                         ret_order_details.uom, --UNIT_OF_MEASURE
                                                                                                                                                                                                                                                                                                'RCV', --INTERFACE_SOURCE_CODE
                                                                                                                                                                                                                                                                                                       ret_order_details.inventory_item_id, --ITEM_ID
                                                                                                                                                                                                                                                                                                                                            lv_employee_id, --EMPLOYEE_ID
                                                                                                                                                                                                                                                                                                                                                            'DELIVER', --AUTO_TRANSACT_CODE
                                                                                                                                                                                                                                                                                                                                                                       'CUSTOMER', --RECEIPT_SOURCE_CODE
                                                                                                                                                                                                                                                                                                                                                                                   ret_order_details.ship_from_org_id, --TO_ORGANIZATION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                       'RMA', --SOURCE_DOCUMENT_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                              'INVENTORY', --DESTINATION_TYPE_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                           ret_order_details.location_id, --DELIVER_TO_LOCATION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ret_order_details.subinventory, --SUBINVENTORY
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          SYSDATE, --EXPECTED_RECEIPT_DATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   ret_order_details.header_id, --OE_ORDER_HEADER_ID
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

        IF lv_count > 0
        THEN
            auto_receipt_retn_orders (lv_org_id,
                                      lv_request_id,
                                      x_return_status);
            write_log ('Auto Receipt Return Status ' || x_return_status);

            IF x_return_status <> gc_ret_success
            THEN
                write_log ('Error in Receiving Transaction Processor');
                RAISE return_process_exp;
            -- Commented by Viswanathan Pandian for CCR0005950
            /*ELSE
              BEGIN
                lv_adj_line_id.DELETE;

                SELECT l.orig_sys_line_ref BULK COLLECT
                  INTO lv_adj_line_id
                  FROM oe_order_lines_all l, oe_order_headers_all h
                 WHERE h.order_type_id = p_order_type_id
                   AND h.order_source_id = p_order_source_id
                   AND h.header_id = l.header_id
                   AND h.org_id = l.org_id
                   AND h.org_id = gn_org_id
                   AND h.flow_status_code = 'BOOKED'
                   AND l.flow_status_code = 'RETURNED'
                   AND exists
                 (SELECT l.orig_sys_line_ref
                          FROM xxdo.xxdo_wms_3pl_adj_l ls
                         WHERE TO_CHAR(ls.adj_line_id) = l.orig_sys_line_ref
                           AND ls.process_status = gc_process_import);
              EXCEPTION
                WHEN OTHERS THEN
                  lv_adj_line_id.DELETE;
                  write_log('Exception while get adj_line_id in Create Sales Order Prc');
              END;

              IF lv_adj_line_id.COUNT > 0 THEN
                FOR i IN 1 .. lv_adj_line_id.COUNT LOOP
                  updating_process_status(gc_process_returned,
                                          'SO Returned',
                                          TO_NUMBER(lv_adj_line_id(i)));

                END LOOP;
                write_log('ret lv_adj_line_id.count ' || lv_adj_line_id.count || ' ' ||
                          SYSDATE);
              END IF;*/
            -- Commented by Viswanathan Pandian for CCR0005950
            END IF;
        END IF;

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
    -- Procedure/Function Name   : auto_receipt_retn_orders
    -- Decription                : Receiving Transaction Processor Concurrent program to process interface records
    --
    -- Parameters
    -- p_org_id          IN
    -- x_request_id      OUT
    -- x_return_status   OUT
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE auto_receipt_retn_orders (p_org_id IN NUMBER, x_request_id OUT NUMBER, x_return_status OUT VARCHAR2)
    IS
        lv_request_num   NUMBER;
        lv_message       VARCHAR2 (2000);
        lb_wait          BOOLEAN;
        lv_phase         VARCHAR2 (80);
        lv_status        VARCHAR2 (80);
        lv_dev_phase     VARCHAR2 (30);
        lv_dev_status    VARCHAR2 (30);
    BEGIN
        write_log ('--4.2 Inside Doing auto Recp Transaction Prc');
        -- Launching 'Receiving Transaction Processor' to process the RCV records
        lv_request_num    :=
            fnd_request.submit_request (
                application   => 'PO',
                program       => 'RVCTP',
                description   => 'Receiving Transaction Processor',
                start_time    => SYSDATE,
                argument1     => 'BATCH',
                --Model
                argument2     => NULL,                             -- group_id
                argument3     => p_org_id,
                --Operation Code
                argument4     => CHR (0));
        COMMIT;
        x_request_id      := lv_request_num;
        write_log ('Return Receive request: ' || TO_CHAR (lv_request_num));

        IF lv_request_num > 0
        THEN
            LOOP
                lb_wait   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => lv_request_num --ln_concurrent_request_id
                                                      ,
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

        x_return_status   := gc_ret_success;
        -- Commented by Viswanathan Pandian for CCR0005950
        /*FOR error_rcv in (SELECT ol.orig_sys_line_ref, pe.error_message
                            FROM po_interface_errors        pe,
                                 rcv_transactions_interface rti,
                                 oe_order_lines_all         ol
                           WHERE rti.interface_transaction_id =
                                 pe.interface_line_id
                             AND rti.receipt_source_code = 'CUSTOMER'
                             and ol.header_id = rti.oe_order_header_id
                             and ol.line_id = rti.oe_order_line_id
                             and exists
                           (SELECT 'Y'
                                    FROM xxdo.xxdo_wms_3pl_adj_l ls
                                   WHERE TO_CHAR(ls.adj_line_id) =
                                         ol.orig_sys_line_ref
                                     AND ls.process_status = 'S')) LOOP
          updating_process_status(gc_process_error,
                                  error_rcv.error_message,
                                  TO_NUMBER(error_rcv.orig_sys_line_ref));

        END LOOP;*/
        -- Commented by Viswanathan Pandian for CCR0005950

        write_log ('Return Receive Status: ' || x_return_status);
        write_log ('--End  Doing auto Recp Transaction Prc');
    EXCEPTION
        WHEN OTHERS
        THEN
            write_log ('Error in Submit Receiving Transaction Processor');
            write_log (SQLERRM);
            x_return_status   := gc_ret_error;
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : generate_exception_notifaction
    -- Decription                : Generate the exception notifaction to Ecommerce contact.
    --                             1. If there are adjustment records from 3PL (in staging table)
    --                                  that has not been flipped into an order (stuck there for more than 3 days)
    --                              2. If auto pick /ship process fails for the ecommerce shipment records
    --                             3. If auto receipt process fails for the ecommerce return records
    --                              4. If ship only sales orders are open / not processed for more than a couple of days
    -- Parameters
    -- retcode          OUT
    -- errbuf            OUT
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -----------------------------------------------------------------------------------
    PROCEDURE generate_exception_notifaction (retcode   OUT VARCHAR2,
                                              errbuf    OUT VARCHAR2)
    IS
        --If there are adjustment records from 3PL (in staging table) that has not been flipped into an order (stuck there for more than 3 days)
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

        -- Commented by Viswanathan Pandian for CCR0005950
        /*
        --If auto pick /ship process fails for the ecommerce shipment records
        --If auto receipt process fails for the ecommerce return records
        CURSOR cur_so_processed_error IS
          SELECT wal.adj_header_id,
                 wal.adj_line_id,
                 wal.sku_code,
                 wal.inventory_item_id,
                 wal.process_status,
                 wal.error_message
            FROM xxdo.xxdo_wms_3pl_adj_l wal
           WHERE wal.process_status = 'E'
             AND adj_type_code IN
                 (SELECT lookup_code
                    FROM fnd_lookup_values_vl flv
                   WHERE flv.lookup_type = gc_order_mapping
                     AND flv.enabled_flag = 'Y');*/
        -- Commented by Viswanathan Pandian for CCR0005950

        --If ship only sales orders are open / not processed for more than a couple of days
        CURSOR cur_open_ship_so IS
            (SELECT TO_CHAR (oh.order_number) order_number, -- Added TO_CHAR by Viswanathan Pandian for CCR0005950
                                                            ol.line_number, ol.ordered_item,
                    ol.flow_status_code
               FROM oe_order_headers_all oh, oe_order_lines_all ol
              WHERE     oh.header_id = ol.header_id
                    AND ol.flow_status_code NOT IN ('SHIPPED', 'CLOSED', 'CANCELLED',
                                                    'RETURNED') -- Added RETURNED by Viswanathan Pandian for CCR0005950
                    AND oh.flow_status_code IN ('ENTERED', 'BOOKED')
                    AND ol.org_id = fnd_global.org_id
                    AND ol.line_type_id IN
                            (SELECT DISTINCT wf.line_type_id
                               FROM oe_workflow_assignments wf, oe_transaction_types_vl ott, oe_transaction_types_all ota,
                                    oe_transaction_types_vl otta, fnd_lookup_values_vl flv
                              WHERE     wf.line_type_id =
                                        ott.transaction_type_id
                                    AND wf.line_type_id IS NOT NULL
                                    AND wf.order_type_id =
                                        otta.transaction_type_id
                                    AND ota.transaction_type_id =
                                        ott.transaction_type_id
                                    AND ota.order_category_code = 'ORDER'
                                    AND wf.end_date_active IS NULL
                                    AND otta.name = flv.attribute1
                                    AND flv.lookup_type = gc_order_mapping
                                    AND flv.enabled_flag = 'Y'))
            -- Start code change by Viswanathan Pandian for CCR0005950
            -- AND TRUNC (ol.last_update_date) < TRUNC (SYSDATE - 2));
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
                   AND flv.enabled_flag = 'Y';

        -- End code change by Viswanathan Pandian for CCR0005950

        ln_no_process_cnt            NUMBER := 0;
        --ln_process_cnt             NUMBER := 0;-- Commented by Viswanathan Pandian for CCR0005950
        ln_open_so_cnt               NUMBER := 0;
        stage_no_processed_details   cur_3pl_no_processed%ROWTYPE;
        --so_processed_error_details cur_so_processed_error%ROWTYPE;-- Commented by Viswanathan Pandian for CCR0005950
        open_ship_so_details         cur_open_ship_so%ROWTYPE;
        -- send email parameters
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

        -- Commented by Viswanathan Pandian for CCR0005950
        /*OPEN cur_so_processed_error;

        LOOP
          FETCH cur_so_processed_error
            INTO so_processed_error_details;

          ln_process_cnt := cur_so_processed_error%ROWCOUNT;
          EXIT WHEN cur_so_processed_error%NOTFOUND;
        END LOOP;

        CLOSE cur_so_processed_error;*/
        -- Commented by Viswanathan Pandian for CCR0005950

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
        --write_log('So Processed Error: ' || TO_CHAR(ln_process_cnt));-- Commented by Viswanathan Pandian for CCR0005950
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

        --  lt_users_email_lst(1) := 'supratip.majumdar@deckers.com';

        BEGIN
            /*  SELECT NVL(ppf.email_address, fu.email_address) AS email_address
                INTO lt_users_email_lst(1)
                FROM apps.per_people_f ppf, apps.fnd_user fu
               WHERE fu.user_id = gn_user_id
                 AND ppf.person_id(+) = fu.employee_id;*/

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

        /*  get_email_address_list(l_lookup_type, lt_users_email_lst);*/
        IF lt_users_email_lst.COUNT < 1
        THEN
            RAISE le_mail_exception;
        END IF;

        -- Start code change by Viswanathan Pandian for CCR0005950
        -- IF ln_process_cnt > 0 OR ln_no_process_cnt > 0 OR ln_open_so_cnt > 0 THEN
        IF ln_no_process_cnt > 0 OR ln_open_so_cnt > 0
        THEN
            -- End code change by Viswanathan Pandian for CCR0005950
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

            -- Commented by Viswanathan Pandian for CCR0005950
            /*
            --cur_so_processed_error
            IF ln_process_cnt > 0 THEN
              do_mail_utils.send_mail_line(UTL_TCP.crlf || UTL_TCP.crlf ||
                                           '**Sales Order Lines auto pick /ship process fails for the ecommerce shipment records. Or auto receipt process fails for the ecommerce return records .' ||
                                           UTL_TCP.crlf,
                                           lc_status);
            END IF;*/
            -- Commented by Viswanathan Pandian for CCR0005950

            --cur_3pl_no_processed
            IF ln_no_process_cnt > 0
            THEN
                do_mail_utils.send_mail_line (
                       UTL_TCP.crlf
                    || UTL_TCP.crlf
                    || '**There are adjustment records from 3PL (in staging table) that has not been flipped into an order (stuck there for more than 3 days.'
                    || UTL_TCP.crlf,
                    lc_status);
            END IF;

            --cur_open_ship_so
            IF ln_open_so_cnt > 0
            THEN
                do_mail_utils.send_mail_line (
                       UTL_TCP.crlf
                    || UTL_TCP.crlf
                    -- Start code change by Viswanathan Pandian for CCR0005950
                    --|| '**There are Ship only sales orders are open / not processed for more than a couple of days .'
                    || '**Sales Orders that are open/not processed/stuck in interface for more than a couple of days .'
                    -- End code change by Viswanathan Pandian for CCR0005950
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

            -- Commented by Viswanathan Pandian for CCR0005950
            /*IF ln_process_cnt > 0 THEN
              FOR so_processed_error IN cur_so_processed_error LOOP
                do_mail_utils.send_mail_line(RPAD(so_processed_error.adj_header_id,
                                                  30,
                                                  ' ') || RPAD(so_processed_error.adj_line_id,
                                                               30,
                                                               ' ') ||
                                             RPAD(so_processed_error.sku_code,
                                                  20,
                                                  ' ') || RPAD(so_processed_error.process_status,
                                                               20,
                                                               ' ') ||
                                             so_processed_error.error_message,
                                             lc_status);
              END LOOP;
            END IF;*/
            -- Commented by Viswanathan Pandian for CCR0005950

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

            -- Commented by Viswanathan Pandian for CCR0005950
            /*IF (cur_so_processed_error%ISOPEN) THEN
              CLOSE cur_so_processed_error;
            END IF;*/
            -- Commented by Viswanathan Pandian for CCR0005950

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

            -- Commented by Viswanathan Pandian for CCR0005950
            /*IF (cur_so_processed_error%ISOPEN) THEN
              CLOSE cur_so_processed_error;
            END IF;*/
            -- Commented by Viswanathan Pandian for CCR0005950

            IF (cur_open_ship_so%ISOPEN)
            THEN
                CLOSE cur_open_ship_so;
            END IF;
    END;

    PROCEDURE get_return_reason_code (p_adj_type_code        IN     VARCHAR2,
                                      x_return_reason_code      OUT VARCHAR2)
    IS
    BEGIN
        SELECT flvb.lookup_code
          INTO x_return_reason_code
          FROM fnd_lookup_values_vl flva, fnd_lookup_values_vl flvb
         WHERE     flva.lookup_type = gc_order_mapping
               AND flva.enabled_flag = 'Y'
               AND flva.lookup_code = p_adj_type_code
               AND flva.description = flvb.meaning
               AND flvb.lookup_type = 'CREDIT_MEMO_REASON'
               AND flvb.enabled_flag = 'Y';
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_log (' Return Reason Code : Value is not found.');
            write_output (' Return Reason Code : Value is not found.');
        WHEN OTHERS
        THEN
            x_return_reason_code   := NULL;
            write_log (
                   'Return Reason Code  : ERROR with'
                || SUBSTR (SQLERRM, 1, 2000));
            write_output (
                   'Return Reason Code  : ERROR with'
                || SUBSTR (SQLERRM, 1, 2000));
    END;

    PROCEDURE get_customer (p_item_brand IN VARCHAR2, p_adj_type_code IN VARCHAR2, p_platform IN VARCHAR2
                            ,                    -- Added for CCR : CCR0006261
                              x_customer_acct OUT VARCHAR2, x_customer_id OUT NUMBER, x_sales_channel_code OUT VARCHAR2)
    IS
        lv_customer_num    hz_cust_accounts.account_number%TYPE;
        lv_sales_channel   hz_cust_accounts.sales_channel_code%TYPE;
        lv_customer_id     hz_cust_accounts.cust_account_id%TYPE;
    BEGIN
        write_log ('IN PACKAGE- ' || gc_package_name || ': Get Customer');

        BEGIN
            -------------------------------------
            -- Start changes for CCR : CCR0006261
            -------------------------------------
            /*SELECT h.account_number, h.sales_channel_code, h.cust_account_id
              INTO lv_customer_num, lv_sales_channel, lv_customer_id
              FROM hz_cust_accounts h
             WHERE     h.attribute1 = p_item_brand
                   AND h.status = 'A'
                   AND EXISTS
                          (SELECT 'Y'
                             FROM hz_cust_accounts hca, fnd_lookup_values_vl flv
                            WHERE     flv.lookup_type = gc_order_mapping
                                  AND flv.enabled_flag = 'Y'
                                  AND flv.tag = hca.account_number
                                  AND flv.lookup_code = p_adj_type_code
                                  AND hca.status = 'A'
                                  AND h.party_id = hca.party_id);*/
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
        -------------------------------------
        -- End changes for CCR : CCR0006261
        -------------------------------------
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

    /*  PROCEDURE get_ship_bill_to(p_org_id      IN NUMBER,
                                 p_customer_id IN NUMBER,
                                 x_ship_to     OUT NUMBER,
                                 x_bill_to     OUT NUMBER) IS
        lv_ship_to_id NUMBER;
        lv_bill_to_id NUMBER;
      BEGIN
        write_log('IN PACKAGE- ' || gc_package_name || ': Get Bill To/Ship To');
        lv_ship_to_id := NULL;
        lv_bill_to_id := NULL;

        BEGIN
          SELECT ship_su.site_use_id
            INTO lv_ship_to_id
            FROM hz_cust_acct_sites_all ship_cas,
                 hz_cust_site_uses_all  ship_su,
                 hz_party_sites         ship_ps
           WHERE ship_su.org_id = p_org_id
             AND ship_su.org_id = ship_cas.org_id
             AND site_use_code = 'SHIP_TO'
             AND ship_su.primary_flag = 'Y'
             AND ship_su.cust_acct_site_id = ship_cas.cust_acct_site_id
             AND ship_cas.party_site_id = ship_ps.party_site_id
             AND ship_cas.cust_account_id = p_customer_id
             AND ship_ps.party_site_id IN
                 (SELECT party_site_id
                    FROM hz_party_sites hp, ra_customers rc
                   WHERE hp.party_id = rc.party_id
                     AND rc.customer_id = p_customer_id
                     AND rc.status = 'A');
        EXCEPTION
          WHEN OTHERS THEN
            lv_ship_to_id := NULL;
            write_log('Ship To in Header: ERROR with' || SQLERRM);
        END;

        IF lv_ship_to_id IS NULL THEN
          BEGIN
            SELECT ship_su.site_use_id
              INTO lv_ship_to_id
              FROM hz_cust_acct_sites_all ship_cas,
                   hz_cust_site_uses_all  ship_su
             WHERE ship_su.org_id = p_org_id
               AND ship_su.org_id = ship_cas.org_id
               AND ship_su.site_use_code = 'SHIP_TO'
               AND ship_su.primary_flag = 'Y'
               AND ship_su.cust_acct_site_id = ship_cas.cust_acct_site_id
               AND ship_cas.party_site_id IN
                   (SELECT party_site_id
                      FROM hz_party_sites hp, ra_customers rc
                     WHERE hp.party_id = rc.party_id
                       AND rc.customer_id = p_customer_id
                       AND rc.status = 'A');
          EXCEPTION
            WHEN OTHERS THEN
              lv_ship_to_id := NULL;
              write_log('Ship To in Header: ERROR with' || SQLERRM);
          END;
        END IF;

        BEGIN
          SELECT bill_su.site_use_id
            INTO lv_bill_to_id
            FROM hz_cust_acct_sites_all bill_cas,
                 hz_cust_site_uses_all  bill_su,
                 hz_party_sites         bill_ps
           WHERE bill_su.org_id = p_org_id
             AND bill_su.org_id = bill_cas.org_id
             AND site_use_code = 'BILL_TO'
             AND bill_su.primary_flag = 'Y'
             AND bill_su.cust_acct_site_id = bill_cas.cust_acct_site_id
             AND bill_cas.party_site_id = bill_ps.party_site_id
             AND bill_cas.cust_account_id = p_customer_id
             AND bill_ps.party_site_id IN
                 (SELECT party_site_id
                    FROM hz_party_sites hp, ra_customers rc
                   WHERE hp.party_id = rc.party_id
                     AND rc.customer_id = p_customer_id
                     AND rc.status = 'A');
        EXCEPTION
          WHEN OTHERS THEN
            lv_bill_to_id := NULL;
            write_log('Bill To in Header: ERROR with' || SQLERRM);
        END;

        x_ship_to := lv_ship_to_id;
        x_bill_to := lv_bill_to_id;
      END get_ship_bill_to;*/

    --GET LINE TYPE ID
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

    PROCEDURE get_salesrep_id (p_org_id IN NUMBER, x_salesrep_id OUT NUMBER)
    IS
    BEGIN
        SELECT salesrep_id
          INTO x_salesrep_id
          FROM ra_salesreps_all
         WHERE name = 'No Sales Credit' AND org_id = p_org_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            write_log (
                'SalesRep ID in Header : ''No Sales Credit'' is not found.');
        WHEN OTHERS
        THEN
            x_salesrep_id   := NULL;
            write_log (
                   'SalesRep ID in Header : ERROR with'
                || SUBSTR (SQLERRM, 1, 2000));
    END;

    -----------------------------------------------------------------------------------
    -- Procedure/Function Name   : so_interface_load_prc
    -- Decription                : Converting  Ecommerce material transactions to sales orders
    --
    -- Parameters
    -- x_errbuf           OUT
    -- x_retcode          OUT
    -- p_order_source_id   IN
    -- p_order_type_id     IN
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
    -- Siva B          23-Aug-2017                   For CCR : CCR0006261
    -----------------------------------------------------------------------------------
    PROCEDURE so_interface_load_prc (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, p_order_source_id IN NUMBER
                                     , p_order_type_id IN NUMBER)
    IS
        -- Cursor For Get Staging table information
        CURSOR wms_3pl_adj_cur IS
            --ECOMMERCE
            SELECT -------------------------------------------------------
                   -- Commented for CCR : CCR0006261
                   --------------------------------------------------------
                   /*ROW_NUMBER ()
                          OVER (PARTITION BY mc.segment1, wah.adj_type_code
                                ORDER BY mc.segment1)
                             AS rnum,
                             MIN (wah.adj_header_id)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                          || '-'
                          || MAX (wah.adj_header_id)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                             AS orig_sys_doc_ref,
                             MIN (wah.adjust_date)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                          || '-'
                          || MAX (wah.adjust_date)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                             AS cust_po_num,*/
                   ------------------------------------------------------------
                   -- Commented for CCR : CCR0006261
                   ------------------------------------------------------------
                   ------------------------------------------------------------
                   -- Added for CCR : CCR0006261
                   ------------------------------------------------------------
                   ROW_NUMBER () OVER (PARTITION BY wah.adj_header_id, wah.adj_type_code ORDER BY wah.adj_header_id) AS rnum, MIN (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS orig_sys_doc_ref, MIN (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS cust_po_num,
                   ----------------------------------------------------------------------
                   -- End of addition for CCR :    CCR0006261 by Siva B
                   ----------------------------------------------------------------------
                   mc.segment1 brand, wah.adj_header_id, wah.adjust_date,
                   wal.adj_line_id, TO_NUMBER (-wal.quantity_to_adjust) quantity_to_adjust, wal.inventory_item_id,
                   wal.sku_code, wal.transaction_id, wah.organization_id,
                   wah.adj_type_code, wal.adj_type_code adj_line_type_code, wal.subinventory_code,
                   wah.ecom_platform platform -- Added by Siva B for CCR : CCR0006261
              FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, mtl_system_items_b mtl,
                   mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                   org_organization_definitions org, oe_transaction_types_vl ott, oe_transaction_types_all ota,
                   apps.fnd_lookup_values_vl flv
             WHERE     wah.process_status = 'P'
                   AND wal.process_status = 'O'
                   AND wal.adj_type_code = 'ECOMMERCE'
                   AND mcs.category_set_name = 'Inventory'
                   AND wah.adj_header_id = wal.adj_header_id
                   AND mtl.inventory_item_id = wal.inventory_item_id
                   AND mtl.organization_id = wah.organization_id
                   AND mtl.inventory_item_id = mic.inventory_item_id
                   AND mtl.organization_id = mic.organization_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mc.category_id = mic.category_id
                   AND mtl.organization_id = org.organization_id
                   AND ott.name = flv.attribute1
                   AND flv.lookup_type = gc_order_mapping
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code =
                       NVL (wah.adj_type_code, wal.adj_type_code)
                   AND ott.transaction_type_id = ota.transaction_type_id
            --AND ORG.OPERATING_UNIT = gn_org_id--Viswa
            UNION ALL
            --Hk Ecommerce
            SELECT     -------------------------------------------------------
                   -- Commented for CCR : CCR0006261
                   --------------------------------------------------------
                   /*ROW_NUMBER ()
                          OVER (PARTITION BY mc.segment1, wah.adj_type_code
                                ORDER BY mc.segment1)
                             AS rnum,
                             MIN (wah.adj_header_id)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                          || '-'
                          || MAX (wah.adj_header_id)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                             AS orig_sys_doc_ref,
                             MIN (wah.adjust_date)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                          || '-'
                          || MAX (wah.adjust_date)
                                OVER (PARTITION BY mc.segment1 ORDER BY mc.segment1)
                             AS cust_po_num,*/
                   ------------------------------------------------------------
                   -- Commented for CCR : CCR0006261
                   ------------------------------------------------------------
                   ------------------------------------------------------------
                   -- Added for CCR : CCR0006261
                   ------------------------------------------------------------
                   ROW_NUMBER () OVER (PARTITION BY wah.adj_header_id, wah.adj_type_code ORDER BY wah.adj_header_id) AS rnum, MIN (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adj_header_id) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS orig_sys_doc_ref, MIN (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) || '-' || MAX (wah.adjust_date) OVER (PARTITION BY wah.adj_header_id ORDER BY wah.adj_header_id) AS cust_po_num,
                   ----------------------------------------------------------------------
                   -- End of addition for CCR :    CCR0006261 by Siva B
                   ----------------------------------------------------------------------
                   mc.segment1 brand, wah.adj_header_id, wah.adjust_date,
                   wal.adj_line_id, TO_NUMBER (-wal.quantity_to_adjust) quantity_to_adjust, wal.inventory_item_id,
                   wal.sku_code, wal.transaction_id, wah.organization_id,
                   wah.adj_type_code, wal.adj_type_code adj_line_type_code, wal.subinventory_code,
                   wah.ecom_platform platform -- Added by Siva B for CCR : CCR0006261
              FROM xxdo.xxdo_wms_3pl_adj_h wah, xxdo.xxdo_wms_3pl_adj_l wal, mtl_system_items_b mtl,
                   mtl_item_categories mic, mtl_category_sets mcs, mtl_categories mc,
                   org_organization_definitions org, oe_transaction_types_vl ott, oe_transaction_types_all ota,
                   apps.fnd_lookup_values_vl flv
             WHERE     wah.process_status = 'O'
                   AND wal.process_status = 'P'
                   AND wah.adj_type_code IN ('SHIPECOMM', 'RETURNECOMM')
                   AND mcs.category_set_name = 'Inventory'
                   AND wah.adj_header_id = wal.adj_header_id
                   AND mtl.inventory_item_id = wal.inventory_item_id
                   AND mtl.organization_id = wah.organization_id
                   AND mtl.inventory_item_id = mic.inventory_item_id
                   AND mtl.organization_id = mic.organization_id
                   AND mcs.category_set_id = mic.category_set_id
                   AND mc.category_id = mic.category_id
                   AND mtl.organization_id = org.organization_id
                   AND ott.name = flv.attribute1
                   AND flv.lookup_type = gc_order_mapping
                   AND flv.enabled_flag = 'Y'
                   AND flv.lookup_code =
                       NVL (wah.adj_type_code, wal.adj_type_code)
                   AND ott.transaction_type_id = ota.transaction_type_id;

        --AND ORG.OPERATING_UNIT = gn_org_id;--Viswa

        -- type for order header information
        TYPE lr_iface_tab IS TABLE OF ont.oe_headers_iface_all%ROWTYPE
            INDEX BY BINARY_INTEGER;

        -- type for order Line information
        TYPE lr_iface_lines_tab IS TABLE OF ont.oe_lines_iface_all%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lr_iface_rec            lr_iface_tab;
        lr_iface_lines_rec      lr_iface_lines_tab;
        --HEADER
        ln_order_source_id      oe_order_headers_all.order_source_id%TYPE;
        lv_orig_sys_doc_ref     VARCHAR2 (1000);
        lv_operation_code       VARCHAR2 (10) := 'INSERT';
        ln_order_type_id        oe_headers_iface_all.order_type_id%TYPE;
        ln_price_list_id        oe_headers_iface_all.price_list_id%TYPE;
        ln_payment_term_id      oe_headers_iface_all.payment_term_id%TYPE;
        ln_salesrep_id          oe_headers_iface_all.salesrep_id%TYPE;
        lv_shipping_method      oe_transaction_types_all.shipping_method_code%TYPE;
        ln_warehouse_id         oe_transaction_types_all.warehouse_id%TYPE;
        lv_fob                  oe_transaction_types_all.fob_point_code%TYPE;
        lv_freight_terms_code   oe_transaction_types_all.freight_terms_code%TYPE;
        lv_shipment_priority    oe_transaction_types_all.shipment_priority_code%TYPE;
        lv_customer_num         hz_cust_accounts.account_number%TYPE;
        lv_sales_channel        hz_cust_accounts.sales_channel_code%TYPE;
        lv_payment              ra_terms_vl.name%TYPE := 'Net 30';
        --LINE
        lv_line_type_id         oe_transaction_types_all.transaction_type_id%TYPE;
        lv_customer_id          hz_cust_accounts.cust_account_id%TYPE;
        lv_return_reason_code   apps.fnd_lookup_values.lookup_code%TYPE;
        lv_cust_po              VARCHAR2 (500);
        lv_subinventory         VARCHAR2 (10);
        lv_order_type_name      oe_transaction_types_vl.name%TYPE;
        -- lv_ship_to            oe_headers_iface_all.ship_to_org_id%TYPE;
        --  lv_bill_to            oe_headers_iface_all.invoice_to_org_id%TYPE;
        -- local parameters
        lv_header_idx           NUMBER := 0;
        lv_org_id               NUMBER;
        lf_valid_flag           VARCHAR2 (1) := 'Y';
        lv_err_adj_line_id      gt_adj_line_id_tbl;
        too_many_order_type     EXCEPTION;
        validationexcp          EXCEPTION;
        lv_platform             VARCHAR2 (100) := NULL; -- Added by Siva B for CCR : CCR0006261
    BEGIN
        write_log (
            '-------------In Extract Data into Interface----------------');
        --
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
        ln_salesrep_id          := NULL;
        lv_line_type_id         := NULL;
        lv_customer_id          := 0;
        -- lv_ship_to            := NULL;
        --  lv_bill_to            := NULL;
        lf_valid_flag           := 'Y';
        lv_org_id               := NULL;
        lv_header_idx           := 0;
        lv_err_adj_line_id.delete;
        write_log (
            '---------------------------------------------------------');
        --get order source id
        ln_order_source_id      := p_order_source_id;
        write_log ('Order Source ID ' || ln_order_source_id);

        -- get payment_term_id
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
            -- payment term

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
                    --    lv_ship_to            := NULL;
                    --    lv_bill_to            := NULL;
                    ln_salesrep_id          := NULL;
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
                            --HEADER
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
                            --LINE
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

                    -- get order type id,price list id,shipping method, warehouse,fob,freight terms,shipment priority
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
                    -- get header ORIG_SYS_DOCUMENT_REF  ,  Customer PO
                    lv_orig_sys_doc_ref     :=
                        wms_3pl_adj_rec.orig_sys_doc_ref;
                    lv_cust_po              := wms_3pl_adj_rec.cust_po_num;
                    write_log ('Orig Sys Doc Ref ' || lv_orig_sys_doc_ref);
                    write_log ('Customper PO ' || lv_cust_po);
                    -- Get Customer
                    get_customer (
                        wms_3pl_adj_rec.brand,
                        NVL (wms_3pl_adj_rec.adj_type_code,
                             wms_3pl_adj_rec.adj_line_type_code),
                        wms_3pl_adj_rec.platform, -- Added by Siva B for CCR : CCR0006261
                        lv_customer_num,
                        lv_customer_id,                       --SOLD TO ORG ID
                        lv_sales_channel);
                    write_log ('Customer ID ' || lv_customer_id);
                    /*   get_ship_bill_to(lv_org_id,
                                        lv_customer_id,
                                        lv_ship_to,
                                        lv_bill_to);*/
                    --get sales person ID
                    --   write_log('Ship To, Bill To ' || lv_ship_to || ' ' || lv_bill_to);
                    get_salesrep_id (lv_org_id, ln_salesrep_id);
                    write_log ('Sales Person ' || ln_salesrep_id);

                    IF (lv_orig_sys_doc_ref IS NULL OR lv_customer_id IS NULL --   OR lv_ship_to IS NULL
                                                                              OR ln_salesrep_id IS NULL)
                    THEN
                        lf_valid_flag   := 'N';
                        lv_err_adj_line_id (lv_err_adj_line_id.COUNT + 1)   :=
                            wms_3pl_adj_rec.adj_line_id;
                    END IF;

                    BEGIN
                        IF lf_valid_flag <> 'N'
                        THEN
                            -- insert into header
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
                            --lr_iface_rec(lv_header_idx).order_number := NULL;
                            -- order number
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
                            -- Transaction Date LESS 2 dyas
                            lr_iface_rec (wms_3pl_adj_rec.rnum).order_type_id   :=
                                ln_order_type_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).price_list_id   :=
                                ln_price_list_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).payment_term_id   :=
                                ln_payment_term_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).salesrep_id   :=
                                ln_salesrep_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).sold_from_org_id   :=
                                lv_org_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).sold_to_org_id   :=
                                lv_customer_id;
                            lr_iface_rec (wms_3pl_adj_rec.rnum).ship_from_org_id   :=
                                ln_warehouse_id;
                            --    lr_iface_rec(wms_3pl_adj_rec.rnum).ship_to_org_id := lv_ship_to;
                            --   lr_iface_rec(wms_3pl_adj_rec.rnum).invoice_to_org_id := lv_bill_to;
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
                            -- dff cancel date
                            lr_iface_rec (wms_3pl_adj_rec.rnum).attribute5   :=
                                wms_3pl_adj_rec.brand;
                            -- dff brand
                            lr_iface_rec (wms_3pl_adj_rec.rnum).booked_flag   :=
                                'Y'; -- Changed from N to Y by Viswanathan Pandian for CCR0005950
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

                -- Insert into line
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
                            -- Line Flow - Generic, Ship Only
                            get_line_type_id (ln_order_type_id,
                                              'ORDER',
                                              lv_line_type_id);

                            IF lv_line_type_id IS NOT NULL
                            THEN
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).schedule_ship_date   :=
                                    SYSDATE;
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).override_atp_date_code   :=
                                    'Y';
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).line_type_id   :=
                                    lv_line_type_id;
                            ELSE
                                lv_err_adj_line_id (
                                    lv_err_adj_line_id.COUNT + 1)   :=
                                    wms_3pl_adj_rec.adj_line_id;
                            END IF;
                        ELSE
                            --Line Flow - Return with Receipt Only, No Credit
                            get_line_type_id (ln_order_type_id,
                                              'RETURN',
                                              lv_line_type_id);
                            get_return_reason_code (
                                NVL (wms_3pl_adj_rec.adj_line_type_code,
                                     wms_3pl_adj_rec.adj_type_code),
                                lv_return_reason_code);

                            IF     lv_return_reason_code IS NOT NULL
                               AND lv_line_type_id IS NOT NULL
                            THEN
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).line_type_id   :=
                                    lv_line_type_id;
                                lr_iface_lines_rec (wms_3pl_adj_rec.rnum).return_reason_code   :=
                                    lv_return_reason_code;
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
                        -- lr_iface_lines_rec(wms_3pl_adj_rec.rnum).subinventory := lv_subinventory;-- Commented by Naveen on 02-Jul-15
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).subinventory   :=
                            wms_3pl_adj_rec.subinventory_code; --Added by Naveen on 02-Jul-15
                        -- lr_iface_lines_rec(wms_3pl_adj_rec.rnum).schedule_status_code := 'SCHEDULED'; -- Commented by Mona 2016-06-16
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).request_date   :=
                            wms_3pl_adj_rec.adjust_date - 2;
                        -- not available for item available date
                        lr_iface_lines_rec (wms_3pl_adj_rec.rnum).attribute1   :=
                            TO_CHAR (
                                  lr_iface_lines_rec (wms_3pl_adj_rec.rnum).request_date
                                + 30,
                                'YYYY/MM/DD HH24:MI:SS');
                    -- CANCEL DATE

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
                --
                -- insert data into interface
                write_log (
                       'Step 1 Load data into Intf header table '
                    || lr_iface_rec.COUNT);

                FOR i IN 1 .. lr_iface_rec.COUNT
                LOOP
                    --HEADER
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
                    --LINE
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
                    -- update the table with Validation Error
                    FOR i IN 1 .. lv_err_adj_line_id.COUNT
                    LOOP
                        updating_process_status (gc_process_error,
                                                 'Validation Failed',
                                                 lv_err_adj_line_id (i));
                    END LOOP;

                    lv_err_adj_line_id.delete;
                END IF;

                -- import order
                xxdo_wms_3pl_adj_conv_pkg.create_sales_order (
                    x_errbuf,
                    x_retcode,
                    ln_order_source_id,
                    p_order_type_id);
            END IF;
        -- update staging table with status 'I'
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
    --
    -- Parameters
    -- x_errbuf          OUT
    -- x_retcode         OUT
    -- Modification History
    --
    --
    -- Author         Date           Version        Changes
    -- -----------    ------------   -----------    -----------------------------------
    -- BT tech Team    02-Jun-2015    V1.0           Initial Version
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
               --AND org.operating_unit = gn_org_id--Viswa
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
                --Begin call concurrent program to load data into interface AND create sales Orders
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

                --Begin call concurrent program to receive the returns
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

                --Begin call concurrent program to ship confirm
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

                /*  Submit the Request set  */
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
                                request_id   => lv_request_id --ln_concurrent_request_id
                                                             ,
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
        -- Commenting the change as per CCR0005950

        -- UPDATING Staging table with 'S'
        /*BEGIN
          UPDATE xxdo.xxdo_wms_3pl_adj_h wah
             SET wah.process_status = gc_process_success,
                 wah.error_message  = 'Processing Complete'
           WHERE wah.process_status IN ('R', 'T')
             AND EXISTS
           (SELECT 'X'
                    FROM fnd_lookup_values_vl flv, xxdo.xxdo_wms_3pl_adj_l wal
                   WHERE flv.lookup_type = gc_order_mapping
                     AND flv.enabled_flag = 'Y'
                     AND flv.attribute1 = lv_order_type_name
                     AND NVL(wah.adj_type_code, wal.adj_type_code) =
                         flv.lookup_code);
          COMMIT;

          UPDATE xxdo.xxdo_wms_3pl_adj_l wal
             SET wal.process_status = gc_process_success,
                 wal.error_message  = 'Processing Complete'
           WHERE wal.process_status IN ('R', 'T')
             AND EXISTS
           (SELECT 'X'
                    FROM fnd_lookup_values_vl flv, xxdo.xxdo_wms_3pl_adj_h wah
                   WHERE flv.lookup_type = gc_order_mapping
                     AND flv.enabled_flag = 'Y'
                     AND flv.attribute1 = lv_order_type_name
                     AND wah.adj_header_id = wal.adj_header_id
                     AND NVL(wah.adj_type_code, wal.adj_type_code) =
                         flv.lookup_code);
          COMMIT;
        EXCEPTION
          WHEN OTHERS THEN
            write_log('Error in Updata final status' || SQLERRM);
        END;*/
        -- Commenting the change as per CCR0005950
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
END xxdo_wms_3pl_adj_conv_pkg;
/
