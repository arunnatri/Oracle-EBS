--
-- XXD_ONT_CALLOFF_RELINK_PKG  (Package Body) 
--
/* Formatted on 4/26/2023 4:28:57 PM (QP5 v5.362) */
CREATE OR REPLACE PACKAGE BODY APPS."XXD_ONT_CALLOFF_RELINK_PKG"
AS
    /****************************************************************************************
    * Package      : XXD_ONT_CALLOFF_RELINK_PKG
    * Design       : This package will be used to make a calloff order eligible for
    *                reconsumption by applying a line level hold and reseting the status
    * Notes        :
    * Modification :
    -- ======================================================================================
    -- Date         Version#   Name                    Comments
    -- ======================================================================================
    -- 15-Mar-2018  1.0        Viswanathan Pandian     Initial Version
    -- 02-Mar-2020  1.1        Viswanathan Pandian     Redesigned for CCR0008440
    *****************************************************************************************/
    -- ======================================================================================
    -- Set values for Global Variables
    -- ======================================================================================
    gn_org_id              NUMBER := fnd_global.org_id;
    gn_user_id             NUMBER := fnd_global.user_id;
    gn_login_id            NUMBER := fnd_global.login_id;
    gn_request_id          NUMBER := fnd_global.conc_request_id;
    gn_application_id      NUMBER := fnd_profile.VALUE ('RESP_APPL_ID');
    gn_responsibility_id   NUMBER := fnd_profile.VALUE ('RESP_ID');
    gc_debug_enable        VARCHAR2 (1);
    p_parent_request_id    NUMBER := fnd_global.conc_request_id;

    -- ======================================================================================
    -- This procedure prints the Debug Messages in Log Or File
    -- ======================================================================================
    PROCEDURE debug_msg (p_msg IN VARCHAR2)
    AS
    BEGIN
        -- Write Conc Log
        IF gc_debug_enable = 'Y'
        THEN
            fnd_file.put_line (fnd_file.LOG, p_msg);
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
    EXCEPTION
        WHEN OTHERS
        THEN
            fnd_file.put_line (fnd_file.LOG,
                               'Others Exception in INIT = ' || SQLERRM);
    END init;

    -- ======================================================================================
    -- This procedure will collect calloff orders eligible for reconsumption in a table
    -- ======================================================================================
    PROCEDURE master_prc (
        x_errbuf                 OUT NOCOPY VARCHAR2,
        x_retcode                OUT NOCOPY VARCHAR2,
        p_org_id                            hr_operating_units.organization_id%TYPE,
        p_cust_account_id     IN            oe_order_headers_all.sold_to_org_id%TYPE,
        p_cust_po_number      IN            oe_order_headers_all.cust_po_number%TYPE,
        p_order_number        IN            oe_order_headers_all.order_number%TYPE,
        p_order_type_id       IN            oe_order_headers_all.order_type_id%TYPE,
        p_request_date_from   IN            VARCHAR2,
        p_request_date_to     IN            VARCHAR2,
        p_threads             IN            NUMBER,
        p_purge_days          IN            NUMBER,
        p_debug_enable        IN            VARCHAR2)
    AS
        CURSOR get_hold_id_c IS
            SELECT ol.lookup_code
              FROM oe_lookups ol
             WHERE     ol.meaning = 'REPROCESS'
                   AND ol.lookup_type = 'XXD_ONT_CALLOFF_ORDER_HOLDS'
                   AND ol.enabled_flag = 'Y'
                   AND ((ol.start_date_active IS NOT NULL AND ol.start_date_active <= SYSDATE) OR (ol.start_date_active IS NULL AND 1 = 1))
                   AND ((ol.end_date_active IS NOT NULL AND ol.end_date_active >= SYSDATE) OR (ol.end_date_active IS NULL AND 1 = 1));

        CURSOR get_batches IS
              SELECT bucket, MIN (batch_id) from_batch_id, MAX (batch_id) to_batch_id
                FROM (SELECT batch_id, NTILE (p_threads) OVER (ORDER BY batch_id) bucket
                        FROM (SELECT DISTINCT batch_id
                                FROM xxd_ont_calloff_order_relink_t
                               WHERE     parent_request_id = gn_request_id
                                     AND status = 'N'))
            GROUP BY bucket
            ORDER BY 1;

        TYPE conc_request_tbl IS TABLE OF NUMBER
            INDEX BY BINARY_INTEGER;

        l_line_rec             oe_order_pub.line_rec_type;
        l_header_rec           oe_order_pub.header_rec_type;
        l_action_request_tbl   oe_order_pub.request_tbl_type;
        l_request_rec          oe_order_pub.request_rec_type;
        l_line_tbl             oe_order_pub.line_tbl_type;
        l_hold_source_rec      oe_holds_pvt.hold_source_rec_type;
        l_order_tbl_type       oe_holds_pvt.order_tbl_type;
        l_conc_request_tbl     conc_request_tbl;
        ln_hold_id             oe_hold_sources_all.hold_id%TYPE;
        ln_msg_count           NUMBER := 0;
        ln_record_count        NUMBER := 0;
        ln_msg_index_out       NUMBER;
        ln_request_id          NUMBER;
        ln_req_count           NUMBER := 0;
        lc_sub_prog_name       VARCHAR2 (20) := 'MASTER_PRC';
        lc_req_data            VARCHAR2 (10);
        lc_msg_data            VARCHAR2 (4000);
        lc_error_message       VARCHAR2 (4000);
        lc_return_status       VARCHAR2 (20);
        lb_req_status          BOOLEAN;
        lc_phase               VARCHAR2 (100);
        lc_status              VARCHAR2 (100);
        lc_dev_phase           VARCHAR2 (100);
        lc_dev_status          VARCHAR2 (100);
        lc_message             VARCHAR2 (4000);
        lb_flag                BOOLEAN;
        lex_hold_exception     EXCEPTION;
    BEGIN
        IF lc_req_data IS NOT NULL
        THEN
            debug_msg ('Done!!!');
            RETURN;
        END IF;

        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        init;
        gc_debug_enable   := p_debug_enable;

        OPEN get_hold_id_c;

        FETCH get_hold_id_c INTO ln_hold_id;

        CLOSE get_hold_id_c;

        IF ln_hold_id IS NULL
        THEN
            x_errbuf    :=
                'Hold Information is not available in lookup XXD_ONT_CALLOFF_ORDER_HOLDS';
            x_retcode   := 1;
            RAISE lex_hold_exception;
        END IF;

        DELETE xxd_ont_calloff_order_relink_t
         WHERE TRUNC (creation_date) <= TRUNC (SYSDATE) - p_purge_days;

        debug_msg ('Delete records older than ' || p_purge_days || ' days');
        debug_msg ('Count = ' || SQL%ROWCOUNT);

        INSERT INTO xxd_ont_calloff_order_relink_t
            SELECT ooha.org_id,
                   ooha.header_id,
                   ooha.order_number,
                   ooha.sold_to_org_id,
                   ooha.cust_po_number,
                   ooha.request_date,
                   ooha.attribute5,
                   oola.line_id,
                   oola.line_number,
                   oola.shipment_number,
                   oola.ordered_item,
                   oola.inventory_item_id,
                   oola.ordered_quantity,
                   oola.request_date,
                   oola.schedule_ship_date,
                   oola.latest_acceptable_date,
                   oola.demand_class_code,
                   (SELECT DECODE (COUNT (1), 0, 'N', 'Y')
                      FROM oe_order_headers_all ooha_bulk, oe_order_lines_all oola_bulk, fnd_lookup_values flv
                     WHERE     ooha_bulk.header_id = oola_bulk.header_id
                           AND ooha_bulk.order_type_id =
                               TO_NUMBER (flv.lookup_code)
                           AND ooha_bulk.org_id = TO_NUMBER (flv.tag)
                           AND flv.language = USERENV ('LANG')
                           AND flv.enabled_flag = 'Y'
                           AND TRUNC (SYSDATE) BETWEEN TRUNC (
                                                           NVL (
                                                               flv.start_date_active,
                                                               SYSDATE))
                                                   AND TRUNC (
                                                           NVL (
                                                               flv.end_date_active,
                                                               SYSDATE))
                           AND flv.lookup_type = 'XXD_ONT_BULK_ORDER_TYPE'
                           AND ooha_bulk.open_flag = 'Y'
                           AND oola_bulk.open_flag = 'Y'
                           AND ooha_bulk.org_id = p_org_id
                           AND ooha_bulk.sold_to_org_id = ooha.sold_to_org_id
                           AND oola_bulk.inventory_item_id =
                               oola.inventory_item_id
                           AND oola_bulk.request_date <=
                               oola_bulk.latest_acceptable_date
                           AND oola_bulk.schedule_ship_date <
                               oola.latest_acceptable_date + 1
                           AND oola_bulk.schedule_ship_date IS NOT NULL
                           AND oola_bulk.ordered_quantity > 0)
                       bulk_available,
                   gn_request_id,
                   NULL,
                   NULL,
                   ln_hold_id,
                   'N',
                   NULL,
                   SYSDATE,
                   gn_user_id,
                   SYSDATE,
                   gn_user_id,
                   gn_login_id
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
                   AND NOT EXISTS
                           (SELECT 1
                              FROM mtl_reservations mr
                             WHERE mr.demand_source_line_id = oola.line_id)
                   AND oola.global_attribute19 IS NULL
                   AND ooha.org_id = p_org_id
                   AND ((p_cust_po_number IS NOT NULL AND ooha.cust_po_number = p_cust_po_number) OR (p_cust_po_number IS NULL AND 1 = 1))
                   AND ((p_order_number IS NOT NULL AND ooha.order_number = p_order_number) OR (p_order_number IS NULL AND 1 = 1))
                   AND ((p_cust_account_id IS NOT NULL AND ooha.sold_to_org_id = p_cust_account_id) OR (p_cust_account_id IS NULL AND 1 = 1))
                   AND ((p_order_type_id IS NOT NULL AND ooha.order_type_id = p_order_type_id) OR (p_order_type_id IS NULL AND 1 = 1))
                   AND ((p_request_date_from IS NOT NULL AND p_request_date_to IS NOT NULL AND ooha.request_date BETWEEN fnd_date.canonical_to_date (p_request_date_from) AND fnd_date.canonical_to_date (p_request_date_to)) OR ((p_request_date_from IS NULL OR p_request_date_to IS NULL) AND 1 = 1));

        ln_record_count   := SQL%ROWCOUNT;
        debug_msg ('Record Count = ' || ln_record_count);

        IF ln_record_count = 0
        THEN
            x_errbuf      := 'No Data Found';
            x_retcode     := 1;
            debug_msg (x_errbuf);
            lc_req_data   := 'END';
        ELSE
            -- Mark error for no bulk records
            UPDATE xxd_ont_calloff_order_relink_t
               SET status = 'E', error_message = 'No eligible bulk available'
             WHERE parent_request_id = gn_request_id AND bulk_available = 'N';

            debug_msg ('Perform Batching');

            -- Perform Batching
            MERGE INTO xxd_ont_calloff_order_relink_t xocort
                 USING (SELECT ROWID, header_id, DENSE_RANK () OVER (ORDER BY header_id) batch_id
                          FROM xxd_ont_calloff_order_relink_t
                         WHERE     parent_request_id = gn_request_id
                               AND status = 'N') xocort1
                    ON (xocort.ROWID = xocort1.ROWID AND xocort.header_id = xocort1.header_id)
            WHEN MATCHED
            THEN
                UPDATE SET xocort.batch_id   = xocort1.batch_id;

            COMMIT;

            -- Submit Child Programs
            FOR i IN get_batches
            LOOP
                ln_req_count   := ln_req_count + 1;
                l_conc_request_tbl (ln_req_count)   :=
                    fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_CALLOFF_RELINK_CHILD', sub_request => FALSE, argument1 => gn_request_id, argument2 => i.from_batch_id, argument3 => i.to_batch_id
                                                , argument4 => p_debug_enable);
                COMMIT;
            END LOOP;

            IF ln_req_count > 0 OR ln_record_count > 0
            THEN
                IF ln_req_count > 0
                THEN
                    debug_msg ('Successfully Submitted Child Threads');

                    -- Wait for all Calloff Order Schedule Programs
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
                END IF;                                    -- ln_req_count > 0

                debug_msg ('Submitting Report');
                lb_flag   :=
                    fnd_request.add_layout (
                        template_appl_name   => 'XXDO',
                        template_code        => 'XXD_ONT_CALLOFF_RELINK_REP',
                        template_language    => 'en',
                        template_territory   => '00',
                        output_format        => 'EXCEL');
                ln_request_id   :=
                    fnd_request.submit_request (application => 'XXDO', program => 'XXD_ONT_CALLOFF_RELINK_REP', sub_request => FALSE
                                                , argument1 => gn_request_id);
                COMMIT;
                debug_msg ('Report Request ID = ' || ln_request_id);

                LOOP
                    lb_req_status   :=
                        fnd_concurrent.wait_for_request (
                            request_id   => ln_request_id,
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

                -- Per Oracle Doc ID 1922152.1
                UPDATE fnd_concurrent_requests
                   SET priority_request_id = gn_request_id, is_sub_request = 'Y'
                 WHERE request_id = ln_request_id;
            END IF;

            debug_msg (
                'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
            debug_msg ('End ' || lc_sub_prog_name);
            lc_req_data   := 'END';
        END IF;
    EXCEPTION
        WHEN lex_hold_exception
        THEN
            fnd_file.put_line (fnd_file.LOG, x_errbuf);
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_calloff_order_relink_t
               SET status = 'E', error_message = lc_error_message
             WHERE parent_request_id = gn_request_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in MASTER_PRC = ' || SQLERRM);
    END master_prc;

    -- ======================================================================================
    -- This procedure will apply hold for each order line of the current batch
    -- ======================================================================================

    PROCEDURE child_prc (x_errbuf OUT NOCOPY VARCHAR2, x_retcode OUT NOCOPY VARCHAR2, p_parent_request_id IN NUMBER
                         , p_from_batch_id IN NUMBER, p_to_batch_id IN NUMBER, p_debug_enable IN VARCHAR2)
    AS
        CURSOR get_lines_c IS
            SELECT *
              FROM xxd_ont_calloff_order_relink_t
             WHERE     parent_request_id = p_parent_request_id
                   AND status = 'N'
                   AND batch_id >= p_from_batch_id
                   AND batch_id <= p_to_batch_id;

        lc_sub_prog_name    VARCHAR2 (100) := 'CHILD_PRC';
        l_hold_source_rec   oe_holds_pvt.hold_source_rec_type;
        ln_msg_count        NUMBER := 0;
        ln_msg_index_out    NUMBER;
        lc_msg_data         VARCHAR2 (4000);
        lc_error_message    VARCHAR2 (4000);
        lc_return_status    VARCHAR2 (20);
    BEGIN
        -- Per Oracle Doc ID 1922152.1
        UPDATE fnd_concurrent_requests
           SET priority_request_id = p_parent_request_id, is_sub_request = 'Y'
         WHERE request_id = fnd_global.conc_request_id;

        gc_debug_enable   := p_debug_enable;
        debug_msg ('Start ' || lc_sub_prog_name);
        debug_msg (
            'Start Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg (RPAD ('=', 100, '='));
        init;

        FOR lines_rec IN get_lines_c
        LOOP
            oe_msg_pub.delete_msg;
            oe_msg_pub.initialize;
            SAVEPOINT order_line;

            debug_msg (
                   'Processing Order Number '
                || lines_rec.order_number
                || '. Order Line Number '
                || lines_rec.line_number
                || '.'
                || lines_rec.shipment_number);
            lc_error_message                     := NULL;

            ln_msg_count                         := 0;
            ln_msg_index_out                     := 0;
            lc_msg_data                          := NULL;
            lc_error_message                     := NULL;
            l_hold_source_rec.hold_id            := lines_rec.reprocess_hold_id;
            l_hold_source_rec.hold_entity_code   := 'O';
            l_hold_source_rec.hold_entity_id     := lines_rec.header_id;
            l_hold_source_rec.line_id            := lines_rec.line_id;
            l_hold_source_rec.hold_comment       :=
                'Applying processing hold on Calloff Order Line';
            oe_holds_pub.apply_holds (
                p_api_version        => 1.0,
                p_validation_level   => fnd_api.g_valid_level_full,
                p_hold_source_rec    => l_hold_source_rec,
                x_msg_count          => ln_msg_count,
                x_msg_data           => lc_msg_data,
                x_return_status      => lc_return_status);
            debug_msg ('Apply Hold Status = ' || lc_return_status);

            IF lc_return_status = 'S'
            THEN
                UPDATE oe_order_lines_all
                   SET global_attribute19 = 'REPROCESS', global_attribute20 = ''
                 WHERE line_id = lines_rec.line_id;

                debug_msg ('Status updated in Order Lines table');
            ELSE
                FOR i IN 1 .. oe_msg_pub.count_msg
                LOOP
                    oe_msg_pub.get (p_msg_index => i, p_encoded => fnd_api.g_false, p_data => lc_msg_data
                                    , p_msg_index_out => ln_msg_index_out);
                    lc_error_message   :=
                        SUBSTR (lc_error_message || lc_msg_data, 1, 4000);
                END LOOP;

                debug_msg ('Hold API Error = ' || lc_error_message);
                ROLLBACK TO order_line;
            END IF;

            UPDATE xxd_ont_calloff_order_relink_t
               SET status = lc_return_status, error_message = lc_error_message, request_id = gn_request_id,
                   last_update_date = SYSDATE
             WHERE     line_id = lines_rec.line_id
                   AND parent_request_id = p_parent_request_id
                   AND batch_id >= p_from_batch_id
                   AND batch_id <= p_to_batch_id;

            COMMIT;
        END LOOP;

        debug_msg (RPAD ('=', 100, '='));
        debug_msg (
            'End Time ' || TO_CHAR (SYSDATE, 'DD-MON-YYYY HH24:MI:SS AM'));
        debug_msg ('End ' || lc_sub_prog_name);
    EXCEPTION
        WHEN OTHERS
        THEN
            ROLLBACK;
            lc_error_message   := SUBSTR (SQLERRM, 1, 2000);

            UPDATE xxd_ont_calloff_order_relink_t
               SET status = 'E', error_message = lc_error_message
             WHERE     parent_request_id = p_parent_request_id
                   AND batch_id >= p_from_batch_id
                   AND batch_id <= p_to_batch_id;

            debug_msg ('End ' || lc_sub_prog_name);
            fnd_file.put_line (
                fnd_file.LOG,
                'Others Exception in CHILD_PRC = ' || lc_error_message);
    END child_prc;
END xxd_ont_calloff_relink_pkg;
/
