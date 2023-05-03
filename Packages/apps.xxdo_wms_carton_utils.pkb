--
-- XXDO_WMS_CARTON_UTILS  (Package Body) 
--
/* Formatted on 4/26/2023 4:32:05 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXDO_WMS_CARTON_UTILS"
AS
    /********************************************************************************************
       Modification History:
     Version    By                     Date           Comments

     1.0        BT-Technology Team     22-Nov-2014    Updated for  BT
     1.1        Aravind Kannuri        26-Jun-2019    Changes as per CCR0007979(Macau-EMEA)
     1.2        Aravind Kannuri        13-Sep-2021    Changes as per CCR0009444
     1.3        Aravind Kannuri        18-Jul-2022    Changes as per CCR0010058
     1.4        Ramesh Reddy           23-Jan-2023    Changes as per CCR0010325
     ******************************************************************************************/
    --Begin CCR0007790
    l_grn_complete              CONSTANT VARCHAR2 (10) := 'GRN COMPLT';
    l_grn_pending               CONSTANT VARCHAR2 (10) := 'PENDING';
    l_grn_error                 CONSTANT VARCHAR2 (10) := 'ERROR';
    l_grn_complete_no_partial   CONSTANT VARCHAR2 (10) := 'GRN CMP NP';

    --End CCR0007790

    PROCEDURE DoLog (p_text VARCHAR2)
    IS
    BEGIN
        NULL;
        --  DBMS_OUTPUT.put_line (p_text);
        fnd_file.PUT_LINE (fnd_file.LOG, p_text);
    END;

    PROCEDURE run_rcv_transaction_processor (organizatiom_id IN NUMBER, GROUP_ID IN NUMBER, error_stat OUT VARCHAR
                                             , error_msg OUT VARCHAR2)
    IS
    BEGIN
        NULL;
    END;

    PROCEDURE apply_receipts_to_cartons (p_shipment_header_id IN NUMBER, p_err_stat OUT VARCHAR2, p_err_msg OUT VARCHAR2)
    IS
        CURSOR c_rec IS
              SELECT rt.transaction_id, rt.quantity, rt.transaction_date,
                     rt.attribute6, rt.organization_id,           --CCR0007790
                                                        cart.asn_carton_id,
                     cart.quantity cart_qty, cart.quantity_received, cart.rcv_transaction_id,
                     cart.quantity_cancelled, cart.status_flag
                FROM XXDO.XXDO_WMS_ASN_CARTONS cart, rcv_transactions rt
               WHERE     cart.destination_line_id = rt.shipment_line_id
                     AND cart.destination_header_id = rt.shipment_header_id
                     AND rt.attribute6 = cart.carton_number
                     AND rt.shipment_header_id = p_shipment_header_id
                     AND rt.transaction_type = 'DELIVER'
            ORDER BY rt.transaction_id;

        l_send_partial      VARCHAR2 (1);                         --CCR0007790
        l_organization_id   NUMBER;                               --CCR0007790
        --Start Added for CCR0009444
        ln_lastrun_exists   NUMBER := 0;
        lv_lastrun_dt       VARCHAR2 (30);
    --End Added for CCR0009444
    BEGIN
        SAVEPOINT rec_update;

        --Begin CCR0007790
        SELECT ship_to_org_id
          INTO l_organization_id
          FROM rcv_shipment_headers
         WHERE shipment_header_id = p_shipment_header_id;

        --End CCR0007790

        FOR rec IN c_rec
        LOOP
            UPDATE XXDO.XXDO_WMS_ASN_CARTONS
               SET quantity_received = rec.cart_qty, quantity_cancelled = rec.cart_qty - (rec.quantity_received + rec.cart_qty), receive_date = rec.transaction_date,
                   rcv_transaction_id = rec.transaction_id, status_flag = 'RECEIVED'
             WHERE asn_carton_id = rec.asn_carton_id;
        END LOOP;


        --Begin CCR0007790
        --Update ASN status : moved from 3PL interface
        --Get partial receive flag for org
        SELECT NVL (TO_NUMBER (mpd.partial_asn_in_3pl_interface), 1) AS allow_partial
          INTO l_send_partial
          FROM apps.mtl_parameters_dfv mpd, apps.mtl_parameters mp
         WHERE     mp.organization_id = l_organization_id
               AND mpd.row_id = mp.ROWID;

        --Start Commmented for CCR0009444
        --Update ASN with complete status
        /*UPDATE apps.rcv_shipment_headers
           SET asn_status =
                  DECODE (l_send_partial,
                          2, l_grn_complete_no_partial,
                          l_grn_complete)
         WHERE shipment_header_id = p_shipment_header_id;*/
        --End CCR0007790
        --End Commmented for CCR0009444

        --Start Added for CCR0009444
        --To get program last-run date
        BEGIN
              SELECT TO_CHAR (fcr.actual_completion_date, 'dd-mon-yyyy hh24:mi:ss')
                INTO lv_lastrun_dt
                FROM fnd_concurrent_programs fcp, fnd_concurrent_requests fcr
               WHERE     fcp.concurrent_program_id = fcr.concurrent_program_id
                     AND fcp.concurrent_program_name = 'XXDO_3PL_PROGCART'
                     AND fcr.request_id =
                         (SELECT MAX (request_id)
                            FROM fnd_concurrent_requests fcr1
                           WHERE     fcr1.concurrent_program_id =
                                     fcp.concurrent_program_id
                                 AND fcr1.phase_code = 'C'
                                 AND fcr1.status_code = 'C')
            ORDER BY request_id;
        EXCEPTION
            WHEN OTHERS
            THEN
                lv_lastrun_dt   := NULL;
        END;

        fnd_file.put_line (fnd_file.LOG,
                           'program lastrun_dt > ' || lv_lastrun_dt);

        IF lv_lastrun_dt IS NOT NULL
        THEN
            --Validate if any receive transaction exists post lastrun of program
            BEGIN
                  SELECT COUNT (1)
                    INTO ln_lastrun_exists
                    FROM rcv_shipment_headers rsh, rcv_shipment_lines rsl, rcv_transactions rt
                   WHERE     rsh.shipment_header_id = rsl.shipment_header_id
                         AND rsl.shipment_header_id = rt.shipment_header_id
                         AND rsh.shipment_header_id = p_shipment_header_id
                         AND rt.transaction_id =
                             (SELECT MAX (transaction_id)
                                FROM rcv_transactions rt1
                               WHERE rt1.shipment_header_id =
                                     rt.shipment_header_id)
                         AND rsh.asn_status = 'EXTRACTED' -- EXTRACTED/GRN COMPLT
                         AND rsl.source_document_code IN ('PO', 'REQ')
                         AND (TO_CHAR (rt.last_update_date, 'dd-mon-yyyy hh24:mi:ss') >= lv_lastrun_dt)
                ORDER BY rsh.shipment_header_id;
            EXCEPTION
                WHEN OTHERS
                THEN
                    ln_lastrun_exists   := -1;
            END;
        END IF;

        fnd_file.put_line (
            fnd_file.LOG,
            'receipts posted after lastrun > ' || ln_lastrun_exists);

        --Update ASN with complete status
        IF (NVL (ln_lastrun_exists, 0) > 0) --Allow if any receipts posted in last 30 mins
        THEN
            UPDATE apps.rcv_shipment_headers
               SET asn_status = DECODE (l_send_partial, 2, l_grn_complete_no_partial, l_grn_complete), last_update_date = SYSDATE
             WHERE shipment_header_id = p_shipment_header_id;
        END IF;

        --End Added for CCR0009444

        p_err_stat   := 'S';
        p_err_msg    := '';
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK TO rec_update;
            p_err_stat   := 'E';
            p_err_msg    := SQLERRM;
    END;


    PROCEDURE get_asn_destination (p_src_type_id IN NUMBER, p_src_line_id IN NUMBER, p_carton_number IN VARCHAR2
                                   , p_dest_type_id OUT NUMBER, p_dest_header_id OUT NUMBER, p_dest_line_id OUT NUMBER)
    IS
        l_source_type_id            NUMBER;
        l_source_header_id          NUMBER;
        l_source_line_id            NUMBER;
        l_destination_type_id       NUMBER;
        l_destination_line_id       NUMBER;
        l_oe_line_id                NUMBER;
        l_oe_header_id              NUMBER;
        l_new_destination_type_id   NUMBER;
        l_asn_header_id             NUMBER; --Changed naming l_ir_asn_header_id to l_asn_header_id as per ver 1.1
        l_asn_line_id               NUMBER; --Changed naming l_ir_asn_line_id to l_asn_line_id as per ver 1.1
        l_jp_asn_header_id          NUMBER;
        l_jp_asn_line_id            NUMBER;
    BEGIN
        DoLog (
               'Get Destination Src Type : '
            || p_src_type_id
            || ' Src Line : '
            || p_src_line_id);

        IF p_src_type_id = pTypePO
        THEN
            --get destination for a factory container

            BEGIN
                SELECT DISTINCT 1   source_type_id,
                                cart.source_header_id,
                                cart.source_line_id,
                                cart.destination_type_id,
                                cart.destination_line_id,
                                oola.line_id oe_line_id,
                                oola.header_id oe_header_id,
                                CASE
                                    WHEN rsl_ir.shipment_header_id IS NULL
                                    THEN
                                        3
                                    ELSE
                                        2
                                END destination_type_id,
                                rsl_ir.shipment_header_id ir_asn_header_id,
                                rsl_ir.shipment_line_id ir_asn_line_id,
                                NULL jp_asn_header,
                                NULL jp_asn_line
                  INTO l_source_type_id, l_source_header_id, l_source_line_id, l_destination_type_id,
                                       l_destination_line_id, l_oe_line_id, l_oe_header_id,
                                       l_new_destination_type_id, l_asn_header_id, l_asn_line_id,
                                       l_jp_asn_header_id, l_jp_asn_line_id
                  FROM XXDO.XXDO_WMS_ASN_CARTONS cart, rcv_shipment_lines rsl, --  po_line_locations_all plla,
                                                                               oe_order_lines_all oola,
                       wsh_delivery_details wdd, mtl_material_transactions mmt, apps.po_requisition_lines_all prla,
                       apps.rcv_shipment_lines rsl_ir, mtl_parameters mp
                 WHERE     1 = 1
                       AND rsl.to_organization_id = mp.organization_id
                       AND mp.organization_code = 'MC1'
                       AND cart.source_line_id = rsl.shipment_line_id
                       AND cart.item_id = rsl.item_id
                       AND TO_NUMBER (rsl.attribute3) = oola.line_id
                       --    AND rsl.po_line_location_id = plla.line_location_id
                       --    AND TO_CHAR (plla.line_location_id) = oola.attribute16(+)
                       AND oola.source_document_line_id =
                           prla.requisition_line_id(+)
                       AND oola.line_id = wdd.source_line_id(+)
                       AND wdd.delivery_detail_id = mmt.picking_line_id(+)
                       AND mmt.transaction_id = rsl_ir.mmt_transaction_id(+)
                       AND mmt.inventory_item_id = rsl_ir.item_id(+)
                       --AND prla.requisition_line_id =  rsl_ir.requisition_line_id(+)
                       AND cart.source_line_id = p_src_line_id
                       AND cart.carton_number = p_carton_number
                UNION
                --Fac ASN -> DSS order (add link for JP)
                SELECT DISTINCT 1   source_type_id,
                                source_header_id,
                                source_line_id,
                                cart.destination_type_id,
                                cart.destination_line_id,
                                oola.line_id oe_line_id,
                                oola.header_id oe_header_id,
                                CASE
                                    WHEN rsl_jp.shipment_line_id IS NOT NULL
                                    THEN
                                        1
                                    ELSE
                                        3
                                END destination_type_id,
                                NULL ir_asn_header_id,
                                NULL ir_asn_line_id,
                                rsl_jp.shipment_header_id jp_asn_header,
                                rsl_jp.shipment_line_id jp_asn_line
                  FROM XXDO.XXDO_WMS_ASN_CARTONS cart, rcv_shipment_lines rsl, po_line_locations_all plla,
                       oe_drop_ship_sources dss, oe_order_lines_all oola, po_lines_all pla_jp,
                       po_line_locations_all plla_jp, rcv_shipment_lines rsl_jp
                 WHERE     plla.drop_ship_flag = 'Y'
                       AND cart.source_line_id = rsl.shipment_line_id
                       AND cart.item_id = rsl.item_id
                       AND rsl.po_line_location_id = plla.line_location_id
                       AND plla.line_location_id = dss.line_location_id
                       AND dss.line_id = oola.line_id
                       AND oola.line_id = pla_jp.attribute5(+)
                       AND oola.inventory_item_id = pla_jp.item_id(+)
                       AND pla_jp.po_line_id = plla_jp.po_line_id(+)
                       AND plla_jp.line_location_id =
                           rsl_jp.po_line_location_id(+)
                       AND cart.source_line_id = p_src_line_id
                       AND cart.carton_number = p_carton_number
                --START Added as per ver 1.1
                UNION
                --Fac ASN direct to 3PL Orgs
                SELECT DISTINCT 1 source_type_id, cart.source_header_id, cart.source_line_id,
                                cart.destination_type_id, cart.destination_line_id, NULL po_line_id,
                                NULL po_header_id, 2 destination_type_id, rsl.shipment_header_id asn_header_id,
                                rsl.shipment_line_id asn_line_id, NULL jp_asn_header, NULL jp_asn_line
                  FROM xxdo.xxdo_wms_asn_cartons cart, rcv_shipment_headers rsh, rcv_shipment_lines rsl,
                       po_headers_all pha, po_lines_all pla, po_line_locations_all plla,
                       rcv_routing_headers rrh, mtl_parameters mp
                 WHERE     1 = 1
                       AND rsl.to_organization_id = mp.organization_id
                       AND EXISTS
                               (SELECT 1
                                  FROM hr_locations_all hl
                                 WHERE     hl.inventory_organization_id =
                                           rsl.to_organization_id
                                       AND hl.attribute1 IS NOT NULL) -- To fetch all 3PL Orgs
                       AND cart.source_line_id = rsl.shipment_line_id
                       AND cart.item_id = rsl.item_id
                       AND rsl.shipment_header_id = rsh.shipment_header_id
                       AND rsh.receipt_source_code = 'VENDOR'
                       AND rsl.po_header_id = pha.po_header_id
                       AND pha.po_header_id = pla.po_header_id
                       AND pla.po_line_id = plla.po_line_id
                       AND rsl.po_line_location_id = plla.line_location_id
                       AND plla.receiving_routing_id = rrh.routing_header_id
                       AND rrh.routing_name = 'Direct Delivery'
                       AND rsl.shipment_line_status_code IN
                               ('EXPECTED', 'PARTIALLY RECEIVED')
                       AND rsl.quantity_shipped - rsl.quantity_received > 0
                       AND cart.source_line_id = p_src_line_id
                       AND cart.carton_number = p_carton_number;
            --END Added as per ver 1.1
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
                WHEN TOO_MANY_ROWS
                THEN
                    dolog (
                           'Multiple rows returned for line ID : '
                        || p_src_line_id);
            END;

            --Has the destination been set yet
            IF l_destination_type_id IS NULL
            THEN
                IF l_asn_line_id IS NOT NULL
                THEN
                    p_dest_type_id     := pTypeDC;
                    p_dest_header_id   := l_asn_header_id;
                    p_dest_line_id     := l_asn_line_id;
                ELSE
                    p_dest_type_id     := pTypeCustomer;
                    p_dest_header_id   := l_oe_header_id;
                    p_dest_line_id     := l_oe_line_id;
                END IF;
            ELSIF l_destination_type_id = pTypeCustomer
            THEN
                IF l_asn_line_id IS NOT NULL
                THEN
                    p_dest_type_id     := pTypeDC;
                    p_dest_header_id   := l_asn_header_id;
                    p_dest_line_id     := l_asn_line_id;
                ELSIF l_jp_asn_line_id IS NOT NULL
                THEN
                    p_dest_type_id     := pTypePO;
                    p_dest_header_id   := l_jp_asn_header_id;
                    p_dest_line_id     := l_jp_asn_line_id;
                END IF;
            END IF;
        ELSIF p_src_type_id = pTypeDC
        THEN
            BEGIN
                SELECT DISTINCT 1 source_type_id, cart.source_header_id, cart.source_line_id,
                                cart.destination_type_id, rsl_ir.shipment_line_id, wnd.source_header_id oe_header_id,
                                wdd.source_line_id oe_line_id, 2 destination_type_id, rsl_ir.shipment_header_id,
                                rsl_ir.shipment_line_id
                  INTO l_source_type_id, l_source_header_id, l_source_line_id, l_destination_type_id,
                                       l_destination_line_id, l_oe_line_id, l_oe_header_id,
                                       l_new_destination_type_id, l_asn_header_id, l_asn_line_id
                  -- wda.delivery_assignment_id,
                  -- wda.delivery_detail_id
                  FROM XXDO.XXDO_WMS_ASN_CARTONS cart, wsh_new_deliveries wnd, wsh_delivery_assignments wda,
                       wsh_delivery_assignments wda_cart, wsh_delivery_details wdd, mtl_material_transactions mmt,
                       rcv_shipment_lines rsl_ir
                 WHERE     cart.source_header_id = wnd.delivery_id
                       AND cart.source_line_id = wda_cart.delivery_detail_id
                       AND wnd.delivery_id = wda.delivery_id
                       AND wda.delivery_detail_id =
                           wda_cart.parent_delivery_detail_id
                       AND wda_cart.delivery_detail_id =
                           wdd.delivery_detail_id
                       AND mmt.picking_line_id = wdd.delivery_detail_id
                       AND mmt.source_line_id = wdd.source_line_id
                       AND rsl_ir.mmt_transaction_id = mmt.transaction_id
                       AND rsl_ir.item_id = mmt.inventory_item_id
                       AND cart.source_line_id = p_src_line_id
                       AND cart.carton_number = p_carton_number;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
                WHEN TOO_MANY_ROWS
                THEN
                    dolog (
                           'Multiple rows returned for line ID : '
                        || p_src_line_id);
            END;

            IF l_asn_line_id IS NOT NULL
            THEN
                p_dest_type_id     := pTypeDC;
                p_dest_header_id   := l_asn_header_id;
                p_dest_line_id     := l_asn_line_id;
            END IF;
        END IF;

        dolog (
               'p_dest_type_id : '
            || p_dest_type_id
            || ' p_dest_header_id : '
            || p_dest_header_id
            || ' p_dest_line_id : '
            || p_dest_line_id);
    END;

    PROCEDURE update_asn_destination (p_src_header_id IN NUMBER:= NULL, p_dest_header_id IN NUMBER:= NULL, p_err_stat OUT VARCHAR
                                      , p_err_msg OUT VARCHAR2)
    IS
        CURSOR c_recs IS
            SELECT *
              FROM XXDO.XXDO_WMS_ASN_CARTONS
             WHERE     source_header_id =
                       NVL (p_src_header_id, source_header_id)
                   AND NVL (destination_header_id, -1) =
                       NVL (p_dest_header_id,
                            NVL (destination_header_id, -1));

        l_dest_type        NUMBER;
        l_dest_header_id   NUMBER;
        l_dest_line_id     NUMBER;
    BEGIN
        SAVEPOINT header_rec;

        FOR rec IN c_recs
        LOOP
            --Get the destination for this carton
            get_asn_destination (rec.source_type_id,
                                 rec.source_line_id,
                                 rec.carton_number,
                                 l_dest_type,
                                 l_dest_header_id,
                                 l_dest_line_id);

            dolog (l_dest_type || '-' || rec.destination_type_id); --if the destination type changed than update the links

            IF    rec.destination_type_id IS NULL
               OR l_dest_type != rec.destination_type_id
            THEN
                dolog (rec.carton_number);

                UPDATE XXDO.XXDO_WMS_ASN_CARTONS
                   SET destination_type_id = l_dest_type, destination_header_id = l_dest_header_id, destination_line_id = l_dest_line_id
                 WHERE     source_line_id = rec.source_line_id
                       AND carton_number = rec.carton_number;
            END IF;
        END LOOP;

        p_err_stat   := 'S';
        p_err_msg    := '';
        COMMIT;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_err_stat   := 'E';
            p_err_msg    :=
                'Update_asn_destination - Error occurred : ' || SQLERRM;
            ROLLBACK TO header_rec;
    END;

    FUNCTION check_carton_receiving (p_grn_header_id IN NUMBER)
        RETURN NUMBER
    IS
        l_carton_count          NUMBER;
        l_source_header_id      NUMBER;
        l_grn_quantity          NUMBER;
        l_no_cartons            NUMBER;
        l_cnt_missing_cartons   NUMBER;
    BEGIN
        BEGIN
            dolog ('check_carton_receiving-enter : ' || p_grn_header_id);

              --Get carton count from GRN tables
              --grn_header_id is 1-1 with source header id
              SELECT source_header_id, SUM (quantity_to_receive) grn_quantity, COUNT (DISTINCT carton_code) no_cartons,
                     SUM (DECODE (carton_code, NULL, 1, 0)) cnt_missing_cartons
                INTO l_source_header_id, l_grn_quantity, l_no_cartons, l_cnt_missing_cartons
                FROM XXDO.XXDO_WMS_3PL_GRN_L l, XXDO.XXDO_WMS_3PL_GRN_H h
               WHERE     l.grn_header_id = h.grn_header_id
                     AND h.grn_header_id = p_grn_header_id
            GROUP BY source_header_id;
        EXCEPTION
            WHEN NO_DATA_FOUND
            THEN
                dolog ('no_data_found here');
                RETURN 0;
        END;

        dolog (
               'No cartons : '
            || l_no_cartons
            || ' cnt_missing_cartons : '
            || l_cnt_missing_cartons);

        IF l_cnt_missing_cartons > 0
        THEN
            dolog ('missing cartons');

            --there are lines w/o carton data. we need to invalidate any reaining unreceived cartons and any ASNs sourcing this grn
            --This inactivates the entire IR ASN even if it is not asll contained on this GRN
            UPDATE XXDO.XXDO_WMS_ASN_CARTONS cart
               SET status_flag   = 'INACTIVE'
             WHERE asn_carton_id IN
                       (SELECT asn_carton_id
                          FROM XXDO.XXDO_WMS_ASN_CARTONS cart, rcv_shipment_lines rsl, XXDO.XXDO_WMS_3PL_GRN_L l
                         WHERE     CART.destination_header_ID =
                                   rsl.shipment_header_id
                               AND rsl.shipment_line_id = l.source_line_id
                               AND rsl.item_id = l.inventory_item_id
                               AND cart.status_flag != 'RECEIVED'
                               AND l.grn_header_id = p_grn_header_id);

            UPDATE rcv_shipment_headers
               SET attribute4   = 'N'
             WHERE shipment_header_id IN
                       (SELECT shipment_header_id
                          FROM rcv_shipment_lines rsl, XXDO.XXDO_WMS_3PL_GRN_L l
                         WHERE     rsl.shipment_line_id = l.source_line_id
                               AND l.grn_header_id = p_grn_header_id);

            RETURN 0;
        END IF;

        SELECT COUNT (*)
          INTO l_carton_count
          FROM apps.rcv_shipment_headers rsh, apps.rcv_shipment_lines rsl, XXDO.XXDO_WMS_ASN_CARTONS cart
         WHERE     rsh.shipment_header_id = rsl.shipment_header_id
               AND rsl.shipment_line_id = cart.destination_line_id(+)
               AND rsh.shipment_header_id IN
                       (SELECT shipment_header_id
                          FROM rcv_shipment_lines rsl, XXDO.XXDO_WMS_3PL_GRN_L l
                         WHERE     rsl.shipment_line_id = l.source_line_id
                               AND l.grn_header_id = p_grn_header_id)
               AND cart.carton_number IS NOT NULL
               AND rsh.attribute4 = 'Y';         --Cartons were enabled for PA

        IF l_carton_count > 0
        THEN
            RETURN 1;
        ELSE
            RETURN 0;
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            dolog ('err ' || SQLERRM);
    END;


    --Check if carton codes are valid for this shipment
    --Cartons can only be sent if there are carons in the cartons table and the count of cartons/sum items matches the ASN
    --Also ther cannot be any INACTIVE cartons
    FUNCTION check_asn_cartons (p_source_header_id IN NUMBER)
        RETURN NUMBER
    IS
        l_rec_count         NUMBER;
        l_cnt_inactive      NUMBER;

        l_rsl_item_cnt      NUMBER;
        l_rsl_shipped       NUMBER;
        l_cart_item_cnt     NUMBER;
        l_cart_shipped      NUMBER;
        l_carton_flag       NUMBER := -1;        --Initialize an invalid state
        l_carton_flag_new   NUMBER := 1;      --Initialize to contains cartons
        l_cartons_enabled   VARCHAR2 (1);

        CURSOR c_asn_list IS
            SELECT shipment_header_id, attribute4
              FROM rcv_shipment_headers
             WHERE attribute2 = TO_CHAR (p_source_header_id);
    BEGIN
        FOR rec IN c_asn_list
        LOOP
            --Check if destination is enabled for cartons.
            l_carton_flag_new   := 1;

            SELECT CASE NVL (mp.attribute15, '0')
                       WHEN '2' THEN 'Y'
                       ELSE 'N'
                   END cartons_enabled
              INTO l_cartons_enabled
              FROM rcv_shipment_headers rsh, mtl_parameters mp
             WHERE     rsh.ship_to_org_id = mp.organization_id
                   AND rsh.shipment_header_id = rec.shipment_header_id;

            IF l_cartons_enabled = 'N'
            THEN
                l_carton_flag_new   := 0;
            END IF;


            IF l_carton_flag_new = 1
            THEN
                SELECT COUNT (*) rec_count,       --total count of carton data
                                            SUM (DECODE (status_flag, 'INACTIVE', 1, 0)) cnt_inactive --total inactive cartons
                  INTO l_rec_count, l_cnt_inactive
                  FROM XXDO.XXDO_WMS_ASN_CARTONS cart
                 WHERE cart.destination_header_id = rec.shipment_header_id;

                IF l_rec_count = 0
                THEN
                    l_carton_flag_new   := 0;
                END IF;

                IF l_cnt_inactive > 0
                THEN
                    --theree are inactive cartons
                    l_carton_flag_new   := 0;
                END IF;
            END IF;



            IF l_carton_flag_new = 1
            THEN
                BEGIN
                      --match carton count in ASN with carton count in custom table
                      SELECT COUNT (DISTINCT rsl.item_id) rsl_item_cnt, SUM (quantity_shipped) rsl_shipped, COUNT (DISTINCT cart.item_id) cart_item_cnt,
                             SUM (cart_qty) cart_shipped
                        INTO l_rsl_item_cnt, l_rsl_shipped, l_cart_item_cnt, l_cart_shipped
                        FROM rcv_shipment_lines rsl,
                             (  SELECT destination_header_id, destination_line_id, 1 cart_items,
                                       item_id, SUM (quantity) cart_qty
                                  FROM XXDO.XXDO_WMS_ASN_CARTONS
                              GROUP BY item_id, destination_header_id, destination_line_id)
                             cart
                       WHERE     rsl.shipment_header_id =
                                 rec.shipment_header_id
                             AND rsl.item_id = cart.item_id(+)
                             AND rsl.shipment_line_id =
                                 cart.destination_line_id(+)
                             AND rsl.shipment_header_id =
                                 cart.destination_header_id(+)
                    GROUP BY cart_items;                  --no cartons in data
                EXCEPTION
                    WHEN NO_DATA_FOUND
                    THEN
                        l_carton_flag_new   := 0;
                END;



                --Mismatch between RSL and Carton count on this ASN
                IF    l_rsl_item_cnt <> l_cart_item_cnt
                   OR l_rsl_shipped <> l_cart_shipped
                THEN
                    l_carton_flag_new   := 0;
                END IF;
            END IF;



            --if the new setting for cartons does not match prior and prior has been initialized then we have a heterogenous
            --grouping. set to -1 error state and exit.loop
            IF l_carton_flag_new != l_carton_flag AND l_carton_flag != -1
            THEN
                l_carton_flag   := -1;
                EXIT;
            ELSE
                l_carton_flag   := l_carton_flag_new;
            END IF;
        END LOOP;

        RETURN l_carton_flag;
    EXCEPTION
        WHEN OTHERS
        THEN
            RETURN 0;
    END;

    /*-------------------------------
             Populate_factory_cartons

             Populate the cartons table for a factory ASN
             Parameters
             p_shipment_header_id :  ASN Header ID
             p_reload            : remove and reload cartond for a Factory ASN. Only used if no Shipment ID is passed
             p_start_date        : look only for ASNs that were created since this date. Only used if no Shipment ID is passed



             ---------------------------------*/

    PROCEDURE populate_factory_cartons (
        p_shipment_header_id   IN     NUMBER,
        p_reload               IN     VARCHAR2 := 'N',
        p_start_date           IN     DATE,
        p_err_stat                OUT VARCHAR2,
        p_err_msg                 OUT VARCHAR2)
    IS
        l_asn_carton_id    NUMBER;
        p_user_id          NUMBER := fnd_global.user_id;
        l_carton_status    VARCHAR2 (1);
        l_count            NUMBER;
        l_quantity         NUMBER;
        l_num_containers   NUMBER;
        l_dest_type        NUMBER;
        l_dest_header_id   NUMBER;
        l_dest_line_id     NUMBER;


        CURSOR c_headers IS
              SELECT DISTINCT SHIPMENT_HEADER_ID, REQ_CREATED_DATE, COUNT (*) NUM_LINES,
                              NVL (SUM (QUANTITY), 0) QTY, COUNT (DISTINCT CARTON_NUMBER) CNT_CARTONS
                FROM XXDO.XXDO_FACTORY_CONTAINERS_V VW
               WHERE     SHIPMENT_HEADER_ID =
                         NVL (P_SHIPMENT_HEADER_ID, SHIPMENT_HEADER_ID)
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM XXDO.XXDO_WMS_ASN_CARTONS ASN_CART
                               WHERE ASN_CART.SOURCE_HEADER_ID =
                                     VW.SHIPMENT_HEADER_ID)
                     AND REQ_CREATED_DATE >=
                         CASE
                             WHEN P_SHIPMENT_HEADER_ID IS NULL
                             THEN
                                 NVL (P_START_DATE, REQ_CREATED_DATE)
                             ELSE
                                 REQ_CREATED_DATE
                         END
            GROUP BY SHIPMENT_HEADER_ID, REQ_CREATED_DATE;

        CURSOR c_cartons (l_shipment_header_id NUMBER)
        IS
            SELECT *
              FROM XXDO.XXDO_FACTORY_CONTAINERS_V
             WHERE     shipment_header_id = l_shipment_header_id
                   AND NVL (QUANTITY, 0) > 0;
    BEGIN
        DoLog ('populate_factory_cartons - Enter');

        FOR header_rec IN c_headers
        LOOP
            DoLog (
                'Processing header id : ' || header_rec.shipment_header_id);

            SAVEPOINT header_rec;

            --Check ASN status
            BEGIN
                SELECT attribute4
                  INTO l_carton_status
                  FROM rcv_shipment_headers
                 WHERE shipment_header_id = header_rec.shipment_header_id;
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            END;



            FOR carton_rec IN c_cartons (header_rec.shipment_header_id)
            LOOP
                SELECT xxdo.XXDO_WMS_ASN_CARTONS_s.NEXTVAL
                  INTO l_asn_carton_id
                  FROM DUAL;

                DoLog ('Next Val ' || l_asn_carton_id);

                INSERT INTO XXDO.XXDO_WMS_ASN_CARTONS (
                                asn_carton_id,
                                source_type_id,
                                source_header_id,
                                source_line_id,
                                source_organization_id,
                                status_flag,
                                carton_number,
                                quantity,
                                item_id,
                                quantity_received,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                po_header_id,
                                po_line_id,
                                destination_location_id)
                         VALUES (l_asn_carton_id,
                                 pTypePO,                                 --PO
                                 carton_rec.shipment_header_id,
                                 carton_rec.shipment_line_id,
                                 NULL,
                                 'ACTIVE',
                                 carton_rec.carton_number,
                                 carton_rec.quantity,
                                 carton_rec.item_id,
                                 0,
                                 p_user_id,
                                 SYSDATE,
                                 p_user_id,
                                 SYSDATE,
                                 carton_rec.po_header_id,
                                 carton_rec.po_line_id,
                                 carton_rec.destination_location_id);
            END LOOP;

            --Validate ASN carrton contents
            SELECT COUNT (*), SUM (quantity), COUNT (DISTINCT carton_number)
              INTO l_count, l_quantity, l_num_containers
              FROM XXDO.XXDO_WMS_ASN_CARTONS
             WHERE     source_header_id = header_rec.shipment_header_id
                   AND source_type_id = pTypePO;



            DoLog ('After processing counts');
            DoLog (
                   'Total Lines - ASN : '
                || header_rec.num_lines
                || ' - Carton tbl : '
                || l_count);
            DoLog (
                   'Total Qty - ASN : '
                || header_rec.qty
                || ' - Carton tbl : '
                || l_quantity);
            DoLog (
                   'Total Cartons - ASN : '
                || header_rec.cnt_cartons
                || ' - Carton tbl : '
                || l_num_containers);


            IF    l_count != header_rec.num_lines
               OR l_quantity != header_rec.qty
               OR l_num_containers != header_rec.cnt_cartons
            THEN
                DoLog ('Mismatch in carton data');

                ROLLBACK TO header_rec;

                UPDATE rcv_shipment_headers
                   SET attribute4   = 'N'
                 WHERE shipment_header_id = header_rec.shipment_header_id;

                COMMIT;
            ELSE
                --Update shipment header for carton tracking
                UPDATE rcv_shipment_headers
                   SET attribute4   = 'Y'
                 WHERE shipment_header_id = header_rec.shipment_header_id;

                DoLog ('Populating dest data');
                update_asn_destination (header_rec.shipment_header_id, NULL, p_err_stat
                                        , p_err_msg);

                COMMIT;
            END IF;

            DoLog ('Processing shipment complete');
        END LOOP;

        p_err_stat   := 'S';
        p_err_msg    := '';

        DoLog ('populate_factory_cartons - End');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_err_msg    := 'populate_factory_cartons - Error' || SQLERRM;
            DoLog (p_err_msg);
            p_err_stat   := 'E';
    END;

    PROCEDURE populate_dc_cartons (p_delivery_id   IN     NUMBER,
                                   p_reload        IN     VARCHAR2 := 'N',
                                   p_start_date    IN     DATE,
                                   p_err_stat         OUT VARCHAR2,
                                   p_err_msg          OUT VARCHAR2)
    IS
        l_asn_carton_id        NUMBER;
        l_shipment_header_id   NUMBER;
        l_user_id              NUMBER := fnd_global.user_id;
        l_carton_status        VARCHAR2 (1);
        l_count                NUMBER;
        l_quantity             NUMBER;
        l_num_containers       NUMBER;

        CURSOR c_headers IS
              SELECT delivery_id, confirm_date, COUNT (*) NUM_LINES,
                     SUM (QUANTITY) QTY, COUNT (DISTINCT CARTON_NUMBER) CNT_CARTONS
                FROM XXDO.XXDO_WMS_DC_CONTAINERS_V vw
               WHERE     delivery_id = NVL (P_delivery_id, delivery_id)
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM XXDO.XXDO_WMS_ASN_CARTONS ASN_CART
                               WHERE ASN_CART.SOURCE_HEADER_ID = VW.delivery_id)
                     AND confirm_DATE >=
                         CASE
                             WHEN P_delivery_id IS NULL
                             THEN
                                 NVL (P_START_DATE, confirm_date)
                             ELSE
                                 confirm_date
                         END
            GROUP BY delivery_id, confirm_date;

        CURSOR c_cartons (l_delivery_id NUMBER)
        IS
            SELECT *
              FROM XXDO.XXDO_WMS_DC_CONTAINERS_V
             WHERE delivery_id = l_delivery_id;
    BEGIN
        DoLog ('populate_dc_cartons Enter - ' || p_delivery_id);

        FOR header_rec IN c_headers
        LOOP
            DoLog ('Processing header id : ' || header_rec.delivery_id);
            SAVEPOINT header_rec;                       --Added as per ver 1.1

            --Check ASN status
            --Proposed Attribute5 on RSH = parent delivery ID. option to use function instead
            BEGIN
                SELECT attribute4, shipment_header_id
                  INTO l_carton_status, l_shipment_header_id
                  FROM rcv_shipment_headers
                 WHERE shipment_num = TO_CHAR (p_delivery_id); --Verify shipment_num = delivery_id for all ASNs from a DC shipment
            EXCEPTION
                WHEN NO_DATA_FOUND
                THEN
                    NULL;
            --TODO: Shipment not found;
            END;


            FOR carton_rec IN c_cartons (header_rec.delivery_id)
            LOOP
                SELECT xxdo.XXDO_WMS_ASN_CARTONS_s.NEXTVAL
                  INTO l_asn_carton_id
                  FROM DUAL;

                DoLog ('Next Val ' || l_asn_carton_id);

                INSERT INTO XXDO.XXDO_WMS_ASN_CARTONS (
                                asn_carton_id,
                                source_type_id,
                                source_header_id,
                                source_line_id,
                                source_organization_id,
                                status_flag,
                                carton_number,
                                quantity,
                                item_id,
                                quantity_received,
                                created_by,
                                creation_date,
                                last_updated_by,
                                last_update_date,
                                delivery_id)
                     VALUES (l_asn_carton_id, pTypeDC,                    --PO
                                                       carton_rec.delivery_id, carton_rec.delivery_detail_id, NULL, 'ACTIVE', carton_rec.carton_number, carton_rec.quantity, carton_rec.item_id, 0, l_user_id, SYSDATE
                             , l_user_id, SYSDATE, carton_rec.delivery_id);
            END LOOP;


            --Validate ASN carrton contents
            SELECT COUNT (*), SUM (quantity), COUNT (DISTINCT carton_number)
              INTO l_count, l_quantity, l_num_containers
              FROM XXDO.XXDO_WMS_ASN_CARTONS
             WHERE     source_header_id = header_rec.delivery_id
                   AND source_type_id = pTypeDC;

            DoLog ('After processing counts');
            DoLog (
                   'Total Lines - ASN : '
                || header_rec.num_lines
                || ' - Carton tbl : '
                || l_count);
            DoLog (
                   'Total Qty - ASN : '
                || header_rec.qty
                || ' - Carton tbl : '
                || l_quantity);
            DoLog (
                   'Total Cartons - ASN : '
                || header_rec.cnt_cartons
                || ' - Carton tbl : '
                || l_num_containers);

            IF    l_count != header_rec.num_lines
               OR l_quantity != header_rec.qty
               OR l_num_containers != header_rec.cnt_cartons
            THEN
                DoLog ('Rollback');
                DoLog ('Mismatch in carton data');
                ROLLBACK TO header_rec;

                UPDATE rcv_shipment_headers
                   SET attribute4   = 'N'
                 WHERE shipment_header_id = header_rec.delivery_id;

                COMMIT;
            ELSE
                DoLog ('Populating dest data');
                update_asn_destination (header_rec.delivery_id, NULL, p_err_stat
                                        , p_err_msg);

                DoLog ('Commit');
                COMMIT;
            END IF;
        END LOOP;

        DoLog ('populate_dc_cartons - End');
        p_err_stat   := 'S';
        p_err_msg    := '';
    EXCEPTION
        WHEN OTHERS
        THEN
            p_err_msg    := 'populate_dc_cartons - Error' || SQLERRM;
            DoLog (p_err_msg);
            p_err_stat   := 'E';
    END;

    ---Entry functions

    PROCEDURE populate_carton_data (p_src_type IN NUMBER, p_src_key IN NUMBER, p_reload IN VARCHAR2:= 'N'
                                    , p_start_date IN DATE, p_err_stat OUT VARCHAR2, p_err_msg OUT VARCHAR2)
    IS
    BEGIN
        --Shipments from a Factory / purchase order
        IF p_src_type = pTypePO
        THEN
            populate_factory_cartons (p_shipment_header_id   => p_src_key,
                                      p_reload               => p_reload,
                                      p_start_date           => p_start_date,
                                      p_err_stat             => p_err_stat,
                                      p_err_msg              => p_err_msg);
        ELSIF p_src_type = pTypeDC
        THEN
            populate_dc_cartons (p_delivery_id   => p_src_key,
                                 p_reload        => p_reload,
                                 p_start_date    => p_start_date,
                                 p_err_stat      => p_err_stat,
                                 p_err_msg       => p_err_msg);
        ELSE
            DoLog ('Unsupported source type.');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            p_err_stat   := 'E';
            p_err_msg    := 'Error occurred ' || SQLERRM;
            DoLog (p_err_msg);
    END;

    PROCEDURE progress_cartons (p_err_stat OUT VARCHAR2, p_err_msg OUT VARCHAR2, p_no_days IN NUMBER:= 1)
    AS
        CURSOR c_new_asns IS
            SELECT DISTINCT shipment_header_id
              FROM rcv_shipment_headers rsh, mtl_parameters mp
             WHERE     rsh.attribute4 IS NULL
                   AND rsh.ship_to_org_id = mp.organization_id
                   AND mp.wms_enabled_flag = 'N'
                   AND rsh.receipt_source_code = 'VENDOR'
                   AND rsh.creation_date >=
                       TRUNC (SYSDATE) - NVL (p_no_days, 1);

        CURSOR c_iso_orders IS
            SELECT DISTINCT ooha.header_id
              FROM oe_order_headers_all ooha, oe_order_lines_all oola, wsh_delivery_details wdd
             WHERE     oola.header_id = ooha.header_id
                   AND oola.line_id = wdd.source_line_id
                   AND oola.header_id = wdd.source_header_id
                   AND oola.actual_shipment_date >=
                       TRUNC (SYSDATE) - NVL (p_no_days, 1)
                   AND oola.order_source_id = 10
                   AND wdd.released_status = 'C'
                   --Begin CCR0007790
                   --No closed WDD records for the SO that are not interfaced
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM wsh_delivery_details wdd1
                             WHERE     wdd1.source_header_id = ooha.header_id
                                   AND wdd1.released_status = 'C'
                                   AND wdd1.inv_interfaced_flag != 'Y')
                   --End CCR0007790
                   AND EXISTS
                           (SELECT 1
                              FROM XXDO.XXDO_WMS_ASN_CARTONS cart
                             WHERE     cart.destination_header_id =
                                       ooha.header_id
                                   AND cart.destination_type_id =
                                       pTypeCustomer);

        CURSOR c_dc_shipments IS
            SELECT DISTINCT wnd.delivery_id
              FROM wsh_new_deliveries wnd, wsh_delivery_details wdd, wsh_delivery_assignments wda,
                   oe_order_headers_all ooha, oe_order_lines_all oola
             WHERE     wnd.status_code = 'CL'
                   AND confirm_date >= TRUNC (SYSDATE) - NVL (p_no_days, 1)
                   AND wdd.source_line_id(+) = oola.line_id
                   AND wda.delivery_detail_id = wdd.delivery_detail_id
                   AND wnd.delivery_id = wda.delivery_id
                   AND ooha.header_id = oola.header_id
                   AND ooha.order_source_id = 10 --TODO: Make more generic to ExUS DC shipments
                   -- AND ooha.org_id IN (81, 95, 98, 99)   --Commented as per ver 1.1 to support CA and other OUs
                   --Begin CCR0007790
                   --No closed WDD records for the delivery that are not interfaced
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM wsh_delivery_details wdd1, wsh_delivery_assignments wda1
                             WHERE     wdd1.delivery_detail_id =
                                       wda1.delivery_detail_id
                                   AND wda1.delivery_id = wnd.delivery_id
                                   AND wdd1.released_status = 'C'
                                   AND wdd1.inv_interfaced_flag != 'Y')
                   --End CCR0007790
                   AND NOT EXISTS
                           (SELECT NULL
                              FROM XXDO.XXDO_WMS_ASN_CARTONS cart
                             WHERE cart.delivery_id = wnd.delivery_id);

        --get distinct listing of factory ASNs having an errored IR ASN. These will be removed so the process will regenerate
        CURSOR c_iso_asn_err IS
            SELECT DISTINCT rsl_fac.shipment_header_id
              FROM rcv_shipment_lines rsl_fac, oe_order_lines_all oola, wsh_delivery_details wdd,
                   mtl_material_transactions mmt, rcv_shipment_lines rsl, rcv_shipment_headers rsh
             WHERE     1 = 1
                   AND rsl_fac.attribute3 = TO_NUMBER (oola.line_id)
                   AND oola.line_id = wdd.source_line_id
                   AND mmt.picking_line_id = wdd.delivery_detail_id
                   AND rsl.mmt_transaction_id = mmt.transaction_id
                   AND rsl.item_id = mmt.inventory_item_id
                   AND rsh.shipment_header_id = rsl.shipment_header_id
                   AND rsh.asn_status = 'ERROR';

        CURSOR c_iso_asn IS
              SELECT shipment_header_id,
                     creation_date,
                     CASE NVL (attribute15, '0')
                         WHEN '2' THEN 'Y'
                         ELSE 'N'
                     END carton_extract,
                     SUM (qty_shipped) total_shipped,
                     SUM (qty_received) total_received,
                     SUM (ABS (var)) asn_variance,
                     SUM (carton_qty) total_carton_qty,
                     SUM (carton_rcv) total_carton_rcv
                FROM (  SELECT rsh.creation_date, rsh.shipment_num, rsh.shipment_header_id,
                               rsh.ship_to_org_id, rsl.item_id, mp.attribute15,
                               SUM (rsl.quantity_shipped) qty_shipped, SUM (rsl.quantity_received) qty_received, NVL (SUM (cart.qty), 0) carton_qty,
                               NVL (SUM (qty_rcv), 0) carton_rcv, SUM (rsl.quantity_shipped - NVL (cart.qty, 0)) var
                          FROM rcv_shipment_headers rsh,
                               rcv_shipment_lines rsl,
                               mtl_parameters mp,
                               (  SELECT destination_header_id, -- Added for CCR0010325
                                                                destination_line_id, SUM (quantity) qty,
                                         SUM (quantity_received) qty_rcv
                                    FROM XXDO.XXDO_WMS_ASN_CARTONS
                                GROUP BY destination_header_id, destination_line_id)
                               cart
                         WHERE     rsh.shipment_header_id =
                                   rsl.shipment_header_id
                               AND rsh.ship_to_org_id = mp.organization_id
                               AND rsl.shipment_header_id =
                                   cart.destination_header_id(+) -- Added for CCR0010325
                               AND rsl.shipment_line_id =
                                   cart.destination_line_id(+)
                               --AND mp.attribute15 = '2'
                               AND rsh.asn_status IS NULL
                               AND rsh.receipt_source_code = 'INTERNAL ORDER'
                               AND rsh.creation_date >=
                                   TRUNC (SYSDATE) - NVL (p_no_days, 1)
                      GROUP BY rsh.creation_date, rsh.shipment_num, rsh.shipment_header_id,
                               rsh.ship_to_org_id, mp.attribute15, rsl.item_id)
            GROUP BY shipment_header_id,
                     creation_date,
                     CASE NVL (attribute15, '0')
                         WHEN '2' THEN 'Y'
                         ELSE 'N'
                     END;

        --Begin CCR007790
        CURSOR c_receipts IS
              SELECT rt.shipment_header_id
                FROM rcv_transactions rt,
                     rcv_shipment_headers rsh,
                     (SELECT *
                        FROM XXDO.XXDO_WMS_ASN_CARTONS
                       WHERE     status_flag = 'ACTIVE'
                             AND NVL (quantity_received, 0) = 0) cart
               WHERE     rt.shipment_line_id = cart.destination_line_id(+)
                     AND rt.shipment_header_id = cart.destination_header_id(+)
                     AND rt.attribute6 = cart.carton_number(+)
                     AND rt.shipment_header_id = rsh.shipment_header_id
                     AND NOT EXISTS
                             (SELECT NULL
                                FROM XXDO.XXDO_WMS_ASN_CARTONS c1
                               WHERE     c1.status_flag IN
                                             ('INACTIVE', 'RECEIVED')
                                     AND rt.shipment_line_id =
                                         c1.destination_line_id
                                     AND rt.shipment_header_id =
                                         c1.destination_header_id
                                     AND rt.attribute6 = c1.carton_number)
                     AND rsh.asn_status = 'EXTRACTED'
            GROUP BY rt.shipment_header_id
              --HAVING MIN (rt.transaction_date) >=       --Commented for 1.3
              HAVING MAX (rt.transaction_date) >=              --Added for 1.3
                     TRUNC (SYSDATE) - NVL (p_no_days, 1);

        --End CCR007790

        --CURSOR c_tq_asns   --Commented and updated cursor_name as per ver 1.1
        CURSOR c_dir_ship_asns IS
            SELECT DISTINCT rsh.shipment_header_id
              FROM rcv_shipment_headers rsh, ap_suppliers aps
             WHERE     rsh.asn_status IS NULL
                   AND rsh.receipt_source_code = 'VENDOR'
                   --START Added as per ver 1.1
                   --AND aps.vendor_type_lookup_code = 'TQ PROVIDER' --Commented not only for TQ provider Factory ASNs
                   AND EXISTS
                           (SELECT 1
                              FROM hr_locations_all hl
                             WHERE     hl.inventory_organization_id =
                                       rsh.ship_to_org_id
                                   AND hl.attribute1 IS NOT NULL) -- To fetch all 3PL Orgs
                   --End Added as per ver 1.1
                   AND rsh.vendor_id = aps.vendor_id
                   AND rsh.creation_date >=
                       TRUNC (SYSDATE) - NVL (p_no_days, 1);

        n_cnt   NUMBER := 0;
    BEGIN
        dolog ('progress_cartons - Enter');
        DoLog ('Num Days : ' || p_no_days);

        --clear out any  ASNs having errored IR ASNs
        FOR c_rec IN c_iso_asn_err
        LOOP
            doLog (
                'Clearing cartons for shipment : ' || c_rec.shipment_header_id);

            DELETE FROM XXDO.XXDO_WMS_ASN_CARTONS
                  WHERE source_header_id = c_rec.shipment_header_id;

            UPDATE rcv_shipment_headers
               SET attribute4   = NULL
             WHERE shipment_header_id = c_rec.shipment_header_id;
        END LOOP;

        --Reset any errored ASNs
        UPDATE rcv_shipment_headers rsh
           SET asn_status = NULL, attribute4 = NULL
         WHERE     asn_status = 'ERROR'
               AND NOT EXISTS
                       (SELECT NULL
                          FROM XXDO.XXDO_WMS_ASN_CARTONS
                         WHERE destination_header_id = rsh.shipment_header_id);

        COMMIT;

        --Progress carton table data:
        --1) Create carton data for factory /DC shipments missing data
        dolog ('1 - Creating Factory ASN cartons');

        FOR c_rec IN c_new_asns
        LOOP
            dolog (' > Shipment Header ID : ' || c_rec.shipment_header_id);
            populate_carton_data (p_src_type     => pTypePO,
                                  p_src_key      => c_rec.shipment_header_id,
                                  p_reload       => NULL,
                                  p_start_date   => NULL,   --TRUNC (SYSDATE),
                                  p_err_stat     => p_err_stat,
                                  p_err_msg      => p_err_msg);
        END LOOP;


        doLog ('2 - Progress cartons for ISO shipment');

        --2) Progress shipped ISO orders
        FOR c_rec IN c_iso_orders
        LOOP
            dolog (' > Header ID : ' || c_rec.header_id);
            --Update carton data for delivery
            update_asn_destination (p_src_header_id => NULL, p_dest_header_id => c_rec.header_id, p_err_stat => p_err_stat
                                    , p_err_msg => p_err_msg);
        END LOOP;

        --3) Create cartons for ExDC ISO shipments
        doLog ('3 - Create cartons for exUS ISO shipments');

        FOR c_rec IN c_dc_shipments
        LOOP
            dolog (' > Delivery ID : ' || c_rec.delivery_id);
            populate_carton_data (p_src_type     => pTypeDC,
                                  p_src_key      => c_rec.delivery_id,
                                  p_reload       => NULL,
                                  p_start_date   => NULL,   --TRUNC (SYSDATE),
                                  p_err_stat     => p_err_stat,
                                  p_err_msg      => p_err_msg);
        END LOOP;

        --4) check internal order ASNs for container data and update ASN_STATUS to PENDING

        --First balance ASN with cartons in the cartons table
        n_cnt        := 0;

        FOR c_rec IN c_iso_asn
        LOOP
            dolog ('> shipment header id : ' || c_rec.total_carton_qty);

            IF c_rec.asn_variance = 0
            THEN
                --No imbalance between the RASN and the carton
                UPDATE rcv_shipment_headers
                   SET asn_status = 'PENDING', attribute4 = c_rec.carton_extract
                 WHERE shipment_header_id = c_rec.shipment_header_id;
            ELSE
                IF c_rec.total_carton_qty = 0
                THEN
                    --No cartons sent. PA can proceed
                    UPDATE rcv_shipment_headers
                       SET asn_status = 'PENDING', attribute4 = 'N'
                     WHERE shipment_header_id = c_rec.shipment_header_id;
                ELSE
                    --there is a mismatch between the ASN and the carton data some carton data sent. Fail this ASN
                    DoLog ('--ASN mismatch with carton count');
                    n_cnt   := n_cnt + 1;

                    UPDATE rcv_shipment_headers
                       SET asn_status = 'ERROR', attribute4 = 'N'
                     WHERE shipment_header_id = c_rec.shipment_header_id;
                END IF;
            END IF;
        END LOOP;

        IF n_cnt != 0
        THEN
            NULL;
        END IF;

        --5) complete carton receipts for received carton transactions
        FOR c_rec IN c_receipts
        LOOP
            apply_receipts_to_cartons (
                p_shipment_header_id   => c_rec.shipment_header_id,
                p_err_stat             => p_err_stat,
                p_err_msg              => p_err_msg);
        END LOOP;

        --6) Update ASN status on POs shipping to DC (TQ + 3PL)
        FOR c_rec IN c_dir_ship_asns      --Updated cursor name as per ver 1.1
        LOOP
            UPDATE rcv_shipment_headers
               SET asn_status   = 'PENDING'
             WHERE shipment_header_id = c_rec.shipment_header_id;
        END LOOP;

        p_err_stat   := '';
        p_err_msg    := NULL;
        dolog ('progress_cartons - Exit');
    EXCEPTION
        WHEN OTHERS
        THEN
            p_err_stat   := 'E';
            p_err_msg    := 'Error occurred : ' || SQLERRM;
    END;
END XXDO_WMS_CARTON_UTILS;
/
