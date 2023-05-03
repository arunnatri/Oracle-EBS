--
-- XXDO_XDOCK_UNPACK  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:02 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_XDOCK_UNPACK"
AS
    PROCEDURE XDOCK_UNPACK_MAIN (errbuf                  OUT VARCHAR2,
                                 retcode                 OUT VARCHAR2,
                                 pn_order_number      IN     NUMBER,
                                 pv_parent_lpn        IN     VARCHAR2,
                                 pn_organization_id   IN     NUMBER)
    IS
        ln_order_count   NUMBER;
        ln_lpn_count     NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Parameters');
        fnd_file.put_line (fnd_file.LOG, 'Order Number: ' || pn_order_number);
        fnd_file.put_line (fnd_file.LOG, 'Parent LPN: ' || pv_parent_lpn);
        fnd_file.put_line (fnd_file.LOG,
                           'Organization Id: ' || pn_organization_id);

        SELECT COUNT (DISTINCT ooh.order_number)
          INTO ln_order_count
          FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool
         WHERE     ooh.header_id = ool.header_id
               AND ool.ship_from_org_id = pn_organization_id
               AND ooh.order_number = pn_order_number;

        SELECT COUNT (DISTINCT license_plate_number)
          INTO ln_lpn_count
          FROM apps.wms_license_plate_numbers
         WHERE     license_plate_number = pv_parent_lpn
               AND organization_id = pn_organization_id;



        IF pn_order_number IS NOT NULL AND pv_parent_lpn IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Pass either Order or LPN, donot enter values for both');

            retcode   := 2;
        ELSIF pn_order_number IS NULL AND pv_parent_lpn IS NULL
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Pass either Order or LPN');

            retcode   := 2;
        ELSIF pn_order_number IS NOT NULL
        THEN
            IF ln_order_count = 0
            THEN
                fnd_file.put_line (fnd_file.LOG, 'Order is not Valid');
                retcode   := 2;
            ELSE
                unpack_order (pn_order_number, pn_organization_id);
            END IF;
        ELSIF pv_parent_lpn IS NOT NULL
        THEN
            IF ln_lpn_count = 0
            THEN
                fnd_file.put_line (fnd_file.LOG, 'LPN is not Valid');
                retcode   := 2;
            ELSE
                unpack_parent_lpn (pv_parent_lpn, pn_organization_id);
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Inside Main Exception:' || SQLERRM);
    END xdock_unpack_main;

    PROCEDURE unpack_order (pn_order_number      IN NUMBER,
                            pn_organization_id   IN NUMBER)
    IS
        CURSOR cur_parent_lpn IS
            SELECT DISTINCT wlpn_parent.license_plate_number parent_lpn
              FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.mtl_reservations mr,
                   apps.wms_license_plate_numbers wlpn, apps.wms_license_plate_numbers wlpn_parent
             WHERE     ooh.order_number = pn_order_number
                   AND ooh.header_id = ool.header_id
                   AND ool.line_id = mr.demand_source_line_id
                   AND ool.ship_from_org_id = mr.organization_id
                   AND mr.organization_id = pn_organization_id
                   AND mr.subinventory_code = 'XDOCK'
                   AND mr.supply_source_type_id = 13
                   AND mr.lpn_id = wlpn.lpn_id
                   AND wlpn.lpn_id = wlpn_parent.lpn_id;

        ln_parent_lpn_count   NUMBER;
    BEGIN
        ln_parent_lpn_count   := 0;

        fnd_file.put_line (fnd_file.LOG, 'Inside Unpack Order');

        FOR rec_parent_lpn IN cur_parent_lpn
        LOOP
            unpack_parent_lpn (rec_parent_lpn.parent_lpn, pn_organization_id);
            ln_parent_lpn_count   := ln_parent_lpn_count + 1;
        END LOOP;

        IF ln_parent_lpn_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'No Parent LPNs found for the Order');
        END IF;

        fnd_file.put_line (fnd_file.LOG,
                           'Updating the LPN ID of Reservations to NULL');

        /* Update Reservations */
        UPDATE apps.mtl_reservations
           SET lpn_id   = NULL
         WHERE     demand_source_line_id IN
                       (SELECT line_id
                          FROM apps.oe_order_lines_all
                         WHERE header_id IN
                                   (SELECT header_id
                                      FROM apps.oe_order_headers_all
                                     WHERE order_number = pn_order_number))
               AND supply_source_type_id = 13
               AND subinventory_code = 'XDOCK'
               AND organization_id = pn_organization_id;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception during Unpack Order' || SQLERRM);
    END unpack_order;

    PROCEDURE unpack_parent_lpn (pv_parent_lpn        IN VARCHAR2,
                                 pn_organization_id   IN NUMBER)
    IS
        r_mti_rec                  MTL_TRANSACTIONS_INTERFACE%ROWTYPE;
        ln_transaction_header_id   NUMBER;
        ln_interface_id            NUMBER;
        ln_transaction_type_id     NUMBER;
        lv_proceed_flag            VARCHAR2 (1);
        lv_return_status           VARCHAR2 (1);
        ln_ordered_quantity        NUMBER;
        lv_error_message           VARCHAR2 (1000);
        lv_msg_data                VARCHAR2 (1000);
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER;


        CURSOR cur_lpn_details IS
              SELECT moqd.organization_id, moqd.inventory_item_id, moqd.subinventory_code,
                     moqd.locator_id, moqd.transaction_uom_code, wlpn.lpn_id,
                     NVL2 (wlpn.parent_lpn_id, wlpn_parent.lpn_id, NULL) parent_lpn_id, wlpn.license_plate_number lpn, NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL) pallet_lpn,
                     SUM (moqd.transaction_quantity) quantiy
                FROM apps.wms_license_plate_numbers wlpn, apps.wms_license_plate_numbers wlpn_parent, apps.mtl_onhand_quantities_detail moqd
               WHERE     wlpn_parent.license_plate_number = pv_parent_lpn
                     AND wlpn_parent.lpn_id = wlpn.parent_lpn_id
                     AND wlpn.lpn_id = moqd.lpn_id
                     AND wlpn.organization_id = pn_organization_id
                     AND wlpn.organization_id = moqd.organization_id
            GROUP BY moqd.organization_id, moqd.subinventory_code, moqd.locator_id,
                     moqd.transaction_uom_code, moqd.inventory_item_id, wlpn.lpn_id,
                     NVL2 (wlpn.parent_lpn_id, wlpn_parent.lpn_id, NULL), wlpn.license_plate_number, NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL);
    BEGIN
        lv_proceed_flag   := 'Y';


        fnd_file.put_line (fnd_file.LOG,
                           'Processing for Parent LPN: ' || pv_parent_lpn);

        FOR rec_lpn_details IN cur_lpn_details
        LOOP
            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_transaction_header_id
              FROM DUAL;

            IF rec_lpn_details.parent_lpn_id IS NOT NULL
            THEN
                wms_container_pub.PackUnpack_Container (
                    p_api_version       => 1.0,
                    x_return_status     => lv_return_status,
                    x_msg_count         => ln_msg_count,
                    x_msg_data          => lv_msg_data,
                    p_lpn_id            => rec_lpn_details.parent_lpn_id,
                    p_content_lpn_id    => rec_lpn_details.lpn_id,
                    p_organization_id   => rec_lpn_details.organization_id,
                    p_operation         => 2,               /* 2 for Unpack */
                    p_unpack_all        => 2             /* dont unpack all */
                                            );

                --DBMS_OUTPUT.put_line ('lv_return_status: ' || lv_return_status);

                IF lv_return_status <> 'S'
                THEN
                    IF ln_msg_count > 0
                    THEN
                        FOR v_index IN 1 .. ln_msg_count
                        LOOP
                            fnd_msg_pub.get (
                                p_msg_index       => v_index,
                                p_encoded         => 'F',
                                p_data            => lv_msg_data,
                                p_msg_index_out   => ln_msg_index_out);
                            lv_msg_data   := SUBSTR (lv_msg_data, 1, 200);
                        END LOOP;
                    END IF;

                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error in Parent LPN unpack: ' || lv_msg_data);
                ELSE
                    fnd_file.put_line (fnd_file.LOG,
                                       'Parent LPN unpacked successfully');
                END IF;

                COMMIT;
            END IF;

            /*During Un-pack it should be lpn_id*/
            r_mti_rec.lpn_id                     := rec_lpn_details.lpn_id;

            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_interface_id
              FROM DUAL;

            BEGIN
                SELECT transaction_type_id
                  INTO ln_transaction_type_id
                  FROM mtl_transaction_types
                 WHERE transaction_type_name = 'Container Unpack';
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Error:Container Pack: transaciton_type missing:');
            END;

            fnd_file.put_line (
                fnd_file.LOG,
                'Unpacking Child LPN: ' || rec_lpn_details.lpn);

            r_mti_rec.transaction_header_id      := ln_transaction_header_id;
            r_mti_rec.transaction_interface_id   := ln_interface_id;
            r_mti_rec.transaction_uom            :=
                rec_lpn_details.transaction_uom_code;
            r_mti_rec.source_code                := 'Container Unpack';
            r_mti_rec.locator_id                 :=
                rec_lpn_details.locator_id;
            r_mti_rec.inventory_item_id          :=
                rec_lpn_details.inventory_item_id;
            r_mti_rec.organization_id            :=
                rec_lpn_details.organization_id;
            r_mti_rec.subinventory_code          :=
                rec_lpn_details.subinventory_code;
            r_mti_rec.transaction_quantity       := rec_lpn_details.quantiy;
            r_mti_rec.primary_quantity           := rec_lpn_details.quantiy;
            r_mti_rec.transaction_type_id        := ln_transaction_type_id;


            /* Call the procedure to insert MTI record */
            --DBMS_OUTPUT.put_line ('Inserting into MTI');
            XXDO_WMS_INVENTORY_CONVERSION.insert_mti_record (
                r_mti_rec,
                lv_return_status);

            --DBMS_OUTPUT.put_line ('lv_return_status: ' || lv_return_status);

            IF lv_return_status <> 'S'
            THEN
                lv_proceed_flag   := 'N';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while inserting into MTL_TRANSACTION_INTERFACE');
            ELSE
                /* Call the procedure in UTIL Package to process record */
                XXDO_WMS_INVENTORY_CONVERSION.process_transaction (
                    ln_transaction_header_id,
                    lv_return_status,
                    lv_error_message);
            END IF;


            IF lv_return_status <> 'S'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while processing MTI: ' || lv_error_message);
            ELSE
                fnd_file.put_line (fnd_file.LOG,
                                   'Child LPN Unpacked Succesfully');

                UPDATE apps.mtl_reservations
                   SET lpn_id   = NULL
                 WHERE     lpn_id = rec_lpn_details.lpn_id
                       AND supply_source_type_id = 13;

                COMMIT;
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in unpack parent LPN :' || SQLERRM);
    END unpack_parent_lpn;
END XXDO_XDOCK_UNPACK;
/
