--
-- XXD_ONT_CALLOFF_PROCESS_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CALLOFF_PROCESS_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_PROCESS_PKG
    * Design       : This package will be used for Calloff Orders Processing
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 30-May-2018  1.0        Viswanathan Pandian     Initial Version
    -- 02-Mar-2020  1.1        Viswanathan Pandian     Updated for CCR0008440
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
    gc_debug_enable        VARCHAR2 (1);

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
        oe_msg_pub.delete_msg;
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
    PROCEDURE insert_data (p_calloff_header_id IN oe_order_headers_all.header_id%TYPE, p_calloff_line_id IN oe_order_lines_all.line_id%TYPE, p_bulk_header_id IN oe_order_headers_all.header_id%TYPE, p_bulk_line_id IN oe_order_lines_all.line_id%TYPE, p_linked_qty IN NUMBER, p_free_atp_cust IN VARCHAR2
                           ,                           -- Added for CCR0008440
                             p_cancel_qty IN NUMBER)
    AS
        lc_sub_prog_name       VARCHAR2 (100) := 'INSERT_DATA';
        l_calloff_header_rec   oe_order_pub.header_rec_type;
        l_calloff_line_rec     oe_order_pub.line_rec_type;
        l_bulk_header_rec      oe_order_pub.header_rec_type;
        l_bulk_line_rec        oe_order_pub.line_rec_type;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);

        oe_header_util.query_row (p_header_id    => p_calloff_header_id,
                                  x_header_rec   => l_calloff_header_rec);

        oe_line_util.query_row (p_line_id    => p_calloff_line_id,
                                x_line_rec   => l_calloff_line_rec);

        -- Start changes for CCR0008440
        IF p_bulk_header_id IS NOT NULL
        THEN
            -- End changes for CCR0008440

            oe_header_util.query_row (p_header_id    => p_bulk_header_id,
                                      x_header_rec   => l_bulk_header_rec);

            oe_line_util.query_row (p_line_id    => p_bulk_line_id,
                                    x_line_rec   => l_bulk_line_rec);
        END IF;                                        -- Added for CCR0008440

        INSERT INTO xxd_ont_bulk_orders_t (bulk_id, link_type, status,
                                           error_message, org_id, calloff_header_id, calloff_order_number, calloff_sold_to_org_id, calloff_cust_po_number, calloff_request_date, calloff_order_brand, bulk_header_id, bulk_order_number, bulk_sold_to_org_id, bulk_cust_po_number, bulk_request_date, bulk_order_brand, calloff_line_id, calloff_line_number, calloff_shipment_number, calloff_ordered_item, calloff_inventory_item_id, calloff_ordered_quantity, new_calloff_ordered_quantity, calloff_line_request_date, calloff_schedule_ship_date, calloff_latest_acceptable_date, calloff_line_demand_class_code, bulk_line_id, bulk_line_number, bulk_shipment_number, bulk_ordered_item, bulk_inventory_item_id, bulk_ordered_quantity, bulk_line_request_date, bulk_schedule_ship_date, bulk_latest_acceptable_date, bulk_line_demand_class_code, linked_qty, atp_qty, cancel_qty, varchar_attribute2, -- Added for CCR0008440
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               parent_request_id, customer_batch_id, bulk_batch_id, calloff_batch_id, line_status, cancel_status, schedule_status, request_id, creation_date, created_by, last_update_date, last_updated_by
                                           , last_update_login)
             VALUES (xxdo.xxd_ont_bulk_orders_s.NEXTVAL, -- Start changes for CCR0008440
                                                         -- 'BULK_LINK',
                                                         DECODE (p_bulk_header_id, NULL, 'BULK_DELINK', 'BULK_LINK'), -- End changes for CCR0008440
                                                                                                                      'S', NULL, l_calloff_header_rec.org_id, l_calloff_header_rec.header_id, l_calloff_header_rec.order_number, l_calloff_header_rec.sold_to_org_id, l_calloff_header_rec.cust_po_number, l_calloff_header_rec.request_date, l_calloff_header_rec.attribute5, l_bulk_header_rec.header_id, l_bulk_header_rec.order_number, l_bulk_header_rec.sold_to_org_id, l_bulk_header_rec.cust_po_number, l_bulk_header_rec.request_date, l_bulk_header_rec.attribute5, l_calloff_line_rec.line_id, l_calloff_line_rec.line_number, l_calloff_line_rec.shipment_number, l_calloff_line_rec.ordered_item, l_calloff_line_rec.inventory_item_id, l_calloff_line_rec.ordered_quantity, l_calloff_line_rec.ordered_quantity, l_calloff_line_rec.request_date, l_calloff_line_rec.schedule_ship_date, l_calloff_line_rec.latest_acceptable_date, l_calloff_line_rec.demand_class_code, l_bulk_line_rec.line_id, l_bulk_line_rec.line_number, l_bulk_line_rec.shipment_number, l_bulk_line_rec.ordered_item, l_bulk_line_rec.inventory_item_id, l_bulk_line_rec.ordered_quantity, l_bulk_line_rec.request_date, l_bulk_line_rec.schedule_ship_date, l_bulk_line_rec.latest_acceptable_date, l_bulk_line_rec.demand_class_code, p_linked_qty, 0, p_cancel_qty, p_free_atp_cust, -- Added for CCR0008440
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               gn_request_id, NULL, NULL, NULL, l_calloff_line_rec.global_attribute19, -- Start changes for CCR0008440
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       -- 'N',
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       DECODE (p_bulk_header_id, NULL, 'S', 'N'), -- End changes for CCR0008440
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  'N', NULL, SYSDATE, gn_user_id, SYSDATE, gn_user_id
                     , gn_login_id);

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in INSERT_DATA = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
    END insert_data;

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
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        oe_msg_pub.delete_msg;

        oe_order_pub.process_order (
            p_api_version_number       => 1.0,
            p_init_msg_list            => fnd_api.g_true,
            p_return_values            => fnd_api.g_true,
            p_action_commit            => fnd_api.g_false,
            x_return_status            => lc_return_status,
            x_msg_count                => ln_msg_count,
            x_msg_data                 => lc_msg_data,
            p_org_id                   => gn_org_id,   -- Added for CCR0008440
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
                lc_error_message   :=
                    SUBSTR (lc_error_message || lc_msg_data, 1, 3000); -- Added SUBSTR for CCR0008440
            END LOOP;

            x_error_message   :=
                NVL (lc_error_message, 'OE_ORDER_PUB Failed');
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
    -- This procedure will be used to release hold
    -- ======================================================================================
    PROCEDURE release_hold_prc (p_header_id IN oe_order_holds_all.header_id%TYPE, p_line_id IN oe_order_holds_all.line_id%TYPE, x_status OUT NOCOPY VARCHAR2)
    AS
        CURSOR get_calloff_hold_c (
            p_order_type_id oe_order_headers_all.order_type_id%TYPE)
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

        lc_sub_prog_name       VARCHAR2 (100) := 'RELEASE_HOLD_PRC';
        lc_return_status       VARCHAR2 (1);
        lc_message             VARCHAR2 (4000);
        lc_error_message       VARCHAR2 (4000);
        lc_msg_data            VARCHAR2 (1000);
        ln_msg_count           NUMBER;
        ln_msg_index_out       NUMBER;
        ln_hold_id             oe_hold_sources_all.hold_id%TYPE;
        l_calloff_header_rec   oe_order_pub.header_rec_type;
        l_order_tbl_type       oe_holds_pvt.order_tbl_type;
    BEGIN
        gc_delimiter           := CHR (9);
        debug_msg ('Start ' || lc_sub_prog_name);
        oe_msg_pub.delete_msg;
        oe_msg_pub.initialize;
        l_calloff_header_rec   := oe_order_pub.g_miss_header_rec;
        oe_header_util.query_row (p_header_id    => p_header_id,
                                  x_header_rec   => l_calloff_header_rec);

        gc_delimiter           := CHR (9) || CHR (9);

        /****************************************************************************************
        * Release Hold on Calloff Section
        ****************************************************************************************/
        debug_msg ('Releasing Hold');

        -- Verify if Hold exists on Calloff
        OPEN get_calloff_hold_c (l_calloff_header_rec.order_type_id);

        FETCH get_calloff_hold_c INTO ln_hold_id;

        CLOSE get_calloff_hold_c;

        debug_msg ('Calloff Order Hold ID ' || ln_hold_id);

        IF ln_hold_id IS NOT NULL
        THEN
            l_order_tbl_type (1).header_id   := p_header_id;
            l_order_tbl_type (1).line_id     := p_line_id;

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
                lc_message   :=
                    SUBSTR (('Release hold failed = ' || lc_error_message),
                            1,
                            240);
            END IF;
        ELSE
            lc_message         := 'No Hold exists';
            debug_msg (lc_message);
            lc_return_status   := 'S';
        END IF;

        x_status               := lc_return_status;
        gc_delimiter           := CHR (9);
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('Others Exception in RELEASE_HOLD_PRC = ' || SQLERRM);
            debug_msg ('End ' || lc_sub_prog_name);
            x_status   := 'E';
    END release_hold_prc;

    -- Start changes for CCR0008440
    FUNCTION get_order_type_fnc (
        p_org_id IN oe_order_headers_all.org_id%TYPE)
        RETURN order_type_table
        PIPELINED
    IS
        l_order_type_rec   order_type_record;
    BEGIN
        FOR l_order_type_rec
            IN (SELECT TO_NUMBER (lookup_code)
                  FROM fnd_lookup_values
                 WHERE     1 = 1
                       AND language = USERENV ('LANG')
                       AND enabled_flag = 'Y'
                       AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                       NVL (
                                                           start_date_active,
                                                           SYSDATE))
                                               AND TRUNC (
                                                       NVL (end_date_active,
                                                            SYSDATE))
                       AND lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                       AND TO_NUMBER (tag) = p_org_id)
        LOOP
            PIPE ROW (l_order_type_rec);
        END LOOP;

        RETURN;
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg (
                'Others Exception in GET_ORDER_TYPE_FNC = ' || SQLERRM);
    END get_order_type_fnc;

    -- End changes for CCR0008440
    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- 1. Selects and Inserts Eligible Calloff Order Lines in custom table
    -- 2. Spawns child requests based on no. of threads
    -- ======================================================================================
    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE, p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_bulk_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_threads IN NUMBER
                          , p_debug IN VARCHAR2)
    AS
        CURSOR get_calloff_lines_c IS
              SELECT /*+ parallel(2)*/
                     ooha.order_number,
                     ooha.header_id,
                     ooha.sold_to_org_id,
                     UPPER (NVL (ooha.cust_po_number, '-99')) cust_po_number,
                     oola.line_id,
                     oola.inventory_item_id,
                     oola.latest_acceptable_date,
                     oola.ordered_quantity,
                     oola.global_attribute19 line_status,
                     -- Start changes for CCR0008440
                     oola.request_date,
                     (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                        FROM fnd_lookup_values flv
                       WHERE     flv.language = USERENV ('LANG')
                             AND flv.enabled_flag = 'Y'
                             AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                             NVL (
                                                                 flv.start_date_active,
                                                                 SYSDATE))
                                                     AND TRUNC (
                                                             NVL (
                                                                 flv.end_date_active,
                                                                 SYSDATE))
                             AND flv.lookup_type =
                                 'XXD_ONT_BULK_ACCT_NO_FREE_ATP'
                             AND TO_NUMBER (flv.attribute1) = ooha.org_id
                             AND TO_NUMBER (flv.attribute2) =
                                 ooha.sold_to_org_id
                             AND flv.attribute3 = 'Y'
                             AND ((flv.attribute4 IS NOT NULL AND TO_NUMBER (flv.attribute4) = ooha.order_type_id) OR (flv.attribute4 IS NULL AND 1 = 1))) free_atp_cust
                -- End changes for CCR0008440
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
                     AND oola.global_attribute19 IN ('NEW', 'REPROCESS')
                     AND ((p_cust_account_id IS NOT NULL AND ooha.sold_to_org_id = p_cust_account_id) OR (p_cust_account_id IS NULL AND 1 = 1))
                     AND ((p_cust_po_number IS NOT NULL AND ooha.cust_po_number = p_cust_po_number) OR (p_cust_po_number IS NULL AND 1 = 1))
                     AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                     AND ((p_ordered_date_from IS NOT NULL AND p_ordered_date_to IS NOT NULL AND TRUNC (ooha.ordered_date) BETWEEN fnd_date.canonical_to_date (p_ordered_date_from) AND fnd_date.canonical_to_date (p_ordered_date_to)) OR ((p_ordered_date_from IS NULL OR p_ordered_date_to IS NULL) AND 1 = 1))
                     AND ((p_request_date_from IS NOT NULL AND p_request_date_to IS NOT NULL AND TRUNC (ooha.request_date) BETWEEN fnd_date.canonical_to_date (p_request_date_from) AND fnd_date.canonical_to_date (p_request_date_to)) OR ((p_request_date_from IS NULL OR p_request_date_to IS NULL) AND 1 = 1))
                     AND ((p_order_source_id IS NOT NULL AND ooha.order_source_id = p_order_source_id) OR (p_order_source_id IS NULL AND 1 = 1))
                     AND ((p_order_type_id IS NOT NULL AND ooha.order_type_id = p_order_type_id) OR (p_order_type_id IS NULL AND 1 = 1))
                     AND NOT EXISTS
                             (SELECT 1
                                FROM xxd_ont_bulk_orders_t
                               WHERE     calloff_header_id = ooha.header_id
                                     AND calloff_line_id = oola.line_id
                                     AND link_type = 'BULK_LINK')
            ORDER BY oola.line_id; -- Used Line ID instead of Creation Date for CCR0008440

        CURSOR get_bulk_lines_c (p_cust_po_number oe_order_headers_all.cust_po_number%TYPE, p_sold_to_org_id oe_order_headers_all.sold_to_org_id%TYPE, p_latest_acceptable_date oe_order_lines_all.latest_acceptable_date%TYPE
                                 , p_request_date oe_order_lines_all.request_date%TYPE, -- Added for CCR0008440
                                                                                        p_inventory_item_id oe_order_lines_all.inventory_item_id%TYPE)
        IS
            -- Start changes for CCR0008440
            --SELECT  /*+ use_hash(OOHA,OOLA) */
            /*ooha.order_number,
            oola.header_id,
            oola.line_id,
            ooha.org_id,
            oola.demand_class_code,
            UPPER (ooha.cust_po_number) bulk_cust_po_number,
            oola.ordered_quantity
       FROM oe_order_headers_all ooha, oe_order_lines_all oola
      WHERE     ooha.header_id = oola.header_id
            AND ooha.open_flag = 'Y'
            AND oola.open_flag = 'Y'
            AND ooha.org_id = p_org_id
            AND ooha.order_type_id = p_bulk_order_type_id
            AND ooha.sold_to_org_id = p_sold_to_org_id
            AND oola.inventory_item_id = p_inventory_item_id
            AND oola.request_date <= oola.latest_acceptable_date
            AND oola.schedule_ship_date < p_latest_acceptable_date + 1
            AND oola.schedule_ship_date IS NOT NULL
            AND oola.ordered_quantity > 0
   ORDER BY CASE
                WHEN bulk_cust_po_number = p_cust_po_number THEN 1
            END ASC,
            oola.schedule_ship_date DESC, -- Ordering by the matching PO first
            CASE
                WHEN bulk_cust_po_number <> p_cust_po_number THEN 2
            END ASC,
            oola.schedule_ship_date DESC;
            -- Ordering by the oldest SSD then
            */
            -- PO Match Consumption
            SELECT *
              FROM (  SELECT /*+ use_hash(OOHA,OOLA) */
                             ooha.order_number, oola.header_id, oola.line_id,
                             ooha.org_id, oola.demand_class_code, UPPER (ooha.cust_po_number) bulk_cust_po_number,
                             oola.ordered_quantity
                        FROM oe_order_headers_all ooha, oe_order_lines_all oola, TABLE (get_order_type_fnc (ooha.org_id)) ord_typ
                       WHERE     ooha.header_id = oola.header_id
                             AND ooha.open_flag = 'Y'
                             AND oola.open_flag = 'Y'
                             AND ooha.org_id = p_org_id
                             AND ooha.order_type_id = ord_typ.order_type_id
                             AND ooha.sold_to_org_id = p_sold_to_org_id
                             AND oola.inventory_item_id = p_inventory_item_id
                             AND oola.request_date <=
                                 oola.latest_acceptable_date
                             AND oola.schedule_ship_date <
                                 p_latest_acceptable_date + 1
                             AND p_cust_po_number = UPPER (ooha.cust_po_number)
                             AND oola.schedule_ship_date IS NOT NULL
                             AND oola.ordered_quantity > 0
                             AND ((p_bulk_order_type_id IS NOT NULL AND ooha.order_type_id = p_bulk_order_type_id) OR (p_bulk_order_type_id IS NULL AND 1 = 1))
                    ORDER BY oola.schedule_ship_date ASC)
            UNION ALL
            -- Backward Consumption
            SELECT *
              FROM (  SELECT /*+ use_hash(OOHA,OOLA) */
                             ooha.order_number, oola.header_id, oola.line_id,
                             ooha.org_id, oola.demand_class_code, UPPER (ooha.cust_po_number) bulk_cust_po_number,
                             oola.ordered_quantity
                        FROM oe_order_headers_all ooha, oe_order_lines_all oola, TABLE (get_order_type_fnc (ooha.org_id)) ord_typ
                       WHERE     ooha.header_id = oola.header_id
                             AND ooha.open_flag = 'Y'
                             AND oola.open_flag = 'Y'
                             AND ooha.org_id = p_org_id
                             AND ooha.order_type_id = ord_typ.order_type_id
                             AND ooha.sold_to_org_id = p_sold_to_org_id
                             AND oola.inventory_item_id = p_inventory_item_id
                             AND oola.request_date <=
                                 oola.latest_acceptable_date
                             AND oola.schedule_ship_date <
                                 p_latest_acceptable_date + 1
                             AND p_cust_po_number <>
                                 UPPER (ooha.cust_po_number)
                             AND TRUNC (oola.schedule_ship_date) <=
                                 p_request_date
                             AND oola.schedule_ship_date IS NOT NULL
                             AND oola.ordered_quantity > 0
                             AND ((p_bulk_order_type_id IS NOT NULL AND ooha.order_type_id = p_bulk_order_type_id) OR (p_bulk_order_type_id IS NULL AND 1 = 1))
                    ORDER BY oola.schedule_ship_date DESC)
            UNION ALL
            -- Forward Consumption
            SELECT *
              FROM (  SELECT /*+ use_hash(OOHA,OOLA) */
                             ooha.order_number, oola.header_id, oola.line_id,
                             ooha.org_id, oola.demand_class_code, UPPER (ooha.cust_po_number) bulk_cust_po_number,
                             oola.ordered_quantity
                        FROM oe_order_headers_all ooha, oe_order_lines_all oola, TABLE (get_order_type_fnc (ooha.org_id)) ord_typ
                       WHERE     ooha.header_id = oola.header_id
                             AND ooha.open_flag = 'Y'
                             AND oola.open_flag = 'Y'
                             AND ooha.org_id = p_org_id
                             AND ooha.order_type_id = ord_typ.order_type_id
                             AND ooha.sold_to_org_id = p_sold_to_org_id
                             AND oola.inventory_item_id = p_inventory_item_id
                             AND oola.request_date <=
                                 oola.latest_acceptable_date
                             AND oola.schedule_ship_date <
                                 p_latest_acceptable_date + 1
                             AND p_cust_po_number <>
                                 UPPER (ooha.cust_po_number)
                             AND TRUNC (oola.schedule_ship_date) >
                                 p_request_date
                             AND oola.schedule_ship_date IS NOT NULL
                             AND oola.ordered_quantity > 0
                             AND ((p_bulk_order_type_id IS NOT NULL AND ooha.order_type_id = p_bulk_order_type_id) OR (p_bulk_order_type_id IS NULL AND 1 = 1))
                    ORDER BY oola.schedule_ship_date ASC);

        -- End changes for CCR0008440

        CURSOR get_batches IS
              SELECT bucket, MIN (customer_batch_id) from_customer_batch_id, MAX (customer_batch_id) to_customer_batch_id
                FROM (SELECT customer_batch_id, NTILE (p_threads) OVER (ORDER BY customer_batch_id) bucket
                        FROM (SELECT DISTINCT customer_batch_id
                                FROM xxd_ont_bulk_orders_t
                               WHERE parent_request_id = gn_request_id))
            GROUP BY bucket
            ORDER BY 1;

        TYPE calloff_lines_tbl_typ IS TABLE OF get_calloff_lines_c%ROWTYPE;

        l_calloff_lines_tbl_typ    calloff_lines_tbl_typ;
        lc_sub_prog_name           VARCHAR2 (100) := 'MASTER_PRC';
        ln_req_id                  NUMBER;
        ln_record_count            NUMBER := 0;
        ln_bulk_qty                NUMBER := 0;
        ln_bulk_count              NUMBER := 0;
        ln_bulk_remaining_qty      NUMBER := 0;
        lc_remaining_calloff_qty   NUMBER := 0;
        ln_cancel_qty              NUMBER := 0;
        ln_linked_qty              NUMBER := 0;
        ln_index                   NUMBER := 0;
        lc_req_data                VARCHAR2 (10);
        lc_status                  VARCHAR2 (10);
        lc_bulk_available          VARCHAR2 (1);
        lc_hold_status             VARCHAR2 (1);

        -- Start changes for CCR0008440
        TYPE conc_request_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_conc_request_tbl         conc_request_tbl;
        lb_req_status              BOOLEAN;
        lc_phase                   VARCHAR2 (100);
        lc_dev_phase               VARCHAR2 (100);
        lc_dev_status              VARCHAR2 (100);
        lc_message                 VARCHAR2 (4000);
        ln_req_count               NUMBER := 0;
    -- End changes for CCR0008440
    BEGIN
        lc_req_data       := fnd_conc_global.request_data;

        IF lc_req_data = 'MASTER'
        THEN
            RETURN;
        END IF;

        init;                                          -- Added for CCR0008440
        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_debug, 'N'));
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        lc_status         := xxd_ont_check_plan_run_fnc ();

        IF lc_status = 'N'
        THEN
            -- Select Eligible Calloff order lines
            OPEN get_calloff_lines_c;

           <<calloff_lines>>
            LOOP
                FETCH get_calloff_lines_c
                    BULK COLLECT INTO l_calloff_lines_tbl_typ
                    LIMIT 2000;

                EXIT calloff_lines WHEN l_calloff_lines_tbl_typ.COUNT = 0;

                FOR ln_index IN 1 .. l_calloff_lines_tbl_typ.COUNT
                LOOP
                    gc_delimiter               := '';
                    debug_msg (RPAD ('=', 100, '='));
                    debug_msg (
                           'Processing Calloff Order Number '
                        || l_calloff_lines_tbl_typ (ln_index).order_number
                        || '. Header ID '
                        || l_calloff_lines_tbl_typ (ln_index).header_id
                        || '. Order Line ID '
                        || l_calloff_lines_tbl_typ (ln_index).line_id
                        || '. Status as '
                        || l_calloff_lines_tbl_typ (ln_index).line_status);
                    debug_msg (
                           'Cust_PO_Number = '
                        || l_calloff_lines_tbl_typ (ln_index).cust_po_number);
                    debug_msg (
                           'Sold_To_Org_ID = '
                        || l_calloff_lines_tbl_typ (ln_index).sold_to_org_id);
                    debug_msg (
                           'Latest_Acceptable_Date = '
                        || l_calloff_lines_tbl_typ (ln_index).latest_acceptable_date);
                    debug_msg (
                           'Inventory_Item_ID = '
                        || l_calloff_lines_tbl_typ (ln_index).inventory_item_id);
                    debug_msg (
                           'Calloff Qty = '
                        || l_calloff_lines_tbl_typ (ln_index).ordered_quantity);
                    ln_bulk_qty                := 0;
                    lc_remaining_calloff_qty   := 0;
                    ln_cancel_qty              := 0;
                    ln_linked_qty              := 0;
                    lc_bulk_available          := 'N';
                    ln_bulk_remaining_qty      := 0;

                    -- Select respective Bulk order lines
                    FOR bulk_lines_rec
                        IN get_bulk_lines_c (
                               l_calloff_lines_tbl_typ (ln_index).cust_po_number,
                               l_calloff_lines_tbl_typ (ln_index).sold_to_org_id,
                               l_calloff_lines_tbl_typ (ln_index).latest_acceptable_date,
                               TRUNC (
                                   l_calloff_lines_tbl_typ (ln_index).request_date), -- Added for CCR0008440
                               l_calloff_lines_tbl_typ (ln_index).inventory_item_id)
                    LOOP
                        gc_delimiter   := CHR (9);

                        -- Find All Lines Till Qty is Fulfilled
                        IF l_calloff_lines_tbl_typ (ln_index).ordered_quantity >
                           ln_bulk_qty
                        THEN
                            debug_msg (
                                   'Calloff Qty '
                                || l_calloff_lines_tbl_typ (ln_index).ordered_quantity
                                || ' > Bulk Qty Variable '
                                || ln_bulk_qty);
                            gc_delimiter   := CHR (9) || CHR (9);
                            debug_msg (
                                   'Processing Bulk Order Number '
                                || bulk_lines_rec.order_number
                                || '. Header ID '
                                || bulk_lines_rec.header_id
                                || '. Order Line ID '
                                || bulk_lines_rec.line_id);
                            debug_msg (
                                'Original Bulk Qty = ' || bulk_lines_rec.ordered_quantity);

                            SELECT COUNT (1), SUM (linked_qty)
                              INTO ln_bulk_count, ln_bulk_remaining_qty
                              FROM xxd_ont_bulk_orders_t
                             WHERE     bulk_line_id = bulk_lines_rec.line_id
                                   AND parent_request_id = gn_request_id;

                            debug_msg (
                                   'Existing Count of this Bulk Line = '
                                || ln_bulk_count);

                            IF ln_bulk_count > 0
                            THEN
                                ln_bulk_remaining_qty   :=
                                    CASE
                                        WHEN   bulk_lines_rec.ordered_quantity
                                             - ln_bulk_remaining_qty >
                                             0
                                        THEN
                                              bulk_lines_rec.ordered_quantity
                                            - ln_bulk_remaining_qty
                                        ELSE
                                              ln_bulk_remaining_qty
                                            - bulk_lines_rec.ordered_quantity
                                    END;
                            ELSE
                                ln_bulk_remaining_qty   :=
                                    bulk_lines_rec.ordered_quantity;
                            END IF;

                            debug_msg (
                                   'Remaining Qty of this Bulk Line = '
                                || ln_bulk_remaining_qty);

                            ln_bulk_qty    :=
                                ln_bulk_qty + ln_bulk_remaining_qty;

                            IF ln_bulk_qty > 0
                            THEN
                                IF l_calloff_lines_tbl_typ (ln_index).ordered_quantity >=
                                   ln_bulk_qty
                                THEN
                                    debug_msg (
                                        'Calloff Qty is >= Available Bulk Qty. Cancelling all qty in Bulk');
                                    ln_cancel_qty   := 0;
                                    ln_linked_qty   := ln_bulk_remaining_qty;
                                ELSE
                                    debug_msg (
                                        'Calloff Qty is < Available Bulk Qty. Cancelling remaining qty in Bulk');
                                    ln_linked_qty   :=
                                        CASE
                                            WHEN lc_remaining_calloff_qty = 0
                                            THEN
                                                l_calloff_lines_tbl_typ (
                                                    ln_index).ordered_quantity
                                            ELSE
                                                CASE
                                                    WHEN   l_calloff_lines_tbl_typ (
                                                               ln_index).ordered_quantity
                                                         - lc_remaining_calloff_qty >
                                                         0
                                                    THEN
                                                          l_calloff_lines_tbl_typ (
                                                              ln_index).ordered_quantity
                                                        - lc_remaining_calloff_qty
                                                    ELSE
                                                        0
                                                END
                                        END;

                                    ln_cancel_qty   :=
                                        CASE
                                            WHEN   ln_bulk_remaining_qty
                                                 - ln_linked_qty >
                                                 0
                                            THEN
                                                  ln_bulk_remaining_qty
                                                - ln_linked_qty
                                            ELSE
                                                0
                                        END;
                                END IF;

                                debug_msg (
                                    'To Cancel Quantity = ' || ln_cancel_qty);
                                ln_record_count     := ln_record_count + 1;
                                lc_bulk_available   := 'Y';

                                insert_data (p_calloff_header_id => l_calloff_lines_tbl_typ (ln_index).header_id, p_calloff_line_id => l_calloff_lines_tbl_typ (ln_index).line_id, p_bulk_header_id => bulk_lines_rec.header_id, p_bulk_line_id => bulk_lines_rec.line_id, p_linked_qty => ln_linked_qty, -- Start changes for CCR0008440
                                                                                                                                                                                                                                                                                                          p_free_atp_cust => l_calloff_lines_tbl_typ (ln_index).free_atp_cust
                                             , -- End changes for CCR0008440
                                               p_cancel_qty => ln_cancel_qty);
                            ELSE
                                debug_msg (
                                    'Already Consumed this Bulk Line. Checking for next line!');
                            END IF;
                        ELSE
                            -- If Quantity Fulfilled Then Exit Loop
                            debug_msg (
                                   'Calloff Qty '
                                || l_calloff_lines_tbl_typ (ln_index).ordered_quantity
                                || ' <= ln_bulk_qty '
                                || ln_bulk_qty);
                            debug_msg (
                                'Quantity Fulfilled from all availble Bulk Orders');
                            EXIT;
                        END IF;

                        lc_remaining_calloff_qty   :=
                            lc_remaining_calloff_qty + ln_bulk_remaining_qty;
                    END LOOP;

                    IF lc_bulk_available = 'N'
                    THEN
                        -- Start changes for CCR0008440
                        -- Check if Customer is eligible to cancel line if no bulk
                        -- And Calloff Qty is not fully filfilled
                        IF l_calloff_lines_tbl_typ (ln_index).free_atp_cust =
                           'Y'
                        THEN
                            debug_msg (
                                'No Free ATP eligible for this Customer. Insert record to cancel the line.');
                            insert_data (p_calloff_header_id => l_calloff_lines_tbl_typ (ln_index).header_id, p_calloff_line_id => l_calloff_lines_tbl_typ (ln_index).line_id, p_bulk_header_id => NULL, p_bulk_line_id => NULL, p_linked_qty => 0, p_free_atp_cust => l_calloff_lines_tbl_typ (ln_index).free_atp_cust
                                         , p_cancel_qty => 0);
                        ELSE
                            -- End changes for CCR0008440
                            debug_msg (
                                'No Bulk Lines Available. Progressing as Non Bulk.');
                            --If no bulk, then release hold and progress as normal order
                            release_hold_prc (
                                p_header_id   =>
                                    l_calloff_lines_tbl_typ (ln_index).header_id,
                                p_line_id   =>
                                    l_calloff_lines_tbl_typ (ln_index).line_id,
                                x_status   => lc_hold_status);

                            IF NVL (lc_hold_status, 'E') = 'S'
                            THEN
                                BEGIN
                                    wf_engine.completeactivity (
                                        itemtype   => 'OEOL',
                                        itemkey    =>
                                            TO_CHAR (
                                                l_calloff_lines_tbl_typ (
                                                    ln_index).line_id),
                                        activity   => 'XXD_ONT_BULK_WAIT',
                                        result     => 'NONBULK');
                                    debug_msg ('WF Progress Success');
                                EXCEPTION
                                    WHEN OTHERS
                                    THEN
                                        debug_msg ('WF Error: ' || SQLERRM);
                                END;

                                UPDATE oe_order_lines_all
                                   SET global_attribute19   = NULL
                                 WHERE line_id =
                                       l_calloff_lines_tbl_typ (ln_index).line_id;

                                COMMIT;
                            ELSE
                                debug_msg (
                                    'Release Hold Failed. Skip processing the current line!');
                            END IF;
                        END IF;                        -- Added for CCR0008440
                    END IF;
                END LOOP;

                COMMIT;
            END LOOP calloff_lines;

            CLOSE get_calloff_lines_c;

            COMMIT;

            IF ln_record_count > 0
            THEN
                gc_delimiter   := CHR (9);
                debug_msg (
                    'Quantity Fulfilled from all availble Bulk Orders');
                gc_delimiter   := '';
                debug_msg (RPAD ('=', 100, '='));
                debug_msg ('Total Record Count = ' || ln_record_count);

                -- Start changes for CCR0008440
                debug_msg (
                    'Calculate Split Qty for Partial Consumption Cases');

                MERGE INTO xxd_ont_bulk_orders_t xobot
                     USING (SELECT oola.line_id, (oola.ordered_quantity - xxd.lined_qty) split_qty
                              FROM oe_order_lines_all oola,
                                   (  SELECT calloff_line_id, SUM (linked_qty) lined_qty
                                        FROM xxd_ont_bulk_orders_t
                                       WHERE     link_type = 'BULK_LINK'
                                             AND varchar_attribute2 = 'Y'
                                             AND parent_request_id =
                                                 gn_request_id
                                    GROUP BY calloff_line_id) xxd
                             WHERE oola.line_id = xxd.calloff_line_id) xobot1
                        ON (xobot.calloff_line_id = xobot1.line_id AND xobot1.split_qty > 0)
                WHEN MATCHED
                THEN
                    UPDATE SET xobot.number_attribute1   = xobot1.split_qty;

                debug_msg ('Count = ' || ln_record_count);

                COMMIT;
                -- End changes for CCR0008440
                debug_msg ('Perform Customer Batching');

                -- Perform Customer Batching
                MERGE INTO xxd_ont_bulk_orders_t xobot
                     USING (SELECT ROWID, DENSE_RANK () OVER (ORDER BY calloff_sold_to_org_id) customer_batch_id
                              FROM xxd_ont_bulk_orders_t
                             WHERE parent_request_id = gn_request_id) xobot1
                        ON (xobot.ROWID = xobot1.ROWID)
                WHEN MATCHED
                THEN
                    UPDATE SET
                        xobot.customer_batch_id   = xobot1.customer_batch_id;

                COMMIT;

                debug_msg ('Submit Customer Child Programs');

                -- Submit Child Programs
                FOR i IN get_batches
                LOOP
                    -- Start changes for CCR0008440
                    -- ln_req_id := 0;
                    -- ln_req_id :=
                    ln_req_count   := ln_req_count + 1;
                    l_conc_request_tbl (ln_req_count)   :=
                        -- End changes for CCR0008440
                         fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_CALLOFF_PROCESS_CHILD', description => NULL, start_time => NULL, sub_request => FALSE, -- Modifed from TRUE for CCR0008440
                                                                                                                                                                                       argument1 => i.from_customer_batch_id, argument2 => i.to_customer_batch_id, argument3 => gn_request_id, argument4 => p_threads
                                                     , argument5 => p_debug);
                    COMMIT;
                END LOOP;

                debug_msg ('Successfully Submitted Child Threads');

                -- Start changes for CCR0008440
                --fnd_conc_global.set_req_globals (conc_status    => 'PAUSED',
                --                                 request_data   => 'MASTER');
                -- Wait for all Child Programs
                FOR i IN 1 .. l_conc_request_tbl.COUNT
                LOOP
                    LOOP
                        lb_req_status   :=
                            fnd_concurrent.wait_for_request (
                                request_id   => l_conc_request_tbl (i),
                                interval     => 10,
                                max_wait     => 60,
                                phase        => lc_phase,
                                status       => lc_status,
                                dev_phase    => lc_dev_phase,
                                dev_status   => lc_dev_status,
                                MESSAGE      => lc_message);
                        EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                                  OR UPPER (lc_status) IN
                                         ('CANCELLED', 'ERROR', 'TERMINATED');
                    END LOOP;
                END LOOP;
            -- End changes for CCR0008440
            ELSE
                debug_msg ('No Data Found to Process');
                debug_msg (RPAD ('=', 100, '='));
            END IF;
        ELSE
            x_errbuf    :=
                'Planning Programs are running in ASCP. Calloff Order Processing Program cannot run now!!!';
            debug_msg (x_errbuf);
            x_retcode   := 1;
        END IF;

        -- Update Custom Table Schedule Status
        MERGE INTO xxd_ont_bulk_orders_t xobot
             USING (SELECT header_id, line_id
                      FROM oe_order_lines_all
                     WHERE     org_id = gn_org_id
                           AND schedule_ship_date IS NOT NULL
                           AND cancelled_flag = 'N') oola
                ON (xobot.calloff_header_id = oola.header_id AND xobot.calloff_line_id = oola.line_id)
        WHEN MATCHED
        THEN
            UPDATE SET
                xobot.schedule_status   = 'S'
                     WHERE     org_id = gn_org_id
                           AND xobot.schedule_status = 'E'
                           AND xobot.link_type = 'BULK_LINK';

        COMMIT;
        debug_msg ('Update Schedule Status Count = ' || SQL%ROWCOUNT);

        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

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
    -- This procedure performs below activities for eligible calloff order lines
    -- 1. Submit Bulk Order Cancel Program and wait for completion
    -- 2. Submit Calloff Order Schedule Program and update status
    -- ======================================================================================
    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_from_customer_batch_id IN NUMBER, p_to_customer_batch_id IN NUMBER, p_parent_request_id IN NUMBER, p_threads IN NUMBER
                         , p_debug IN VARCHAR2)
    AS
        CURSOR get_bulk_order_batches IS
              SELECT bucket, MIN (bulk_batch_id) from_bulk_batch_id, MAX (bulk_batch_id) to_bulk_batch_id
                FROM (SELECT bulk_batch_id, NTILE (p_threads) OVER (ORDER BY bulk_batch_id) bucket
                        FROM (SELECT DISTINCT bulk_batch_id
                                FROM xxd_ont_bulk_orders_t
                               WHERE     parent_request_id =
                                         p_parent_request_id
                                     AND cancel_status = 'N'
                                     AND customer_batch_id >=
                                         p_from_customer_batch_id
                                     AND customer_batch_id <=
                                         p_to_customer_batch_id))
            GROUP BY bucket
            ORDER BY 1;

        -- Start changes for CCR0008440
        CURSOR get_calloff_split_batches IS
              SELECT bucket, MIN (calloff_batch_id) from_calloff_batch_id, MAX (calloff_batch_id) to_calloff_batch_id
                FROM (SELECT calloff_batch_id, NTILE (p_threads) OVER (ORDER BY calloff_batch_id) bucket
                        FROM (SELECT DISTINCT calloff_batch_id
                                FROM xxd_ont_bulk_orders_t
                               WHERE     parent_request_id =
                                         p_parent_request_id
                                     AND schedule_status = 'N'
                                     AND cancel_status = 'S'
                                     AND varchar_attribute2 = 'Y'
                                     AND customer_batch_id >=
                                         p_from_customer_batch_id
                                     AND customer_batch_id <=
                                         p_to_customer_batch_id))
            GROUP BY bucket
            UNION
            -- At least one Split program needs to be launched
            SELECT 1 bucket, 1 from_calloff_batch_id, 1 to_calloff_batch_id
              FROM xxd_ont_bulk_orders_t
             WHERE parent_request_id = p_parent_request_id AND ROWNUM = 1
            ORDER BY 1;

        -- End changes for CCR0008440

        CURSOR get_calloff_order_batches IS
              SELECT bucket, MIN (calloff_batch_id) from_calloff_batch_id, MAX (calloff_batch_id) to_calloff_batch_id
                FROM (SELECT calloff_batch_id, NTILE (p_threads) OVER (ORDER BY calloff_batch_id) bucket
                        FROM (SELECT DISTINCT calloff_batch_id
                                FROM xxd_ont_bulk_orders_t
                               WHERE     parent_request_id =
                                         p_parent_request_id
                                     AND schedule_status = 'N'
                                     AND cancel_status = 'S'
                                     AND customer_batch_id >=
                                         p_from_customer_batch_id
                                     AND customer_batch_id <=
                                         p_to_customer_batch_id))
            GROUP BY bucket
            ORDER BY 1;

        TYPE conc_request_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        lc_sub_prog_name             VARCHAR2 (100) := 'CHILD_PRC';
        l_bulk_conc_request_tbl      conc_request_tbl;
        l_calloff_conc_request_tbl   conc_request_tbl;
        lb_req_status                BOOLEAN;
        lc_phase                     VARCHAR2 (100);
        lc_status                    VARCHAR2 (100);
        lc_dev_phase                 VARCHAR2 (100);
        lc_dev_status                VARCHAR2 (100);
        lc_message                   VARCHAR2 (4000);
        lc_req_data                  VARCHAR2 (10);
        ln_bulk_count                NUMBER := 0;
        ln_calloff_count             NUMBER := 0;
        -- Start changes for CCR0008440
        ln_split_count               NUMBER := 0;
        l_split_conc_request_tbl     conc_request_tbl;
    -- End changes for CCR0008440
    BEGIN
        -- Start changes for CCR0008440
        -- Per Oracle Doc ID 1922152.1
        UPDATE fnd_concurrent_requests
           SET priority_request_id = p_parent_request_id, is_sub_request = 'Y'
         WHERE request_id = gn_request_id;

        -- End changes for CCR0008440
        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_debug, 'N'));
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('Perform Cancellation Batching');

        -- Perform Cancellation Batching
        MERGE INTO xxd_ont_bulk_orders_t xobot
             USING (SELECT ROWID, DENSE_RANK () OVER (ORDER BY bulk_header_id) bulk_batch_id
                      FROM xxd_ont_bulk_orders_t
                     WHERE     parent_request_id = p_parent_request_id
                           AND cancel_status = 'N'
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id)
                   xobot1
                ON (xobot.ROWID = xobot1.ROWID)
        WHEN MATCHED
        THEN
            UPDATE SET xobot.bulk_batch_id = xobot1.bulk_batch_id, xobot.request_id = gn_request_id;

        COMMIT;
        debug_msg ('Submit Bulk Order Cancel Programs');

        -- Submit Bulk Order Cancel Programs
        FOR i IN get_bulk_order_batches
        LOOP
            ln_bulk_count   := ln_bulk_count + 1;
            l_bulk_conc_request_tbl (ln_bulk_count)   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_BULK_ORDER_CANCEL',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => i.from_bulk_batch_id,
                    argument2     => i.to_bulk_batch_id,
                    argument3     => p_from_customer_batch_id,
                    argument4     => p_to_customer_batch_id,
                    argument5     => p_parent_request_id,
                    argument6     => p_debug);
            COMMIT;
        END LOOP;

        debug_msg ('Wait for all Bulk Order Cancel Programs');
        debug_msg (
               'Start Wait Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        -- Wait for all Bulk Order Cancel Programs
        FOR i IN 1 .. l_bulk_conc_request_tbl.COUNT
        LOOP
            LOOP
                lb_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_bulk_conc_request_tbl (i),
                        interval     => 10,
                        max_wait     => 60,
                        phase        => lc_phase,
                        status       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END LOOP;

        debug_msg (
               'End Wait Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('Perform Scheduling Batching');

        -- Perform Scheduling Batching
        MERGE INTO xxd_ont_bulk_orders_t xobot
             USING (SELECT ROWID, DENSE_RANK () OVER (ORDER BY calloff_header_id) calloff_batch_id
                      FROM xxd_ont_bulk_orders_t
                     WHERE     parent_request_id = p_parent_request_id
                           AND schedule_status = 'N'
                           AND cancel_status = 'S'
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id)
                   xobot1
                ON (xobot.ROWID = xobot1.ROWID)
        WHEN MATCHED
        THEN
            UPDATE SET xobot.calloff_batch_id = xobot1.calloff_batch_id, xobot.request_id = gn_request_id;

        COMMIT;

        -- Start changes for CCR0008440
        debug_msg ('Submit Calloff Order Split and Cancel Programs');

        -- Submit Calloff Order Split and Cancel Programs
        FOR i IN get_calloff_split_batches
        LOOP
            ln_split_count   := ln_split_count + 1;
            l_split_conc_request_tbl (ln_split_count)   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_CALLOFF_SPLIT',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => i.from_calloff_batch_id,
                    argument2     => i.to_calloff_batch_id,
                    argument3     => p_from_customer_batch_id,
                    argument4     => p_to_customer_batch_id,
                    argument5     => p_parent_request_id,
                    argument6     => p_debug);
            COMMIT;
        END LOOP;

        debug_msg ('Wait for all Calloff Order Split and Cancel Programs');
        debug_msg (
               'Start Wait Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        -- Wait for all Calloff Order Split and Cancel Programs
        FOR i IN 1 .. l_split_conc_request_tbl.COUNT
        LOOP
            LOOP
                lb_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_split_conc_request_tbl (i),
                        interval     => 10,
                        max_wait     => 60,
                        phase        => lc_phase,
                        status       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END LOOP;

        debug_msg (
               'End Wait Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        -- End changes for CCR0008440

        debug_msg ('Submit Calloff Order Schedule Programs');

        -- Submit Calloff Order Schedule Programs
        FOR i IN get_calloff_order_batches
        LOOP
            ln_calloff_count   := ln_calloff_count + 1;
            l_calloff_conc_request_tbl (ln_calloff_count)   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_CALLOFF_ORDER_SCHEDULE',
                    description   => NULL,
                    start_time    => NULL,
                    sub_request   => FALSE,
                    argument1     => i.from_calloff_batch_id,
                    argument2     => i.to_calloff_batch_id,
                    argument3     => p_from_customer_batch_id,
                    argument4     => p_to_customer_batch_id,
                    argument5     => p_parent_request_id,
                    argument6     => p_debug);
            COMMIT;
        END LOOP;

        debug_msg ('Wait for all Calloff Order Schedule Programs');
        debug_msg (
               'Start Wait Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        -- Wait for all Calloff Order Schedule Programs
        FOR i IN 1 .. l_calloff_conc_request_tbl.COUNT
        LOOP
            LOOP
                lb_req_status   :=
                    fnd_concurrent.wait_for_request (
                        request_id   => l_calloff_conc_request_tbl (i),
                        interval     => 10,
                        max_wait     => 60,
                        phase        => lc_phase,
                        status       => lc_status,
                        dev_phase    => lc_dev_phase,
                        dev_status   => lc_dev_status,
                        MESSAGE      => lc_message);
                EXIT WHEN    UPPER (lc_phase) = 'COMPLETED'
                          OR UPPER (lc_status) IN
                                 ('CANCELLED', 'ERROR', 'TERMINATED');
            END LOOP;
        END LOOP;

        debug_msg (
               'End Wait Time '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

        IF ln_bulk_count = 0 AND ln_calloff_count = 0
        THEN
            debug_msg ('No Data Found');
        END IF;


        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in CHILD_PRC = ' || SQLERRM);
    END child_prc;
END xxd_ont_calloff_process_pkg;
/
