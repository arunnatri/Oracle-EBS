--
-- XXDOEC_PROCESS_CP_SHIPMENTS  (Package Body) 
--
/* Formatted on 4/26/2023 4:40:55 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDOEC_PROCESS_CP_SHIPMENTS"
IS
    /****************************************************************************
      Modification history:
     ****************************************************************************
         NAME:        XXDOEC_PROCESS_CP_SHIPMENTS
         PURPOSE:      Package will be used to receive the PO lines and for Pick/Ship Confirm

         REVISIONS:
         Version        Date        Author           Description
         ---------  ----------  ---------------  ---------------------------------
         1.1        13-May-2015    INFOSYS        1. BT CHANGES
    ******************************************************************************
    ******************************************************************************/
    gn_jp_ou_id   CONSTANT NUMBER
        := apps.do_get_profile_value ('DO_JAPAN_OU_NAME') ;  -- Added for 1.1.

    PROCEDURE receive_po_lines (x_errbuf           OUT VARCHAR2,
                                x_retcode          OUT NUMBER,
                                p_shipment_id   IN     NUMBER)
    IS
        l_user_id      NUMBER := fnd_global.user_id;
        l_request_id   NUMBER;


        TYPE po_ll_rec IS RECORD
        (
            po_header_id        NUMBER,
            po_ll_id            NUMBER,
            ordered_quantity    NUMBER,
            vendor_id           NUMBER,
            iso_line_id         NUMBER
        );

        c_plr          po_ll_rec;

        CURSOR c_shipments IS
            SELECT ool.org_id, csd.shipment_id, csd.order_id,
                   csd.fluid_recipe_id, csd.shipped_quantity
              FROM xxdoec_cp_shipment_dtls_stg csd, oe_order_lines_all ool
             WHERE     NVL (csd.po_received_flag, 'N') = 'N'
                   AND csd.shipment_id = NVL (p_shipment_id, csd.shipment_id)
                   AND ool.cust_po_number = csd.order_id
                   AND ool.customer_job = csd.fluid_recipe_id;

        CURSOR c_po_lines_to_receive (p_order_id    IN VARCHAR2,
                                      p_recipe_id   IN VARCHAR2)
        IS
            SELECT mr.supply_source_header_id, mr.supply_source_line_id, ool.ordered_quantity,
                   poh.vendor_id
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.mtl_reservations_all_v mr,
                   apps.po_headers_all poh
             WHERE     ool.header_id = ooh.header_id
                   AND ool.open_flag = 'Y'
                   AND mr.demand_source_type_id = 2             -- Sales order
                   AND mr.demand_source_line_id = ool.line_id
                   AND mr.supply_source_type_id = 1
                   AND poh.po_header_id = mr.supply_source_header_id
                   AND ooh.cust_po_number = p_order_id
                   AND ool.customer_job = p_recipe_id;

        CURSOR c_jp_po_lines_to_receive (c_order_id    IN VARCHAR2,
                                         c_recipe_id   IN VARCHAR2)
        IS
            SELECT pll.po_header_id, pll.line_location_id, ool_so.ordered_quantity,
                   poh.vendor_id, ool_iso.line_id
              FROM apps.oe_order_headers_all ooh_so, apps.oe_order_lines_all ool_so, apps.mtl_reservations mr,
                   apps.po_requisition_headers_all prh_ir, apps.po_requisition_lines_all prl_ir, apps.oe_order_headers_all ooh_iso,
                   apps.oe_order_lines_all ool_iso, apps.mtl_reservations_all_v mr_iso, apps.po_line_locations_all pll,
                   apps.po_headers_all poh
             WHERE     ooh_so.cust_po_number = c_order_id
                   AND ool_so.header_id = ooh_so.header_id
                   AND ool_so.customer_job = c_recipe_id
                   AND mr.demand_source_line_id = ool_so.line_id
                   AND prl_ir.requisition_line_id =
                       mr.orig_supply_source_line_id
                   AND prh_ir.requisition_header_id =
                       prl_ir.requisition_header_id
                   AND ool_iso.source_document_line_id =
                       prl_ir.requisition_line_id
                   AND ool_iso.source_document_id =
                       prl_ir.requisition_header_id
                   AND ool_iso.inventory_item_id = prl_ir.item_id
                   AND ooh_iso.header_id = ool_iso.header_id
                   AND mr_iso.demand_source_line_id = ool_iso.line_id
                   AND pll.line_location_id = mr_iso.supply_source_line_id
                   AND poh.po_header_id = pll.po_header_id;

        CURSOR c_po_line_dtls (c_pll_id IN NUMBER)
        IS
            SELECT pl.item_id, pl.po_line_id, pl.po_header_id,
                   pl.line_num, pll.quantity, pl.unit_meas_lookup_code,
                   mp.organization_code, pll.line_location_id, pll.closed_code,
                   pll.quantity_received, pll.cancel_flag, pll.shipment_num
              FROM po_lines_all pl, po_line_locations_all pll, mtl_parameters mp
             WHERE     pll.line_location_id = c_pll_id
                   AND pl.po_line_id = pll.po_line_id
                   AND pll.ship_to_organization_id = mp.organization_id;
    BEGIN
        FOR c_sh IN c_shipments
        LOOP
            BEGIN
                c_plr   := NULL;

                -- IF c_sh.org_id = '232'         -- Commented for 1.1.
                IF c_sh.org_id = gn_jp_ou_id                 -- Added for 1.1.
                THEN
                    OPEN c_jp_po_lines_to_receive (c_sh.order_id,
                                                   c_sh.fluid_recipe_id);

                    FETCH c_jp_po_lines_to_receive
                        INTO c_plr.po_header_id, c_plr.po_ll_id, c_plr.ordered_quantity, c_plr.vendor_id,
                             c_plr.iso_line_id;

                    CLOSE c_jp_po_lines_to_receive;
                ELSE
                    OPEN c_po_lines_to_receive (c_sh.order_id,
                                                c_sh.fluid_recipe_id);

                    FETCH c_po_lines_to_receive INTO c_plr.po_header_id, c_plr.po_ll_id, c_plr.ordered_quantity, c_plr.vendor_id;

                    CLOSE c_po_lines_to_receive;
                END IF;

                IF c_plr.po_ll_id IS NOT NULL
                THEN
                    BEGIN
                        -- populate interface header
                        INSERT INTO rcv_headers_interface (
                                        header_interface_id,
                                        GROUP_ID,
                                        processing_status_code,
                                        receipt_source_code,
                                        transaction_type,
                                        last_update_date,
                                        last_updated_by,
                                        last_update_login,
                                        vendor_id,
                                        expected_receipt_date,
                                        validation_flag)
                            SELECT rcv_headers_interface_s.NEXTVAL, rcv_interface_groups_s.NEXTVAL, 'PENDING',
                                   'VENDOR', 'NEW', SYSDATE,
                                   l_user_id, 0, c_plr.vendor_id,
                                   SYSDATE, 'Y'
                              FROM DUAL;

                        --
                        FOR c1 IN c_po_line_dtls (c_plr.po_ll_id)
                        LOOP
                            IF     c1.closed_code IN ('APPROVED', 'OPEN')
                               AND c1.quantity_received < c1.quantity
                               AND NVL (c1.cancel_flag, 'N') = 'N'
                            THEN
                                -- populate interface lines
                                INSERT INTO rcv_transactions_interface (
                                                interface_transaction_id,
                                                GROUP_ID,
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
                                                po_header_id,
                                                po_line_id,
                                                item_id,
                                                quantity,
                                                unit_of_measure,
                                                po_line_location_id,
                                                auto_transact_code,
                                                destination_type_code,
                                                receipt_source_code,
                                                to_organization_code,
                                                subinventory,
                                                locator_id,
                                                source_document_code,
                                                header_interface_id,
                                                validation_flag)
                                    SELECT rcv_transactions_interface_s.NEXTVAL, rcv_interface_groups_s.CURRVAL, SYSDATE,
                                           l_user_id, SYSDATE, l_user_id,
                                           0, 'RECEIVE', SYSDATE,
                                           'PENDING', 'BATCH', 'PENDING',
                                           c1.po_header_id, c1.po_line_id, c1.item_id,
                                           c_sh.shipped_quantity, c1.unit_meas_lookup_code, c1.line_location_id,
                                           'DELIVER', 'INVENTORY', 'VENDOR',
                                           c1.organization_code, 'FACTORY', NULL,
                                           'PO', rcv_headers_interface_s.CURRVAL, 'Y'
                                      FROM DUAL;

                                --
                                UPDATE xxdoec_cp_shipment_dtls_stg
                                   SET po_line_location_id = c1.line_location_id, po_received_flag = 'Y'
                                 WHERE shipment_id = c_sh.shipment_id;

                                COMMIT;
                            ELSE
                                ROLLBACK;

                                --
                                UPDATE xxdoec_cp_shipment_dtls_stg
                                   SET po_line_location_id = c1.line_location_id, po_received_flag = 'E'
                                 WHERE shipment_id = c_sh.shipment_id;

                                COMMIT;
                                fnd_file.put_line (
                                    fnd_file.LOG,
                                       'PO line '
                                    || c1.line_num
                                    || ' is either closed, cancelled, received.');
                            END IF;
                        END LOOP;                                   -- c1 loop
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                END IF;                                          -- c_plr loop
            EXCEPTION
                WHEN OTHERS
                THEN
                    x_retcode   := -1;
                    x_errbuf    := SQLERRM;
            END;
        END LOOP;                                                 -- c_sh loop

        -- Submit RTP concurrent job
        l_request_id   :=
            fnd_request.submit_request ('PO', 'RVCTP', 'RECEIVE REQUEST',
                                        NULL, FALSE, 'BATCH',
                                        NULL);

        IF l_request_id <> 0
        THEN
            COMMIT;
            fnd_file.put_line (fnd_file.LOG,
                               '*** Request ID: ' || l_request_id);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := -2;
            x_errbuf    := SQLERRM;
    END receive_po_lines;

    --
    PROCEDURE pick_release_so_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_shipment_id IN NUMBER)
    IS
        x_msg_details         VARCHAR2 (3000);
        x_msg_summary         VARCHAR2 (3000);
        p_line_rows           wsh_util_core.id_tab_type;
        x_del_rows            wsh_util_core.id_tab_type;
        --l_ship_method_code  VARCHAR2(100);
        l_commit              VARCHAR2 (30);
        l_delivery_id         NUMBER;
        l_delivery_name       VARCHAR2 (30);
        l_trip_id             VARCHAR2 (30);
        l_trip_name           VARCHAR2 (30);
        --l_picked_flag       VARCHAR2(10);
        l_return_status       VARCHAR2 (10);
        l_msg_count           NUMBER;
        l_msg_data            VARCHAR2 (2000);
        l_shipping_attr_tab   wsh_delivery_details_pub.changedattributetabtype;
        exep_api              EXCEPTION;

        CURSOR c_shipments IS
            SELECT *
              FROM xxdoec_cp_shipment_dtls_stg
             WHERE     po_received_flag = 'Y'
                   AND NVL (so_pick_release_flag, 'N') = 'N'
                   AND shipment_id = NVL (p_shipment_id, shipment_id);

        CURSOR c_ord_details (c_order_id VARCHAR2, c_recipe_id VARCHAR2)
        IS
            SELECT ooh.order_number sales_order, ooh.org_id, ool.line_number,
                   ool.shipment_number, ool.flow_status_code, wdd.delivery_detail_id,
                   wdd.inv_interfaced_flag, wdd.oe_interfaced_flag, wdd.released_status,
                   ool.line_id
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.wsh_delivery_details wdd
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.org_id = ool.org_id
                   AND ooh.header_id = wdd.source_header_id
                   AND ool.line_id = wdd.source_line_id
                   AND ooh.booked_flag = 'Y'
                   AND NVL (ool.cancelled_flag, 'N') <> 'Y'
                   AND wdd.released_status IN ('R', 'B')
                   AND ool.flow_status_code = 'AWAITING_SHIPPING'
                   AND ooh.cust_po_number = c_order_id
                   AND ool.customer_job = c_recipe_id;
    BEGIN
        l_return_status   := wsh_util_core.g_ret_sts_success;

        FOR c_sh IN c_shipments
        LOOP
            FOR c_dd IN c_ord_details (c_sh.order_id, c_sh.fluid_recipe_id)
            LOOP
                BEGIN
                    -- Mandatory initialization for R12
                    mo_global.set_policy_context ('S', c_dd.org_id);
                    mo_global.init ('ONT');
                    p_line_rows (1)   := c_dd.delivery_detail_id;
                    -- API Call for Auto Create Deliveries
                    wsh_delivery_details_pub.autocreate_deliveries (
                        p_api_version_number   => 1.0,
                        p_init_msg_list        => fnd_api.g_true,
                        p_commit               => l_commit,
                        x_return_status        => l_return_status,
                        x_msg_count            => l_msg_count,
                        x_msg_data             => l_msg_data,
                        p_line_rows            => p_line_rows,
                        x_del_rows             => x_del_rows);

                    IF (l_return_status <> wsh_util_core.g_ret_sts_success)
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to Auto create delivery for Sales Order');
                        RAISE exep_api;
                    END IF;

                    -- Pick release.
                    l_delivery_id     := x_del_rows (1);
                    l_delivery_name   := TO_CHAR (x_del_rows (1));
                    -- API Call for Pick Release
                    wsh_deliveries_pub.delivery_action (
                        p_api_version_number        => 1.0,
                        p_init_msg_list             => fnd_api.g_true,
                        x_return_status             => l_return_status,
                        x_msg_count                 => l_msg_count,
                        x_msg_data                  => l_msg_data,
                        p_action_code               => 'PICK-RELEASE',
                        p_delivery_id               => l_delivery_id,
                        p_delivery_name             => l_delivery_name,
                        p_asg_trip_id               => NULL,
                        p_asg_trip_name             => NULL,
                        p_asg_pickup_stop_id        => NULL,
                        p_asg_pickup_loc_id         => NULL,
                        p_asg_pickup_stop_seq       => NULL,
                        p_asg_pickup_loc_code       => NULL,
                        p_asg_pickup_arr_date       => NULL,
                        p_asg_pickup_dep_date       => NULL,
                        p_asg_dropoff_stop_id       => NULL,
                        p_asg_dropoff_loc_id        => NULL,
                        p_asg_dropoff_stop_seq      => NULL,
                        p_asg_dropoff_loc_code      => NULL,
                        p_asg_dropoff_arr_date      => NULL,
                        p_asg_dropoff_dep_date      => NULL,
                        p_sc_action_flag            => 'S',
                        p_sc_intransit_flag         => 'N',
                        p_sc_close_trip_flag        => 'N',
                        p_sc_create_bol_flag        => 'N',
                        p_sc_stage_del_flag         => 'Y',
                        p_sc_trip_ship_method       => NULL,
                        p_sc_actual_dep_date        => NULL,
                        p_sc_report_set_id          => NULL,
                        p_sc_report_set_name        => NULL,
                        p_sc_defer_interface_flag   => 'N',
                        p_sc_send_945_flag          => NULL,
                        p_sc_rule_id                => NULL,
                        p_sc_rule_name              => NULL,
                        p_wv_override_flag          => 'N',
                        x_trip_id                   => l_trip_id,
                        x_trip_name                 => l_trip_name);

                    IF (l_return_status <> wsh_util_core.g_ret_sts_success)
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Failed to Pick Release the Sales Order Line');
                        RAISE exep_api;
                    ELSE
                        -- update tracking number
                        l_shipping_attr_tab.DELETE;
                        l_shipping_attr_tab (1).tracking_number   :=
                            c_sh.tracking_number;
                        l_shipping_attr_tab (1).delivery_detail_id   :=
                            c_dd.delivery_detail_id;
                        wsh_delivery_details_pub.update_shipping_attributes (
                            p_api_version_number   => 1.0,
                            p_init_msg_list        => fnd_api.g_true,
                            p_commit               => fnd_api.g_false,
                            x_return_status        => l_return_status,
                            x_msg_count            => l_msg_count,
                            x_msg_data             => l_msg_data,
                            p_changed_attributes   => l_shipping_attr_tab,
                            p_source_code          => 'OE',
                            p_container_flag       => NULL);
                        -- update order line
                        xxdoec_oeol_wf_pkg.update_line_custom_status (
                            p_line_id       => c_dd.line_id,
                            p_status_code   => 'SHE',
                            p_reason_code   => NULL,
                            x_rtn_sts       => l_return_status,
                            x_rtn_msg       => l_msg_data);

                        -- update shipment record
                        UPDATE xxdoec_cp_shipment_dtls_stg
                           SET so_delivery_id = l_delivery_id, so_line_id = c_dd.line_id, so_pick_release_flag = 'Y'
                         WHERE shipment_id = c_sh.shipment_id;

                        COMMIT;
                    END IF;
                EXCEPTION
                    WHEN exep_api
                    THEN
                        ROLLBACK;
                        wsh_util_core.get_messages ('Y', x_msg_summary, x_msg_details
                                                    , l_msg_count);
                        l_msg_data   :=
                            SUBSTR (x_msg_summary || x_msg_details, 1, 2000);

                        -- update shipment record
                        UPDATE xxdoec_cp_shipment_dtls_stg
                           SET so_line_id = c_dd.line_id, so_pick_release_flag = 'E', error_message = l_msg_data
                         WHERE shipment_id = c_sh.shipment_id;

                        COMMIT;
                        fnd_file.put_line (fnd_file.LOG, l_msg_data);
                    WHEN OTHERS
                    THEN
                        x_retcode   := -1;
                        x_errbuf    := SQLERRM;
                END;
            END LOOP;                                             -- c_dd loop
        END LOOP;                                                 -- c_sh loop
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := -2;
            x_errbuf    := SQLERRM;
    END pick_release_so_lines;

    PROCEDURE ship_confirm_so_lines (x_errbuf OUT VARCHAR2, x_retcode OUT NUMBER, p_shipment_id IN NUMBER)
    IS
        -- Local variables here
        l_virtual_inv_org_id   NUMBER;
        l_shipped_date         DATE;
        l_trip_id              NUMBER;
        l_trip_name            VARCHAR2 (120);
        l_rtn_status           VARCHAR2 (1);
        l_msg_count            NUMBER;
        l_msg_data             VARCHAR2 (2000);
        l_msg_index_out        NUMBER;
        x_rtn_msg              VARCHAR2 (2000);


        CURSOR c_shipments (ln_oper_unit_id NUMBER) -- Added parameter to Cursor for 1.1.
        IS
            SELECT csd.shipment_id, csd.so_line_id, csd.shipped_date,
                   csd.so_delivery_id
              FROM xxdoec_cp_shipment_dtls_stg csd, oe_order_lines_all ool
             WHERE     ool.cust_po_number = csd.order_id
                   AND ool.customer_job = csd.fluid_recipe_id
                   AND csd.po_received_flag = 'Y'
                   AND csd.so_pick_release_flag = 'Y'
                   AND NVL (csd.so_ship_confirm_flag, '~') =
                       DECODE (ool.org_id, ln_oper_unit_id, '~', -- Removed hardcoding for Japan OU id. 1.1.
                                                                 'R')
                   AND csd.shipment_id = NVL (p_shipment_id, csd.shipment_id);

        CURSOR c_virtual_inv_org (p_so_line_id IN NUMBER)
        IS
            SELECT ool.ship_from_org_id
              FROM oe_order_lines_all ool
             WHERE ool.line_id = p_so_line_id;

        CURSOR c_actual_dept_date (p_inv_org_id   IN NUMBER,
                                   p_ship_date    IN DATE)
        IS
            SELECT p_ship_date
              FROM org_acct_periods
             WHERE     organization_id = p_inv_org_id
                   AND open_flag = 'Y'
                   AND p_ship_date BETWEEN period_start_date
                                       AND schedule_close_date;

        CURSOR c_op_actual_dept_date (p_inv_org_id   IN NUMBER,
                                      p_ship_date    IN DATE)
        IS
            SELECT MIN (period_start_date)
              FROM org_acct_periods
             WHERE     organization_id = p_inv_org_id
                   AND open_flag = 'Y'
                   AND period_start_date >= p_ship_date;
    BEGIN
        FOR c_sh IN c_shipments (gn_jp_ou_id) -- Added parameter to cursor for 1.1.
        LOOP
            OPEN c_virtual_inv_org (c_sh.so_line_id);

            FETCH c_virtual_inv_org INTO l_virtual_inv_org_id;

            CLOSE c_virtual_inv_org;

            -- derive actual departure date
            OPEN c_actual_dept_date (l_virtual_inv_org_id, c_sh.shipped_date);

            FETCH c_actual_dept_date INTO l_shipped_date;

            IF c_actual_dept_date%FOUND
            THEN
                CLOSE c_actual_dept_date;
            ELSE
                CLOSE c_actual_dept_date;

                OPEN c_op_actual_dept_date (l_virtual_inv_org_id,
                                            c_sh.shipped_date);

                FETCH c_op_actual_dept_date INTO l_shipped_date;

                CLOSE c_op_actual_dept_date;
            END IF;

            wsh_deliveries_pub.delivery_action (p_api_version_number => 1.0, p_init_msg_list => fnd_api.g_true, x_return_status => l_rtn_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_action_code => 'CONFIRM', p_delivery_id => c_sh.so_delivery_id, p_sc_actual_dep_date => l_shipped_date, p_sc_intransit_flag => 'Y', p_sc_close_trip_flag => 'Y', p_sc_defer_interface_flag => 'N', x_trip_id => l_trip_id
                                                , x_trip_name => l_trip_name);

            IF     (l_rtn_status = fnd_api.g_ret_sts_error OR l_rtn_status = fnd_api.g_ret_sts_unexp_error)
               AND l_msg_count > 0
            THEN
                ROLLBACK;

                -- Retrieve messages
                FOR i IN 1 .. l_msg_count
                LOOP
                    fnd_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => l_msg_data
                                     , p_msg_index_out => l_msg_index_out);
                    x_rtn_msg   :=
                        SUBSTR (x_rtn_msg || l_msg_data || CHR (13), 1, 2000);
                END LOOP;

                -- Update shipment record error message
                UPDATE xxdoec_cp_shipment_dtls_stg
                   SET so_ship_confirm_flag = 'E', error_message = x_rtn_msg
                 WHERE shipment_id = c_sh.shipment_id;

                COMMIT;
            ELSE
                -- Update shipment record success
                UPDATE xxdoec_cp_shipment_dtls_stg
                   SET so_ship_confirm_flag   = 'Y'
                 WHERE shipment_id = c_sh.shipment_id;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := -2;
            x_errbuf    := SQLERRM;
    END ship_confirm_so_lines;
END xxdoec_process_cp_shipments;
/
