--
-- XXD_ONT_BULK_CALLOFF_ORDER_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:29:03 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_BULK_CALLOFF_ORDER_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_BULK_CALLOFF_ORDER_PKG
    * Design       : This package will be used for processing Calloff Orders
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 21-Nov-2017  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    gn_org_id              NUMBER := fnd_global.org_id;
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gn_application_id      NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id   NUMBER := fnd_profile.VALUE ('RESP_ID');
    gc_delimiter           VARCHAR2 (100);
    gc_debug_enable        VARCHAR2 (1)
        := NVL (fnd_profile.VALUE ('XXD_ONT_BULK_DEBUG_ENABLE'), 'N');

    gc_om_debug_enable     VARCHAR2 (1)
        := NVL (fnd_profile.VALUE ('XXD_ONT_BULK_OM_DEBUG_ENABLE'), 'N');

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
        lc_debug_mode   VARCHAR2 (1000);
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, gc_delimiter || p_msg);
        END IF;

        -- Enable OM Debug
        IF gc_om_debug_enable = 'Y'
        THEN
            oe_debug_pub.debug_on;
            oe_debug_pub.setdebuglevel (5);
            lc_debug_mode   := oe_debug_pub.set_debug_mode ('CONC');
        END IF;
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in DEBUG_MSG = ' || SQLERRM);
    END debug_msg;

    -- ======================================================================================
    -- This procedure will be used to initialize
    -- ======================================================================================
    PROCEDURE init
    AS
    BEGIN
        debug_msg ('Initializing');
        mo_global.init ('ONT');
        oe_msg_pub.initialize;
        mo_global.set_policy_context ('S', gn_org_id);
        fnd_global.apps_initialize (user_id        => gn_user_id,
                                    resp_id        => gn_responsibility_id,
                                    resp_appl_id   => gn_application_id);

        debug_msg ('Org ID = ' || gn_org_id);
        debug_msg ('User ID = ' || gn_user_id);
        debug_msg ('Responsibility ID = ' || gn_responsibility_id);
        debug_msg ('Application ID = ' || gn_application_id);
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in INIT = ' || SQLERRM);
    END init;

    -- ======================================================================================
    -- This function return Y or N if an order line is locked by another session/user
    -- ======================================================================================
    FUNCTION lock_order_line (p_line_id IN oe_order_lines_all.line_id%TYPE)
        RETURN VARCHAR2
    AS
        CURSOR get_order IS
                SELECT oola.line_id
                  FROM oe_order_lines_all oola
                 WHERE oola.line_id = p_line_id
            FOR UPDATE NOWAIT;

        lc_sub_prog_name   VARCHAR2 (100) := 'CHECK_ORDER_LOCK';
        ln_line_id         oe_order_lines_all.line_id%TYPE;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        OPEN get_order;

        FETCH get_order INTO ln_line_id;

        CLOSE get_order;

        debug_msg ('Order Line is not Locked');
        debug_msg ('End ' || lc_sub_prog_name);
        RETURN 'N';
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in DEBUG_MSG = ' || SQLERRM);

            IF get_order%ISOPEN
            THEN
                CLOSE get_order;
            END IF;

            debug_msg ('End ' || lc_sub_prog_name);

            RETURN 'Y';
    END lock_order_line;

    -- ======================================================================================
    -- This procedure inserts data into the custom table
    -- ======================================================================================
    PROCEDURE insert_data (
        p_calloff_header_rec   IN oe_order_pub.header_rec_type,
        p_calloff_line_rec     IN oe_order_pub.line_rec_type,
        p_bulk_header_id          oe_order_headers_all.header_id%TYPE,
        p_bulk_line_id            oe_order_lines_all.line_id%TYPE,
        p_link_type               VARCHAR2, --BULK_LINK, BULK_DELINK, BULK_ATP
        p_linked_qty              NUMBER,
        p_free_atp_qty            NUMBER,
        p_status                  VARCHAR2,
        p_error_msg               VARCHAR2)
    AS
        lc_sub_prog_name    VARCHAR2 (100) := 'INSERT_DATA';
        l_bulk_header_rec   oe_order_pub.header_rec_type;
        l_bulk_line_rec     oe_order_pub.line_rec_type;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        IF p_bulk_header_id IS NOT NULL
        THEN
            oe_header_util.query_row (p_header_id    => p_bulk_header_id,
                                      x_header_rec   => l_bulk_header_rec);
        END IF;

        IF p_bulk_line_id IS NOT NULL
        THEN
            oe_line_util.query_row (p_line_id    => p_bulk_line_id,
                                    x_line_rec   => l_bulk_line_rec);
        END IF;

        INSERT INTO xxd_ont_bulk_orders_t (bulk_id, link_type, status,
                                           error_message, org_id, calloff_header_id, calloff_order_number, calloff_sold_to_org_id, calloff_cust_po_number, calloff_request_date, calloff_order_brand, bulk_header_id, bulk_order_number, bulk_sold_to_org_id, bulk_cust_po_number, bulk_request_date, bulk_order_brand, calloff_line_id, calloff_line_number, calloff_shipment_number, calloff_ordered_item, calloff_inventory_item_id, calloff_ordered_quantity, new_calloff_ordered_quantity, calloff_line_request_date, calloff_schedule_ship_date, calloff_latest_acceptable_date, calloff_line_demand_class_code, bulk_line_id, bulk_line_number, bulk_shipment_number, bulk_ordered_item, bulk_inventory_item_id, bulk_ordered_quantity, bulk_line_request_date, bulk_schedule_ship_date, bulk_latest_acceptable_date, bulk_line_demand_class_code, linked_qty, atp_qty, request_id, creation_date, created_by, last_update_date, last_updated_by, last_update_login, number_attribute1, number_attribute2, number_attribute3, number_attribute4, number_attribute5, varchar_attribute1, varchar_attribute2, varchar_attribute3, varchar_attribute4, varchar_attribute5, date_attribute1, date_attribute2, date_attribute3, date_attribute4
                                           , date_attribute5)
             VALUES (xxdo.xxd_ont_bulk_orders_s.NEXTVAL, p_link_type, p_status, p_error_msg, p_calloff_header_rec.org_id, p_calloff_header_rec.header_id, p_calloff_header_rec.order_number, p_calloff_header_rec.sold_to_org_id, p_calloff_header_rec.cust_po_number, p_calloff_header_rec.request_date, p_calloff_header_rec.attribute5, l_bulk_header_rec.header_id, l_bulk_header_rec.order_number, l_bulk_header_rec.sold_to_org_id, l_bulk_header_rec.cust_po_number, l_bulk_header_rec.request_date, l_bulk_header_rec.attribute5, p_calloff_line_rec.line_id, p_calloff_line_rec.line_number, p_calloff_line_rec.shipment_number, p_calloff_line_rec.ordered_item, p_calloff_line_rec.inventory_item_id, p_calloff_line_rec.ordered_quantity, p_calloff_line_rec.ordered_quantity, p_calloff_line_rec.request_date, p_calloff_line_rec.schedule_ship_date, p_calloff_line_rec.latest_acceptable_date, p_calloff_line_rec.demand_class_code, l_bulk_line_rec.line_id, l_bulk_line_rec.line_number, l_bulk_line_rec.shipment_number, l_bulk_line_rec.ordered_item, l_bulk_line_rec.inventory_item_id, l_bulk_line_rec.ordered_quantity, l_bulk_line_rec.request_date, l_bulk_line_rec.schedule_ship_date, l_bulk_line_rec.latest_acceptable_date, l_bulk_line_rec.demand_class_code, p_linked_qty, p_free_atp_qty, gn_request_id, SYSDATE, gn_user_id, SYSDATE, gn_user_id, gn_login_id, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL
                     , NULL);

        debug_msg ('Records Inserted = ' || SQL%ROWCOUNT);
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in INSERT_DATA = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
    END insert_data;

    -- ======================================================================================
    -- This procedure calls MRP_ATP_PUB to evaluate available SKU quantity
    -- ======================================================================================
    PROCEDURE get_atp_qty (p_atp_rec IN mrp_atp_pub.atp_rec_typ, x_atp_rec OUT NOCOPY mrp_atp_pub.atp_rec_typ, x_return_status OUT NOCOPY VARCHAR2
                           , x_error_message OUT NOCOPY VARCHAR2)
    AS
        lc_sub_prog_name      VARCHAR2 (100) := 'GET_ATP_QTY';
        lx_atp_rec            mrp_atp_pub.atp_rec_typ;
        l_atp_supply_demand   mrp_atp_pub.atp_supply_demand_typ;
        l_atp_period          mrp_atp_pub.atp_period_typ;
        l_atp_details         mrp_atp_pub.atp_details_typ;
        lc_msg_data           VARCHAR2 (2000);
        ln_msg_index_out      NUMBER;
        ln_session_id         NUMBER;
        ln_msg_count          NUMBER;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        SELECT oe_order_sch_util.get_session_id INTO ln_session_id FROM DUAL;

        mrp_atp_pub.call_atp (p_session_id          => ln_session_id,
                              p_atp_rec             => p_atp_rec,
                              x_atp_rec             => lx_atp_rec,
                              x_atp_supply_demand   => l_atp_supply_demand,
                              x_atp_period          => l_atp_period,
                              x_atp_details         => l_atp_details,
                              x_return_status       => x_return_status,
                              x_msg_data            => lc_msg_data,
                              x_msg_count           => ln_msg_count);

        IF x_return_status <> 'S'
        THEN
            FOR i IN 1 .. ln_msg_count
            LOOP
                fnd_msg_pub.get (i, fnd_api.g_false, lc_msg_data,
                                 ln_msg_index_out);
                x_error_message   := x_error_message || ' ' || lc_msg_data;
            END LOOP;
        END IF;

        x_atp_rec   := lx_atp_rec;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in GET_ATP_QTY = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            x_return_status   := 'E';
            x_error_message   := SUBSTR (SQLERRM, 1, 2000);
    END get_atp_qty;

    -- ======================================================================================
    -- This procedure calls OE_ORDER_PUB to make changes in the order
    -- ======================================================================================
    PROCEDURE process_order (p_header_rec IN oe_order_pub.header_rec_type, p_line_tbl IN oe_order_pub.line_tbl_type, p_action_request_tbl IN oe_order_pub.request_tbl_type
                             , x_line_tbl OUT NOCOPY oe_order_pub.line_tbl_type, x_return_status OUT NOCOPY VARCHAR2, x_error_message OUT NOCOPY VARCHAR2)
    AS
        lc_sub_prog_name           VARCHAR2 (100) := 'PROCESS_ORDER';
        lc_return_status           VARCHAR2 (2000);
        lc_error_message           VARCHAR2 (4000);
        lc_msg_data                VARCHAR2 (4000);
        ln_msg_count               NUMBER;
        ln_msg_index_out           NUMBER;
        x_header_rec               oe_order_pub.header_rec_type;
        x_header_val_rec           oe_order_pub.header_val_rec_type;
        x_header_adj_tbl           oe_order_pub.header_adj_tbl_type;
        x_header_adj_val_tbl       oe_order_pub.header_adj_val_tbl_type;
        x_header_price_att_tbl     oe_order_pub.header_price_att_tbl_type;
        x_header_adj_att_tbl       oe_order_pub.header_adj_att_tbl_type;
        x_header_adj_assoc_tbl     oe_order_pub.header_adj_assoc_tbl_type;
        x_header_scredit_tbl       oe_order_pub.header_scredit_tbl_type;
        x_header_scredit_val_tbl   oe_order_pub.header_scredit_val_tbl_type;
        x_line_val_tbl             oe_order_pub.line_val_tbl_type;
        x_line_adj_tbl             oe_order_pub.line_adj_tbl_type;
        x_line_adj_val_tbl         oe_order_pub.line_adj_val_tbl_type;
        x_line_price_att_tbl       oe_order_pub.line_price_att_tbl_type;
        x_line_adj_att_tbl         oe_order_pub.line_adj_att_tbl_type;
        x_line_adj_assoc_tbl       oe_order_pub.line_adj_assoc_tbl_type;
        x_line_scredit_tbl         oe_order_pub.line_scredit_tbl_type;
        x_line_scredit_val_tbl     oe_order_pub.line_scredit_val_tbl_type;
        x_lot_serial_tbl           oe_order_pub.lot_serial_tbl_type;
        x_lot_serial_val_tbl       oe_order_pub.lot_serial_val_tbl_type;
        x_action_request_tbl       oe_order_pub.request_tbl_type;
        ln_var                     NUMBER := 0;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_false,
            p_return_values            => fnd_api.g_false,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => lc_return_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lc_msg_data,
            p_header_rec               => p_header_rec,
            p_line_tbl                 => p_line_tbl,
            p_action_request_tbl       => p_action_request_tbl,
            x_header_rec               => x_header_rec,
            x_header_val_rec           => x_header_val_rec,
            x_header_adj_tbl           => x_header_adj_tbl,
            x_header_adj_val_tbl       => x_header_adj_val_tbl,
            x_header_price_att_tbl     => x_header_price_att_tbl,
            x_header_adj_att_tbl       => x_header_adj_att_tbl,
            x_header_adj_assoc_tbl     => x_header_adj_assoc_tbl,
            x_header_scredit_tbl       => x_header_scredit_tbl,
            x_header_scredit_val_tbl   => x_header_scredit_val_tbl,
            x_line_tbl                 => x_line_tbl,
            x_line_val_tbl             => x_line_val_tbl,
            x_line_adj_tbl             => x_line_adj_tbl,
            x_line_adj_val_tbl         => x_line_adj_val_tbl,
            x_line_price_att_tbl       => x_line_price_att_tbl,
            x_line_adj_att_tbl         => x_line_adj_att_tbl,
            x_line_adj_assoc_tbl       => x_line_adj_assoc_tbl,
            x_line_scredit_tbl         => x_line_scredit_tbl,
            x_line_scredit_val_tbl     => x_line_scredit_val_tbl,
            x_lot_serial_tbl           => x_lot_serial_tbl,
            x_lot_serial_val_tbl       => x_lot_serial_val_tbl,
            x_action_request_tbl       => x_action_request_tbl);
        debug_msg ('x_return_status = ' || lc_return_status);

        IF lc_return_status <> fnd_api.g_ret_sts_success
        THEN
            FOR i IN 1 .. oe_msg_pub.count_msg
            LOOP
                oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                , p_msg_index_out => ln_msg_index_out);
                lc_error_message   := lc_error_message || lc_msg_data;
            END LOOP;

            x_error_message   :=
                NVL (lc_error_message, 'OE_ORDER_PUB Failed');
            debug_msg ('PROCESS_ORDER API Error = ' || x_error_message);
        END IF;

        x_return_status   := lc_return_status;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in PROCESS_ORDER = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            x_return_status   := 'E';
            x_error_message   := SQLERRM;
    END process_order;

    -- ======================================================================================
    -- This procedure will be called from Concurrent Program to link Calloff-Bulk Orders
    -- Possible Order Status: NEW, PROCESSED, REPROCESS, DELINKED, NULL
    -- ======================================================================================
    PROCEDURE process_calloff_order (p_header_id IN oe_order_holds_all.header_id%TYPE, p_line_id IN oe_order_holds_all.line_id%TYPE, x_return_status OUT NOCOPY VARCHAR2
                                     , x_result_code OUT NOCOPY VARCHAR2)
    AS
        CURSOR get_calloff_hold_c (p_header_id oe_order_holds_all.header_id%TYPE, p_line_id oe_order_holds_all.line_id%TYPE, p_order_type_id oe_order_headers_all.order_type_id%TYPE)
        IS
            SELECT ohsa.hold_id
              FROM oe_order_holds_all holds, oe_hold_sources_all ohsa, oe_hold_definitions ohd,
                   oe_lookups ol
             WHERE     holds.hold_source_id = ohsa.hold_source_id
                   AND ohsa.hold_id = ohd.hold_id
                   AND holds.header_id = p_header_id
                   AND holds.line_id = p_line_id
                   AND holds.released_flag = 'N'
                   AND ohsa.released_flag = 'N'
                   AND ohsa.hold_id = TO_NUMBER (ol.lookup_code)
                   AND ol.lookup_type = 'XXD_ONT_CALLOFF_ORDER_HOLDS'
                   AND ol.enabled_flag = 'Y'
                   AND ((ol.start_date_active IS NOT NULL AND ol.start_date_active <= SYSDATE) OR (ol.start_date_active IS NULL AND 1 = 1))
                   AND ((ol.end_date_active IS NOT NULL AND ol.end_date_active >= SYSDATE) OR (ol.end_date_active IS NULL AND 1 = 1));

        CURSOR get_bulk_orders_c (
            p_cust_po_number           oe_order_headers_all.cust_po_number%TYPE,
            p_sold_to_org_id           oe_order_headers_all.sold_to_org_id%TYPE,
            p_latest_acceptable_date   oe_order_lines_all.latest_acceptable_date%TYPE,
            p_inventory_item_id        oe_order_lines_all.inventory_item_id%TYPE)
        IS
              SELECT ooha.order_number, oola.header_id, oola.line_id,
                     ooha.org_id, oola.ordered_quantity, oola.demand_class_code,
                     UPPER (ooha.cust_po_number) bulk_cust_po_number
                FROM oe_order_headers_all ooha, oe_order_lines_all oola, fnd_lookup_values flv
               WHERE     ooha.header_id = oola.header_id
                     AND ooha.open_flag = 'Y'
                     AND oola.open_flag = 'Y'
                     AND ooha.org_id = gn_org_id
                     AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                     AND ooha.org_id = TO_NUMBER (flv.tag)
                     AND flv.language = USERENV ('LANG')
                     AND flv.enabled_flag = 'Y'
                     AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                     AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                     AND flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                     AND ooha.sold_to_org_id = p_sold_to_org_id
                     AND oola.inventory_item_id = p_inventory_item_id
                     AND TRUNC (oola.schedule_ship_date) <=
                         TRUNC (p_latest_acceptable_date)
                     AND oola.schedule_ship_date IS NOT NULL
                     AND oola.ordered_quantity > 0
                     AND EXISTS
                             (SELECT 1
                                FROM msc_alloc_demands@bt_ebs_to_ascp mad
                               WHERE     mad.sales_order_line_id = oola.line_id
                                     AND mad.allocated_quantity > 0)
            ORDER BY CASE
                         WHEN bulk_cust_po_number = p_cust_po_number THEN 1
                     END ASC,
                     oola.schedule_ship_date DESC, -- Ordering by the matching PO first
                     CASE
                         WHEN bulk_cust_po_number <> p_cust_po_number THEN 2
                     END ASC,
                     oola.schedule_ship_date DESC; -- Ordering by the oldest SSD then

        CURSOR get_bulk_lines_c (
            p_calloff_line_id IN oe_order_holds_all.line_id%TYPE)
        IS
            SELECT SUM (linked_qty) total_bulk_qty, MIN (bulk_line_demand_class_code) bulk_demand_class_code
              FROM xxd_ont_bulk_orders_t
             WHERE     calloff_line_id = p_calloff_line_id
                   AND link_type = 'BULK_LINK';

        CURSOR get_bulks_c (
            p_calloff_line_id IN oe_order_holds_all.line_id%TYPE)
        IS
            SELECT bulk_header_id,
                   org_id,
                   bulk_line_id,
                   bulk_ordered_quantity,
                   CASE
                       WHEN bulk_ordered_quantity - linked_qty > 0
                       THEN
                           bulk_ordered_quantity - linked_qty
                       ELSE
                           0
                   END bulk_cancel_quantity
              FROM xxd_ont_bulk_orders_t
             WHERE     calloff_line_id = p_calloff_line_id
                   AND link_type = 'BULK_LINK';

        lc_sub_prog_name               VARCHAR2 (100) := 'PROCESS_CALLOFF_ORDER';
        lc_return_status               VARCHAR2 (1);
        lc_api_return_status           VARCHAR2 (1);
        lc_atp_return_status           VARCHAR2 (1);
        lc_status                      VARCHAR2 (1);
        lc_message                     VARCHAR2 (4000);
        lc_error_message               VARCHAR2 (4000);
        lc_lock_status                 VARCHAR2 (1);
        lc_msg_data                    VARCHAR2 (1000);
        lc_result_code                 VARCHAR2 (40);
        lc_line_status                 VARCHAR2 (200);
        ln_msg_count                   NUMBER;
        ln_msg_index_out               NUMBER;
        ln_record_count                NUMBER DEFAULT 0;
        ln_msc_count                   NUMBER DEFAULT 0;
        ln_linked_qty                  NUMBER DEFAULT 0;
        ln_bulk_qty                    NUMBER DEFAULT 0;
        lc_remaining_calloff_qty       NUMBER DEFAULT 0;
        ln_requested_atp_qty           NUMBER DEFAULT 0;
        ln_atp_current_available_qty   NUMBER DEFAULT 0;
        ln_original_line_split_qty     NUMBER DEFAULT 0;
        ln_new_line_split_qty          NUMBER DEFAULT 0;
        ln_allocated_quantity          NUMBER DEFAULT 0;
        ln_total_bulk_qty              NUMBER DEFAULT 0;
        ln_reset_count                 NUMBER DEFAULT 0;
        lc_bulk_demand_class_code      oe_order_lines_all.demand_class_code%TYPE;
        ln_hold_id                     oe_hold_sources_all.hold_id%TYPE;
        ln_reapply_hold_id             oe_hold_sources_all.hold_id%TYPE;
        l_calloff_line_rec             oe_order_pub.line_rec_type;
        l_calloff_header_rec           oe_order_pub.header_rec_type;
        l_header_rec                   oe_order_pub.header_rec_type;
        l_line_tbl                     oe_order_pub.line_tbl_type;
        lx_line_tbl                    oe_order_pub.line_tbl_type;
        l_action_request_tbl           oe_order_pub.request_tbl_type;
        l_request_rec                  oe_order_pub.request_rec_type;
        x_action_request_tbl           oe_order_pub.request_tbl_type;
        l_atp_rec                      mrp_atp_pub.atp_rec_typ;
        lx_atp_rec                     mrp_atp_pub.atp_rec_typ;
        l_order_tbl_type               oe_holds_pvt.order_tbl_type;
        l_hold_source_rec              oe_holds_pvt.hold_source_rec_type;
    BEGIN
        gc_delimiter           := CHR (9);
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg ('Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        l_calloff_header_rec   := oe_order_pub.g_miss_header_rec;
        l_calloff_line_rec     := oe_order_pub.g_miss_line_rec;
        oe_header_util.query_row (p_header_id    => p_header_id,
                                  x_header_rec   => l_calloff_header_rec);
        oe_line_util.query_row (p_line_id    => p_line_id,
                                x_line_rec   => l_calloff_line_rec);
        gc_delimiter           := CHR (9) || CHR (9);
        -- Lock Bulk Calloff Order
        lc_lock_status         :=
            lock_order_line (l_calloff_line_rec.line_id);
        lc_status              := 'S';
        gc_delimiter           := CHR (9);

        IF lc_lock_status = 'N'
        THEN
            /****************************************************************************************
            * Release Hold on Calloff Section
            ****************************************************************************************/
            debug_msg ('Locking Calloff Order Line');
            debug_msg ('Releasing Hold');

            -- Verify if Hold exists on Calloff
            OPEN get_calloff_hold_c (l_calloff_header_rec.header_id,
                                     l_calloff_line_rec.line_id,
                                     l_calloff_header_rec.order_type_id);

            FETCH get_calloff_hold_c INTO ln_hold_id;

            CLOSE get_calloff_hold_c;

            debug_msg ('Calloff Order Hold ID ' || ln_hold_id);

            IF ln_hold_id IS NOT NULL
            THEN
                lc_remaining_calloff_qty   := 0;
                l_order_tbl_type (1).header_id   :=
                    l_calloff_header_rec.header_id;
                l_order_tbl_type (1).line_id   :=
                    l_calloff_line_rec.line_id;

                -- Call Process Order to release hold
                oe_holds_pub.release_holds (p_api_version => 1.0, p_init_msg_list => fnd_api.g_true, p_commit => fnd_api.g_false, p_order_tbl => l_order_tbl_type, p_hold_id => ln_hold_id, p_release_reason_code => 'PGM_BULK_RELEASE', p_release_comment => 'Program Released hold on Bulk Call off Order', x_return_status => lc_return_status, x_msg_count => ln_msg_count
                                            , x_msg_data => lc_msg_data);

                debug_msg ('Hold Release Status = ' || lc_return_status);

                IF lc_return_status <> 'S'
                THEN
                    FOR i IN 1 .. oe_msg_pub.count_msg
                    LOOP
                        oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                        , p_msg_index_out => ln_msg_index_out);
                        lc_error_message   := lc_error_message || lc_msg_data;
                    END LOOP;

                    debug_msg (
                           'Unable to release hold with error = '
                        || lc_error_message);
                    lc_status   := 'E';
                    lc_message   :=
                        SUBSTR (
                            ('Release hold failed = ' || lc_error_message),
                            1,
                            240);
                ELSE
                    lc_status   := 'S';
                END IF;
            ELSE
                lc_status   := 'E';
                lc_message   :=
                    'No Hold exists. Not an eligible Calloff Order Line';
                debug_msg (lc_message);
            END IF;

            /****************************************************************************************
            * Pickup all eligible Bulk Lines
            ****************************************************************************************/
            IF lc_status = 'S'
            THEN
                gc_delimiter       := CHR (9) || CHR (9);
                lc_error_message   := NULL;
                debug_msg (
                    'Cust_PO_Number = ' || l_calloff_header_rec.cust_po_number);
                debug_msg (
                    'Sold_To_Org_ID = ' || l_calloff_header_rec.sold_to_org_id);
                debug_msg (
                    'Latest_Acceptable_Date = ' || l_calloff_line_rec.latest_acceptable_date);
                debug_msg (
                    'Inventory_Item_ID = ' || l_calloff_line_rec.inventory_item_id);
                debug_msg (
                    'Calloff Qty = ' || l_calloff_line_rec.ordered_quantity);
                l_header_rec       := oe_order_pub.g_miss_header_rec;
                l_line_tbl         := oe_order_pub.g_miss_line_tbl;
                gc_delimiter       := '';
                debug_msg (RPAD ('-', 100, '-'));
                debug_msg ('Bulk Orders');

                -- Get all eligible Bulk Order Lines with Cust PO, Cust, LAD and Item
                FOR bulk_orders_rec
                    IN get_bulk_orders_c (
                           UPPER (
                               NVL (l_calloff_header_rec.cust_po_number,
                                    '-99')),
                           l_calloff_header_rec.sold_to_org_id,
                           l_calloff_line_rec.latest_acceptable_date,
                           l_calloff_line_rec.inventory_item_id)
                LOOP
                    gc_delimiter               := CHR (9) || CHR (9);

                    -- Find All Lines Till Qty is Fulfilled
                    IF l_calloff_line_rec.ordered_quantity > ln_bulk_qty
                    THEN
                        debug_msg (
                               'Calloff Qty '
                            || l_calloff_line_rec.ordered_quantity
                            || ' > Bulk Qty Variable '
                            || ln_bulk_qty);
                        debug_msg (
                               'Processing Bulk Order Number '
                            || bulk_orders_rec.order_number
                            || '. Header ID '
                            || bulk_orders_rec.header_id
                            || '. Order Line ID '
                            || bulk_orders_rec.line_id);

                        -- Lock Bulk Order
                        lc_lock_status   :=
                            lock_order_line (bulk_orders_rec.line_id);

                        IF lc_lock_status = 'N'
                        THEN
                            debug_msg ('Locking Bulk Order Line');
                            gc_delimiter      := CHR (9) || CHR (9) || CHR (9);
                            ln_bulk_qty       :=
                                  ln_bulk_qty
                                + bulk_orders_rec.ordered_quantity;
                            debug_msg (
                                'Available Bulk Qty = ' || ln_bulk_qty);

                            IF l_calloff_line_rec.ordered_quantity >=
                               ln_bulk_qty
                            THEN
                                debug_msg (
                                    'Calloff Qty is >= Available Bulk Qty. Cancelling all qty in Bulk');
                                ln_allocated_quantity   := 0;
                                ln_linked_qty           :=
                                    bulk_orders_rec.ordered_quantity;
                            ELSE
                                debug_msg (
                                    'Calloff Qty is < Available Bulk Qty. Cancelling remaining qty in Bulk');
                                ln_linked_qty   :=
                                    CASE
                                        WHEN lc_remaining_calloff_qty = 0
                                        THEN
                                            l_calloff_line_rec.ordered_quantity
                                        ELSE
                                            CASE
                                                WHEN   l_calloff_line_rec.ordered_quantity
                                                     - lc_remaining_calloff_qty >
                                                     0
                                                THEN
                                                      l_calloff_line_rec.ordered_quantity
                                                    - lc_remaining_calloff_qty
                                                ELSE
                                                    0
                                            END
                                    END;

                                ln_allocated_quantity   :=
                                    CASE
                                        WHEN   bulk_orders_rec.ordered_quantity
                                             - ln_linked_qty >
                                             0
                                        THEN
                                              bulk_orders_rec.ordered_quantity
                                            - ln_linked_qty
                                        ELSE
                                            0
                                    END;
                            END IF;

                            debug_msg (
                                   'Allocated Quantity = '
                                || ln_allocated_quantity);

                            ln_record_count   := ln_record_count + 1;
                            gc_delimiter      :=
                                CHR (9) || CHR (9) || CHR (9) || CHR (9);

                            -- Call Linking Process
                            insert_data (
                                p_calloff_header_rec   => l_calloff_header_rec,
                                p_calloff_line_rec     => l_calloff_line_rec,
                                p_bulk_header_id       =>
                                    bulk_orders_rec.header_id,
                                p_bulk_line_id         =>
                                    bulk_orders_rec.line_id,
                                p_link_type            => 'BULK_LINK',
                                p_linked_qty           => ln_linked_qty,
                                p_free_atp_qty         => 0,
                                p_status               => 'S',
                                p_error_msg            => NULL);
                            gc_delimiter      :=
                                CHR (9) || CHR (9) || CHR (9);
                        ELSE
                            lc_status   := 'E';
                            lc_message   :=
                                'One or more eligible Bulk Order for this Calloff line is locked by another user';
                            debug_msg (
                                   bulk_orders_rec.order_number
                                || '. Header ID '
                                || bulk_orders_rec.header_id
                                || '. Order Line ID '
                                || bulk_orders_rec.line_id
                                || ' is locked by another user');
                            EXIT;
                        END IF;
                    ELSE
                        -- If Quantity Fulfilled Then Exit Loop
                        debug_msg (
                               'Calloff Qty '
                            || l_calloff_line_rec.ordered_quantity
                            || ' <= ln_bulk_qty '
                            || ln_bulk_qty);
                        debug_msg (
                            'Quantity Fulfilled from all availble Bulk Orders');
                        EXIT;
                    END IF;

                    lc_remaining_calloff_qty   :=
                          lc_remaining_calloff_qty
                        + bulk_orders_rec.ordered_quantity;

                    -- Update ASCP table for Bulk Record
                    UPDATE msc_alloc_demands@bt_ebs_to_ascp
                       SET allocated_quantity   = ln_allocated_quantity
                     WHERE     sales_order_line_id = bulk_orders_rec.line_id
                           AND allocated_quantity > 0;

                    ln_msc_count               := SQL%ROWCOUNT;
                    debug_msg (
                           'Allocated Qty updated in MSC_ALLOC_DEMANDS count = '
                        || ln_msc_count);

                    IF ln_msc_count = 0
                    THEN
                        lc_status    := 'E';
                        lc_message   := 'MSC Record Not Found';
                        EXIT;
                    ELSE
                        lc_status   := 'S';
                    END IF;
                END LOOP;
            END IF;

            /****************************************************************************************
            * Commit MSC changes and Relock Bulk Order Lines Again
            ****************************************************************************************/
            IF lc_status = 'S' AND ln_record_count > 0
            THEN
                COMMIT;

                -- Try locking all Bulk(s) again
                FOR bulks_rec IN get_bulks_c (l_calloff_line_rec.line_id)
                LOOP
                    lc_lock_status   :=
                        lock_order_line (l_calloff_line_rec.line_id);

                    IF lc_lock_status = 'N'
                    THEN
                        lc_status   := 'S';
                    ELSE
                        lc_status   := 'E';
                        lc_message   :=
                            'One or more eligible Bulk Order for this Calloff line is locked by another user';
                    END IF;
                END LOOP;
            END IF;

            /****************************************************************************************
            * Unscheduling Calloff Section
            ****************************************************************************************/
            IF     lc_status = 'S'
               AND ln_record_count > 0
               AND l_calloff_line_rec.schedule_ship_date IS NOT NULL
            THEN
                debug_msg ('Unscheduling Calloff Order Line');
                l_header_rec               := oe_order_pub.g_miss_header_rec;
                l_line_tbl                 := oe_order_pub.g_miss_line_tbl;
                -- Unschedule Calloff Order Line
                l_line_tbl (1)             := oe_order_pub.g_miss_line_rec;
                l_line_tbl (1).header_id   := l_calloff_header_rec.header_id;
                l_line_tbl (1).org_id      := l_calloff_header_rec.org_id;
                l_line_tbl (1).line_id     := l_calloff_line_rec.line_id;
                l_line_tbl (1).schedule_action_code   :=
                    oe_order_sch_util.oesch_act_unschedule;
                l_line_tbl (1).operation   :=
                    oe_globals.g_opr_update;
                process_order (p_header_rec           => l_header_rec,
                               p_line_tbl             => l_line_tbl,
                               p_action_request_tbl   => l_action_request_tbl,
                               x_line_tbl             => lx_line_tbl,
                               x_return_status        => lc_api_return_status,
                               x_error_message        => lc_error_message);

                debug_msg ('Unscheduling Status = ' || lc_api_return_status);

                IF lc_api_return_status <> 'S'
                THEN
                    lc_status   := 'E';
                    debug_msg ('Unable to unschedule Calloff Order Line');
                    debug_msg ('Error = ' || lc_error_message);
                    lc_message   :=
                        SUBSTR (
                            ('Unschedule Calloff Failed = ' || lc_error_message),
                            1,
                            240);
                ELSE
                    lc_status   := 'S';
                END IF;
            END IF;

            gc_delimiter   := '';
            debug_msg (RPAD ('-', 100, '-'));
            gc_delimiter   := CHR (9) || CHR (9);
            debug_msg ('Number of Bulk Lines = ' || ln_record_count);

            /****************************************************************************************
            * ATP check and Order Split section
            ****************************************************************************************/
            IF lc_status = 'S' AND ln_record_count > 0
            THEN
                OPEN get_bulk_lines_c (l_calloff_line_rec.line_id);

                FETCH get_bulk_lines_c INTO ln_total_bulk_qty, lc_bulk_demand_class_code;

                CLOSE get_bulk_lines_c;

                -- If still Qty not Fulfilled, use Free/Bulk ATP
                IF l_calloff_line_rec.ordered_quantity > ln_total_bulk_qty
                THEN
                    -- Requested ATP qty has to be the total ordered qty to correct Free ATP + Bulk
                    ln_requested_atp_qty                     :=
                        l_calloff_line_rec.ordered_quantity;
                    debug_msg (
                           'Not enough Bulk Lines available. Checking ATP for Qty '
                        || ln_requested_atp_qty
                        || ' with Demand Class Code as '
                        || lc_bulk_demand_class_code);

                    -- ATP Rec
                    msc_atp_global.extend_atp (l_atp_rec, x_return_status, 1);
                    l_atp_rec.inventory_item_id (1)          :=
                        l_calloff_line_rec.inventory_item_id;
                    l_atp_rec.quantity_ordered (1)           := ln_requested_atp_qty;
                    l_atp_rec.quantity_uom (1)               :=
                        l_calloff_line_rec.order_quantity_uom;
                    -- Pass LAD to Request Date to cover future supplies
                    l_atp_rec.requested_ship_date (1)        :=
                        l_calloff_line_rec.latest_acceptable_date;
                    l_atp_rec.latest_acceptable_date (1)     :=
                        l_calloff_line_rec.latest_acceptable_date;
                    l_atp_rec.source_organization_id (1)     :=
                        l_calloff_line_rec.ship_from_org_id;
                    l_atp_rec.demand_class (1)               :=
                        lc_bulk_demand_class_code;
                    -- Set additional input values
                    l_atp_rec.action (1)                     := 100;
                    l_atp_rec.instance_id (1)                := 61;
                    l_atp_rec.oe_flag (1)                    := 'N';
                    l_atp_rec.insert_flag (1)                := 1;
                    -- Hardcoded value for profile MRP:Calculate Supply Demand 0= NO
                    l_atp_rec.attribute_04 (1)               := 1;
                    -- With this Attribute set to 1 this will enable the Period (Horizontal Plan),
                    l_atp_rec.customer_id (1)                := NULL;
                    l_atp_rec.customer_site_id (1)           := NULL;
                    l_atp_rec.calling_module (1)             := NULL;
                    l_atp_rec.row_id (1)                     := NULL;
                    l_atp_rec.source_organization_code (1)   := NULL;
                    l_atp_rec.organization_id (1)            := NULL;
                    l_atp_rec.order_number (1)               := NULL;
                    l_atp_rec.line_number (1)                := NULL;
                    l_atp_rec.override_flag (1)              := 'N';
                    get_atp_qty (p_atp_rec => l_atp_rec, x_atp_rec => lx_atp_rec, x_return_status => lc_atp_return_status
                                 , x_error_message => lc_error_message);

                    debug_msg ('ATP API Status = ' || lc_atp_return_status);

                    IF lc_atp_return_status = 'S'
                    THEN
                        debug_msg (
                            'Requested Date Qty from API = ' || lx_atp_rec.requested_date_quantity (1));

                        debug_msg (
                            'Next Arrival Date from API = ' || lx_atp_rec.arrival_date (1));

                        ln_atp_current_available_qty   :=
                            NVL (lx_atp_rec.requested_date_quantity (1), 0);

                        gc_delimiter   := CHR (9) || CHR (9) || CHR (9);

                        IF l_calloff_line_rec.ordered_quantity <=
                           ln_atp_current_available_qty
                        THEN
                            debug_msg ('Enough Free ATP is available');

                            ln_requested_atp_qty   :=
                                  l_calloff_line_rec.ordered_quantity
                                - ln_total_bulk_qty;

                            -- Call Linking Process
                            insert_data (
                                p_calloff_header_rec   => l_calloff_header_rec,
                                p_calloff_line_rec     => l_calloff_line_rec,
                                p_bulk_header_id       => NULL,
                                p_bulk_line_id         => NULL,
                                p_link_type            => 'BULK_ATP',
                                p_linked_qty           => 0,
                                p_free_atp_qty         => ln_requested_atp_qty,
                                p_status               => 'S',
                                p_error_msg            => NULL);
                            lc_status   := 'S';
                        ELSIF l_calloff_line_rec.ordered_quantity >
                              ln_atp_current_available_qty
                        THEN
                            debug_msg (
                                'Free ATP is less than what needed. Performing Order Line Split');
                            -- Consume what Free ATP has and split into two Order Lines
                            -- Original Line Qty = free atp
                            ln_original_line_split_qty          :=
                                ln_atp_current_available_qty;
                            debug_msg (
                                   'Original Line Qty modified will be = '
                                || ln_original_line_split_qty);
                            -- Split line will have the remaining portion
                            ln_new_line_split_qty               :=
                                  l_calloff_line_rec.ordered_quantity
                                - ln_atp_current_available_qty;
                            debug_msg (
                                   'New Split Line Qty = '
                                || ln_new_line_split_qty);

                            IF ln_atp_current_available_qty > 0
                            THEN
                                gc_delimiter   :=
                                    CHR (9) || CHR (9) || CHR (9) || CHR (9);

                                IF ln_atp_current_available_qty >=
                                   ln_total_bulk_qty
                                THEN
                                    ln_atp_current_available_qty   :=
                                          ln_atp_current_available_qty
                                        - ln_total_bulk_qty;
                                END IF;

                                -- Call Linking Process for the Free ATP line
                                insert_data (
                                    p_calloff_header_rec   =>
                                        l_calloff_header_rec,
                                    p_calloff_line_rec   => l_calloff_line_rec,
                                    p_bulk_header_id     => NULL,
                                    p_bulk_line_id       => NULL,
                                    p_link_type          => 'BULK_ATP',
                                    p_linked_qty         => 0,
                                    p_free_atp_qty       =>
                                        ln_atp_current_available_qty,
                                    p_status             => 'S',
                                    p_error_msg          => NULL);
                            END IF;

                            gc_delimiter                        := CHR (9) || CHR (9) || CHR (9);

                            -- Update Calloff Ordered Qty in Custom table
                            UPDATE xxd_ont_bulk_orders_t
                               SET new_calloff_ordered_quantity = ln_original_line_split_qty
                             WHERE     calloff_line_id =
                                       l_calloff_line_rec.line_id
                                   AND link_type IN ('BULK_LINK', 'BULK_ATP');

                            debug_msg (
                                   'Updated New Calloff Ordered Qty Count = '
                                || SQL%ROWCOUNT);

                            gc_delimiter                        :=
                                CHR (9) || CHR (9) || CHR (9) || CHR (9);
                            l_header_rec                        := oe_order_pub.g_miss_header_rec;
                            l_line_tbl                          := oe_order_pub.g_miss_line_tbl;
                            -- Original Line Changes
                            l_line_tbl (1)                      := oe_order_pub.g_miss_line_rec;
                            l_line_tbl (1).header_id            :=
                                l_calloff_line_rec.header_id;
                            l_line_tbl (1).org_id               :=
                                l_calloff_line_rec.org_id;
                            l_line_tbl (1).line_id              :=
                                l_calloff_line_rec.line_id;
                            l_line_tbl (1).split_action_code    := 'SPLIT';
                            -- Pass User Id to "Split_By" instead of value "USER" to Original Line. Oracle Doc ID 2156475.1
                            l_line_tbl (1).split_by             := gn_user_id;
                            l_line_tbl (1).ordered_quantity     :=
                                ln_original_line_split_qty;
                            l_line_tbl (1).operation            :=
                                oe_globals.g_opr_update;

                            -- Split Line
                            l_line_tbl (2)                      :=
                                oe_order_pub.g_miss_line_rec;
                            l_line_tbl (2).header_id            :=
                                l_calloff_line_rec.header_id;
                            l_line_tbl (2).org_id               :=
                                l_calloff_line_rec.org_id;
                            l_line_tbl (2).split_action_code    := 'SPLIT';
                            -- Pass constant value "USER" to "Split_By" to Split Line. Oracle Doc ID 2156475.1
                            l_line_tbl (2).split_by             := 'USER';
                            l_line_tbl (2).split_from_line_id   :=
                                l_calloff_line_rec.line_id;
                            l_line_tbl (2).ordered_quantity     :=
                                ln_new_line_split_qty;
                            -- Resetting Attributes not working. So next scheduled program will reset to null
                            l_line_tbl (2).global_attribute19   := '';
                            l_line_tbl (2).global_attribute20   := '';
                            l_line_tbl (2).request_id           :=
                                gn_request_id;
                            l_line_tbl (2).operation            :=
                                oe_globals.g_opr_create;

                            -- Call Process Order to create/update lines
                            process_order (
                                p_header_rec           => l_header_rec,
                                p_line_tbl             => l_line_tbl,
                                p_action_request_tbl   => l_action_request_tbl,
                                x_line_tbl             => lx_line_tbl,
                                x_return_status        => lc_api_return_status,
                                x_error_message        => lc_error_message);

                            IF lc_api_return_status = 'S'
                            THEN
                                lc_status   := 'S';
                                debug_msg (
                                    'Updated Original Line Successfully');
                                debug_msg (
                                       'New Split Line ID '
                                    || lx_line_tbl (2).line_id);
                            ELSE
                                debug_msg ('Split Lines creation failed');
                                lc_status   := 'E';
                                lc_message   :=
                                    SUBSTR (
                                        ('Split Lines failed = ' || lc_error_message),
                                        1,
                                        240);
                            END IF;
                        END IF;
                    ELSE
                        debug_msg ('ATP API Err Msg = ' || lc_error_message);
                        lc_status   := 'E';
                        lc_message   :=
                            SUBSTR (
                                ('ATP API Err Msg = ' || lc_error_message),
                                1,
                                240);
                    END IF;
                ELSE
                    debug_msg ('Quantity Already Fulfilled.');
                    lc_status   := 'S';
                END IF;
            END IF;

            /****************************************************************************************
            * Marking Line Status and Result Section
           ****************************************************************************************/
            IF ln_record_count = 0
            THEN
                -- Commit needed for non calloff to schedule if qty available
                COMMIT;

                lc_line_status   :=
                    CASE
                        WHEN l_calloff_line_rec.global_attribute19 =
                             'REPROCESS'
                        THEN
                            'DELINKED'
                        ELSE
                            ''
                    END;
                lc_result_code   := 'NONBULK';
            ELSE
                IF lc_status = 'S'
                THEN
                    lc_line_status   := 'PROCESSED';
                    lc_result_code   := 'BULK';
                    lc_status        := 'S';
                ELSE
                    lc_line_status   := '';
                    lc_result_code   := 'NONBULK';
                    lc_status        := 'E';
                END IF;
            END IF;

            /****************************************************************************************
            * Update Demand Class and Scheduling Section
            ****************************************************************************************/
            IF lc_status = 'S' OR ln_hold_id IS NULL
            THEN
                gc_delimiter                          := CHR (9) || CHR (9) || CHR (9);
                lc_api_return_status                  := NULL;
                lc_error_message                      := NULL;
                l_header_rec                          := oe_order_pub.g_miss_header_rec;
                l_line_tbl                            := oe_order_pub.g_miss_line_tbl;
                l_line_tbl (1)                        := oe_order_pub.g_miss_line_rec;
                l_line_tbl (1).header_id              := l_calloff_header_rec.header_id;
                l_line_tbl (1).org_id                 := l_calloff_header_rec.org_id;
                l_line_tbl (1).line_id                := l_calloff_line_rec.line_id;

                IF lc_bulk_demand_class_code IS NOT NULL
                THEN
                    debug_msg ('Update Demand Class in Calloff Order Line');
                    l_line_tbl (1).demand_class_code   :=
                        lc_bulk_demand_class_code;
                END IF;

                l_line_tbl (1).global_attribute19     := lc_line_status;
                l_line_tbl (1).global_attribute20     := lc_message;
                l_line_tbl (1).request_id             := gn_request_id;
                l_line_tbl (1).schedule_action_code   :=
                    oe_order_sch_util.oesch_act_schedule;
                l_line_tbl (1).operation              :=
                    oe_globals.g_opr_update;

                process_order (p_header_rec           => l_header_rec,
                               p_line_tbl             => l_line_tbl,
                               p_action_request_tbl   => l_action_request_tbl,
                               x_line_tbl             => lx_line_tbl,
                               x_return_status        => lc_api_return_status,
                               x_error_message        => lc_error_message);

                gc_delimiter                          := CHR (9) || CHR (9);
                debug_msg ('Scheduling Status = ' || lc_api_return_status);

                IF lc_api_return_status = 'S'
                THEN
                    lc_status   := 'S';
                ELSE
                    IF ln_record_count > 0
                    THEN
                        lc_status   := 'E';
                        lc_message   :=
                            SUBSTR (
                                ('Scheduling Failed = ' || lc_error_message),
                                1,
                                240);
                    ELSE
                        lc_message   :=
                            'Scheduling Failed. But proceeding as regular line';
                        lc_status   := 'S';
                        debug_msg (lc_message);

                        -- If scheduling failed, try update
                        UPDATE oe_order_lines_all
                           SET global_attribute19 = NULL, global_attribute20 = NULL, request_id = gn_request_id,
                               last_update_date = SYSDATE, last_updated_by = gn_user_id
                         WHERE line_id = l_calloff_line_rec.line_id;
                    END IF;
                END IF;
            END IF;

            /****************************************************************************************
            * Cancel all eligible and linked Bulk Order lines
            ****************************************************************************************/
            IF lc_status = 'S'
            THEN
                IF ln_record_count > 0
                THEN
                    debug_msg ('Cancel All Eligible Bulk Lines');
                END IF;

                FOR bulks_rec IN get_bulks_c (l_calloff_line_rec.line_id)
                LOOP
                    debug_msg ('Bulk Line ID = ' || bulks_rec.bulk_line_id);
                    debug_msg (
                        'Bulk Qty = ' || bulks_rec.bulk_cancel_quantity);
                    lc_api_return_status              := NULL;
                    lc_error_message                  := NULL;
                    l_header_rec                      := oe_order_pub.g_miss_header_rec;
                    l_line_tbl                        := oe_order_pub.g_miss_line_tbl;
                    -- Line
                    l_line_tbl (1)                    := oe_order_pub.g_miss_line_rec;
                    l_line_tbl (1).header_id          := bulks_rec.bulk_header_id;
                    l_line_tbl (1).org_id             := bulks_rec.org_id;
                    l_line_tbl (1).line_id            := bulks_rec.bulk_line_id;
                    l_line_tbl (1).ordered_quantity   :=
                        bulks_rec.bulk_cancel_quantity;

                    IF bulks_rec.bulk_cancel_quantity = 0
                    THEN
                        l_line_tbl (1).cancelled_flag   := 'Y';
                    END IF;

                    l_line_tbl (1).change_reason      := 'BLK_ADJ_PGM';
                    l_line_tbl (1).change_comments    :=
                           'Bulk Order Qty Adjustment done on '
                        || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM')
                        || ' by program request_id:'
                        || gn_request_id;
                    l_line_tbl (1).request_id         := gn_request_id;
                    l_line_tbl (1).operation          :=
                        oe_globals.g_opr_update;
                    process_order (
                        p_header_rec           => l_header_rec,
                        p_line_tbl             => l_line_tbl,
                        p_action_request_tbl   => l_action_request_tbl,
                        x_line_tbl             => lx_line_tbl,
                        x_return_status        => lc_api_return_status,
                        x_error_message        => lc_error_message);

                    IF lc_api_return_status = 'S'
                    THEN
                        lc_status   := 'S';
                        debug_msg ('Not Committed After Cancel Bulk');
                    ELSE
                        -- Even if one bulk line fails, rollback all
                        lc_status   := 'E';
                        lc_message   :=
                            SUBSTR (
                                ('Bulk lines cancel failed = ' || lc_error_message),
                                1,
                                240);
                        EXIT;
                    END IF;
                END LOOP;
            END IF;

            /****************************************************************************************
            * If any error at any stage, rollback and update MSC table to original state
            ****************************************************************************************/
            IF lc_status = 'E'
            THEN
                ROLLBACK;

                -- Reset MSC
                FOR bulks_rec IN get_bulks_c (l_calloff_line_rec.line_id)
                LOOP
                    UPDATE msc_alloc_demands@bt_ebs_to_ascp
                       SET allocated_quantity = bulks_rec.bulk_ordered_quantity
                     WHERE     sales_order_line_id = bulks_rec.bulk_line_id
                           AND old_demand_date IS NULL;

                    ln_reset_count   := ln_reset_count + SQL%ROWCOUNT;
                END LOOP;

                debug_msg (
                       'MSC Table has been reset for Bulk Order Line(s) Count = '
                    || ln_reset_count);

                -- Rollback Custom Data
                DELETE xxd_ont_bulk_orders_t
                 WHERE     calloff_line_id = l_calloff_line_rec.line_id
                       AND link_type IN ('BULK_LINK', 'BULK_ATP');

                -- If current run releases the hold, put it back
                IF ln_hold_id IS NOT NULL
                THEN
                    l_hold_source_rec.hold_id            := ln_hold_id;
                    l_hold_source_rec.hold_entity_code   := 'O';
                    l_hold_source_rec.hold_entity_id     :=
                        l_calloff_line_rec.header_id;
                    l_hold_source_rec.line_id            :=
                        l_calloff_line_rec.line_id;
                    l_hold_source_rec.hold_comment       :=
                        'Applying processing hold on Bulk Call off Order';
                    oe_holds_pub.apply_holds (
                        p_api_version        => 1.0,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        p_hold_source_rec    => l_hold_source_rec,
                        x_msg_count          => ln_msg_count,
                        x_msg_data           => lc_msg_data,
                        x_return_status      => lc_return_status);

                    IF lc_return_status = 'S'
                    THEN
                        debug_msg ('Reapplied Hold Successfully');
                    ELSE
                        FOR i IN 1 .. oe_msg_pub.count_msg
                        LOOP
                            oe_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => lc_msg_data,
                                p_msg_index_out   => ln_msg_index_out);
                            lc_error_message   :=
                                lc_error_message || lc_msg_data;
                        END LOOP;

                        debug_msg (
                            'Reapply Hold Failed = ' || lc_error_message);
                    END IF;
                END IF;

                -- Commit needed to ensure we flip it to old state
                COMMIT;
            END IF;

            /****************************************************************************************
            * Final Status check section
            ****************************************************************************************/
            IF lc_status = 'S'
            THEN
                x_return_status   := 'S';
                x_result_code     := lc_result_code;
            ELSE
                x_return_status   := 'E';
            END IF;
        ELSE
            debug_msg ('Calloff Order Line is locked by another user');
            x_return_status   := 'E';
        END IF;

        gc_delimiter           := CHR (9) || CHR (9);
        debug_msg ('Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                'Others Exception in PROCESS_CALLOFF_ORDER = ' || SQLERRM);
            x_return_status   := 'E';
            debug_msg ('End ' || lc_sub_prog_name);
            ROLLBACK;
    END process_calloff_order;

    -- ======================================================================================
    -- This procedure spawns child requests based on no. of threads
    -- ======================================================================================
    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE
                          , p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_consumption IN oe_order_lines_all.global_attribute19%TYPE, p_threads IN NUMBER)
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'MASTER_PRC';
        ln_req_id          NUMBER;
        lc_req_data        VARCHAR2 (10);
        lc_status          VARCHAR2 (10);
    BEGIN
        lc_req_data   := fnd_conc_global.request_data;

        IF lc_req_data IS NULL
        THEN
            debug_msg ('Start ' || lc_sub_prog_name);

            lc_status   := xxd_ont_check_plan_run_fnc ();

            IF lc_status = 'N'
            THEN
                FOR i IN 1 .. p_threads
                LOOP
                    ln_req_id   := 0;

                    ln_req_id   :=
                        fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_BULK_ORDER_CHILD', description => NULL, start_time => NULL, sub_request => TRUE, argument1 => p_org_id, argument2 => p_cust_account_id, argument3 => p_cust_po_number, argument4 => p_order_number_from, argument5 => p_order_number_to, argument6 => p_ordered_date_from, argument7 => p_ordered_date_to, argument8 => p_request_date_from, argument9 => p_request_date_to, argument10 => p_order_source_id, argument11 => p_order_type_id, argument12 => p_consumption, argument13 => p_threads
                                                    , argument14 => i);
                    COMMIT;
                END LOOP;

                fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                                                 request_data   => 1);

                debug_msg ('Successfully Submitted Child Threads');
            ELSE
                x_errbuf    :=
                    'Planning Programs are running in ASCP. Calloff-Bulk Linking Program cannot run now!!!';
                debug_msg (x_errbuf);
                x_retcode   := 1;
            END IF;
        END IF;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_errbuf    := SQLERRM;
            x_retcode   := 2;
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC : ' || x_errbuf);
    END master_prc;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- 1. Selects Eligible Order Lines
    -- 2. Calls Linking Process
    -- ======================================================================================
    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_consumption IN oe_order_lines_all.global_attribute19%TYPE, p_threads IN NUMBER
                         , p_run_id IN NUMBER)
    AS
        CURSOR get_orders_c IS
              -- Parallel processing is not in scope for Bulk Phase II
              --         SELECT *
              --           FROM (SELECT order_number,
              --                        header_id,
              --                        line_id,
              --                        NTILE (p_threads) OVER (PARTITION BY ORDER BY latest_acceptable_date)
              --           run_id
              --           FROM (
              SELECT /*+ parallel(2)*/
                     ooha.order_number, ooha.header_id, oola.line_id,
                     oola.latest_acceptable_date, oola.global_attribute19 status
                FROM oe_order_lines_all oola, oe_order_headers_all ooha, fnd_lookup_values flv
               WHERE     ooha.header_id = oola.header_id
                     AND ooha.open_flag = 'Y'
                     AND oola.open_flag = 'Y'
                     AND ooha.booked_flag = 'Y'
                     AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                     AND ooha.org_id = TO_NUMBER (flv.tag)
                     AND flv.language = USERENV ('LANG')
                     AND flv.enabled_flag = 'Y'
                     AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                     AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                     AND flv.lookup_type = 'XXD_ONT_BLK_CALLOFF_ORDER_TYPE'
                     AND ooha.org_id = p_org_id
                     AND oola.global_attribute19 IS NOT NULL
                     AND oola.global_attribute19 = p_consumption
                     AND ((p_cust_account_id IS NOT NULL AND ooha.sold_to_org_id = p_cust_account_id) OR (p_cust_account_id IS NULL AND 1 = 1))
                     AND ((p_cust_po_number IS NOT NULL AND ooha.cust_po_number = p_cust_po_number) OR (p_cust_po_number IS NULL AND 1 = 1))
                     AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                     AND ((p_ordered_date_from IS NOT NULL AND p_ordered_date_to IS NOT NULL AND ooha.ordered_date BETWEEN fnd_date.canonical_to_date (p_ordered_date_from) AND fnd_date.canonical_to_date (p_ordered_date_to)) OR ((p_ordered_date_from IS NULL OR p_ordered_date_to IS NULL) AND 1 = 1))
                     AND ((p_request_date_from IS NOT NULL AND p_request_date_to IS NOT NULL AND ooha.request_date BETWEEN fnd_date.canonical_to_date (p_request_date_from) AND fnd_date.canonical_to_date (p_request_date_to)) OR ((p_request_date_from IS NULL OR p_request_date_to IS NULL) AND 1 = 1))
                     AND ((p_order_source_id IS NOT NULL AND ooha.order_source_id = p_order_source_id) OR (p_order_source_id IS NULL AND 1 = 1))
                     AND ((p_order_type_id IS NOT NULL AND ooha.order_type_id = p_order_type_id) OR (p_order_type_id IS NULL AND 1 = 1))
            ORDER BY oola.latest_acceptable_date;

        --))
        --WHERE run_id = p_run_id;

        lc_sub_prog_name   VARCHAR2 (100) := 'CHILD_PRC';
        lc_return_status   VARCHAR2 (1);
        lc_result_code     VARCHAR2 (40);
        ln_var             NUMBER := 0;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg ('Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        init ();

        FOR orders_rec IN get_orders_c
        LOOP
            lc_return_status   := NULL;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Calloff Order Number '
                || orders_rec.order_number
                || '. Header ID '
                || orders_rec.header_id
                || '. Order Line ID '
                || orders_rec.line_id
                || '. Status as '
                || orders_rec.status);

            -- Call Linking Program
            process_calloff_order (p_header_id => orders_rec.header_id, p_line_id => orders_rec.line_id, x_return_status => lc_return_status
                                   , x_result_code => lc_result_code);

            gc_delimiter       := CHR (9);

            IF lc_return_status = 'S'
            THEN
                IF orders_rec.status = 'NEW'
                THEN
                    debug_msg (
                           'Progressing Workflow Activity with Result_code as '
                        || lc_result_code);

                    BEGIN
                        wf_engine.completeactivity (
                            itemtype   => 'OEOL',
                            itemkey    => TO_CHAR (orders_rec.line_id),
                            activity   => 'XXD_ONT_BULK_WAIT',
                            result     => lc_result_code);
                        debug_msg ('WF Progress Success');
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            debug_msg ('WF Error: ' || SQLERRM);
                    END;
                END IF;

                debug_msg ('All good; commiting');
                COMMIT;
            ELSE
                debug_msg ('Rollbacking');
                ROLLBACK;
            END IF;

            gc_delimiter       := '';
        END LOOP;

        IF lc_return_status IS NULL
        THEN
            debug_msg ('No Data Found');
        END IF;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('End ' || lc_sub_prog_name);
            ROLLBACK;
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in CHILD_PRC = ' || SQLERRM);
    END child_prc;
END xxd_ont_bulk_calloff_order_pkg;
/
