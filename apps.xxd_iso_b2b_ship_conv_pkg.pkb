--
-- XXD_ISO_B2B_SHIP_CONV_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:32 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ISO_B2B_SHIP_CONV_PKG"
/**********************************************************************************************************

    File Name    : XXD_ISO_B2B_SHIP_CONV_PKG

    Created On   : 29-May-2015

    Created By   : BT Technology Team

    Purpose      : This  package is to do ship confirm for the elligible back to back elligible order lines
                   into 12.2.3 EBS .
   ***********************************************************************************************************
    Modification History:
    Version   SCN#        By                        Date                     Comments
    1.0              BT Technology Team          29-May-2015               Base Version

    **********************************************************************************************************
   Parameters: 1.Mode
               2.Debug Flag
   **********************************************************************************************************/
AS
    PROCEDURE submit_interface_trip_stop (x_retcode OUT NOCOPY NUMBER, x_errbuf OUT NOCOPY VARCHAR2, P_DELIVERY_ID IN NUMBER)
    IS
        v_request_status   BOOLEAN;
        v_phase            VARCHAR2 (2000);
        v_wait_status      VARCHAR2 (2000);
        v_dev_phase        VARCHAR2 (2000);
        v_dev_status       VARCHAR2 (2000);
        v_message          VARCHAR2 (2000);
        v_req_id           NUMBER;
    BEGIN
        v_req_id   :=
            fnd_request.submit_request (application => 'WSH', program => 'WSHINTERFACES', description => NULL, start_time => SYSDATE, sub_request => FALSE, argument1 => 'ALL', argument2 => NULL, argument3 => P_DELIVERY_ID, argument4 => 1, argument5 => NULL, argument6 => NULL, argument7 => NULL
                                        , argument8 => NULL, argument9 => NULL);

        COMMIT;

        IF v_req_id = 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Request Not Submitted due to ?' || fnd_message.get || '?.');
            x_retcode   := 1;
        ELSE
            fnd_file.put_line (
                fnd_file.LOG,
                   'The Interface Trip Stop Program submitted ? Request id :'
                || v_req_id);
        END IF;

        IF v_req_id > 0
        THEN
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                '   Waiting for the Interface Trip Stop Program');

            LOOP
                v_request_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => v_req_id,
                        INTERVAL     => 60,
                        max_wait     => 0,
                        phase        => v_phase,
                        status       => v_wait_status,
                        dev_phase    => v_dev_phase,
                        dev_status   => v_dev_status,
                        MESSAGE      => v_message);

                EXIT WHEN    UPPER (v_phase) = 'COMPLETED'
                          OR UPPER (v_wait_status) IN ('CANCELLED', 'ERROR', 'TERMINATED',
                                                       'NORMAL');
            END LOOP;

            COMMIT;
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   '  Interface Trip Stop Program Request Phase'
                || '-'
                || v_dev_phase);
            FND_FILE.PUT_LINE (
                FND_FILE.LOG,
                   '  Interface Trip Stop Program Request Dev status'
                || '-'
                || v_dev_status);

            IF     UPPER (v_phase) = 'COMPLETED'
               AND UPPER (v_wait_status) = 'ERROR'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'The Interface Trip Stop prog completed in error. See log for request id');
                fnd_file.put_line (fnd_file.LOG, SQLERRM);
                x_retcode   := 1;

                RETURN;
            ELSIF     UPPER (v_phase) = 'COMPLETED'
                  AND UPPER (v_wait_status) = 'NORMAL'
            THEN
                Fnd_File.PUT_LINE (
                    Fnd_File.LOG,
                       'The Interface Trip Stop Import successfully completed for request id: '
                    || v_req_id);
            ELSE
                Fnd_File.PUT_LINE (
                    Fnd_File.LOG,
                    'The Interface Trip Stop Import request failed.Review log for Oracle request id ');
                Fnd_File.PUT_LINE (Fnd_File.LOG, SQLERRM);
                x_retcode   := 1;

                RETURN;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            Fnd_File.PUT_LINE (
                Fnd_File.LOG,
                'WHEN OTHERS Interface Trip Stop STANDARD CALL' || SQLERRM);
    END;

    PROCEDURE delete_RESERVATION (x_retcode OUT NOCOPY NUMBER, x_errbuf OUT NOCOPY VARCHAR2, P_LINE_ID IN NUMBER)
    IS
        lv_msg_index_out    NUMBER;
        lv_error_message    VARCHAR2 (4000);
        x_status            VARCHAR2 (50) := 'SUCCESS';
        x_msg_count         NUMBER := 0;
        x_msg_data          VARCHAR2 (250);
        ln_reservation_id   NUMBER;
        p_dummy_sn          inv_reservation_global.serial_number_tbl_type;
        l_rsv               inv_reservation_global.mtl_reservation_rec_type;

        CURSOR lcu_reservation (LN_line_id NUMBER)
        IS
            SELECT reservation_id
              INTO ln_reservation_id
              FROM mtl_reservations
             WHERE     demand_source_line_id = LN_line_id
                   AND (orig_supply_source_line_id IS NULL OR supply_source_line_id IS NULL);
    BEGIN
        --Start : delete any reservation if present

        FOR i IN lcu_reservation (P_line_id)
        LOOP
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Reservation Id for SO Line Id ' || P_line_id || ' is ' || i.reservation_id);

            l_rsv.reservation_id   := i.reservation_id;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Calling delete reservation api for reservation id ' || i.reservation_id);

            inv_reservation_pub.delete_reservation (
                p_api_version_number   => 1.0,
                p_init_msg_lst         => fnd_api.g_true,
                x_return_status        => x_status,
                x_msg_count            => x_msg_count,
                x_msg_data             => x_msg_data,
                p_rsv_rec              => l_rsv,
                p_serial_number        => p_dummy_sn);

            IF x_status = fnd_api.g_ret_sts_success
            THEN
                apps.fnd_file.put_line (apps.fnd_file.LOG,
                                        'Reservation deleted');
            ELSE
                x_retcode   := 1;

                FOR I IN 1 .. x_msg_count
                LOOP
                    /* DBMS_OUTPUT.put_line (
                           I
                        || '. '
                        || SUBSTR (
                              FND_MSG_PUB.Get (p_encoded => FND_API.G_FALSE),
                              1,
                              255));*/
                    apps.fnd_msg_pub.get (
                        p_msg_index       => i,
                        p_encoded         => fnd_api.g_false,
                        p_data            => x_msg_data,
                        p_msg_index_out   => lv_msg_index_out);

                    IF lv_error_message IS NULL
                    THEN
                        lv_error_message   := SUBSTR (x_msg_data, 1, 250);
                    ELSE
                        lv_error_message   :=
                               lv_error_message
                            || ' /'
                            || SUBSTR (x_msg_data, 1, 250);
                    END IF;
                END LOOP;

                x_errbuf    := lv_error_message;

                fnd_file.put_line (
                    fnd_file.LOG,
                    '------------------------------------------');
                fnd_file.put_line (fnd_file.LOG,
                                   'Error Message :' || lv_error_message);
            END IF;
        --End : delete any reservation if present

        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'WHEN OTHERS WHILE DELETING RESERVATION: '
                || P_LINE_id
                || SQLERRM);
    END;

    /* PROCEDURE delete_delivery (x_retcode          OUT NOCOPY NUMBER,
                                x_errbuf           OUT NOCOPY VARCHAR2,
                                P_DELIVERY_ID   IN            NUMBER)
     IS
        lv_msg_index_out   NUMBER;
        lv_error_message   VARCHAR2 (4000);
        RETSTAT            VARCHAR2 (1);
        MSGCOUNT           NUMBER;
        MSGDATA            VARCHAR2 (2000);
        X_TRIP_ID          VARCHAR2 (30);
        X_TRIP_NAME        VARCHAR2 (30);
     BEGIN
        APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION (
           P_API_VERSION_NUMBER   => 1.0,
           P_INIT_MSG_LIST        => NULL,
           X_RETURN_STATUS        => RETSTAT,
           X_MSG_COUNT            => MSGCOUNT,
           X_MSG_DATA             => MSGDATA,
           P_ACTION_CODE          => 'DELETE',
           P_DELIVERY_ID          => P_delivery_id,              --l_delivery_id
           X_TRIP_ID              => X_TRIP_ID,
           X_TRIP_NAME            => X_TRIP_NAME);

        --COMMIT;
        --Deliveries Loop--

        IF (RETSTAT <> wsh_util_core.g_ret_sts_success)
        THEN
           fnd_file.put_line (
              fnd_file.LOG,
                 'The DELETE action on the delivery '
              || P_delivery_id                                   --l_delivery_id
              || ' errored out.');

           FOR i IN 1 .. MSGCOUNT
           LOOP
              apps.fnd_msg_pub.get (p_msg_index       => i,
                                    p_encoded         => fnd_api.g_false,
                                    p_data            => MSGDATA,
                                    p_msg_index_out   => lv_msg_index_out);

              IF lv_error_message IS NULL
              THEN
                 lv_error_message := SUBSTR (MSGDATA, 1, 250);
              ELSE
                 lv_error_message :=
                    lv_error_message || ' /' || SUBSTR (MSGDATA, 1, 250);
              END IF;
           END LOOP;

           fnd_file.put_line (fnd_file.LOG,
                              '------------------------------------------');
           fnd_file.put_line (fnd_file.LOG,
                              'Error Message :' || lv_error_message);
           x_retcode := 1;
        ELSE
           fnd_file.put_line (
              fnd_file.LOG,
                 'The DELETE action on the delivery '
              || P_delivery_id                                  -- l_delivery_id
              || ' is successful.');

           COMMIT;
        END IF;
     EXCEPTION
        WHEN OTHERS
        THEN
           fnd_file.put_line (
              fnd_file.LOG,
                 'WHEN OTHERS WHILE DELETING DELIVERY: '
              || P_delivery_id
              || SQLERRM);
     END;*/

    PROCEDURE BACK_TO_BACK_SHIP (x_retcode OUT NOCOPY NUMBER, x_errbuf OUT NOCOPY VARCHAR2, p_org_name IN VARCHAR2
                                 , p_ship_date IN VARCHAR2)
    IS
        TYPE l_line_container_rec
            IS RECORD
        (
            line_id                   NUMBER,
            shipment_priority_code    oe_order_lines_all.shipment_priority_code%TYPE
        );

        TYPE l_line_container_tbl IS TABLE OF l_line_container_rec
            INDEX BY BINARY_INTEGER;

        TYPE l_num_tbl IS TABLE OF NUMBER
            INDEX BY VARCHAR2 (50);

        ex_user_EXP          EXCEPTION;
        l_line_containers    l_line_container_tbl;
        l_hdr_ids            l_num_tbl;
        p_header_iface_id    NUMBER;
        p_group_id           NUMBER;
        l_req_status         BOOLEAN;
        l_trx_date           DATE;
        l_req_id             NUMBER;
        l_phase              VARCHAR2 (80);
        l_status             VARCHAR2 (80);
        l_dev_phase          VARCHAR2 (80);
        l_dev_status         VARCHAR2 (80);
        l_message            VARCHAR2 (255);
        l_buffer_number      NUMBER;
        l_vendor_id          NUMBER;
        l_res_id             NUMBER;
        l_res_qty            NUMBER;
        l_rec_id             NUMBER;
        x_ret_stat           VARCHAR2 (1);
        x_error_text         VARCHAR2 (240);
        RETSTAT              VARCHAR2 (1);
        MSGCOUNT             NUMBER;
        MSGDATA              VARCHAR2 (2000);
        X_TRIP_ID            VARCHAR2 (30);
        X_TRIP_NAME          VARCHAR2 (30);
        l_batch_rowid        ROWID;
        l_pick_batch_id      NUMBER;
        l_batch_name         VARCHAR2 (30);
        l_ret_stat           VARCHAR2 (1);
        l_error_text         VARCHAR2 (2000);
        l_gl_did             NUMBER;
        l_key                VARCHAR2 (30);
        l_header_id          NUMBER;
        l_container_id       VARCHAR2 (30);
        l_user_id            NUMBER;
        l_responsiblity_id   NUMBER;
        l_application_id     NUMBER;
        l_org_id             NUMBER;
        v_count              NUMBER;
        lv_msg_index_out     NUMBER;
        lv_error_message     VARCHAR2 (4000);
        --V_SO_QTY  NUMBER;
        l_delivery_name      VARCHAR2 (30);
        l_delivery_id        NUMBER;
        L_OU_ID              NUMBER;
        --
        l_changed_rec        WSH_DELIVERY_DETAILS_PUB.ChangedAttributeTabType;
        l_init_rec           WSH_DELIVERY_DETAILS_PUB.ChangedAttributeRecType;
        l_return_status      VARCHAR2 (1000);
        l_msg_count          NUMBER;
        l_msg_data           VARCHAR2 (1000);
        error                EXCEPTION;

        CURSOR c_lines_emea IS
            SELECT /*+ FIRST_ROWS(10) */
                     (SELECT SUM (rsl.quantity_RECEIVED)
                        FROM rcv_shipment_lines rsl, rcv_shipment_HEADERs rsH
                       WHERE     PLA.PO_LINE_ID = rsl.PO_LINE_ID
                             AND RSH.SHIPMENT_HEADER_ID =
                                 RSL.SHIPMENT_HEADER_ID --AND RSH.asn_type = 'ASN'
                                                       )
                   - NVL (
                         (SELECT SUM (oOla.shipped_quantity)
                            FROM oe_order_lines_all OOLA
                           WHERE oeol.source_document_line_id =
                                 oOla.source_document_line_id),
                         0) SO_QTY,
                   oeh.header_id,
                   oeh.order_number,
                   oeol.ship_from_org_id,
                   oeol.attribute16,
                   oeh.org_id,
                   oeol.inventory_item_id,
                   oeol.line_id,
                   oeol.shipment_priority_code,
                   NULL DELIVERY_NAME
              -- MAX (dc.container_id) AS container_id
              FROM APPS.OE_ORDER_HEADERS_ALL OEH, APPS.OE_ORDER_LINES_ALL OEOL, APPS.PO_REQUISITION_HEADERS_ALL PRHA,
                   APPS.PO_HEADERS_ALL PHA, APPS.PO_LINES_ALL PLA, apps.po_line_locations_all plla,
                   APPS.PO_REQ_DISTRIBUTIONS_ALL PRDA, APPS.PO_DISTRIBUTIONS_ALL PDA, APPS.PO_REQUISITION_LINES_ALL PRLA,
                   APPS.hr_operating_units hou-- ,APPS.org_organization_definitions ood
                                              , apps.po_requisition_lines_all porl, APPS.MTL_RESERVATIONS MR
             WHERE     1 = 1
                   AND PHA.PO_HEADER_ID = PLA.PO_HEADER_ID
                   AND PDA.PO_LINE_ID = PLA.PO_LINE_ID
                   AND pda.line_location_id = plla.line_location_id
                   AND plla.po_line_id = pla.po_line_id
                   AND plla.PO_HEADER_ID = PHA.PO_HEADER_ID
                   AND PDA.PO_HEADER_ID = PHA.PO_HEADER_ID
                   AND PDA.REQ_DISTRIBUTION_ID = PRDA.DISTRIBUTION_ID
                   AND PRLA.REQUISITION_HEADER_ID =
                       PRHA.REQUISITION_HEADER_ID
                   AND PRDA.REQUISITION_LINE_ID = PRLA.REQUISITION_LINE_ID
                   AND PRHA.INTERFACE_SOURCE_CODE = 'CTO'
                   AND porl.ATTRIBUTE14 = pla.ATTRIBUTE15
                   AND porl.requisition_line_id =
                       oeol.source_document_line_id
                   AND OEOL.ATTRIBUTE16 = TO_CHAR (plla.line_location_id)
                   AND oeh.org_id = pha.org_id
                   AND OEH.HEADER_ID = OEOL.HEADER_ID
                   AND hou.organization_id = pha.org_id
                   AND hou.name LIKE 'Deckers Macau OU'
                   AND MR.DEMAND_SOURCE_LINE_ID = OEOL.LINE_ID
                   AND MR.ORGANIZATION_ID = 129
                   AND plla.ship_to_organization_id = 129
                   AND OEOL.FLOW_STATUS_CODE IN
                           ('AWAITING_SHIPPING', 'PO_RECEIVED', 'PO_PARTIAL')
                   AND OEOL.OPEN_FLAG = 'Y'
                   --       AND porl.DESTINATION_ORGANIZATION_ID = ood.organization_id
                   --          AND (ood.organization_code LIKE 'EU%'
                   --               OR ood.organization_code LIKE 'UK%')
                   AND EXISTS
                           (SELECT 1
                              FROM apps.po_12_2_3_emea EMEA
                             WHERE     1 = 1
                                   --    AND PURCHASE_ORDER_NUM in('60861','60860','60889')--'60893' -- = 60606) --60635100)
                                   AND pha.PO_HEADER_ID = EMEA.PO_HEADER_ID
                                   AND PLA.ATTRIBUTE15 = EMEA.OLD_PO_line_id)--61043 60811  --(58296,58298,58299,58301,58303,58313,58334,58335,58336,58338,58339))
                                                                             /* GROUP BY oeh.header_id,
                                                                                       oeh.order_number,
                                                                                       oeol.line_id,
                                                                                       oeh.org_id,
                                                                                       oeol.inventory_item_id,
                                                                                       oeol.shipment_priority_code*/
                                                                             ;

        CURSOR c_lines_japan IS
            SELECT /*+ FIRST_ROWS(10) */
                     (SELECT SUM (rsl.quantity_RECEIVED)
                        FROM rcv_shipment_lines rsl, rcv_shipment_HEADERs rsH
                       WHERE     PLA.PO_LINE_ID = rsl.PO_LINE_ID
                             AND RSH.SHIPMENT_HEADER_ID =
                                 RSL.SHIPMENT_HEADER_ID --AND RSH.asn_type = 'ASN'
                                                       )
                   - NVL (
                         (SELECT SUM (oOla.shipped_quantity)
                            FROM oe_order_lines_all OOLA
                           WHERE oeol.source_document_line_id =
                                 oOla.source_document_line_id),
                         0) SO_QTY,
                   oeh.header_id,
                   oeh.order_number,
                   oeol.ship_from_org_id,
                   oeol.attribute16,
                   oeh.org_id,
                   oeol.inventory_item_id,
                   oeol.line_id,
                   oeol.shipment_priority_code,
                   NULL DELIVERY_NAME
              -- MAX (dc.container_id) AS container_id
              FROM apps.oe_order_headers_all oeh, apps.oe_order_lines_all oeol, apps.po_requisition_headers_all prha,
                   apps.po_headers_all pha, apps.po_lines_all pla, apps.po_req_distributions_all prda,
                   apps.po_distributions_all pda, apps.po_requisition_lines_all prla, -- custom.do_containers dc,
                                                                                      -- custom.do_items di,
                                                                                      apps.mtl_reservations mr
             WHERE     1 = 1
                   --AND dc.container_id(+) = di.container_id
                   --  AND di.order_line_id(+) = pla.po_line_id
                   AND pha.po_header_id = pla.po_header_id
                   -- AND PHA.SEGMENT1 = '60830'
                   AND pda.po_line_id = pla.po_line_id
                   AND oeh.header_id = oeol.header_id
                   AND pda.req_distribution_id = prda.distribution_id
                   AND pda.po_header_id = pha.po_header_id
                   AND prla.requisition_header_id =
                       prha.requisition_header_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND oeol.attribute16 = prla.line_location_id
                   -- AND mr.orig_supply_source_line_id = prla.requisition_line_id
                   AND mr.demand_source_line_id = oeol.line_id
                   -- and oeh.orig_sys_document_ref = porh.segment1
                   AND mr.organization_id = 129
                   AND oeol.flow_status_code IN
                           ('AWAITING_SHIPPING', 'PO_RECEIVED', 'PO_PARTIAL')
                   /*AND EXISTS
                         (SELECT NULL
                            FROM apps.mtl_reservations mr
                           WHERE     mr.organization_id = 129
                                 AND mr.supply_source_line_id IS NULL
                                 AND mr.demand_source_line_id = oeol.line_id)*/
                   AND oeol.open_flag = 'Y'
                   AND prha.INTERFACE_SOURCE_CODE = 'CTO'
                   --AND prha.interface_source_line_id = oeol.line_id
                   --AND oeol.header_id =2788372  --2788412 --2788230 --2788495  --2788488
                   AND EXISTS
                           (SELECT 1
                              FROM apps.po_12_2_3_japan japan
                             WHERE     1 = 1
                                   --    AND PURCHASE_ORDER_NUM in('60861','60860','60889')--'60893' -- = 60606) --60635100)
                                   AND pha.PO_HEADER_ID = japan.PO_HEADER_ID
                                   AND PLA.ATTRIBUTE15 = japan.OLD_PO_line_id) --61043 60811  --(58296,58298,58299,58301,58303,58313,58334,58335,58336,58338,58339))
                                                                              /* GROUP BY oeh.header_id,
                                                                                        oeh.order_number,
                                                                                        oeol.line_id,
                                                                                        oeh.org_id,
                                                                                        oeol.inventory_item_id,
                                                                                        oeol.shipment_priority_code*/
                                                                              ;

        CURSOR c_apac_deliveries IS
            SELECT DISTINCT delivery_name, delivery_id
              FROM xxd_conv.XXD_ISO_SHIP_STG --where requisition_line_id = 1432303
                                            ;

        CURSOR c_lines_apac (p_delivery_id NUMBER)
        IS
            SELECT /*+ FIRST_ROWS(10) */
                   oeh.header_id, oeh.order_number, oeol.line_id,
                   oeh.org_id, oeol.ship_from_org_id, oeol.attribute16,
                   oeol.inventory_item_id, -- oeol.shipment_priority_code,
                                           xISV.DELIVERY_NAME shipment_priority_code, XISV.DELIVERY_NAME,
                   xisv.shipment_line_id old_shipment_line_id, xisv.shipment_num, XISV.rsl_quantity_shipped so_qty,
                   XISV.line_id old_line_id
              -- MAX (dc.container_id) AS container_id
              FROM apps.oe_order_headers_all oeh, apps.oe_order_lines_all oeol, apps.po_requisition_headers_all prha,
                   apps.po_headers_all pha, apps.po_lines_all pla, apps.po_req_distributions_all prda,
                   apps.po_distributions_all pda, po_line_locations_all plla, apps.po_requisition_lines_all prla,
                   -- custom.do_containers dc,
                   -- apps.rcv_shipment_lines rsl,
                   apps.po_requisition_headers_all porh, apps.po_requisition_lines_all porl, -- custom.do_items di,
                                                                                             -- apps.mtl_reservations mr,--,APPS.XXD_ISO_SHIPMENT_V XISV
                                                                                             xxd_conv.XXD_ISO_SHIP_STG xisv
             WHERE     1 = 1
                   -- AND dc.container_id(+) = di.container_id
                   --  AND di.order_line_id(+) = pla.po_line_id
                   AND pha.po_header_id = pla.po_header_id
                   AND pda.po_line_id = pla.po_line_id
                   AND plla.po_line_id = pla.po_line_id
                   AND oeh.header_id = oeol.header_id
                   AND pda.req_distribution_id = prda.distribution_id
                   AND pda.po_header_id = pha.po_header_id
                   AND prla.requisition_header_id =
                       prha.requisition_header_id
                   AND prda.requisition_line_id = prla.requisition_line_id
                   AND oeol.attribute16 = plla.line_location_id
                   --AND mr.orig_supply_source_line_id = prla.requisition_line_id
                   /*AND mr.orig_supply_source_line_id is null
                   AND mr.demand_source_line_id = oeol.line_id
                   AND mr.organization_id = 129*/
                   --commented on 28th jul
                   AND plla.ship_to_organization_id = 129
                   --  AND OEOL.LINE_number = 5
                   -- AND oeh.order_number = '51518145200'
                   AND oeol.flow_status_code IN
                           ('AWAITING_SHIPPING', 'PO_RECEIVED', 'PO_PARTIAL',
                            'SUPPLY_PARTIAL', 'SUPPLY_ELIGIBLE', 'PO_OPEN')
                   /*AND EXISTS
                         (SELECT NULL
                            FROM apps.mtl_reservations mr
                           WHERE     mr.organization_id = 129
                                 AND mr.supply_source_line_id IS NULL
                                 AND mr.demand_source_line_id = oeol.line_id)*/
                   AND oeol.open_flag = 'Y'
                   AND prha.INTERFACE_SOURCE_CODE = 'CTO'
                   AND oeh.orig_sys_document_ref = porh.segment1
                   AND porl.requisition_header_id =
                       porh.requisition_header_id
                   AND oeh.source_document_id = porh.requisition_header_id
                   --and pha.segment1 != '59773'
                   --and rsl.po_line_id = pla.po_line_id
                   -- AND porh.segment1 != '378'
                   -- not in ('402','402_2')
                   -- and porh.segment1 not in ('402_2','409_2','193_2','402','409','193')
                   -- and oeh.order_number = '50735407'
                   --AND prha.interface_source_line_id = oeol.line_id
                   --AND oeol.header_id =2788372  --2788412 --2788230 --2788495  --2788488
                   AND TO_CHAR (XISV.REQUISITION_LINE_ID) = porl.ATTRIBUTE15
                   AND xisv.delivery_id = p_delivery_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.rcv_shipment_lines rsl
                             WHERE rsl.po_line_id = pla.po_line_id)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all ola
                             WHERE     ola.header_id = oeol.header_id
                                   AND oeol.line_number = ola.line_number
                                   AND OLA.shipment_priority_code =
                                       xisv.delivery_name
                                   AND ola.flow_status_code IN
                                           ('SHIPPED', 'CLOSED'))
                   AND PLA.ATTRIBUTE15 = porl.attribute14
                   AND EXISTS
                           (SELECT 1
                              FROM apps.po_12_2_3_APAC APAC
                             WHERE     1 = 1
                                   -- AND PURCHASE_ORDER_NUM --= '59790200'
                                   -- in( '60839' ,'60837','60835','60841','60836','60838','60840')
                                   AND pha.PO_HEADER_ID = APAC.PO_HEADER_ID
                                   AND PLA.ATTRIBUTE15 =
                                       TO_CHAR (APAC.OLD_PO_line_id)) --61043 60811  --(58296,58298,58299,58301,58303,58313,58334,58335,58336,58338,58339))
                                                                     /*GROUP BY oeh.header_id,
                                                                              oeh.order_number,
                                                                              oeol.line_id,
                                                                              oeh.org_id,
                                                                              oeol.inventory_item_id,
                                                                              oeol.shipment_priority_code*/
                                                                     ;

        TYPE c_lines_apac_t IS TABLE OF c_lines_apac%ROWTYPE
            INDEX BY BINARY_INTEGER;

        c_lines_apac_tab     c_lines_apac_t;

        CURSOR c_deliveries (p_header_id NUMBER)
        IS
              SELECT wda.delivery_id
                FROM wsh_delivery_assignments wda, wsh_delivery_details wdd, oe_order_lines_all oola,
                     -- mtl_demand md,
                     mtl_reservations mr
               WHERE     oola.header_id = p_header_id
                     AND wdd.source_code = 'OE'
                     AND wdd.source_line_id = oola.line_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     -- AND md.demand_source_line = TO_CHAR (oola.line_id)
                     AND (mr.orig_supply_source_line_id IS NULL OR mr.supply_source_line_id IS NULL)
                     AND mr.demand_source_line_id = oola.line_id
                     AND wdd.released_status = 'Y'
                     --  and oola.shipment_priority_code = p_delivery_name
                     AND oola.flow_status_code = 'AWAITING_SHIPPING'
            GROUP BY wda.delivery_id;

        CURSOR c_deliveries_new (p_header_id       NUMBER,
                                 p_delivery_name   VARCHAR2)
        IS
              SELECT wda.delivery_id
                FROM wsh_delivery_assignments wda, wsh_delivery_details wdd, oe_order_lines_all oola
               -- mtl_demand md,
               --mtl_reservations mr
               --  ,XXD_COnV.XXD_ISO_SHIP_STG xiss
               WHERE     oola.header_id = p_header_id
                     AND wdd.source_code = 'OE'
                     AND wdd.source_line_id = oola.line_id
                     AND wda.delivery_detail_id = wdd.delivery_detail_id
                     -- AND md.demand_source_line = TO_CHAR (oola.line_id)
                     --  AND mr.demand_source_line_id = oola.line_id
                     --  AND mr.orig_supply_source_line_id IS NULL
                     AND oola.shipment_priority_code = p_delivery_name
                     AND wdd.released_status = 'Y'
                     --  and oola.shipment_priority_code = p_delivery_name
                     AND oola.flow_status_code IN
                             ('AWAITING_SHIPPING', 'SUPPLY_PARTIAL', 'PO_PARTIAL')
            GROUP BY wda.delivery_id;

        CURSOR C_UPDATE_ATTR15 IS
            SELECT XISV.SHIPMENT_LINE_ID OLD_SHIPMENT_LINE_ID, RSL.SHIPMENT_LINE_ID
              FROM xxd_conv.XXD_ISO_SHIP_STG xisv, wsh_delivery_assignments wda, wsh_delivery_details wdd,
                   apps.po_requisition_lines_all porl, APPS.RCV_SHIPMENT_LINES RSL, mtl_material_transactions mmt,
                   oe_order_lines_all ooLA
             WHERE     wdd.source_code = 'OE'
                   AND wdd.source_line_id = oola.line_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND WDD.SHIPMENT_PRIORITY_CODE = XISV.DELIVERY_NAME
                   AND TO_CHAR (XISV.REQUISITION_LINE_ID) = porl.ATTRIBUTE15
                   AND oola.source_document_line_id =
                       porl.requisition_line_id
                   AND WDD.SOURCE_LINE_ID = OOLA.LINE_ID
                   AND mmt.transaction_id = rsl.mmt_transaction_id
                   AND mmt.source_line_id = wdd.source_line_id
                   AND RSL.QUANTITY_SHIPPED = XISV.rsl_QUANTITY_SHIPPED
                   AND RSL.ATTRIBUTE15 IS NULL;

        /* CURSOR C_DELETE_DEL (
            P_LINE_ID NUMBER)
         IS
            SELECT DISTINCT wda.delivery_id
              -- into l_delivery_id
              FROM wsh_delivery_assignments wda,
                   wsh_delivery_details wdd,
                   oe_order_lines_all ooLA
             WHERE     wdd.source_code = 'OE'
                   AND wdd.source_line_id = oola.line_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wdd.released_status NOT IN ('Y', 'C')
                   AND OOLA.LINE_ID = P_LINE_ID;*/

        -- MAKE_KEY

        FUNCTION make_key (p_header_id IN NUMBER, p_container_id IN VARCHAR2)
            RETURN VARCHAR2
        IS
        BEGIN
            RETURN p_header_id || '-' || p_container_id;
        END;

        --BREAK_KEY

        PROCEDURE break_key (p_key            IN     VARCHAR2,
                             x_header_id         OUT NUMBER,
                             x_container_id      OUT VARCHAR2)
        IS
        BEGIN
            x_header_id      := SUBSTR (p_key, 1, INSTR (p_key, '-') - 1);
            x_container_id   := SUBSTR (p_key, INSTR (p_key, '-') + 1);
        END;

        PROCEDURE msg (p_debug_text    IN VARCHAR2,
                       p_debug_level   IN NUMBER := 1000)
        IS
        BEGIN
            do_debug_tools.msg (p_debug_text, p_debug_level);
            fnd_file.put_line (fnd_file.LOG, p_debug_text);
        --DBMS_OUTPUT.PUT_LINE (p_debug_text);
        END;
    BEGIN
        BEGIN
            SELECT mp.organization_id
              INTO l_org_id
              FROM apps.mtl_parameters mp
             WHERE 1 = 1 AND organization_code = 'MC1';
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('Org MC1 is not setup');
        END;

        BEGIN
            SELECT orgANIZATION_id
              INTO L_OU_ID
              FROM hr_operating_units
             WHERE name = 'Deckers Macau OU';
        EXCEPTION
            WHEN OTHERS
            THEN
                msg ('OU is not setup');
        END;


        msg ('Fetching Org Id ' || l_org_id);

        /* BEGIN
            SELECT fnd.user_id, fresp.responsibility_id, fresp.application_id
              INTO l_user_id, l_responsiblity_id, l_application_id
              FROM fnd_user fnd, fnd_responsibility_vl fresp
             WHERE     fnd.user_name = 'BT_O2C_INSTALL'
                   AND fresp.responsibility_name LIKE
                          'Deckers Order Management Manager - Macau';
         EXCEPTION
            WHEN OTHERS
            THEN
               msg (
                  'User "BT_O2C_INSTALL" or Responsiblity "Deckers Order Management Manager - Macau" have error ');
         END;



         apps.DO_APPS_INITIALIZE (l_user_id,
                                  l_responsiblity_id,
                                  l_application_id);*/
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', L_OU_ID);
        l_application_id     := fnd_global.resp_appl_id;
        l_responsiblity_id   := fnd_global.resp_id;
        l_user_id            := fnd_global.user_id;
        APPS.fnd_global.APPS_INITIALIZE (l_user_id,
                                         l_responsiblity_id,
                                         l_application_id);

        -- apps.fnd_profile.put ('MFG_ORGANIZATION_ID', l_org_id);
        do_debug_tools.enable_conc_log (100000);
        msg ('Start: ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS PM'));

        l_trx_date           := fnd_date.canonical_TO_DATE (p_ship_date);
        --Build Line Details--
        msg ('Building line details');

        msg ('p_org_name ==>' || p_org_name);

        IF p_org_name IN ('EMEA', 'JAPAN')
        THEN
            IF p_org_name = 'EMEA'
            THEN
                FOR c_line IN c_lines_emea
                LOOP
                    --XXEUR_AUTO_RES_LOTS_PROC(c_line.inventory_item_id,c_line.ship_from_org_id, c_line.header_id,c_line.line_id,x_errbuf,P_ORG_NAME,c_line.so_qty);
                    IF c_line.attribute16 IS NULL
                    THEN
                        update_order_attribute (c_line.line_id);
                    END IF;

                    l_line_containers (l_line_containers.COUNT + 1).line_id   :=
                        c_line.line_id;
                    l_line_containers (l_line_containers.COUNT).shipment_priority_code   :=
                        c_line.shipment_priority_code;

                    l_key   :=
                        make_key (c_line.header_id,
                                  TO_CHAR (c_line.delivery_name));


                    /* l_key :=
                    make_key (c_line.header_id,
                              NVL (TO_CHAR (c_line.container_id), '-NONE-'));*/
                    --commented on 7th july

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'IN EMEA Cursor: line_id' || c_line.line_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_line_containers (l_line_containers.COUNT + 1).shipment_priority_code:'
                        || c_line.shipment_priority_code);
                    -- fnd_file.put_line (fnd_file.log,'l_line_containers (l_line_containers.COUNT).shipment_priority_code:'||l_line_containers (l_line_containers.COUNT).shipment_priority_code);
                    fnd_file.put_line (fnd_file.LOG, 'l_key:' || l_key);

                    IF NOT l_hdr_ids.EXISTS (l_key)
                    THEN
                        l_hdr_ids (l_key)   := 1;
                    END IF;
                /*UPDATE oe_order_lines_all
                   SET shipment_priority_code =
                          NVL (TO_CHAR (c_line.container_id), '-NONE-')
                 WHERE line_id = c_line.line_id;

                UPDATE wsh_delivery_details
                   SET shipment_priority_code =
                          NVL (TO_CHAR (c_line.container_id), '-NONE-')
                 WHERE source_line_id = c_line.line_id AND source_code = 'OE';

                msg (
                      'Set SHIPMENT_PRIORITY_CODE='
                   || NVL (TO_CHAR (c_line.container_id), '-NONE-')
                   || ' for Line ID '
                   || c_line.line_id
                   || ', Header ID '
                   || c_line.header_id);*/
                --commented on 7th july
                END LOOP;
            ELSIF p_org_name = 'JAPAN'
            THEN
                FOR c_line IN c_lines_JAPAN
                LOOP
                    --XXEUR_AUTO_RES_LOTS_PROC(c_line.inventory_item_id,c_line.ship_from_org_id, c_line.header_id,c_line.line_id,x_errbuf,P_ORG_NAME,c_line.so_qty);
                    IF c_line.attribute16 IS NULL
                    THEN
                        update_order_attribute (c_line.line_id);
                    END IF;

                    l_line_containers (l_line_containers.COUNT + 1).line_id   :=
                        c_line.line_id;
                    l_line_containers (l_line_containers.COUNT).shipment_priority_code   :=
                        c_line.shipment_priority_code;

                    l_key   :=
                        make_key (c_line.header_id,
                                  TO_CHAR (c_line.delivery_name));


                    /* l_key :=
                    make_key (c_line.header_id,
                              NVL (TO_CHAR (c_line.container_id), '-NONE-'));*/
                    --commented on 7th july

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'IN JAPAN Cursor: line_id' || c_line.line_id);
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'l_line_containers (l_line_containers.COUNT + 1).shipment_priority_code:'
                        || c_line.shipment_priority_code);
                    -- fnd_file.put_line (fnd_file.log,'l_line_containers (l_line_containers.COUNT).shipment_priority_code:'||l_line_containers (l_line_containers.COUNT).shipment_priority_code);
                    fnd_file.put_line (fnd_file.LOG, 'l_key:' || l_key);

                    IF NOT l_hdr_ids.EXISTS (l_key)
                    THEN
                        l_hdr_ids (l_key)   := 1;
                    END IF;
                END LOOP;
            END IF;

            BEGIN
                v_count   := 0;
                --
                -- Sales Order Header Loop --
                --
                l_key     := l_hdr_ids.FIRST;
                fnd_file.put_line (fnd_file.LOG, 'l_key:' || l_key);

                WHILE l_key IS NOT NULL
                LOOP
                    break_key (l_key, l_header_id, l_delivery_name);
                    v_count           := v_count + 1;
                    msg (
                           '  Processing Header ID '
                        || l_header_id
                        || ', Delivery Name'
                        || l_delivery_name);
                    /*break_key (l_key, l_header_id, l_container_id);
                    v_count:=v_count+1;
                    msg (
                          '  Processing Header ID '
                       || l_header_id
                       || ', Container ID '
                       || l_container_id);*/
                    --commented on 7th july
                    l_pick_batch_id   := NULL;
                    l_batch_rowid     := NULL;
                    l_batch_name      := l_delivery_name;
                    msg ('    Inserting Pick Batch Row');
                    fnd_file.put_line (fnd_file.LOG, 'Count:' || v_count);

                    WSH_PICKING_BATCHES_PKG.Insert_Row (
                        x_rowid                        => l_batch_rowid,
                        x_batch_id                     => l_pick_batch_id,
                        p_creation_date                => SYSDATE,
                        p_created_by                   => fnd_global.user_id,
                        p_last_update_date             => SYSDATE,
                        p_last_updated_by              => fnd_global.user_id,
                        p_last_update_login            => -1,
                        x_name                         => l_batch_name,
                        p_backorders_only_flag         => 'I',
                        p_document_set_id              => NULL, --TO_NUMBER (fnd_profile.VALUE ('DO_WSH_PICK_DOC_SET_ID')),
                        p_existing_rsvs_only_flag      => 'Y',
                        p_shipment_priority_code       => l_delivery_name, -- l_container_id,
                        p_ship_method_code             => NULL,
                        p_customer_id                  => NULL,
                        p_order_header_id              => l_header_id,
                        p_ship_set_number              => NULL,
                        p_inventory_item_id            => NULL,
                        p_order_type_id                => NULL,
                        p_from_requested_date          => NULL,
                        p_to_requested_date            => NULL,
                        p_from_scheduled_ship_date     => NULL,
                        p_to_scheduled_ship_date       => NULL,
                        p_ship_to_location_id          => NULL,
                        p_ship_from_location_id        => NULL,
                        p_trip_id                      => NULL,
                        p_delivery_id                  => NULL,
                        p_include_planned_lines        => 'N',
                        p_pick_grouping_rule_id        => NULL,        --1006,
                        p_pick_sequence_rule_id        => NULL, --TO_NUMBER (fnd_profile.VALUE ( 'DO_WSH_PICK_SEQ_RULE_ID')),
                        p_autocreate_delivery_flag     => 'Y',
                        p_attribute_category           => NULL,
                        p_attribute1                   => NULL,
                        p_attribute2                   => NULL,
                        p_attribute3                   => NULL,
                        p_attribute4                   => NULL,
                        p_attribute5                   => NULL,
                        p_attribute6                   => NULL,
                        p_attribute7                   => NULL,
                        p_attribute8                   => NULL,
                        p_attribute9                   => NULL,
                        p_attribute10                  => NULL,
                        p_attribute11                  => NULL,
                        p_attribute12                  => NULL,
                        p_attribute13                  => NULL,
                        p_attribute14                  => NULL,
                        p_attribute15                  => NULL,
                        p_autodetail_pr_flag           => 'Y',
                        p_carrier_id                   => NULL,
                        p_trip_stop_id                 => NULL,
                        p_default_stage_subinventory   => 'FACTORY',
                        p_default_stage_locator_id     => NULL,
                        p_pick_from_subinventory       => 'FACTORY',
                        p_pick_from_locator_id         => NULL,
                        p_auto_pick_confirm_flag       => 'Y',
                        p_delivery_detail_id           => NULL,
                        p_project_id                   => NULL,
                        p_task_id                      => NULL,
                        p_organization_id              => l_org_id,
                        p_ship_confirm_rule_id         => NULL,
                        p_autopack_flag                => 'N',
                        p_autopack_level               => 0,
                        p_task_planning_flag           => 'N',
                        p_non_picking_flag             => NULL,
                        p_regionID                     => NULL,
                        p_zoneId                       => NULL,
                        p_categoryID                   => NULL,
                        p_categorySetID                => NULL,
                        p_acDelivCriteria              => NULL,
                        p_RelSubinventory              => NULL,
                        p_append_flag                  => NULL,
                        p_task_priority                => NULL,
                        P_Ship_Set_Smc_Flag            => NULL --- Added for pick release Public API
                                                              ,
                        p_actual_departure_date        => NULL,
                        p_allocation_method            => NULL       -- X-dock
                                                              ,
                        p_crossdock_criteria_id        => NULL       -- X-dock
                                                              -- but 5117876, following 14 attributes are added
                                                              ,
                        p_Delivery_Name_Lo             => l_delivery_name,
                        p_Delivery_Name_Hi             => l_delivery_name,
                        p_Bol_Number_Lo                => NULL,
                        p_Bol_Number_Hi                => NULL,
                        p_Intmed_Ship_To_Loc_Id        => NULL,
                        p_Pooled_Ship_To_Loc_Id        => NULL,
                        p_Fob_Code                     => NULL,
                        p_Freight_Terms_Code           => NULL,
                        p_Pickup_Date_Lo               => l_trx_date,
                        p_Pickup_Date_Hi               => l_trx_date,
                        p_Dropoff_Date_Lo              => NULL,
                        p_Dropoff_Date_Hi              => NULL,
                        p_Planned_Flag                 => NULL,
                        p_Selected_Batch_Id            => NULL);
                    msg ('    Releasing Pick Batch');
                    WSH_PICK_LIST.Release_Batch (
                        errbuf          => l_error_text,
                        retcode         => l_ret_stat,
                        p_batch_id      => l_pick_batch_id,
                        p_log_level     => 0,
                        p_num_workers   => 1);
                    msg ('      Ret: ' || l_ret_stat);
                    msg ('      Err: ' || l_error_text);
                    msg ('      Batch: ' || l_pick_batch_id);
                    --  COMMIT;
                    --
                    --dbms_lock.sleep(30);
                    --


                    msg ('      before delivery loop');

                    FOR c_delivery IN c_deliveries (l_header_id)
                    LOOP
                        msg (
                            '    Ship-Confirm Delivery ' || c_delivery.delivery_id);
                        APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION (
                            P_API_VERSION_NUMBER        => 1.0,
                            P_INIT_MSG_LIST             => NULL,
                            X_RETURN_STATUS             => RETSTAT,
                            X_MSG_COUNT                 => MSGCOUNT,
                            X_MSG_DATA                  => MSGDATA,
                            P_ACTION_CODE               => 'CONFIRM',
                            P_DELIVERY_ID               => c_delivery.delivery_id,
                            P_SC_ACTION_FLAG            => 'S',
                            P_SC_INTRANSIT_FLAG         => 'Y',
                            P_SC_CLOSE_TRIP_FLAG        => 'Y',
                            P_SC_DEFER_INTERFACE_FLAG   => 'N',
                            P_SC_ACTUAL_DEP_DATE        => l_trx_date,
                            p_wv_override_flag          => 'N',
                            X_TRIP_ID                   => X_TRIP_ID,
                            X_TRIP_NAME                 => l_delivery_name --X_TRIP_NAME
                                                                          );

                        --COMMIT;
                        --Deliveries Loop--

                        IF (RETSTAT <> wsh_util_core.g_ret_sts_success)
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'The confirm action on the delivery '
                                || c_delivery.delivery_id
                                || ' errored out.');

                            FOR i IN 1 .. MSGCOUNT
                            LOOP
                                apps.fnd_msg_pub.get (
                                    p_msg_index       => i,
                                    p_encoded         => fnd_api.g_false,
                                    p_data            => MSGDATA,
                                    p_msg_index_out   => lv_msg_index_out);

                                IF lv_error_message IS NULL
                                THEN
                                    lv_error_message   :=
                                        SUBSTR (MSGDATA, 1, 250);
                                ELSE
                                    lv_error_message   :=
                                           lv_error_message
                                        || ' /'
                                        || SUBSTR (MSGDATA, 1, 250);
                                END IF;

                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '------------------------------------------');
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Return Status: ' || RETSTAT);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Error Message :' || lv_error_message);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    '------------------------------------------');
                            END LOOP;
                        ELSE
                            fnd_file.put_line (
                                fnd_file.LOG,
                                   'The confirm action on the delivery '
                                || c_delivery.delivery_id
                                || ' is successful.');
                        END IF;

                        msg (
                            '  Finished Processing Header ID ' || l_header_id);
                        l_key   := l_hdr_ids.NEXT (l_key);

                        fnd_file.put_line (fnd_file.LOG,
                                           'Return Status: ' || RETSTAT);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Trip Id      : ' || X_TRIP_ID);
                        fnd_file.put_line (fnd_file.LOG,
                                           'Trip Name    : ' || X_TRIP_NAME);
                    END LOOP;
                END LOOP;
            EXCEPTION
                WHEN OTHERS
                THEN
                    fnd_file.put_line (fnd_file.LOG,
                                       'In exception:' || SQLERRM);
                    ROLLBACK;

                    --
                    -- Reset Shipment Priority Code Loop --
                    --
                    /*  FOR idx IN 1 .. l_line_containers.COUNT
                      LOOP
                         UPDATE oe_order_lines_all
                            SET shipment_priority_code =
                                   l_line_containers (idx).shipment_priority_code
                          WHERE line_id = l_line_containers (idx).line_id;

                         UPDATE wsh_delivery_details
                            SET shipment_priority_code =
                                   l_line_containers (idx).shipment_priority_code
                          WHERE     source_line_id = l_line_containers (idx).line_id
                                AND source_code = 'OE';
                      END LOOP;*/
                    --commented on 7th july

                    --COMMIT;
                    RAISE;
            END;
        ELSIF p_org_name = 'APAC'
        THEN
            FOR c_apac_del IN c_apac_deliveries
            LOOP
                c_lines_apac_tab.DELETE;
                MSG ('INSIDE LOOP1');

                OPEN c_lines_apac (c_apac_del.delivery_id);

                MSG ('INSIDE LOOP1.1');

                FETCH c_lines_apac BULK COLLECT INTO c_lines_apac_tab;

                MSG ('INSIDE LOOP1.2');

                CLOSE c_lines_apac;

                IF c_lines_apac_tab.COUNT > 0
                THEN
                    FOR I IN c_lines_apac_tab.FIRST .. c_lines_apac_tab.LAST
                    LOOP
                        MSG ('INSIDE LOOP2');
                        delete_reservation (x_retcode,
                                            x_errbuf,
                                            c_lines_apac_tab (I).line_id);

                        IF x_retcode = 1
                        THEN
                            RAISE EX_USER_EXP;
                        END IF;
                    END LOOP;

                    l_hdr_ids.delete;

                    --FOR c_line IN c_lines_apac (c_apac_del.delivery_id)
                    FOR J IN c_lines_apac_tab.FIRST .. c_lines_apac_tab.LAST
                    LOOP
                        MSG ('INSIDE LOOP3');
                        /*FOR J IN C_DELETE_DEL(C_LINE.LINE_ID)
                        LOOP
                        DELETE_DELIVERY(x_retcode,x_errbuf,J.DELIVERY_ID);
                        END LOOP;
                        IF x_retcode = 1
                        THEN
                        RAISE EX_USER_EXP;
                        END IF;*/

                        /*XXEUR_AUTO_RES_LOTS_PROC (c_line.inventory_item_id,
                                                  c_line.ship_from_org_id,
                                                  c_line.header_id,
                                                  c_line.line_id,
                                                  x_retcode,
                                                  x_errbuf,
                                                  P_ORG_NAME,
                                                  c_line.so_qty)
         IF x_retcode = 1
                        THEN
                           RAISE EX_USER_EXP;
                        END IF;

                        IF c_line.attribute16 IS NULL
                        THEN
                           update_order_attribute (c_line.line_id);
                        END IF;

                        l_line_containers (l_line_containers.COUNT + 1).line_id :=
                           c_line.line_id;
                        l_line_containers (l_line_containers.COUNT).shipment_priority_code :=
                           c_line.shipment_priority_code;


                        l_key :=
                           make_key (c_line.header_id, TO_CHAR (c_line.delivery_name));

                        --commented on 7th july

                        fnd_file.put_line (
                           fnd_file.LOG,
                           'IN apac Cursor: line_id' || c_line.line_id);
                        fnd_file.put_line (
                           fnd_file.LOG,
                              'l_line_containers (l_line_containers.COUNT + 1).shipment_priority_code:'
                           || c_line.shipment_priority_code);
                        -- fnd_file.put_line (fnd_file.log,'l_line_containers (l_line_containers.COUNT).shipment_priority_code:'||l_line_containers (l_line_containers.COUNT).shipment_priority_code);
                        fnd_file.put_line (fnd_file.LOG, 'l_key:' || l_key);

                        IF NOT l_hdr_ids.EXISTS (l_key)
                        THEN
                           l_hdr_ids (l_key) := 1;
                        END IF;

                        UPDATE oe_order_lines_all
                           SET shipment_priority_code =
                                  -- NVL (TO_CHAR (c_line.container_id), '-NONE-')--commented on 7th july
                                  NVL (TO_CHAR (c_line.delivery_name), '-NONE-')
                         WHERE line_id = c_line.line_id;

                        UPDATE wsh_delivery_details
                           SET shipment_priority_code =
                                  -- NVL (TO_CHAR (c_line.container_id), '-NONE-')--commented on 7th july
                                  NVL (TO_CHAR (c_line.delivery_name), '-NONE-')
                         WHERE source_line_id = c_line.line_id AND source_code = 'OE';

                        msg (
                              'Set SHIPMENT_PRIORITY_CODE='
                           --|| NVL (TO_CHAR (c_line.container_id), '-NONE-')--commented on 7th july
                           || NVL (TO_CHAR (c_line.delivery_name), '-NONE-')
                           || ' for Line ID '
                           || c_line.line_id
                           || ', Header ID '
                           || c_line.header_id);*/

                        XXEUR_AUTO_RES_LOTS_PROC (
                            c_lines_apac_tab (J).inventory_item_id,
                            c_lines_apac_tab (J).ship_from_org_id,
                            c_lines_apac_tab (J).header_id,
                            c_lines_apac_tab (J).line_id,
                            x_retcode,
                            x_errbuf,
                            P_ORG_NAME,
                            c_lines_apac_tab (J).so_qty);

                        IF x_retcode = 1
                        THEN
                            RAISE EX_USER_EXP;
                        END IF;

                        IF c_lines_apac_tab (J).attribute16 IS NULL
                        THEN
                            update_order_attribute (
                                c_lines_apac_tab (J).line_id);
                        END IF;

                        l_line_containers (l_line_containers.COUNT + 1).line_id   :=
                            c_lines_apac_tab (J).line_id;
                        l_line_containers (l_line_containers.COUNT).shipment_priority_code   :=
                            c_lines_apac_tab (J).shipment_priority_code;


                        l_key   :=
                            make_key (
                                c_lines_apac_tab (J).header_id,
                                TO_CHAR (c_lines_apac_tab (J).delivery_name));


                        /* l_key :=
                            make_key (c_line.header_id,
                                      NVL (TO_CHAR (c_line.container_id), '-NONE-'));*/
                        --commented on 7th july

                        fnd_file.put_line (
                            fnd_file.LOG,
                               'IN apac Cursor: line_id'
                            || c_lines_apac_tab (J).line_id);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'l_line_containers (l_line_containers.COUNT + 1).shipment_priority_code:'
                            || c_lines_apac_tab (J).shipment_priority_code);
                        -- fnd_file.put_line (fnd_file.log,'l_line_containers (l_line_containers.COUNT).shipment_priority_code:'||l_line_containers (l_line_containers.COUNT).shipment_priority_code);
                        fnd_file.put_line (fnd_file.LOG, 'l_key:' || l_key);

                        IF NOT l_hdr_ids.EXISTS (l_key)
                        THEN
                            l_hdr_ids (l_key)   := 1;
                        END IF;

                        UPDATE oe_order_lines_all
                           SET shipment_priority_code = -- NVL (TO_CHAR (c_line.container_id), '-NONE-')--commented on 7th july
                                                        NVL (TO_CHAR (c_lines_apac_tab (J).delivery_name), '-NONE-')
                         WHERE line_id = c_lines_apac_tab (J).line_id;

                        UPDATE wsh_delivery_details
                           SET shipment_priority_code = -- NVL (TO_CHAR (c_line.container_id), '-NONE-')--commented on 7th july
                                                        NVL (TO_CHAR (c_lines_apac_tab (J).delivery_name), '-NONE-')
                         WHERE     source_line_id =
                                   c_lines_apac_tab (J).line_id
                               AND source_code = 'OE';

                        msg (
                               'Set SHIPMENT_PRIORITY_CODE='
                            --|| NVL (TO_CHAR (c_line.container_id), '-NONE-')--commented on 7th july
                            || NVL (
                                   TO_CHAR (
                                       c_lines_apac_tab (J).delivery_name),
                                   '-NONE-')
                            || ' for Line ID '
                            || c_lines_apac_tab (J).line_id
                            || ', Header ID '
                            || c_lines_apac_tab (J).header_id);
                    END LOOP;

                    --END IF;

                    BEGIN
                        v_count   := 0;
                        --
                        -- Sales Order Header Loop --
                        --
                        l_key     := l_hdr_ids.FIRST;
                        fnd_file.put_line (fnd_file.LOG, 'l_key:' || l_key);

                        WHILE l_key IS NOT NULL
                        LOOP
                            break_key (l_key, l_header_id, l_delivery_name);
                            v_count           := v_count + 1;
                            msg (
                                   '  Processing Header ID '
                                || l_header_id
                                || ', Delivery Name'
                                || l_delivery_name);


                            /*break_key (l_key, l_header_id, l_container_id);
                            v_count:=v_count+1;
                            msg (
                                  '  Processing Header ID '
                               || l_header_id
                               || ', Container ID '
                               || l_container_id);*/
                            --commented on 7th july
                            l_pick_batch_id   := NULL;
                            l_batch_rowid     := NULL;
                            l_batch_name      := l_delivery_name;
                            msg ('    Inserting Pick Batch Row');
                            fnd_file.put_line (fnd_file.LOG,
                                               'Count:' || v_count);

                            WSH_PICKING_BATCHES_PKG.Insert_Row (
                                x_rowid                        => l_batch_rowid,
                                x_batch_id                     => l_pick_batch_id,
                                p_creation_date                => SYSDATE,
                                p_created_by                   => fnd_global.user_id,
                                p_last_update_date             => SYSDATE,
                                p_last_updated_by              => fnd_global.user_id,
                                p_last_update_login            => -1,
                                x_name                         => l_batch_name,
                                p_backorders_only_flag         => 'I',
                                p_document_set_id              => NULL, --TO_NUMBER (fnd_profile.VALUE ('DO_WSH_PICK_DOC_SET_ID')),
                                p_existing_rsvs_only_flag      => 'Y',
                                p_shipment_priority_code       => l_delivery_name, -- l_container_id,
                                p_ship_method_code             => NULL,
                                p_customer_id                  => NULL,
                                p_order_header_id              => l_header_id,
                                p_ship_set_number              => NULL,
                                p_inventory_item_id            => NULL,
                                p_order_type_id                => NULL,
                                p_from_requested_date          => NULL,
                                p_to_requested_date            => NULL,
                                p_from_scheduled_ship_date     => NULL,
                                p_to_scheduled_ship_date       => NULL,
                                p_ship_to_location_id          => NULL,
                                p_ship_from_location_id        => NULL,
                                p_trip_id                      => NULL,
                                p_delivery_id                  => NULL, --c_apac_del.delivery_id,
                                p_include_planned_lines        => 'N',
                                p_pick_grouping_rule_id        => NULL, --1006,
                                p_pick_sequence_rule_id        => NULL, --TO_NUMBER (fnd_profile.VALUE ( 'DO_WSH_PICK_SEQ_RULE_ID')),
                                p_autocreate_delivery_flag     => 'Y',
                                p_attribute_category           => NULL,
                                p_attribute1                   => NULL,
                                p_attribute2                   => NULL,
                                p_attribute3                   => NULL,
                                p_attribute4                   => NULL,
                                p_attribute5                   => NULL,
                                p_attribute6                   => NULL,
                                p_attribute7                   => NULL,
                                p_attribute8                   => NULL,
                                p_attribute9                   => NULL,
                                p_attribute10                  => NULL,
                                p_attribute11                  => NULL,
                                p_attribute12                  => NULL,
                                p_attribute13                  => NULL,
                                p_attribute14                  => NULL,
                                p_attribute15                  => NULL,
                                p_autodetail_pr_flag           => 'Y',
                                p_carrier_id                   => NULL,
                                p_trip_stop_id                 => NULL,
                                p_default_stage_subinventory   => 'FACTORY',
                                p_default_stage_locator_id     => NULL,
                                p_pick_from_subinventory       => 'FACTORY',
                                p_pick_from_locator_id         => NULL,
                                p_auto_pick_confirm_flag       => 'Y',
                                p_delivery_detail_id           => NULL,
                                p_project_id                   => NULL,
                                p_task_id                      => NULL,
                                p_organization_id              => l_org_id,
                                p_ship_confirm_rule_id         => NULL,
                                p_autopack_flag                => 'N',
                                p_autopack_level               => 0,
                                p_task_planning_flag           => 'N',
                                p_non_picking_flag             => NULL,
                                p_regionID                     => NULL,
                                p_zoneId                       => NULL,
                                p_categoryID                   => NULL,
                                p_categorySetID                => NULL,
                                p_acDelivCriteria              => NULL,
                                p_RelSubinventory              => NULL,
                                p_append_flag                  => NULL,
                                p_task_priority                => NULL,
                                P_Ship_Set_Smc_Flag            => NULL --- Added for pick release Public API
                                                                      ,
                                p_actual_departure_date        => NULL,
                                p_allocation_method            => NULL -- X-dock
                                                                      ,
                                p_crossdock_criteria_id        => NULL -- X-dock
                                                                      -- but 5117876, following 14 attributes are added
                                                                      ,
                                p_Delivery_Name_Lo             =>
                                    l_delivery_name,
                                p_Delivery_Name_Hi             =>
                                    l_delivery_name,
                                p_Bol_Number_Lo                => NULL,
                                p_Bol_Number_Hi                => NULL,
                                p_Intmed_Ship_To_Loc_Id        => NULL,
                                p_Pooled_Ship_To_Loc_Id        => NULL,
                                p_Fob_Code                     => NULL,
                                p_Freight_Terms_Code           => NULL,
                                p_Pickup_Date_Lo               => l_trx_date,
                                p_Pickup_Date_Hi               => l_trx_date,
                                p_Dropoff_Date_Lo              => NULL,
                                p_Dropoff_Date_Hi              => NULL,
                                p_Planned_Flag                 => NULL,
                                p_Selected_Batch_Id            => NULL);
                            msg ('    Releasing Pick Batch');
                            WSH_PICK_LIST.Release_Batch (
                                errbuf          => l_error_text,
                                retcode         => l_ret_stat,
                                p_batch_id      => l_pick_batch_id,
                                p_log_level     => 5,
                                p_num_workers   => 1);
                            msg ('      Ret: ' || l_ret_stat);
                            msg ('      Err: ' || l_error_text);
                            msg ('      Batch: ' || l_pick_batch_id);
                            --  COMMIT;
                            --
                            --dbms_lock.sleep(30);
                            --
                            /*  SELECT wda.delivery_id
                              into l_delivery_id
                        FROM wsh_delivery_assignments wda,
                             wsh_delivery_details wdd,
                             oe_order_lines_all oola,
                            -- mtl_demand md,
                             mtl_reservations mr
                       WHERE     oola.header_id = 736041
                             AND wdd.source_code = 'OE'
                             AND wdd.source_line_id = oola.line_id
                             AND wda.delivery_detail_id = wdd.delivery_detail_id
                            -- AND md.demand_source_line = TO_CHAR (oola.line_id)
                            AND mr.orig_supply_source_line_id is null
                             AND mr.demand_source_line_id = oola.line_id
                             AND wdd.released_status = 'Y'
                              AND oola.flow_status_code in('AWAITING_SHIPPING','SUPPLY_PARTIAL','PO_PARTIAL')
                             and oola.line_number = 5;*/


                            msg ('      before delivery ');

                            FOR c_delivery
                                IN c_deliveries_new (l_header_id,
                                                     l_delivery_name)
                            LOOP
                                msg (
                                       '    Ship-Confirm Delivery '
                                    || c_delivery.delivery_id  --l_delivery_id
                                                             );
                                APPS.Wsh_Deliveries_Pub.DELIVERY_ACTION (
                                    P_API_VERSION_NUMBER        => 1.0,
                                    P_INIT_MSG_LIST             => NULL,
                                    X_RETURN_STATUS             => RETSTAT,
                                    X_MSG_COUNT                 => MSGCOUNT,
                                    X_MSG_DATA                  => MSGDATA,
                                    P_ACTION_CODE               => 'CONFIRM',
                                    P_DELIVERY_ID               =>
                                        c_delivery.delivery_id, --l_delivery_id
                                    P_SC_ACTION_FLAG            => 'S',
                                    P_SC_INTRANSIT_FLAG         => 'Y',
                                    P_SC_CLOSE_TRIP_FLAG        => 'Y',
                                    P_SC_DEFER_INTERFACE_FLAG   => 'Y',
                                    P_SC_ACTUAL_DEP_DATE        => l_trx_date,
                                    p_wv_override_flag          => 'N',
                                    X_TRIP_ID                   => X_TRIP_ID,
                                    X_TRIP_NAME                 =>
                                        l_delivery_name          --X_TRIP_NAME
                                                       );

                                --COMMIT;
                                --Deliveries Loop--

                                IF (RETSTAT <> wsh_util_core.g_ret_sts_success)
                                THEN
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'The confirm action on the delivery '
                                        || c_delivery.delivery_id --l_delivery_id
                                        || ' errored out.');

                                    FOR i IN 1 .. MSGCOUNT
                                    LOOP
                                        apps.fnd_msg_pub.get (
                                            p_msg_index   => i,
                                            p_encoded     => fnd_api.g_false,
                                            p_data        => MSGDATA,
                                            p_msg_index_out   =>
                                                lv_msg_index_out);

                                        IF lv_error_message IS NULL
                                        THEN
                                            lv_error_message   :=
                                                SUBSTR (MSGDATA, 1, 250);
                                        ELSE
                                            lv_error_message   :=
                                                   lv_error_message
                                                || ' /'
                                                || SUBSTR (MSGDATA, 1, 250);
                                        END IF;
                                    END LOOP;

                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        '------------------------------------------');
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                        'Error Message :' || lv_error_message);
                                    ROLLBACK;
                                ELSE
                                    fnd_file.put_line (
                                        fnd_file.LOG,
                                           'The confirm action on the delivery '
                                        || c_delivery.delivery_id -- l_delivery_id
                                        || ' is successful.');
                                    SUBMIT_INTERFACE_TRIP_STOP (
                                        x_retcode,
                                        x_errbuf,
                                        c_delivery.delivery_id);

                                    IF x_retcode = 1
                                    THEN
                                        RAISE EX_USER_EXP;
                                    ELSE
                                        COMMIT;
                                    END IF;
                                END IF;


                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Return Status: ' || RETSTAT);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Trip Id      : ' || X_TRIP_ID);
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                    'Trip Name    : ' || X_TRIP_NAME);
                            END LOOP;

                            msg (
                                   '  Finished Processing Header ID '
                                || l_header_id);
                            l_key             := l_hdr_ids.NEXT (l_key);
                        END LOOP;
                    --Sales Order Header Loop--

                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (fnd_file.LOG,
                                               'In exception:' || SQLERRM);
                            ROLLBACK;
                            RAISE;
                    END;
                ELSE
                    MSG ('INSIDE ELSE');
                END IF;
            END LOOP;
        END IF;


        msg (   'Workflow Background: '
             || fnd_request.submit_request (application   => 'FND',
                                            program       => 'FNDWFBG',
                                            argument1     => '',
                                            argument2     => '',
                                            argument3     => '',
                                            argument4     => 'Y',
                                            argument5     => 'Y',
                                            argument6     => 'N'));
        COMMIT;
        msg ('End: ' || TO_CHAR (SYSDATE, 'MM/DD/YYYY HH:MI:SS PM'));

        FOR I IN C_UPDATE_ATTR15
        LOOP
            UPDATE APPS.RCV_SHIPMENT_LINES
               SET ATTRIBUTE15   = I.OLD_SHIPMENT_LINE_ID
             WHERE SHIPMENT_LINE_ID = I.SHIPMENT_LINE_ID;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN ex_user_EXP
        THEN
            x_retcode   := 1;
            apps.fnd_file.put_line (apps.fnd_file.LOG, x_errbuf);
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'In main exception:' || SQLERRM);
    END BACK_TO_BACK_SHIP;

    PROCEDURE UPDATE_ORDER_ATTRIBUTE (p_line_id IN NUMBER)
    IS
        v_line_id            NUMBER;
        v_line_location_id   NUMBER;
    BEGIN
            SELECT oola.line_id, pda.line_location_id
              INTO v_line_id, v_line_location_id
              FROM mtl_reservations mr, oe_order_lines_all oola, po_requisition_lines_all prla,
                   po_req_distributions_all prda, po_distributions_all pda, oe_order_headers_all ooha
             WHERE     mr.DEMAND_SOURCE_LINE_ID = oola.line_id
                   --AND ooha.header_id = 42586
                   AND mr.ORIG_SUPPLY_SOURCE_LINE_ID = prla.REQUISITION_LINE_ID
                   AND ooha.header_id = oola.header_id
                   AND prla.REQUISITION_LINE_ID = prda.REQUISITION_LINE_ID
                   AND prda.DISTRIBUTION_ID = pda.REQ_DISTRIBUTION_ID
                   AND oola.line_id = p_line_id
        FOR UPDATE OF oola.attribute16;


        UPDATE oe_order_lines_all
           SET attribute16   = v_line_location_id
         WHERE line_id = v_line_id;
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'no data found during update attribute16');
        WHEN OTHERS
        THEN
            FND_FILE.PUT_LINE (FND_FILE.LOG,
                               'error during update' || SQLERRM);
    END;

    PROCEDURE XXEUR_AUTO_RES_LOTS_PROC (p_item_id     IN            NUMBER,
                                        p_org_id      IN            NUMBER,
                                        p_header_id   IN            NUMBER,
                                        p_line_id     IN            NUMBER,
                                        --  p_subin_code    IN     VARCHAR,
                                        x_retcode        OUT NOCOPY NUMBER,
                                        x_err_msg        OUT NOCOPY VARCHAR2,
                                        p_scenario    IN            VARCHAR2,
                                        P_SO_QTY      IN            VARCHAR2)
    IS
        ln_total_atr                  NUMBER := 0;
        ln_so_qty                     NUMBER := 0;
        ln_line_id                    NUMBER := 0;
        x_return_status               VARCHAR2 (5) := NULL;
        x_msg_count                   NUMBER := 0;
        x_msg_data                    VARCHAR2 (4000) := NULL;
        ln_qty_left_tbr               NUMBER := 0;
        ln_qty_tbr                    NUMBER := 0;
        x_qty                         NUMBER := 0;
        x_rsv_id                      NUMBER := 0;
        x_status                      VARCHAR2 (50) := 'SUCCESS';
        x_msg_cnt                     NUMBER := 0;
        x_msg_dta                     VARCHAR2 (250);
        v_msg_index_out               VARCHAR2 (20);
        ld_request_date               DATE;
        lc_item_name                  VARCHAR2 (1000);
        p_dummy_sn                    inv_reservation_global.serial_number_tbl_type;
        x_dummy_sn                    inv_reservation_global.serial_number_tbl_type;
        lc_uom                        oe_order_lines_all.order_quantity_uom%TYPE := NULL;
        l_hold_source_rec             oe_holds_pvt.hold_source_rec_type;
        l_rsv                         inv_reservation_global.mtl_reservation_rec_type;
        ln_header_id                  oe_order_headers_all.header_id%TYPE := NULL;
        p_rsv                         inv_reservation_global.mtl_reservation_rec_type;
        ln_so_id                      mtl_sales_orders.sales_order_id%TYPE := NULL;
        lc_hold_name                  oe_hold_definitions.name%TYPE := NULL;
        ln_reservation_id             mtl_reservations.reservation_id%TYPE := NULL;
        ex_no_lot                     EXCEPTION;
        ex_user_defined               EXCEPTION;
        gc_error                      VARCHAR2 (250);
        ln_demand_source_type_id      NUMBER;
        ln_supply_source_type_id      NUMBER;
        ln_DESTINATION_SUBINVENTORY   VARCHAR2 (100);

        CURSOR lcu_so_lots_cur (p_item_id NUMBER, p_organization_id NUMBER --,  p_subinv_code                     VARCHAR
                                                                          )
        IS
            SELECT moqd.subinventory_code, NVL2 (MIL.segment1, MIL.segment1 || '.' || MIL.segment2 || '.' || MIL.segment3 || '.' || MIL.segment4 || '.' || MIL.segment5, NULL) LOCATOR, MOQD.locator_id
              FROM mtl_item_locations MIL, mtl_onhand_quantities_detail MOQD
             WHERE     1 = 1
                   AND MOQD.inventory_item_id = p_item_id
                   AND MOQD.organization_id = p_org_id                   --129
                   AND MOQD.inventory_item_id = MIL.inventory_item_id(+)
                   AND MOQD.organization_id = MIL.organization_id(+)
                   AND MIL.inventory_location_id(+) = MOQD.locator_id;

        -- AND NVL(moqd.subinventory_code,1) = NVL(p_subinv_code,NVL(MIL.subinventory_code,1)  );

        TYPE lcu_so_lots_tb_type IS TABLE OF lcu_so_lots_cur%ROWTYPE
            INDEX BY BINARY_INTEGER;

        lcu_so_lots_type              lcu_so_lots_tb_type;

        CURSOR lcu_reservation (p_line_id NUMBER)
        IS
            SELECT reservation_id
              INTO ln_reservation_id
              FROM mtl_reservations
             WHERE     demand_source_line_id = p_line_id
                   AND (orig_supply_source_line_id IS NULL OR supply_source_line_id IS NULL);
    BEGIN
        x_err_msg                            := 'SUCCESS';
        mo_global.init ('ONT');
        mo_global.set_policy_context ('S', p_org_id);
        fnd_global.apps_initialize (fnd_global.USER_ID,
                                    fnd_global.RESP_ID,
                                    fnd_global.RESP_APPL_ID);
        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
               '******************Starting Procedure XXEUR_AUTO_RES_LOTS_PROC for Item '
            || p_item_id
            || ' and Org '
            || p_org_id                --|| ' and Subinv Code '|| p_subin_code
                       );


        BEGIN
            IF p_scenario = 'APAC'
            THEN
                SELECT P_SO_QTY so_qty, OOLA.line_id, OOLA.header_id,
                       MSI.primary_uom_code, MSO.sales_order_id, OOLA.request_date,
                       MSIB.description    -- ,nvl(mr.demand_source_type_id,8)
                                       , /*( SELECT nvl(mr.demand_source_type_id,8)
                                         FROM apps.mtl_reservations mr
                                         WHERE  mr.demand_source_line_id = oola.line_id
                                            AND mr.organization_id = 129
                                             AND mr.orig_supply_source_line_id is null)*/
                                         8 demand_source_type_id, /*( SELECT nvl(mr.supply_source_type_id,13)
                                                               FROM apps.mtl_reservations mr
                                                               WHERE  mr.demand_source_line_id = oola.line_id
                                                                  AND mr.organization_id = 129
                                                                   AND mr.orig_supply_source_line_id is null)*/
                                                                  13 supply_source_type_id --,nvl(mr.supply_source_type_id,13)
                                                                                          ,
                       UPPER (PdA.DESTINATION_SUBINVENTORY)
                  INTO ln_so_qty, ln_line_id, ln_header_id, lc_uom,
                                ln_so_id, ld_request_date, lc_item_name,
                                ln_demand_source_type_id, ln_supply_source_type_id, ln_DESTINATION_SUBINVENTORY
                  FROM oe_order_headers_all OOHA, oe_order_lines_all OOLA, mtl_sales_orders MSO,
                       mtl_system_items MSI, mtl_system_items_b MSIB, po_line_locations_all plla,
                       po_distributions_all pda, po_lines_all pla, po_requisition_lines_all porl,
                       po_requisition_headers_all porh
                 -- ,apps.mtl_reservations mr
                 WHERE     OOHA.header_id = OOLA.header_id
                       AND MSO.segment1 = OOHA.order_number
                       AND MSI.inventory_item_id = OOLA.inventory_item_id
                       AND MSIB.inventory_item_id = OOLA.inventory_item_id
                       AND MSIB.organization_id = OOLA.ship_from_org_id
                       AND MSI.organization_id = p_org_id
                       AND OOHA.header_id = p_header_id
                       AND OOLA.line_id = p_line_id
                       AND oola.attribute16 = plla.line_location_id
                       AND ooha.orig_sys_document_ref = porh.segment1
                       AND plla.po_line_id = pla.po_line_id
                       AND plla.line_location_id = pda.line_location_id
                       AND porl.requisition_line_id = oola.source_document_line_id -- AND oola.flow_status_code IN
                  --        ('AWAITING_SHIPPING', 'PO_RECEIVED', 'PO_PARTIAL')
                ;
            ELSIF p_scenario = 'EMEA'
            THEN
                SELECT P_SO_QTY so_qty, OOLA.line_id, OOLA.header_id,
                       MSI.primary_uom_code, MSO.sales_order_id, OOLA.request_date,
                       MSIB.description, NVL (mr.demand_source_type_id, 8), NVL (mr.supply_source_type_id, 13),
                       UPPER (PdA.DESTINATION_SUBINVENTORY)
                  INTO ln_so_qty, ln_line_id, ln_header_id, lc_uom,
                                ln_so_id, ld_request_date, lc_item_name,
                                ln_demand_source_type_id, ln_supply_source_type_id, ln_DESTINATION_SUBINVENTORY
                  FROM oe_order_headers_all OOHA, oe_order_lines_all OOLA, mtl_sales_orders MSO,
                       mtl_system_items MSI, mtl_system_items_b MSIB, po_line_locations_all plla,
                       po_lines_all pla, po_distributions_all pda, po_requisition_lines_all porl,
                       po_requisition_headers_all porh, apps.mtl_reservations mr
                 WHERE     OOHA.header_id = OOLA.header_id
                       AND MSO.segment1 = OOHA.order_number
                       AND MSI.inventory_item_id = OOLA.inventory_item_id
                       AND MSIB.inventory_item_id = OOLA.inventory_item_id
                       AND MSIB.organization_id = OOLA.ship_from_org_id
                       AND mr.demand_source_line_id = oola.line_id
                       AND mr.organization_id = MSI.organization_id
                       AND MSI.organization_id = p_org_id
                       AND OOHA.header_id = p_header_id
                       AND OOLA.line_id = p_line_id
                       AND oola.attribute16 = plla.line_location_id
                       AND ooha.orig_sys_document_ref = porh.segment1
                       AND plla.po_line_id = pla.po_line_id
                       AND plla.line_location_id = pda.line_location_id
                       AND porl.requisition_line_id = oola.source_document_line_id --AND oola.flow_status_code IN
                         -- ('AWAITING_SHIPPING', 'PO_RECEIVED', 'PO_PARTIAL')
                ;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                gc_error   :=
                       'No SO details fetched for SO -'
                    || p_header_id
                    || ' and line-'
                    || p_line_id;
                RAISE ex_user_defined;
            WHEN OTHERS
            THEN
                gc_error   := 'Unexpected error while gathering SO Details';
                RAISE ex_user_defined;
        END;

        --  apps.fnd_file.put_line (apps.fnd_file.LOG,
        --                              'SO Quantity for SO - '
        --            || p_so_number
        --            || ' and line -'
        --            || p_so_line_num || ' is ' ||ln_so_qty );

        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Sales Order id-' || p_header_id);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Sales Order Line id-' || p_line_id);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Item Name-' || lc_item_name);
        apps.fnd_file.put_line (apps.fnd_file.LOG,
                                'Line Quantity-' || ln_so_qty);

        --Start : delete any reservation if present

        /* FOR i IN lcu_reservation (ln_line_id)
         LOOP
            apps.fnd_file.put_line (
               apps.fnd_file.LOG,
                  'Reservation Id for SO Line Id '
               || ln_line_id
               || ' is '
               || i.reservation_id);

            l_rsv.reservation_id := i.reservation_id;

            apps.fnd_file.put_line (
               apps.fnd_file.LOG,
                  'Calling delete reservation api for reservation id '
               || i.reservation_id);

            inv_reservation_pub.delete_reservation (
               p_api_version_number   => 1.0,
               p_init_msg_lst         => fnd_api.g_true,
               x_return_status        => x_status,
               x_msg_count            => x_msg_count,
               x_msg_data             => x_msg_data,
               p_rsv_rec              => l_rsv,
               p_serial_number        => p_dummy_sn);

            IF x_status = fnd_api.g_ret_sts_success
            THEN
               apps.fnd_file.put_line (apps.fnd_file.LOG, 'Reservation deleted');
            ELSE
            x_retcode := 1;
               IF x_msg_count >= 1
               THEN
                  FOR I IN 1 .. x_msg_count
                  LOOP
                     DBMS_OUTPUT.put_line (
                           I
                        || '. '
                        || SUBSTR (
                              FND_MSG_PUB.Get (p_encoded => FND_API.G_FALSE),
                              1,
                              255));
                  END LOOP;
               END IF;
            END IF;
         --End : delete any reservation if present

         END LOOP;*/
        --commented on 30/07/15


        /* OPEN lcu_so_lots_cur(p_item_id  ,p_org_id);

         LOOP
            FETCH lcu_so_lots_cur BULK COLLECT INTO   lcu_so_lots_type;

            IF lcu_so_lots_type.COUNT = 0
            THEN
               gc_error := 'No Lots fetched for the item';
               RAISE ex_no_lot;
            END IF;

            FOR z IN lcu_so_lots_type.FIRST .. lcu_so_lots_type.LAST
            LOOP*/
        --COMMENTED ON 23/07/15


        p_rsv.organization_id                := p_org_id;
        p_rsv.inventory_item_id              := p_item_id;
        p_rsv.demand_source_type_id          := ln_demand_source_type_id; --inv_reservation_global.g_source_type_oe;
        p_rsv.demand_source_name             := NULL;
        p_rsv.demand_source_header_id        := ln_so_id;
        p_rsv.demand_source_line_id          := ln_line_id;
        p_rsv.primary_uom_code               := lc_uom;
        p_rsv.primary_uom_id                 := NULL;
        p_rsv.reservation_uom_code           := lc_uom;
        p_rsv.reservation_uom_id             := NULL;
        p_rsv.lot_number                     := NULL;
        p_rsv.reservation_id                 := NULL;
        p_rsv.requirement_date               := ld_request_date;
        p_rsv.subinventory_code              := ln_DESTINATION_SUBINVENTORY; --lcu_so_lots_type (z).subinventory_code;
        p_rsv.subinventory_id                := NULL;
        p_rsv.locator_id                     := NULL; --lcu_so_lots_type (z).locator_id;
        p_rsv.autodetail_group_id            := NULL;
        p_rsv.external_source_code           := NULL;
        p_rsv.external_source_line_id        := NULL;
        p_rsv.supply_source_type_id          := ln_supply_source_type_id; --inv_reservation_global.g_source_type_inv;
        p_rsv.supply_source_header_id        := NULL;
        p_rsv.supply_source_line_id          := NULL;
        p_rsv.supply_source_name             := NULL;
        p_rsv.supply_source_line_detail      := NULL;
        p_rsv.revision                       := NULL;
        p_rsv.ship_ready_flag                := NULL;
        p_rsv.attribute_category             := NULL;
        p_rsv.attribute1                     := NULL;
        p_rsv.attribute2                     := NULL;
        p_rsv.attribute3                     := NULL;
        p_rsv.attribute4                     := NULL;
        p_rsv.attribute5                     := NULL;
        p_rsv.attribute6                     := NULL;
        p_rsv.attribute7                     := NULL;
        p_rsv.attribute8                     := NULL;
        p_rsv.attribute9                     := NULL;
        p_rsv.attribute10                    := NULL;
        p_rsv.attribute11                    := NULL;
        p_rsv.attribute12                    := NULL;
        p_rsv.attribute13                    := NULL;
        p_rsv.attribute14                    := NULL;
        p_rsv.attribute15                    := NULL;
        p_rsv.pick_slip_number               := NULL;
        p_rsv.lpn_id                         := NULL;
        p_rsv.lot_number_id                  := NULL;
        p_rsv.demand_source_delivery         := NULL;


        --reservation api
        p_rsv.reservation_quantity           := ln_so_qty;
        p_rsv.primary_reservation_quantity   := ln_so_qty;

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            'Calling Reservation API for Lot- ' || ' Quantity ' || ln_so_qty);

        inv_reservation_pub.create_reservation (
            p_api_version_number   => 1.0,
            x_return_status        => x_status,
            x_msg_count            => x_msg_count,
            x_msg_data             => x_msg_data,
            p_rsv_rec              => p_rsv,
            p_serial_number        => p_dummy_sn,
            x_serial_number        => x_dummy_sn,
            x_quantity_reserved    => x_qty,
            x_reservation_id       => x_rsv_id);

        IF (x_status <> fnd_api.g_ret_sts_success)
        THEN
            x_retcode   := 1;

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                fnd_msg_pub.get (p_msg_index => j, p_encoded => 'F', p_data => x_msg_data
                                 , p_msg_index_out => v_msg_index_out);
            END LOOP;

            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'The Required Quantity is not allocated:' || x_msg_data);
        ELSE
            fnd_file.put_line (apps.fnd_file.LOG,
                               'quantity reserved' || x_rsv_id);
        --  apps.fnd_file.put_line ( apps.fnd_file.LOG, 'Lot Quantity-' || lcu_so_lots_type (z).avail_to_reserve);
        --   apps.fnd_file.put_line ( apps.fnd_file.LOG, 'Reserved Quantity for Lo '|| lcu_so_lots_type (z).lot_number || ' is ' || ln_qty_tbr);

        --    ln_qty_left_tbr := ln_qty_tbr - ln_so_qty;
        END IF;

        /* IF ln_qty_left_tbr<= 0 THEN


             COMMIT;
         END IF;


   END LOOP;

   EXIT WHEN lcu_so_lots_cur%NOTFOUND;
END LOOP;*/
        --commented on 23/7/15

        apps.fnd_file.put_line (
            apps.fnd_file.LOG,
            '******************End of  Procedure XXEUR_AUTO_RES_LOTS_PROC*********************');
    EXCEPTION
        WHEN ex_no_lot
        THEN
            x_err_msg   := 'SUCCESS';
            apps.fnd_file.put_line (apps.fnd_file.LOG, x_err_msg);
        WHEN ex_user_defined
        THEN
            x_retcode   := 1;
            x_err_msg   := SQLERRM || '-' || gc_error;
            apps.fnd_file.put_line (apps.fnd_file.LOG, x_err_msg);
        WHEN OTHERS
        THEN
            x_retcode   := 1;
            x_err_msg   := 'FAILURE-' || SQLERRM;
            apps.fnd_file.put_line (apps.fnd_file.LOG, x_err_msg);
    END XXEUR_AUTO_RES_LOTS_PROC;
END XXD_ISO_B2B_SHIP_CONV_PKG;
/
