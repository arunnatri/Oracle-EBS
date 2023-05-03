--
-- XXD_ONT_CALLOFF_ORDER_ADJ_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:59 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CALLOFF_ORDER_ADJ_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_ORDER_ADJ_PKG
    * Design       : This package will be used for processing Calloff Orders
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 21-Nov-2017  1.0        Viswanathan Pandian     Initial Version
    -- 24-Jun-2018  1.1        Viswanathan Pandian     CCR0007302 Bulk Order Redesign
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
    -- This procedure performs below activities for eligible order lines
    -- If a calloff order line's ordered qty/LAD got reduced/increased after a bulk order link
    -- 1. Unschedule Calloff Order Line
    -- 2. Create a new Bulk Order Line
    -- 3. Apply hold on Calloff Order Line
    -- 4. Mark all the already linked lines as DELINK
    -- ======================================================================================
    PROCEDURE calloff_order_line_change_prc (
        x_errbuf                OUT NOCOPY VARCHAR2,
        x_retcode               OUT NOCOPY VARCHAR2,
        p_org_id             IN            oe_order_headers_all.org_id%TYPE,
        p_line_change_type   IN            VARCHAR2)
    AS
        CURSOR get_calloff_orders_c IS
            -- Calloff Quantity Reduction Case
            SELECT ooha.order_number, oola.header_id, oola.line_id,
                   oola.ordered_quantity, oola.request_date, xobot.linked_qty linked_qty,
                   xobot.atp_qty atp_qty, (xobot.linked_qty + xobot.atp_qty) original_ord_qty, ((xobot.linked_qty + xobot.atp_qty) - oola.ordered_quantity) qty_reduced,
                   p_line_change_type line_change_type
              FROM oe_order_lines_all oola,
                   oe_order_headers_all ooha,
                   fnd_lookup_values flv,
                   (  SELECT xobot.calloff_header_id, xobot.calloff_line_id, SUM (linked_qty) linked_qty,
                             SUM (atp_qty) atp_qty
                        FROM xxd_ont_bulk_orders_t xobot, oe_order_headers_all ooha_bulk -- Added for CCR0007302
                       WHERE     xobot.org_id = p_org_id
                             AND xobot.bulk_header_id = ooha_bulk.header_id -- Added for CCR0007302
                             AND ooha_bulk.open_flag = 'Y' -- Added for CCR0007302
                             AND ((xobot.link_type = 'BULK_LINK' AND xobot.linked_qty > 0) OR (xobot.link_type = 'BULK_ATP' AND xobot.atp_qty > 0))
                             AND xobot.link_type IN ('BULK_LINK', 'BULK_ATP')
                    GROUP BY xobot.calloff_header_id, xobot.calloff_line_id)
                   xobot
             WHERE     ooha.header_id = oola.header_id
                   AND oola.global_attribute19 IS NOT NULL
                   AND oola.global_attribute19 = 'PROCESSED'
                   AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                   AND ooha.org_id = TO_NUMBER (flv.tag)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                   AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                   AND flv.lookup_type = 'XXD_ONT_BLK_CALLOFF_ORDER_TYPE'
                   AND ooha.org_id = p_org_id
                   AND p_line_change_type = 'Qty Reduction'
                   AND xobot.calloff_header_id = ooha.header_id
                   AND xobot.calloff_line_id = oola.line_id
                   -- Line Histroy table check not required; Custom Table check should be good enough
                   AND oola.ordered_quantity <
                       (xobot.linked_qty + xobot.atp_qty)
            UNION
            -- Calloff Quantity Increase Case
            SELECT ooha.order_number, oola.header_id, oola.line_id,
                   oola.ordered_quantity, oola.request_date, xobot.linked_qty linked_qty,
                   xobot.atp_qty atp_qty, (xobot.linked_qty + xobot.atp_qty) original_ord_qty, 0 qty_reduced,
                   p_line_change_type line_change_type
              FROM oe_order_lines_all oola,
                   oe_order_headers_all ooha,
                   fnd_lookup_values flv,
                   (  SELECT xobot.calloff_header_id, xobot.calloff_line_id, SUM (linked_qty) linked_qty,
                             SUM (atp_qty) atp_qty
                        FROM xxd_ont_bulk_orders_t xobot
                       WHERE     xobot.org_id = p_org_id
                             AND xobot.link_type IN ('BULK_LINK', 'BULK_ATP')
                             AND ((xobot.link_type = 'BULK_LINK' AND xobot.linked_qty > 0) OR (xobot.link_type = 'BULK_ATP' AND xobot.atp_qty > 0))
                    GROUP BY xobot.calloff_header_id, xobot.calloff_line_id)
                   xobot
             WHERE     ooha.header_id = oola.header_id
                   AND oola.global_attribute19 IS NOT NULL
                   AND oola.global_attribute19 = 'PROCESSED'
                   AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                   AND ooha.org_id = TO_NUMBER (flv.tag)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                   AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                   AND flv.lookup_type = 'XXD_ONT_BLK_CALLOFF_ORDER_TYPE'
                   AND ooha.org_id = p_org_id
                   AND p_line_change_type = 'Qty Increase'
                   AND xobot.calloff_header_id = ooha.header_id
                   AND xobot.calloff_line_id = oola.line_id
                   -- Line Histroy table check not required; Custom Table check should be good enough
                   AND oola.ordered_quantity >
                       (xobot.linked_qty + xobot.atp_qty)
            UNION
            -- Calloff Latest Acceptable Date Change Case
            SELECT ooha.order_number, oola.header_id, oola.line_id,
                   oola.ordered_quantity, oola.request_date, xobot.linked_qty linked_qty,
                   xobot.atp_qty atp_qty, (xobot.linked_qty + xobot.atp_qty) original_ord_qty, 0 qty_reduced,
                   p_line_change_type line_change_type
              FROM oe_order_lines_all oola,
                   oe_order_headers_all ooha,
                   fnd_lookup_values flv,
                   (  SELECT xobot.calloff_header_id, xobot.calloff_line_id, SUM (linked_qty) linked_qty,
                             SUM (atp_qty) atp_qty, MAX (calloff_latest_acceptable_date) calloff_latest_acceptable_date
                        FROM xxd_ont_bulk_orders_t xobot, oe_order_headers_all ooha_bulk -- Added for CCR0007302
                       WHERE     xobot.org_id = p_org_id
                             AND xobot.bulk_header_id = ooha_bulk.header_id -- Added for CCR0007302
                             AND ooha_bulk.open_flag = 'Y' -- Added for CCR0007302
                             AND xobot.link_type IN ('BULK_LINK', 'BULK_ATP')
                             AND ((xobot.link_type = 'BULK_LINK' AND xobot.linked_qty > 0) OR (xobot.link_type = 'BULK_ATP' AND xobot.atp_qty > 0))
                    GROUP BY xobot.calloff_header_id, xobot.calloff_line_id)
                   xobot
             WHERE     ooha.header_id = oola.header_id
                   AND oola.global_attribute19 IS NOT NULL
                   AND oola.global_attribute19 = 'PROCESSED'
                   AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                   AND ooha.org_id = TO_NUMBER (flv.tag)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                   AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                   AND flv.lookup_type = 'XXD_ONT_BLK_CALLOFF_ORDER_TYPE'
                   AND ooha.org_id = p_org_id
                   AND p_line_change_type = 'Latest Acceptable Date Change'
                   AND xobot.calloff_header_id = ooha.header_id
                   AND xobot.calloff_line_id = oola.line_id
                   -- Line Histroy table check not required; Custom Table check should be good enough
                   AND TRUNC (oola.latest_acceptable_date) <>
                       TRUNC (calloff_latest_acceptable_date)
            ORDER BY request_date;

        CURSOR get_bulk_orders_c (p_calloff_header_id IN oe_order_lines_all.header_id%TYPE, p_calloff_line_id oe_order_lines_all.line_id%TYPE)
        IS
              SELECT bulk_line_id, linked_qty
                FROM xxd_ont_bulk_orders_t
               WHERE     calloff_header_id = p_calloff_header_id
                     AND calloff_line_id = p_calloff_line_id
                     AND link_type = 'BULK_LINK'
                     AND linked_qty > 0
            ORDER BY bulk_id DESC;

        CURSOR get_hold_id_c IS
            SELECT TO_NUMBER (lookup_code)
              FROM oe_lookups
             WHERE     lookup_type = 'XXD_ONT_CALLOFF_ORDER_HOLDS'
                   AND meaning = 'REPROCESS'
                   AND enabled_flag = 'Y'
                   AND ((start_date_active IS NOT NULL AND start_date_active <= SYSDATE) OR (start_date_active IS NULL AND 1 = 1))
                   AND ((end_date_active IS NOT NULL AND end_date_active >= SYSDATE) OR (end_date_active IS NULL AND 1 = 1));

        CURSOR get_new_bulk_lines_c IS
            SELECT DISTINCT oola.line_id
              FROM oe_order_lines_all oola, oe_order_headers_all ooha, fnd_lookup_values flv
             WHERE     ooha.header_id = oola.header_id
                   AND ooha.org_id = p_org_id
                   AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                   AND ooha.org_id = TO_NUMBER (flv.tag)
                   AND flv.language = USERENV ('LANG')
                   AND flv.enabled_flag = 'Y'
                   AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                   AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                   AND flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                   AND TRUNC (oola.creation_date) = TRUNC (SYSDATE)
                   AND oola.request_id = gn_request_id;

        lc_sub_prog_name             VARCHAR2 (100) := 'PROCESS_CALLOFF_ORDER';
        l_hold_source_rec            oe_holds_pvt.hold_source_rec_type;
        l_bulk_header_rec            oe_order_pub.header_rec_type;
        l_bulk_line_rec              oe_order_pub.line_rec_type;
        l_line_tbl                   oe_order_pub.line_tbl_type;
        lx_line_tbl                  oe_order_pub.line_tbl_type;
        l_header_rec                 oe_order_pub.header_rec_type;
        l_action_request_tbl         oe_order_pub.request_tbl_type;
        ln_hold_id                   oe_hold_sources_all.hold_id%TYPE;
        ln_msg_count                 NUMBER := 0;
        ln_hold_msg_count            NUMBER := 0;
        ln_record_count              NUMBER := 0;
        ln_atp_adj_qty               NUMBER := 0;
        ln_remaining_adj_qty         NUMBER := 0;
        ln_msg_index_out             NUMBER;
        lc_hold_msg_data             VARCHAR2 (2000);
        lc_hold_return_status        VARCHAR2 (20);
        lc_api_return_status         VARCHAR2 (1);
        lc_bulk_line_create_status   VARCHAR2 (1);
        lc_delink_status             VARCHAR2 (1);
        lc_lock_status               VARCHAR2 (1);
        lc_status                    VARCHAR2 (1);
        lc_wf_status                 VARCHAR2 (1);
        lc_error_message             VARCHAR2 (4000);
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        lc_status   := xxd_ont_check_plan_run_fnc;

        IF lc_status = 'N'
        THEN
            xxd_ont_bulk_calloff_order_pkg.init ();

            FOR calloff_orders_rec IN get_calloff_orders_c
            LOOP
                -- Without Rollback Unscheduling always fails for the first order
                ROLLBACK;
                SAVEPOINT calloff_line;
                ln_record_count         := ln_record_count + 1;

                lc_lock_status          := NULL;
                lc_hold_return_status   := NULL;
                lc_delink_status        := NULL;
                lc_api_return_status    := NULL;
                lc_wf_status            := NULL;
                l_hold_source_rec       :=
                    oe_holds_pvt.g_miss_hold_source_rec;
                oe_msg_pub.initialize;

                IF calloff_orders_rec.line_change_type =
                   'Latest Acceptable Date Change'
                THEN
                    -- Lock Calloff Order Line
                    lc_lock_status   :=
                        xxd_ont_bulk_calloff_order_pkg.lock_order_line (
                            calloff_orders_rec.line_id);

                    IF lc_lock_status = 'Y'
                    THEN
                        debug_msg (
                            'Calloff Order Number = ' || calloff_orders_rec.order_number);
                        debug_msg ('Order Locked by another user. Skipping');
                        CONTINUE;
                    END IF;
                END IF;

                gc_delimiter            := '';
                debug_msg (RPAD ('=', 100, '='));
                debug_msg (
                    'Calloff Order Number = ' || calloff_orders_rec.order_number);
                debug_msg (
                    'Calloff Order Header ID = ' || calloff_orders_rec.header_id);
                debug_msg (
                    'Calloff Order Line ID = ' || calloff_orders_rec.line_id);
                debug_msg (
                    'Calloff Ordered Qty = ' || calloff_orders_rec.ordered_quantity);

                IF calloff_orders_rec.line_change_type =
                   'Latest Acceptable Date Change'
                THEN
                    gc_delimiter               := CHR (9);
                    debug_msg ('Unscheduling Calloff Order Line');
                    -- Unschedule Calloff Order Line
                    l_header_rec               := oe_order_pub.g_miss_header_rec;
                    l_line_tbl                 := oe_order_pub.g_miss_line_tbl;
                    l_action_request_tbl       := oe_order_pub.g_miss_request_tbl;

                    l_line_tbl (1)             := oe_order_pub.g_miss_line_rec;
                    l_line_tbl (1).header_id   :=
                        calloff_orders_rec.header_id;
                    l_line_tbl (1).org_id      := p_org_id;
                    l_line_tbl (1).line_id     := calloff_orders_rec.line_id;
                    l_line_tbl (1).schedule_action_code   :=
                        oe_order_sch_util.oesch_act_unschedule;
                    l_line_tbl (1).operation   :=
                        oe_globals.g_opr_update;
                    xxd_ont_bulk_calloff_order_pkg.process_order (
                        p_header_rec           => l_header_rec,
                        p_line_tbl             => l_line_tbl,
                        p_action_request_tbl   => l_action_request_tbl,
                        x_line_tbl             => lx_line_tbl,
                        x_return_status        => lc_api_return_status,
                        x_error_message        => lc_error_message);

                    debug_msg (
                        'Unscheduling Status = ' || lc_api_return_status);

                    IF lc_api_return_status <> 'S'
                    THEN
                        debug_msg ('Unable to unschedule Calloff Order Line');
                        debug_msg ('Error = ' || lc_error_message);
                        debug_msg ('ROLLBACK');
                        -- Retry next time
                        ROLLBACK TO calloff_line;
                        CONTINUE;
                    END IF;
                ELSE
                    -- Non LAD Cases continue as success
                    lc_api_return_status   := 'S';
                END IF;

                IF lc_api_return_status = 'S'
                THEN
                    debug_msg ('Proceed To Create New Bulk Order Lines');

                    IF calloff_orders_rec.line_change_type = 'Qty Reduction'
                    THEN
                        ln_atp_adj_qty   :=
                            CASE
                                WHEN   calloff_orders_rec.atp_qty
                                     - calloff_orders_rec.qty_reduced >
                                     0
                                THEN
                                      calloff_orders_rec.atp_qty
                                    - calloff_orders_rec.qty_reduced
                                ELSE
                                    0
                            END;

                        debug_msg (
                            'Original Ord Qty = ' || calloff_orders_rec.original_ord_qty);
                        debug_msg (
                            'Current Ord Qty = ' || calloff_orders_rec.ordered_quantity);
                        debug_msg (
                            'Qty Reduced = ' || calloff_orders_rec.qty_reduced);
                        debug_msg (
                               'ATP Qty = '
                            || NVL (calloff_orders_rec.atp_qty, 0));
                        debug_msg (
                               'New ATP Line''s Adjusted Qty = '
                            || ln_atp_adj_qty);

                        UPDATE xxd_ont_bulk_orders_t
                           SET atp_qty = ln_atp_adj_qty, varchar_attribute1 = calloff_orders_rec.line_change_type, request_id = gn_request_id,
                               last_update_date = SYSDATE, last_updated_by = gn_user_id, last_update_login = gn_login_id
                         WHERE     calloff_header_id =
                                   calloff_orders_rec.header_id
                               AND calloff_line_id =
                                   calloff_orders_rec.line_id
                               AND link_type = 'BULK_ATP';

                        ln_remaining_adj_qty   :=
                              calloff_orders_rec.original_ord_qty
                            - calloff_orders_rec.ordered_quantity
                            - calloff_orders_rec.atp_qty;
                        debug_msg (
                            'Remaining Adj Qty  = ' || ln_remaining_adj_qty);
                    END IF;

                    IF    ln_remaining_adj_qty > 0
                       OR calloff_orders_rec.line_change_type =
                          'Latest Acceptable Date Change'
                    THEN
                        FOR bulk_orders_rec
                            IN get_bulk_orders_c (
                                   calloff_orders_rec.header_id,
                                   calloff_orders_rec.line_id)
                        LOOP
                            IF     ln_remaining_adj_qty = 0
                               AND calloff_orders_rec.line_change_type =
                                   'Qty Reduction'
                            THEN
                                debug_msg (
                                    'All Bulk Adjustments are completed. Exiting!');
                                EXIT;
                            END IF;

                            gc_delimiter           := CHR (9) || CHR (9);
                            debug_msg (RPAD ('-', 84, '-'));
                            lc_api_return_status   := NULL;

                            -- Get Original Bulk Line
                            oe_line_util.query_row (
                                p_line_id    => bulk_orders_rec.bulk_line_id,
                                x_line_rec   => l_bulk_line_rec);

                            -- Get Original Bulk Order
                            oe_header_util.query_row (
                                p_header_id    => l_bulk_line_rec.header_id,
                                x_header_rec   => l_bulk_header_rec);

                            debug_msg (
                                   'Original Bulk Order Number = '
                                || l_bulk_header_rec.order_number);

                            debug_msg (
                                   'Bulk Order Open Flag = '
                                || l_bulk_header_rec.open_flag);

                            -- Verify if Original Bulk Order is open
                            IF l_bulk_header_rec.open_flag = 'Y'
                            THEN
                                debug_msg (
                                    'Original Bulk Order is open. Creating new line in that order.');

                                oe_globals.g_price_flag                  := 'N'; -- Added for CCR0007302

                                -- Header
                                l_header_rec                             :=
                                    oe_order_pub.g_miss_header_rec;
                                l_line_tbl                               :=
                                    oe_order_pub.g_miss_line_tbl;
                                l_header_rec.header_id                   :=
                                    l_bulk_header_rec.header_id;
                                l_header_rec.org_id                      :=
                                    l_bulk_header_rec.org_id;
                                l_header_rec.operation                   :=
                                    oe_globals.g_opr_update;

                                -- Lines
                                l_line_tbl (1).header_id                 :=
                                    l_bulk_line_rec.header_id;
                                l_line_tbl (1)                           :=
                                    oe_order_pub.g_miss_line_rec;
                                l_line_tbl (1).operation                 :=
                                    oe_globals.g_opr_create;

                                IF calloff_orders_rec.line_change_type =
                                   'Qty Reduction'
                                THEN
                                    IF bulk_orders_rec.linked_qty >=
                                       ln_remaining_adj_qty
                                    THEN
                                        l_line_tbl (1).ordered_quantity   :=
                                            ln_remaining_adj_qty;
                                    ELSE
                                        l_line_tbl (1).ordered_quantity   :=
                                            bulk_orders_rec.linked_qty;
                                    END IF;

                                    ln_remaining_adj_qty   :=
                                          ln_remaining_adj_qty
                                        - l_line_tbl (1).ordered_quantity;
                                    debug_msg (
                                           'Current Bulk Ord Qty  = '
                                        || l_line_tbl (1).ordered_quantity);
                                    debug_msg (
                                           'Remaining Adj Qty  = '
                                        || ln_remaining_adj_qty);
                                ELSE
                                    l_line_tbl (1).ordered_quantity   :=
                                        bulk_orders_rec.linked_qty;
                                END IF;

                                l_line_tbl (1).line_type_id              :=
                                    l_bulk_line_rec.line_type_id;
                                l_line_tbl (1).cust_po_number            :=
                                    l_bulk_line_rec.cust_po_number;
                                l_line_tbl (1).inventory_item_id         :=
                                    l_bulk_line_rec.inventory_item_id;
                                l_line_tbl (1).ship_from_org_id          :=
                                    l_bulk_line_rec.ship_from_org_id;
                                l_line_tbl (1).demand_class_code         :=
                                    l_bulk_line_rec.demand_class_code;
                                l_line_tbl (1).unit_list_price           :=
                                    l_bulk_line_rec.unit_list_price;
                                l_line_tbl (1).invoice_to_org_id         :=
                                    l_bulk_line_rec.invoice_to_org_id;
                                l_line_tbl (1).ship_to_org_id            :=
                                    l_bulk_line_rec.ship_to_org_id;
                                l_line_tbl (1).salesrep_id               :=
                                    l_bulk_line_rec.salesrep_id;
                                l_line_tbl (1).price_list_id             :=
                                    l_bulk_line_rec.price_list_id;
                                l_line_tbl (1).order_source_id           :=
                                    l_bulk_line_rec.order_source_id;
                                l_line_tbl (1).payment_term_id           :=
                                    l_bulk_line_rec.payment_term_id;
                                l_line_tbl (1).shipping_method_code      :=
                                    l_bulk_line_rec.shipping_method_code;
                                l_line_tbl (1).freight_terms_code        :=
                                    l_bulk_line_rec.freight_terms_code;
                                l_line_tbl (1).request_date              :=
                                    l_bulk_line_rec.request_date;
                                l_line_tbl (1).shipping_instructions     :=
                                    l_bulk_line_rec.shipping_instructions;
                                l_line_tbl (1).packing_instructions      :=
                                    l_bulk_line_rec.packing_instructions;
                                l_line_tbl (1).request_id                :=
                                    gn_request_id;
                                l_line_tbl (1).attribute1                :=
                                    l_bulk_line_rec.attribute1;
                                l_line_tbl (1).attribute6                :=
                                    l_bulk_line_rec.attribute6;
                                l_line_tbl (1).attribute7                :=
                                    l_bulk_line_rec.attribute7;
                                l_line_tbl (1).attribute8                :=
                                    l_bulk_line_rec.attribute8;
                                l_line_tbl (1).attribute10               :=
                                    l_bulk_line_rec.attribute10;
                                l_line_tbl (1).attribute13               :=
                                    l_bulk_line_rec.attribute13;
                                l_line_tbl (1).attribute14               :=
                                    l_bulk_line_rec.attribute14;
                                l_line_tbl (1).attribute15               :=
                                    l_bulk_line_rec.attribute15;
                                l_line_tbl (1).deliver_to_org_id         :=
                                    l_bulk_line_rec.deliver_to_org_id;
                                l_line_tbl (1).latest_acceptable_date    :=
                                    l_bulk_line_rec.latest_acceptable_date;
                                l_line_tbl (1).source_document_type_id   := 2; -- 2 for "Copy"
                                l_line_tbl (1).source_document_id        :=
                                    l_bulk_line_rec.header_id;
                                l_line_tbl (1).source_document_line_id   :=
                                    l_bulk_line_rec.line_id;

                                -- Call Procees_Order to crate Bulk Order Line
                                xxd_ont_bulk_calloff_order_pkg.process_order (
                                    p_header_rec      => l_header_rec,
                                    p_line_tbl        => l_line_tbl,
                                    p_action_request_tbl   =>
                                        l_action_request_tbl,
                                    x_line_tbl        => lx_line_tbl,
                                    x_return_status   => lc_api_return_status,
                                    x_error_message   => lc_error_message);

                                IF lc_api_return_status = 'S'
                                THEN
                                    debug_msg (
                                           'Bulk Order Number = '
                                        || l_bulk_header_rec.order_number);
                                    debug_msg (
                                           'Bulk Header ID = '
                                        || l_bulk_header_rec.header_id);
                                    debug_msg (
                                           'Created New Bulk Order Line. Line ID = '
                                        || lx_line_tbl (1).line_id);
                                    lc_bulk_line_create_status   := 'S';

                                    IF calloff_orders_rec.line_change_type =
                                       'Qty Reduction'
                                    THEN
                                        UPDATE xxd_ont_bulk_orders_t
                                           SET linked_qty = linked_qty - l_line_tbl (1).ordered_quantity, varchar_attribute1 = calloff_orders_rec.line_change_type, request_id = gn_request_id,
                                               last_update_date = SYSDATE, last_updated_by = gn_user_id, last_update_login = gn_login_id
                                         WHERE     calloff_header_id =
                                                   calloff_orders_rec.header_id
                                               AND calloff_line_id =
                                                   calloff_orders_rec.line_id
                                               AND bulk_line_id =
                                                   l_bulk_line_rec.line_id
                                               AND link_type = 'BULK_LINK';
                                    END IF;
                                ELSE
                                    lc_bulk_line_create_status   := 'E';
                                    -- Even if any one Bulk Line creation fails, retry next time
                                    EXIT;
                                END IF;
                            ELSE
                                debug_msg (
                                    'Bulk Order is Closed. Nothing to be created');
                                -- If Bulk Order is closed, make it as success always
                                lc_bulk_line_create_status   := 'S';
                            END IF;
                        END LOOP;
                    ELSE
                        debug_msg ('No changes needed in Bulk Lines');
                        -- No changes needed in Bulk, make it as success always
                        lc_bulk_line_create_status   := 'S';
                    END IF;
                END IF;

                debug_msg (RPAD ('-', 84, '-'));
                gc_delimiter            := CHR (9);

                debug_msg (
                       'Bulk Line(s) Creation Status = '
                    || lc_bulk_line_create_status);

                IF     lc_bulk_line_create_status = 'S'
                   AND calloff_orders_rec.line_change_type = 'Qty Reduction'
                THEN
                    UPDATE xxd_ont_bulk_orders_t
                       SET new_calloff_ordered_quantity = calloff_orders_rec.ordered_quantity, request_id = gn_request_id, last_update_date = SYSDATE,
                           last_updated_by = gn_user_id, last_update_login = gn_login_id
                     WHERE     calloff_header_id =
                               calloff_orders_rec.header_id
                           AND calloff_line_id = calloff_orders_rec.line_id
                           AND link_type IN ('BULK_LINK', 'BULK_ATP');

                    debug_msg ('All done. Committing');
                    COMMIT;
                    lc_wf_status   := 'S';
                END IF;

                IF     lc_bulk_line_create_status = 'S'
                   AND calloff_orders_rec.line_change_type =
                       'Latest Acceptable Date Change'
                THEN
                    OPEN get_hold_id_c;

                    FETCH get_hold_id_c INTO ln_hold_id;

                    CLOSE get_hold_id_c;

                    debug_msg ('Apply Hold on Calloff Order Line');
                    -- Apply Calloff Order Line Hold
                    l_hold_source_rec.hold_id            := ln_hold_id;
                    l_hold_source_rec.hold_entity_code   := 'O';
                    l_hold_source_rec.hold_entity_id     :=
                        calloff_orders_rec.header_id;
                    l_hold_source_rec.line_id            :=
                        calloff_orders_rec.line_id;
                    l_hold_source_rec.hold_comment       :=
                        'Applying processing hold on Bulk Calloff Order';
                    oe_holds_pub.apply_holds (
                        p_api_version        => 1.0,
                        p_validation_level   => fnd_api.g_valid_level_full,
                        p_hold_source_rec    => l_hold_source_rec,
                        x_msg_count          => ln_hold_msg_count,
                        x_msg_data           => lc_hold_msg_data,
                        x_return_status      => lc_hold_return_status);
                    debug_msg (
                        'Apply Hold Status = ' || lc_hold_return_status);

                    IF lc_hold_return_status = 'S'
                    THEN
                        lc_delink_status   := 'S';
                    ELSE
                        FOR i IN 1 .. oe_msg_pub.count_msg
                        LOOP
                            oe_msg_pub.get (
                                p_msg_index       => i,
                                p_encoded         => fnd_api.g_false,
                                p_data            => lc_hold_msg_data,
                                p_msg_index_out   => ln_msg_index_out);
                            lc_error_message   :=
                                lc_error_message || lc_hold_msg_data;
                        END LOOP;

                        debug_msg ('Hold API Error = ' || lc_error_message);
                        ROLLBACK TO calloff_line;
                        -- If unable to apply hold, skip and continue
                        CONTINUE;
                    END IF;
                ELSIF     lc_bulk_line_create_status <> 'S'
                      AND calloff_orders_rec.ordered_quantity > 0
                THEN
                    debug_msg (
                        'One or more Bulk Order Lines creation failed. Rollback!');
                    lc_delink_status   := 'E';
                    ROLLBACK TO calloff_line;
                    CONTINUE;
                ELSIF     lc_bulk_line_create_status = 'S'
                      AND calloff_orders_rec.ordered_quantity = 0
                THEN
                    debug_msg (
                        'Since Calloff Line fully cancelled, no changes needed!');
                    lc_delink_status   := 'S';
                END IF;

                gc_delimiter            := '';

                IF     lc_delink_status = 'S'
                   AND calloff_orders_rec.line_change_type =
                       'Latest Acceptable Date Change'
                THEN
                    debug_msg ('Try Delink');

                    -- Mark delink
                    UPDATE xxd_ont_bulk_orders_t
                       SET link_type = 'BULK_DELINK', varchar_attribute1 = calloff_orders_rec.line_change_type, request_id = gn_request_id,
                           last_update_date = SYSDATE, last_updated_by = gn_user_id, last_update_login = gn_login_id
                     WHERE     calloff_header_id =
                               calloff_orders_rec.header_id
                           AND calloff_line_id = calloff_orders_rec.line_id
                           AND link_type IN ('BULK_LINK', 'BULK_ATP');

                    debug_msg (
                           'Delinked Bulk Order Line (s) and Free ATP Line Count = '
                        || SQL%ROWCOUNT);

                    IF calloff_orders_rec.ordered_quantity > 0
                    THEN
                        -- Mark Calloff Order Line as REPROCESS
                        UPDATE oe_order_lines_all
                           SET global_attribute19 = 'REPROCESS', global_attribute20 = NULL
                         WHERE line_id = calloff_orders_rec.line_id;

                        debug_msg (
                               'Reset Status in Calloff Order Line as REPROCESS. Line Count = '
                            || SQL%ROWCOUNT);
                    END IF;

                    debug_msg ('All done. Committing');
                    COMMIT;
                    lc_wf_status   := 'S';
                END IF;
            END LOOP;

            IF lc_wf_status = 'S'
            THEN
                -- Schedule the newly created Bulk Order Line(s)
                FOR new_bulk_lines_rec IN get_new_bulk_lines_c
                LOOP
                    BEGIN
                        debug_msg (
                               'Schedule the newly created Bulk Order Line ID = '
                            || new_bulk_lines_rec.line_id);
                        wf_engine.completeactivity (itemtype => 'OEOL', itemkey => TO_CHAR (new_bulk_lines_rec.line_id), activity => 'SCHEDULING_ELIGIBLE'
                                                    , result => NULL);
                        debug_msg ('WF Progress Success');
                        COMMIT;
                    EXCEPTION
                        WHEN OTHERS
                        THEN
                            NULL;
                    END;
                END LOOP;
            END IF;

            IF ln_record_count = 0
            THEN
                debug_msg ('No Data Found');
            ELSE
                gc_delimiter   := '';
                debug_msg (RPAD ('=', 100, '='));
            END IF;
        ELSE
            x_errbuf    :=
                'Planning Programs are running in ASCP. Calloff-Bulk Linking Program cannot run now!!!';
            debug_msg (x_errbuf);
            x_retcode   := 1;
        END IF;

        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            x_retcode   := 2;
            x_errbuf    :=
                   'Others Exception in CALLOFF_ORDER_LINE_CHANGE_PRC = '
                || SQLERRM;
            debug_msg (x_errbuf);
            debug_msg ('End ' || lc_sub_prog_name);
            ROLLBACK;
    END calloff_order_line_change_prc;
END xxd_ont_calloff_order_adj_pkg;
/
