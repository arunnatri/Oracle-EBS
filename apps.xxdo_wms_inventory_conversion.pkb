--
-- XXDO_WMS_INVENTORY_CONVERSION  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_INVENTORY_CONVERSION"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 05-NOV-2017  1.0        Krishna Lavu            Initial Version
    ******************************************************************************************/

    gn_user_id      NUMBER := FND_GLOBAL.USER_ID;
    gn_request_id   NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gv_src_org      VARCHAR2 (200);
    gv_dest_org     VARCHAR2 (200);
    gv_brand        VARCHAR2 (200) := 'KOOLABURRA';

    PROCEDURE extract_main (pv_errbuf           OUT VARCHAR2,
                            pv_retcode          OUT VARCHAR2,
                            pv_brand         IN     VARCHAR2,
                            pv_src_org       IN     NUMBER,
                            pv_src_subinv    IN     VARCHAR2,
                            pv_src_locator   IN     VARCHAR2,
                            pv_dest_org      IN     NUMBER,
                            pv_dest_subinv   IN     VARCHAR2)
    AS
        ln_src_org         VARCHAR2 (10);
        ln_dest_org        VARCHAR2 (10);
        lv_return_status   VARCHAR2 (1);
    BEGIN
        BEGIN
            SELECT organization_code
              INTO ln_src_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pv_src_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_src_org   := NULL;
        END;

        BEGIN
            SELECT organization_code
              INTO ln_dest_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pv_dest_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_dest_org   := NULL;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');
        fnd_file.put_line (
            fnd_file.LOG,
            '+------------------------------- Parameters --------------------------------+');

        fnd_file.put_line (fnd_file.LOG, 'Brand: ' || pv_brand);
        fnd_file.put_line (fnd_file.LOG, 'Source Org: ' || ln_src_org);
        fnd_file.put_line (fnd_file.LOG,
                           'Source Subinventory: ' || pv_src_subinv);
        fnd_file.put_line (fnd_file.LOG,
                           'Source Locator: ' || pv_src_locator);
        fnd_file.put_line (fnd_file.LOG, 'Destination Org: ' || ln_dest_org);
        fnd_file.put_line (fnd_file.LOG,
                           'Destination Subinventory: ' || pv_dest_subinv);
        fnd_file.put_line (fnd_file.LOG, 'User ID: ' || gn_user_id);
        fnd_file.put_line (fnd_file.LOG,
                           'Resp Appl ID: ' || FND_GLOBAL.RESP_APPL_ID);

        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');

        gv_src_org    := ln_src_org;
        gv_dest_org   := ln_dest_org;
        gv_brand      := pv_brand;

        lv_return_status   :=
            validate_data (pv_brand, pv_src_org, pv_dest_org);

        IF lv_return_status = 'S'
        THEN
            /*Insert the SKU and LPN information in staging table */
            onhand_insert (pv_src_org, pv_src_subinv, pv_src_locator,
                           pv_dest_org, pv_dest_subinv);


            /*Write the SKU and LPN information in staging table */
            onhand_extract (pv_src_org, pv_src_subinv, pv_src_locator,
                            pv_dest_org, pv_dest_subinv);

            /* Unpack the SKR from Carton and Pallet and rename the carton LPN */
            pack_unpack_lpn (pv_src_org, pv_src_subinv, pv_src_locator);

            /* Creates Internal Requisition */
            create_internal_requisition (pv_src_org, pv_src_subinv, pv_src_locator
                                         , pv_dest_org, pv_dest_subinv);
        ELSE
            pv_retcode   := 2;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while extracting onhand :' || SQLERRM);
            ROLLBACK;
    END extract_main;

    FUNCTION validate_data (pv_brand         IN VARCHAR2,
                            pn_src_org_id    IN NUMBER,
                            pn_dest_org_id   IN NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR cur_validate_item_config IS
            SELECT DISTINCT segment1
              FROM apps.mtl_system_items_b
             WHERE     inventory_item_id IN
                           (SELECT msi.inventory_item_id
                              FROM apps.mtl_categories_b mc, apps.mtl_item_categories mic, apps.mtl_system_items_kfv msi,
                                   apps.mtl_onhand_quantities_detail moqd
                             WHERE     mc.segment1 = pv_brand
                                   AND mc.category_id = mic.category_id
                                   AND mic.inventory_item_id =
                                       msi.inventory_item_id
                                   AND msi.organization_id = pn_src_org_id
                                   AND msi.organization_id =
                                       mic.organization_id
                                   AND moqd.inventory_item_id =
                                       msi.inventory_item_id
                                   AND msi.organization_id =
                                       moqd.organization_id)
                   AND organization_id = pn_dest_org_id
                   AND (PURCHASING_ENABLED_FLAG = 'N' OR INTERNAL_ORDER_ENABLED_FLAG = 'N');

        CURSOR cur_item_exists IS
            SELECT msi.segment1
              FROM apps.mtl_categories_b mc, apps.mtl_item_categories mic, apps.mtl_system_items_kfv msi,
                   apps.mtl_onhand_quantities_detail moqd
             WHERE     mc.segment1 = pv_brand
                   AND mc.category_id = mic.category_id
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND msi.organization_id = pn_src_org_id
                   AND msi.organization_id = mic.organization_id
                   AND moqd.inventory_item_id = msi.inventory_item_id
                   AND msi.organization_id = moqd.organization_id
                   AND NOT EXISTS
                           (SELECT msi1.segment1
                              FROM apps.mtl_system_items_kfv msi1
                             WHERE     msi1.organization_id = pn_dest_org_id
                                   AND msi1.segment1 = msi.segment1);

        CURSOR cur_check_reservations IS
            SELECT DISTINCT msi.segment1
              FROM apps.mtl_categories_b mc, apps.mtl_item_categories mic, apps.mtl_system_items_kfv msi,
                   apps.mtl_reservations mr
             WHERE     mc.segment1 = pv_brand
                   AND mc.category_id = mic.category_id
                   AND mic.inventory_item_id = msi.inventory_item_id
                   AND msi.organization_id = pn_src_org_id
                   AND msi.organization_id = mic.organization_id
                   AND mr.organization_id = msi.organization_id
                   AND mr.inventory_item_id = msi.inventory_item_id;

        CURSOR cur_check_picktasks IS
            SELECT DISTINCT ooh.order_number
              FROM apps.mtl_material_transactions_temp mmtt, apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh
             WHERE     mmtt.organization_id = pn_src_org_id
                   AND mmtt.transaction_type_id = 52
                   AND mmtt.trx_source_line_id = ool.line_id
                   AND ool.header_id = ooh.header_id
                   AND mmtt.inventory_item_id IN
                           (SELECT msi.inventory_item_id
                              FROM apps.mtl_categories_b mc, apps.mtl_item_categories mic, apps.mtl_system_items_kfv msi
                             WHERE     mc.segment1 = pv_brand
                                   AND mc.category_id = mic.category_id
                                   AND mic.inventory_item_id =
                                       msi.inventory_item_id
                                   AND msi.organization_id = pn_src_org_id
                                   AND msi.organization_id =
                                       mic.organization_id);

        lv_return_status   VARCHAR2 (1);
        ln_cnt             NUMBER;
    BEGIN
        lv_return_status   := 'S';

        /* Validating SKU Configuration in Destination Organization */
        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');
        fnd_file.put_line (
            fnd_file.LOG,
            'Validating SKU Configuration in Destination Organization');

        FOR rec_validate_item_config IN cur_validate_item_config
        LOOP
            lv_return_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                   'Item Not purchase enabled or Internal Order Enabled: '
                || rec_validate_item_config.segment1);
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');

        /* Check Items doesnt exist in Destination Org */
        fnd_file.put_line (fnd_file.LOG,
                           'Checking Item exist or not in Destination Org');

        FOR rec_item_exists IN cur_item_exists
        LOOP
            lv_return_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                'Itemd doesnt exists in Destination Org: ' || rec_item_exists.segment1);
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');

        /* Check Reservations */
        fnd_file.put_line (fnd_file.LOG, 'Checking for Reservation');

        FOR rec_check_reservations IN cur_check_reservations
        LOOP
            lv_return_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                'Reservations exists for SKU: ' || rec_check_reservations.segment1);
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');

        /* Check Open Pick Tasks */
        fnd_file.put_line (fnd_file.LOG, 'Checking for Pending Pick Tasks');

        FOR rec_check_picktasks IN cur_check_picktasks
        LOOP
            lv_return_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                'Pick Tasks Exists for the order: ' || rec_check_picktasks.order_number);
        END LOOP;

        fnd_file.put_line (
            fnd_file.LOG,
            '+---------------------------------------------------------------------------+');

        RETURN lv_return_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while Validating the Program :' || SQLERRM);
            lv_return_status   := 'E';
            RETURN lv_return_status;
            ROLLBACK;
    END validate_data;

    PROCEDURE onhand_insert (pn_src_org_id    IN NUMBER,
                             pv_src_subinv    IN VARCHAR2,
                             pv_src_locator   IN VARCHAR2,
                             pn_dest_org_id   IN NUMBER,
                             pv_dest_subinv   IN VARCHAR2)
    AS
        CURSOR cur_onhand IS
              SELECT mp.organization_code source_org, msi.segment1 item_number, msi.description,
                     moqd.inventory_item_id, moqd.subinventory_code source_subinventory, mil.concatenated_segments source_locator,
                     msi.primary_uom_code uom, NVL (cic.item_cost, 0) item_unit_cost, wlpn.license_plate_number lpn,
                     NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL) pallet_lpn, SUM (moqd.transaction_quantity) quantiy
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_categories_b mc, apps.mtl_item_categories mic,
                     apps.mtl_system_items_kfv msi, apps.mtl_item_locations_kfv mil, apps.mtl_parameters mp,
                     apps.wms_license_plate_numbers wlpn, apps.wms_license_plate_numbers wlpn_parent, apps.cst_item_costs cic
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.organization_id = mic.organization_id
                     AND mic.inventory_item_id = moqd.inventory_item_id
                     AND mc.category_id = mic.category_id
                     AND mc.segment1 = gv_brand
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.organization_id = mp.organization_id
                     AND moqd.organization_id = wlpn.organization_id(+)
                     AND moqd.lpn_id = wlpn.lpn_id(+)
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
                     AND wlpn_parent.lpn_id(+) = wlpn.outermost_lpn_id
                     AND cic.organization_id = moqd.organization_id(+)
                     AND cic.inventory_item_id = moqd.inventory_item_id(+)
                     AND cic.cost_type_id = mp.primary_cost_method(+)
            GROUP BY mp.organization_code, moqd.subinventory_code, moqd.inventory_item_id,
                     msi.description, msi.segment1, mil.concatenated_segments,
                     msi.primary_uom_code, wlpn.license_plate_number, NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL),
                     NVL (cic.item_cost, 0)
            ORDER BY msi.segment1;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Onhand Insert Procedure');

        FOR rec_onhand IN cur_onhand
        LOOP
            INSERT INTO XXDO_INV_CONV_ONHAND_STG (SOURCE_ORGANIZATION,
                                                  SOURCE_ORG_ID,
                                                  SOURCE_SUBINVENTORY,
                                                  SOURCE_LOCATOR,
                                                  DESTINATION_ORGANIZATION,
                                                  DESTINATION_ORG_ID,
                                                  DESTINATION_SUBINVENTORY,
                                                  ITEM_NUMBER,
                                                  INVENTORY_ITEM_ID,
                                                  ITEM_DESCRIPTION,
                                                  UOM,
                                                  ITEM_UNIT_COST,
                                                  LPN,
                                                  PALLET_LPN,
                                                  QUANTITY,
                                                  BRAND,
                                                  CREATION_DATE,
                                                  CREATED_BY,
                                                  LAST_UPDATE_DATE,
                                                  LAST_UPDATED_BY,
                                                  REQUEST_ID)
                 VALUES (rec_onhand.source_org, pn_src_org_id, rec_onhand.source_subinventory, rec_onhand.source_locator, gv_dest_org, pn_dest_org_id, pv_dest_subinv, rec_onhand.item_number, rec_onhand.inventory_item_id, rec_onhand.description, rec_onhand.uom, rec_onhand.item_unit_cost, rec_onhand.lpn, rec_onhand.pallet_lpn, rec_onhand.quantiy, gv_brand, SYSDATE, gn_user_id
                         , SYSDATE, gn_user_id, gn_request_id);
        END LOOP;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (SQLERRM);
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END onhand_insert;

    PROCEDURE onhand_extract (pn_src_org_id    IN NUMBER,
                              pv_src_subinv    IN VARCHAR2,
                              pv_src_locator   IN VARCHAR2,
                              pn_dest_org_id   IN NUMBER,
                              pv_dest_subinv   IN VARCHAR2)
    AS
        CURSOR cur_onhand IS
              SELECT mp.organization_code source_org, msi.segment1 item_number, msi.description,
                     moqd.inventory_item_id, moqd.subinventory_code source_sbuinventory, mil.concatenated_segments source_locator,
                     msi.primary_uom_code uom, NVL (cic.item_cost, 0) item_unit_cost, wlpn.license_plate_number lpn,
                     NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL) pallet_lpn, SUM (moqd.transaction_quantity) quantiy
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_categories_b mc, apps.mtl_item_categories mic,
                     apps.mtl_system_items_kfv msi, apps.mtl_item_locations_kfv mil, apps.mtl_parameters mp,
                     apps.wms_license_plate_numbers wlpn, apps.wms_license_plate_numbers wlpn_parent, apps.cst_item_costs cic
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.organization_id = mic.organization_id
                     AND mic.inventory_item_id = moqd.inventory_item_id
                     AND mc.category_id = mic.category_id
                     AND mc.segment1 = gv_brand
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND moqd.locator_id = mil.inventory_location_id
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.organization_id = mp.organization_id
                     AND moqd.organization_id = wlpn.organization_id(+)
                     AND moqd.lpn_id = wlpn.lpn_id(+)
                     AND wlpn_parent.lpn_id(+) = wlpn.outermost_lpn_id
                     AND cic.organization_id = moqd.organization_id(+)
                     AND cic.inventory_item_id = moqd.inventory_item_id(+)
                     AND cic.cost_type_id = mp.primary_cost_method(+)
            GROUP BY mp.organization_code, moqd.subinventory_code, moqd.inventory_item_id,
                     msi.description, msi.segment1, mil.concatenated_segments,
                     msi.primary_uom_code, wlpn.license_plate_number, NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL),
                     NVL (cic.item_cost, 0)
            ORDER BY msi.segment1;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Onhand Extract Procedure');

        fnd_file.put_line (
            fnd_file.output,
               'Source Org'
            || ','
            || 'Item Number'
            || ','
            || 'Source Subinventory'
            || ','
            || 'Source Locator'
            || ','
            || 'UOM'
            || ','
            || 'LPN'
            || ','
            || 'Pallet LPN'
            || ','
            || 'Quantity'
            || ','
            || 'Receipt Date');

        FOR rec_onhand IN cur_onhand
        LOOP
            fnd_file.put_line (
                fnd_file.output,
                   rec_onhand.source_org
                || ','
                || rec_onhand.item_number
                || ','
                || rec_onhand.source_sbuinventory
                || ','
                || rec_onhand.source_locator
                || ','
                || rec_onhand.uom
                || ','
                || rec_onhand.lpn
                || ','
                || rec_onhand.pallet_lpn
                || ','
                || rec_onhand.quantiy
                || ','
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY'));
        END LOOP;

        fnd_file.put_line (fnd_file.LOG,
                           'Completed Onhand Extract Procedure');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, SQLERRM);
    END onhand_extract;

    PROCEDURE pack_unpack_lpn (pn_src_org_id IN NUMBER, pv_src_subinventory IN VARCHAR2, pv_src_locator IN VARCHAR2)
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
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_categories_b mc, apps.mtl_item_categories mic,
                     apps.mtl_system_items_kfv msi, apps.mtl_item_locations_kfv mil, apps.wms_license_plate_numbers wlpn,
                     apps.wms_license_plate_numbers wlpn_parent
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinventory
                     AND moqd.organization_id = mic.organization_id
                     AND mic.inventory_item_id = moqd.inventory_item_id
                     AND mc.category_id = mic.category_id
                     AND mc.segment1 = 'KOOLABURRA'
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.lpn_id IS NOT NULL
                     AND moqd.organization_id = wlpn.organization_id(+)
                     AND moqd.lpn_id = wlpn.lpn_id(+)
                     AND wlpn_parent.lpn_id(+) = wlpn.outermost_lpn_id
            GROUP BY moqd.organization_id, moqd.subinventory_code, moqd.locator_id,
                     moqd.transaction_uom_code, moqd.inventory_item_id, wlpn.lpn_id,
                     NVL2 (wlpn.parent_lpn_id, wlpn_parent.lpn_id, NULL), wlpn.license_plate_number, NVL2 (wlpn.parent_lpn_id, wlpn_parent.license_plate_number, NULL);
    BEGIN
        lv_proceed_flag   := 'Y';

        fnd_file.put_line (fnd_file.LOG, 'Inside pack_unpack_lpn Procedure');

        FOR rec_lpn_details IN cur_lpn_details
        LOOP
            --DBMS_OUTPUT.put_line ('Parent LPN: ' || rec_lpn_details.pallet_lpn);
            --DBMS_OUTPUT.put_line ('LPN: ' || rec_lpn_details.lpn);

            SELECT mtl_material_transactions_s.NEXTVAL
              INTO ln_transaction_header_id
              FROM DUAL;

            IF rec_lpn_details.parent_lpn_id IS NOT NULL
            THEN
                --DBMS_OUTPUT.put_line ('Inside Parent LPN Unpack');
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
                        'Error While Unpacking LPN from Parent LPN');
                    fnd_file.put_line (
                        fnd_file.LOG,
                        'Parent LPN: ' || rec_lpn_details.pallet_lpn);
                    fnd_file.put_line (fnd_file.LOG,
                                       'LPN: ' || rec_lpn_details.lpn);
                    fnd_file.put_line (fnd_file.LOG,
                                       'ERROR: ' || lv_msg_data);
                END IF;
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

            inv_trx_util_pub.trace (
                'Inserting MTI for LPN ID: ' || rec_lpn_details.lpn_id);
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
            insert_mti_record (r_mti_rec, lv_return_status);

            --DBMS_OUTPUT.put_line ('lv_return_status: ' || lv_return_status);

            IF lv_return_status <> 'S'
            THEN
                lv_proceed_flag   := 'N';
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while inserting into MTL_TRANSACTION_INTERFACE');
            ELSE
                /* Call the procedure in UTIL Package to process record */
                process_transaction (ln_transaction_header_id,
                                     lv_return_status,
                                     lv_error_message);
            END IF;


            IF lv_return_status <> 'S'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error while processing MTI: ' || lv_error_message);
            ELSE
                UPDATE wms_license_plate_numbers
                   SET license_plate_number = license_plate_number || '_OLD', last_update_date = SYSDATE, last_updated_by = gn_user_id
                 WHERE lpn_id = rec_lpn_details.lpn_id;
            END IF;
        END LOOP;

        fnd_file.put_line (fnd_file.LOG, 'Exit pack_unpack_lpn Procedure');
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Exception in pack_lpn :' || SQLERRM);
    END pack_unpack_lpn;

    PROCEDURE insert_mti_record (p_mti_rec IN MTL_TRANSACTIONS_INTERFACE%ROWTYPE, p_return_status OUT VARCHAR2)
    IS
        r_mti_rec   MTL_TRANSACTIONS_INTERFACE%ROWTYPE;
    BEGIN
        r_mti_rec         := p_mti_rec;

        INSERT INTO mtl_transactions_interface (transaction_header_id, transaction_interface_id, transaction_uom, transaction_date, source_code, source_line_id, source_header_id, process_flag, transaction_mode, lock_flag, inventory_item_id, organization_id, subinventory_code, locator_id, transaction_quantity, primary_quantity, transaction_type_id, last_update_date, last_updated_by, created_by, creation_date, transfer_subinventory, transfer_locator, content_lpn_id
                                                , transfer_lpn_id, lpn_id)
             VALUES (r_mti_rec.transaction_header_id, r_mti_rec.transaction_interface_id, r_mti_rec.transaction_uom, SYSDATE, r_mti_rec.source_code, 99, 99, 1, 3, 2, r_mti_rec.inventory_item_id, r_mti_rec.organization_id, r_mti_rec.subinventory_code, r_mti_rec.locator_id, r_mti_rec.transaction_quantity, r_mti_rec.primary_quantity, r_mti_rec.transaction_type_id, SYSDATE, 0, 0, SYSDATE, r_mti_rec.transfer_subinventory, r_mti_rec.transfer_locator, r_mti_rec.content_lpn_id
                     , r_mti_rec.transfer_lpn_id, r_mti_rec.lpn_id);

        COMMIT;
        p_return_status   := 'S';
    EXCEPTION
        WHEN OTHERS
        THEN
            p_return_status   := 'E';
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while inserting record in MTI :' || SQLERRM);
    END insert_mti_record;

    --------------------------------------------------------------------------------------------------------
    /* Process the MTI Record                                                                             */
    --------------------------------------------------------------------------------------------------------

    PROCEDURE process_transaction (p_transaction_header_id IN NUMBER, p_return_status OUT VARCHAR2, pv_error_message OUT VARCHAR2)
    IS
        CURSOR c_mti (p_transactions_header_id NUMBER)
        IS
            SELECT transaction_interface_id, ROWID row_id, error_explanation,
                   ERROR_CODE
              FROM mtl_transactions_interface
             WHERE transaction_header_id = p_transactions_header_id;

        TYPE lt_mti IS TABLE OF c_mti%ROWTYPE;

        ltb_mti               lt_mti;
        l_return_status       VARCHAR2 (1);
        l_msg_data            VARCHAR2 (100);
        l_trans_count         NUMBER;
        l_msg_count           NUMBER;
        l_result              NUMBER;
        l_completion_status   BOOLEAN;
    BEGIN
        l_completion_status   := TRUE;

        inv_quantity_tree_pub.clear_quantity_cache;
        l_result              :=
            inv_txn_manager_pub.process_transactions (
                p_api_version        => 1.0,
                p_header_id          => p_transaction_header_id,
                p_init_msg_list      => fnd_api.g_true,
                p_commit             => fnd_api.g_false,
                p_validation_level   => 100,
                x_return_status      => l_return_status,
                x_msg_data           => l_msg_data,
                x_trans_count        => l_trans_count,
                x_msg_count          => l_msg_count);

        IF NVL (l_return_status, 'S') <> 'S'
        THEN
            fnd_file.put_line (fnd_file.LOG, 'API : ' || l_msg_data);
            l_completion_status   := FALSE;
            pv_error_message      := l_msg_data;

            OPEN c_mti (p_transaction_header_id);

            FETCH c_mti BULK COLLECT INTO ltb_mti;

            CLOSE c_mti;

            ROLLBACK;

            FOR l_index IN 1 .. ltb_mti.COUNT
            LOOP
                UPDATE mtl_transactions_interface
                   SET error_explanation = ltb_mti (l_index).error_explanation, ERROR_CODE = ltb_mti (l_index).ERROR_CODE, transaction_mode = 3,
                       process_flag = 3, lock_flag = 2
                 WHERE transaction_interface_id =
                       ltb_mti (l_index).transaction_interface_id;

                fnd_file.put_line (
                    fnd_file.LOG,
                       'Updating transaction_interface_id : '
                    || ltb_mti (l_index).transaction_interface_id);
            END LOOP;
        END IF;

        IF NOT (l_completion_status)
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   ' Processing failed for header id '
                || p_transaction_header_id);

            UPDATE mtl_transactions_interface
               SET process_flag = 3, lock_flag = 2, transaction_mode = 3
             WHERE transaction_header_id = p_transaction_header_id;

            p_return_status   := 'E';
        ELSE
            p_return_status   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Error while transaction process :' || SQLERRM);
            pv_error_message   :=
                'Error while transaction process :' || SQLERRM;
    END process_transaction;

    PROCEDURE create_internal_requisition (pn_src_org_id    IN NUMBER,
                                           pv_src_subinv    IN VARCHAR2,
                                           pv_src_locator   IN VARCHAR2,
                                           pn_dest_org_id   IN NUMBER,
                                           pv_dest_subinv   IN VARCHAR2)
    IS
        CURSOR cur_onhand IS
              SELECT moqd.organization_id source_org_id, moqd.subinventory_code source_subinventory, moqd.inventory_item_id,
                     msi.segment1 item_number, msi.primary_uom_code uom, SUM (moqd.transaction_quantity) quantiy
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_categories_b mc, apps.mtl_item_categories mic,
                     apps.mtl_system_items_kfv msi, apps.mtl_item_locations_kfv mil, apps.mtl_parameters mp
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.organization_id = mic.organization_id
                     AND mic.inventory_item_id = moqd.inventory_item_id
                     AND mc.category_id = mic.category_id
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
                     AND mc.segment1 = gv_brand
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.organization_id = mp.organization_id
                     AND moqd.lpn_id IS NULL
            GROUP BY moqd.organization_id, moqd.subinventory_code, moqd.inventory_item_id,
                     msi.segment1, msi.primary_uom_code
            ORDER BY msi.segment1;

        ln_req_request_id       NUMBER;
        ln_del_to_loc_id        NUMBER;
        ln_ccid                 NUMBER;
        lv_source_code          VARCHAR2 (200);
        ln_item_exists          NUMBER;
        ln_resp_id              NUMBER;
        ln_resp_appl_id         NUMBER;
        ln_org_id               NUMBER;
        ln_person_id            NUMBER;
        lb_bol_result           BOOLEAN;
        lv_chr_phase            VARCHAR2 (120 BYTE);
        lv_chr_status           VARCHAR2 (120 BYTE);
        lv_requisition_number   VARCHAR2 (200);
        lv_chr_dev_phase        VARCHAR2 (120 BYTE);
        lv_chr_dev_status       VARCHAR2 (120 BYTE);
        lv_chr_message          VARCHAR2 (2000 BYTE);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Create Requisitions - Process Started...');

        SELECT employee_id
          INTO ln_person_id
          FROM fnd_user
         WHERE user_name = fnd_global.user_name;

        /*fnd_file.put_line (fnd_file.LOG, 'Person Id: ' || ln_person_id);*/

        SELECT location_id
          INTO ln_del_to_loc_id
          FROM hr_organization_units_v
         WHERE organization_id = pn_dest_org_id;


        SELECT material_account
          INTO ln_ccid
          FROM mtl_parameters
         WHERE organization_id = pn_dest_org_id;


        lv_source_code   :=
               gv_brand
            || '-'
            || pv_src_subinv
            || '-'
            || TO_CHAR (gn_request_id);

        FOR rec_onhand IN cur_onhand
        LOOP
            /*fnd_file.put_line (
               fnd_file.LOG,
               'Processing the Item : ' || rec_onhand.item_number);*/

            ln_item_exists   := 0;

            BEGIN
                SELECT COUNT (1)
                  INTO ln_item_exists
                  FROM mtl_system_items_kfv msi
                 WHERE     msi.organization_id = pn_dest_org_id
                       AND msi.inventory_item_id =
                           rec_onhand.inventory_item_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_item_exists   := 0;
            END;

            IF ln_item_exists = 0
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Item: '
                    || rec_onhand.item_number
                    || ' doesn''t exists in Destintation Org');
            ELSE
                SELECT operating_unit
                  INTO ln_org_id
                  FROM apps.org_organization_definitions
                 WHERE organization_id = pn_src_org_id;

                /*fnd_file.put_line (fnd_file.LOG,
                                   'Operating Unit : ' || ln_org_id); */


                INSERT INTO po_requisitions_interface_all (
                                Interface_source_code,
                                Requisition_type,
                                Org_id,
                                Authorization_status,
                                Charge_account_id,
                                quantity,
                                uom_code,
                                group_code,
                                item_id,
                                need_by_date,
                                Preparer_id,
                                deliver_to_requestor_id,
                                Source_type_code,
                                source_organization_id,
                                source_subinventory,
                                destination_type_code,
                                destination_organization_id,
                                destination_subinventory,
                                deliver_to_location_id,
                                --line_attribute3,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by)
                     VALUES (lv_source_code, 'INTERNAL', ln_org_id, /* ORG_ID */
                             'APPROVED',               -- Authorization_Status
                                         ln_ccid,                -- Valid ccid
                                                  rec_onhand.quantiy, -- Quantity
                             rec_onhand.uom,                       -- UOm Code
                                             lv_source_code, rec_onhand.inventory_item_id, SYSDATE, -- neeed by date
                                                                                                    ln_person_id, -- Person id of the preparer
                                                                                                                  ln_person_id, -- Person_id of the requestor
                                                                                                                                'INVENTORY', -- source_type_code
                                                                                                                                             rec_onhand.source_org_id, -- Source org id - US4
                                                                                                                                                                       rec_onhand.source_subinventory, --- source subinventory
                                                                                                                                                                                                       'INVENTORY', -- destination_type_code
                                                                                                                                                                                                                    pn_dest_org_id, -- Destination org id - US1
                                                                                                                                                                                                                                    pv_dest_subinv, -- destination sub inventory
                                                                                                                                                                                                                                                    ln_del_to_loc_id, --TO_CHAR (SYSDATE, 'DD-MON-YYYY'),
                                                                                                                                                                                                                                                                      SYSDATE, gn_user_id
                             , SYSDATE, gn_user_id);
            END IF;
        END LOOP;



        COMMIT;

        fnd_file.put_line (
            fnd_file.LOG,
            'Create Requisitions - Launching the Requisition import requests...');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers WMS Inv Control Manager'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 51614;
                ln_resp_appl_id   := 385;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        /*APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => 4962,
                                         RESP_ID        => 51614,
                                         RESP_APPL_ID   => 385); */


        ln_req_request_id   :=
            apps.fnd_request.submit_request (application => 'PO', -- application short name
                                                                  program => 'REQIMPORT', -- program short name
                                                                                          start_time => SYSDATE, sub_request => FALSE, argument1 => lv_source_code, -- interface source code
                                                                                                                                                                    argument2 => NULL, -- Batch Id
                                                                                                                                                                                       argument3 => 'ALL', -- Group By
                                                                                                                                                                                                           argument4 => NULL, -- Last Requisition Number
                                                                                                                                                                                                                              argument5 => 'N'
                                             ,          -- Multi Distributions
                                               argument6 => 'Y' -- Initiate Requisition Approval after Requisition Import    /* APPROVAL_PARAMETER */
                                                               );

        COMMIT;

        fnd_file.put_line (fnd_file.LOG,
                           'Requisition Request Id :' || ln_req_request_id);

        IF ln_req_request_id <> 0
        THEN
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 15,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF lv_chr_dev_phase = 'COMPLETE'
            THEN
                BEGIN
                    SELECT segment1
                      INTO lv_requisition_number
                      FROM apps.po_requisition_headers_all
                     WHERE interface_source_code = lv_source_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        fnd_file.put_line (
                            fnd_file.LOG,
                            'Unable to find requisituon number, search manually');
                        lv_requisition_number   := NULL;
                END;
            END IF;
        END IF;

        IF lv_requisition_number IS NOT NULL
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Requisituon number: ' || lv_requisition_number);
        END IF;


        fnd_file.put_line (fnd_file.LOG,
                           'Create Requisitions - Process Ended');
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Unexpected error while creating requisitions :' || SQLERRM);
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while creating requisitions :' || SQLERRM);
    END create_internal_requisition;

    PROCEDURE receive_shipment (pv_errbuf            OUT VARCHAR2,
                                pv_retcode           OUT VARCHAR2,
                                pv_shipment_num   IN     VARCHAR2,
                                pv_org            IN     NUMBER,
                                pv_dest_subinv    IN     VARCHAR2)
    IS
        lv_source_document_code   VARCHAR2 (100);
        ln_ret_code               NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Receive Shipment Main');

        BEGIN
            SELECT DISTINCT rsl.source_document_code
              INTO lv_source_document_code
              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
             WHERE     rsh.shipment_num = pv_shipment_num
                   AND rsh.shipment_header_id = rsl.shipment_header_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Unable to Identify Source Document Reference for '
                    || pv_shipment_num);
                pv_retcode   := 2;
        END;

        fnd_file.put_line (
            fnd_file.LOG,
            'Source Doc Ref Type: ' || lv_source_document_code);

        IF NVL (lv_source_document_code, 'XX') = 'REQ'
        THEN
            receive_req_shipment (pv_shipment_num, pv_org, pv_dest_subinv,
                                  ln_ret_code);
        ELSIF NVL (lv_source_document_code, 'XX') = 'PO'
        THEN
            receive_po_shipment (pv_shipment_num, pv_org, pv_dest_subinv,
                                 ln_ret_code);
        END IF;

        pv_retcode   := ln_ret_code;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Main Exception: ' || SQLERRM);
            ROLLBACK;
            pv_retcode   := 2;
    END receive_shipment;

    PROCEDURE receive_req_shipment (pv_shipment_num IN VARCHAR2, pv_org IN NUMBER, pv_dest_subinv IN VARCHAR2
                                    , pv_retcode OUT NUMBER)
    IS
        CURSOR cur_shipment_lines IS
            SELECT rsl.quantity_shipped, rsl.primary_unit_of_measure, rsl.item_id,
                   rsl.deliver_to_person_id, rsl.shipment_header_id, rsl.shipment_line_id,
                   rsl.ship_to_location_id, rsl.to_organization_id, rsl.source_document_code,
                   rsl.requisition_line_id, rsl.req_distribution_id, rsl.destination_type_code,
                   rsl.deliver_to_location_id, rsl.to_subinventory, rsh.shipment_num
              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
             WHERE     rsh.shipment_num = pv_shipment_num
                   AND rsh.shipment_header_id = rsl.shipment_header_id;

        ln_header_interface_id   NUMBER;
        ln_rcv_group_id          NUMBER;
        ln_employee_id           NUMBER;
        ln_ship_to_org_id        NUMBER;
        ln_org_id                NUMBER;
        lv_receipt_source_code   VARCHAR2 (100);
        lv_org_code              VARCHAR2 (100);
        ln_created_by            NUMBER;
        lv_proceed_flag          VARCHAR2 (1);
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Inside Receive Requisition Shipment');

        pv_retcode        := 0;

        SELECT operating_unit, organization_code
          INTO ln_org_id, lv_org_code
          FROM apps.org_organization_definitions
         WHERE organization_id = pv_org;

        lv_proceed_flag   := 'Y';

        fnd_file.put_line (fnd_file.LOG,
                           'Shipment Number: ' || pv_shipment_num);
        fnd_file.put_line (fnd_file.LOG, 'Destination Org: ' || lv_org_code);
        fnd_file.put_line (fnd_file.LOG,
                           'Destination Subinventory: ' || pv_dest_subinv);

        BEGIN
            SELECT employee_id, ship_to_org_id, receipt_source_code,
                   created_by
              INTO ln_employee_id, ln_ship_to_org_id, lv_receipt_source_code, ln_created_by
              FROM rcv_shipment_headers
             WHERE shipment_num = pv_shipment_num AND ship_to_org_id = pv_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Shipment Information Not Found');
                pv_retcode        := 2;
                lv_proceed_flag   := 'N';
        END;

        IF lv_proceed_flag = 'Y'
        THEN
            ln_header_interface_id   := rcv_headers_interface_s.NEXTVAL;
            ln_rcv_group_id          := rcv_interface_groups_s.NEXTVAL;


            INSERT INTO RCV_HEADERS_INTERFACE (HEADER_INTERFACE_ID,
                                               GROUP_ID,
                                               PROCESSING_STATUS_CODE,
                                               RECEIPT_SOURCE_CODE,
                                               TRANSACTION_TYPE,
                                               AUTO_TRANSACT_CODE,
                                               LAST_UPDATE_DATE,
                                               LAST_UPDATED_BY,
                                               LAST_UPDATE_LOGIN,
                                               CREATION_DATE,
                                               CREATED_BY,
                                               SHIPMENT_NUM,
                                               SHIP_TO_ORGANIZATION_ID,
                                               EXPECTED_RECEIPT_DATE,
                                               SHIPPED_DATE,
                                               EMPLOYEE_ID,
                                               VALIDATION_FLAG)
                 VALUES (ln_header_interface_id,         --HEADER_INTERFACE_ID
                                                 ln_rcv_group_id,   --GROUP_ID
                                                                  'PENDING', --PROCESSING_STATUS_CODE
                         lv_receipt_source_code,         --RECEIPT_SOURCE_CODE
                                                 'NEW',     --TRANSACTION_TYPE
                                                        'DELIVER', --AUTO_TRANSACT_CODE
                         SYSDATE,                           --LAST_UPDATE_DATE
                                  ln_created_by,              --LAST_UPDATE_BY
                                                 ln_created_by, --LAST_UPDATE_LOGIN
                         SYSDATE,                              --CREATION_DATE
                                  ln_created_by,                  --CREATED_BY
                                                 pv_shipment_num, --SHIPMENT_NUM
                         ln_ship_to_org_id,          --SHIP_TO_ORGANIZATION_ID
                                            SYSDATE + 1, --EXPECTED_RECEIPT_DATE
                                                         SYSDATE, --SHIPPED_DATE
                         ln_employee_id,                         --EMPLOYEE_ID
                                         'Y'                 --VALIDATION_FLAG
                                            );

            COMMIT;

            DBMS_OUTPUT.put_line ('After Header Insert');

            FOR rec_shipment_line IN cur_shipment_lines
            LOOP
                DBMS_OUTPUT.put_line (
                    'Inserting Line: ' || rec_shipment_line.requisition_line_id);

                INSERT INTO RCV_TRANSACTIONS_INTERFACE (
                                INTERFACE_TRANSACTION_ID,
                                GROUP_ID,
                                REQUEST_ID,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY,
                                CREATION_DATE,
                                CREATED_BY,
                                LAST_UPDATE_LOGIN,
                                TRANSACTION_TYPE,
                                TRANSACTION_DATE,
                                PROCESSING_STATUS_CODE,
                                PROCESSING_MODE_CODE,
                                TRANSACTION_STATUS_CODE,
                                QUANTITY,
                                UNIT_OF_MEASURE,
                                INTERFACE_SOURCE_CODE,
                                ITEM_ID,
                                EMPLOYEE_ID,
                                AUTO_TRANSACT_CODE,
                                SHIPMENT_HEADER_ID,
                                SHIPMENT_LINE_ID,
                                SHIP_TO_LOCATION_ID,
                                RECEIPT_SOURCE_CODE,
                                TO_ORGANIZATION_ID,
                                SOURCE_DOCUMENT_CODE,
                                REQUISITION_LINE_ID,
                                REQ_DISTRIBUTION_ID,
                                DESTINATION_TYPE_CODE,
                                DELIVER_TO_PERSON_ID,
                                LOCATION_ID,
                                DELIVER_TO_LOCATION_ID,
                                SUBINVENTORY,
                                SHIPMENT_NUM,
                                EXPECTED_RECEIPT_DATE,
                                SHIPPED_DATE,
                                HEADER_INTERFACE_ID,
                                VALIDATION_FLAG,
                                ORG_ID)
                     VALUES (rcv_transactions_interface_s.NEXTVAL, -- INTERFACE_TRANSACTION_ID
                                                                   ln_rcv_group_id, --GROUP_ID
                                                                                    gn_request_id, --REQUEST_ID
                                                                                                   SYSDATE, --LAST_UPDATE_DATE
                                                                                                            ln_created_by, --LAST_UPDATED_BY
                                                                                                                           SYSDATE, --CREATION_DATE
                                                                                                                                    ln_created_by, --CREATED_BY
                                                                                                                                                   ln_created_by, --LAST_UPDATE_LOGIN
                                                                                                                                                                  'RECEIVE', --TRANSACTION_TYPE
                                                                                                                                                                             SYSDATE, --TRANSACTION_DATE
                                                                                                                                                                                      'PENDING', --PROCESSING_STATUS_CODE
                                                                                                                                                                                                 'BATCH', --PROCESSING_MODE_CODE
                                                                                                                                                                                                          'PENDING', --TRANSACTION_STATUS_CODE
                                                                                                                                                                                                                     rec_shipment_line.quantity_shipped, --QUANTITY
                                                                                                                                                                                                                                                         rec_shipment_line.primary_unit_of_measure, --UNIT_OF_MEASURE
                                                                                                                                                                                                                                                                                                    'RCV', --INTERFACE_SOURCE_CODE
                                                                                                                                                                                                                                                                                                           rec_shipment_line.item_id, --ITEM_ID
                                                                                                                                                                                                                                                                                                                                      rec_shipment_line.deliver_to_person_id, --EMPLOYEE_ID
                                                                                                                                                                                                                                                                                                                                                                              'DELIVER', --AUTO_TRANSACT_CODE
                                                                                                                                                                                                                                                                                                                                                                                         rec_shipment_line.shipment_header_id, --SHIPMENT_HEADER_ID
                                                                                                                                                                                                                                                                                                                                                                                                                               rec_shipment_line.shipment_line_id, --SHIPMENT_LINE_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                   rec_shipment_line.ship_to_location_id, --SHIP_TO_LOCATION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          lv_receipt_source_code, --RECEIPT_SOURCE_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  rec_shipment_line.to_organization_id, --TO_ORGANIZATION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        rec_shipment_line.source_document_code, --SOURCE_DOCUMENT_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                rec_shipment_line.requisition_line_id, --REQUISITION_LINE_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       rec_shipment_line.req_distribution_id, --REQ_DISTRIBUTION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              rec_shipment_line.destination_type_code, --DESTINATION_TYPE_CODE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       rec_shipment_line.deliver_to_person_id, --DELIVER_TO_PERSON_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               rec_shipment_line.deliver_to_location_id, --LOCATION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         rec_shipment_line.deliver_to_location_id, --DELIVER_TO_LOCATION_ID
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   NVL (rec_shipment_line.to_subinventory, pv_dest_subinv), --SUBINVENTORY
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            rec_shipment_line.shipment_num, --SHIPMENT_NUM
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            SYSDATE + 1, --EXPECTED_RECEIPT_DATE,
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         SYSDATE, --SHIPPED_DATE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  ln_header_interface_id
                             ,                           --HEADER_INTERFACE_ID
                               'Y',                          --VALIDATION_FLAG
                                    ln_org_id);
            END LOOP;

            COMMIT;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Interface records inserted, run Receiving Transaction Interface program');
        fnd_file.put_line (fnd_file.LOG, 'Group Id:' || ln_rcv_group_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Main Exception: ' || SQLERRM);
            ROLLBACK;
            pv_retcode   := 2;
    END receive_req_shipment;

    PROCEDURE receive_po_shipment (pv_shipment_num IN VARCHAR2, pv_org IN NUMBER, pv_dest_subinv IN VARCHAR2
                                   , pv_retcode OUT NUMBER)
    IS
        CURSOR cur_shipment_lines IS
            SELECT rsl.quantity_shipped, rsl.primary_unit_of_measure, rsl.item_id,
                   rsl.deliver_to_person_id, rsl.shipment_header_id, rsl.shipment_line_id,
                   rsl.ship_to_location_id, rsl.to_organization_id, rsl.source_document_code,
                   rsl.requisition_line_id, rsl.req_distribution_id, rsl.destination_type_code,
                   rsl.deliver_to_location_id, rsl.to_subinventory, rsh.shipment_num,
                   rsl.category_id, msib.primary_uom_code, rsl.routing_header_id,
                   ph.po_header_id, rsl.po_line_id, rsl.po_line_location_id,
                   pl.unit_price, 'USD' currency_code, msib.segment1 item_number,
                   ph.segment1 po_number, pl.line_num, rsl.container_num
              FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh, apps.mtl_system_items_b msib,
                   apps.po_headers_all ph, apps.po_lines_all pl
             WHERE     rsh.shipment_num = pv_shipment_num
                   AND rsh.shipment_header_id = rsl.shipment_header_id
                   AND msib.inventory_item_id = rsl.item_id
                   AND msib.organization_id = rsl.to_organization_id
                   AND ph.PO_HEADER_ID = rsl.PO_HEADER_ID
                   AND pl.PO_LINE_ID = rsl.PO_LINE_ID
                   AND ph.PO_HEADER_ID = pl.PO_HEADER_ID;

        ln_header_interface_id   NUMBER;
        ln_rcv_group_id          NUMBER;
        ln_employee_id           NUMBER;
        ln_ship_to_org_id        NUMBER;
        ln_org_id                NUMBER;
        lv_receipt_source_code   VARCHAR2 (100);
        lv_org_code              VARCHAR2 (100);
        ln_created_by            NUMBER;
        lv_proceed_flag          VARCHAR2 (1);
        ln_vendor_id             NUMBER;
        ln_vendor_site_id        NUMBER;
        ln_ship_to_location_id   NUMBER;
        lv_packing_slip          VARCHAR2 (100);
    BEGIN
        fnd_file.put_line (fnd_file.LOG, 'Inside Receive PO Shipment');

        pv_retcode        := 0;

        SELECT operating_unit, organization_code
          INTO ln_org_id, lv_org_code
          FROM apps.org_organization_definitions
         WHERE organization_id = pv_org;

        lv_proceed_flag   := 'Y';

        fnd_file.put_line (fnd_file.LOG,
                           'Shipment Number: ' || pv_shipment_num);
        fnd_file.put_line (fnd_file.LOG, 'Destination Org: ' || lv_org_code);
        fnd_file.put_line (fnd_file.LOG,
                           'Destination Subinventory: ' || pv_dest_subinv);

        BEGIN
            SELECT employee_id, ship_to_org_id, receipt_source_code,
                   created_by, vendor_id, vendor_site_id,
                   ship_to_location_id, packing_slip
              INTO ln_employee_id, ln_ship_to_org_id, lv_receipt_source_code, ln_created_by,
                                 ln_vendor_id, ln_vendor_site_id, ln_ship_to_location_id,
                                 lv_packing_slip
              FROM rcv_shipment_headers
             WHERE shipment_num = pv_shipment_num AND ship_to_org_id = pv_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                fnd_file.put_line (fnd_file.LOG,
                                   'Shipment Information Not Found');
                pv_retcode        := 2;
                lv_proceed_flag   := 'N';
        END;

        IF lv_proceed_flag = 'Y'
        THEN
            ln_header_interface_id   := rcv_headers_interface_s.NEXTVAL;
            ln_rcv_group_id          := rcv_interface_groups_s.NEXTVAL;


            INSERT INTO RCV_HEADERS_INTERFACE (HEADER_INTERFACE_ID,
                                               GROUP_ID,
                                               PROCESSING_STATUS_CODE,
                                               RECEIPT_SOURCE_CODE,
                                               TRANSACTION_TYPE,
                                               AUTO_TRANSACT_CODE,
                                               LAST_UPDATE_DATE,
                                               LAST_UPDATED_BY,
                                               LAST_UPDATE_LOGIN,
                                               CREATION_DATE,
                                               CREATED_BY,
                                               SHIPMENT_NUM,
                                               SHIP_TO_ORGANIZATION_ID,
                                               EXPECTED_RECEIPT_DATE,
                                               SHIPPED_DATE,
                                               EMPLOYEE_ID,
                                               VALIDATION_FLAG,
                                               VENDOR_ID,
                                               VENDOR_SITE_ID,
                                               LOCATION_ID,
                                               PACKING_SLIP)
                     VALUES (ln_header_interface_id,     --HEADER_INTERFACE_ID
                             ln_rcv_group_id,                       --GROUP_ID
                             'PENDING',               --PROCESSING_STATUS_CODE
                             lv_receipt_source_code,     --RECEIPT_SOURCE_CODE
                             'NEW',                         --TRANSACTION_TYPE
                             'DELIVER',                   --AUTO_TRANSACT_CODE
                             SYSDATE,                       --LAST_UPDATE_DATE
                             ln_created_by,                   --LAST_UPDATE_BY
                             ln_created_by,                --LAST_UPDATE_LOGIN
                             SYSDATE,                          --CREATION_DATE
                             ln_created_by,                       --CREATED_BY
                             pv_shipment_num,                   --SHIPMENT_NUM
                             ln_ship_to_org_id,      --SHIP_TO_ORGANIZATION_ID
                             SYSDATE + 1,              --EXPECTED_RECEIPT_DATE
                             SYSDATE,                           --SHIPPED_DATE
                             ln_employee_id,                     --EMPLOYEE_ID
                             'Y',                            --VALIDATION_FLAG
                             ln_vendor_id,                         --VENDOR_ID
                             ln_vendor_site_id,              -- VENDOR_SITE_ID
                             ln_ship_to_location_id,     --SHIP_TO_LOCATION_ID
                             lv_packing_slip                    --PACKING_SLIP
                                            );

            COMMIT;

            fnd_file.put_line (fnd_file.LOG, 'After Header Insert');

            FOR rec_shipment_line IN cur_shipment_lines
            LOOP
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Inserting Line: ' || rec_shipment_line.requisition_line_id);

                INSERT INTO RCV_TRANSACTIONS_INTERFACE (
                                INTERFACE_TRANSACTION_ID,
                                GROUP_ID,
                                REQUEST_ID,
                                LAST_UPDATE_DATE,
                                LAST_UPDATED_BY,
                                CREATION_DATE,
                                CREATED_BY,
                                LAST_UPDATE_LOGIN,
                                TRANSACTION_TYPE,
                                TRANSACTION_DATE,
                                PROCESSING_STATUS_CODE,
                                PROCESSING_MODE_CODE,
                                TRANSACTION_STATUS_CODE,
                                QUANTITY,
                                UNIT_OF_MEASURE,
                                INTERFACE_SOURCE_CODE,
                                ITEM_ID,
                                EMPLOYEE_ID,
                                AUTO_TRANSACT_CODE,
                                SHIPMENT_HEADER_ID,
                                SHIPMENT_LINE_ID,
                                SHIP_TO_LOCATION_ID,
                                RECEIPT_SOURCE_CODE,
                                TO_ORGANIZATION_ID,
                                SOURCE_DOCUMENT_CODE,
                                REQUISITION_LINE_ID,
                                REQ_DISTRIBUTION_ID,
                                DESTINATION_TYPE_CODE,
                                DELIVER_TO_PERSON_ID,
                                LOCATION_ID,
                                DELIVER_TO_LOCATION_ID,
                                SUBINVENTORY,
                                SHIPMENT_NUM,
                                EXPECTED_RECEIPT_DATE,
                                SHIPPED_DATE,
                                HEADER_INTERFACE_ID,
                                VALIDATION_FLAG,
                                ORG_ID,
                                CATEGORY_ID,
                                UOM_CODE,
                                PRIMARY_QUANTITY,
                                PRIMARY_UNIT_OF_MEASURE,
                                VENDOR_ID,
                                VENDOR_SITE_ID,
                                ROUTING_HEADER_ID,
                                PO_HEADER_ID,
                                PO_LINE_ID,
                                PO_LINE_LOCATION_ID,
                                PO_UNIT_PRICE,
                                CURRENCY_CODE,
                                PACKING_SLIP,
                                SOURCE_DOC_UNIT_OF_MEASURE,
                                ITEM_NUM,
                                DOCUMENT_NUM,
                                DOCUMENT_LINE_NUM,
                                CONTAINER_NUM)
                         VALUES (
                                    rcv_transactions_interface_s.NEXTVAL, -- INTERFACE_TRANSACTION_ID
                                    ln_rcv_group_id,                --GROUP_ID
                                    gn_request_id,                --REQUEST_ID
                                    SYSDATE,                --LAST_UPDATE_DATE
                                    ln_created_by,           --LAST_UPDATED_BY
                                    SYSDATE,                   --CREATION_DATE
                                    ln_created_by,                --CREATED_BY
                                    ln_created_by,         --LAST_UPDATE_LOGIN
                                    'RECEIVE',              --TRANSACTION_TYPE
                                    SYSDATE,                --TRANSACTION_DATE
                                    'PENDING',        --PROCESSING_STATUS_CODE
                                    'BATCH',            --PROCESSING_MODE_CODE
                                    'PENDING',       --TRANSACTION_STATUS_CODE
                                    rec_shipment_line.quantity_shipped, --QUANTITY
                                    rec_shipment_line.primary_unit_of_measure, --UNIT_OF_MEASURE
                                    'RCV',             --INTERFACE_SOURCE_CODE
                                    rec_shipment_line.item_id,       --ITEM_ID
                                    rec_shipment_line.deliver_to_person_id, --EMPLOYEE_ID
                                    'DELIVER',            --AUTO_TRANSACT_CODE
                                    rec_shipment_line.shipment_header_id, --SHIPMENT_HEADER_ID
                                    rec_shipment_line.shipment_line_id, --SHIPMENT_LINE_ID
                                    rec_shipment_line.ship_to_location_id, --SHIP_TO_LOCATION_ID
                                    lv_receipt_source_code, --RECEIPT_SOURCE_CODE
                                    rec_shipment_line.to_organization_id, --TO_ORGANIZATION_ID
                                    rec_shipment_line.source_document_code, --SOURCE_DOCUMENT_CODE
                                    rec_shipment_line.requisition_line_id, --REQUISITION_LINE_ID
                                    rec_shipment_line.req_distribution_id, --REQ_DISTRIBUTION_ID
                                    rec_shipment_line.destination_type_code, --DESTINATION_TYPE_CODE
                                    rec_shipment_line.deliver_to_person_id, --DELIVER_TO_PERSON_ID
                                    rec_shipment_line.deliver_to_location_id, --LOCATION_ID
                                    rec_shipment_line.deliver_to_location_id, --DELIVER_TO_LOCATION_ID
                                    NVL (rec_shipment_line.to_subinventory,
                                         pv_dest_subinv),       --SUBINVENTORY
                                    rec_shipment_line.shipment_num, --SHIPMENT_NUM
                                    SYSDATE + 1,      --EXPECTED_RECEIPT_DATE,
                                    SYSDATE,                    --SHIPPED_DATE
                                    ln_header_interface_id, --HEADER_INTERFACE_ID
                                    'Y',                     --VALIDATION_FLAG
                                    ln_org_id,
                                    rec_shipment_line.category_id,
                                    rec_shipment_line.primary_uom_code,
                                    rec_shipment_line.quantity_shipped,
                                    rec_shipment_line.primary_unit_of_measure,
                                    ln_vendor_id,
                                    ln_vendor_site_id,
                                    rec_shipment_line.routing_header_id,
                                    rec_shipment_line.po_header_id,
                                    rec_shipment_line.po_line_id,
                                    rec_shipment_line.po_line_location_id,
                                    rec_shipment_line.unit_price,
                                    rec_shipment_line.currency_code,
                                    lv_packing_slip,
                                    rec_shipment_line.primary_unit_of_measure,
                                    rec_shipment_line.item_number,
                                    rec_shipment_line.po_number,
                                    rec_shipment_line.line_num,
                                    rec_shipment_line.container_num);
            END LOOP;

            COMMIT;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'Interface records inserted, run Receiving Transaction Interface program');
        fnd_file.put_line (fnd_file.LOG, 'Group Id:' || ln_rcv_group_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Main Exception: ' || SQLERRM);
            ROLLBACK;
            pv_retcode   := 2;
    END receive_po_shipment;

    PROCEDURE create_asn_requisition (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_asn_number IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pn_dest_org_id IN NUMBER
                                      , pv_dest_subinv IN VARCHAR2)
    IS
        CURSOR cur_onhand IS
              SELECT DISTINCT moqd.organization_id source_org_id, moqd.subinventory_code source_subinventory, moqd.inventory_item_id,
                              msib.segment1 item_number, msib.primary_uom_code uom, msib.list_price_per_unit price,
                              rsl.quantity_shipped quantiy, pl.po_line_id, ph.segment1 po_number
                FROM apps.po_headers_all ph, apps.po_lines_all pl, apps.mtl_onhand_quantities_detail moqd,
                     apps.mtl_system_items_b msib, apps.rcv_shipment_headers rsh, apps.rcv_shipment_lines rsl
               WHERE     rsh.shipment_num = pv_asn_number
                     AND rsh.shipment_header_id = rsl.shipment_header_id
                     AND rsl.po_line_id = pl.po_line_id
                     AND ph.po_header_id = pl.po_header_id
                     AND moqd.inventory_item_id = pl.item_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.inventory_item_id = msib.inventory_item_id
                     AND moqd.organization_id = msib.organization_id
            ORDER BY msib.segment1;

        ln_req_request_id       NUMBER;
        ln_del_to_loc_id        NUMBER;
        ln_ccid                 NUMBER;
        lv_source_code          VARCHAR2 (200);
        ln_item_exists          NUMBER;
        ln_resp_id              NUMBER;
        ln_resp_appl_id         NUMBER;
        ln_org_id               NUMBER;
        ln_person_id            NUMBER;
        lb_bol_result           BOOLEAN;
        lv_chr_phase            VARCHAR2 (120 BYTE);
        lv_chr_status           VARCHAR2 (120 BYTE);
        lv_requisition_number   VARCHAR2 (200);
        lv_chr_dev_phase        VARCHAR2 (120 BYTE);
        lv_chr_dev_status       VARCHAR2 (120 BYTE);
        lv_chr_message          VARCHAR2 (2000 BYTE);
        lv_proceed_flag         VARCHAR2 (1);
        ln_rsl_line_count       NUMBER;
        ln_rti_line_count       NUMBER;
        ln_onhand_mismatch      NUMBER;
        ln_asn_count            NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Create Requisitions - Process Started...');
        fnd_file.put_line (fnd_file.LOG, 'ASN Number: ' || pv_asn_number);
        fnd_file.put_line (fnd_file.LOG, 'Source Org ID: ' || pn_src_org_id);
        fnd_file.put_line (fnd_file.LOG, 'Source Sub: ' || pv_src_subinv);
        fnd_file.put_line (fnd_file.LOG, 'Dest Org ID: ' || pn_dest_org_id);
        fnd_file.put_line (fnd_file.LOG, 'Dest Sub: ' || pv_dest_subinv);

        lv_proceed_flag   := 'Y';

        SELECT COUNT (DISTINCT rsh.shipment_num)
          INTO ln_asn_count
          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
         WHERE     rsh.shipment_num = pv_asn_number
               AND rsh.shipment_header_id = rsl.shipment_header_id
               AND rsl.to_organization_id = pn_src_org_id;


        IF ln_asn_count = 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'ASN doesnt exists');
            pv_retcode        := 2;
            lv_proceed_flag   := 'N';
        END IF;


        /* Check whether the lines are fully received or not */
        SELECT COUNT (1)
          INTO ln_rsl_line_count
          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
         WHERE     rsh.shipment_num = pv_asn_number
               AND rsh.shipment_header_id = rsl.shipment_header_id
               AND rsl.shipment_line_status_code <> 'FULLY RECEIVED'
               AND rsl.to_organization_id = pn_src_org_id;

        SELECT COUNT (1)
          INTO ln_rti_line_count
          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
         WHERE     rsh.shipment_num = pv_asn_number
               AND rsh.shipment_header_id = rsl.shipment_header_id
               AND rsl.quantity_shipped <>
                   (SELECT SUM (quantity)
                      FROM rcv_transactions
                     WHERE     shipment_line_id = rsl.shipment_line_id
                           AND transaction_type = 'DELIVER');

        /* Check Onhand in synch with PO quantity */
        SELECT COUNT (1)
          INTO ln_onhand_mismatch
          FROM apps.rcv_shipment_lines rsl, apps.rcv_shipment_headers rsh
         WHERE     rsh.shipment_num = pv_asn_number
               AND rsh.shipment_header_id = rsl.shipment_header_id
               AND rsl.quantity_shipped >
                   (SELECT SUM (moqd.primary_transaction_quantity)
                      FROM apps.mtl_onhand_quantities_detail moqd
                     WHERE     moqd.inventory_item_id = rsl.item_id
                           AND moqd.organization_id = rsl.to_organization_id
                           AND moqd.subinventory_code = pv_src_subinv);


        IF ln_rsl_line_count <> 0 OR ln_rti_line_count <> 0
        THEN
            fnd_file.put_line (fnd_file.LOG, 'ASN is not fully received');
            pv_retcode        := 2;
            lv_proceed_flag   := 'N';
        END IF;

        IF ln_onhand_mismatch <> 0
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Available Onhand is not equal to ASN quantity');
            pv_retcode        := 2;
            lv_proceed_flag   := 'N';
        END IF;

        IF lv_proceed_flag = 'Y'
        THEN
            SELECT employee_id
              INTO ln_person_id
              FROM fnd_user
             WHERE user_name = fnd_global.user_name;

            /*fnd_file.put_line (fnd_file.LOG, 'Person Id: ' || ln_person_id);*/

            SELECT location_id
              INTO ln_del_to_loc_id
              FROM hr_organization_units_v
             WHERE organization_id = pn_dest_org_id;


            SELECT material_account
              INTO ln_ccid
              FROM mtl_parameters
             WHERE organization_id = pn_dest_org_id;


            lv_source_code   := TO_CHAR (pv_asn_number);

            FOR rec_onhand IN cur_onhand
            LOOP
                /*fnd_file.put_line (
                   fnd_file.LOG,
                   'Processing the Item : ' || rec_onhand.item_number);*/

                ln_item_exists   := 0;

                BEGIN
                    SELECT COUNT (1)
                      INTO ln_item_exists
                      FROM mtl_system_items_kfv msi
                     WHERE     msi.organization_id = pn_dest_org_id
                           AND msi.inventory_item_id =
                               rec_onhand.inventory_item_id;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_item_exists   := 0;
                END;

                IF ln_item_exists = 0
                THEN
                    fnd_file.put_line (
                        fnd_file.LOG,
                           'Item: '
                        || rec_onhand.item_number
                        || ' doesn''t exists in Destintation Org');
                ELSE
                    SELECT operating_unit
                      INTO ln_org_id
                      FROM apps.org_organization_definitions
                     WHERE organization_id = pn_src_org_id;

                    /*fnd_file.put_line (fnd_file.LOG,
                                       'Operating Unit : ' || ln_org_id); */


                    INSERT INTO po_requisitions_interface_all (
                                    Interface_source_code,
                                    Requisition_type,
                                    Org_id,
                                    Authorization_status,
                                    Charge_account_id,
                                    quantity,
                                    uom_code,
                                    group_code,
                                    item_id,
                                    need_by_date,
                                    Preparer_id,
                                    deliver_to_requestor_id,
                                    Source_type_code,
                                    source_organization_id,
                                    source_subinventory,
                                    destination_type_code,
                                    destination_organization_id,
                                    destination_subinventory,
                                    deliver_to_location_id,
                                    line_attribute1,
                                    line_attribute10,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (lv_source_code, 'INTERNAL', ln_org_id, /* ORG_ID */
                                 'APPROVED',           -- Authorization_Status
                                             ln_ccid,            -- Valid ccid
                                                      rec_onhand.quantiy, -- Quantity
                                 rec_onhand.uom,                   -- UOm Code
                                                 lv_source_code, rec_onhand.inventory_item_id, SYSDATE + 1, -- neeed by date
                                                                                                            ln_person_id, -- Person id of the preparer
                                                                                                                          ln_person_id, -- Person_id of the requestor
                                                                                                                                        'INVENTORY', -- source_type_code
                                                                                                                                                     rec_onhand.source_org_id, -- Source org id - US4
                                                                                                                                                                               rec_onhand.source_subinventory, --- source subinventory
                                                                                                                                                                                                               'INVENTORY', -- destination_type_code
                                                                                                                                                                                                                            pn_dest_org_id, -- Destination org id - US1
                                                                                                                                                                                                                                            pv_dest_subinv, -- destination sub inventory
                                                                                                                                                                                                                                                            ln_del_to_loc_id, rec_onhand.po_number, rec_onhand.po_line_id, SYSDATE, gn_user_id, SYSDATE
                                 , gn_user_id);
                END IF;
            END LOOP;



            COMMIT;

            fnd_file.put_line (
                fnd_file.LOG,
                'Create Requisitions - Launching the Requisition import requests...');

            BEGIN
                SELECT responsibility_id, application_id
                  INTO ln_resp_id, ln_resp_appl_id
                  FROM fnd_responsibility_tl
                 WHERE     responsibility_name =
                           'Deckers WMS Inv Control Manager'
                       AND language = 'US';
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_resp_id        := 51614;
                    ln_resp_appl_id   := 385;
            END;

            APPS.FND_GLOBAL.APPS_INITIALIZE (
                USER_ID        => gn_user_id,
                RESP_ID        => ln_resp_id,
                RESP_APPL_ID   => ln_resp_appl_id);

            /*APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => 4962,
                                             RESP_ID        => 51614,
                                             RESP_APPL_ID   => 385); */


            ln_req_request_id   :=
                apps.fnd_request.submit_request (application => 'PO', -- application short name
                                                                      program => 'REQIMPORT', -- program short name
                                                                                              start_time => SYSDATE, sub_request => FALSE, argument1 => lv_source_code, -- interface source code
                                                                                                                                                                        argument2 => NULL, -- Batch Id
                                                                                                                                                                                           argument3 => 'ALL', -- Group By
                                                                                                                                                                                                               argument4 => NULL, -- Last Requisition Number
                                                                                                                                                                                                                                  argument5 => 'N'
                                                 ,      -- Multi Distributions
                                                   argument6 => 'Y' -- Initiate Requisition Approval after Requisition Import    /* APPROVAL_PARAMETER */
                                                                   );

            COMMIT;

            fnd_file.put_line (
                fnd_file.LOG,
                'Requisition Request Id :' || ln_req_request_id);

            IF ln_req_request_id <> 0
            THEN
                lb_bol_result   :=
                    fnd_concurrent.wait_for_request (ln_req_request_id,
                                                     15,
                                                     0,
                                                     lv_chr_phase,
                                                     lv_chr_status,
                                                     lv_chr_dev_phase,
                                                     lv_chr_dev_status,
                                                     lv_chr_message);

                IF lv_chr_dev_phase = 'COMPLETE'
                THEN
                    BEGIN
                        SELECT segment1
                          INTO lv_requisition_number
                          FROM apps.po_requisition_headers_all
                         WHERE interface_source_code = lv_source_code;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            fnd_file.put_line (
                                fnd_file.LOG,
                                'Unable to find requisituon number, search manually');
                            lv_requisition_number   := NULL;
                    END;
                END IF;
            END IF;

            IF lv_requisition_number IS NOT NULL
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Requisituon number: ' || lv_requisition_number);
            END IF;


            fnd_file.put_line (fnd_file.LOG,
                               'Create Requisitions - Process Ended');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line (
                'Unexpected error while creating requisitions :' || SQLERRM);
            ROLLBACK;
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while creating requisitions :' || SQLERRM);
    END create_asn_requisition;
END XXDO_WMS_INVENTORY_CONVERSION;
/
