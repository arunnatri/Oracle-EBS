--
-- XXD_WSH_PROCESS_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:26:41 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_WSH_PROCESS_ORDER_PKG"
AS
    lg_package_name   CONSTANT VARCHAR2 (200) := 'XXDO_WSH_PROCESS_ORDER_PKG';
    /******************************************************************************************
     * Package      : xxd_po_rcv_util_pub
     * Design       : This package is used for Receiving ASNs for Direct Ship and Special VAS
     * Notes        :
     * Modification :
    -- =============================================================================
    -- Date         Version#   Name                    Comments
    -- =============================================================================
    -- 02-MAY-2019  1.0        Greg Jensen             Initial Version
    -- 11-Sep-2019  1.1        Viswanathan Pandian     Updated for CCR0008125
 -- 03-Jul-2020  1.2        Showkath Ali            CCR0008512 -- SPS Enable for EDI Customers
    ******************************************************************************************/
    gn_org_id                  NUMBER := fnd_global.org_id;
    gn_user_id                 NUMBER := fnd_global.user_id;
    gn_login_id                NUMBER := fnd_global.login_id;
    gn_request_id              NUMBER := fnd_global.conc_request_id;
    gn_employee_id             NUMBER := fnd_global.employee_id;
    gn_application_id          NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id       NUMBER := fnd_profile.VALUE ('RESP_ID');
    gc_debug_enable            VARCHAR2 (1);
    gv_application             VARCHAR2 (50)
        := 'Deckers WMS Direct Ship Order Processing';

    TYPE shipment_rec IS RECORD
    (
        delivery_detail_id    NUMBER,
        inventory_item_id     NUMBER,
        quantity              NUMBER
    );

    TYPE shipment_tab IS TABLE OF shipment_rec
        INDEX BY BINARY_INTEGER;

      /*******************
Write to the log file
********************/
    PROCEDURE debug_msg (pv_msg IN VARCHAR2, pn_delivery_id IN VARCHAR2:= NULL, pv_func_name IN VARCHAR2:= NULL
                         , pv_breakout_oe_lines IN VARCHAR2:= 'N')
    IS
        PRAGMA AUTONOMOUS_TRANSACTION;

        CURSOR c_del_lines IS
            SELECT DISTINCT wdd.source_line_id line_id
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     wdd.delivery_detail_id = wda.delivery_detail_id
                   AND wdd.source_code = 'OE'
                   AND wda.delivery_id = pn_delivery_id;
    BEGIN
        --   DBMS_OUTPUT.put_line (pv_msg);

        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, pv_msg);
        END IF;

        IF pv_breakout_oe_lines = 'Y'
        THEN
            FOR c_rec IN c_del_lines
            LOOP
                INSERT INTO custom.do_debug (debug_text, creation_date, created_by, session_id, -- debug_id,
                                                                                                request_id, application_id
                                             , call_stack)
                     VALUES (pv_msg                          -- Error/Log text
                                   , SYSDATE                  -- Creation_Date
                                            , NVL (gn_user_id, -1) --Created_by
                                                                  ,
                             NVL (USERENV ('SESSIONID'), -1)      --session_id
                                                            , -- NVL (pn_delivery_id, -1)                      --Delivery ID
                                                              NVL (gn_request_id, -1) --Concurrent Program Request_id
                                                                                     , gv_application -- “Direct Ship – WMS Pick Pack Process”
                             , 'OEID:' || c_rec.line_id --reference to OE Line ID for common process debugging
                                                       );
            END LOOP;
        ELSE
            INSERT INTO custom.do_debug (debug_text, creation_date, created_by, session_id, -- debug_id,
                                                                                            request_id, application_id
                                         , call_stack)
                 VALUES (pv_msg                              -- Error/Log text
                               , SYSDATE                      -- Creation_Date
                                        , NVL (gn_user_id, -1)    --Created_by
                                                              ,
                         NVL (USERENV ('SESSIONID'), -1)          --session_id
                                                        , -- NVL (pn_delivery_id, -1)                      --Delivery ID
                                                          NVL (gn_request_id, -1) --Concurrent Program Request_id
                                                                                 , gv_application -- “Direct Ship – WMS Pick Pack Process”
                         , pv_func_name -- “<<Current Procedure/Function name>>”
                                       );
        END IF;

        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    --1.2 chages start
    -- Function to get customer type from xxdo_edi_customers value set.
    FUNCTION get_customer_type (p_customer_id IN NUMBER)
        RETURN VARCHAR2
    IS
        lv_sps_customer   VARCHAR2 (10) := NULL;
    BEGIN
        BEGIN
            SELECT flv.attribute1
              INTO lv_sps_customer
              FROM fnd_lookup_values flv, hz_cust_accounts hca
             WHERE     1 = 1
                   AND flv.lookup_type = 'XXDO_EDI_CUSTOMERS'
                   AND flv.language = 'US'
                   AND NVL (flv.enabled_flag, 'N') = 'Y'
                   AND NVL (TRUNC (flv.start_date_active), TRUNC (SYSDATE)) <=
                       TRUNC (SYSDATE)
                   AND NVL (TRUNC (flv.end_date_active), TRUNC (SYSDATE)) >=
                       TRUNC (SYSDATE)
                   AND hca.account_number = flv.lookup_code
                   AND hca.cust_account_id = p_customer_id;

            fnd_file.put_line (
                fnd_file.LOG,
                   'The customer service is:'
                || lv_sps_customer
                || '-'
                || 'for customer');
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_sps_customer   := NULL;
        END;

        RETURN lv_sps_customer;
    END get_customer_type;

    PROCEDURE add_edi_shipments (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pv_bill_of_lading IN VARCHAR2
                                 , pv_container IN VARCHAR2, pn_ship_to_org_id IN NUMBER, pn_delivery_id IN NUMBER)
    IS
        l_pn                  VARCHAR2 (200) := lg_package_name || '.add_edi_shipments';
        lv_seal_number        VARCHAR2 (50);
        lv_tracking_number    VARCHAR2 (50);
        lv_pro_number         VARCHAR2 (30);
        lv_load_id            VARCHAR2 (10);
        ln_num_shipment_id    NUMBER;
        ln_count              NUMBER;
        lv_vessel_name        VARCHAR2 (35);
        ld_etd                DATE;
        ln_carrier_id         NUMBER;
        lv_carrier_name       VARCHAR2 (100);
        lv_scac_code          VARCHAR2 (10);
        ln_ship_to_org_id     NUMBER;
        ln_location_id        NUMBER;
        ln_customer_id        NUMBER;
        ln_organization_id    NUMBER;
        ln_shipment_id        NUMBER;
        ln_source_header_id   NUMBER;
        lv_brand_code         VARCHAR2 (2);
        ln_carton_count       NUMBER;
        ln_ordered_quantity   NUMBER;
        ln_shipped_quantity   NUMBER;
        ln_weight             NUMBER;
        ln_volume             NUMBER;
        lv_shipment_key       VARCHAR2 (20);
        lv_sps_customer       VARCHAR2 (10);                             --1.2
    BEGIN
        debug_msg ('add_edi_shipments - Enter', pn_delivery_id, l_pn);

        --Check for a record with this combinaton
        BEGIN
            SELECT DISTINCT shipment_id
              INTO ln_num_shipment_id
              FROM do_edi.do_edi856_shipments
             WHERE     trailer_number = pv_container
                   AND waybill = pv_bill_of_lading
                   AND ship_to_org_id = pn_ship_to_org_id
                   AND dock_door_event = 'Y'
                   AND asn_status = 'X';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                ln_num_shipment_id   := NULL;
            WHEN OTHERS
            THEN
                RETURN;                               --TODO better error here
        END;

        IF ln_num_shipment_id IS NULL
        THEN
            debug_msg ('add_edi_shipments - select header data',
                       pn_delivery_id,
                       l_pn);

            BEGIN
                --Get shipment data
                SELECT DISTINCT vessel_name, etd, carrier_id,
                                carrier_name, scac_code, ship_to_org_id,
                                location_id, customer_id, organization_id
                  INTO lv_vessel_name, ld_etd, ln_carrier_id, lv_carrier_name,
                                     lv_scac_code, ln_ship_to_org_id, ln_location_id,
                                     ln_customer_id, ln_organization_id
                  FROM xxd_wsh_delivery_cartons_v
                 WHERE     bill_of_lading = pv_bill_of_lading
                       AND container_num = pv_container
                       AND ship_to_org_id = pn_ship_to_org_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    debug_msg ('add_edi_shipments - Header no data',
                               pn_delivery_id,
                               l_pn);
                    ROLLBACK;
                    RETURN;
                WHEN OTHERS
                THEN
                    debug_msg (
                           'add_edi_shipments - Add Header - Other Exception'
                        || SQLERRM,
                        pn_delivery_id,
                        l_pn);
                    ROLLBACK;
                    RETURN;
            END;

            ln_num_shipment_id   := NULL;
            --- Get next shipment id
            do_edi.get_next_values ('DO_EDI856_SHIPMENTS',
                                    1,
                                    ln_num_shipment_id);
            debug_msg ('add_edi_shipments - add header',
                       pn_delivery_id,
                       l_pn);
            -- function to get customer is SPS or not
            lv_sps_customer      := get_customer_type (ln_customer_id); -- 1.2

            INSERT INTO do_edi.do_edi856_shipments (shipment_id,
                                                    asn_status,
                                                    asn_date,
                                                    invoice_date,
                                                    customer_id,
                                                    ship_to_org_id,
                                                    waybill,
                                                    seal_code,
                                                    trailer_number,
                                                    tracking_number,
                                                    pro_number,
                                                    est_delivery_date,
                                                    creation_date,
                                                    created_by,
                                                    last_update_date,
                                                    last_updated_by,
                                                    archive_flag,
                                                    organization_id,
                                                    location_id,
                                                    request_sent_date,
                                                    reply_rcv_date,
                                                    scheduled_pu_date,
                                                    bill_of_lading,
                                                    carrier,
                                                    carrier_scac,
                                                    comments,
                                                    confirm_sent_date,
                                                    contact_name,
                                                    cust_shipment_id,
                                                    earliest_pu_date,
                                                    latest_pu_date,
                                                    load_id,
                                                    routing_status,
                                                    ship_confirm_date,
                                                    shipment_weight,
                                                    shipment_weight_uom,
                                                    dock_door_event,
                                                    voyage_num,
                                                    vessel_name,
                                                    vessel_dept_date,
                                                    sps_event            --1.2
                                                             )
                 VALUES (ln_num_shipment_id, 'X',                -- ASN Status
                                                  NULL,             --ASN Date
                         NULL,                                  --Invoice date
                               ln_customer_id, ln_ship_to_org_id,
                         pv_bill_of_lading, lv_seal_number, -- seal_number,   ---TBD
                                                            pv_container,
                         pv_bill_of_lading,          --tracking_number, ---TBD
                                            lv_pro_number,  --pro_number,--TBD
                                                           NULL, -- head.ship_date + 3 est_delivery_date,
                         SYSDATE,                             --creation_date,
                                  gn_user_id,                    --created_by,
                                              SYSDATE,    -- last_update_date,
                         gn_user_id,                       -- last_updated_by,
                                     'N',                     -- archive_flag,
                                          ln_organization_id,
                         ln_location_id, NULL,           -- request_sent_date,
                                               NULL,        -- reply_rcv_date,
                         NULL,                           -- scheduled_pu_date,
                               pv_bill_of_lading,           -- bill_of_lading,
                                                  lv_carrier_name, -- carrier,
                         lv_scac_code, NULL,                       --comments,
                                             NULL,       -- confirm_sent_date,
                         NULL,                                 --contact_name,
                               NULL,                      -- cust_shipment_id,
                                     NULL,                -- earliest_pu_date,
                         NULL,                              -- latest_pu_date,
                               lv_load_id,                    -- load_id,--TBD
                                           NULL,            -- routing_status,
                         NULL,                           -- ship_confirm_date,
                               NULL,                       -- shipment_weight,
                                     'LB',             -- shipment_weight_uom,
                         'Y', NULL, lv_vessel_name,
                         ld_etd, lv_sps_customer                         --1.2
                                                );
        END IF;

        BEGIN
            debug_msg ('add_edi_shipments - line select',
                       pn_delivery_id,
                       l_pn);

            SELECT oe_wdd_link.header_id
                       source_header_id,
                   dob.brand_code,
                   (SELECT COUNT (DISTINCT container_name)
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                     WHERE     delivery_id = oe_wdd_link.delivery_id
                           AND wda.delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wdd.source_code = 'WSH')
                       carton_count,
                   (SELECT SUM (ordered_quantity)
                      FROM oe_order_lines_all
                     WHERE     line_id IN
                                   (SELECT DISTINCT source_line_id
                                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                                     WHERE     wda.delivery_detail_id =
                                               wdd.delivery_detail_id
                                           AND wda.delivery_id =
                                               oe_wdd_link.delivery_id
                                           AND wdd.source_code = 'OE')
                           AND header_id = oe_wdd_link.header_id)
                       ordered_quantity,
                   (SELECT SUM (wdd.requested_quantity)
                      FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
                     WHERE     wda.delivery_detail_id =
                               wdd.delivery_detail_id
                           AND wda.delivery_id = oe_wdd_link.delivery_id
                           AND wdd.source_code = 'OE')
                       shipped_quantity,
                   NVL (
                       apps.do_edi_utils_pub.delivery_ship_weight (
                           oe_wdd_link.delivery_id),
                       0)
                       weight,
                   NVL (
                       apps.do_edi_utils_pub.delivery_ship_volume (
                           oe_wdd_link.delivery_id),
                       0)
                       volume
              INTO ln_source_header_id, lv_brand_code, ln_carton_count, ln_ordered_quantity,
                                      ln_shipped_quantity, ln_weight, ln_volume
              FROM wsh_new_deliveries wnd,
                   oe_order_headers_all ooha,
                   do_custom.do_brands dob,
                   (  SELECT oola.header_id, wda.delivery_id
                        FROM oe_order_lines_all oola, wsh_delivery_details wdd, wsh_delivery_assignments wda
                       WHERE     oola.line_id = wdd.source_line_id
                             AND wdd.delivery_detail_id =
                                 wda.delivery_detail_id
                             AND wdd.source_code = 'OE'
                    GROUP BY oola.header_id, wda.delivery_id) oe_wdd_link
             WHERE     wnd.delivery_id = pn_delivery_id
                   AND oe_wdd_link.header_id = ooha.header_id
                   AND oe_wdd_link.delivery_id = wnd.delivery_id
                   AND ooha.attribute5 = dob.brand_name
                   AND NOT EXISTS --Delivery cannot already be in the pick-tickets table
                           (SELECT NULL
                              FROM do_edi.do_edi856_pick_tickets
                             WHERE delivery_id = wnd.delivery_id);
        --lv_shipment_key := pn_delivery_id || lv_brand_code; -- commented for ccr0008125
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                debug_msg ('add_edi_shipments - line no data',
                           pn_delivery_id,
                           l_pn);
                ROLLBACK;
                RETURN;
            WHEN OTHERS
            THEN
                debug_msg (
                       'add_edi_shipments - Add line -Other Exception'
                    || SQLERRM,
                    pn_delivery_id,
                    l_pn);
                ROLLBACK;
                RETURN;
        END;

        debug_msg ('add_edi_shipments - Add line', pn_delivery_id, l_pn);
        lv_shipment_key   := ln_num_shipment_id || lv_brand_code; -- added for ccr0008125

        --Add record for shipment_line
        INSERT INTO do_edi.do_edi856_pick_tickets (shipment_id, delivery_id, weight, weight_uom, number_cartons, cartons_uom, volume, volume_uom, ordered_qty, shipped_qty, shipped_qty_uom, source_header_id, intmed_ship_to_org_id, creation_date, created_by, last_update_date, last_updated_by, archive_flag
                                                   , shipment_key)
             VALUES (ln_num_shipment_id, pn_delivery_id, ln_weight,   --weight
                     'LB',                                        --weight_uom
                           ln_carton_count, 'EA',
                     ln_volume,                                       --volume
                                'CI',                           --volume units
                                      ln_ordered_quantity,
                     ln_shipped_quantity, 'EA',                   --carton UOM
                                                ln_source_header_id,
                     NULL,                                       --intermet st
                           SYSDATE, gn_user_id,
                     SYSDATE, gn_user_id, 'N',
                     lv_shipment_key);

        debug_msg ('add_edi_shipments - check container/BOL/ST',
                   pn_delivery_id,
                   l_pn);

        --find any deliveries in the  BOL/Container/ST not assigned to a EDI shipment record
        SELECT COUNT (DISTINCT rsh.shipment_num)
          INTO ln_count
          FROM rcv_shipment_lines rsl, rcv_shipment_headers rsh, custom.do_shipments s,
               wsh_new_deliveries wnd, oe_order_headers_all ooha, oe_order_lines_all oola
         WHERE     rsh.packing_slip = s.invoice_num
               AND rsl.shipment_header_id = rsh.shipment_header_id
               AND wnd.source_header_id = ooha.header_id
               AND rsh.shipment_num = wnd.attribute8(+)
               AND s.bill_of_lading = pv_bill_of_lading
               AND ooha.header_id = oola.header_id
               AND rsl.container_num = pv_container
               AND oola.ship_to_org_id = pn_ship_to_org_id
               AND wnd.status_code = 'OP'        --TODO : Check this condition
               AND (   NOT EXISTS
                           (SELECT NULL
                              FROM do_edi.do_edi856_shipments sp, do_edi.do_edi856_pick_tickets pt
                             WHERE     sp.shipment_id = pt.shipment_id
                                   AND ship_to_org_id = pn_ship_to_org_id
                                   AND pt.delivery_id = wnd.delivery_id
                                   AND sp.ship_to_org_id =
                                       oola.ship_to_org_id)
                    OR wnd.attribute8 IS NULL);

        debug_msg (
               'add_edi_shipments - check container/BOL/ST : Records found :'
            || ln_count,
            pn_delivery_id,
            l_pn);

        --If none exist, update the ASN status to N to be ready for extract
        IF ln_count = 0
        THEN
            debug_msg ('add_edi_shipments - update asn status',
                       pn_delivery_id,
                       l_pn);

            UPDATE do_edi.do_edi856_shipments s
               SET s.asn_status   = 'N',
                   shipment_weight   =
                       NVL ((SELECT SUM (weight) --Roll up delivery weight to header
                               FROM do_edi.do_edi856_pick_tickets pt
                              WHERE s.shipment_id = pt.shipment_id),
                            0)
             WHERE     s.trailer_number = pv_container
                   AND waybill = pv_bill_of_lading
                   AND ship_to_org_id = pn_ship_to_org_id;
        END IF;

        COMMIT;
        debug_msg ('add_edi_shipments - Exit', pn_delivery_id, l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('add_edi_shipments - Err' || SQLERRM,
                       pn_delivery_id,
                       l_pn);
            ROLLBACK;
    END add_edi_shipments;

    PROCEDURE process_delivery_line (p_delivery_detail_id       NUMBER,
                                     p_ship_qty                 NUMBER,
                                     p_ship_date                DATE,
                                     p_carrier                  VARCHAR2,
                                     p_carrier_code             VARCHAR2,
                                     p_shipping_method          VARCHAR2,
                                     p_tracking_number          VARCHAR2,
                                     x_retstat              OUT VARCHAR2)
    IS
        l_pn                 VARCHAR2 (200) := lg_package_name || '.process_delivery_line';
        changed_attributes   wsh_delivery_details_pub.changedattributetabtype;
        retstat              VARCHAR2 (1);
        msgcount             NUMBER;
        msgdata              VARCHAR2 (2000);
        l_message            VARCHAR2 (2000);
        l_message1           VARCHAR2 (2000);
        iid                  NUMBER;
        l_carrier_code       VARCHAR2 (100);
        l_ship_method_code   VARCHAR2 (100);
    BEGIN
        debug_msg ('delivery_detail_id = ' || TO_CHAR (p_delivery_detail_id),
                   p_delivery_detail_id,
                   l_pn);
        changed_attributes (1).delivery_detail_id     := p_delivery_detail_id;
        --changed_attributes (1).date_scheduled := p_ship_date; -- Raja
        --Added by CC for Canada 3PL Phase-3
        --changed_attributes (1).freight_carrier_code := p_carrier;
        ----Added by CC for Canada Retail and Ecomm
        changed_attributes (1).freight_carrier_code   :=
            NVL (p_carrier, p_carrier_code);
        changed_attributes (1).tracking_number        :=
            TRIM (p_tracking_number);
        --08/26/2003 - KWG  Trim for searching performance
        changed_attributes (1).shipped_quantity       := p_ship_qty;
        debug_msg ('before select', p_delivery_detail_id, l_pn);

        SELECT source_line_id, organization_id, requested_quantity - p_ship_qty,
               inventory_item_id, ship_method_code
          INTO changed_attributes (1).source_line_id, changed_attributes (1).ship_from_org_id, changed_attributes (1).cycle_count_quantity, iid,
                                                    l_ship_method_code
          FROM wsh_delivery_details
         WHERE delivery_detail_id = p_delivery_detail_id;

        FOR i IN 1 .. changed_attributes.COUNT
        LOOP
            debug_msg (
                   'SKU: '
                || iid_to_sku (iid)
                || ' DDID: '
                || TO_CHAR (changed_attributes (1).delivery_detail_id)
                || ' Requested: '
                || TO_CHAR (
                         changed_attributes (1).shipped_quantity
                       + changed_attributes (1).cycle_count_quantity)
                || ' Shipped: '
                || TO_CHAR (changed_attributes (1).shipped_quantity)
                || ' Cycle_count: '
                || TO_CHAR (changed_attributes (1).cycle_count_quantity)
                || ' Ship Method Code: '
                || l_ship_method_code,
                p_delivery_detail_id,
                l_pn);
        END LOOP;

        debug_msg ('before update_shipping_attributes',
                   p_delivery_detail_id,
                   l_pn);

        ----Added by CC for Canada Retail and Ecomm

        IF p_carrier_code IS NOT NULL
        THEN
            BEGIN
                UPDATE apps.wsh_new_deliveries
                   SET attribute2   = TRIM (p_carrier_code)
                 WHERE delivery_id =
                       (SELECT DISTINCT delivery_id
                          FROM apps.wsh_delivery_assignments
                         WHERE     delivery_detail_id = p_delivery_detail_id
                               AND delivery_id IS NOT NULL);

                debug_msg ('Carrier SCAC updated in WND',
                           p_delivery_detail_id,
                           l_pn);
            EXCEPTION
                WHEN OTHERS
                THEN
                    NULL;
            END;
        END IF;

        wsh_delivery_details_pub.update_shipping_attributes (
            p_api_version_number   => 1.0,
            p_init_msg_list        => NULL,
            p_commit               => NULL,
            x_return_status        => retstat,
            x_msg_count            => msgcount,
            x_msg_data             => msgdata,
            p_changed_attributes   => changed_attributes,
            p_source_code          => 'OE');
        debug_msg ('before error loop', p_delivery_detail_id, l_pn);

        BEGIN
            debug_msg ('RETSTAT: ' || retstat, p_delivery_detail_id, l_pn);
            debug_msg ('Message count: ' || msgcount,
                       p_delivery_detail_id,
                       l_pn);

            FOR i IN 1 .. NVL (msgcount, 5)
            LOOP
                l_message   := fnd_msg_pub.get (i, 'F');
                l_message   := REPLACE (l_message, CHR (0), ' ');
                debug_msg ('Error message: ' || SUBSTR (l_message, 1, 200),
                           p_delivery_detail_id,
                           l_pn);

                IF (i = 1)
                THEN
                    l_message1   := l_message;
                END IF;
            END LOOP;
        EXCEPTION
            WHEN OTHERS
            THEN
                debug_msg ('Error loop Unexp Error message: ' || SQLERRM,
                           p_delivery_detail_id,
                           l_pn);
        END;

        fnd_msg_pub.delete_msg ();
        x_retstat                                     := retstat;
        debug_msg ('-' || l_pn, p_delivery_detail_id, l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Unexp Error message: ' || SQLERRM,
                       p_delivery_detail_id,
                       l_pn);
            x_retstat   := 'U';
            debug_msg ('-' || l_pn, p_delivery_detail_id, l_pn);
    END process_delivery_line;

    PROCEDURE create_container (p_delivery_id IN NUMBER, p_container_item_id IN NUMBER, p_container_name IN VARCHAR2
                                , x_container_instance_id OUT NUMBER, x_ret_stat OUT VARCHAR2, p_organization_id IN NUMBER -- Commented for BT := 7  Added IN
                                                                                                                          )
    IS
        l_pn          VARCHAR2 (200) := lg_package_name || '.create_container';
        hell          EXCEPTION;
        containers    wsh_util_core.id_tab_type;
        msg_count     NUMBER;
        msg_data      VARCHAR2 (2000);
        api_version   NUMBER := 1.0;
        segs          fnd_flex_ext.segmentarray;
        ret_stat      VARCHAR2 (1);
    BEGIN
        debug_msg ('+' || l_pn);
        fnd_msg_pub.initialize;
        wsh_container_pub.create_containers (p_api_version => api_version, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_validation_level => fnd_api.g_valid_level_full, x_return_status => x_ret_stat, x_msg_count => msg_count, x_msg_data => msg_data, p_container_item_id => p_container_item_id, p_container_item_name => NULL, p_container_item_seg => segs, p_organization_id => p_organization_id, p_organization_code => NULL, p_name_prefix => NULL, p_name_suffix => NULL, p_base_number => NULL, p_num_digits => NULL, p_quantity => 1, p_container_name => p_container_name
                                             , x_container_ids => containers);
        debug_msg ('-----');
        debug_msg ('Ret_stat: ' || x_ret_stat);
        debug_msg ('msg_count: ' || msg_count);
        debug_msg ('msg data: ' || msg_data);

        FOR j IN 1 .. fnd_msg_pub.count_msg
        LOOP
            msg_data   := fnd_msg_pub.get (j, 'F');
            msg_data   := REPLACE (msg_data, CHR (0), ' ');
            debug_msg (msg_data);
        END LOOP;

        IF x_ret_stat <> fnd_api.g_ret_sts_success
        THEN
            RETURN;
        END IF;

        debug_msg ('container count:' || containers.COUNT);

        FOR i IN 1 .. containers.COUNT
        LOOP
            x_container_instance_id   := containers (i);
            debug_msg ('container id:' || containers (i));
            fnd_msg_pub.initialize;
            wsh_container_actions.update_cont_attributes (NULL, p_delivery_id, containers (i)
                                                          , ret_stat);
            debug_msg ('update attributes ret_stat: ' || ret_stat);

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                msg_data   := fnd_msg_pub.get (j, 'F');
                msg_data   := REPLACE (msg_data, CHR (0), ' ');
                debug_msg (msg_data);
            END LOOP;

            IF ret_stat <> fnd_api.g_ret_sts_success
            THEN
                x_ret_stat   := ret_stat;
                debug_msg ('-' || l_pn);
                RETURN;
            END IF;

            fnd_msg_pub.initialize;
            wsh_container_actions.assign_to_delivery (containers (i),
                                                      p_delivery_id,
                                                      ret_stat);
            debug_msg ('assign to delivery ret_stat: ' || ret_stat);

            FOR j IN 1 .. fnd_msg_pub.count_msg
            LOOP
                msg_data   := fnd_msg_pub.get (j, 'F');
                msg_data   := REPLACE (msg_data, CHR (0), ' ');
                debug_msg (msg_data);
            END LOOP;

            IF ret_stat <> fnd_api.g_ret_sts_success
            THEN
                x_ret_stat   := ret_stat;
                debug_msg ('-' || l_pn);

                RETURN;
            END IF;

            UPDATE wsh_delivery_details
               SET source_header_id   =
                       (SELECT source_header_id
                          FROM wsh_new_deliveries
                         WHERE delivery_id = p_delivery_id)
             WHERE delivery_detail_id = x_container_instance_id;
        END LOOP;

        debug_msg ('-----');
        x_ret_stat   := fnd_api.g_ret_sts_success;
        debug_msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('sql errm: ' || SQLERRM);
            debug_msg ('-----');
            x_ret_stat   := fnd_api.g_ret_sts_unexp_error;
            debug_msg ('-' || l_pn);
    END create_container;

    FUNCTION get_requested_quantity (p_delivery_detail_id IN NUMBER)
        RETURN NUMBER
    IS
        l_pn        VARCHAR2 (200) := lg_package_name || '.get_requested_quantity';
        requested   NUMBER;
    BEGIN
        debug_msg ('+' || l_pn);

        SELECT requested_quantity
          INTO requested
          FROM wsh_delivery_details
         WHERE delivery_detail_id = p_delivery_detail_id;

        RETURN requested;
        debug_msg ('-' || l_pn);
    EXCEPTION
        WHEN NO_DATA_FOUND
        THEN
            debug_msg ('-' || l_pn);
            RETURN 0;
        WHEN OTHERS
        THEN
            debug_msg ('-' || l_pn);
            RETURN -1;
    END get_requested_quantity;

    PROCEDURE split_delivery_detail (p_delivery_detail_id IN NUMBER, p_x_split_quantity IN OUT NUMBER, x_new_delivery_detail_id OUT NUMBER
                                     , x_ret_stat OUT VARCHAR2)
    IS
        l_pn        VARCHAR2 (200) := lg_package_name || '.split_delivery_detail';
        msg_count   NUMBER;
        msg_data    VARCHAR2 (2000);
        dummy       NUMBER;
    BEGIN
        debug_msg ('+' || l_pn);
        debug_msg (
               'WDD_ID : '
            || p_delivery_detail_id
            || '- Qty : '
            || p_x_split_quantity);
        wsh_delivery_details_pub.split_line (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            x_return_status      => x_ret_stat,
            x_msg_count          => msg_count,
            x_msg_data           => msg_data,
            p_from_detail_id     => p_delivery_detail_id,
            x_new_detail_id      => x_new_delivery_detail_id,
            x_split_quantity     => p_x_split_quantity,
            x_split_quantity2    => dummy);
        debug_msg ('msg_count: ' || msg_count);
        debug_msg (
            'msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 1, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 100, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 200, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 300, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 400, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 500, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 600, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 700, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 800, 100));
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 900, 100));

        FOR j IN 1 .. fnd_msg_pub.count_msg
        LOOP
            msg_data   := fnd_msg_pub.get (j, 'F');
            msg_data   := REPLACE (msg_data, CHR (0), ' ');
            debug_msg (msg_data);
        END LOOP;

        debug_msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('sql errm: ' || SQLERRM);
            debug_msg ('-----');
            x_ret_stat   := fnd_api.g_ret_sts_unexp_error;
            debug_msg ('-' || l_pn);
    END split_delivery_detail;

    PROCEDURE split_shipments (p_shipments IN shipment_tab, p_carrier IN VARCHAR2, p_carrier_code VARCHAR2, p_shipping_method VARCHAR2, p_tracking_no IN VARCHAR2, p_shipment_date IN DATE
                               , x_delivery_ids OUT wsh_util_core.id_tab_type, x_ret_stat OUT VARCHAR2)
    IS
        l_pn                   VARCHAR2 (200) := lg_package_name || '.split_shipments';
        ret_stat               VARCHAR2 (1);
        qty                    NUMBER;
        split_line_failure     EXCEPTION;
        process_line_failure   EXCEPTION;
    BEGIN
        debug_msg ('+' || l_pn, NULL, 'split_shipments');

        FOR i IN 1 .. p_shipments.COUNT
        LOOP
            IF p_shipments (i).quantity >=
               get_requested_quantity (p_shipments (i).delivery_detail_id)
            THEN
                qty                  := p_shipments (i).quantity;
                x_delivery_ids (i)   := p_shipments (i).delivery_detail_id;
                debug_msg ('took old delivery_id', NULL, 'split_shipments');
            ELSE
                qty          := p_shipments (i).quantity;
                debug_msg (
                       'Need to Create new delivery_id  for '
                    || p_shipments (i).quantity
                    || ' units ',
                    NULL,
                    'split_shipments');
                split_delivery_detail (p_shipments (i).delivery_detail_id, qty, x_delivery_ids (i)
                                       , ret_stat);
                x_ret_stat   := ret_stat;
                debug_msg ('Create new delivery_id ' || x_delivery_ids (i),
                           NULL,
                           'split_shipments');

                IF NVL (ret_stat, g_ret_error) <>
                   apps.fnd_api.g_ret_sts_success
                THEN
                    RAISE split_line_failure;
                END IF;
            END IF;

            process_delivery_line (x_delivery_ids (i), qty, p_shipment_date,
                                   p_carrier, p_carrier_code, p_shipping_method
                                   , p_tracking_no, ret_stat);
            x_ret_stat   := ret_stat;

            IF NVL (ret_stat, g_ret_error) <> apps.fnd_api.g_ret_sts_success
            THEN
                RAISE process_line_failure;
            END IF;
        END LOOP;

        debug_msg ('-' || l_pn, NULL, 'split_shipments');
    EXCEPTION
        WHEN OTHERS
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_unexp_error;
            debug_msg ('-' || l_pn, NULL, 'split_shipments');
            RETURN;
    END split_shipments;

    PROCEDURE pack_into_container (p_delivery_id IN NUMBER, p_container_id IN NUMBER, p_delivery_ids IN wsh_util_core.id_tab_type
                                   , x_ret_stat OUT VARCHAR2)
    IS
        l_pn          VARCHAR2 (200) := lg_package_name || '.pack_into_container';
        pack_status   VARCHAR2 (2000);
        msg_count     NUMBER;
        msg_data      VARCHAR2 (4000);
    BEGIN
        debug_msg ('+' || l_pn);
        fnd_msg_pub.initialize;
        debug_msg ('Trying to pack into container id: ' || p_container_id,
                   p_delivery_id,
                   l_pn);
        debug_msg ('delivery_id: ' || p_delivery_id, p_delivery_id, l_pn);
        debug_msg ('container_id: ' || p_container_id, p_delivery_id, l_pn);

        FOR i IN 1 .. p_delivery_ids.COUNT
        LOOP
            debug_msg (
                'delivery_detail_id (' || i || '): ' || p_delivery_ids (i),
                p_delivery_id,
                l_pn);
        END LOOP;

        wsh_container_pub.container_actions (
            p_api_version        => 1.0,
            p_init_msg_list      => fnd_api.g_false,
            p_commit             => fnd_api.g_false,
            p_validation_level   => fnd_api.g_valid_level_full,
            x_return_status      => x_ret_stat,
            x_msg_count          => msg_count,
            x_msg_data           => msg_data,
            p_detail_tab         => p_delivery_ids,
            p_container_name     => NULL,
            p_cont_instance_id   => p_container_id,
            p_container_flag     => 'N',
            p_delivery_flag      => 'N',
            p_delivery_id        => p_delivery_id,
            p_delivery_name      => NULL,
            p_action_code        => 'PACK');
        debug_msg ('pack status: ' || pack_status, p_delivery_id, l_pn);
        debug_msg ('msg_count: ' || msg_count, p_delivery_id, l_pn);
        debug_msg (
            'msg data: ' || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 1, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 100, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 200, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 300, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 400, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 500, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 600, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 700, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 800, 100),
            p_delivery_id,
            l_pn);
        debug_msg (
               'msg data: '
            || SUBSTR (REPLACE (msg_data, CHR (0), ' '), 900, 100),
            p_delivery_id,
            l_pn);

        FOR j IN 1 .. fnd_msg_pub.count_msg
        LOOP
            msg_data   := fnd_msg_pub.get (j, 'F');
            msg_data   := REPLACE (msg_data, CHR (0), ' ');
            debug_msg (msg_data, p_delivery_id, l_pn);
        END LOOP;

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_into_container, API Message: '||msg_data);

        debug_msg ('-' || l_pn, p_delivery_id, l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('sql errm: ' || SQLERRM, p_delivery_id, l_pn);
            debug_msg ('-----');
            x_ret_stat   := fnd_api.g_ret_sts_unexp_error;
            debug_msg ('-' || l_pn, p_delivery_id, l_pn);
    END pack_into_container;

    PROCEDURE process_delivery_freight (p_delivery_id              NUMBER,
                                        p_freight_charge           NUMBER,
                                        p_carrier_code             VARCHAR2,
                                        p_freight_charges          NUMBER,
                                        p_delivery_detail_id       NUMBER,
                                        p_carrier                  VARCHAR2,
                                        p_shipping_method          VARCHAR2,
                                        x_retstat              OUT VARCHAR2)
    IS
        l_pn                VARCHAR2 (200)
                                := lg_package_name || '.process_delivery_freight';
        v_header_id         NUMBER;
        cust_flag           VARCHAR2 (1);
        order_type_flag     VARCHAR2 (1);
        carrier             VARCHAR2 (1) := 'Y';
        freight             wsh_freight_costs_pub.pubfreightcostrectype;
        retstat             VARCHAR2 (1);
        msgcount            NUMBER;
        msgdata             VARCHAR2 (2000);
        l_message           VARCHAR2 (2000);
        l_message1          VARCHAR2 (2000);
        l_curr_code         VARCHAR2 (10);
        l_freight_applied   VARCHAR2 (1);
    BEGIN
        debug_msg ('+' || l_pn);

        SELECT MAX (wdd.source_header_id)
          INTO v_header_id
          FROM wsh_delivery_assignments wda, wsh_delivery_details wdd
         WHERE     wda.delivery_id = p_delivery_id
               AND wdd.delivery_detail_id = wda.delivery_detail_id
               AND wdd.container_flag = 'N';

        BEGIN
            --         SELECT TRIM (nvl(attribute1, 'Y'))
            --           INTO carrier
            --           FROM org_freight f, apps.org_organization_definitions o
            --          WHERE     o.organization_id = f.organization_id
            --                AND freight_code = NVL (p_carrier, p_carrier_code)
            --                AND o.organization_code =
            --                       fnd_profile.VALUE ('XXDO: ORGANIZATION CODE'); --'VNT';

            SELECT TRIM (NVL (wcsd.freight_charge_flag, 'Y'))
              INTO carrier
              FROM apps.wsh_carrier_services wcs, apps.wsh_carrier_services_dfv wcsd
             WHERE     wcs.ship_method_code = p_shipping_method
                   AND wcs.ROWID = wcsd.ROWID;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                carrier   := 'Y';
        END;

        BEGIN
            SELECT SUBSTR (rc.attribute6, 1, 1), oh.transactional_curr_code
              INTO cust_flag, l_curr_code
              FROM ra_customers rc, oe_order_headers_all oh
             WHERE     rc.customer_id = oh.sold_to_org_id
                   AND oh.header_id = v_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                cust_flag   := 'N';
        END;

        BEGIN
            SELECT NVL (ott.attribute4, 'N')
              INTO order_type_flag
              FROM oe_transaction_types_all ott, oe_order_headers_all oh
             WHERE     ott.transaction_type_id = oh.order_type_id
                   AND oh.header_id = v_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                order_type_flag   := 'N';
        END;

        -- Check to see if we've already applied freight for this delivery
        l_freight_applied           := 'N';

        BEGIN
            SELECT 'Y'
              INTO l_freight_applied
              FROM wsh_freight_costs wfc
             WHERE wfc.delivery_id = p_delivery_id AND ROWNUM = 1;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                l_freight_applied   := 'N';
        END;

        IF    l_freight_applied = 'Y'
           OR cust_flag = 'Y'
           OR order_type_flag = 'Y'
           OR carrier = 'N'
           OR (p_freight_charge = 0 AND p_freight_charges = 0)
        THEN
            x_retstat   := 'S';
            debug_msg ('-' || l_pn);
            RETURN;
        END IF;

        freight.currency_code       := NVL (l_curr_code, 'USD');
        freight.action_code         := 'CREATE';
        freight.delivery_id         := p_delivery_id;
        freight.attribute1          := TO_CHAR (p_delivery_detail_id);
        --freight.freight_cost_type_id := 1;
        freight.freight_cost_type   := 'Shipping';

        --Added by CC for Canada 3PL Phase-3
        IF p_freight_charges IS NOT NULL OR p_freight_charges <> 0
        THEN
            freight.unit_amount   := p_freight_charges;
        ELSE
            freight.unit_amount   := p_freight_charge;
        END IF;

        BEGIN
            SELECT freight_cost_type_id
              INTO freight.freight_cost_type_id
              FROM apps.wsh_freight_cost_types
             WHERE freight_cost_type_code = 'FREIGHT' AND name = 'Shipping';
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                freight.freight_cost_type_id   := 1;
        END;

        --Changes completed

        UPDATE oe_order_lines_all
           SET calculate_price_flag   = 'Y'
         WHERE line_id IN
                   (SELECT source_line_id
                      FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                     WHERE     wda.delivery_id = p_delivery_id
                           AND wdd.delivery_detail_id =
                               wda.delivery_detail_id
                           AND wdd.container_flag = 'N');

        debug_msg (
               'Charging freight: '
            || freight.unit_amount
            || ' for delivery_id: '
            || freight.delivery_id
            || ' on delivery_detail_id: '
            || freight.delivery_detail_id);
        apps.wsh_freight_costs_pub.create_update_freight_costs (
            p_api_version_number   => 1.0,
            p_init_msg_list        => NULL,
            p_commit               => NULL,
            x_return_status        => retstat,
            x_msg_count            => msgcount,
            x_msg_data             => msgdata,
            p_pub_freight_costs    => freight,
            p_action_code          => 'CREATE',
            x_freight_cost_id      => freight.freight_cost_type_id);

        FOR i IN 1 .. msgcount + 10
        LOOP
            l_message   := fnd_msg_pub.get (i, 'F');
            l_message   := REPLACE (l_message, CHR (0), ' ');
            debug_msg ('Error message: ' || SUBSTR (l_message, 1, 200));

            IF (i = 1)
            THEN
                l_message1   := l_message;
            END IF;
        END LOOP;

        fnd_msg_pub.delete_msg ();
        x_retstat                   := retstat;
        debug_msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Error message: ' || SQLERRM);
            x_retstat   := 'U';
            debug_msg ('-' || l_pn);
    END process_delivery_freight;

    PROCEDURE process_container_tracking (
        p_delivery_detail_id       NUMBER,
        p_tracking_number          VARCHAR2,
        p_container_weight         NUMBER,
        p_carrier                  VARCHAR2,
        x_retstat              OUT VARCHAR2)
    IS
        l_pn      VARCHAR2 (200)
                      := lg_package_name || '.process_container_tracking';
        retstat   VARCHAR2 (1);
    BEGIN
        debug_msg ('+' || l_pn);
        debug_msg ('delivery_detail_id = ' || TO_CHAR (p_delivery_detail_id));

        UPDATE wsh_delivery_details
           SET tracking_number = TRIM (p_tracking_number), net_weight = p_container_weight
         WHERE delivery_detail_id = p_delivery_detail_id;

        x_retstat   := 'S';
        debug_msg ('-' || l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Unexp Error message: ' || SQLERRM);
            x_retstat   := 'U';
            debug_msg ('-' || l_pn);
    END process_container_tracking;

    PROCEDURE pack_container (p_delivery_id        IN     NUMBER,
                              p_container_name     IN     VARCHAR2,
                              p_shipments          IN     shipment_tab,
                              p_freight_cost       IN     NUMBER,
                              p_container_weight   IN     NUMBER,
                              p_tracking_number    IN     VARCHAR2,
                              p_carrier            IN     VARCHAR2,
                              p_carrier_code       IN     VARCHAR2,
                              p_shipping_method    IN     VARCHAR2,
                              p_freight_charges    IN     NUMBER,
                              p_shipment_date      IN     DATE,
                              x_container_id          OUT NUMBER,
                              x_ret_stat              OUT VARCHAR2,
                              p_organization_id    IN     NUMBER --:= 7  -- Commented for BT Added IN
                                                                )
    IS
        l_pn                          VARCHAR2 (200) := lg_package_name || '.pack_container';
        ret_stat                      VARCHAR2 (1);
        g_container_item_id           NUMBER := 160489;
        container_id                  NUMBER;
        delivery_ids                  wsh_util_core.id_tab_type;
        junk                          wsh_util_core.id_tab_type;
        create_container_failure      EXCEPTION;
        split_shipments_failure       EXCEPTION;
        pack_into_container_failure   EXCEPTION;
        process_freight_failure       EXCEPTION;
        process_tracking_failure      EXCEPTION;
        --Added for Canada Retail and Ecomm Project
        process_shipping_failure      EXCEPTION;

        CURSOR headers (p2_delivery_id NUMBER)
        IS
            SELECT DISTINCT wdd.source_header_id
              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
             WHERE     wda.delivery_id = p2_delivery_id
                   AND wdd.delivery_detail_id = wda.delivery_detail_id;

        temp                          BOOLEAN;
    BEGIN
        debug_msg ('+' || l_pn);
        debug_msg ('+' || l_pn);
        wsh_delivery_autocreate.autocreate_deliveries (
            p_line_rows           => junk,
            p_init_flag           => 'N',
            p_pick_release_flag   => 'N',
            p_container_flag      => 'Y',
            p_check_flag          => 'Y',
            p_max_detail_commit   => 1000,
            x_del_rows            => junk,
            x_grouping_rows       => junk,
            x_return_status       => ret_stat);
        ret_stat         := NULL;

        create_container (p_delivery_id, g_container_item_id, p_container_name
                          , container_id, ret_stat, p_organization_id);
        debug_msg ('Create Container Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, create_container status : '||ret_stat);

        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE create_container_failure;
        END IF;

        split_shipments (p_shipments, p_carrier, p_carrier_code,
                         p_shipping_method, p_tracking_number, p_shipment_date
                         , delivery_ids, ret_stat);
        debug_msg ('Split Shipments Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, split_shipments status : '||ret_stat);

        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE split_shipments_failure;
        END IF;

        debug_msg (
               'Delivery_id :'
            || p_delivery_id
            || ' container_id: '
            || container_id
            || ' count of delivery_ids: '
            || delivery_ids.COUNT);

        FOR i IN 1 .. delivery_ids.COUNT
        LOOP
            debug_msg ('     Delivery_id to be packed: ' || delivery_ids (i));
        END LOOP;

        /*
              --Added for Canada Retail and Ecomm Project

              process_shipping_details (p_delivery_id, p_shipping_method, ret_stat);
             debug_msg ('Process Delivery Shipping Details Ret Stat: ' || ret_stat);

              --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, process_shipping_details status : '||ret_stat);

              IF ret_stat <> apps.fnd_api.g_ret_sts_success
              THEN
                 RAISE process_shipping_failure;
              END IF;
              */

        pack_into_container (p_delivery_id, container_id, delivery_ids,
                             ret_stat);
        x_container_id   := container_id;
        debug_msg ('Pack into container Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, pack_into_container status : '||ret_stat);

        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE pack_into_container_failure;
        END IF;

        process_delivery_freight (p_delivery_id, p_freight_cost, p_carrier_code, p_freight_charges, container_id, p_carrier
                                  , p_shipping_method, ret_stat);
        debug_msg ('process_delivery_freight Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, process_delivery_freight status : '||ret_stat);

        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE process_freight_failure;
        END IF;

        process_container_tracking (container_id, p_tracking_number, p_container_weight
                                    , p_carrier, ret_stat);
        debug_msg ('process_container_tracking Ret Stat: ' || ret_stat);

        --apps.XXDO_3PL_DEBUG_PROCEDURE('pack_container, process_container_tracking status : '||ret_stat);

        IF ret_stat <> apps.fnd_api.g_ret_sts_success
        THEN
            RAISE process_tracking_failure;
        END IF;

        x_ret_stat       := g_ret_success;
        debug_msg ('-' || l_pn);
        debug_msg ('-' || l_pn);
    EXCEPTION
        WHEN create_container_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            debug_msg ('-' || l_pn);
            RETURN;
        WHEN split_shipments_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            debug_msg ('-' || l_pn);
            RETURN;
        WHEN pack_into_container_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            debug_msg ('-' || l_pn);
            RETURN;
        WHEN process_freight_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            debug_msg ('-' || l_pn);
            RETURN;
        WHEN process_tracking_failure
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_error;
            debug_msg ('-' || l_pn);
            RETURN;
        WHEN process_shipping_failure
        THEN
            --x_ret_stat := apps.fnd_api.g_ret_sts_error;
            x_ret_stat   := 'S'; --Manually updating the STATUS to support EMEA/APAC 3PL operations
            debug_msg ('-' || l_pn);
            RETURN;
        WHEN OTHERS
        THEN
            x_ret_stat   := apps.fnd_api.g_ret_sts_unexp_error;
            debug_msg ('-' || l_pn);
            RETURN;
    END pack_container;

    PROCEDURE split_delivery (pn_delivery_id IN NUMBER, pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2)
    IS
        l_pn          VARCHAR2 (200) := lg_package_name || '.split_delivery';
        l_shipments   shipment_tab;
        l_container   NUMBER;
        l_remainder   NUMBER;

        l_ret_stat    VARCHAR2 (1);
    BEGIN
        debug_msg ('+split_delivery', pn_delivery_id, l_pn);

        FOR c_header IN (SELECT DISTINCT h.delivery_id, h.source_header_id, h.organization_id,
                                         h.scac_code, h.ship_method_code, h.bill_of_lading,
                                         NULL ship_confirm_date
                           FROM xxd_wsh_delivery_cartons_v h
                          WHERE h.delivery_id = pn_delivery_id)
        LOOP
            SAVEPOINT begin_header;

            FOR c_container IN (SELECT DISTINCT c.carton_number
                                  FROM xxd_wsh_delivery_cartons_v c
                                 WHERE c.delivery_id = c_header.delivery_id)
            LOOP
                l_shipments.delete;
                debug_msg (
                    'CARTON NUMBER Process : ' || c_container.carton_number,
                    pn_delivery_id,
                    l_pn);

                FOR c_line
                    IN (  SELECT l.source_line_id, l.item_id, SUM (l.quantity) quantity_to_ship
                            FROM xxd_wsh_delivery_cartons_v l
                           WHERE l.carton_number = c_container.carton_number
                        GROUP BY l.source_line_id, l.item_id)
                LOOP
                    l_remainder   := c_line.quantity_to_ship;
                    debug_msg (
                           'LINE Process : source_line_id = '
                        || c_line.source_line_id
                        || ', item_id = '
                        || c_line.item_id
                        || ', quantity = '
                        || c_line.quantity_to_ship
                        || ' carton number ='
                        || c_container.carton_number,
                        pn_delivery_id,
                        l_pn);

                    FOR c_detail
                        IN (SELECT wdd.delivery_detail_id, GREATEST (NVL (wdd.requested_quantity, 0) - NVL (wdd.shipped_quantity, 0), 0) quantity
                              FROM wsh_delivery_details wdd, wsh_delivery_assignments wda
                             WHERE     GREATEST (
                                             NVL (wdd.requested_quantity, 0)
                                           - NVL (wdd.shipped_quantity, 0),
                                           0) >
                                       0
                                   AND wdd.source_code = 'OE'
                                   AND wdd.source_line_id =
                                       c_line.source_line_id
                                   AND wdd.released_status = 'Y'
                                   --CCR0001800 -- Support for partially picked lines--
                                   AND wda.delivery_detail_id =
                                       wdd.delivery_detail_id
                                   AND wda.delivery_id = c_header.delivery_id) --CCR0001800 -- Support for partially picked lines--
                    LOOP
                        debug_msg (
                               'DETAIL Process :  delivery_detail_id = '
                            || c_detail.delivery_detail_id
                            || ', quantity = '
                            || c_detail.quantity
                            || ', remainder = '
                            || l_remainder
                            || ', least of '
                            || LEAST (l_remainder, c_detail.quantity),
                            pn_delivery_id,
                            l_pn);

                        l_shipments (l_shipments.COUNT + 1).delivery_detail_id   :=
                            c_detail.delivery_detail_id;
                        l_shipments (l_shipments.COUNT).inventory_item_id   :=
                            c_line.item_id;
                        l_shipments (l_shipments.COUNT).quantity   :=
                            LEAST (l_remainder, c_detail.quantity);
                        l_remainder   :=
                              l_remainder
                            - l_shipments (l_shipments.COUNT).quantity;
                        EXIT WHEN l_remainder <= 0;
                    END LOOP;                                       --C_detail

                    IF l_shipments.COUNT <> 0
                    THEN         ---BT Team: Entered the condition for testing
                        l_shipments (l_shipments.COUNT).quantity   :=
                              l_shipments (l_shipments.COUNT).quantity
                            + l_remainder;
                    END IF;
                END LOOP;                                             --c_line

                pack_container (
                    p_delivery_id        => c_header.delivery_id,
                    p_container_name     => c_container.carton_number,
                    p_shipments          => l_shipments,
                    p_freight_cost       => 0,
                    p_container_weight   => 0,
                    p_tracking_number    => c_header.bill_of_lading,
                    p_carrier            => NULL,          --c_header.carrier,
                    p_carrier_code       => c_header.scac_code, --c_header.carrier_code, -- Added by CC for Canada Phase-3
                    p_shipping_method    => c_header.ship_method_code, --v_ship_method_code,
                    p_freight_charges    => 0, --c_header.freight_charges, --Changes completed Canada Phase-3
                    p_shipment_date      => c_header.ship_confirm_date,
                    x_container_id       => l_container,
                    x_ret_stat           => l_ret_stat,
                    p_organization_id    => c_header.organization_id);
            END LOOP;                                            --c_container

            COMMIT;
        END LOOP;

        --c_header
        pv_err_stat   := 'S';
        pv_err_msg    := '';
        debug_msg ('-split_delivery', pn_delivery_id, l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            pv_err_stat   := 'E';
            pv_err_msg    := SQLERRM;
            debug_msg ('-split_delivery. Exception : ' || SQLERRM,
                       pn_delivery_id,
                       l_pn);
    END split_delivery;

    PROCEDURE do_process (pv_err_stat OUT VARCHAR2, pv_err_msg OUT VARCHAR2, pn_delivery_id IN NUMBER:= NULL
                          , pv_debug IN VARCHAR2)
    IS
        CURSOR c_deliveries IS
            SELECT DISTINCT delivery_id, container_ref, bill_of_lading,
                            scac_code, asn_reference_no, etd,
                            ship_to_org_id, packed_cartons, asn_cartons,
                            ob_asn_shipment_id
              FROM xxd_wsh_staged_deliveries_v
             WHERE (delivery_id = pn_delivery_id OR pn_delivery_id IS NULL);

        l_pn          VARCHAR2 (200) := lg_package_name || '.do_process';
        lv_err_msg    VARCHAR2 (2000);
        lv_err_stat   VARCHAR2 (1);

        ln_count      NUMBER;
    BEGIN
        gc_debug_enable   := NVL (gc_debug_enable, NVL (pv_debug, 'N')); --Enable logging
        debug_msg ('Start Direct ship order process', NULL, l_pn);
        debug_msg ('ORG ID : ' || fnd_global.org_id);
        debug_msg ('USER ID : ' || fnd_global.user_id);
        debug_msg ('LOGIN ID : ' || fnd_global.login_id);
        debug_msg ('CC ID : ' || fnd_global.conc_request_id);
        debug_msg ('EMPLOYEE ID : ' || fnd_global.employee_id);
        debug_msg ('RESP APPL ID : ' || fnd_profile.VALUE ('RESP_APPL_ID'));
        debug_msg ('RESP ID : ' || fnd_profile.VALUE ('RESP_ID'));
        debug_msg ('DELIVERY ID : ' || pn_delivery_id);

        FOR del_rec IN c_deliveries
        LOOP
            lv_err_stat   := 'S';

            --Update attributes in delivery for EDI output.
            UPDATE wsh_new_deliveries
               SET attribute2 = del_rec.scac_code, attribute6 = del_rec.container_ref
             WHERE delivery_id = del_rec.delivery_id;

            COMMIT;

            --If Packed carton count is less than the ASN count then do packing of cartons
            IF del_rec.packed_cartons < del_rec.asn_cartons
            THEN
                debug_msg (
                    'Split delivery details for delivery : ' || del_rec.delivery_id,
                    del_rec.delivery_id,
                    l_pn);
                --Check if entire delivery is staged
                --If all staged then
                split_delivery (del_rec.delivery_id, lv_err_stat, lv_err_msg);
            END IF;

            IF lv_err_stat = 'S'
            THEN
                IF del_rec.ob_asn_shipment_id IS NULL
                THEN
                    debug_msg ('Add EDI Shipment : ' || del_rec.delivery_id,
                               del_rec.delivery_id,
                               l_pn);
                    -- Add records into Do_edi856 tables
                    add_edi_shipments (lv_err_stat,
                                       lv_err_msg,
                                       del_rec.bill_of_lading,
                                       del_rec.container_ref,
                                       del_rec.ship_to_org_id,
                                       del_rec.delivery_id);
                END IF;
            ELSE                             --error occurred in split. Return
                debug_msg (
                       'Exit Direct ship order process : error splitting delivery details : '
                    || lv_err_msg,
                    del_rec.delivery_id,
                    l_pn);

                --Write log for procerss exception log
                debug_msg ('Error splitting delivery details. ' || lv_err_msg, del_rec.delivery_id, l_pn
                           , 'Y');

                --proceed to next delivery
                CONTINUE;
            END IF;

            IF lv_err_stat != 'S'
            THEN
                --Add EDI records failed
                debug_msg (
                       'Exit Direct ship order process : error creating EDI shipments : '
                    || lv_err_msg,
                    del_rec.delivery_id,
                    l_pn);

                --Write log for procerss exception log
                debug_msg ('Error creating EDI shipments. ' || lv_err_msg, del_rec.delivery_id, l_pn
                           , 'Y');

                --proceed to next delivery
                CONTINUE;
            END IF;
        END LOOP;

        pv_err_stat       := 0;
        pv_err_msg        := '';
        debug_msg ('Exit Direct ship order process', NULL, l_pn);
    EXCEPTION
        WHEN OTHERS
        THEN
            pv_err_stat   := 2;
            pv_err_msg    := SQLERRM;
            debug_msg (
                'Exit Direct ship order process with exception ' || SQLERRM,
                NULL,
                l_pn);
    END do_process;
END xxd_wsh_process_order_pkg;
/
