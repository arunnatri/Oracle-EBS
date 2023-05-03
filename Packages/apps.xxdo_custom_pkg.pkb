--
-- XXDO_CUSTOM_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:34:06 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_CUSTOM_PKG"
AS
    PROCEDURE xxdo_custom_rcv_prc (pv_errbuff   OUT VARCHAR2,
                                   pv_retcode   OUT NUMBER)
    IS
        CURSOR c_rcv_cur IS
            SELECT prl.org_id, apps.iid_to_sku (prl.item_id) sku, prl.item_id,
                   prl.quantity item_quantity, prl.unit_meas_lookup_code unit_of_measure, rsh.shipment_num,
                   rsl.from_organization_id, rsl.shipment_line_status_code, rsl.ship_to_location_id,
                   rsl.category_id, msb.description item_description, msb.primary_uom_code item_uom_code,
                   rsl.shipment_header_id, prl.quantity primary_quantity, msb.primary_uom_code primary_unit_of_measure,
                   rsl.to_organization_id ship_to_organization_id, msb.receiving_routing_id, rsl.deliver_to_person_id,
                   rsl.ship_to_location_id location_id, rsl.deliver_to_location_id, prl.unit_meas_lookup_code source_doc_unit_of_measure,
                   rsl.shipment_line_id, prl.requisition_header_id, prl.requisition_line_id,
                   prd.distribution_id req_distribution_id, rsl.created_by, rsl.last_updated_by,
                   prl.last_update_login
              FROM apps.po_requisition_lines_all prl, apps.po_req_distributions_all prd, apps.rcv_shipment_lines rsl,
                   apps.rcv_shipment_headers rsh, apps.mtl_system_items_b msb, apps.oe_order_headers_all ooha,
                   apps.oe_order_lines_all oola, apps.mtl_reservations mr, apps.mtl_parameters mp,
                   apps.fnd_common_lookups fcl
             WHERE     prl.requisition_line_id = rsl.requisition_line_id
                   AND rsl.shipment_header_id = rsh.shipment_header_id
                   AND prl.item_id = msb.inventory_item_id
                   AND prl.destination_organization_id = msb.organization_id
                   AND prd.requisition_line_id = prl.requisition_line_id
                   AND prl.quantity_delivered = 0
                   AND ooha.ship_from_org_id = mp.organization_id
                   AND mp.organization_code = fcl.lookup_code
                   AND fcl.lookup_type = 'XXDO_UBY_WAREHOUSE'
                   AND ooha.header_id = oola.header_id
                   AND mr.demand_source_line_id = oola.line_id
                   AND mr.orig_supply_source_line_id =
                       prl.requisition_line_id
                   AND NOT EXISTS
                           (SELECT shipment_line_id
                              FROM apps.rcv_transactions_interface
                             WHERE shipment_line_id = rsl.shipment_line_id);

        --
        l_rti_tran_id   NUMBER;
    BEGIN
        FOR i_rcv_cur IN c_rcv_cur
        LOOP
            SELECT apps.rcv_transactions_interface_s.NEXTVAL
              INTO l_rti_tran_id
              FROM DUAL;

            --
            INSERT INTO apps.rcv_transactions_interface (
                            interface_transaction_id,
                            GROUP_ID,
                            item_id,
                            transaction_type,
                            transaction_date,
                            processing_status_code,
                            processing_mode_code,
                            transaction_status_code,
                            quantity,
                            unit_of_measure,
                            auto_transact_code,
                            receipt_source_code,
                            source_document_code,
                            subinventory,
                            last_update_date,
                            last_updated_by,
                            creation_date,
                            created_by,
                            last_update_login,
                            ship_to_location_id,
                            category_id,
                            interface_source_code,
                            item_description,
                            uom_code,
                            employee_id,
                            shipment_header_id,
                            primary_quantity,
                            primary_unit_of_measure,
                            to_organization_id,
                            routing_header_id,
                            routing_step_id,
                            inspection_status_code,
                            destination_type_code,
                            deliver_to_person_id,
                            location_id,
                            deliver_to_location_id,
                            expected_receipt_date,
                            destination_context,
                            source_doc_unit_of_measure,
                            use_mtl_lot,
                            use_mtl_serial,
                            shipment_line_id,
                            from_organization_id,
                            requisition_line_id,
                            req_distribution_id,
                            shipment_num,
                            shipped_date,
                            org_id)
                 VALUES (l_rti_tran_id, 99, i_rcv_cur.item_id,
                         'RECEIVE', SYSDATE, 'PENDING',
                         'BATCH', 'PENDING', i_rcv_cur.item_quantity,
                         i_rcv_cur.unit_of_measure, 'DELIVER', 'INTERNAL ORDER', 'REQ', 'FACTORY-JP', SYSDATE, i_rcv_cur.last_updated_by, SYSDATE, i_rcv_cur.created_by, i_rcv_cur.last_update_login, i_rcv_cur.ship_to_location_id, i_rcv_cur.category_id, 'RCV', i_rcv_cur.item_description, i_rcv_cur.item_uom_code, i_rcv_cur.deliver_to_person_id, i_rcv_cur.shipment_header_id, i_rcv_cur.primary_quantity, i_rcv_cur.primary_unit_of_measure, i_rcv_cur.ship_to_organization_id, i_rcv_cur.receiving_routing_id, 1, 'NOT INSPECTED', 'INVENTORY', i_rcv_cur.deliver_to_person_id, i_rcv_cur.location_id, i_rcv_cur.deliver_to_location_id, SYSDATE, 'INVENTORY', i_rcv_cur.item_uom_code, 1, 1, i_rcv_cur.shipment_line_id, i_rcv_cur.from_organization_id, i_rcv_cur.requisition_line_id, i_rcv_cur.req_distribution_id
                         , i_rcv_cur.shipment_num, SYSDATE, i_rcv_cur.org_id);
        END LOOP;

        --
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            apps.fnd_file.put_line (
                apps.fnd_file.LOG,
                'Error while receiving requisitions - ' || SQLERRM);
            ROLLBACK;

            pv_retcode   := 2;
            pv_errbuff   :=
                'Error while receiving requisitions - ' || SQLERRM;

            RAISE;
    --
    END xxdo_custom_rcv_prc;
--
END;
/
