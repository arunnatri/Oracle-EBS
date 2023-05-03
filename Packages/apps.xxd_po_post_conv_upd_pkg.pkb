--
-- XXD_PO_POST_CONV_UPD_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:27:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_PO_POST_CONV_UPD_PKG"
AS
    /*************************************************************************************************/
    /*                                                                                               */
    /* $Header: XXD_PO_POST_CONV_UPD_PKG.pkb 1.0 05/05/2014 PwC  $                                   */
    /*                                                                                               */
    /* PACKAGE NAME:  XXD_PO_POST_CONV_UPD_PKG                                                       */
    /*                                                                                               */
    /* PROGRAM NAME:  Deckers Cross Dock PO Update Program                                           */
    /*                                                                                               */
    /* DEPENDENCIES: NA                                                                              */
    /*                                                                                               */
    /* REFERENCED BY: NA                                                                             */
    /*                                                                                               */
    /* DESCRIPTION          : Package body for Cross Dock PO Update Program                          */
    /*                                                                                               */
    /* HISTORY:                                                                                      */
    /*-----------------------------------------------------------------------------------------------*/
    /* Verson Num       Developer          Date           Description                                */
    /*                                                                                               */
    /*-----------------------------------------------------------------------------------------------*/
    /* 1.0              PwC                05-May-2015    Initial Version                            */
    /*-----------------------------------------------------------------------------------------------*/
    /*                                                                                               */
    /*************************************************************************************************/

    gn_user_id      NUMBER := fnd_global.user_id;
    gn_request_id   NUMBER := fnd_global.conc_request_id;
    gn_login_id     NUMBER := fnd_global.login_id;
    gn_success      NUMBER := 0;
    gn_warning      NUMBER := 1;
    gn_error        NUMBER := 2;

    PROCEDURE print_log (p_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.LOG, p_message);
    END print_log;

    PROCEDURE print_output (p_message IN VARCHAR2)
    IS
    BEGIN
        fnd_file.put_line (fnd_file.output, p_message);
    END print_output;

    PROCEDURE get_locator (p_org_id IN NUMBER, p_locator_id OUT NOCOPY NUMBER, p_locator OUT NOCOPY VARCHAR2
                           , p_error OUT NOCOPY VARCHAR2)
    IS
    BEGIN
        SELECT MIN (inventory_location_id)
          INTO p_locator_id
          FROM mtl_item_locations
         WHERE     subinventory_code = 'XDOCK'
               AND organization_id = p_org_id
               AND empty_flag = 'Y'
               AND enabled_flag = 'Y'
               AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                               NVL (start_date_active,
                                                    SYSDATE))
                                       AND TRUNC (
                                               NVL (end_date_active, SYSDATE))
               --Locator Reservation
               AND NOT EXISTS
                       (SELECT 1
                          FROM xxd_ont_special_vas_info_t
                         WHERE     vas_status IN ('N', 'C')
                               AND inventory_org_id = p_org_id
                               AND demand_locator_id = inventory_location_id);

        BEGIN
            SELECT concatenated_segments
              INTO p_locator
              FROM mtl_item_locations_kfv
             WHERE inventory_location_id = p_locator_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                p_error   := 'Unable to derive the Demand Locator';
                fnd_file.put_line (
                    fnd_file.LOG,
                       'In get_locator excep. '
                    || SQLERRM
                    || DBMS_UTILITY.format_error_stack ()
                    || DBMS_UTILITY.format_error_backtrace ());
        END;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_error   := 'Unable to derive the Demand Locator';
            fnd_file.put_line (
                fnd_file.LOG,
                   'In get_locator excep. '
                || SQLERRM
                || DBMS_UTILITY.format_error_stack ()
                || DBMS_UTILITY.format_error_backtrace ());
    END get_locator;

    PROCEDURE cross_dock_po_upd_prc (x_return_mesg      OUT NOCOPY VARCHAR2,
                                     x_ret_code         OUT NOCOPY NUMBER)
    IS
        CURSOR get_cross_dock_po_dtls_c IS
              SELECT poh.segment1 po_number, pol.line_num po_line_num, poh.po_header_id,
                     pol.po_line_id, poll.line_location_id po_line_location_id, pod.po_distribution_id,
                     ooha.order_number so_number, oola.line_number so_line_num, ooha.header_id so_header_id,
                     oola.line_id so_line_id
                FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                     po_distributions_all pod, xxd_conv.xxd_po_headers_conv_1206 poh1, xxd_conv.xxd_po_lines_conv_1206 pol1,
                     xxd_conv.xxd_po_distributions_conv_1206 pod1, oe_order_headers_all ooha, oe_order_lines_all oola,
                     xxd_conv.xxd_1206_oe_order_headers_all xoh, xxd_conv.xxd_1206_oe_order_lines_all xol
               WHERE     poh.po_header_id = pol.po_header_id
                     AND poh.po_header_id = poll.po_header_id
                     AND pol.po_line_id = poll.po_line_id
                     AND poh.po_header_id = pod.po_header_id
                     AND pol.po_line_id = pod.po_line_id
                     AND poll.line_location_id = pod.line_location_id
                     AND poh1.po_header_id = pol1.po_header_id
                     AND pol1.po_line_id = pod1.po_line_id
                     AND poh1.po_number = poh.segment1
                     AND pol1.line_num = pol.line_num
                     AND ooha.header_id = oola.header_id
                     AND xoh.header_id = xol.header_id
                     AND ooha.order_number = xoh.order_number
                     --AND oola.line_number = xol.line_number
                     AND oola.orig_sys_line_ref = xol.orig_sys_line_ref
                     AND xol.project_id = pod1.project_id
                     AND oola.inventory_item_id = pol.item_id
                     AND oola.ordered_quantity = pol.quantity
                     AND xol.project_id IS NOT NULL
                     AND oola.open_flag = 'Y'
                     AND NVL (poh.cancel_flag, 'N') = 'N'
                     AND NVL (pol.cancel_flag, 'N') = 'N'
                     AND (TO_CHAR (poll.line_location_id) <> NVL (oola.attribute15, '-1') OR TO_CHAR (oola.line_id) <> NVL (poll.attribute15, '-1'))
            ORDER BY so_number, so_line_num, po_number,
                     po_line_num;

        CURSOR get_error_xdock_so_dtls (p_so_header_id NUMBER)
        IS
              SELECT ooha.header_id so_header_id
                FROM po_headers_all poh, po_lines_all pol, po_line_locations_all poll,
                     po_distributions_all pod, xxd_conv.xxd_po_headers_conv_1206 poh1, xxd_conv.xxd_po_lines_conv_1206 pol1,
                     xxd_conv.xxd_po_distributions_conv_1206 pod1, oe_order_headers_all ooha, oe_order_lines_all oola,
                     xxd_conv.xxd_1206_oe_order_headers_all xoh, xxd_conv.xxd_1206_oe_order_lines_all xol
               WHERE     poh.po_header_id = pol.po_header_id
                     AND poh.po_header_id = poll.po_header_id
                     AND pol.po_line_id = poll.po_line_id
                     AND poh.po_header_id = pod.po_header_id
                     AND pol.po_line_id = pod.po_line_id
                     AND poll.line_location_id = pod.line_location_id
                     AND poh1.po_header_id = pol1.po_header_id
                     AND pol1.po_line_id = pod1.po_line_id
                     AND poh1.po_number = poh.segment1
                     AND pol1.line_num = pol.line_num
                     AND ooha.header_id = oola.header_id
                     AND xoh.header_id = xol.header_id
                     AND ooha.order_number = xoh.order_number
                     --AND oola.line_number = xol.line_number
                     AND oola.orig_sys_line_ref = xol.orig_sys_line_ref
                     AND xol.project_id = pod1.project_id
                     AND oola.inventory_item_id = pol.item_id
                     AND oola.ordered_quantity <> pol.quantity
                     AND xol.project_id IS NOT NULL
                     AND oola.open_flag = 'Y'
                     AND NVL (poh.cancel_flag, 'N') = 'N'
                     AND NVL (pol.cancel_flag, 'N') = 'N'
                     AND ooha.header_id = NVL (p_so_header_id, ooha.header_id)
            GROUP BY ooha.header_id;

        CURSOR get_specival_vas_rec_dtls IS
            SELECT xxdo.xxd_ont_special_vas_info_s.NEXTVAL vas_id, ooha.header_id order_header_id, ooha.order_number,
                   ooha.ordered_date, ooha.flow_status_code order_status, ooha.org_id,
                   ooha.ship_to_org_id, xrcv.customer_name, ooha.attribute5 brand,
                   ooha.transactional_curr_code currency_code, oola.line_id order_line_id, oola.line_number order_line_num,
                   oola.inventory_item_id, oola.ordered_item, oola.ordered_quantity,
                   oola.request_date, oola.schedule_ship_date, oola.flow_status_code order_line_status,
                   TO_DATE (fnd_date.canonical_to_date (oola.attribute1)) order_line_cancel_date, oola.order_quantity_uom, oola.request_date need_by_date,
                   0 attachments_count, mp.organization_code inventory_org_code, mp.organization_id inventory_org_id,
                   'C' vas_status, NULL error_message, pav.agent_id buyer_id,
                   pav.agent_name buyer_name, 'XDOCK' demand_subinventory, hr.ship_to_location_id,
                   msib.list_price_per_unit, aps.vendor_id, aps.vendor_name,
                   apss.vendor_site_id, apss.vendor_site_code, poh.po_header_id,
                   pol.po_line_id, poh.segment1 po_number, pol.line_num po_line_num,
                   pol.quantity po_ordered_qty, poll.line_location_id supply_identifier, fnd_date.canonical_to_date (poh.attribute1) xfactory_date,
                   gn_request_id request_id, SYSDATE creation_date, gn_user_id created_by,
                   SYSDATE last_update_date, gn_user_id last_updated_by
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, mtl_parameters mp,
                   hr_locations_all hr, mtl_system_items_b msib, po_agents_v pav,
                   xxd_ra_customers_v xrcv, ap_suppliers aps, ap_supplier_sites_all apss,
                   po_headers_all poh, po_lines_all pol, po_line_locations_all poll
             WHERE     ooha.header_id = oola.header_id
                   AND oola.ship_from_org_id = mp.organization_id
                   AND oola.open_flag = 'Y'
                   AND oola.ship_from_org_id = hr.inventory_organization_id
                   AND hr.ship_to_site_flag = 'Y'
                   AND oola.inventory_item_id = msib.inventory_item_id
                   AND msib.organization_id = oola.ship_from_org_id
                   AND pav.agent_name(+) = 'VAS - ' || ooha.attribute5 || ','
                   AND poh.vendor_id = aps.vendor_id
                   AND poh.vendor_site_id = apss.vendor_site_id
                   AND aps.vendor_id = apss.vendor_id
                   AND poh.po_header_id = pol.po_header_id
                   AND poh.po_header_id = poll.po_header_id
                   AND NVL (poh.cancel_flag, 'N') = 'N'
                   AND NVL (pol.cancel_flag, 'N') = 'N'
                   AND pol.po_line_id = poll.po_line_id
                   AND TO_CHAR (poll.line_location_id) = oola.attribute15
                   AND TO_CHAR (oola.line_id) = poll.attribute15
                   AND xrcv.customer_id = ooha.sold_to_org_id
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_ont_special_vas_info_t xosvit
                             WHERE     ooha.header_id =
                                       xosvit.order_header_id
                                   AND oola.line_id = xosvit.order_line_id);

        CURSOR get_wms_orgs_c (
            p_org_id IN mtl_parameters.organization_id%TYPE)
        IS
            SELECT COUNT (1)
              FROM mtl_parameters
             WHERE wms_enabled_flag = 'Y' AND organization_id = p_org_id;

        CURSOR get_locator_c (p_order_header_id NUMBER)
        IS
            SELECT demand_locator_id, demand_locator
              FROM xxd_ont_special_vas_info_t
             WHERE order_header_id = p_order_header_id;

        ln_locator_id           NUMBER;
        lc_locator              VARCHAR2 (4000);
        lc_locator_error        VARCHAR2 (4000);
        ln_wms_org              NUMBER;
        ln_po_upd_success_cnt   NUMBER := 0;
        ln_po_upd_error_cnt     NUMBER := 0;
        ln_so_upd_success_cnt   NUMBER := 0;
        ln_so_upd_error_cnt     NUMBER := 0;
        ln_so_header_id         NUMBER;
        ln_specival_vas_cnt     NUMBER := 0;
    BEGIN
        FOR lcu_cross_dock_po_dtls_rec IN get_cross_dock_po_dtls_c
        LOOP
            print_log ('');
            print_log (RPAD ('*', 20, '*'));
            print_log (
                'SO Number : ' || lcu_cross_dock_po_dtls_rec.so_number);
            print_log (
                'SO Line Number : ' || lcu_cross_dock_po_dtls_rec.so_line_num);
            print_log (
                'PO Number : ' || lcu_cross_dock_po_dtls_rec.po_number);
            print_log (
                'PO Line Number : ' || lcu_cross_dock_po_dtls_rec.po_line_num);

            ln_so_header_id   := NULL;

            OPEN get_error_xdock_so_dtls (
                p_so_header_id => lcu_cross_dock_po_dtls_rec.so_header_id);

            FETCH get_error_xdock_so_dtls INTO ln_so_header_id;

            CLOSE get_error_xdock_so_dtls;

            IF ln_so_header_id IS NULL
            THEN
                BEGIN
                    UPDATE po_line_locations_all
                       SET attribute15 = lcu_cross_dock_po_dtls_rec.so_line_id, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                           last_update_login = gn_login_id
                     WHERE line_location_id =
                           lcu_cross_dock_po_dtls_rec.po_line_location_id;

                    UPDATE po_headers_all
                       SET attribute4 = lcu_cross_dock_po_dtls_rec.so_number, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                           last_update_login = gn_login_id
                     WHERE po_header_id =
                           lcu_cross_dock_po_dtls_rec.po_header_id;

                    ln_po_upd_success_cnt   := ln_po_upd_success_cnt + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_po_upd_error_cnt   := ln_po_upd_error_cnt + 1;
                        print_log (
                               'Error while updating PO line location : '
                            || lcu_cross_dock_po_dtls_rec.po_line_location_id
                            || ' - '
                            || SQLCODE
                            || ' : '
                            || SQLERRM);
                END;

                BEGIN
                    UPDATE oe_order_lines_all
                       SET attribute15 = lcu_cross_dock_po_dtls_rec.po_line_location_id, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                           last_update_login = gn_login_id
                     WHERE line_id = lcu_cross_dock_po_dtls_rec.so_line_id;

                    ln_so_upd_success_cnt   := ln_so_upd_success_cnt + 1;
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_so_upd_error_cnt   := ln_so_upd_error_cnt + 1;
                        print_log (
                               'Error while updating SO line : '
                            || lcu_cross_dock_po_dtls_rec.so_line_id
                            || ' - '
                            || SQLCODE
                            || ' : '
                            || SQLERRM);
                END;
            ELSE
                print_log (
                    'PO and SO do not have one-to-one relationship, skipping the record from Cross dock linking');
            END IF;
        END LOOP;

        COMMIT;

        print_log ('');
        print_log (RPAD ('*', 20, '*'));
        print_log ('Update sales order with default value');

        FOR lcu_error_xdock_so_dtls
            IN get_error_xdock_so_dtls (p_so_header_id => NULL)
        LOOP
            print_log (
                'SO Header ID : ' || lcu_error_xdock_so_dtls.so_header_id);

            BEGIN
                UPDATE oe_order_lines_all
                   SET attribute15 = '999999999', last_updated_by = gn_user_id, last_update_date = SYSDATE,
                       last_update_login = gn_login_id
                 WHERE header_id = lcu_error_xdock_so_dtls.so_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           'Error while updating SO with default value : '
                        || lcu_error_xdock_so_dtls.so_header_id
                        || ' - '
                        || SQLCODE
                        || ' : '
                        || SQLERRM);
            END;
        END LOOP;

        COMMIT;

        print_log ('');
        print_log (RPAD ('*', 20, '*'));
        print_log ('Insert data into xxd_ont_special_vas_info_t');

        FOR lcu_specival_vas_rec_dtls IN get_specival_vas_rec_dtls
        LOOP
            ln_locator_id      := NULL;
            lc_locator         := NULL;
            lc_locator_error   := NULL;

            OPEN get_locator_c (lcu_specival_vas_rec_dtls.order_header_id);

            FETCH get_locator_c INTO ln_locator_id, lc_locator;

            IF get_locator_c%NOTFOUND
            THEN
                OPEN get_wms_orgs_c (
                    lcu_specival_vas_rec_dtls.inventory_org_id);

                FETCH get_wms_orgs_c INTO ln_wms_org;

                CLOSE get_wms_orgs_c;

                -- Locator Assignment is only for WMS Orgs
                IF ln_wms_org > 0
                THEN
                    get_locator (lcu_specival_vas_rec_dtls.inventory_org_id, ln_locator_id, lc_locator
                                 , lc_locator_error);

                    IF lc_locator_error IS NOT NULL
                    THEN
                        ln_locator_id   := NULL;
                        lc_locator      := NULL;
                    END IF;
                END IF;
            END IF;

            CLOSE get_locator_c;

            BEGIN
                INSERT INTO xxd_ont_special_vas_info_t (vas_id, order_header_id, order_number, ordered_date, order_status, org_id, ship_to_org_id, customer_name, brand, currency_code, order_line_id, order_line_num, inventory_item_id, ordered_item, ordered_quantity, request_date, schedule_ship_date, order_line_status, order_line_cancel_date, order_quantity_uom, need_by_date, attachments_count, inventory_org_code, inventory_org_id, vas_status, error_message, buyer_id, buyer_name, demand_subinventory, ship_to_location_id, list_price_per_unit, vendor_id, vendor_name, vendor_site_id, vendor_site, po_header_id, po_line_id, po_number, po_line_num, po_ordered_qty, supply_identifier, xfactory_date, demand_locator_id, demand_locator, request_id, creation_date, created_by, last_update_date
                                                        , last_updated_by)
                     VALUES (lcu_specival_vas_rec_dtls.vas_id, lcu_specival_vas_rec_dtls.order_header_id, lcu_specival_vas_rec_dtls.order_number, lcu_specival_vas_rec_dtls.ordered_date, lcu_specival_vas_rec_dtls.order_status, lcu_specival_vas_rec_dtls.org_id, lcu_specival_vas_rec_dtls.ship_to_org_id, lcu_specival_vas_rec_dtls.customer_name, lcu_specival_vas_rec_dtls.brand, lcu_specival_vas_rec_dtls.currency_code, lcu_specival_vas_rec_dtls.order_line_id, lcu_specival_vas_rec_dtls.order_line_num, lcu_specival_vas_rec_dtls.inventory_item_id, lcu_specival_vas_rec_dtls.ordered_item, lcu_specival_vas_rec_dtls.ordered_quantity, lcu_specival_vas_rec_dtls.request_date, lcu_specival_vas_rec_dtls.schedule_ship_date, lcu_specival_vas_rec_dtls.order_line_status, lcu_specival_vas_rec_dtls.order_line_cancel_date, lcu_specival_vas_rec_dtls.order_quantity_uom, lcu_specival_vas_rec_dtls.need_by_date, lcu_specival_vas_rec_dtls.attachments_count, lcu_specival_vas_rec_dtls.inventory_org_code, lcu_specival_vas_rec_dtls.inventory_org_id, lcu_specival_vas_rec_dtls.vas_status, lcu_specival_vas_rec_dtls.error_message, lcu_specival_vas_rec_dtls.buyer_id, lcu_specival_vas_rec_dtls.buyer_name, lcu_specival_vas_rec_dtls.demand_subinventory, lcu_specival_vas_rec_dtls.ship_to_location_id, lcu_specival_vas_rec_dtls.list_price_per_unit, lcu_specival_vas_rec_dtls.vendor_id, lcu_specival_vas_rec_dtls.vendor_name, lcu_specival_vas_rec_dtls.vendor_site_id, lcu_specival_vas_rec_dtls.vendor_site_code, lcu_specival_vas_rec_dtls.po_header_id, lcu_specival_vas_rec_dtls.po_line_id, lcu_specival_vas_rec_dtls.po_number, lcu_specival_vas_rec_dtls.po_line_num, lcu_specival_vas_rec_dtls.po_ordered_qty, lcu_specival_vas_rec_dtls.supply_identifier, lcu_specival_vas_rec_dtls.xfactory_date, ln_locator_id, lc_locator, lcu_specival_vas_rec_dtls.request_id, lcu_specival_vas_rec_dtls.creation_date, lcu_specival_vas_rec_dtls.created_by, lcu_specival_vas_rec_dtls.last_update_date
                             , lcu_specival_vas_rec_dtls.last_updated_by);

                ln_specival_vas_cnt   := ln_specival_vas_cnt + 1;
            EXCEPTION
                WHEN OTHERS
                THEN
                    print_log (
                           'Error while inserting data into xxd_ont_special_vas_info_t : '
                        || SQLCODE
                        || ' : '
                        || SQLERRM);
            END;
        END LOOP;

        print_log ('Total records inserted : ' || ln_specival_vas_cnt);

        COMMIT;
        -- displaying extract results in output file
        print_output (RPAD ('-', 100, '-'));
        print_output (
            'Program               : Deckers Cross Dock PO Update Program');
        print_output (
               'Date                  : '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS'));
        print_output ('Concurrent Request ID : ' || gn_request_id);
        print_output (
               'Total PO line locations update success       : '
            || ln_po_upd_success_cnt);
        print_output (
               'Total PO line locations update failed        : '
            || ln_po_upd_error_cnt);
        print_output (
               'Total SO line update success                 : '
            || ln_so_upd_success_cnt);
        print_output (
               'Total SO line update failed                  : '
            || ln_so_upd_error_cnt);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_code   := gn_warning;
            print_log (
                'CROSS_DOCK_PO_UPD_PRC - ' || SQLCODE || ' : ' || SQLERRM);
    END cross_dock_po_upd_prc;

    PROCEDURE xxd_japan_po_update_attribute5 (x_return_mesg OUT NOCOPY VARCHAR2, x_ret_code OUT NOCOPY NUMBER)
    AS
        CURSOR cur_jp_po_1206 IS
              SELECT DISTINCT poh.segment1 purchase_order_num_japan, ooh.order_number, POL.ITEM_ID,
                              pol.line_num, ool.line_number
                FROM po_headers_all@bt_read_1206 poh, po_lines_all@bt_read_1206 pol, po_line_locations_all@bt_read_1206 pll,
                     po_distributions_all@bt_read_1206 pod, oe_order_lines_all@bt_read_1206 ool, oe_order_headers_all@bt_read_1206 ooh,
                     ap_suppliers@bt_read_1206 aps, ap_supplier_sites_all@bt_read_1206 assa, hr_locations_all@bt_read_1206 hr_bill,
                     hr_locations_all@bt_read_1206 hr_ship, mtl_system_items_b@bt_read_1206 msb, mtl_parameters@bt_read_1206 mp
               WHERE     poh.vendor_id = aps.vendor_id
                     AND aps.vendor_id = assa.vendor_id
                     AND assa.vendor_site_id = poh.vendor_site_id
                     AND hr_bill.location_id = poh.bill_to_location_id
                     AND hr_ship.location_id = pll.ship_to_location_id
                     AND pll.po_header_id = poh.po_header_id
                     AND pol.po_header_id = poh.po_header_id
                     AND pol.po_header_id = pod.po_header_id
                     AND pol.po_line_id = pll.po_line_id
                     AND pod.po_line_id = pll.po_line_id
                     AND pod.line_location_id = pll.line_location_id
                     AND pol.attribute5 = ool.line_id
                     AND ool.header_id = ooh.header_id
                     AND msb.inventory_item_id = pol.item_id
                     AND msb.organization_id = mp.organization_id
                     AND mp.organization_id = pll.ship_to_organization_id
                     AND poh.org_id = 232                 -- Deckers Japan G.K
                     AND poh.closed_code = 'OPEN'
                     AND aps.vendor_name IN
                             ('MARUBENI CORPORATION', 'ITOCHU CORPORATION')
                     AND poh.creation_date >
                         TO_DATE ('01-JAN-2014', 'DD-MON-YYYY')
            --AND ooh.order_number IN (50498948,50498955,50628129,50824703)  --AND rownum<50
            --AND poh.segment1=1289
            ORDER BY pol.line_num, poh.segment1;

        CURSOR cur_iso_1223 (p_order_number NUMBER, p_line_num NUMBER)
        IS
            SELECT ool.line_id, ool.inventory_item_id, ool.line_number
              FROM oe_order_headers_all ooh, oe_order_lines_all ool
             WHERE     ooh.header_id = ool.header_id
                   AND ooh.order_number = p_order_number
                   AND ool.line_number = p_line_num;

        ln_po_upd_success_cnt   NUMBER := 0;
        ln_po_upd_error_cnt     NUMBER := 0;
        gn_user_id              NUMBER := fnd_global.user_id;
        gn_login_id             NUMBER := fnd_global.login_id;
        gn_success              NUMBER := 0;
        gn_warning              NUMBER := 1;
        gn_error                NUMBER := 2;
        v_header_id             NUMBER;
    BEGIN
        fnd_file.put_line (fnd_file.LOG,
                           'Start PO lines attribute5 update Program');

        FOR rec_valid_iso_1206 IN cur_jp_po_1206
        LOOP
            FOR rec_valid_iso_1223
                IN cur_iso_1223 (rec_valid_iso_1206.order_number,
                                 rec_valid_iso_1206.LINE_NUMber)
            LOOP
                BEGIN
                    UPDATE po_lines_all
                       SET attribute5 = rec_valid_iso_1223.line_id, last_updated_by = gn_user_id, last_update_date = SYSDATE,
                           last_update_login = gn_login_id
                     WHERE     po_header_id =
                               (SELECT po_header_id
                                  FROM po_headers_all
                                 WHERE segment1 =
                                       rec_valid_iso_1206.purchase_order_num_japan)
                           AND line_num = rec_valid_iso_1206.line_num -- Defect#494 added line_num to cursor
                           AND item_id = rec_valid_iso_1206.item_id;

                    ln_po_upd_success_cnt   := ln_po_upd_success_cnt + 1;

                    SELECT po_header_id
                      INTO v_header_id
                      FROM po_headers_all
                     WHERE segment1 =
                           rec_valid_iso_1206.purchase_order_num_japan;
                /* fnd_file.put_line ( fnd_file.LOG,'1223 ISO line id:' ||  rec_valid_iso_1223.line_id);
                 fnd_file.put_line ( fnd_file.LOG,'1223 po_header_id:' ||  v_header_id);
                 fnd_file.put_line ( fnd_file.LOG,'1206 PO Line Num:' ||  rec_valid_iso_1206.LINE_NUM);
                 fnd_file.put_line ( fnd_file.LOG,'1206 PO item id:' || rec_valid_iso_1206.item_id);
                 --fnd_file.put_line ( fnd_file.LOG,'SO item Id:' ||  rec_valid_iso_1223.inventory_item_id);*/
                EXCEPTION
                    WHEN OTHERS
                    THEN
                        ln_po_upd_error_cnt   := ln_po_upd_error_cnt + 1;
                        DBMS_OUTPUT.put_line (
                               'ERROR WHILE UPDATING PO'
                            || rec_valid_iso_1206.purchase_order_num_japan
                            || SQLERRM);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'ERROR WHILE UPDATING PO'
                            || rec_valid_iso_1206.purchase_order_num_japan
                            || SQLERRM);
                        fnd_file.put_line (
                            fnd_file.LOG,
                               'ERROR WHILE UPDATING SO LINE ID'
                            || rec_valid_iso_1223.line_id
                            || SQLERRM);
                END;
            END LOOP;
        END LOOP;

        COMMIT;


        fnd_file.put_line (
            fnd_file.output,
            'Program               : Deckers Japan TQ PO Sourced from Factory PO line Attribute5 Update Program');
        fnd_file.put_line (
            fnd_file.output,
               'Total PO line Id''s'' update success       : '
            || ln_po_upd_success_cnt);

        IF ln_po_upd_success_cnt = 0
        THEN
            fnd_file.put_line (fnd_file.output,
                               'No Records Found to Update : ');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            DBMS_OUTPUT.put_line ('IN EXCEPTION' || SQLERRM);
            fnd_file.put_line (fnd_file.LOG, 'IN EXCEPTION' || SQLERRM);
            x_ret_code   := gn_warning;
    END xxd_japan_po_update_attribute5;

    PROCEDURE main (x_retcode      OUT NUMBER,
                    x_errbuf       OUT VARCHAR2,
                    p_process   IN     VARCHAR2)
    IS
        x_errcode   VARCHAR2 (500);
        x_errmsg    VARCHAR2 (500);
    BEGIN
        IF p_process = gc_cross_dock
        THEN
            cross_dock_po_upd_prc (x_return_mesg   => x_errbuf,
                                   x_ret_code      => x_retcode);
        END IF;

        IF p_process = gc_japan_po_update
        THEN
            xxd_japan_po_update_attribute5 (x_return_mesg   => x_errbuf,
                                            x_ret_code      => x_retcode);
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (
                fnd_file.LOG,
                   'Error Messgae: '
                || 'Unexpected error in main '
                || SUBSTR (SQLERRM, 1, 250));
            fnd_file.put_line (fnd_file.LOG, '');
            x_retcode   := 2;
            x_errbuf    := 'Error Message main ' || SUBSTR (SQLERRM, 1, 250);
    END main;
END xxd_po_post_conv_upd_pkg;
/
