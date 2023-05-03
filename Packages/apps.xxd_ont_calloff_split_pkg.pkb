--
-- XXD_ONT_CALLOFF_SPLIT_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:56 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CALLOFF_SPLIT_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_SPLIT_PKG
    * Design       : This package will be used for Calloff Order Split and Cancellation when
    *                there is no bulk to consume
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 25-Mar-2020  1.0        Viswanathan Pandian     Initial Version
    ******************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    gn_org_id         NUMBER := fnd_global.org_id;
    gn_user_id        NUMBER := fnd_global.user_id;
    gn_login_id       NUMBER := fnd_global.login_id;
    gn_request_id     NUMBER := fnd_global.conc_request_id;
    gc_delimiter      VARCHAR2 (100);
    gc_debug_enable   VARCHAR2 (1);

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
    -- This procedure performs below activities for eligible order lines
    -- Reduce the unconsumed units in the original line and create a split line
    -- ======================================================================================
    PROCEDURE split_prc (p_from_calloff_batch_id    IN NUMBER,
                         p_to_calloff_batch_id      IN NUMBER,
                         p_from_customer_batch_id   IN NUMBER,
                         p_to_customer_batch_id     IN NUMBER,
                         p_parent_request_id        IN NUMBER)
    AS
        CURSOR get_calloff_headers_c IS
            SELECT DISTINCT calloff_order_number, calloff_header_id, org_id
              FROM xxd_ont_bulk_orders_t
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y'         -- Cancel No Bulk Line
                   AND number_attribute1 > 0;                     -- Split Qty

        CURSOR get_calloff_lines_c (
            p_header_id IN oe_order_lines_all.header_id%TYPE)
        IS
            SELECT DISTINCT oola.line_id calloff_line_id, oola.ordered_quantity calloff_ordered_quantity, xobot.number_attribute1 split_qty
              FROM xxd_ont_bulk_orders_t xobot, oe_order_lines_all oola
             WHERE     xobot.calloff_header_id = oola.header_id
                   AND oola.line_id = xobot.calloff_line_id
                   AND xobot.calloff_header_id = p_header_id
                   AND xobot.parent_request_id = p_parent_request_id
                   AND xobot.cancel_status = 'S'
                   AND xobot.calloff_batch_id >= p_from_calloff_batch_id
                   AND xobot.calloff_batch_id <= p_to_calloff_batch_id
                   AND xobot.customer_batch_id >= p_from_customer_batch_id
                   AND xobot.customer_batch_id <= p_to_customer_batch_id
                   AND xobot.varchar_attribute2 = 'Y'
                   AND xobot.number_attribute1 > 0;

        lc_sub_prog_name       VARCHAR2 (100) := 'SPLIT_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
        ln_line_tbl_count      NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        lx_lock_line_tbl       oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        gc_delimiter   := CHR (9) || CHR (9) || CHR (9) || CHR (9);

        FOR calloff_headers_rec IN get_calloff_headers_c
        LOOP
            lc_api_return_status   := NULL;
            lc_error_message       := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            ln_line_tbl_count      := 0;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Calloff Order Number '
                || calloff_headers_rec.calloff_order_number
                || '. Header ID '
                || calloff_headers_rec.calloff_header_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

            l_header_rec           := oe_order_pub.g_miss_header_rec;
            l_line_tbl             := oe_order_pub.g_miss_line_tbl;

            oe_line_util.lock_rows (
                p_header_id       => calloff_headers_rec.calloff_header_id,
                x_line_tbl        => lx_lock_line_tbl,
                x_return_status   => lc_lock_status);

            IF lc_lock_status <> 'S'
            THEN
                lc_error_message       :=
                    'One or more line is locked by another user';
                debug_msg (lc_error_message);
                lc_lock_status         := 'E';
                lc_api_return_status   := 'E';
            ELSE
                FOR calloff_lines_rec
                    IN get_calloff_lines_c (
                           calloff_headers_rec.calloff_header_id)
                LOOP
                    ln_line_tbl_count   := ln_line_tbl_count + 1;
                    l_line_tbl (ln_line_tbl_count)   :=
                        oe_order_pub.g_miss_line_rec;
                    -- Original Line Changes
                    l_line_tbl (ln_line_tbl_count).header_id   :=
                        calloff_headers_rec.calloff_header_id;
                    l_line_tbl (ln_line_tbl_count).org_id   :=
                        calloff_headers_rec.org_id;
                    l_line_tbl (ln_line_tbl_count).line_id   :=
                        calloff_lines_rec.calloff_line_id;
                    l_line_tbl (ln_line_tbl_count).split_action_code   :=
                        'SPLIT';
                    -- Pass User Id to "Split_By" instead of value "USER" to Original Line. Oracle Doc ID 2156475.1
                    l_line_tbl (ln_line_tbl_count).split_by   :=
                        gn_user_id;
                    l_line_tbl (ln_line_tbl_count).ordered_quantity   :=
                          calloff_lines_rec.calloff_ordered_quantity
                        - calloff_lines_rec.split_qty;
                    l_line_tbl (ln_line_tbl_count).operation   :=
                        oe_globals.g_opr_update;

                    -- Split Line
                    ln_line_tbl_count   :=
                        ln_line_tbl_count + 1;
                    l_line_tbl (ln_line_tbl_count)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_tbl_count).header_id   :=
                        calloff_headers_rec.calloff_header_id;
                    l_line_tbl (ln_line_tbl_count).org_id   :=
                        calloff_headers_rec.org_id;
                    l_line_tbl (ln_line_tbl_count).split_action_code   :=
                        'SPLIT';
                    -- Pass constant value "USER" to "Split_By" to Split Line. Oracle Doc ID 2156475.1
                    l_line_tbl (ln_line_tbl_count).split_by   :=
                        'USER';
                    l_line_tbl (ln_line_tbl_count).split_from_line_id   :=
                        calloff_lines_rec.calloff_line_id;
                    l_line_tbl (ln_line_tbl_count).ordered_quantity   :=
                        calloff_lines_rec.split_qty;
                    l_line_tbl (ln_line_tbl_count).request_id   :=
                        gn_request_id;
                    l_line_tbl (ln_line_tbl_count).operation   :=
                        oe_globals.g_opr_create;
                END LOOP;

                -- Call Process Order to create/update lines
                xxd_ont_calloff_process_pkg.process_order (
                    p_header_rec           => l_header_rec,
                    p_line_tbl             => l_line_tbl,
                    p_action_request_tbl   => l_action_request_tbl,
                    x_line_tbl             => lx_line_tbl,
                    x_return_status        => lc_api_return_status,
                    x_error_message        => lc_error_message);

                debug_msg ('Calloff Split Status = ' || lc_api_return_status);
                debug_msg ('Calloff Split Error = ' || lc_error_message);
            END IF;

            UPDATE xxd_ont_bulk_orders_t
               SET varchar_attribute3 = lc_api_return_status, error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     calloff_header_id =
                       calloff_headers_rec.calloff_header_id
                   AND parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y'
                   AND number_attribute1 > 0;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg ('Updated Status in Custom Table');
            debug_msg (RPAD ('=', 100, '='));
        END LOOP;

        COMMIT;

        gc_delimiter   := '';
        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_bulk_orders_t
               SET varchar_attribute3 = 'E', error_message = lc_error_message, request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y'
                   AND number_attribute1 > 0;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in SPLIT_PRC = ' || lc_error_message);
    END split_prc;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- Cancels unconsumed lines including the split lines created before in SPLIT_PRC
    -- ======================================================================================
    PROCEDURE cancel_prc (p_from_calloff_batch_id    IN NUMBER,
                          p_to_calloff_batch_id      IN NUMBER,
                          p_from_customer_batch_id   IN NUMBER,
                          p_to_customer_batch_id     IN NUMBER,
                          p_parent_request_id        IN NUMBER)
    AS
        CURSOR get_calloff_headers_c IS
            SELECT DISTINCT calloff_order_number, calloff_header_id, org_id
              FROM xxd_ont_bulk_orders_t
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y'         -- Cancel No Bulk Line
            UNION
            -- Select order lines that got created without bulk
            SELECT order_number calloff_order_number, header_id calloff_header_id, org_id
              FROM oe_order_headers_all ooha, fnd_lookup_values flv_calloff, fnd_lookup_values flv_free_atp
             WHERE     ooha.org_id = gn_org_id
                   AND ooha.open_flag = 'Y'
                   AND ooha.booked_flag = 'Y'
                   -- Select only in the first child
                   AND p_from_calloff_batch_id = 1
                   AND p_from_customer_batch_id = 1
                   -- 'No Bulk' Calloff Lines
                   AND EXISTS
                           (SELECT 1
                              FROM oe_order_lines_all oola
                             WHERE     oola.header_id = ooha.header_id
                                   AND oola.open_flag = 'Y'
                                   AND TRUNC (oola.creation_date) >=
                                       TRUNC (SYSDATE - 4)
                                   AND NOT EXISTS
                                           (SELECT 1
                                              FROM mtl_reservations mr
                                             WHERE mr.demand_source_line_id =
                                                   oola.line_id))
                   -- Calloff Order Type List
                   AND ooha.order_type_id =
                       TO_NUMBER (flv_calloff.lookup_code)
                   AND ooha.org_id = TO_NUMBER (flv_calloff.tag)
                   AND flv_calloff.language = USERENV ('LANG')
                   AND flv_calloff.enabled_flag = 'Y'
                   AND ((flv_calloff.start_date_active IS NOT NULL AND flv_calloff.start_date_active <= SYSDATE) OR (flv_calloff.start_date_active IS NULL AND 1 = 1))
                   AND ((flv_calloff.end_date_active IS NOT NULL AND flv_calloff.end_date_active >= SYSDATE) OR (flv_calloff.end_date_active IS NULL AND 1 = 1))
                   AND flv_calloff.lookup_type =
                       'XXD_ONT_BLK_CALLOFF_ORDER_TYPE'
                   -- No Free ATP Customer List
                   AND TO_NUMBER (flv_free_atp.attribute1) = ooha.org_id
                   AND TO_NUMBER (flv_free_atp.attribute2) =
                       ooha.sold_to_org_id
                   AND flv_free_atp.attribute3 = 'Y'    -- Cancel No Bulk Line
                   AND ((flv_free_atp.attribute4 IS NOT NULL AND TO_NUMBER (flv_free_atp.attribute4) = ooha.order_type_id) OR (flv_free_atp.attribute4 IS NULL AND 1 = 1))
                   AND flv_free_atp.language = USERENV ('LANG')
                   AND flv_free_atp.enabled_flag = 'Y'
                   AND ((flv_free_atp.start_date_active IS NOT NULL AND flv_free_atp.start_date_active <= SYSDATE) OR (flv_free_atp.start_date_active IS NULL AND 1 = 1))
                   AND ((flv_free_atp.end_date_active IS NOT NULL AND flv_free_atp.end_date_active >= SYSDATE) OR (flv_free_atp.end_date_active IS NULL AND 1 = 1))
                   AND flv_free_atp.lookup_type =
                       'XXD_ONT_BULK_ACCT_NO_FREE_ATP';

        CURSOR get_calloff_lines_c (
            p_header_id IN oe_order_lines_all.header_id%TYPE)
        IS
            SELECT DISTINCT calloff_line_id
              FROM xxd_ont_bulk_orders_t
             WHERE     calloff_header_id = p_header_id
                   AND parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y'
                   AND link_type = 'BULK_DELINK'
            UNION
            -- Lines that got split by this program
            SELECT oola.line_id calloff_line_id
              FROM oe_order_lines_all oola
             WHERE     oola.org_id = gn_org_id
                   AND oola.header_id = p_header_id
                   AND oola.open_flag = 'Y'
                   AND oola.split_from_line_id IS NOT NULL
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id)
                   -- Consumption table should have a reference to the original line
                   AND EXISTS
                           (SELECT 1
                              FROM xxd_ont_bulk_orders_t xobot
                             WHERE     xobot.calloff_header_id =
                                       oola.header_id
                                   AND xobot.calloff_line_id =
                                       oola.split_from_line_id
                                   AND xobot.link_type = 'BULK_LINK'
                                   AND xobot.number_attribute1 > 0
                                   AND xobot.org_id = gn_org_id)
            UNION
            -- Lines that got created without any bulk
            SELECT oola.line_id calloff_line_id
              FROM oe_order_lines_all oola
             WHERE     oola.org_id = gn_org_id
                   AND oola.header_id = p_header_id
                   AND oola.open_flag = 'Y'
                   AND TRUNC (oola.creation_date) >= TRUNC (SYSDATE - 4)
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id)
                   -- Consumption table should NOT have a reference to the original line
                   AND NOT EXISTS
                           (SELECT 1
                              FROM xxd_ont_bulk_orders_t xobot
                             WHERE     xobot.calloff_header_id =
                                       oola.header_id
                                   AND xobot.calloff_line_id = oola.line_id
                                   AND xobot.link_type = 'BULK_LINK'
                                   AND xobot.org_id = gn_org_id);

        lc_sub_prog_name       VARCHAR2 (100) := 'CANCEL_PRC';
        lc_api_return_status   VARCHAR2 (1);
        lc_lock_status         VARCHAR2 (1);
        lc_status              VARCHAR2 (1);
        lc_row_id              VARCHAR2 (1000);
        lc_error_message       VARCHAR2 (4000);
        ln_record_count        NUMBER := 0;
        ln_line_tbl_count      NUMBER := 0;
        ln_commit_count        NUMBER := 0;
        l_header_rec           oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        lx_lock_line_tbl       oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
    BEGIN
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        gc_delimiter   := CHR (9) || CHR (9) || CHR (9) || CHR (9);

        /****************************************************************************************
        * Cancel Calloff section
        ****************************************************************************************/
        FOR calloff_headers_rec IN get_calloff_headers_c
        LOOP
            lc_api_return_status   := NULL;
            lc_error_message       := NULL;
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            ln_record_count        := ln_record_count + 1;
            ln_line_tbl_count      := 0;
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                   'Processing Calloff Order Number '
                || calloff_headers_rec.calloff_order_number
                || '. Header ID '
                || calloff_headers_rec.calloff_header_id);
            debug_msg (
                   'Start Time '
                || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));

            l_header_rec           := oe_order_pub.g_miss_header_rec;
            l_line_tbl             := oe_order_pub.g_miss_line_tbl;
            lc_lock_status         := 'S';

            oe_line_util.lock_rows (
                p_header_id       => calloff_headers_rec.calloff_header_id,
                x_line_tbl        => lx_lock_line_tbl,
                x_return_status   => lc_lock_status);

            IF lc_lock_status <> 'S'
            THEN
                lc_error_message       :=
                    'One or more line is locked by another user';
                debug_msg (lc_error_message);
                lc_lock_status         := 'E';
                lc_api_return_status   := 'E';
            ELSE
                -- Header
                l_header_rec.header_id   :=
                    calloff_headers_rec.calloff_header_id;
                l_header_rec.operation   := oe_globals.g_opr_update;

                FOR calloff_lines_rec
                    IN get_calloff_lines_c (
                           calloff_headers_rec.calloff_header_id)
                LOOP
                    debug_msg (
                        'Line ID ' || calloff_lines_rec.calloff_line_id);
                    lc_error_message                                  := NULL;
                    lc_api_return_status                              := NULL;
                    ln_line_tbl_count                                 := ln_line_tbl_count + 1;

                    -- Line
                    l_line_tbl (ln_line_tbl_count)                    :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_tbl_count).header_id          :=
                        calloff_headers_rec.calloff_header_id;
                    l_line_tbl (ln_line_tbl_count).org_id             :=
                        calloff_headers_rec.org_id;
                    l_line_tbl (ln_line_tbl_count).line_id            :=
                        calloff_lines_rec.calloff_line_id;
                    l_line_tbl (ln_line_tbl_count).ordered_quantity   := 0;
                    l_line_tbl (ln_line_tbl_count).cancelled_flag     := 'Y';
                    l_line_tbl (ln_line_tbl_count).change_reason      :=
                        'OM-ALLOC-CANCEL';
                    l_line_tbl (ln_line_tbl_count).change_comments    :=
                           'Line cancelled (Restricted Free ATP) on '
                        || SYSDATE
                        || ' by program request_id: '
                        || gn_request_id;
                    l_line_tbl (ln_line_tbl_count).request_id         :=
                        gn_request_id;
                    l_line_tbl (ln_line_tbl_count).operation          :=
                        oe_globals.g_opr_update;
                END LOOP;

                IF ln_line_tbl_count > 0
                THEN
                    xxd_ont_calloff_process_pkg.process_order (
                        p_header_rec           => l_header_rec,
                        p_line_tbl             => l_line_tbl,
                        p_action_request_tbl   => l_action_request_tbl,
                        x_line_tbl             => lx_line_tbl,
                        x_return_status        => lc_api_return_status,
                        x_error_message        => lc_error_message);
                    debug_msg (
                           'Calloff Cancellation Status = '
                        || lc_api_return_status);
                END IF;
            END IF;

            UPDATE xxd_ont_bulk_orders_t
               SET varchar_attribute4 = lc_api_return_status, error_message = SUBSTR (error_message || lc_error_message, 1, 2000), request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     calloff_header_id =
                       calloff_headers_rec.calloff_header_id
                   AND parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y';

            debug_msg ('Updated Status in Custom Table');
            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg (RPAD ('=', 100, '='));
        END LOOP;

        COMMIT;

        IF ln_record_count < 0
        THEN
            debug_msg ('No Data Found');
        END IF;

        gc_delimiter   := '';
        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_bulk_orders_t
               SET varchar_attribute4 = 'E', error_message = lc_error_message, request_id = gn_request_id,
                   last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y';

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CHILD_PRC = ' || lc_error_message);
    END cancel_prc;

    -- ======================================================================================
    -- This procedure performs below activities for eligible order lines
    -- If a Calloff Order Line is not completely fulfilled
    -- 1. Split the unconsumed units
    -- 2. Cancel the unconsumed units
    -- ======================================================================================
    PROCEDURE split_cancel_prc (
        x_errbuf                      OUT NOCOPY VARCHAR2,
        x_retcode                     OUT NOCOPY VARCHAR2,
        p_from_calloff_batch_id    IN            NUMBER,
        p_to_calloff_batch_id      IN            NUMBER,
        p_from_customer_batch_id   IN            NUMBER,
        p_to_customer_batch_id     IN            NUMBER,
        p_parent_request_id        IN            NUMBER,
        p_debug                    IN            VARCHAR2)
    AS
        lc_sub_prog_name   VARCHAR2 (100) := 'SPLIT_CANCEL_PRC';
        lc_error_message   VARCHAR2 (4000);
    BEGIN
        IF p_parent_request_id IS NOT NULL
        THEN
            -- Per Oracle Doc ID 1922152.1
            UPDATE fnd_concurrent_requests
               SET priority_request_id = p_parent_request_id, is_sub_request = 'Y'
             WHERE request_id = gn_request_id;
        END IF;

        gc_debug_enable   := NVL (p_debug, 'N');
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        xxd_ont_calloff_process_pkg.init ();
        fnd_profile.put ('MRP_ATP_CALC_SD', 'N');

        -- Call Split Process
        split_prc (p_from_calloff_batch_id, p_to_calloff_batch_id, p_from_customer_batch_id
                   , p_to_customer_batch_id, p_parent_request_id);

        -- Call Cancel Process
        cancel_prc (p_from_calloff_batch_id, p_to_calloff_batch_id, p_from_customer_batch_id
                    , p_to_customer_batch_id, p_parent_request_id);
        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_bulk_orders_t
               SET varchar_attribute3 = 'E', varchar_attribute4 = 'E', error_message = lc_error_message,
                   request_id = gn_request_id, last_update_date = SYSDATE, last_update_login = gn_login_id
             WHERE     parent_request_id = p_parent_request_id
                   AND cancel_status = 'S'
                   AND calloff_batch_id >= p_from_calloff_batch_id
                   AND calloff_batch_id <= p_to_calloff_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND varchar_attribute2 = 'Y';

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in SPLIT_CANCEL_PRC = ' || lc_error_message);
    END split_cancel_prc;
END xxd_ont_calloff_split_pkg;
/
