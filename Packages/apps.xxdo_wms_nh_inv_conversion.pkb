--
-- XXDO_WMS_NH_INV_CONVERSION  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:04 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_NH_INV_CONVERSION"
AS
    /******************************************************************************************
    -- Modification History:
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 18-MAR-2018  1.0        Krishna Lavu            NH Inventory Movement Project
    -- 05-JUN-2018  1.1        Krishna Lavu            Aging Calculation Defect
    -- 03-NOV-2018  1.2        Krishna Lavu            CCR0007600 Enhancements
    ******************************************************************************************/

    gn_user_id              NUMBER := FND_GLOBAL.USER_ID;
    gv_user_name            VARCHAR2 (200) := FND_GLOBAL.USER_NAME;
    gn_request_id           NUMBER := FND_GLOBAL.CONC_REQUEST_ID;
    gv_src_org              VARCHAR2 (200);
    gv_dest_org             VARCHAR2 (200);
    gv_brand                VARCHAR2 (200);
    gv_dock_door            VARCHAR2 (200);
    gv_requisition_number   VARCHAR2 (200);
    gn_dock_door_id         NUMBER;
    gv_transfer_date        VARCHAR2 (100);
    gn_org_id               NUMBER;

    PROCEDURE insert_message (pv_message_type   IN VARCHAR2,
                              pv_message        IN VARCHAR2)
    AS
    BEGIN
        IF UPPER (pv_message_type) IN ('LOG', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_message);
        END IF;

        IF UPPER (pv_message_type) IN ('OUTPUT', 'BOTH')
        THEN
            fnd_file.put_line (fnd_file.OUTPUT, pv_message);
        END IF;

        IF UPPER (pv_message_type) = 'DATABASE'
        THEN
            DBMS_OUTPUT.put_line (pv_message);
        END IF;
    END insert_message;

    /*
    ***********************************************************************************
     Procedure/Function Name  :  wait_for_request
     Description              :  This procedure waits for the child concurrent programs
                                 that are spawned by current program
    **********************************************************************************
    */
    PROCEDURE wait_for_request (in_num_parent_req_id IN NUMBER)
    AS
        ln_count                NUMBER := 0;
        ln_num_intvl            NUMBER := 5;
        ln_data_set_id          NUMBER := NULL;
        ln_num_max_wait         NUMBER := 120000;
        lv_chr_phase            VARCHAR2 (250) := NULL;
        lv_chr_status           VARCHAR2 (250) := NULL;
        lv_chr_dev_phase        VARCHAR2 (250) := NULL;
        lv_chr_dev_status       VARCHAR2 (250) := NULL;
        lv_chr_msg              VARCHAR2 (250) := NULL;
        lb_bol_request_status   BOOLEAN;

        ------------------------------------------
        --Cursor to fetch the child request id's--
        ------------------------------------------
        CURSOR cur_child_req_id IS
            SELECT request_id
              FROM fnd_concurrent_requests
             WHERE parent_request_id = in_num_parent_req_id;
    ---------------
    --Begin Block--
    ---------------
    BEGIN
        ------------------------------------------------------
        --Loop for each child request to wait for completion--
        ------------------------------------------------------
        FOR rec_child_req_id IN cur_child_req_id
        LOOP
            --Wait for request to complete
            lb_bol_request_status   :=
                fnd_concurrent.wait_for_request (rec_child_req_id.request_id,
                                                 ln_num_intvl,
                                                 ln_num_max_wait,
                                                 lv_chr_phase, -- out parameter
                                                 lv_chr_status, -- out parameter
                                                 lv_chr_dev_phase,
                                                 -- out parameter
                                                 lv_chr_dev_status,
                                                 -- out parameter
                                                 lv_chr_msg   -- out parameter
                                                           );

            IF    UPPER (lv_chr_dev_status) = 'WARNING'
               OR UPPER (lv_chr_dev_status) = 'ERROR'
            THEN
                fnd_file.put_line (
                    fnd_file.LOG,
                       'Error in submitting the request, request_id = '
                    || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_phase =' || lv_chr_phase);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_status =' || lv_chr_status);
                fnd_file.put_line (
                    fnd_file.LOG,
                    'Error,lv_chr_dev_status =' || lv_chr_dev_status);
                fnd_file.put_line (fnd_file.LOG,
                                   'Error,lv_chr_msg =' || lv_chr_msg);
            ELSE
                fnd_file.put_line (fnd_file.LOG, 'Request completed');
                fnd_file.put_line (
                    fnd_file.LOG,
                    'request_id = ' || rec_child_req_id.request_id);
                fnd_file.put_line (fnd_file.LOG,
                                   'lv_chr_msg =' || lv_chr_msg);
            END IF;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG, 'Error:' || SQLERRM);
    END wait_for_request;

    PROCEDURE extract_main (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_brand IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pv_dock_door IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2
                            , pv_dest_locator IN VARCHAR2)
    AS
        lv_src_org         VARCHAR2 (10);
        lv_dest_org        VARCHAR2 (10);
        lv_return_status   VARCHAR2 (1) := 'S';
        ln_dock_door_id    NUMBER;
        ln_org_id          NUMBER;
    BEGIN
        BEGIN
            SELECT organization_code, operating_unit
              INTO lv_src_org, ln_org_id
              FROM apps.org_organization_definitions
             WHERE organization_id = pn_src_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_src_org   := NULL;
        END;

        BEGIN
            SELECT organization_code
              INTO lv_dest_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pn_dest_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dest_org   := NULL;
        END;

        gn_org_id      := ln_org_id;

        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');
        insert_message (
            'BOTH',
            '+------------------------------- Parameters --------------------------------+');

        insert_message ('BOTH', 'Brand: ' || UPPER (pv_brand));
        insert_message ('BOTH', 'Source Org: ' || lv_src_org);
        insert_message ('BOTH', 'Source Subinventory: ' || pv_src_subinv);
        insert_message ('BOTH', 'Source Locator: ' || pv_src_locator);
        insert_message ('BOTH', 'Dock Door: ' || pv_dock_door);
        insert_message ('BOTH', 'Destination Org: ' || lv_dest_org);
        insert_message ('BOTH',
                        'Destination Subinventory: ' || pv_dest_subinv);
        insert_message ('LOG', 'User Name: ' || gv_user_name);
        insert_message ('LOG', 'Resp Appl ID: ' || FND_GLOBAL.RESP_APPL_ID);

        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');

        gv_src_org     := lv_src_org;
        gv_dest_org    := lv_dest_org;
        gv_brand       := UPPER (pv_brand);
        gv_dock_door   := pv_dock_door;

        BEGIN
            SELECT flv.meaning
              INTO gv_transfer_date
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_NH_INV_TRANSFER_DATE'
                   AND flv.language = 'US'
                   AND flv.lookup_code = gv_src_org
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_return_status   := 'E';
                insert_message (
                    'BOTH',
                    'No Transfer Date defined for the Org in the Lookup');
        END;

        insert_message ('LOG', 'Transfer Date: ' || gv_transfer_date);


        IF lv_return_status = 'S'
        THEN
            lv_return_status   :=
                validate_data (UPPER (pv_brand), pn_src_org_id, pv_src_subinv
                               , pv_src_locator, pn_dest_org_id);

            IF lv_return_status = 'S'
            THEN
                /*Insert the SKU and LPN information in staging table */
                onhand_insert (pn_src_org_id, pv_src_subinv, pv_src_locator,
                               pn_dest_org_id, pv_dest_subinv, pv_dest_locator
                               , lv_return_status);
            END IF;
        END IF;

        IF lv_return_status = 'S'
        THEN
            /*Write the SKU and LPN information in staging table
              onhand_extract (pn_src_org_id, pv_src_subinv, pv_src_locator);*/

            /* Creates Internal Requisition */
            create_internal_requisition (pn_src_org_id, pv_src_subinv, pv_src_locator, pn_dest_org_id, pv_dest_subinv, pv_dest_locator
                                         , lv_return_status);
        END IF;

        IF lv_return_status <> 'S'
        THEN
            pv_retcode   := 2;
        ELSIF lv_return_status = 'S'
        THEN
            insert_iso_data (pn_src_org_id, pv_src_subinv, pv_src_locator);

            relieve_atp;

            create_internal_orders (lv_return_status);

            IF lv_return_status = 'S'
            THEN
                run_order_import (lv_return_status);
            END IF;

            IF lv_return_status = 'S'
            THEN
                schedule_iso;
            --progress_workflow;
            END IF;
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
                            pv_src_subinv    IN VARCHAR2,
                            pv_src_locator   IN VARCHAR2,
                            pn_dest_org_id   IN NUMBER)
        RETURN VARCHAR2
    IS
        CURSOR cur_validate_item_config IS
            SELECT DISTINCT segment1
              FROM apps.mtl_system_items_b
             WHERE     inventory_item_id IN
                           (SELECT DISTINCT moqd.inventory_item_id
                              FROM apps.mtl_item_locations_kfv mil, apps.mtl_onhand_quantities_detail moqd
                             WHERE     mil.subinventory_code = pv_src_subinv
                                   AND mil.concatenated_segments =
                                       pv_src_locator
                                   AND mil.organization_id = pn_src_org_id
                                   AND mil.subinventory_code =
                                       moqd.subinventory_code
                                   AND mil.inventory_location_id =
                                       moqd.locator_id
                                   AND mil.organization_id =
                                       moqd.organization_id)
                   AND organization_id = pn_dest_org_id
                   AND (PURCHASING_ENABLED_FLAG = 'N' OR INTERNAL_ORDER_ENABLED_FLAG = 'N');

        /* Added for CCR0007600*/
        CURSOR cur_validate_item_config_src IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_system_items_b msib, apps.mtl_item_locations_kfv mil, apps.mtl_onhand_quantities_detail moqd
             WHERE     msib.inventory_item_id = moqd.inventory_item_id
                   AND mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = pn_src_org_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND mil.organization_id = moqd.organization_id
                   AND msib.organization_id = moqd.organization_id
                   AND (msib.PURCHASING_ENABLED_FLAG = 'N' OR msib.INTERNAL_ORDER_ENABLED_FLAG = 'N');

        CURSOR cur_item_exists IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_item_locations_kfv mil, apps.mtl_system_items_b msib, apps.mtl_onhand_quantities_detail moqd
             WHERE     mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = pn_src_org_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND mil.organization_id = moqd.organization_id
                   AND msib.organization_id = moqd.organization_id
                   AND msib.inventory_item_id = moqd.inventory_item_id
                   AND NOT EXISTS
                           (SELECT msi1.segment1
                              FROM apps.mtl_system_items_kfv msi1
                             WHERE     msi1.organization_id = pn_dest_org_id
                                   AND msi1.segment1 = msib.segment1);

        CURSOR cur_check_reservations IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_item_locations_kfv mil, apps.mtl_reservations mr, apps.mtl_system_items_b msib
             WHERE     mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = pn_src_org_id
                   AND mil.subinventory_code = mr.subinventory_code
                   AND mil.inventory_location_id = mr.locator_id
                   AND mil.organization_id = mr.organization_id
                   AND msib.inventory_item_id = mr.inventory_item_id
                   AND msib.organization_id = mr.organization_id;

        CURSOR cur_check_picktasks IS
            SELECT DISTINCT ooh.order_number
              FROM apps.mtl_material_transactions_temp mmtt, apps.oe_order_lines_all ool, apps.oe_order_headers_all ooh,
                   apps.mtl_item_locations_kfv mil
             WHERE     mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = pn_src_org_id
                   AND mmtt.organization_id = mil.organization_id
                   AND mil.subinventory_code = mmtt.subinventory_code
                   AND mil.inventory_location_id = mmtt.locator_id
                   AND mmtt.transaction_type_id = 52
                   AND mmtt.trx_source_line_id = ool.line_id
                   AND mmtt.organization_id = ool.ship_from_org_id
                   AND ool.header_id = ooh.header_id;

        CURSOR cur_loose_inventory IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_item_locations_kfv mil, apps.mtl_onhand_quantities_detail moqd, apps.mtl_system_items_b msib
             WHERE     mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = pn_src_org_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND mil.organization_id = moqd.organization_id
                   AND moqd.organization_id = msib.organization_id
                   AND moqd.inventory_item_id = msib.inventory_item_id
                   AND moqd.lpn_id IS NULL;

        CURSOR cur_multiple_sku_casepack IS
              SELECT wlpn.license_plate_number, COUNT (DISTINCT moqd.inventory_item_id)
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_item_locations_kfv mil, apps.wms_license_plate_numbers wlpn
               WHERE     mil.subinventory_code = pv_src_subinv
                     AND mil.organization_id = pn_src_org_id
                     AND mil.concatenated_segments = pv_src_locator
                     AND mil.organization_id = moqd.organization_id
                     AND mil.subinventory_code = moqd.subinventory_code
                     AND mil.inventory_location_id = moqd.locator_id
                     AND wlpn.lpn_id = moqd.lpn_id
                     AND wlpn.organization_id = moqd.organization_id
            GROUP BY wlpn.license_plate_number
              HAVING COUNT (DISTINCT moqd.inventory_item_id) > 1;

        CURSOR cur_onhand_packed_qty_mismatch IS
            SELECT license_plate_number, sku, onhand,
                   packed_qty
              FROM (  SELECT wlpn.license_plate_number,
                             msib.segment1 sku,
                             SUM (moqd.transaction_quantity) onhand,
                             (SELECT SUM (quantity)
                                FROM apps.wms_lpn_contents
                               WHERE parent_lpn_id = wlpn.lpn_id) packed_qty
                        FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_item_locations_kfv mil, apps.wms_license_plate_numbers wlpn,
                             apps.mtl_system_items_b msib
                       WHERE     mil.subinventory_code = pv_src_subinv
                             AND mil.organization_id = pn_src_org_id
                             AND mil.concatenated_segments = pv_src_locator
                             AND mil.organization_id = moqd.organization_id
                             AND mil.subinventory_code = moqd.subinventory_code
                             AND mil.inventory_location_id = moqd.locator_id
                             AND wlpn.lpn_id = moqd.lpn_id
                             AND wlpn.organization_id = moqd.organization_id
                             AND msib.inventory_item_id =
                                 moqd.inventory_item_id
                             AND msib.organization_id = moqd.organization_id
                    GROUP BY wlpn.license_plate_number, msib.segment1, wlpn.lpn_id)
             WHERE onhand <> packed_qty;

        CURSOR cur_cpq_onhand_mismatch IS
            SELECT license_plate_number, sku, onhand,
                   packed_qty, cpq
              FROM (  SELECT wlpn.license_plate_number,
                             msib.segment1 sku,
                             muc.conversion_rate cpq,
                             SUM (moqd.transaction_quantity) onhand,
                             (SELECT SUM (quantity)
                                FROM apps.wms_lpn_contents
                               WHERE parent_lpn_id = wlpn.lpn_id) packed_qty
                        FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_item_locations_kfv mil, apps.wms_license_plate_numbers wlpn,
                             apps.mtl_system_items_b msib, apps.mtl_uom_conversions muc
                       WHERE     mil.subinventory_code = pv_src_subinv
                             AND mil.organization_id = pn_src_org_id
                             AND mil.concatenated_segments = pv_src_locator
                             AND mil.organization_id = moqd.organization_id
                             AND mil.subinventory_code = moqd.subinventory_code
                             AND mil.inventory_location_id = moqd.locator_id
                             AND wlpn.lpn_id = moqd.lpn_id
                             AND wlpn.organization_id = moqd.organization_id
                             AND msib.inventory_item_id =
                                 moqd.inventory_item_id
                             AND msib.organization_id = moqd.organization_id
                             AND msib.inventory_item_id = muc.inventory_item_id
                             AND muc.disable_date IS NULL
                    GROUP BY wlpn.license_plate_number, msib.segment1, muc.conversion_rate,
                             wlpn.lpn_id)
             WHERE (onhand <> cpq) OR (packed_qty <> cpq);

        CURSOR cur_location_mismatch IS
            SELECT DISTINCT wlpn.license_plate_number lpn, wlpn.subinventory_code lpn_sub, wlpn.locator_id lpn_loc,
                            moqd.subinventory_code onhand_sub, moqd.locator_id onhand_loc
              FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_item_locations_kfv mil, apps.wms_license_plate_numbers wlpn
             WHERE     mil.subinventory_code = pv_src_subinv
                   AND mil.organization_id = pn_src_org_id
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = moqd.organization_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND wlpn.lpn_id = moqd.lpn_id
                   AND wlpn.organization_id = moqd.organization_id
                   AND (wlpn.subinventory_code <> moqd.subinventory_code OR wlpn.locator_id <> moqd.locator_id);

        CURSOR cur_truck_items IS
              SELECT msi.segment1 item_number, SUM (moqd.transaction_quantity) quantity
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_system_items_kfv msi, apps.mtl_item_locations_kfv mil
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
            GROUP BY msi.segment1
            ORDER BY msi.segment1;

        CURSOR cur_item_quantities (pv_item IN VARCHAR2)
        IS
            SELECT (SELECT NVL (SUM (transaction_quantity), 0)
                      FROM apps.mtl_onhand_quantities_detail
                     WHERE     subinventory_code IN ('BULK', 'RSV', 'BULK4')
                           AND organization_id = msib.organization_id
                           AND inventory_item_id = msib.inventory_item_id)
                       case_quantity,
                   (SELECT NVL (SUM (transaction_quantity), 0)
                      FROM apps.mtl_onhand_quantities_detail
                     WHERE     subinventory_code IN ('TRUCK')
                           AND organization_id = msib.organization_id
                           AND inventory_item_id = msib.inventory_item_id)
                       truck_quantity,
                   apps.f_get_atr (msib.inventory_item_id, msib.organization_id, NULL
                                   , NULL)
                       free_atr,
                   xxdo_wms_nh_inv_conversion.f_get_supply (
                       msib.inventory_item_id,
                       msib.organization_id,
                       SYSDATE,
                       TO_DATE (gv_transfer_date, 'DD-MON-YYYY'))
                       supply_quantity,
                   (SELECT NVL (SUM (atp), 0)
                      FROM xxdo.xxdo_atp_final atp
                     WHERE     atp.organization_id = msib.organization_id
                           AND demand_class = '-1'
                           AND atp.inventory_item_id = msib.inventory_item_id
                           AND TRUNC (dte) = TRUNC (SYSDATE))
                       free_atp,
                   (SELECT NVL (SUM (ordered_quantity), 0)
                      FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                     WHERE     flv.lookup_type = 'XXDO_NH_BLANKET_ISO_LIST'
                           AND flv.language = 'US'
                           AND ooha.order_number = flv.lookup_code
                           AND flv.enabled_flag = 'Y'
                           AND ooha.header_id = oola.header_id
                           AND oola.inventory_item_id =
                               msib.inventory_item_id
                           AND oola.ship_from_org_id = msib.organization_id
                           AND oola.schedule_ship_date IS NOT NULL
                           AND NVL (oola.open_flag, 'N') = 'Y'
                           AND NVL (oola.cancelled_flag, 'N') = 'N'
                           AND oola.line_category_code = 'ORDER'
                           AND oola.flow_status_code = 'AWAITING_SHIPPING')
                       released_iso_quantity
              FROM apps.xxd_common_items_v xdiv, apps.mtl_system_items_b msib
             WHERE     xdiv.organization_id = pn_src_org_id
                   AND msib.segment1 = pv_item
                   AND xdiv.organization_id = msib.organization_id
                   AND xdiv.item_number = msib.segment1
                   AND msib.enabled_flag = 'Y'
                   AND msib.inventory_item_id IN
                           (SELECT DISTINCT item_id inventory_item_id
                              FROM apps.mtl_supply
                             WHERE to_organization_id = pn_src_org_id
                            UNION
                            SELECT DISTINCT inventory_item_id
                              FROM apps.mtl_onhand_quantities_detail
                             WHERE organization_id = pn_src_org_id
                            UNION
                            SELECT DISTINCT oola.inventory_item_id
                              FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                             WHERE     flv.lookup_type =
                                       'XXDO_NH_BLANKET_ISO_LIST'
                                   AND flv.language = 'US'
                                   AND ooha.order_number = flv.lookup_code
                                   AND ooha.header_id = oola.header_id
                                   AND oola.ship_from_org_id = pn_src_org_id
                                   AND oola.schedule_ship_date IS NOT NULL
                                   AND NVL (oola.open_flag, 'N') = 'Y'
                                   AND NVL (oola.cancelled_flag, 'N') = 'N'
                                   AND oola.line_category_code = 'ORDER'
                                   AND oola.flow_status_code =
                                       'AWAITING_SHIPPING');

        CURSOR cur_item_cpq IS
            SELECT DISTINCT msib.segment1
              FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_item_locations_kfv mil, apps.wms_license_plate_numbers wlpn,
                   apps.mtl_system_items_b msib
             WHERE     mil.subinventory_code = pv_src_subinv
                   AND mil.organization_id = pn_src_org_id
                   AND mil.concatenated_segments = pv_src_locator
                   AND mil.organization_id = moqd.organization_id
                   AND mil.subinventory_code = moqd.subinventory_code
                   AND mil.inventory_location_id = moqd.locator_id
                   AND wlpn.lpn_id = moqd.lpn_id
                   AND wlpn.organization_id = moqd.organization_id
                   AND msib.inventory_item_id = moqd.inventory_item_id
                   AND msib.organization_id = moqd.organization_id
                   AND NOT EXISTS
                           (SELECT inventory_item_id
                              FROM apps.mtl_uom_conversions muc
                             WHERE     msib.inventory_item_id =
                                       muc.inventory_item_id
                                   AND muc.disable_date IS NULL);

        /* Added for CCR0007600 */
        CURSOR c_lpn_length_check IS
            SELECT DISTINCT license_plate_number, LENGTH (license_plate_number) LENGTH
              FROM apps.wms_license_plate_numbers wlpn, apps.mtl_item_locations_kfv mil
             WHERE     mil.organization_id = pn_src_org_id
                   AND mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND wlpn.organization_id = mil.organization_id
                   AND wlpn.subinventory_code = mil.subinventory_code
                   AND wlpn.locator_id = mil.inventory_location_id
                   AND EXISTS
                           (SELECT 1
                              FROM apps.wms_lpn_contents wlc
                             WHERE wlc.parent_lpn_id = wlpn.lpn_id);

        CURSOR c_lpn_validation IS
            SELECT DISTINCT license_plate_number
              FROM apps.wms_license_plate_numbers wlpn, apps.mtl_item_locations_kfv mil
             WHERE     mil.organization_id = pn_src_org_id
                   AND mil.subinventory_code = pv_src_subinv
                   AND mil.concatenated_segments = pv_src_locator
                   AND wlpn.lpn_id = wlpn.parent_lpn_id
                   AND wlpn.organization_id = mil.organization_id
                   AND wlpn.subinventory_code = mil.subinventory_code
                   AND wlpn.locator_id = mil.inventory_location_id;


        lv_return_status           VARCHAR2 (1);
        ln_loose_quantity          NUMBER;
        ln_cnt                     NUMBER;
        lv_include_free_atp        VARCHAR2 (1);
        ln_max_transfer_quantity   NUMBER;
        ln_truck_quantity          NUMBER;
        ln_free_atp                NUMBER;
        ln_dock_door_id            NUMBER;
        ln_count                   NUMBER;
    BEGIN
        lv_return_status   := 'S';

        /* Validating SKU Configuration in Destination Organization */
        insert_message (
            'BOTH',
            '+------------------------- Start Validation --------------------------------+');
        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');

        insert_message ('LOG',
                        'Validating Source and Destination Organization');

        IF pn_dest_org_id = pn_src_org_id
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Source Org: '
                || gv_src_org
                || 'cannot be same as Destination Org: '
                || gv_dest_org);
        END IF;

        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');

        BEGIN
            SELECT inventory_location_id
              INTO ln_dock_door_id
              FROM apps.mtl_item_locations_kfv
             WHERE     organization_id = pn_src_org_id
                   AND concatenated_segments = gv_dock_door
                   AND attribute1 = 'LTL';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_dock_door_id    := NULL;
                lv_return_status   := 'E';
                insert_message (
                    'BOTH',
                       'Dock Door: '
                    || gv_dock_door
                    || ', is invalid or not LTL');
        END;

        gn_dock_door_id    := ln_dock_door_id;

        SELECT COUNT (DISTINCT wst.delivery_id)
          INTO ln_count
          FROM apps.mtl_item_locations_kfv mil, apps.wms_shipping_transaction_temp wst
         WHERE     mil.organization_id = pn_src_org_id
               AND mil.concatenated_segments = gv_dock_door
               AND mil.inventory_location_id = wst.dock_door_id
               AND mil.organization_id = wst.organization_id;


        IF ln_count <> 0
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Dock Door: ' || gv_dock_door || ', is not empty');
        END IF;


        SELECT COUNT (DISTINCT request_id)
          INTO ln_count
          FROM XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
         WHERE     source_locator = pv_src_locator
               AND source_org_id = pn_src_org_id
               AND process_status <> 'COMPLETE';

        IF ln_count <> 0
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Truck Locator: '
                || pv_src_locator
                || ' is already in process. Cannot submit more than once');
        END IF;

        SELECT COUNT (DISTINCT request_id)
          INTO ln_count
          FROM XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
         WHERE     dock_door = gv_dock_door
               AND source_org_id = pn_src_org_id
               AND process_status <> 'COMPLETE';

        IF ln_count <> 0
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Dock Door: '
                || gv_dock_door
                || ' is already in process. Please use different one');
        END IF;

        SELECT COUNT (DISTINCT moqd.inventory_item_id)
          INTO ln_count
          FROM apps.mtl_item_locations_kfv mil, apps.mtl_onhand_quantities_detail moqd
         WHERE     mil.subinventory_code = pv_src_subinv
               AND mil.concatenated_segments = pv_src_locator
               AND mil.organization_id = pn_src_org_id
               AND mil.subinventory_code = moqd.subinventory_code
               AND mil.inventory_location_id = moqd.locator_id
               AND mil.organization_id = moqd.organization_id;

        IF ln_count = 0
        THEN
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'No Inventory exists in the Truck Location: '
                || pv_src_locator);
        END IF;

        insert_message (
            'LOG',
            'Validating SKU Configuration in Destination Organization');

        FOR rec_validate_item_config IN cur_validate_item_config
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Item Not purchase enabled or Internal Order Enabled Dest Org: '
                || rec_validate_item_config.segment1);
        END LOOP;

        /* Added for CCR0007600 */
        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        insert_message (
            'LOG',
            'Validating SKU Configuration in Source Organization');

        FOR rec_validate_item_config_src IN cur_validate_item_config_src
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Item Not purchase enabled or Internal Order Enabled in Source Org: '
                || rec_validate_item_config_src.segment1);
        END LOOP;


        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Items doesnt exist in Destination Org */
        insert_message ('LOG',
                        'Checking Item exist or not in Destination Org');

        FOR rec_item_exists IN cur_item_exists
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Item doesnt exists in Destination Org: ' || rec_item_exists.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Items has CPQ */
        insert_message ('LOG', 'Checking Item has CPQ defined');

        FOR rec_item_cpq IN cur_item_cpq
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'CPQ Not Defined for the Item: ' || rec_item_cpq.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Reservations */
        insert_message ('LOG', 'Checking for Reservation');

        FOR rec_check_reservations IN cur_check_reservations
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Reservations exists for SKU: ' || rec_check_reservations.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Open Pick Tasks */
        insert_message ('LOG', 'Checking for Pending Pick Tasks');

        FOR rec_check_picktasks IN cur_check_picktasks
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Pick Tasks Exists for the order: ' || rec_check_picktasks.order_number);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Loose Inventory */
        insert_message ('LOG', 'Checking for Loose Quantity in the location');

        FOR rec_loose_inventory IN cur_loose_inventory
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Loose Quantity exists in the location for SKU: '
                || rec_loose_inventory.segment1);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check Multiple SKU in Case Packs */
        insert_message (
            'LOG',
            'Checking for Multiple SKU in Case Packs in the location');

        FOR rec_multiple_sku_casepack IN cur_multiple_sku_casepack
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Multiple SKU reported in LPN: ' || rec_multiple_sku_casepack.license_plate_number);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check for Onhand and Packed Quantity Mismatch */
        insert_message ('LOG',
                        'Checking for Onhand and Packed Quantity Mismatch');

        FOR rec_onhand_packed_qty_mismatch IN cur_onhand_packed_qty_mismatch
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Onhand and Packed Quantity mismatch found for LPN: '
                || rec_onhand_packed_qty_mismatch.license_plate_number
                || ', SKU: '
                || rec_onhand_packed_qty_mismatch.sku
                || ', Onhand: '
                || rec_onhand_packed_qty_mismatch.onhand
                || ', Packed: '
                || rec_onhand_packed_qty_mismatch.packed_qty);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check for Onhand and Packed Quantity Mismatch */
        insert_message ('LOG',
                        'Checking for CPQ and Packed Quantity Mismatch');

        FOR rec_cpq_onhand_mismatch IN cur_cpq_onhand_mismatch
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'CPQ and Packed Quantity mismatch found for LPN: '
                || rec_cpq_onhand_mismatch.license_plate_number
                || ', SKU: '
                || rec_cpq_onhand_mismatch.sku
                || ', CPQ: '
                || rec_cpq_onhand_mismatch.CPQ
                || ', Onhand: '
                || rec_cpq_onhand_mismatch.onhand
                || ', Packed: '
                || rec_cpq_onhand_mismatch.packed_qty);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check for Onhand and Packed Location Mismatch */
        insert_message ('LOG',
                        'Checking for Onhand and Packed Location Mismatch');

        FOR rec_location_mismatch IN cur_location_mismatch
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'Onhand and Packed Location mismatch found for LPN: '
                || rec_location_mismatch.lpn
                || ', LPN Sub: '
                || rec_location_mismatch.lpn_sub
                || ', LPN Location: '
                || rec_location_mismatch.lpn_loc
                || ', Onhand Sub: '
                || rec_location_mismatch.onhand_sub
                || ', Onhand Location: '
                || rec_location_mismatch.onhand_loc);
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        /* Check for Max Inventory Transfer */
        insert_message ('LOG', 'Checking for Max allowed Inventory');

        BEGIN
            SELECT flv.tag
              INTO lv_include_free_atp
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_INCLUDE_FREE_ATP'
                   AND flv.language = 'US'
                   AND flv.lookup_code = gv_src_org
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_include_free_atp   := 'N';
                ln_free_atp           := 0;
        END;

        FOR rec_truck_items IN cur_truck_items
        LOOP
            FOR rec_item_quantities
                IN cur_item_quantities (rec_truck_items.item_number)
            LOOP
                IF lv_include_free_atp = 'Y'
                THEN
                    ln_free_atp   := rec_item_quantities.free_atp;
                ELSE
                    ln_free_atp   := 0;
                END IF;

                ln_truck_quantity   := rec_item_quantities.truck_quantity;

                ln_max_transfer_quantity   :=
                    LEAST (
                        GREATEST (
                              (rec_item_quantities.released_iso_quantity + ln_free_atp)
                            - NVL (rec_item_quantities.supply_quantity, 0),
                            0),
                        rec_item_quantities.free_atr + rec_truck_items.quantity,
                        NVL (
                              rec_item_quantities.case_quantity
                            + ln_truck_quantity,
                            0));

                IF rec_truck_items.quantity > ln_max_transfer_quantity
                THEN
                    lv_return_status   := 'E';
                    insert_message (
                        'BOTH',
                           'Quantity in location for Item: '
                        || rec_truck_items.item_number
                        || ' is: '
                        || rec_truck_items.quantity
                        || ', exceeds max transfer quantity: '
                        || ln_max_transfer_quantity);
                END IF;
            END LOOP;
        END LOOP;

        /* Added for CCR0007600 */
        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        insert_message (
            'LOG',
            'Validating the LPN length - LPN should be 20 digits');

        FOR rec_lpn_check IN c_lpn_length_check
        LOOP
            IF rec_lpn_check.LENGTH <> 20
            THEN
                lv_return_status   := 'E';
                insert_message (
                    'BOTH',
                    'LPN failed 20 digit length validation ' || rec_lpn_check.license_plate_number);
            END IF;
        END LOOP;

        insert_message (
            'LOG',
            '+---------------------------------------------------------------------------+');

        insert_message ('LOG', 'LPN and Parent LPN Validation');

        FOR rec_lpn_validation IN c_lpn_validation
        LOOP
            lv_return_status   := 'E';
            insert_message (
                'BOTH',
                   'LPN and Parent LPN Cannot have the same value '
                || rec_lpn_validation.license_plate_number);
        END LOOP;


        insert_message (
            'BOTH',
            '+-------------------------End Validation------------------------------------+');
        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');


        RETURN lv_return_status;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Unexpected error while Validating the Program :' || SQLERRM);
            lv_return_status   := 'E';
            RETURN lv_return_status;
            ROLLBACK;
    END validate_data;

    PROCEDURE onhand_insert (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2, pv_dest_locator IN VARCHAR2
                             , pv_return_status OUT VARCHAR2)
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

        ln_record_count   NUMBER;
    BEGIN
        insert_message ('LOG', 'Inside Onhand Insert Procedure');

        ln_record_count   := 0;


        FOR rec_onhand IN cur_onhand
        LOOP
            ln_record_count   := ln_record_count + 1;

            INSERT INTO XXDO.XXDO_INV_CONV_LPN_ONHAND_STG (
                            SOURCE_ORGANIZATION,
                            SOURCE_ORG_ID,
                            SOURCE_SUBINVENTORY,
                            SOURCE_LOCATOR,
                            DESTINATION_ORGANIZATION,
                            DESTINATION_ORG_ID,
                            DESTINATION_SUBINVENTORY,
                            DESTINATION_LOCATOR,
                            DOCK_DOOR,
                            ITEM_NUMBER,
                            INVENTORY_ITEM_ID,
                            ITEM_DESCRIPTION,
                            UOM,
                            ITEM_UNIT_COST,
                            LPN,
                            PALLET_LPN,
                            QUANTITY,
                            BRAND,
                            PROCESS_STATUS,
                            CREATION_DATE,
                            CREATED_BY,
                            LAST_UPDATE_DATE,
                            LAST_UPDATED_BY,
                            REQUEST_ID)
                 VALUES (rec_onhand.source_org, pn_src_org_id, rec_onhand.source_subinventory, rec_onhand.source_locator, gv_dest_org, pn_dest_org_id, pv_dest_subinv, pv_dest_locator, gv_dock_door, rec_onhand.item_number, rec_onhand.inventory_item_id, rec_onhand.description, rec_onhand.uom, rec_onhand.item_unit_cost, rec_onhand.lpn, rec_onhand.pallet_lpn, rec_onhand.quantiy, gv_brand, 'NEW', SYSDATE, gn_user_id
                         , SYSDATE, gn_user_id, gn_request_id);
        END LOOP;

        COMMIT;

        IF ln_record_count = 0
        THEN
            pv_return_status   := 'E';
            insert_message ('BOTH', 'No data found in the truck location');
        ELSE
            pv_return_status   := 'S';
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message ('LOG',
                            'Inside Exception onhand_insert: ' || SQLERRM);
    END onhand_insert;

    PROCEDURE onhand_extract (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2)
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
        insert_message ('LOG', 'Inside Onhand Extract Procedure');

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
                || rec_onhand.source_subinventory
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


    PROCEDURE create_internal_requisition (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2, pv_dest_locator IN VARCHAR2
                                           , pv_return_status OUT VARCHAR2)
    IS
        CURSOR cur_onhand IS
              SELECT moqd.inventory_item_id, msi.segment1 item_number, msi.primary_uom_code uom,
                     muc.conversion_rate cpq, SUM (moqd.transaction_quantity) quantity
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_uom_conversions muc, apps.mtl_system_items_kfv msi,
                     apps.mtl_item_locations_kfv mil
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.inventory_item_id = muc.inventory_item_id
                     AND muc.disable_date IS NULL
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
            GROUP BY moqd.inventory_item_id, muc.conversion_rate, msi.segment1,
                     msi.primary_uom_code
            ORDER BY moqd.inventory_item_id;

        CURSOR c_rcv_transactions (p_transaction_date DATE, p_item_id NUMBER)
        IS
              SELECT item_id, transaction_date, SUM (qty + corrected_qty) transaction_quantity
                FROM (SELECT rcvt.transaction_id,
                             rsl.item_id,
                             TRUNC (rcvt.transaction_date, 'month') + 14
                                 transaction_date,
                             NVL (rcvt.quantity, 0)
                                 qty,
                             (SELECT NVL (SUM (quantity), 0)
                                FROM apps.rcv_transactions rcvt1
                               WHERE     rcvt1.parent_transaction_id =
                                         rcvt.transaction_id
                                     AND rcvt1.transaction_type = 'CORRECT')
                                 corrected_qty
                        FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                       WHERE     rcvt.transaction_type = 'DELIVER'
                             AND rcvt.destination_type_code = 'INVENTORY'
                             AND rsl.source_document_code = 'PO'
                             AND TRUNC (rcvt.transaction_date) >=
                                 p_transaction_date
                             AND rsl.shipment_line_id = rcvt.shipment_line_id
                             AND rsl.item_id = p_item_id
                             AND rcvt.organization_id = pn_src_org_id) x
            GROUP BY item_id, transaction_date
              HAVING SUM (qty + corrected_qty) > 0
            ORDER BY transaction_date;

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

        ln_onhand_qty           NUMBER;
        ld_transaction_date     DATE;
        ld_need_by_date         DATE;
        ln_rcv_qty              NUMBER;
        ln_ir_line_qty          NUMBER;
        ln_locator_qty          NUMBER;
        ln_rcv_cpq_qty          NUMBER;
        ln_cpq                  NUMBER;
        ln_ir_rcv_qty           NUMBER;
        ln_remaning_qty         NUMBER;
        l_ir_qty_failed         EXCEPTION;
        ln_total_rcv_qty        NUMBER;
        ln_diff_qty             NUMBER;
        i                       NUMBER;
    BEGIN
        insert_message ('LOG', 'Create Requisitions - Process Started...');

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

        SELECT operating_unit
          INTO ln_org_id
          FROM apps.org_organization_definitions
         WHERE organization_id = pn_src_org_id;

        SELECT DECODE (TO_CHAR (SYSDATE, 'FMDAY'),  'FRIDAY', SYSDATE + 3,  'SATURDAY', SYSDATE + 2,  SYSDATE + 1)
          INTO ld_need_by_date
          FROM DUAL;


        lv_source_code   := 'NH' || '-' || gn_request_id;

        FOR rec_onhand IN cur_onhand
        LOOP
            ln_locator_qty        := rec_onhand.quantity;
            ln_cpq                := rec_onhand.cpq;

            /* Get onhand in the organization */
            ln_onhand_qty         :=
                f_get_onhand (rec_onhand.inventory_item_id, pn_src_org_id, NULL
                              , NULL);
            /* Get the receiving transaction date for the onhand*/
            ld_transaction_date   :=
                get_transaction_date (rec_onhand.inventory_item_id,
                                      pn_src_org_id,
                                      ln_onhand_qty);

            /* Get total receiving quantity from transaction date */
            BEGIN
                SELECT SUM (qty + corrected_qty) transaction_quantity
                  INTO ln_total_rcv_qty
                  FROM (SELECT NVL (rcvt.quantity, 0) qty,
                               (SELECT NVL (SUM (quantity), 0)
                                  FROM apps.rcv_transactions rcvt1
                                 WHERE     rcvt1.parent_transaction_id =
                                           rcvt.transaction_id
                                       AND rcvt1.transaction_type = 'CORRECT') corrected_qty
                          FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                         WHERE     rcvt.transaction_type = 'DELIVER'
                               AND rcvt.destination_type_code = 'INVENTORY'
                               AND rsl.source_document_code = 'PO'
                               AND TRUNC (rcvt.transaction_date) >=
                                   ld_transaction_date
                               AND rsl.shipment_line_id =
                                   rcvt.shipment_line_id
                               AND rsl.item_id = rec_onhand.inventory_item_id
                               AND rcvt.organization_id = pn_src_org_id);
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_total_rcv_qty   := ln_onhand_qty;
            END;

            i                     := 1;
            ln_remaning_qty       := ln_locator_qty;
            ln_diff_qty           := ln_total_rcv_qty - ln_onhand_qty;

            FOR r_rcv_transactions
                IN c_rcv_transactions (ld_transaction_date,
                                       rec_onhand.inventory_item_id)
            LOOP
                /* Get the quantity of the IR for the same transaction date*/
                /* Modified from attribute3 to attribute11 for CCR0007600*/
                SELECT NVL (SUM (prl.quantity), 0)
                  INTO ln_ir_rcv_qty
                  FROM apps.po_requisition_headers_all prh, apps.po_requisition_lines_all prl
                 WHERE     prh.interface_source_code LIKE 'NH%'
                       AND prh.requisition_header_id =
                           prl.requisition_header_id
                       AND prl.cancel_flag = 'N'
                       AND prl.item_id = rec_onhand.inventory_item_id
                       AND TO_DATE (prl.attribute11, 'DD-MON-YYYY') =
                           r_rcv_transactions.transaction_date
                       AND prh.segment1 NOT IN
                               (SELECT DISTINCT ooha.orig_sys_document_ref
                                  FROM apps.oe_order_headers_all ooha, apps.wsh_delivery_details wdd
                                 WHERE     ooha.orig_sys_document_ref =
                                           prh.segment1
                                       AND ooha.header_id =
                                           wdd.source_header_id
                                       AND wdd.source_code = 'OE'
                                       AND wdd.inventory_item_id =
                                           prl.item_id
                                       AND wdd.released_status = 'C');

                IF i = 1
                THEN
                    ln_rcv_qty   :=
                          r_rcv_transactions.transaction_quantity
                        - ln_ir_rcv_qty
                        - ln_diff_qty;
                    i   := i + 1;
                ELSE
                    ln_rcv_qty   :=
                          r_rcv_transactions.transaction_quantity
                        - ln_ir_rcv_qty;
                END IF;

                ln_rcv_cpq_qty   := TRUNC (ln_rcv_qty / ln_cpq) * ln_cpq;


                IF ln_remaning_qty > ln_rcv_cpq_qty AND ln_rcv_cpq_qty > 0
                THEN
                    ln_ir_line_qty    := ln_rcv_cpq_qty;
                    ln_remaning_qty   := ln_remaning_qty - ln_ir_line_qty;

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
                                    --line_attribute3, /* Commented for CCR0007600*/
                                    line_attribute11,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (lv_source_code, 'INTERNAL', ln_org_id, /* ORG_ID */
                                 'APPROVED',           -- Authorization_Status
                                             ln_ccid,            -- Valid ccid
                                                      ln_ir_line_qty, -- Quantity
                                 rec_onhand.uom,                   -- UOm Code
                                                 lv_source_code, rec_onhand.inventory_item_id, ld_need_by_date, -- neeed by date
                                                                                                                ln_person_id, -- Person id of the preparer
                                                                                                                              ln_person_id, -- Person_id of the requestor
                                                                                                                                            'INVENTORY', -- source_type_code
                                                                                                                                                         pn_src_org_id, -- Source org id - US4
                                                                                                                                                                        pv_src_subinv, --- source subinventory
                                                                                                                                                                                       'INVENTORY', -- destination_type_code
                                                                                                                                                                                                    pn_dest_org_id, -- Destination org id - US1
                                                                                                                                                                                                                    pv_dest_subinv, -- destination sub inventory
                                                                                                                                                                                                                                    ln_del_to_loc_id, TO_CHAR (r_rcv_transactions.transaction_date, 'DD-MON-YYYY'), SYSDATE
                                 , gn_user_id, SYSDATE, gn_user_id);
                ELSIF     ln_remaning_qty <= ln_rcv_cpq_qty
                      AND ln_rcv_cpq_qty > 0
                THEN
                    ln_ir_line_qty    := ln_remaning_qty;
                    ln_remaning_qty   := ln_remaning_qty - ln_ir_line_qty;

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
                                    --line_attribute3, /* Commented for CCR0007600*/
                                    line_attribute11,
                                    creation_date,
                                    created_by,
                                    last_update_date,
                                    last_updated_by)
                         VALUES (lv_source_code, 'INTERNAL', ln_org_id, /* ORG_ID */
                                 'APPROVED',           -- Authorization_Status
                                             ln_ccid,            -- Valid ccid
                                                      ln_ir_line_qty, -- Quantity
                                 rec_onhand.uom,                   -- UOm Code
                                                 lv_source_code, rec_onhand.inventory_item_id, ld_need_by_date, -- neeed by date
                                                                                                                ln_person_id, -- Person id of the preparer
                                                                                                                              ln_person_id, -- Person_id of the requestor
                                                                                                                                            'INVENTORY', -- source_type_code
                                                                                                                                                         pn_src_org_id, -- Source org id - US4
                                                                                                                                                                        pv_src_subinv, --- source subinventory
                                                                                                                                                                                       'INVENTORY', -- destination_type_code
                                                                                                                                                                                                    pn_dest_org_id, -- Destination org id - US1
                                                                                                                                                                                                                    pv_dest_subinv, -- destination sub inventory
                                                                                                                                                                                                                                    ln_del_to_loc_id, TO_CHAR (r_rcv_transactions.transaction_date, 'DD-MON-YYYY'), SYSDATE
                                 , gn_user_id, SYSDATE, gn_user_id);


                    EXIT;
                END IF;
            END LOOP;

            IF ln_remaning_qty > 0
            THEN
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
                                --line_attribute3, /* Commented for CCR0007600*/
                                line_attribute11,
                                creation_date,
                                created_by,
                                last_update_date,
                                last_updated_by)
                     VALUES (lv_source_code, 'INTERNAL', ln_org_id, /* ORG_ID */
                             'APPROVED',               -- Authorization_Status
                                         ln_ccid,                -- Valid ccid
                                                  ln_remaning_qty, -- Quantity
                             rec_onhand.uom,                       -- UOm Code
                                             lv_source_code, rec_onhand.inventory_item_id, ld_need_by_date, -- neeed by date
                                                                                                            ln_person_id, -- Person id of the preparer
                                                                                                                          ln_person_id, -- Person_id of the requestor
                                                                                                                                        'INVENTORY', -- source_type_code
                                                                                                                                                     pn_src_org_id, -- Source org id - US4
                                                                                                                                                                    pv_src_subinv, --- source subinventory
                                                                                                                                                                                   'INVENTORY', -- destination_type_code
                                                                                                                                                                                                pn_dest_org_id, -- Destination org id - US1
                                                                                                                                                                                                                pv_dest_subinv, -- destination sub inventory
                                                                                                                                                                                                                                ln_del_to_loc_id, TRUNC (SYSDATE - 30, 'month') + 14, SYSDATE
                             , gn_user_id, SYSDATE, gn_user_id);
            END IF;
        END LOOP;

        COMMIT;

        insert_message (
            'LOG',
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

        insert_message ('LOG',
                        'Requisition Request Id :' || ln_req_request_id);

        IF ln_req_request_id <> 0
        THEN
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF     UPPER (lv_chr_dev_phase) = 'COMPLETE'
               AND UPPER (lv_chr_status) = 'NORMAL'
            THEN
                BEGIN
                    SELECT segment1
                      INTO lv_requisition_number
                      FROM apps.po_requisition_headers_all
                     WHERE interface_source_code = lv_source_code;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        insert_message (
                            'LOG',
                            'Unable to find requisituon number, search manually');
                        lv_requisition_number   := NULL;
                END;

                pv_return_status   := 'S';
            END IF;
        END IF;

        IF lv_requisition_number IS NOT NULL
        THEN
            gv_requisition_number   := lv_requisition_number;
            insert_message ('BOTH',
                            'Requisition number: ' || lv_requisition_number);

            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET INTERNAL_REQUISITION   = lv_requisition_number
             WHERE REQUEST_ID = gn_request_id;

            COMMIT;
        END IF;


        insert_message ('LOG', 'Create Requisitions - Process Ended');
    EXCEPTION
        WHEN l_ir_qty_failed
        THEN
            UPDATE xxdo.xxdo_inv_conv_lpn_onhand_stg
               SET process_status   = 'ERROR'
             WHERE request_id = gn_request_id;

            COMMIT;

            pv_return_status   := 'E';
            insert_message (
                'BOTH',
                'Error while creating Internal Requisition, Contact IT for support');
        WHEN OTHERS
        THEN
            pv_return_status   := 'E';
            ROLLBACK;
            insert_message (
                'BOTH',
                'Unexpected error while creating requisitions :' || SQLERRM);
    END create_internal_requisition;

    PROCEDURE pick_release_main (pv_errbuf    OUT VARCHAR2,
                                 pv_retcode   OUT VARCHAR2)
    IS
        CURSOR cur_iso_details IS
            SELECT DISTINCT source_org_id, internal_order, source_subinventory,
                            source_locator, dock_door
              FROM XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
             WHERE process_status = 'NEW';

        lv_errbuf    VARCHAR2 (1000);
        lv_retcode   VARCHAR2 (1000);
    BEGIN
        FOR rec_iso_details IN cur_iso_details
        LOOP
            pick_release_iso (lv_errbuf, lv_retcode, rec_iso_details.source_org_id, rec_iso_details.internal_order, rec_iso_details.source_subinventory, rec_iso_details.source_locator
                              , rec_iso_details.dock_door);
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Inside Pick Release Main Exception: ' || SQLERRM);
    END pick_release_main;

    PROCEDURE pick_release_iso (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_org IN VARCHAR2, pv_iso_num IN VARCHAR2, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2
                                , pv_dock_door IN VARCHAR2)
    IS
        i                    NUMBER;
        ln_user_id           NUMBER;
        ln_resp_id           NUMBER;
        ln_appl_id           NUMBER;
        ln_unschedule_cnt    NUMBER;
        lv_commit            VARCHAR2 (30);
        ln_delivery_id       NUMBER;
        ln_org_id            NUMBER;
        ln_from_locator_id   NUMBER;
        ln_batch_prefix      VARCHAR2 (10);
        x_msg_details        VARCHAR2 (3000);
        x_msg_summary        VARCHAR2 (3000);
        ln_msg_count         NUMBER;
        lv_msg_data          VARCHAR2 (2000);
        lv_return_status     VARCHAR2 (1);
        lv_proceed_flag      VARCHAR2 (1);
        ln_new_batch_id      NUMBER;
        ln_count             NUMBER;
        ln_request_id        NUMBER;
        ln_order_type_id     NUMBER;
        lb_bol_result        BOOLEAN;
        lv_chr_phase         VARCHAR2 (250) := NULL;
        lv_chr_status        VARCHAR2 (250) := NULL;
        lv_chr_dev_phase     VARCHAR2 (250) := NULL;
        lv_chr_dev_status    VARCHAR2 (250) := NULL;
        lv_chr_message       VARCHAR2 (250) := NULL;
        p_line_rows          wsh_util_core.id_tab_type;
        l_batch_info_rec     WSH_PICKING_BATCHES_PUB.BATCH_INFO_REC;
        x_del_rows           wsh_util_core.id_tab_type;

        CURSOR c_ord_details IS
            SELECT wdd.delivery_detail_id, oha.org_id, oha.order_type_id
              FROM apps.oe_order_headers_all oha, apps.oe_order_lines_all ola, apps.wsh_delivery_details wdd
             WHERE     oha.header_id = ola.header_id
                   AND oha.org_id = ola.org_id
                   AND oha.header_id = wdd.source_header_id
                   AND ola.line_id = wdd.source_line_id
                   AND oha.booked_flag = 'Y'
                   AND NVL (ola.cancelled_flag, 'N') <> 'Y'
                   AND wdd.released_status IN ('R', 'B')
                   AND wdd.source_code = 'OE'
                   AND ola.flow_status_code = 'AWAITING_SHIPPING'
                   AND oha.order_number = pv_iso_num;
    BEGIN
        insert_message ('LOG', 'ISO Number: ' || pv_iso_num);
        insert_message ('LOG', 'Organization: ' || pv_org);
        insert_message ('LOG', 'Source Subinventory: ' || pv_src_subinv);
        insert_message ('LOG', 'Source Locator: ' || pv_src_locator);
        insert_message ('LOG', 'Dock Door: ' || pv_dock_door);

        SELECT responsibility_id, application_id
          INTO ln_resp_id, ln_appl_id
          FROM fnd_responsibility_vl
         WHERE responsibility_name = 'Order Management Super User';

        lv_proceed_flag   := 'Y';

        ln_org_id         := pv_org;

        BEGIN
            SELECT inventory_location_id
              INTO ln_from_locator_id
              FROM mtl_item_locations_kfv
             WHERE     concatenated_segments = pv_src_locator
                   AND organization_id = ln_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_proceed_flag      := 'N';
                ln_from_locator_id   := NULL;
                insert_message ('LOG', 'Unable to fetch from location');
        END;

        SELECT COUNT (1)
          INTO ln_unschedule_cnt
          FROM apps.oe_order_lines_all oola, apps.oe_order_headers_all ooha
         WHERE     ooha.order_number = pv_iso_num
               AND ooha.header_id = oola.header_id
               AND (schedule_ship_date IS NULL OR schedule_status_code IS NULL)
               AND NVL (oola.open_flag, 'N') = 'Y'
               AND NVL (oola.cancelled_flag, 'N') = 'N'
               AND oola.line_category_code = 'ORDER'
               AND oola.flow_status_code = 'AWAITING_SHIPPING';

        SELECT ooha.order_type_id
          INTO ln_order_type_id
          FROM apps.oe_order_headers_all ooha
         WHERE ooha.order_number = pv_iso_num;

        IF ln_unschedule_cnt <> 0 AND lv_proceed_flag <> 'Y'
        THEN
            lv_proceed_flag   := 'N';
            insert_message (
                'LOG',
                'Order: ' || pv_iso_num || ', is not yet scheduled completly');

            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET attribute1   = 'Order is not yet scheduled completly'
             WHERE internal_order = pv_iso_num;

            COMMIT;
        ELSE
            update_location_status (ln_org_id, pv_src_locator, 1);

            fnd_global.apps_initialize (gn_user_id, ln_resp_id, ln_appl_id);
            lv_return_status                              := wsh_util_core.g_ret_sts_success;

            l_batch_info_rec                              := NULL;

            l_batch_info_rec.order_number                 := pv_iso_num;
            l_batch_info_rec.order_type_id                := ln_order_type_id;
            l_batch_info_rec.Autodetail_Pr_Flag           := 'Y';
            l_batch_info_rec.organization_id              := ln_org_id;
            l_batch_info_rec.autocreate_delivery_flag     := 'Y';
            l_batch_info_rec.Backorders_Only_Flag         := 'I';
            l_batch_info_rec.allocation_method            := 'I';
            l_batch_info_rec.auto_pick_confirm_flag       := 'N';
            l_batch_info_rec.autopack_flag                := 'N';
            l_batch_info_rec.append_flag                  := 'N';
            l_batch_info_rec.Pick_From_Subinventory       := pv_src_subinv;
            l_batch_info_rec.pick_from_locator_id         := ln_from_locator_id;
            l_batch_info_rec.Default_Stage_Subinventory   := 'STAGE';
            l_batch_info_rec.Default_Stage_Locator_Id     := NULL;
            ln_batch_prefix                               := NULL;
            ln_new_batch_id                               := NULL;

            WSH_PICKING_BATCHES_PUB.CREATE_BATCH (
                p_api_version     => 1.0,
                p_init_msg_list   => fnd_api.g_true,
                p_commit          => fnd_api.g_true,
                x_return_status   => lv_return_status,
                x_msg_count       => ln_msg_count,
                x_msg_data        => lv_msg_data,
                p_rule_id         => NULL,
                p_rule_name       => NULL,
                p_batch_rec       => l_batch_info_rec,
                p_batch_prefix    => ln_batch_prefix,
                x_batch_id        => ln_new_batch_id);

            IF lv_return_status <> 'S'
            THEN
                lv_proceed_flag   := 'N';
                insert_message ('LOG', 'Message count ' || ln_msg_count);

                IF ln_msg_count = 1
                THEN
                    insert_message ('LOG', 'lv_msg_data ' || lv_msg_data);
                ELSIF ln_msg_count > 1
                THEN
                    LOOP
                        ln_count   := ln_count + 1;
                        lv_msg_data   :=
                            FND_MSG_PUB.Get (FND_MSG_PUB.G_NEXT,
                                             FND_API.G_FALSE);

                        IF lv_msg_data IS NULL
                        THEN
                            EXIT;
                        END IF;

                        insert_message (
                            'LOG',
                            'Message' || ln_count || '---' || lv_msg_data);
                    END LOOP;
                END IF;
            ELSE                                            /* create batch */
                insert_message (
                    'LOG',
                       'Pick Release Batch Got Created Sucessfully, '
                    || ln_new_batch_id);

                -- Release the batch Created Above
                WSH_PICKING_BATCHES_PUB.RELEASE_BATCH (
                    P_API_VERSION     => 1.0,
                    P_INIT_MSG_LIST   => fnd_api.g_true,
                    P_COMMIT          => fnd_api.g_true,
                    X_RETURN_STATUS   => lv_return_status,
                    X_MSG_COUNT       => ln_msg_count,
                    X_MSG_DATA        => lv_msg_data,
                    P_BATCH_ID        => ln_new_batch_id,
                    P_BATCH_NAME      => NULL,
                    P_LOG_LEVEL       => 1,
                    P_RELEASE_MODE    => 'CONCURRENT', -- (ONLINE or CONCURRENT)
                    X_REQUEST_ID      => ln_request_id);

                insert_message (
                    'LOG',
                    'Pick Selection List Generation ' || ln_request_id);

                IF ln_request_id <> 0
                THEN
                    lb_bol_result   :=
                        fnd_concurrent.wait_for_request (ln_request_id,
                                                         15,
                                                         0,
                                                         lv_chr_phase,
                                                         lv_chr_status,
                                                         lv_chr_dev_phase,
                                                         lv_chr_dev_status,
                                                         lv_chr_message);
                END IF;

                insert_message ('LOG', 'lv_chr_status: ' || lv_chr_status);

                IF lv_chr_dev_phase = 'COMPLETE' AND lv_chr_status = 'Normal'
                THEN
                    insert_message ('LOG',
                                    'Pick Release completed successfully');
                ELSE                                       /* release batch */
                    lv_proceed_flag   := 'N';
                    insert_message (
                        'LOG',
                           'Pick Release completed with status: '
                        || lv_chr_status);
                    insert_message ('LOG', 'Message count ' || ln_msg_count);

                    IF ln_msg_count = 1
                    THEN
                        insert_message ('LOG', 'lv_msg_data ' || lv_msg_data);
                    ELSIF ln_msg_count > 1
                    THEN
                        LOOP
                            ln_count   := ln_count + 1;
                            lv_msg_data   :=
                                FND_MSG_PUB.Get (FND_MSG_PUB.G_NEXT,
                                                 FND_API.G_FALSE);

                            IF lv_msg_data IS NULL
                            THEN
                                EXIT;
                            END IF;
                        END LOOP;

                        insert_message (
                            'LOG',
                            'Message' || ln_count || '---' || lv_msg_data);
                    END IF;
                END IF;
            END IF;

            --END IF;


            IF lv_proceed_flag = 'Y'
            THEN
                pick_confirm_order (pv_iso_num, ln_org_id, pv_dock_door,
                                    lv_return_status);

                IF lv_return_status = 'S'
                THEN
                    update_location_status (ln_org_id, pv_src_locator, 21);

                    UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
                       SET process_status   = 'COMPLETE'
                     WHERE internal_order = pv_iso_num;

                    COMMIT;
                ELSE
                    UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
                       SET attribute1 = 'Exception during pick confirm process, refer logs'
                     WHERE internal_order = pv_iso_num;

                    COMMIT;
                END IF;
            ELSE
                UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
                   SET attribute1 = 'Exception during pick release process, refer logs'
                 WHERE internal_order = pv_iso_num;

                COMMIT;
            END IF;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Unexpected error while pick release of ISO :' || SQLERRM);
            ROLLBACK;
    END pick_release_iso;

    PROCEDURE pick_confirm_order (pv_iso_num IN VARCHAR2, pn_org_id IN NUMBER, pv_dock_door IN VARCHAR2
                                  , pv_return_status OUT VARCHAR2)
    IS
        CURSOR c_move_header (p_order_number VARCHAR2)
        IS
              SELECT DISTINCT mtrh.header_id, mtrh.organization_id
                FROM apps.oe_order_headers_all ooh, apps.oe_order_lines_all ool, apps.mtl_txn_request_lines mtrl,
                     apps.mtl_txn_request_headers mtrh, apps.fnd_user fu, apps.mtl_material_transactions_temp mmtt
               WHERE     ooh.order_number = p_order_number
                     AND ooh.header_id = ool.header_id
                     AND ool.line_id = mtrl.txn_source_line_id
                     AND ool.ship_from_org_id = mtrl.organization_id
                     AND mtrl.header_id = mtrh.header_id
                     AND mtrh.created_by = fu.user_id
                     AND mtrl.line_status = 7
                     AND mmtt.move_order_line_id = mtrl.line_id
                     AND mmtt.organization_id = mtrl.organization_id
                     AND mmtt.transaction_temp_id IS NOT NULL
            ORDER BY mtrh.header_id;

        CURSOR c_task_detail (p_move_header_id NUMBER)
        IS
              SELECT mmtt.transaction_temp_id task_id, mmtt.inventory_item_id, mmtt.subinventory_code,
                     apps.lid_to_loc (mmtt.locator_id, mmtt.organization_id) pick_from_location, mmtt.locator_id, mmtt.transaction_quantity quantity,
                     muc.conversion_rate cpq, msib.primary_uom_code
                FROM apps.mtl_txn_request_lines mtrl, apps.mtl_txn_request_headers mtrh, apps.mtl_material_transactions_temp mmtt,
                     apps.mtl_uom_conversions muc, apps.mtl_system_items_b msib
               WHERE     mtrh.header_id = p_move_header_id
                     AND mtrl.header_id = mtrh.header_id
                     AND mtrl.line_status = 7
                     AND mmtt.move_order_line_id = mtrl.line_id
                     AND mmtt.organization_id = mtrl.organization_id
                     AND mmtt.transaction_temp_id IS NOT NULL
                     AND muc.inventory_item_id = mmtt.inventory_item_id
                     AND msib.inventory_item_id = mmtt.inventory_item_id
                     AND msib.organization_id = mmtt.organization_id
                     AND muc.disable_date IS NULL
            ORDER BY mtrh.header_id;


        CURSOR c_lpn_details (p_item_id NUMBER, p_sub_code VARCHAR2, p_locator_id NUMBER
                              , p_lpn_count NUMBER)
        IS
            SELECT case_lpn, quantity
              FROM (  SELECT DISTINCT wlpn.license_plate_number case_lpn, SUM (moqd.primary_transaction_quantity) quantity
                        FROM apps.wms_license_plate_numbers wlpn, apps.mtl_onhand_quantities_detail moqd
                       WHERE     moqd.inventory_item_id = p_item_id
                             AND moqd.subinventory_code = p_sub_code
                             AND moqd.locator_id = p_locator_id
                             AND moqd.lpn_id = wlpn.lpn_id
                             AND moqd.subinventory_code =
                                 wlpn.subinventory_code
                             AND moqd.locator_id = wlpn.locator_id
                             AND wlpn.lpn_context = 1
                    GROUP BY wlpn.license_plate_number, moqd.inventory_item_id)
             WHERE ROWNUM <= p_lpn_count;

        CURSOR c_parent_lpn_details (p_sub_code     VARCHAR2,
                                     p_locator_id   NUMBER)
        IS
            SELECT DISTINCT wlpn.lpn_id lpn_id, wlpn.license_plate_number lpn, wlpn_parent.lpn_id parent_lpn_id,
                            wlpn_parent.license_plate_number pallet_lpn, wlpn.organization_id
              FROM apps.wms_license_plate_numbers wlpn, apps.mtl_onhand_quantities_detail moqd, apps.wms_license_plate_numbers wlpn_parent
             WHERE     moqd.subinventory_code = p_sub_code
                   AND moqd.locator_id = p_locator_id
                   AND moqd.lpn_id = wlpn.lpn_id
                   AND moqd.subinventory_code = wlpn.subinventory_code
                   AND moqd.locator_id = wlpn.locator_id
                   AND wlpn_parent.lpn_id = wlpn.parent_lpn_id
                   AND wlpn.parent_lpn_id IS NOT NULL;

        ln_user_id               NUMBER;
        ln_resp_id               NUMBER;
        ln_appl_id               NUMBER;
        ln_case_count            NUMBER;
        lv_ret_stat              VARCHAR (20);
        lv_message               VARCHAR (1000);
        lv_loc_empty             VARCHAR (10);
        lv_return_status         VARCHAR2 (10);
        lv_msg_data              VARCHAR2 (1000);
        ln_msg_count             NUMBER;
        ln_msg_index_out         NUMBER;
        ln_uom_conversion_rate   NUMBER;
    BEGIN
        ln_user_id         := gn_user_id;

        lv_return_status   := 'S';

        SELECT responsibility_id, application_id
          INTO ln_resp_id, ln_appl_id
          FROM apps.fnd_responsibility_tl frt
         WHERE responsibility_name = 'Warehouse Manager' AND language = 'US';

        --apps.do_apps_initialize (ln_user_id, ln_resp_id, ln_appl_id);

        FND_PROFILE.put ('MFG_ORGANIZATION_ID', pn_org_id);

        FOR r_move_order IN c_move_header (pv_iso_num)
        LOOP
            insert_message ('LOG', 'Wave Id=' || r_move_order.header_id);

            FOR r_task_detail IN c_task_detail (r_move_order.header_id)
            LOOP
                insert_message (
                    'LOG',
                       'Task_id='
                    || r_task_detail.task_id
                    || ', item_id='
                    || r_task_detail.inventory_item_id
                    || ', loc='
                    || r_task_detail.pick_from_location
                    || ', subinv='
                    || r_task_detail.subinventory_code
                    || ', qty='
                    || r_task_detail.quantity);

                IF r_task_detail.primary_uom_code = 'EA'
                THEN
                    BEGIN
                        SELECT conversion_rate
                          INTO ln_uom_conversion_rate
                          FROM APPS.MTL_UOM_CONVERSIONS
                         WHERE     inventory_item_id = 0
                               AND uom_code = r_task_detail.primary_uom_code
                               AND disable_date IS NULL;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            ln_uom_conversion_rate   := 1;
                    END;
                ELSE
                    ln_uom_conversion_rate   := 1;
                END IF;

                ln_case_count   :=
                      (r_task_detail.quantity * ln_uom_conversion_rate)
                    / r_task_detail.cpq;

                insert_message ('LOG', ' No.of Cases :' || ln_case_count);


                FOR rec_parent_lpn_details
                    IN c_parent_lpn_details (r_task_detail.subinventory_code,
                                             r_task_detail.locator_id)
                LOOP
                    wms_container_pub.PackUnpack_Container (
                        p_api_version       => 1.0,
                        x_return_status     => lv_return_status,
                        x_msg_count         => ln_msg_count,
                        x_msg_data          => lv_msg_data,
                        p_lpn_id            =>
                            rec_parent_lpn_details.parent_lpn_id,
                        p_content_lpn_id    => rec_parent_lpn_details.lpn_id,
                        p_organization_id   =>
                            rec_parent_lpn_details.organization_id,
                        p_operation         => 2,           /* 2 for Unpack */
                        p_unpack_all        => 2         /* dont unpack all */
                                                );


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

                        lv_return_status   := 'E';

                        insert_message (
                            'LOG',
                            'Error While Unpacking LPN from Parent LPN');
                        insert_message (
                            'LOG',
                            'Parent LPN: ' || rec_parent_lpn_details.pallet_lpn);
                        insert_message (
                            'LOG',
                            'LPN: ' || rec_parent_lpn_details.lpn);
                        insert_message ('LOG', 'ERROR: ' || lv_msg_data);
                        ROLLBACK;
                    END IF;
                END LOOP;

                FOR r_lpn_details IN c_lpn_details (r_task_detail.inventory_item_id, r_task_detail.subinventory_code, r_task_detail.locator_id
                                                    , ln_case_count)
                LOOP
                    insert_message (
                        'LOG',
                           'CASE pick, CPQ='
                        || r_task_detail.cpq
                        || ', LPN='
                        || r_lpn_details.case_lpn
                        || ',case_qty='
                        || r_lpn_details.quantity);

                    apps.do_wms_wcs_interface.wcs_pick_load (
                        r_task_detail.task_id,
                        TO_CHAR (r_task_detail.inventory_item_id),
                        r_task_detail.pick_from_location,
                        r_lpn_details.quantity,
                        r_lpn_details.case_lpn,
                        ln_user_id,
                        SYSDATE,
                        NULL,
                        lv_ret_stat,
                        lv_message,
                        lv_loc_empty);

                    IF lv_ret_stat <> 'S'
                    THEN
                        ROLLBACK;

                        insert_message (
                            'LOG',
                               'Error while pick loading the LPN: '
                            || lv_message);
                        lv_return_status   := 'E';
                    ELSE
                        drop_loaded_lpn (pv_dock_door, r_move_order.organization_id, r_lpn_details.case_lpn
                                         , lv_ret_stat, lv_message);

                        IF lv_ret_stat <> 'S'
                        THEN
                            ROLLBACK;
                            insert_message (
                                'LOG',
                                   'Error while pick droping the LPN: '
                                || lv_message);
                            lv_return_status   := 'E';
                        ELSE
                            insert_message (
                                'LOG',
                                'LPN is successfully dropped and loaded to dock door');
                        END IF;
                    END IF;
                END LOOP;
            END LOOP;
        END LOOP;

        pv_return_status   := lv_return_status;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Inside Pick Confirm Order Exception: ' || SQLERRM);
    END pick_confirm_order;

    PROCEDURE drop_loaded_lpn (pv_dock_door         IN     VARCHAR2,
                               pn_organization_id   IN     NUMBER,
                               pv_lpn               IN     VARCHAR2,
                               x_ret_stat              OUT VARCHAR2,
                               x_message               OUT VARCHAR2)
    IS
        ln_trx_type_id1          NUMBER;
        ln_trx_type_id2          NUMBER;
        ln_trx_type_id3          NUMBER;
        lv_org_code              VARCHAR2 (10);
        ln_dock_door_id          NUMBER;
        l_lpn                    apps.wms_license_plate_numbers%ROWTYPE;
        ln_cnt                   NUMBER;
        ln_temp                  NUMBER;
        ln_mmtt_records          NUMBER;
        l_task                   apps.mtl_material_transactions_temp%ROWTYPE;
        ln_msg_count             NUMBER;

        g_ret_success   CONSTANT VARCHAR2 (1)
                                     := APPS.FND_API.G_RET_STS_SUCCESS ;
        G_RET_ERROR     CONSTANT VARCHAR2 (1) := APPS.FND_API.G_RET_STS_ERROR;

        l_error_code             NUMBER;
        l_outermost_lpn          VARCHAR2 (240);
        l_outermost_lpn_id       NUMBER;
        l_parent_lpn_id          NUMBER;
        l_parent_lpn             VARCHAR2 (240);
        l_inventory_item_id      NUMBER;
        l_quantity               NUMBER;
        l_requested_quantity     NUMBER;
        l_delivery_detail_id     NUMBER;
        l_transaction_temp_id    NUMBER;
        l_item_name              VARCHAR2 (240);
        l_subinventory_code      VARCHAR2 (240);
        l_revision               VARCHAR2 (240);
        l_locator_id             NUMBER;
        l_lot_number             VARCHAR2 (240);
        l_loaded_dock_door       VARCHAR2 (240);
        l_delivery_name          VARCHAR2 (240);
        l_trip_name              VARCHAR2 (240);
        l_delivery_detail_ids    VARCHAR2 (240);
    BEGIN
        SELECT transaction_type_id
          INTO ln_trx_type_id1
          FROM mtl_transaction_types
         WHERE transaction_type_name = 'Sales Order Pick';

        SELECT transaction_type_id
          INTO ln_trx_type_id2
          FROM mtl_transaction_types
         WHERE transaction_type_name = 'Internal Order Pick';

        SELECT organization_code
          INTO lv_org_code
          FROM mtl_parameters
         WHERE organization_id = pn_organization_id;

        SELECT inventory_location_id
          INTO ln_dock_door_id
          FROM mtl_item_locations_kfv mil
         WHERE     organization_id = pn_organization_id
               AND concatenated_segments = pv_dock_door;

        x_ret_stat   := 'S';
        x_message    := 'No additional information provided';

        BEGIN
            SELECT *
              INTO l_lpn
              FROM wms_license_plate_numbers
             WHERE license_plate_number = pv_lpn;
        EXCEPTION
            WHEN OTHERS
            THEN
                x_message    :=
                       'LPN ('
                    || pv_lpn
                    || ') does not exist in organization ('
                    || lv_org_code
                    || ')';
                x_ret_stat   := g_ret_error;
                insert_message ('LOG', x_message);
                RETURN;
        END;

        /* Check whether LPN is already issued out */
        BEGIN
            SELECT transaction_type_id
              INTO ln_trx_type_id3
              FROM mtl_transaction_types
             WHERE transaction_type_name = 'Sales order issue';

            SELECT COUNT (*)
              INTO ln_cnt
              FROM mtl_material_transactions mmt, wms_license_plate_numbers wlpn, wsh_delivery_details wdd_cont,
                   wsh_delivery_assignments wda, wsh_delivery_details wdd
             WHERE     wlpn.license_plate_number = pv_lpn
                   AND mmt.organization_id = wlpn.organization_id
                   AND mmt.transaction_type_id = ln_trx_type_id3
                   AND mmt.transaction_action_id = 1
                   AND mmt.source_code = 'ORDER ENTRY'
                   AND mmt.transaction_source_type_id = 2
                   AND wdd_cont.container_name = wlpn.license_plate_number
                   AND wda.parent_delivery_detail_id =
                       wdd_cont.delivery_detail_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id
                   AND mmt.trx_source_line_id = wdd.source_line_id
                   AND wlpn.lpn_id IN
                           (mmt.lpn_id, mmt.transfer_lpn_id, mmt.content_lpn_id);

            IF ln_cnt > 0
            THEN
                x_message    := NULL;
                x_ret_stat   := g_ret_success;
                insert_message (
                    'LOG',
                    'The LPN is already shipped.  No need to continue.');
                RETURN;
            END IF;
        END;

        /* Check whether LPN is already loaded to Dock */
        BEGIN
            SELECT COUNT (*)
              INTO ln_temp
              FROM wms_shipping_transaction_temp
             WHERE     pv_lpn IN (parent_lpn, outermost_lpn)
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM mtl_material_transactions_temp
                             WHERE l_lpn.lpn_id IN (lpn_id, transfer_lpn_id));

            IF ln_temp > 0
            THEN
                x_message    := NULL;
                x_ret_stat   := g_ret_success;
                insert_message (
                    'LOG',
                    'The LPN is already loaded to a door.  No need to continue.');
                RETURN;
            END IF;
        END;

        SELECT *
          INTO l_lpn
          FROM wms_license_plate_numbers
         WHERE license_plate_number = pv_lpn;

        SELECT COUNT (*)
          INTO ln_mmtt_records
          FROM mtl_material_transactions_temp
         WHERE     l_lpn.lpn_id IN (lpn_id, content_lpn_id, transfer_lpn_id)
               AND transaction_type_id IN (ln_trx_type_id1, ln_trx_type_id2);

        IF ln_mmtt_records > 0
        THEN
            insert_message ('LOG', 'Item Drop');

            UPDATE wms_license_plate_numbers
               SET lpn_context   = 8
             WHERE lpn_id = l_lpn.lpn_id;

            FOR rec
                IN (SELECT transaction_temp_id
                      FROM mtl_material_transactions_temp
                     WHERE     l_lpn.lpn_id IN
                                   (lpn_id, transfer_lpn_id, content_lpn_id)
                           AND transaction_type_id IN
                                   (ln_trx_type_id1, ln_trx_type_id2))
            LOOP
                SELECT *
                  INTO l_task
                  FROM mtl_material_transactions_temp
                 WHERE transaction_temp_id = rec.transaction_temp_id;

                drop_lpn (
                    pn_organization_id     => pn_organization_id,
                    pn_lpn_id              => l_lpn.lpn_id,
                    pn_inventory_item_id   => l_task.inventory_item_id,
                    pv_subinventory_code   => l_task.transfer_subinventory,
                    pn_locator             => l_task.transfer_to_location,
                    x_ret_stat             => x_ret_stat,
                    x_msg_count            => ln_msg_count,
                    x_msg_data             => x_message);



                IF NVL (x_ret_stat, fnd_api.g_ret_sts_error) !=
                   fnd_api.g_ret_sts_success
                THEN
                    x_message    := 'drop_lpn failed.  ' || x_message;
                    x_ret_stat   := g_ret_error;
                    insert_message ('LOG', x_message);
                    ROLLBACK;
                    RETURN;
                END IF;
            END LOOP;
        END IF;

        IF ln_dock_door_id IS NOT NULL
        THEN
            wms_shipping_transaction_pub.lpn_submit (
                p_outermost_lpn_id      => l_lpn.lpn_id,
                p_trip_id               => 0,
                p_organization_id       => pn_organization_id,
                p_dock_door_id          => ln_dock_door_id,
                x_error_code            => l_error_code,
                x_outermost_lpn         => l_outermost_lpn,
                x_outermost_lpn_id      => l_outermost_lpn_id,
                x_parent_lpn_id         => l_parent_lpn_id,
                x_parent_lpn            => l_parent_lpn,
                x_inventory_item_id     => l_inventory_item_id,
                x_quantity              => l_quantity,
                x_requested_quantity    => l_requested_quantity,
                x_delivery_detail_id    => l_delivery_detail_id,
                x_transaction_temp_id   => l_transaction_temp_id,
                x_item_name             => l_item_name,
                x_subinventory_code     => l_subinventory_code,
                x_revision              => l_revision,
                x_locator_id            => l_locator_id,
                x_lot_number            => l_lot_number,
                x_loaded_dock_door      => l_loaded_dock_door,
                x_delivery_name         => l_delivery_name,
                x_trip_name             => l_trip_name,
                x_delivery_detail_ids   => l_delivery_detail_ids);


            IF l_error_code NOT IN (0, 1)
            THEN
                x_message    :=
                       'wms_shipping_transaction_pub.lpn_submit returned error ('
                    || l_error_code
                    || ')while loading lpn '
                    || pv_lpn
                    || ' to a dock door';

                IF l_error_code = 2
                THEN
                    x_message   := '; LPN status is incorrect';
                ELSIF l_error_code = 3
                THEN
                    x_message   := '; Unable to populate shipment table';
                ELSIF l_error_code = 5
                THEN
                    x_message   :=
                        '; LPN on the same delivery were loaded to a different dock door';
                ELSIF l_error_code = 6
                THEN
                    x_message   :=
                        '; LPN on the same delivery were loaded to a different dock door';
                ELSIF l_error_code = 7
                THEN
                    x_message   :=
                        '; Outermost LPN contains multiple deliveries';
                ELSIF l_error_code = 8
                THEN
                    x_message   :=
                        '; LPN on the same delivery were loaded by another ship method';
                ELSIF l_error_code = 9
                THEN
                    x_message   := '; delivery line is on credit-check hold';
                ELSIF l_error_code = 4
                THEN
                    x_message   := '; Nested serial check failure.';
                ELSE
                    x_message   := '; Undocumented error occured';
                END IF;

                x_ret_stat   := g_ret_error;
                insert_message ('LOG', x_message);
                RETURN;
            ELSE
                IF l_error_code = 1
                THEN
                    x_message   :=
                           'LPN ('
                        || pv_lpn
                        || ') was previously loaded to a dock door';
                END IF;

                UPDATE wms_license_plate_numbers
                   SET lpn_context   = 9
                 WHERE lpn_id = l_lpn.lpn_id;

                x_ret_stat   := g_ret_success;
            END IF;
        END IF;

        x_ret_stat   := g_ret_success;
        x_message    := NULL;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_message    := x_message || ' Unhandled exception: ' || SQLERRM;
            insert_message ('LOG', x_message);
            x_ret_stat   := G_RET_ERROR;
            RETURN;
    END drop_loaded_lpn;

    PROCEDURE drop_lpn (pn_organization_id     IN            NUMBER,
                        pn_lpn_id              IN            NUMBER,
                        pn_inventory_item_id   IN            NUMBER,
                        pv_subinventory_code   IN            VARCHAR2,
                        pn_locator             IN            NUMBER,
                        x_ret_stat                OUT        VARCHAR2,
                        x_msg_count               OUT NOCOPY NUMBER,
                        x_msg_data                OUT NOCOPY VARCHAR2)
    IS
        l_txn_header_id           NUMBER := NULL;
        l_organization_id         NUMBER
            := NVL (
                   pn_organization_id,
                   TO_NUMBER (
                       apps.do_get_profile_value ('MFG_ORGANIZATION_ID')));
        l_return_status           VARCHAR2 (1) := NULL;
        l_msg_count               NUMBER := NULL;
        l_msg_data                VARCHAR2 (32000) := NULL;
        l_from_lpn_id             NUMBER := pn_lpn_id;
        l_drop_lpn                VARCHAR2 (240) := NULL;
        l_loc_reason_id           NUMBER := 0;
        l_user_id                 NUMBER := fnd_global.user_id;
        l_task_type               NUMBER := 1;
        l_commit                  VARCHAR2 (1) := 'Y';
        v_message                 VARCHAR2 (2000);
        l_next_msg                NUMBER;
        l_ret_stat_holder         VARCHAR2 (2000);
        l_transaction_source_id   NUMBER;
        l_inventory_item_id       NUMBER;
        l_transaction_temp_id     NUMBER;
        ln_trx_type_id1           NUMBER;
        ln_trx_type_id2           NUMBER;
    BEGIN
        x_ret_stat   := 'S';
        x_msg_data   := 'No Additional Information Provided';

        SELECT employee_id
          INTO l_user_id
          FROM fnd_user
         WHERE user_id = fnd_global.user_id;

        SELECT transaction_type_id
          INTO ln_trx_type_id1
          FROM mtl_transaction_types
         WHERE transaction_type_name = 'Sales Order Pick';

        SELECT transaction_type_id
          INTO ln_trx_type_id2
          FROM mtl_transaction_types
         WHERE transaction_type_name = 'Internal Order Pick';

        SELECT MIN (transaction_source_id), MIN (inventory_item_id), MIN (transaction_temp_id)
          INTO l_transaction_source_id, l_inventory_item_id, l_transaction_temp_id
          FROM mtl_material_transactions_temp
         WHERE     organization_id = l_organization_id
               AND transfer_lpn_id = pn_lpn_id
               AND transaction_type_id IN (ln_trx_type_id1, ln_trx_type_id2)
               AND inventory_item_id =
                   NVL (pn_inventory_item_id, inventory_item_id);

        SELECT mtl_material_transactions_s.NEXTVAL
          INTO l_txn_header_id
          FROM DUAL;

        UPDATE mtl_material_transactions_temp
           SET transaction_batch_id = l_txn_header_id, transaction_batch_seq = transaction_temp_id, transaction_header_id = l_txn_header_id,
               transaction_status = 1, transfer_subinventory = pv_subinventory_code, transfer_to_location = pn_locator
         WHERE transaction_temp_id = l_transaction_temp_id;



        wms_task_dispatch_gen.pick_drop (p_temp_id => l_transaction_temp_id, p_txn_header_id => l_txn_header_id, p_org_id => l_organization_id, x_return_status => l_return_status, x_msg_count => l_msg_count, x_msg_data => l_msg_data, p_from_lpn_id => l_from_lpn_id, p_drop_lpn => l_drop_lpn, p_loc_reason_id => l_loc_reason_id, p_sub => pv_subinventory_code, p_loc => pn_locator, p_orig_sub => NULL, p_orig_loc => NULL, p_user_id => l_user_id, p_task_type => l_task_type
                                         , p_commit => l_commit);


        insert_message (
            'LOG',
            'wms_task_dispatch_gen.pick_drop ret_stat: ' || l_return_status);

        IF (l_return_status <> 'S')
        THEN
            l_ret_stat_holder   := l_return_status;
            x_msg_count         := l_msg_count;
            x_msg_data          := l_msg_data;
        END IF;

        IF x_ret_stat <> 'S'
        THEN
            FOR i IN 1 .. fnd_msg_pub.count_msg
            LOOP
                fnd_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => v_message
                                 , p_msg_index_out => l_next_msg);
                DBMS_OUTPUT.put_line (v_message);
                x_msg_data   :=
                    SUBSTR (x_msg_data || ' ' || v_message, 1, 2000);
            END LOOP;

            x_msg_data   :=
                NVL (x_msg_data,
                     'An unknown error was encountered during pick drop.');
        END IF;

        IF (l_ret_stat_holder IS NULL)
        THEN
            x_ret_stat   := 'S';
            x_msg_data   := NULL;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat    := 'E';
            x_msg_data    := 'Others exception thrown: ' || SQLERRM;
            x_msg_count   := 1;
            insert_message ('LOG', x_msg_data);
            RETURN;
    END drop_lpn;

    FUNCTION get_transaction_date (pn_item_id   IN NUMBER,
                                   pn_org_id    IN NUMBER,
                                   pn_qty       IN NUMBER)
        RETURN DATE
    IS
        CURSOR c_item_details IS
              SELECT transaction_date, SUM (qty + corrected_qty) qty
                FROM (SELECT TRUNC (rcvt.transaction_date) transaction_date,
                             NVL (rcvt.quantity, 0) qty,
                             (SELECT NVL (SUM (quantity), 0)
                                FROM apps.rcv_transactions rcvt1
                               WHERE     rcvt1.parent_transaction_id =
                                         rcvt.transaction_id
                                     AND rcvt1.transaction_type = 'CORRECT') corrected_qty
                        FROM apps.rcv_shipment_lines rsl, apps.rcv_transactions rcvt
                       WHERE     rcvt.transaction_type = 'DELIVER'
                             AND rcvt.destination_type_code = 'INVENTORY'
                             AND rsl.source_document_code = 'PO'
                             AND rsl.shipment_line_id = rcvt.shipment_line_id
                             AND rsl.item_id = pn_item_id
                             AND rcvt.organization_id = pn_org_id)
            GROUP BY transaction_date
            ORDER BY transaction_date DESC;

        ln_qty                NUMBER;
        ln_sum_qty            NUMBER;
        ld_transaction_date   DATE;
    BEGIN
        ln_qty                := pn_qty;
        ln_sum_qty            := 0;
        ld_transaction_date   := NULL;

        FOR r_item_details IN c_item_details
        LOOP
            ln_sum_qty   := ln_sum_qty + r_item_details.qty;

            IF ln_sum_qty >= ln_qty
            THEN
                ld_transaction_date   := r_item_details.transaction_date;
                EXIT;
            END IF;
        END LOOP;

        IF ld_transaction_date IS NULL
        THEN
            ld_transaction_date   :=
                ADD_MONTHS (TRUNC (SYSDATE, 'MONTH'), -60) - 1;
            RETURN ld_transaction_date;
        ELSE
            ld_transaction_date   := TRUNC (ld_transaction_date, 'MONTH');
            RETURN ld_transaction_date;
        END IF;

        insert_message (
            'LOG',
            'Receiving Transaction Date: ' || ld_transaction_date);
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message (
                'LOG',
                'Unexpected error while fetching rcv date: ' || SQLERRM);
            ld_transaction_date   := ADD_MONTHS (TRUNC (SYSDATE), -60) - 1;
    END get_transaction_date;

    FUNCTION f_get_onhand (pn_item_id IN NUMBER, pn_org_id IN NUMBER, pv_sub IN VARCHAR2
                           , pn_locator_id IN NUMBER)
        RETURN NUMBER
    IS
        v_api_return_status   VARCHAR2 (1);
        v_qty_oh              NUMBER;
        v_qty_res_oh          NUMBER;
        v_qty_res             NUMBER;
        v_qty_sug             NUMBER;
        v_qty_att             NUMBER;
        v_qty_atr             NUMBER;
        v_msg_count           NUMBER;
        v_msg_data            VARCHAR2 (1000);
        l_onhand              NUMBER := 0;
    BEGIN
        inv_quantity_tree_grp.clear_quantity_cache;

        apps.INV_QUANTITY_TREE_PUB.QUERY_QUANTITIES (p_api_version_number => 1.0, p_init_msg_lst => apps.fnd_api.g_false, x_return_status => v_api_return_status, x_msg_count => v_msg_count, x_msg_data => v_msg_data, p_organization_id => pn_org_id, p_inventory_item_id => pn_item_id, p_tree_mode => apps.inv_quantity_tree_pub.g_transaction_mode, p_onhand_source => 3, p_is_revision_control => FALSE, p_is_lot_control => FALSE, p_is_serial_control => FALSE, p_revision => NULL, p_lot_number => NULL, p_subinventory_code => pv_sub, p_locator_id => pn_locator_id, x_qoh => v_qty_oh, x_rqoh => v_qty_res_oh, x_qr => v_qty_res, x_qs => v_qty_sug, x_att => v_qty_att
                                                     , x_atr => v_qty_atr);

        l_onhand   := v_qty_oh;
        RETURN l_onhand;
    EXCEPTION
        WHEN OTHERS
        THEN
            l_onhand   := 0;
            RETURN l_onhand;
    END f_get_onhand;

    PROCEDURE insert_iso_data (pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2)
    IS
        ln_ordered_quantity     NUMBER;
        ln_remaining_quantity   NUMBER;

        CURSOR c_item_details IS
              SELECT moqd.inventory_item_id, msi.segment1 item_number, muc.conversion_rate cpq,
                     SUM (moqd.transaction_quantity) quantity
                FROM apps.mtl_onhand_quantities_detail moqd, apps.mtl_uom_conversions muc, apps.mtl_system_items_kfv msi,
                     apps.mtl_item_locations_kfv mil
               WHERE     moqd.organization_id = pn_src_org_id
                     AND moqd.subinventory_code = pv_src_subinv
                     AND moqd.locator_id = mil.inventory_location_id
                     AND moqd.organization_id = mil.organization_id
                     AND moqd.inventory_item_id = muc.inventory_item_id
                     AND muc.disable_date IS NULL
                     AND moqd.organization_id = msi.organization_id
                     AND msi.inventory_item_id = moqd.inventory_item_id
                     AND mil.concatenated_segments =
                         NVL (pv_src_locator, mil.concatenated_segments)
            GROUP BY moqd.inventory_item_id, muc.conversion_rate, msi.segment1,
                     msi.primary_uom_code
            ORDER BY moqd.inventory_item_id;

        CURSOR c_order_data IS
              SELECT ooha.header_id, ooha.order_number, flv.meaning
                FROM apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
               WHERE     flv.lookup_type = 'XXDO_NH_BLANKET_ISO_LIST'
                     AND flv.language = 'US'
                     AND ooha.order_number = flv.lookup_code
                     AND flv.enabled_flag = 'Y'
            ORDER BY flv.tag;
    BEGIN
        insert_message ('LOG', 'Inside ISO Data Procedure');

        FOR r_item_details IN c_item_details
        LOOP
            ln_remaining_quantity   := r_item_details.quantity;

            FOR r_order_data IN c_order_data
            LOOP
                BEGIN
                    SELECT NVL (SUM (ordered_quantity), 0)
                      INTO ln_ordered_quantity
                      FROM apps.oe_order_lines_all
                     WHERE     header_id = r_order_data.header_id
                           AND inventory_item_id =
                               r_item_details.inventory_item_id
                           AND open_flag = 'Y';
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_ordered_quantity   := 0;
                END;



                IF     ln_ordered_quantity >= ln_remaining_quantity
                   AND ln_ordered_quantity > 0
                THEN
                    INSERT INTO XXDO.XXDO_ISO_ITEM_ATP_STG (ISO_NUMBER, ITEM_NUMBER, INVENTORY_ITEM_ID, QUANTITY, INTERNAL_REQUISITION, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY
                                                            , REQUEST_ID)
                         VALUES (r_order_data.order_number, r_item_details.item_number, r_item_details.inventory_item_id, ln_remaining_quantity, gv_requisition_number, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                 , gn_request_id);

                    EXIT;
                ELSIF     ln_ordered_quantity > 0
                      AND ln_ordered_quantity < ln_remaining_quantity
                THEN
                    ln_remaining_quantity   :=
                        ln_remaining_quantity - ln_ordered_quantity;

                    INSERT INTO XXDO.XXDO_ISO_ITEM_ATP_STG (ISO_NUMBER, ITEM_NUMBER, INVENTORY_ITEM_ID, QUANTITY, INTERNAL_REQUISITION, CREATION_DATE, CREATED_BY, LAST_UPDATE_DATE, LAST_UPDATED_BY
                                                            , REQUEST_ID)
                         VALUES (r_order_data.order_number, r_item_details.item_number, r_item_details.inventory_item_id, ln_ordered_quantity, gv_requisition_number, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                                 , gn_request_id);
                END IF;
            END LOOP;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message ('LOG',
                            'Inside Releieve ATP Exception: ' || SQLERRM);
    END insert_iso_data;

    PROCEDURE relieve_atp
    IS
        l_header_rec                   OE_ORDER_PUB.Header_Rec_Type;
        l_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type;
        l_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        l_header_adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        l_line_adj_tbl                 OE_ORDER_PUB.line_adj_tbl_Type;
        l_header_scr_tbl               OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        l_line_scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        l_request_rec                  OE_ORDER_PUB.Request_Rec_Type;
        l_return_status                VARCHAR2 (1000);
        l_msg_count                    NUMBER;
        l_msg_data                     VARCHAR2 (1000);
        p_api_version_number           NUMBER := 1.0;
        p_init_msg_list                VARCHAR2 (10) := FND_API.G_FALSE;
        p_return_values                VARCHAR2 (10) := FND_API.G_FALSE;
        p_action_commit                VARCHAR2 (10) := FND_API.G_FALSE;
        x_return_status                VARCHAR2 (1);
        x_msg_count                    NUMBER;
        x_msg_data                     VARCHAR2 (100);
        p_header_rec                   OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_old_header_rec               OE_ORDER_PUB.Header_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_REC;
        p_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_old_header_val_rec           OE_ORDER_PUB.Header_Val_Rec_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_VAL_REC;
        p_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_old_Header_Adj_tbl           OE_ORDER_PUB.Header_Adj_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_TBL;
        p_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_old_Header_Adj_val_tbl       OE_ORDER_PUB.Header_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_VAL_TBL;
        p_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_old_Header_Price_Att_tbl     OE_ORDER_PUB.Header_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_PRICE_ATT_TBL;
        p_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_old_Header_Adj_Att_tbl       OE_ORDER_PUB.Header_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ATT_TBL;
        p_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_old_Header_Adj_Assoc_tbl     OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_ADJ_ASSOC_TBL;
        p_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_old_Header_Scredit_tbl       OE_ORDER_PUB.Header_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_TBL;
        p_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_old_Header_Scredit_val_tbl   OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_HEADER_SCREDIT_VAL_TBL;
        p_line_tbl                     OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_old_line_tbl                 OE_ORDER_PUB.Line_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_LINE_TBL;
        p_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_old_line_val_tbl             OE_ORDER_PUB.Line_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_VAL_TBL;
        p_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_old_Line_Adj_tbl             OE_ORDER_PUB.Line_Adj_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_TBL;
        p_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_old_Line_Adj_val_tbl         OE_ORDER_PUB.Line_Adj_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_VAL_TBL;
        p_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_old_Line_Price_Att_tbl       OE_ORDER_PUB.Line_Price_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_PRICE_ATT_TBL;
        p_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_old_Line_Adj_Att_tbl         OE_ORDER_PUB.Line_Adj_Att_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ATT_TBL;
        p_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_old_Line_Adj_Assoc_tbl       OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_ADJ_ASSOC_TBL;
        p_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_old_Line_Scredit_tbl         OE_ORDER_PUB.Line_Scredit_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_TBL;
        p_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_old_Line_Scredit_val_tbl     OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LINE_SCREDIT_VAL_TBL;
        p_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_old_Lot_Serial_tbl           OE_ORDER_PUB.Lot_Serial_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_TBL;
        p_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_old_Lot_Serial_val_tbl       OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type
            := OE_ORDER_PUB.G_MISS_LOT_SERIAL_VAL_TBL;
        p_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type
                                           := OE_ORDER_PUB.G_MISS_REQUEST_TBL;
        x_header_val_rec               OE_ORDER_PUB.Header_Val_Rec_Type;
        x_Header_Adj_tbl               OE_ORDER_PUB.Header_Adj_Tbl_Type;
        x_Header_Adj_val_tbl           OE_ORDER_PUB.Header_Adj_Val_Tbl_Type;
        x_Header_price_Att_tbl         OE_ORDER_PUB.Header_Price_Att_Tbl_Type;
        x_Header_Adj_Att_tbl           OE_ORDER_PUB.Header_Adj_Att_Tbl_Type;
        x_Header_Adj_Assoc_tbl         OE_ORDER_PUB.Header_Adj_Assoc_Tbl_Type;
        x_Header_Scredit_tbl           OE_ORDER_PUB.Header_Scredit_Tbl_Type;
        x_Header_Scredit_val_tbl       OE_ORDER_PUB.Header_Scredit_Val_Tbl_Type;
        x_line_val_tbl                 OE_ORDER_PUB.Line_Val_Tbl_Type;
        x_Line_Adj_tbl                 OE_ORDER_PUB.Line_Adj_Tbl_Type;
        x_Line_Adj_val_tbl             OE_ORDER_PUB.Line_Adj_Val_Tbl_Type;
        x_Line_price_Att_tbl           OE_ORDER_PUB.Line_Price_Att_Tbl_Type;
        x_Line_Adj_Att_tbl             OE_ORDER_PUB.Line_Adj_Att_Tbl_Type;
        x_Line_Adj_Assoc_tbl           OE_ORDER_PUB.Line_Adj_Assoc_Tbl_Type;
        x_Line_Scredit_tbl             OE_ORDER_PUB.Line_Scredit_Tbl_Type;
        x_Line_Scredit_val_tbl         OE_ORDER_PUB.Line_Scredit_Val_Tbl_Type;
        x_Lot_Serial_tbl               OE_ORDER_PUB.Lot_Serial_Tbl_Type;
        x_Lot_Serial_val_tbl           OE_ORDER_PUB.Lot_Serial_Val_Tbl_Type;
        x_action_request_tbl           OE_ORDER_PUB.Request_Tbl_Type;
        X_DEBUG_FILE                   VARCHAR2 (500);
        l_line_tbl_index               NUMBER;
        l_msg_index_out                NUMBER (10);

        CURSOR c_order_number IS
              SELECT DISTINCT iso_number, ooha.header_id
                FROM xxdo.xxdo_iso_item_atp_stg stg, apps.oe_order_headers_all ooha
               WHERE     stg.request_id = gn_request_id
                     AND stg.iso_number = ooha.order_number
            ORDER BY iso_number;


        CURSOR c_line_details (pv_order_number VARCHAR2)
        IS
              SELECT oola.line_id, oola.header_id, oola.ordered_quantity,
                     oola.ordered_item, oola.request_date, stg.quantity stg_quantity
                FROM xxdo.xxdo_iso_item_atp_stg stg, apps.oe_order_headers_all ooha, apps.oe_order_lines_all oola
               WHERE     stg.request_id = gn_request_id
                     AND stg.iso_number = ooha.order_number
                     AND ooha.order_number = pv_order_number
                     AND ooha.header_id = oola.header_id
                     AND oola.ordered_item = stg.item_number
                     AND oola.open_flag = 'Y'
            ORDER BY oola.ordered_quantity DESC;

        ln_ordered_quantity            NUMBER;
        ln_total_sum                   NUMBER;
        ln_initial_quantity            NUMBER;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;
    BEGIN
        insert_message ('LOG', 'Inside Releieve ATP Procedure');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50746;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (gn_org_id, NULL, 'ONT');

        FOR r_order_number IN c_order_number
        LOOP
            oe_debug_pub.initialize;
            oe_msg_pub.initialize;
            l_line_tbl_index         := 1;
            l_line_tbl.delete ();
            insert_message (
                'LOG',
                'Processing for Order: ' || r_order_number.iso_number);

            l_header_rec             := OE_ORDER_PUB.G_MISS_HEADER_REC;
            l_header_rec.header_id   := r_order_number.header_id;
            l_header_rec.operation   := OE_GLOBALS.G_OPR_UPDATE;

            FOR r_line_details IN c_line_details (r_order_number.iso_number)
            LOOP
                ln_ordered_quantity                                    :=
                    GREATEST (
                        r_line_details.ordered_quantity - r_line_details.stg_quantity,
                        0);

                insert_message (
                    'LOG',
                       'Relieving ATP for Item: '
                    || r_line_details.ordered_item
                    || ', for quantity: '
                    || r_line_details.ordered_quantity);

                insert_message (
                    'LOG',
                       'Order Quantity: '
                    || r_line_details.ordered_quantity
                    || ', Stage Quantity: '
                    || r_line_details.stg_quantity
                    || ', remaining on order: '
                    || ln_ordered_quantity);
                -- Changed attributes
                l_line_tbl (l_line_tbl_index)                          :=
                    OE_ORDER_PUB.G_MISS_LINE_REC;
                l_line_tbl (l_line_tbl_index).operation                :=
                    OE_GLOBALS.G_OPR_UPDATE;
                l_line_tbl (l_line_tbl_index).header_id                :=
                    r_line_details.header_id;        -- header_id of the order
                l_line_tbl (l_line_tbl_index).line_id                  :=
                    r_line_details.line_id;       -- line_id of the order line
                l_line_tbl (l_line_tbl_index).ordered_quantity         :=
                    ln_ordered_quantity;               -- new ordered quantity
                l_line_tbl (l_line_tbl_index).Override_atp_date_code   := 'Y';
                l_line_tbl (l_line_tbl_index).change_reason            := '1'; -- change reason code
                l_line_tbl (l_line_tbl_index).schedule_arrival_date    :=
                    r_line_details.request_date;
                l_line_tbl_index                                       :=
                    l_line_tbl_index + 1;
            END LOOP;

            IF l_line_tbl.COUNT > 0
            THEN
                -- CALL TO PROCESS ORDER
                OE_ORDER_PUB.process_order (
                    p_api_version_number       => 1.0,
                    p_init_msg_list            => fnd_api.g_true,
                    p_return_values            => fnd_api.g_true,
                    p_action_commit            => fnd_api.g_false,
                    x_return_status            => l_return_status,
                    x_msg_count                => l_msg_count,
                    x_msg_data                 => l_msg_data,
                    p_header_rec               => l_header_rec,
                    p_line_tbl                 => l_line_tbl,
                    p_action_request_tbl       => l_action_request_tbl,
                    x_header_rec               => p_header_rec,
                    x_header_val_rec           => x_header_val_rec,
                    x_Header_Adj_tbl           => x_Header_Adj_tbl,
                    x_Header_Adj_val_tbl       => x_Header_Adj_val_tbl,
                    x_Header_price_Att_tbl     => x_Header_price_Att_tbl,
                    x_Header_Adj_Att_tbl       => x_Header_Adj_Att_tbl,
                    x_Header_Adj_Assoc_tbl     => x_Header_Adj_Assoc_tbl,
                    x_Header_Scredit_tbl       => x_Header_Scredit_tbl,
                    x_Header_Scredit_val_tbl   => x_Header_Scredit_val_tbl,
                    x_line_tbl                 => p_line_tbl,
                    x_line_val_tbl             => x_line_val_tbl,
                    x_Line_Adj_tbl             => x_Line_Adj_tbl,
                    x_Line_Adj_val_tbl         => x_Line_Adj_val_tbl,
                    x_Line_price_Att_tbl       => x_Line_price_Att_tbl,
                    x_Line_Adj_Att_tbl         => x_Line_Adj_Att_tbl,
                    x_Line_Adj_Assoc_tbl       => x_Line_Adj_Assoc_tbl,
                    x_Line_Scredit_tbl         => x_Line_Scredit_tbl,
                    x_Line_Scredit_val_tbl     => x_Line_Scredit_val_tbl,
                    x_Lot_Serial_tbl           => x_Lot_Serial_tbl,
                    x_Lot_Serial_val_tbl       => x_Lot_Serial_val_tbl,
                    x_action_request_tbl       => p_action_request_tbl);

                -- Check the return status
                IF l_return_status = FND_API.G_RET_STS_SUCCESS
                THEN
                    insert_message ('LOG', 'Line Quantity Update Sucessful');
                    COMMIT;
                ELSE
                    -- Retrieve messages
                    FOR i IN 1 .. l_msg_count
                    LOOP
                        Oe_Msg_Pub.get (p_msg_index => i, p_encoded => Fnd_Api.G_FALSE, p_data => l_msg_data
                                        , p_msg_index_out => l_msg_index_out);
                        insert_message (
                            'LOG',
                            'message index is: ' || l_msg_index_out);
                        insert_message ('LOG', 'message is: ' || l_msg_data);
                    END LOOP;

                    insert_message ('LOG', 'Line Quantity update Failed');
                END IF;
            END IF;

            COMMIT;
        END LOOP;
    EXCEPTION
        WHEN OTHERS
        THEN
            insert_message ('LOG',
                            'Exception while relieving ATP: ' || SQLERRM);
    END relieve_atp;

    FUNCTION f_get_supply (pn_item_id IN NUMBER, pn_org_id IN NUMBER, pn_start_date IN DATE
                           , pn_end_date IN DATE)
        RETURN NUMBER
    IS
        ln_quantity   NUMBER;
    BEGIN
        SELECT NVL (SUM (quantity), 0)
          INTO ln_quantity
          FROM (SELECT SUM (RSl.quantity_shipped) quantity
                  FROM apps.mtl_supply ms, apps.rcv_shipment_LINES rsl
                 WHERE     ms.to_organization_id = pn_org_id
                       AND ms.destination_type_code = 'INVENTORY'
                       AND ms.supply_type_code = 'SHIPMENT'
                       AND ms.shipment_line_id = rsl.shipment_line_id
                       AND ms.shipment_header_id = rsl.shipment_header_id
                       AND NVL (rsl.quantity_received, 0) = 0
                       AND rsl.to_organization_id = ms.to_organization_id
                       AND rsl.item_id = pn_item_id
                       AND TRUNC (ms.expected_delivery_date) BETWEEN TRUNC (
                                                                         pn_start_date)
                                                                 AND TRUNC (
                                                                         pn_end_date)
                UNION
                SELECT SUM (pll.quantity) quantity
                  FROM apps.mtl_supply ms, apps.po_line_locations_all pll, apps.po_lines_all pl
                 WHERE     ms.to_organization_id = pn_org_id
                       AND ms.destination_type_code = 'INVENTORY'
                       AND ms.supply_type_code = 'PO'
                       AND pl.item_id = pn_item_id
                       AND pll.po_header_id = ms.po_header_id
                       AND pll.po_header_id = pl.po_header_id
                       AND pll.po_line_id = pl.po_line_id
                       AND pll.po_line_id = ms.po_line_id
                       AND ms.to_organization_id =
                           pll.ship_to_organization_id
                       AND pll.quantity_received = 0
                       AND TRUNC (ms.expected_delivery_date) BETWEEN TRUNC (
                                                                         pn_start_date)
                                                                 AND TRUNC (
                                                                         pn_end_date)
                UNION
                SELECT SUM (prl.quantity) quantity
                  FROM apps.po_requisition_lines_all prl, apps.mtl_supply ms
                 WHERE     ms.to_organization_id = pn_org_id
                       AND ms.req_header_id = prl.requisition_header_id
                       AND prl.item_id = pn_item_id
                       AND ms.req_line_id = prl.requisition_line_id
                       AND prl.destination_organization_id =
                           ms.to_organization_id
                       AND NVL (prl.quantity_received, 0) = 0
                       AND NVL (prl.cancel_flag, 'N') = 'N'
                       AND TRUNC (ms.expected_delivery_date) BETWEEN TRUNC (
                                                                         pn_start_date)
                                                                 AND TRUNC (
                                                                         pn_end_date));

        RETURN ln_quantity;
    EXCEPTION
        WHEN OTHERS
        THEN
            ln_quantity   := 0;
            RETURN ln_quantity;
    END f_get_supply;

    PROCEDURE create_internal_orders (pv_return_status OUT VARCHAR2)
    IS
        ln_req_request_id   NUMBER;
        ln_resp_id          NUMBER;
        ln_resp_appl_id     NUMBER;
        lv_chr_phase        VARCHAR2 (120 BYTE);
        lv_chr_status       VARCHAR2 (120 BYTE);
        lv_chr_dev_phase    VARCHAR2 (120 BYTE);
        lv_chr_dev_status   VARCHAR2 (120 BYTE);
        lv_chr_message      VARCHAR2 (2000 BYTE);
        lb_bol_result       BOOLEAN;
    BEGIN
        insert_message ('LOG', 'Inside Create Internal Orders');

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

        ln_req_request_id   :=
            apps.fnd_request.submit_request (application => 'PO', -- application short name
                                                                  program => 'POCISO', -- program short name
                                                                                       start_time => SYSDATE
                                             , sub_request => FALSE);

        COMMIT;

        IF ln_req_request_id <> 0
        THEN
            insert_message (
                'LOG',
                'Create Internal Orders Request Id: ' || ln_req_request_id);
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF lv_chr_dev_phase = 'COMPLETE'
            THEN
                insert_message ('LOG', 'Create Internal Completed');

                IF lv_chr_status = 'Normal'
                THEN
                    pv_return_status   := 'S';
                    insert_message (
                        'LOG',
                        'Internal order program completed successfully');
                END IF;
            ELSE
                insert_message ('LOG', 'Create Internal Not Completed Yet');
            END IF;
        END IF;
    END create_internal_orders;

    PROCEDURE run_order_import (pv_return_status OUT VARCHAR2)
    IS
        ln_req_request_id    NUMBER;
        ln_resp_id           NUMBER;
        ln_resp_appl_id      NUMBER;
        ln_requisition_id    NUMBER;
        lv_requisition_num   VARCHAR2 (100);
        lv_chr_phase         VARCHAR2 (120 BYTE);
        lv_chr_status        VARCHAR2 (120 BYTE);
        lv_chr_dev_phase     VARCHAR2 (120 BYTE);
        lv_chr_dev_status    VARCHAR2 (120 BYTE);
        lv_chr_message       VARCHAR2 (2000 BYTE);
        lb_bol_result        BOOLEAN;
    BEGIN
        insert_message ('LOG', 'Inside Order Import program');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50746;
                ln_resp_appl_id   := 660;
        END;

        BEGIN
            SELECT requisition_header_id, segment1
              INTO ln_requisition_id, lv_requisition_num
              FROM apps.po_requisition_headers_all
             WHERE interface_source_code = 'NH' || '-' || gn_request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_requisition_id   := NULL;
        END;

        IF lv_requisition_num IS NOT NULL
        THEN
            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET INTERNAL_REQUISITION   = lv_requisition_num
             WHERE REQUEST_ID = gn_request_id;

            COMMIT;

            insert_message ('BOTH',
                            'Requisition Number: ' || lv_requisition_num);
        END IF;


        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        mo_global.Set_org_context (gn_org_id, NULL, 'ONT');

        ln_req_request_id   :=
            apps.fnd_request.submit_request (
                application   => 'ONT',              -- application short name
                program       => 'OEOIMP',               -- program short name
                argument1     => gn_org_id,                  -- Operating Unit
                argument2     => 10,                         -- Internal Order
                argument3     => NVL (ln_requisition_id, NULL), -- Orig Sys Document Ref
                argument4     => NULL,                       -- operation code
                argument5     => 'N',                         -- Validate Only
                argument6     => NULL,                          -- Debug level
                argument7     => 4,                               -- Instances
                argument8     => NULL,                       -- Sold to Org Id
                argument9     => NULL,                          -- Sold To Org
                argument10    => NULL,                           -- Change seq
                argument11    => NULL,                           -- Perf Param
                argument12    => 'N',                  -- Trim Trailing Blanks
                argument13    => NULL,           -- Process Orders with no org
                argument14    => NULL,                       -- Default org id
                argument15    => 'Y'              -- Validate Desc Flex Fields
                                    );



        COMMIT;

        IF ln_req_request_id <> 0
        THEN
            insert_message ('LOG',
                            'Order Import Request Id: ' || ln_req_request_id);
            lb_bol_result   :=
                fnd_concurrent.wait_for_request (ln_req_request_id,
                                                 60,
                                                 0,
                                                 lv_chr_phase,
                                                 lv_chr_status,
                                                 lv_chr_dev_phase,
                                                 lv_chr_dev_status,
                                                 lv_chr_message);

            IF UPPER (lv_chr_dev_phase) = 'COMPLETE'
            THEN
                IF UPPER (lv_chr_status) = 'NORMAL'
                THEN
                    pv_return_status   := 'S';
                    insert_message ('LOG',
                                    'Order Import completed successfully');
                END IF;
            ELSE
                insert_message ('LOG', 'Create Internal Not Completed Yet');
            END IF;
        END IF;
    END run_order_import;

    PROCEDURE schedule_iso
    IS
        v_api_version_number           NUMBER := 1;
        v_return_status                VARCHAR2 (4000);
        v_msg_count                    NUMBER;
        v_msg_data                     VARCHAR2 (4000);

        -- IN Variables --
        v_header_rec                   oe_order_pub.header_rec_type;
        test_line                      oe_order_pub.Line_Rec_Type;
        v_line_tbl                     oe_order_pub.line_tbl_type;
        v_action_request_tbl           oe_order_pub.request_tbl_type;
        v_line_adj_tbl                 oe_order_pub.line_adj_tbl_type;

        -- OUT Variables --
        v_header_rec_out               oe_order_pub.header_rec_type;
        v_header_val_rec_out           oe_order_pub.header_val_rec_type;
        v_header_adj_tbl_out           oe_order_pub.header_adj_tbl_type;
        v_header_adj_val_tbl_out       oe_order_pub.header_adj_val_tbl_type;
        v_header_price_att_tbl_out     oe_order_pub.header_price_att_tbl_type;
        v_header_adj_att_tbl_out       oe_order_pub.header_adj_att_tbl_type;
        v_header_adj_assoc_tbl_out     oe_order_pub.header_adj_assoc_tbl_type;
        v_header_scredit_tbl_out       oe_order_pub.header_scredit_tbl_type;
        v_header_scredit_val_tbl_out   oe_order_pub.header_scredit_val_tbl_type;
        v_line_tbl_out                 oe_order_pub.line_tbl_type;
        v_line_val_tbl_out             oe_order_pub.line_val_tbl_type;
        v_line_adj_tbl_out             oe_order_pub.line_adj_tbl_type;
        v_line_adj_val_tbl_out         oe_order_pub.line_adj_val_tbl_type;
        v_line_price_att_tbl_out       oe_order_pub.line_price_att_tbl_type;
        v_line_adj_att_tbl_out         oe_order_pub.line_adj_att_tbl_type;
        v_line_adj_assoc_tbl_out       oe_order_pub.line_adj_assoc_tbl_type;
        v_line_scredit_tbl_out         oe_order_pub.line_scredit_tbl_type;
        v_line_scredit_val_tbl_out     oe_order_pub.line_scredit_val_tbl_type;
        v_lot_serial_tbl_out           oe_order_pub.lot_serial_tbl_type;
        v_lot_serial_val_tbl_out       oe_order_pub.lot_serial_val_tbl_type;
        v_action_request_tbl_out       oe_order_pub.request_tbl_type;

        v_msg_index                    NUMBER;
        v_data                         VARCHAR2 (2000);
        v_loop_count                   NUMBER;
        v_debug_file                   VARCHAR2 (200);
        b_return_status                VARCHAR2 (200);
        b_msg_count                    NUMBER;
        b_msg_data                     VARCHAR2 (2000);
        i                              NUMBER := 0;
        j                              NUMBER := 0;
        ln_resp_id                     NUMBER;
        ln_resp_appl_id                NUMBER;

        CURSOR header_cur IS
            SELECT DISTINCT ooha.order_number, ooha.header_id order_id, ooha.org_id
              FROM apps.po_requisition_headers_all prh, apps.oe_order_headers_all ooha
             WHERE     prh.interface_source_code =
                       'NH' || '-' || gn_request_id
                   AND prh.segment1 = ooha.orig_sys_document_ref
                   AND ooha.open_flag = 'Y';

        CURSOR line_cur (p_order_id NUMBER)
        IS
            SELECT DISTINCT oel.line_id, oel.request_date
              FROM apps.oe_order_lines_all oel
             WHERE     oel.header_id = p_order_id
                   AND oel.flow_status_code IN ('BOOKED')
                   AND oel.schedule_ship_date IS NULL
                   AND oel.open_flag = 'Y';
    BEGIN
        insert_message ('LOG', 'Inside Schedule ISO procedure');

        BEGIN
            SELECT responsibility_id, application_id
              INTO ln_resp_id, ln_resp_appl_id
              FROM fnd_responsibility_tl
             WHERE     responsibility_name =
                       'Deckers Order Management Manager - US'
                   AND language = 'US';
        EXCEPTION
            WHEN OTHERS
            THEN
                ln_resp_id        := 50746;
                ln_resp_appl_id   := 660;
        END;

        APPS.FND_GLOBAL.APPS_INITIALIZE (USER_ID        => gn_user_id,
                                         RESP_ID        => ln_resp_id,
                                         RESP_APPL_ID   => ln_resp_appl_id);

        --mo_global.Set_org_context (95, NULL, 'ONT');



        FOR header_rec IN header_cur
        LOOP
            i   := i + 1;
            j   := 0;
            oe_msg_pub.initialize;
            oe_debug_pub.initialize;
            mo_global.init ('ONT');
            mo_global.Set_org_context (HEADER_REC.ORG_ID, NULL, 'ONT');
            insert_message ('LOG', 'Order id: ' || header_rec.order_id);

            UPDATE XXDO.XXDO_INV_CONV_LPN_ONHAND_STG
               SET INTERNAL_ORDER   = header_rec.order_number
             WHERE REQUEST_ID = gn_request_id;

            COMMIT;

            insert_message ('BOTH',
                            'Order Number: ' || header_rec.order_number);

            /*v_header_rec                        := oe_order_pub.g_miss_header_rec;
            v_header_rec.operation              := OE_GLOBALS.G_OPR_UPDATE;
            v_header_rec.header_id              := header_rec .order_id; */


            --v_action_request_tbl (i) := oe_order_pub.g_miss_request_rec;

            v_line_tbl.delete ();

            FOR line_rec IN line_cur (header_rec.order_id)
            LOOP
                insert_message ('LOG', 'Order Line' || line_rec.line_id);
                j                                       := j + 1;

                v_line_tbl (j)                          := OE_ORDER_PUB.G_MISS_LINE_REC;
                v_line_tbl (j).header_id                := header_rec.order_id;
                v_line_tbl (j).line_id                  := line_rec.line_id;
                v_line_tbl (j).operation                := oe_globals.G_OPR_UPDATE;
                v_line_tbl (j).OVERRIDE_ATP_DATE_CODE   := 'Y';
                v_line_tbl (j).schedule_arrival_date    :=
                    line_rec.request_date;
            --  v_line_tbl (j).schedule_ship_date := line_rec.request_date;
            --v_line_tbl(j).schedule_action_code := oe_order_sch_util.oesch_act_schedule;


            END LOOP;

            IF j > 0
            THEN
                OE_ORDER_PUB.PROCESS_ORDER (
                    p_api_version_number       => v_api_version_number,
                    p_header_rec               => v_header_rec,
                    p_line_tbl                 => v_line_tbl,
                    p_action_request_tbl       => v_action_request_tbl,
                    p_line_adj_tbl             => v_line_adj_tbl,
                    x_header_rec               => v_header_rec_out,
                    x_header_val_rec           => v_header_val_rec_out,
                    x_header_adj_tbl           => v_header_adj_tbl_out,
                    x_header_adj_val_tbl       => v_header_adj_val_tbl_out,
                    x_header_price_att_tbl     => v_header_price_att_tbl_out,
                    x_header_adj_att_tbl       => v_header_adj_att_tbl_out,
                    x_header_adj_assoc_tbl     => v_header_adj_assoc_tbl_out,
                    x_header_scredit_tbl       => v_header_scredit_tbl_out,
                    x_header_scredit_val_tbl   => v_header_scredit_val_tbl_out,
                    x_line_tbl                 => v_line_tbl_out,
                    x_line_val_tbl             => v_line_val_tbl_out,
                    x_line_adj_tbl             => v_line_adj_tbl_out,
                    x_line_adj_val_tbl         => v_line_adj_val_tbl_out,
                    x_line_price_att_tbl       => v_line_price_att_tbl_out,
                    x_line_adj_att_tbl         => v_line_adj_att_tbl_out,
                    x_line_adj_assoc_tbl       => v_line_adj_assoc_tbl_out,
                    x_line_scredit_tbl         => v_line_scredit_tbl_out,
                    x_line_scredit_val_tbl     => v_line_scredit_val_tbl_out,
                    x_lot_serial_tbl           => v_lot_serial_tbl_out,
                    x_lot_serial_val_tbl       => v_lot_serial_val_tbl_out,
                    x_action_request_tbl       => v_action_request_tbl_out,
                    x_return_status            => v_return_status,
                    x_msg_count                => v_msg_count,
                    x_msg_data                 => v_msg_data);



                IF v_return_status = fnd_api.g_ret_sts_success
                THEN
                    COMMIT;
                    insert_message (
                        'LOG',
                        'Update Success for order number:' || header_rec.order_number);
                ELSE
                    insert_message (
                        'LOG',
                        'Update Failed for order number:' || header_rec.order_number);
                    insert_message (
                        'LOG',
                        'Reason is:' || SUBSTR (v_msg_data, 1, 1900));
                    ROLLBACK;

                    FOR i IN 1 .. v_msg_count
                    LOOP
                        v_msg_data   :=
                            oe_msg_pub.get (p_msg_index => i, p_encoded => 'F');
                        insert_message ('LOG', i || ') ' || v_msg_data);
                    END LOOP;

                    insert_message ('LOG', 'v_msg_data  : ' || v_msg_data);
                END IF;
            END IF;

            COMMIT;
        END LOOP;

        COMMIT;
    -- DBMS_OUTPUT.put_line ('END OF THE PROGRAM');
    END schedule_iso;

    PROCEDURE nh_inventory_report (x_errbuf OUT VARCHAR2, x_retcode OUT VARCHAR2, pv_brand VARCHAR2, pv_src_org NUMBER, pv_dest_org NUMBER, pn_first_n_days NUMBER
                                   , pn_second_n_days NUMBER)
    AS
        --Variable Declaration
        gn_warning                 NUMBER (3) := 1;
        gn_error                   NUMBER (3) := 2;
        x_id                       UTL_FILE.file_type;
        p_source_directory         VARCHAR2 (1000) := 'XXDO_NH_INVENTORY_REPORT';
        l_delimiter                VARCHAR2 (3) := '|';
        ld_max_supply_date         DATE;

        CURSOR get_inventory_data IS
              SELECT organization, brand, sku,
                     cpq, sku_description, item_id,
                     NVL (flow_quantity, 0) flow_quantity, NVL (case_quantity, 0) case_quantity, NVL (truck_quantity, 0) truck_quantity,
                     NVL (dockdoor_quantity, 0) dockdoor_quantity, NVL (free_atr, 0) free_atr, NVL (supply_quantity, 0) supply_quantity,
                     NVL (free_atp, 0) free_atp, NVL (released_iso_quantity, 0) released_iso_quantity, NVL (released_priority_1, 0) released_priority_1,
                     NVL (released_other_priority, 0) released_other_priority, NVL (unreleased_iso_quantity, 0) unreleased_iso_quantity, NVL (dest_org_demand_first_n_days, 0) dest_org_demand_first_n_days,
                     NVL (dest_org_demand_second_n_days, 0) dest_org_demand_second_n_days, NVL (dest_org_demand_beyond, 0) dest_org_demand_beyond
                FROM (SELECT mp.organization_code
                                 organization,
                             xdiv.brand,
                             xdiv.item_number
                                 sku,
                             msib.inventory_item_id
                                 item_id,
                             (SELECT DISTINCT muc.conversion_rate
                                FROM apps.mtl_uom_conversions muc
                               WHERE     muc.inventory_item_id =
                                         msib.inventory_item_id
                                     AND muc.inventory_item_id <> 0
                                     AND muc.disable_date IS NULL
                                     AND muc.uom_code = 'CSE')
                                 cpq,
                             REGEXP_REPLACE (xdiv.item_description,
                                             '[^0-9A-Za-z ]')
                                 sku_description,
                             (SELECT SUM (transaction_quantity)
                                FROM apps.mtl_onhand_quantities_detail
                               WHERE     subinventory_code IN ('FLOW', 'FLOW2')
                                     AND organization_id = msib.organization_id
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 flow_quantity,
                             (SELECT SUM (transaction_quantity)
                                FROM apps.mtl_onhand_quantities_detail
                               WHERE     subinventory_code IN
                                             ('BULK', 'RSV', 'BULK4')
                                     AND organization_id = msib.organization_id
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 case_quantity,
                             (SELECT SUM (transaction_quantity)
                                FROM apps.mtl_onhand_quantities_detail
                               WHERE     subinventory_code IN ('TRUCK')
                                     AND organization_id = msib.organization_id
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 truck_quantity,
                             0
                                 dockdoor_quantity,
                             apps.f_get_atr (msib.inventory_item_id, msib.organization_id, NULL
                                             , NULL)
                                 free_atr,
                             xxdo_wms_nh_inv_conversion.f_get_supply (
                                 msib.inventory_item_id,
                                 msib.organization_id,
                                 SYSDATE,
                                 TO_DATE (gv_transfer_date, 'DD-MON-YYYY'))
                                 supply_quantity,
                             (SELECT SUM (atp)
                                FROM xxdo.xxdo_atp_final atp
                               WHERE     atp.organization_id =
                                         msib.organization_id
                                     AND demand_class = '-1'
                                     AND atp.inventory_item_id =
                                         msib.inventory_item_id
                                     AND TRUNC (dte) = TRUNC (SYSDATE))
                                 free_atp,
                             (SELECT SUM (NVL (ordered_quantity, 0))
                                FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                               WHERE     flv.lookup_type =
                                         'XXDO_NH_BLANKET_ISO_LIST'
                                     AND flv.language = 'US'
                                     AND ooha.order_number = flv.lookup_code
                                     AND flv.enabled_flag = 'Y'
                                     AND ooha.header_id = oola.header_id
                                     AND oola.inventory_item_id =
                                         msib.inventory_item_id
                                     AND oola.ship_from_org_id =
                                         msib.organization_id
                                     AND oola.schedule_ship_date IS NOT NULL
                                     AND NVL (oola.open_flag, 'N') = 'Y'
                                     AND NVL (oola.cancelled_flag, 'N') = 'N'
                                     AND oola.line_category_code = 'ORDER'
                                     AND oola.flow_status_code =
                                         'AWAITING_SHIPPING')
                                 released_iso_quantity,
                             (SELECT SUM (NVL (ordered_quantity, 0))
                                FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                               WHERE     flv.lookup_type =
                                         'XXDO_NH_BLANKET_ISO_LIST'
                                     AND flv.language = 'US'
                                     AND NVL (flv.tag, '2') = '1'
                                     AND ooha.order_number = flv.lookup_code
                                     AND flv.enabled_flag = 'Y'
                                     AND ooha.header_id = oola.header_id
                                     AND oola.inventory_item_id =
                                         msib.inventory_item_id
                                     AND oola.ship_from_org_id =
                                         msib.organization_id
                                     AND oola.schedule_ship_date IS NOT NULL
                                     AND NVL (oola.open_flag, 'N') = 'Y'
                                     AND NVL (oola.cancelled_flag, 'N') = 'N'
                                     AND oola.line_category_code = 'ORDER'
                                     AND oola.flow_status_code =
                                         'AWAITING_SHIPPING')
                                 released_priority_1,
                             (SELECT SUM (NVL (ordered_quantity, 0))
                                FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                               WHERE     flv.lookup_type =
                                         'XXDO_NH_BLANKET_ISO_LIST'
                                     AND flv.language = 'US'
                                     AND NVL (flv.tag, '2') <> '1'
                                     AND ooha.order_number = flv.lookup_code
                                     AND flv.enabled_flag = 'Y'
                                     AND ooha.header_id = oola.header_id
                                     AND oola.inventory_item_id =
                                         msib.inventory_item_id
                                     AND oola.ship_from_org_id =
                                         msib.organization_id
                                     AND oola.schedule_ship_date IS NOT NULL
                                     AND NVL (oola.open_flag, 'N') = 'Y'
                                     AND NVL (oola.cancelled_flag, 'N') = 'N'
                                     AND oola.line_category_code = 'ORDER'
                                     AND oola.flow_status_code =
                                         'AWAITING_SHIPPING')
                                 released_other_priority,
                             (SELECT SUM (NVL (ordered_quantity, 0))
                                FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                               WHERE     flv.lookup_type =
                                         'XXDO_NH_BLANKET_ISO_LIST'
                                     AND flv.language = 'US'
                                     AND ooha.order_number = flv.lookup_code
                                     AND NVL (flv.enabled_flag, 'N') = 'N'
                                     AND ooha.header_id = oola.header_id
                                     AND oola.inventory_item_id =
                                         msib.inventory_item_id
                                     AND oola.ship_from_org_id =
                                         msib.organization_id
                                     AND oola.schedule_ship_date IS NOT NULL
                                     AND NVL (oola.open_flag, 'N') = 'Y'
                                     AND NVL (oola.cancelled_flag, 'N') = 'N'
                                     AND oola.line_category_code = 'ORDER'
                                     AND oola.flow_status_code =
                                         'AWAITING_SHIPPING')
                                 unreleased_iso_quantity,
                             (SELECT SUM (ordered_quantity)
                                FROM apps.oe_order_lines_all
                               WHERE     TRUNC (schedule_ship_date) BETWEEN TO_DATE (
                                                                                gv_transfer_date,
                                                                                'DD-MON-YYYY')
                                                                        AND   TO_DATE (
                                                                                  gv_transfer_date,
                                                                                  'DD-MON-YYYY')
                                                                            + pn_first_n_days
                                     AND ship_from_org_id = pv_dest_org
                                     AND schedule_ship_date IS NOT NULL
                                     AND NVL (open_flag, 'N') = 'Y'
                                     AND NVL (cancelled_flag, 'N') = 'N'
                                     AND line_category_code = 'ORDER'
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 dest_org_demand_first_n_days,
                             (SELECT SUM (ordered_quantity)
                                FROM apps.oe_order_lines_all
                               WHERE     TRUNC (schedule_ship_date) BETWEEN   TO_DATE (
                                                                                  gv_transfer_date,
                                                                                  'DD-MON-YYYY')
                                                                            + pn_first_n_days
                                                                            + 1
                                                                        AND   TO_DATE (
                                                                                  gv_transfer_date,
                                                                                  'DD-MON-YYYY')
                                                                            + pn_second_n_days
                                     AND ship_from_org_id = pv_dest_org
                                     AND schedule_ship_date IS NOT NULL
                                     AND NVL (open_flag, 'N') = 'Y'
                                     AND NVL (cancelled_flag, 'N') = 'N'
                                     AND line_category_code = 'ORDER'
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 dest_org_demand_second_n_days,
                             (SELECT SUM (ordered_quantity)
                                FROM apps.oe_order_lines_all
                               WHERE     TRUNC (schedule_ship_date) >=
                                           TO_DATE (gv_transfer_date,
                                                    'DD-MON-YYYY')
                                         + pn_second_n_days
                                         + 1
                                     AND ship_from_org_id = pv_dest_org
                                     AND schedule_ship_date IS NOT NULL
                                     AND NVL (open_flag, 'N') = 'Y'
                                     AND NVL (cancelled_flag, 'N') = 'N'
                                     AND line_category_code = 'ORDER'
                                     AND inventory_item_id =
                                         msib.inventory_item_id)
                                 dest_org_demand_beyond
                        FROM apps.xxd_common_items_v xdiv, apps.mtl_parameters mp, apps.mtl_system_items_b msib
                       WHERE     xdiv.organization_id = pv_src_org
                             AND brand = UPPER (pv_brand)
                             AND xdiv.organization_id = mp.organization_id
                             AND xdiv.organization_id = msib.organization_id
                             AND xdiv.item_number = msib.segment1
                             AND msib.enabled_flag = 'Y'
                             AND msib.inventory_item_id IN
                                     (SELECT DISTINCT item_id inventory_item_id
                                        FROM apps.mtl_supply
                                       WHERE to_organization_id = pv_src_org
                                      UNION
                                      SELECT DISTINCT inventory_item_id
                                        FROM apps.mtl_onhand_quantities_detail
                                       WHERE organization_id = pv_src_org
                                      UNION
                                      SELECT DISTINCT oola.inventory_item_id
                                        FROM apps.oe_order_lines_all oola, apps.fnd_lookup_values flv, apps.oe_order_headers_all ooha
                                       WHERE     flv.lookup_type =
                                                 'XXDO_NH_BLANKET_ISO_LIST'
                                             AND flv.language = 'US'
                                             AND ooha.order_number =
                                                 flv.lookup_code
                                             AND ooha.header_id =
                                                 oola.header_id
                                             AND oola.ship_from_org_id =
                                                 pv_src_org
                                             AND oola.schedule_ship_date
                                                     IS NOT NULL
                                             AND NVL (oola.open_flag, 'N') =
                                                 'Y'
                                             AND NVL (oola.cancelled_flag, 'N') =
                                                 'N'
                                             AND oola.line_category_code =
                                                 'ORDER'
                                             AND oola.flow_status_code =
                                                 'AWAITING_SHIPPING'))
            ORDER BY released_iso_quantity DESC;

        TYPE t_get_inventory_data_rec IS TABLE OF get_inventory_data%ROWTYPE
            INDEX BY PLS_INTEGER;

        l_get_inventory_data_rec   t_get_inventory_data_rec;
        lv_include_free_atp        VARCHAR2 (1);
        ln_max_transfer_quantity   NUMBER;
        ln_free_atp                NUMBER;
        ln_truck_quantity          NUMBER;
        lv_src_org                 VARCHAR2 (10);
        lv_dest_org                VARCHAR2 (10);
    BEGIN
        BEGIN
            SELECT organization_code
              INTO lv_src_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pv_src_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_src_org   := NULL;
        END;

        BEGIN
            SELECT organization_code
              INTO lv_dest_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pv_dest_org;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dest_org   := NULL;
        END;

        BEGIN
            SELECT flv.meaning
              INTO gv_transfer_date
              FROM apps.fnd_lookup_values flv
             WHERE     flv.lookup_type = 'XXDO_NH_INV_TRANSFER_DATE'
                   AND flv.language = 'US'
                   AND flv.lookup_code = lv_src_org
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                insert_message (
                    'LOG',
                    'No Transfer Date defined for the Org in the Lookup');
        END;

        insert_message ('LOG', 'Brand: ' || UPPER (pv_brand));
        insert_message ('LOG', 'Source Org: ' || lv_src_org);
        insert_message ('LOG', 'Destination Org: ' || lv_dest_org);
        insert_message ('LOG', 'Transfer Date: ' || gv_transfer_date);

        BEGIN
            SELECT flv.tag
              INTO lv_include_free_atp
              FROM apps.fnd_lookup_values flv, apps.org_organization_definitions ood
             WHERE     flv.lookup_type = 'XXDO_INCLUDE_FREE_ATP'
                   AND flv.language = 'US'
                   AND flv.lookup_code = ood.organization_code
                   AND ood.organization_id = pv_src_org
                   AND NVL (flv.enabled_flag, 'N') = 'Y';
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_include_free_atp   := 'N';
                ln_free_atp           := 0;
        END;


        OPEN get_inventory_data;

        FETCH get_inventory_data BULK COLLECT INTO l_get_inventory_data_rec;

        CLOSE get_inventory_data;

        IF l_get_inventory_data_rec.COUNT > 0
        THEN
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<?xml version="1.0"?>');
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<ATPINFO>');


            FOR i IN 1 .. l_get_inventory_data_rec.COUNT
            LOOP
                BEGIN
                    SELECT MAX (expected_delivery_date)
                      INTO ld_max_supply_date
                      FROM apps.mtl_supply
                     WHERE     to_organization_id = pv_src_org
                           AND item_id = l_get_inventory_data_rec (i).item_id
                           AND TRUNC (expected_delivery_date) BETWEEN TRUNC (
                                                                          SYSDATE)
                                                                  AND TO_DATE (
                                                                          gv_transfer_date,
                                                                          'DD-MON-YYYY');
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ld_max_supply_date   := NULL;
                END;

                IF lv_include_free_atp = 'Y'
                THEN
                    ln_free_atp   := l_get_inventory_data_rec (i).free_atp;
                ELSE
                    ln_free_atp   := 0;
                END IF;

                ln_truck_quantity   :=
                    NVL (l_get_inventory_data_rec (i).truck_quantity, 0);

                ln_max_transfer_quantity   :=
                    LEAST (
                        GREATEST (
                              (l_get_inventory_data_rec (i).released_iso_quantity + ln_free_atp)
                            - NVL (
                                  l_get_inventory_data_rec (i).supply_quantity,
                                  0),
                            0),
                        l_get_inventory_data_rec (i).free_atr,
                        NVL (l_get_inventory_data_rec (i).case_quantity, 0));

                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '<G_ITEM_DETAILS>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<ORGANIZATION>'
                    || l_get_inventory_data_rec (i).organization
                    || '</ORGANIZATION>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<BRAND>'
                    || l_get_inventory_data_rec (i).brand
                    || '</BRAND>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                    '<SKU>' || l_get_inventory_data_rec (i).sku || '</SKU>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<SKU_DESCRIPTION>'
                    || l_get_inventory_data_rec (i).sku_description
                    || '</SKU_DESCRIPTION>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                    '<CPQ>' || l_get_inventory_data_rec (i).cpq || '</CPQ>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<FLOW_QUANTITY>'
                    || l_get_inventory_data_rec (i).flow_quantity
                    || '</FLOW_QUANTITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<CASE_QUANTITY>'
                    || l_get_inventory_data_rec (i).case_quantity
                    || '</CASE_QUANTITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<TRUCK_QUANTITY>'
                    || l_get_inventory_data_rec (i).truck_quantity
                    || '</TRUCK_QUANTITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DOCK_DOOR_QTY>'
                    || l_get_inventory_data_rec (i).dockdoor_quantity
                    || '</DOCK_DOOR_QTY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<FREE_ATR>'
                    || l_get_inventory_data_rec (i).free_atr
                    || '</FREE_ATR>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<SUPPLY_TILL_TRANSFER_DATE>'
                    || l_get_inventory_data_rec (i).supply_quantity
                    || '</SUPPLY_TILL_TRANSFER_DATE>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<MAX_SUPPLY_DATE>'
                    || ld_max_supply_date
                    || '</MAX_SUPPLY_DATE>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<FREE_ATP>'
                    || l_get_inventory_data_rec (i).free_atp
                    || '</FREE_ATP>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<RELEASED_QTY_PRIORITY_1>'
                    || l_get_inventory_data_rec (i).released_priority_1
                    || '</RELEASED_QTY_PRIORITY_1>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<RELEASED_QTY_OTHER_PRIORITY>'
                    || l_get_inventory_data_rec (i).released_other_priority
                    || '</RELEASED_QTY_OTHER_PRIORITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<UNRELEASED_ISO_QUANTITY>'
                    || l_get_inventory_data_rec (i).unreleased_iso_quantity
                    || '</UNRELEASED_ISO_QUANTITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<MAXIMUM_TRANSFER_QUANITY>'
                    || ln_max_transfer_quantity
                    || '</MAXIMUM_TRANSFER_QUANITY>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DEST_ORG_DEMAND_FIRST_N_DAYS>'
                    || l_get_inventory_data_rec (i).dest_org_demand_first_n_days
                    || '</DEST_ORG_DEMAND_FIRST_N_DAYS>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DEST_ORG_DEMAND_SECOND_N_DAYS>'
                    || l_get_inventory_data_rec (i).dest_org_demand_second_n_days
                    || '</DEST_ORG_DEMAND_SECOND_N_DAYS>');
                FND_FILE.PUT_LINE (
                    FND_FILE.OUTPUT,
                       '<DEST_ORG_DEMAND_BEYOND>'
                    || l_get_inventory_data_rec (i).dest_org_demand_beyond
                    || '</DEST_ORG_DEMAND_BEYOND>');
                FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</G_ITEM_DETAILS>');
            END LOOP;

            FND_FILE.PUT_LINE (FND_FILE.OUTPUT, '</ATPINFO>');
        ELSE
            FND_FILE.PUT_LINE (FND_FILE.OUTPUT,
                               'File is not generated as there is no data ');
        END IF;
    EXCEPTION
        WHEN UTL_FILE.invalid_operation
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid operation');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.invalid_path
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid path');
            UTL_FILE.fclose_all;
            x_retcode   := gn_error;
        WHEN UTL_FILE.invalid_mode
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid mode');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.invalid_filehandle
        THEN
            fnd_file.put_line (fnd_file.LOG, 'invalid filehandle');
            UTL_FILE.fclose_all;
        WHEN UTL_FILE.read_error
        THEN
            fnd_file.put_line (fnd_file.LOG, 'read error');
            UTL_FILE.fclose_all;
            x_retcode   := gn_error;
        WHEN UTL_FILE.internal_error
        THEN
            fnd_file.put_line (fnd_file.LOG, 'internal error');
            UTL_FILE.fclose_all;
            x_retcode   := gn_error;
        WHEN OTHERS
        THEN
            x_retcode   := gn_warning;
            fnd_file.put_line (fnd_file.LOG, 'other error: ' || SQLERRM);
            UTL_FILE.fclose_all;
    END nh_inventory_report;

    PROCEDURE update_location_status (pn_src_org_id IN NUMBER, pv_src_locator IN VARCHAR2, pn_locator_status IN NUMBER)
    IS
        CURSOR cur_location_details IS
            SELECT ood.organization_code, mil.inventory_location_id, mil.description,
                   mil.inventory_location_type, mil.pick_uom_code
              FROM apps.mtl_item_locations_kfv mil, apps.org_organization_definitions ood
             WHERE     concatenated_segments = pv_src_locator
                   AND mil.organization_id = pn_src_org_id
                   AND mil.organization_id = ood.organization_id;

        l_return_status   VARCHAR2 (100);
        l_msg_count       NUMBER;
        l_msg_data        VARCHAR2 (100);
    BEGIN
        FOR rec_loc_details IN cur_location_details
        LOOP
            inv_loc_wms_pub.UPDATE_LOCATOR (
                x_return_status              => l_return_status,
                x_msg_count                  => l_msg_count,
                x_msg_data                   => l_msg_data,
                p_organization_id            => pn_src_org_id,
                p_organization_code          => rec_loc_details.organization_code,
                p_inventory_location_id      =>
                    rec_loc_details.inventory_location_id,
                p_concatenated_segments      => pv_src_locator,
                p_description                => rec_loc_details.description,
                p_disabled_date              => NULL,
                p_inventory_location_type    =>
                    rec_loc_details.inventory_location_type,
                p_picking_order              => NULL,
                p_location_maximum_units     => NULL,
                p_location_Weight_uom_code   => NULL,
                p_max_weight                 => NULL,
                p_volume_uom_code            => NULL,
                p_max_cubic_area             => NULL,
                p_x_coordinate               => NULL,
                p_y_coordinate               => NULL,
                p_z_coordinate               => NULL,
                p_physical_location_id       => NULL,
                p_pick_uom_code              => rec_loc_details.pick_uom_code,
                p_dimension_uom_code         => NULL,
                p_length                     => NULL,
                p_width                      => NULL,
                p_height                     => NULL,
                p_status_id                  => pn_locator_status,
                p_dropping_order             => NULL,
                p_attribute_category         => NULL,
                p_attribute1                 => NULL,
                p_attribute2                 => NULL,
                p_attribute3                 => NULL,
                p_attribute4                 => NULL,
                p_attribute5                 => NULL,
                p_attribute6                 => NULL,
                p_attribute7                 => NULL,
                p_attribute8                 => NULL,
                p_attribute9                 => NULL,
                p_attribute10                => NULL,
                p_attribute11                => NULL,
                p_attribute12                => NULL,
                p_attribute13                => NULL,
                p_attribute14                => NULL,
                p_attribute15                => NULL,
                p_alias                      => NULL);

            IF l_return_status = 'S'
            THEN
                insert_message (
                    'LOG',
                       'Locator Status updated successfully:'
                    || pv_src_locator
                    || 'to '
                    || pn_locator_status);
                COMMIT;
            END IF;
        END LOOP;
    END update_location_status;

    /* CCR0007600 New program to validate Truck Location */
    PROCEDURE validate_locator (pv_errbuf OUT VARCHAR2, pv_retcode OUT VARCHAR2, pv_brand IN VARCHAR2, pn_src_org_id IN NUMBER, pv_src_subinv IN VARCHAR2, pv_src_locator IN VARCHAR2, pv_dock_door IN VARCHAR2, pn_dest_org_id IN NUMBER, pv_dest_subinv IN VARCHAR2
                                , pv_dest_locator IN VARCHAR2)
    AS
        lv_src_org         VARCHAR2 (10);
        lv_dest_org        VARCHAR2 (10);
        lv_return_status   VARCHAR2 (1) := 'S';
        ln_dock_door_id    NUMBER;
        ln_org_id          NUMBER;
    BEGIN
        BEGIN
            SELECT organization_code, operating_unit
              INTO lv_src_org, ln_org_id
              FROM apps.org_organization_definitions
             WHERE organization_id = pn_src_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_src_org   := NULL;
        END;

        BEGIN
            SELECT organization_code
              INTO lv_dest_org
              FROM apps.org_organization_definitions
             WHERE organization_id = pn_dest_org_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_dest_org   := NULL;
        END;

        gn_org_id      := ln_org_id;

        insert_message ('BOTH', 'Locator Validation Program');
        insert_message ('BOTH', 'Validation Time: ' || SYSDATE);
        insert_message ('BOTH', 'User Name: ' || gv_user_name);

        insert_message (
            'BOTH',
            '+------------------------------- Parameters --------------------------------+');

        insert_message ('BOTH', 'Brand: ' || UPPER (pv_brand));
        insert_message ('BOTH', 'Source Org: ' || lv_src_org);
        insert_message ('BOTH', 'Source Subinventory: ' || pv_src_subinv);
        insert_message ('BOTH', 'Source Locator: ' || pv_src_locator);
        insert_message ('BOTH', 'Dock Door: ' || pv_dock_door);
        insert_message ('BOTH', 'Destination Org: ' || lv_dest_org);
        insert_message ('BOTH',
                        'Destination Subinventory: ' || pv_dest_subinv);

        insert_message (
            'BOTH',
            '+---------------------------------------------------------------------------+');

        gv_src_org     := lv_src_org;
        gv_dest_org    := lv_dest_org;
        gv_dock_door   := pv_dock_door;

        lv_return_status   :=
            validate_data (UPPER (pv_brand), pn_src_org_id, pv_src_subinv,
                           pv_src_locator, pn_dest_org_id);

        IF lv_return_status <> 'S'
        THEN
            pv_retcode   := 2;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                'Unexpected error while Locator Validation :' || SQLERRM);
    END validate_locator;
END XXDO_WMS_NH_INV_CONVERSION;
/
