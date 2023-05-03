--
-- XXD_ONT_CALLOFF_ORD_CANCEL_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:58 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CALLOFF_ORD_CANCEL_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_ORD_CANCEL_PKG
    * Design       : This package will be used for processing Calloff Orders cancellations
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 03-Dec-2018  1.0        Viswanathan Pandian     Initial Version
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
    -- This procedure performs below activities for eligible order lines
    -- 1. Identify Calloff Cancellations and insert into custom table
    -- 2. Perform Customer Batching
    -- 3. Submit Child program for each customer
    -- ======================================================================================
    PROCEDURE master_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_org_id IN oe_order_headers_all.org_id%TYPE, p_cust_account_id IN oe_order_headers_all.sold_to_org_id%TYPE, p_cust_po_number IN oe_order_headers_all.cust_po_number%TYPE, p_order_number_from IN oe_order_headers_all.order_number%TYPE, p_order_number_to IN oe_order_headers_all.order_number%TYPE, p_ordered_date_from IN VARCHAR2, p_ordered_date_to IN VARCHAR2, p_request_date_from IN VARCHAR2, p_request_date_to IN VARCHAR2, p_order_source_id IN oe_order_headers_all.order_source_id%TYPE
                          , p_order_type_id IN oe_order_headers_all.order_type_id%TYPE, p_threads IN NUMBER, p_debug IN VARCHAR2)
    AS
        CURSOR get_batches IS
              SELECT bucket, MIN (customer_batch_id) from_customer_batch_id, MAX (customer_batch_id) to_customer_batch_id
                FROM (SELECT customer_batch_id, NTILE (p_threads) OVER (ORDER BY customer_batch_id) bucket
                        FROM (SELECT DISTINCT customer_batch_id
                                FROM xxd_ont_calloff_orders_t
                               WHERE parent_request_id = gn_request_id))
            GROUP BY bucket
            ORDER BY 1;

        TYPE conc_request_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_bulk_conc_request_tbl   conc_request_tbl;
        lb_req_status             BOOLEAN;

        ln_bulk_count             NUMBER := 0;
        ln_record_count           NUMBER := 0;
        ln_req_id                 NUMBER;
        lc_status                 VARCHAR2 (10);
        lc_phase                  VARCHAR2 (100);
        lc_dev_phase              VARCHAR2 (100);
        lc_dev_status             VARCHAR2 (100);
        lc_message                VARCHAR2 (4000);
        lc_error_message          VARCHAR2 (4000);
    BEGIN
        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_debug, 'N'));
        debug_msg ('Start MASTER_PRC');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('Delete records older than 90 days');

        DELETE xxd_ont_calloff_orders_t
         WHERE creation_date <= SYSDATE - 90 AND org_id = p_org_id;

        debug_msg ('Deleted Record Count = ' || SQL%ROWCOUNT);
        COMMIT;

        lc_status         := xxd_ont_check_plan_run_fnc;

        IF lc_status = 'N'
        THEN
            xxd_ont_bulk_calloff_order_pkg.init ();
            debug_msg (RPAD ('=', 100, '='));
            debug_msg ('Fetch Cancelled Calloff Lines');

            INSERT INTO xxd_ont_calloff_orders_t (calloff_id, org_id, calloff_header_id, calloff_order_number, calloff_sold_to_org_id, calloff_cust_po_number, calloff_request_date, calloff_order_brand, calloff_line_id, calloff_line_number, calloff_shipment_number, calloff_ordered_item, calloff_inventory_item_id, calloff_ordered_quantity, calloff_line_request_date, calloff_schedule_ship_date, calloff_latest_acceptable_date, calloff_line_demand_class_code, bulk_id, bulk_header_id, bulk_order_number, bulk_sold_to_org_id, bulk_cust_po_number, bulk_request_date, bulk_order_brand, bulk_line_id, bulk_line_number, bulk_shipment_number, bulk_ordered_item, bulk_inventory_item_id, bulk_ordered_quantity, bulk_line_request_date, bulk_schedule_ship_date, bulk_latest_acceptable_date, bulk_line_demand_class_code, original_linked_qty, calloff_reduced_qty, new_linked_qty, parent_request_id, request_id, customer_batch_id, bulk_batch_id, status, error_message, creation_date, created_by, last_update_date, last_updated_by
                                                  , last_update_login)
                SELECT /*+ parallel(4) */
                       xxdo.xxd_ont_calloff_orders_s.NEXTVAL, ooha.org_id, ooha.header_id calloff_header_id,
                       ooha.order_number calloff_order_number, ooha.sold_to_org_id calloff_sold_to_org_id, ooha.cust_po_number calloff_cust_po_number,
                       ooha.request_date calloff_request_date, ooha.attribute5 calloff_order_brand, oola.line_id calloff_line_id,
                       oola.line_number calloff_line_number, oola.shipment_number calloff_shipment_number, oola.ordered_item calloff_ordered_item,
                       oola.inventory_item_id calloff_inventory_item_id, oola.ordered_quantity calloff_ordered_quantity, oola.request_date calloff_line_request_date,
                       oola.schedule_ship_date calloff_schedule_ship_date, oola.latest_acceptable_date calloff_latest_acceptable_date, oola.demand_class_code calloff_line_demand_class_code,
                       xobot.bulk_id, xobot.bulk_header_id, xobot.bulk_order_number,
                       xobot.bulk_sold_to_org_id, xobot.bulk_cust_po_number, xobot.bulk_request_date,
                       xobot.bulk_order_brand, xobot.bulk_line_id, xobot.bulk_line_number,
                       xobot.bulk_shipment_number, xobot.bulk_ordered_item, xobot.bulk_inventory_item_id,
                       xobot.bulk_ordered_quantity, xobot.bulk_line_request_date, xobot.bulk_schedule_ship_date,
                       xobot.bulk_latest_acceptable_date, xobot.bulk_line_demand_class_code, DECODE (xobot.link_type,  'BULK_LINK', xobot.linked_qty,  'BULK_ATP', xobot.atp_qty) original_linked_qty,
                       0 calloff_reduced_qty, 0 new_linked_qty, gn_request_id,
                       gn_request_id, NULL, NULL,
                       'N', NULL, SYSDATE,
                       gn_user_id, SYSDATE, gn_user_id,
                       gn_login_id
                  FROM oe_order_lines_all oola,
                       oe_order_headers_all ooha,
                       fnd_lookup_values flv,
                       xxd_ont_bulk_orders_t xobot,
                       (  SELECT xobot1.calloff_header_id, xobot1.calloff_line_id, SUM (linked_qty + atp_qty) linked_qty
                            FROM xxd_ont_bulk_orders_t xobot1
                           WHERE     xobot1.org_id = p_org_id
                                 AND xobot1.link_type <> 'BULK_DELINK'
                        GROUP BY xobot1.calloff_header_id, xobot1.calloff_line_id)
                       cons_lines
                 WHERE     ooha.header_id = oola.header_id
                       AND flv.lookup_type = 'XXD_ONT_BLK_CALLOFF_ORDER_TYPE'
                       AND ooha.order_type_id = TO_NUMBER (flv.lookup_code)
                       AND ooha.org_id = TO_NUMBER (flv.tag)
                       AND flv.language = USERENV ('LANG')
                       AND flv.enabled_flag = 'Y'
                       AND ((flv.start_date_active IS NOT NULL AND flv.start_date_active <= SYSDATE) OR (flv.start_date_active IS NULL AND 1 = 1))
                       AND ((flv.end_date_active IS NOT NULL AND flv.end_date_active >= SYSDATE) OR (flv.end_date_active IS NULL AND 1 = 1))
                       AND ooha.creation_date >= ADD_MONTHS (SYSDATE, -12)
                       AND ooha.header_id = xobot.calloff_header_id
                       AND oola.line_id = xobot.calloff_line_id
                       AND cons_lines.calloff_header_id =
                           xobot.calloff_header_id
                       AND cons_lines.calloff_line_id = xobot.calloff_line_id
                       AND xobot.link_type <> 'BULK_DELINK'
                       AND cons_lines.linked_qty > 0
                       AND oola.ordered_quantity < cons_lines.linked_qty
                       AND ooha.org_id = p_org_id
                       AND ((p_cust_account_id IS NOT NULL AND ooha.sold_to_org_id = p_cust_account_id) OR (p_cust_account_id IS NULL AND 1 = 1))
                       AND ((p_cust_po_number IS NOT NULL AND ooha.cust_po_number = p_cust_po_number) OR (p_cust_po_number IS NULL AND 1 = 1))
                       AND ((p_order_number_from IS NOT NULL AND p_order_number_to IS NOT NULL AND ooha.order_number BETWEEN p_order_number_from AND p_order_number_to) OR (p_order_number_from IS NULL AND p_order_number_to IS NULL AND 1 = 1))
                       AND ((p_ordered_date_from IS NOT NULL AND p_ordered_date_to IS NOT NULL AND TRUNC (ooha.ordered_date) BETWEEN fnd_date.canonical_to_date (p_ordered_date_from) AND fnd_date.canonical_to_date (p_ordered_date_to)) OR ((p_ordered_date_from IS NULL OR p_ordered_date_to IS NULL) AND 1 = 1))
                       AND ((p_request_date_from IS NOT NULL AND p_request_date_to IS NOT NULL AND TRUNC (ooha.request_date) BETWEEN fnd_date.canonical_to_date (p_request_date_from) AND fnd_date.canonical_to_date (p_request_date_to)) OR ((p_request_date_from IS NULL OR p_request_date_to IS NULL) AND 1 = 1))
                       AND ((p_order_source_id IS NOT NULL AND ooha.order_source_id = p_order_source_id) OR (p_order_source_id IS NULL AND 1 = 1))
                       AND ((p_order_type_id IS NOT NULL AND ooha.order_type_id = p_order_type_id) OR (p_order_type_id IS NULL AND 1 = 1));

            COMMIT;

            SELECT COUNT (1)
              INTO ln_record_count
              FROM xxd_ont_calloff_orders_t
             WHERE parent_request_id = gn_request_id;

            IF ln_record_count = 0
            THEN
                fnd_file.put_line (fnd_file.LOG, 'No Data Found');
            ELSE
                debug_msg ('Total Calloff Line Count = ' || ln_record_count);
                debug_msg (
                       'End Fetch Time '
                    || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
                debug_msg ('Perform Customer Batching');

                -- Perform Customer Batching
                MERGE INTO xxd_ont_calloff_orders_t xocot
                     USING (SELECT ROWID, DENSE_RANK () OVER (ORDER BY calloff_sold_to_org_id) customer_batch_id
                              FROM xxd_ont_calloff_orders_t xocot1
                             WHERE parent_request_id = gn_request_id) xocot1
                        ON (xocot.ROWID = xocot1.ROWID)
                WHEN MATCHED
                THEN
                    UPDATE SET
                        xocot.customer_batch_id   = xocot1.customer_batch_id;

                COMMIT;

                -- Submit Child Programs
                FOR i IN get_batches
                LOOP
                    ln_bulk_count   := ln_bulk_count + 1;
                    l_bulk_conc_request_tbl (ln_bulk_count)   :=
                        fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_CALLOFF_CANCEL_CHILD', description => NULL, start_time => NULL, sub_request => FALSE, argument1 => i.from_customer_batch_id, argument2 => i.to_customer_batch_id, argument3 => gn_request_id, argument4 => p_threads
                                                    , argument5 => p_debug);
                    COMMIT;
                END LOOP;

                debug_msg ('Successfully Submitted Child Threads');

                debug_msg ('Wait for all Child Programs');
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
            END IF;

            debug_msg (RPAD ('=', 100, '='));
        ELSE
            x_errbuf    :=
                'Planning Programs are running in ASCP. Calloff Cancellation Program cannot run now!!!';
            debug_msg (x_errbuf);
            x_retcode   := 1;
        END IF;

        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End MASTER_PRC');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode          := 2;

            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_calloff_orders_t
               SET status = 'E', error_message = lc_error_message
             WHERE parent_request_id = gn_request_id;

            COMMIT;

            debug_msg ('End MASTER_PRC');
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC = ' || lc_error_message);
    END master_prc;

    -- ======================================================================================
    -- This procedure performs below activities for each customer batch
    -- 1. For each customer perform Bulk Order batching
    -- 2. Submit calloff cancel program for each bulk order
    -- ======================================================================================
    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_from_customer_batch_id IN NUMBER, p_to_customer_batch_id IN NUMBER, p_parent_request_id IN NUMBER, p_threads IN NUMBER
                         , p_debug IN VARCHAR2)
    AS
        CURSOR get_calloff_lines_c IS
              SELECT xocot.calloff_line_id,
                     (  SUM (xocot.original_linked_qty)
                      - (SELECT ordered_quantity
                           FROM oe_order_lines_all oola
                          WHERE oola.line_id = xocot.calloff_line_id)) calloff_reduced_qty
                FROM xxd_ont_calloff_orders_t xocot
               WHERE     xocot.parent_request_id = p_parent_request_id
                     AND xocot.status = 'N'
                     AND xocot.customer_batch_id >= p_from_customer_batch_id
                     AND xocot.customer_batch_id <= p_to_customer_batch_id
            GROUP BY xocot.calloff_line_id;

        CURSOR get_lines_c (p_line_id oe_order_lines_all.line_id%TYPE)
        IS
              SELECT *
                FROM xxd_ont_calloff_orders_t
               WHERE     parent_request_id = p_parent_request_id
                     AND status = 'N'
                     AND customer_batch_id >= p_from_customer_batch_id
                     AND customer_batch_id <= p_to_customer_batch_id
                     AND calloff_line_id = p_line_id
            ORDER BY bulk_id DESC;

        CURSOR get_bulk_order_batches IS
              SELECT bucket, MIN (bulk_batch_id) from_bulk_batch_id, MAX (bulk_batch_id) to_bulk_batch_id
                FROM (SELECT bulk_batch_id, NTILE (p_threads) OVER (ORDER BY bulk_batch_id) bucket
                        FROM (SELECT DISTINCT bulk_batch_id
                                FROM xxd_ont_calloff_orders_t
                               WHERE     parent_request_id =
                                         p_parent_request_id
                                     AND status = 'N'
                                     AND customer_batch_id >=
                                         p_from_customer_batch_id
                                     AND customer_batch_id <=
                                         p_to_customer_batch_id))
            GROUP BY bucket
            ORDER BY 1;

        TYPE conc_request_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_bulk_conc_request_tbl   conc_request_tbl;
        lb_req_status             BOOLEAN;
        lc_phase                  VARCHAR2 (100);
        lc_status                 VARCHAR2 (100);
        lc_dev_phase              VARCHAR2 (100);
        lc_dev_status             VARCHAR2 (100);
        lc_message                VARCHAR2 (4000);
        lc_error_message          VARCHAR2 (4000);
        lc_req_data               VARCHAR2 (10);
        ln_bulk_count             NUMBER := 0;
        ln_remaining_qty          NUMBER := 0;
        ln_new_linked_qty         NUMBER := 0;
    BEGIN
        -- Per Oracle Doc ID 1922152.1
        UPDATE fnd_concurrent_requests
           SET priority_request_id = p_parent_request_id, parent_request_id = p_parent_request_id, is_sub_request = 'Y'
         WHERE request_id = gn_request_id;

        gc_debug_enable   := NVL (gc_debug_enable, NVL (p_debug, 'N'));
        debug_msg ('Start CHILD_PRC');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        debug_msg ('Perform Cancellation Batching');

        -- Perform Cancellation Batching
        MERGE INTO xxd_ont_calloff_orders_t xocot
             USING (SELECT ROWID, DENSE_RANK () OVER (ORDER BY bulk_header_id) bulk_batch_id
                      FROM xxd_ont_calloff_orders_t xocot1
                     WHERE     parent_request_id = p_parent_request_id
                           AND status = 'N'
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id)
                   xocot1
                ON (xocot.ROWID = xocot1.ROWID)
        WHEN MATCHED
        THEN
            UPDATE SET xocot.bulk_batch_id = xocot1.bulk_batch_id, xocot.request_id = gn_request_id;

        COMMIT;
        debug_msg (
               'Cancellation Batching Completed at '
            || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('Start New Linked Qty Calculation');

        -- Calculate New Linked Qty
        FOR calloff_lines_rec IN get_calloff_lines_c
        LOOP
            debug_msg (RPAD ('=', 100, '='));
            debug_msg (
                'Processing Calloff Line ID ' || calloff_lines_rec.calloff_line_id);
            ln_remaining_qty    :=
                CASE
                    WHEN calloff_lines_rec.calloff_reduced_qty < 0 THEN 0
                    ELSE calloff_lines_rec.calloff_reduced_qty
                END;
            ln_new_linked_qty   := 0;

            FOR lines_rec IN get_lines_c (calloff_lines_rec.calloff_line_id)
            LOOP
                IF ln_remaining_qty <> 0
                THEN
                    debug_msg (
                        'Processing Bulk Line ID ' || lines_rec.bulk_line_id);
                    debug_msg ('Remaining Qty = ' || ln_remaining_qty);
                    debug_msg (
                        'Current Orig Linked Qty = ' || lines_rec.original_linked_qty);

                    IF ln_remaining_qty < lines_rec.original_linked_qty
                    THEN
                        ln_new_linked_qty   :=
                            lines_rec.original_linked_qty - ln_remaining_qty;
                    ELSE
                        ln_new_linked_qty   := 0;
                    END IF;

                    debug_msg ('New Linked Qty = ' || ln_new_linked_qty);

                    ln_remaining_qty   :=
                        ln_remaining_qty - lines_rec.original_linked_qty;
                    ln_remaining_qty   :=
                        CASE
                            WHEN ln_remaining_qty > 0 THEN ln_remaining_qty
                            ELSE 0
                        END;

                    UPDATE xxd_ont_calloff_orders_t
                       SET new_linked_qty   = ln_new_linked_qty,
                           status           =
                               -- Mark success for BULK_ATP lines
                                CASE
                                   WHEN bulk_header_id IS NULL THEN 'S'
                                   ELSE 'N'
                               END
                     WHERE     ((lines_rec.bulk_line_id IS NOT NULL AND bulk_line_id = lines_rec.bulk_line_id) OR (lines_rec.bulk_line_id IS NULL AND bulk_id = lines_rec.bulk_id))
                           AND calloff_line_id =
                               calloff_lines_rec.calloff_line_id
                           AND parent_request_id = p_parent_request_id
                           AND status = 'N'
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id;
                ELSE
                    debug_msg (
                        'Remaining Qty = 0; No changes needed for other Bulk Lines');

                    -- No changes needed for Bulk Lines
                    UPDATE xxd_ont_calloff_orders_t
                       SET status = 'S', new_linked_qty = lines_rec.original_linked_qty
                     WHERE     bulk_line_id = lines_rec.bulk_line_id
                           AND calloff_line_id =
                               calloff_lines_rec.calloff_line_id
                           AND parent_request_id = p_parent_request_id
                           AND status = 'N'
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id;
                END IF;
            END LOOP;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        COMMIT;
        debug_msg ('Submit Calloff Order Cancel Programs');

        -- Submit Bulk Order Cancel Programs
        FOR i IN get_bulk_order_batches
        LOOP
            ln_bulk_count   := ln_bulk_count + 1;
            l_bulk_conc_request_tbl (ln_bulk_count)   :=
                fnd_request.submit_request (
                    application   => 'XXDO',
                    program       => 'XXD_ONT_CALLOFF_CANCEL',
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

        -- Update Consumption Table
        MERGE INTO xxd_ont_bulk_orders_t xobot
             USING (SELECT bulk_id, new_linked_qty
                      FROM xxd_ont_calloff_orders_t
                     WHERE     parent_request_id = p_parent_request_id
                           AND status = 'S'
                           AND customer_batch_id >= p_from_customer_batch_id
                           AND customer_batch_id <= p_to_customer_batch_id)
                   xocot
                ON (xobot.bulk_id = xocot.bulk_id)
        WHEN MATCHED
        THEN
            UPDATE SET xobot.linked_qty = DECODE (xobot.link_type, 'BULK_LINK', xocot.new_linked_qty, 0), xobot.atp_qty = DECODE (xobot.link_type, 'BULK_ATP', xocot.new_linked_qty, 0), xobot.link_type = DECODE (xocot.new_linked_qty, 0, 'BULK_DELINK', xobot.link_type),
                       xobot.last_update_date = SYSDATE, xobot.last_updated_by = gn_user_id, xobot.request_id = gn_request_id;

        debug_msg ('End CHILD_PRC');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode          := 2;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_calloff_orders_t
               SET status = 'E', error_message = lc_error_message
             WHERE     parent_request_id = p_parent_request_id
                   AND status = 'N'
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

            COMMIT;
            debug_msg ('End CHILD_PRC');
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in CHILD_PRC = ' || SQLERRM);
    END child_prc;

    PROCEDURE calloff_order_cancel_prc (
        x_errbuf                      OUT NOCOPY VARCHAR2,
        x_retcode                     OUT NOCOPY VARCHAR2,
        p_from_bulk_batch_id       IN            NUMBER,
        p_to_bulk_batch_id         IN            NUMBER,
        p_from_customer_batch_id   IN            NUMBER,
        p_to_customer_batch_id     IN            NUMBER,
        p_parent_request_id        IN            NUMBER,
        p_debug                    IN            VARCHAR2)
    AS
        CURSOR get_orders_c IS
            SELECT DISTINCT bulk_header_id, bulk_order_number, org_id
              FROM xxd_ont_calloff_orders_t
             WHERE     status = 'N'
                   AND parent_request_id = p_parent_request_id
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

        CURSOR get_lines_c (p_header_id oe_order_headers_all.header_id%TYPE)
        IS
            SELECT *
              FROM xxd_ont_calloff_orders_t
             WHERE     status = 'N'
                   AND parent_request_id = p_parent_request_id
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id
                   AND bulk_header_id = p_header_id;

        l_bulk_line_rec        oe_order_pub.line_rec_type;
        l_header_rec           oe_order_pub.header_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        lx_line_tbl            oe_order_pub.line_tbl_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        l_x_header_rec         oe_order_pub.header_rec_type;
        ln_line_tbl_index      NUMBER := 0;
        lc_return_status       VARCHAR2 (1);
        lc_error_message       VARCHAR2 (4000);
    BEGIN
        -- Per Oracle Doc ID 1922152.1
        UPDATE fnd_concurrent_requests
           SET priority_request_id = p_parent_request_id, is_sub_request = 'Y'
         WHERE request_id = gn_request_id;

        gc_debug_enable   := NVL (p_debug, 'N');
        xxd_ont_calloff_process_pkg.init ();
        debug_msg ('Start CALLOFF_ORDER_CANCEL_PRC');
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));

        FOR lcu_orders_rec IN get_orders_c
        LOOP
            debug_msg (
                'Processing Bulk Order ' || lcu_orders_rec.bulk_order_number);
            debug_msg ('Validate Lock');

            oe_header_util.lock_row (
                x_return_status   => lc_return_status,
                p_x_header_rec    => l_x_header_rec,
                p_header_id       => lcu_orders_rec.bulk_header_id);
            debug_msg ('Lock Status = ' || lc_return_status);

            IF lc_return_status = 'S' AND l_x_header_rec.open_flag = 'Y'
            THEN
                -- Header
                l_header_rec             := oe_order_pub.g_miss_header_rec;
                l_line_tbl               := oe_order_pub.g_miss_line_tbl;
                l_header_rec.header_id   := lcu_orders_rec.bulk_header_id;
                l_header_rec.org_id      := lcu_orders_rec.org_id;
                l_header_rec.operation   := oe_globals.g_opr_update;
                ln_line_tbl_index        := 0;

                FOR lcu_lines_rec
                    IN get_lines_c (lcu_orders_rec.bulk_header_id)
                LOOP
                    -- Get Original Bulk Line
                    oe_line_util.query_row (
                        p_line_id    => lcu_lines_rec.bulk_line_id,
                        x_line_rec   => l_bulk_line_rec);
                    ln_line_tbl_index   := ln_line_tbl_index + 1;
                    -- Lines
                    l_line_tbl (ln_line_tbl_index).header_id   :=
                        l_bulk_line_rec.header_id;
                    l_line_tbl (ln_line_tbl_index)   :=
                        oe_order_pub.g_miss_line_rec;
                    l_line_tbl (ln_line_tbl_index).operation   :=
                        oe_globals.g_opr_create;

                    IF lcu_lines_rec.new_linked_qty = 0
                    THEN
                        l_line_tbl (ln_line_tbl_index).ordered_quantity   :=
                            lcu_lines_rec.original_linked_qty;
                    ELSE
                        l_line_tbl (ln_line_tbl_index).ordered_quantity   :=
                              lcu_lines_rec.original_linked_qty
                            - lcu_lines_rec.new_linked_qty;
                    END IF;

                    debug_msg (
                           'New Ordered Qty for line '
                        || ln_line_tbl_index
                        || ' is '
                        || l_line_tbl (ln_line_tbl_index).ordered_quantity);

                    l_line_tbl (ln_line_tbl_index).line_type_id   :=
                        l_bulk_line_rec.line_type_id;
                    l_line_tbl (ln_line_tbl_index).cust_po_number   :=
                        l_bulk_line_rec.cust_po_number;
                    l_line_tbl (ln_line_tbl_index).inventory_item_id   :=
                        l_bulk_line_rec.inventory_item_id;
                    l_line_tbl (ln_line_tbl_index).ship_from_org_id   :=
                        l_bulk_line_rec.ship_from_org_id;
                    l_line_tbl (ln_line_tbl_index).demand_class_code   :=
                        l_bulk_line_rec.demand_class_code;
                    l_line_tbl (ln_line_tbl_index).unit_list_price   :=
                        l_bulk_line_rec.unit_list_price;
                    l_line_tbl (ln_line_tbl_index).invoice_to_org_id   :=
                        l_bulk_line_rec.invoice_to_org_id;
                    l_line_tbl (ln_line_tbl_index).ship_to_org_id   :=
                        l_bulk_line_rec.ship_to_org_id;
                    l_line_tbl (ln_line_tbl_index).salesrep_id   :=
                        l_bulk_line_rec.salesrep_id;
                    l_line_tbl (ln_line_tbl_index).price_list_id   :=
                        CASE
                            WHEN l_bulk_line_rec.agreement_id IS NOT NULL
                            THEN
                                fnd_api.g_miss_num
                            ELSE
                                l_bulk_line_rec.price_list_id
                        END;
                    l_line_tbl (ln_line_tbl_index).agreement_id   :=
                        NVL (l_bulk_line_rec.agreement_id,
                             fnd_api.g_miss_num);
                    l_line_tbl (ln_line_tbl_index).order_source_id   :=
                        l_bulk_line_rec.order_source_id;
                    l_line_tbl (ln_line_tbl_index).payment_term_id   :=
                        l_bulk_line_rec.payment_term_id;
                    l_line_tbl (ln_line_tbl_index).shipping_method_code   :=
                        l_bulk_line_rec.shipping_method_code;
                    l_line_tbl (ln_line_tbl_index).freight_terms_code   :=
                        l_bulk_line_rec.freight_terms_code;
                    l_line_tbl (ln_line_tbl_index).request_date   :=
                        l_bulk_line_rec.request_date;
                    l_line_tbl (ln_line_tbl_index).shipping_instructions   :=
                        l_bulk_line_rec.shipping_instructions;
                    l_line_tbl (ln_line_tbl_index).packing_instructions   :=
                        l_bulk_line_rec.packing_instructions;
                    l_line_tbl (ln_line_tbl_index).request_id   :=
                        gn_request_id;
                    l_line_tbl (ln_line_tbl_index).attribute1   :=
                        l_bulk_line_rec.attribute1;
                    l_line_tbl (ln_line_tbl_index).attribute6   :=
                        l_bulk_line_rec.attribute6;
                    l_line_tbl (ln_line_tbl_index).attribute7   :=
                        l_bulk_line_rec.attribute7;
                    l_line_tbl (ln_line_tbl_index).attribute8   :=
                        l_bulk_line_rec.attribute8;
                    l_line_tbl (ln_line_tbl_index).attribute10   :=
                        l_bulk_line_rec.attribute10;
                    l_line_tbl (ln_line_tbl_index).attribute13   :=
                        l_bulk_line_rec.attribute13;
                    l_line_tbl (ln_line_tbl_index).attribute14   :=
                        l_bulk_line_rec.attribute14;
                    l_line_tbl (ln_line_tbl_index).attribute15   :=
                        l_bulk_line_rec.attribute15;
                    l_line_tbl (ln_line_tbl_index).deliver_to_org_id   :=
                        l_bulk_line_rec.deliver_to_org_id;
                    l_line_tbl (ln_line_tbl_index).latest_acceptable_date   :=
                        l_bulk_line_rec.latest_acceptable_date;
                    l_line_tbl (ln_line_tbl_index).source_document_type_id   :=
                        2;                                     -- 2 for "Copy"
                    l_line_tbl (ln_line_tbl_index).source_document_id   :=
                        l_bulk_line_rec.header_id;
                    l_line_tbl (ln_line_tbl_index).source_document_line_id   :=
                        l_bulk_line_rec.line_id;
                END LOOP;

                xxd_ont_calloff_process_pkg.process_order (
                    p_header_rec           => l_header_rec,
                    p_line_tbl             => l_line_tbl,
                    p_action_request_tbl   => l_action_request_tbl,
                    x_line_tbl             => lx_line_tbl,
                    x_return_status        => lc_return_status,
                    x_error_message        => lc_error_message);

                debug_msg ('API Status ' || lc_return_status);

                IF lc_return_status = fnd_api.g_ret_sts_success
                THEN
                    lc_error_message   := NULL;
                ELSE
                    debug_msg ('API Error Message ' || lc_error_message);
                END IF;
            ELSIF lc_return_status = 'E'
            THEN
                lc_error_message   :=
                    'Order locked by another user. Skip processing this order.';
                lc_return_status   := 'E';
                debug_msg (lc_error_message);
            ELSIF l_x_header_rec.open_flag = 'N'
            THEN
                -- Skip if Bulk Order is closed
                lc_return_status   := 'S';
                lc_error_message   := NULL;
                debug_msg (
                    'Bulk Order is closed. Open Flag = ' || l_x_header_rec.open_flag);
            END IF;

            -- Update Processing Status
            UPDATE xxd_ont_calloff_orders_t
               SET status = lc_return_status, error_message = SUBSTR (lc_error_message, 1, 2000)
             WHERE     bulk_header_id = lcu_orders_rec.bulk_header_id
                   AND parent_request_id = p_parent_request_id
                   AND status = 'N'
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

            COMMIT;              -- Save each successful Bulk Order processing
            debug_msg (RPAD ('=', 100, '='));
        END LOOP;

        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End CALLOFF_ORDER_CANCEL_PRC');
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            x_retcode          := 2;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_calloff_orders_t
               SET status = 'E', error_message = lc_error_message
             WHERE     parent_request_id = p_parent_request_id
                   AND bulk_batch_id >= p_from_bulk_batch_id
                   AND bulk_batch_id <= p_to_bulk_batch_id
                   AND customer_batch_id >= p_from_customer_batch_id
                   AND customer_batch_id <= p_to_customer_batch_id;

            COMMIT;

            debug_msg ('End CALLOFF_ORDER_CANCEL_PRC');
            fnd_file.put_line (
                fnd_file.LOG,
                   'Others Exception in CALLOFF_ORDER_CANCEL_PRC = '
                || lc_error_message);
    END calloff_order_cancel_prc;
END xxd_ont_calloff_ord_cancel_pkg;
/
